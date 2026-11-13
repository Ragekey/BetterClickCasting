local _, ns = ...

local Constants = ns.Constants
local Database = ns.Database

local SpellRanks = {}
ns.SpellRanks = SpellRanks

SpellRanks.RULE_MAX = "MAX"
SpellRanks.RULE_MAX_MINUS_1 = "MAX_MINUS_1"
SpellRanks.RULE_MAX_MINUS_2 = "MAX_MINUS_2"
SpellRanks.RULE_MAX_MINUS_3 = "MAX_MINUS_3"
SpellRanks.RULE_FIXED = "FIXED"

local VALID_RULES = {
	[SpellRanks.RULE_MAX] = true,
	[SpellRanks.RULE_MAX_MINUS_1] = true,
	[SpellRanks.RULE_MAX_MINUS_2] = true,
	[SpellRanks.RULE_MAX_MINUS_3] = true,
	[SpellRanks.RULE_FIXED] = true,
}

local cache = {
	dirty = true,
	byActionID = {}, -- [actionID] = rankEntry
	bySpellKey = {}, -- ["bank:spellName"] = { name, spellBank, entries = { ... }, maxEntry = rankEntry }
}

function SpellRanks.InvalidateCache()
	cache.dirty = true
end

function SpellRanks.ExtractRankNumber(subtext)
	if not subtext or subtext == "" then
		return nil
	end
	local num = string.match(subtext, "(%d+)")
	return num and tonumber(num) or nil
end

function SpellRanks.ExtractShortRankText(subtext)
	local rankNum = SpellRanks.ExtractRankNumber(subtext)
	if rankNum then
		return "R" .. rankNum
	end
	return nil
end

function SpellRanks.GetSpellSubtextForAction(actionID)
	if not actionID or not C_Spell or not C_Spell.GetSpellSubtext then
		return nil
	end

	local subtext = C_Spell.GetSpellSubtext(actionID)
	if subtext and subtext ~= "" then
		return subtext
	end

	if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
		local overrideID = C_SpellBook.FindSpellOverrideByID(actionID)
		if overrideID and overrideID ~= actionID then
			subtext = C_Spell.GetSpellSubtext(overrideID)
			if subtext and subtext ~= "" then
				return subtext
			end
		end
	end

	return nil
end

function SpellRanks.GetSpellBaseNameForAction(actionID)
	if not actionID or not C_Spell or not C_Spell.GetSpellInfo then
		return nil
	end

	local spellIDToQuery = actionID
	if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
		local overrideID = C_SpellBook.FindSpellOverrideByID(actionID)
		if overrideID then
			spellIDToQuery = overrideID
		end
	end

	local spellInfo = C_Spell.GetSpellInfo(spellIDToQuery)
	return spellInfo and spellInfo.name or nil
end

function SpellRanks.GetSpellIconForAction(actionID)
	if not actionID or not C_Spell or not C_Spell.GetSpellInfo then
		return nil
	end
	local spellIDToQuery = actionID
	if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
		local overrideID = C_SpellBook.FindSpellOverrideByID(actionID)
		if overrideID then
			spellIDToQuery = overrideID
		end
	end
	local spellInfo = C_Spell.GetSpellInfo(spellIDToQuery)
	return spellInfo and spellInfo.iconID or nil
end

function SpellRanks.GetSpellPowerCostString(spellID)
	if not spellID or not C_Spell or not C_Spell.GetSpellPowerCost then
		return nil
	end
	local costs = C_Spell.GetSpellPowerCost(spellID)
	if not costs or #costs == 0 then
		return nil
	end
	local first = costs[1]
	if first and first.cost and first.cost > 0 then
		local powerName = (first.name and _G[first.name]) or first.name or ""
		if powerName ~= "" then
			return string.format("%d %s", first.cost, powerName)
		end
		return tostring(first.cost)
	end
	return nil
end

local function MakeSpellGroupKey(spellBank, spellName)
	return tostring(spellBank or 0) .. ":" .. tostring(spellName or "")
end

local function ScanSlotIntoCache(slotIndex, spellBank)
	if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then
		return
	end

	local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
	if not info or info.isPassive or info.isOffSpec then
		return
	end

	local isSpell = (Enum and Enum.SpellBookItemType and info.itemType == Enum.SpellBookItemType.Spell)
	local isPetAction = (Enum and Enum.SpellBookItemType and info.itemType == Enum.SpellBookItemType.PetAction)
	if not isSpell and not isPetAction then
		return
	end

	local actionID = info.actionID
	local spellID = info.spellID or actionID
	local name = info.name
	if not actionID or not name or name == "" then
		return
	end

	local subName = info.subName
	if not subName or subName == "" then
		subName = SpellRanks.GetSpellSubtextForAction(spellID) or SpellRanks.GetSpellSubtextForAction(actionID) or ""
	end

	local isLowRank = false
	if C_SpellBook.IsSpellBookItemLowRank then
		isLowRank = C_SpellBook.IsSpellBookItemLowRank(slotIndex, spellBank) or false
	end

	local rankNum = SpellRanks.ExtractRankNumber(subName)
	local groupKey = MakeSpellGroupKey(spellBank, name)
	local group = cache.bySpellKey[groupKey]
	if not group then
		group = {
			name = name,
			spellBank = spellBank,
			entries = {},
			seenActionIDs = {},
			maxEntry = nil,
		}
		cache.bySpellKey[groupKey] = group
	end

	local entry = group.seenActionIDs[actionID]
	if not entry then
		entry = {
			actionID = actionID,
			spellID = spellID,
			slotIndex = slotIndex,
			spellBank = spellBank,
			name = name,
			subName = subName,
			rankNum = rankNum,
			isLowRank = isLowRank,
			group = group,
		}
		group.seenActionIDs[actionID] = entry
		table.insert(group.entries, entry)
	else
		entry.slotIndex = slotIndex
		if (not entry.subName or entry.subName == "") and subName ~= "" then
			entry.subName = subName
			entry.rankNum = rankNum
		end
		entry.isLowRank = isLowRank
	end

	cache.byActionID[actionID] = entry
	if spellID and spellID ~= actionID then
		cache.byActionID[spellID] = entry
	end
end

function SpellRanks.EnsureCache()
	if not cache.dirty then
		return cache
	end

	cache.byActionID = {}
	cache.bySpellKey = {}

	if C_SpellBook and Enum and Enum.SpellBookSpellBank then
		local playerBank = Enum.SpellBookSpellBank.Player
		local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
		for skillLineIndex = 1, numSkillLines do
			local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
			if skillLineInfo and not skillLineInfo.offSpecID and skillLineInfo.numSpellBookItems and skillLineInfo.itemIndexOffset then
				for i = 1, skillLineInfo.numSpellBookItems do
					local slotIndex = skillLineInfo.itemIndexOffset + i
					ScanSlotIntoCache(slotIndex, playerBank)
				end
			end
		end

		local petBank = Enum.SpellBookSpellBank.Pet
		local numPetSpells = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells() or 0
		for slotIndex = 1, numPetSpells do
			ScanSlotIntoCache(slotIndex, petBank)
		end
	end

	for _, group in pairs(cache.bySpellKey) do
		table.sort(group.entries, function(a, b)
			if a.rankNum and b.rankNum and a.rankNum ~= b.rankNum then
				return a.rankNum < b.rankNum
			end
			return a.slotIndex < b.slotIndex
		end)

		local maxEntry = nil
		for i, entry in ipairs(group.entries) do
			entry.rankIndex = i
			if not entry.isLowRank then
				maxEntry = entry
			end
		end
		if not maxEntry and #group.entries > 0 then
			maxEntry = group.entries[#group.entries]
		end
		group.maxEntry = maxEntry
	end

	cache.dirty = false
	return cache
end

function SpellRanks.GetRankEntryForAction(actionID)
	if not actionID then
		return nil
	end
	local currentCache = SpellRanks.EnsureCache()
	local entry = currentCache.byActionID[actionID]
	if entry then
		return entry
	end

	if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
		local overrideID = C_SpellBook.FindSpellOverrideByID(actionID)
		if overrideID and currentCache.byActionID[overrideID] then
			return currentCache.byActionID[overrideID]
		end
	end

	return nil
end

-- Liefert die Zaubergruppe auch dann, wenn der konkret gebundene Rang (z. B. nach Teil-Respec)
-- nicht mehr gelernt ist, aber niedrigere Ränge desselben Zaubers im Zauberbuch existieren.
function SpellRanks.GetSpellGroupForAction(actionID, bindingType)
	if not actionID then
		return nil
	end
	local directEntry = SpellRanks.GetRankEntryForAction(actionID)
	if directEntry and directEntry.group then
		return directEntry.group
	end

	local baseName = SpellRanks.GetSpellBaseNameForAction(actionID)
	if not baseName or baseName == "" then
		return nil
	end

	local currentCache = SpellRanks.EnsureCache()
	local spellBank = (Enum and Enum.ClickBindingType and bindingType == Enum.ClickBindingType.PetAction)
		and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1)
		or (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0)
	local group = currentCache.bySpellKey[MakeSpellGroupKey(spellBank, baseName)]
	if group and group.entries and #group.entries > 0 then
		return group
	end
	return nil
end

-- Prüft für eine Klickbelegung, ob der gebundene Zauber aktuell im Zauberbuch gelernt ist.
-- Berücksichtigt Leermenge (Talent verlernt), Einzelmenge (rangloser Talent-Zauber) und
-- Begleiter-Zauber (keine Fehlwarnung, solange kein Begleiter gerufen ist).
function SpellRanks.IsBindingSpellLearned(bindingInfo)
	if not bindingInfo or not bindingInfo.actionID or not Constants.IsSpellOrPetBinding(bindingInfo) then
		return true
	end

	local actionID = bindingInfo.actionID
	if SpellRanks.GetRankEntryForAction(actionID) then
		return true
	end

	if Enum and Enum.ClickBindingType and bindingInfo.type == Enum.ClickBindingType.PetAction then
		if not C_SpellBook or not C_SpellBook.HasPetSpells or not C_SpellBook.HasPetSpells() then
			return true
		end
		local petBank = (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
		if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(actionID, petBank, true) then
			return true
		end
		return false
	end

	if C_SpellBook then
		local playerBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		if C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(actionID, playerBank, true) then
			return true
		end
		if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(actionID, playerBank, true) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Smarte Rang-Regeln (Immer MAX, Immer MAX - N, Fester Rang)
--------------------------------------------------------------------------------

function SpellRanks.MakeBindingRuleKey(bindingInfo, rankEntry)
	if not bindingInfo or not bindingInfo.button or not Constants.IsSpellOrPetBinding(bindingInfo) then
		return nil
	end
	rankEntry = rankEntry or SpellRanks.GetRankEntryForAction(bindingInfo.actionID)
	local spellName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(bindingInfo.actionID)
	if not spellName or spellName == "" then
		return nil
	end
	local spellBank = (rankEntry and rankEntry.spellBank) or 0
	local charName = (Constants.GetPlayerDisplayName and Constants.GetPlayerDisplayName()) or (UnitName and UnitName("player")) or "Player"
	local realmName = (GetRealmName and GetRealmName()) or "Realm"
	local modNum = tonumber(bindingInfo.modifiers) or 0

	return string.format("%s-%s|%d:%s|%s:%s", charName, realmName, modNum, tostring(bindingInfo.button), tostring(spellBank), spellName)
end

local function MakeLegacyFirstNameRuleKey(bindingInfo, rankEntry)
	if not bindingInfo or not bindingInfo.button or not Constants.IsSpellOrPetBinding(bindingInfo) then
		return nil
	end
	rankEntry = rankEntry or SpellRanks.GetRankEntryForAction(bindingInfo.actionID)
	local spellName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(bindingInfo.actionID)
	if not spellName or spellName == "" then
		return nil
	end
	local spellBank = (rankEntry and rankEntry.spellBank) or 0
	local firstName = (UnitName and UnitName("player")) or "Player"
	local realmName = (GetRealmName and GetRealmName()) or "Realm"
	local modNum = tonumber(bindingInfo.modifiers) or 0

	return string.format("%s-%s|%d:%s|%s:%s", firstName, realmName, modNum, tostring(bindingInfo.button), tostring(spellBank), spellName)
end

-- Löst einen importierten oder von einem anderen Charakter kopierten Zauber-Eintrag
-- intelligent auf den passenden gelernten Rang des aktuellen Charakters auf.
function SpellRanks.ResolveImportedSpellBinding(importedEntry)
	if type(importedEntry) ~= "table" then
		return nil, nil
	end
	local currentCache = SpellRanks.EnsureCache()
	local bType = tonumber(importedEntry.type) or 0
	local spellBank = (Enum and Enum.ClickBindingType and bType == Enum.ClickBindingType.PetAction)
		and (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1)
		or (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0)

	local directEntry = importedEntry.actionID and SpellRanks.GetRankEntryForAction(importedEntry.actionID)
	local group = directEntry and directEntry.group

	if not group then
		local baseName = importedEntry.spellName
		if (not baseName or baseName == "") and importedEntry.actionID then
			baseName = SpellRanks.GetSpellBaseNameForAction(importedEntry.actionID)
		end
		if baseName and baseName ~= "" then
			local groupKey = MakeSpellGroupKey(spellBank, baseName)
			group = currentCache.bySpellKey[groupKey]
		end
	end

	if not group or not group.entries or #group.entries == 0 then
		return nil, nil
	end

	local ruleMode = importedEntry.ruleMode
	if not ruleMode or not VALID_RULES[ruleMode] then
		ruleMode = SpellRanks.RULE_MAX
	end

	-- Bei aktiver Smart-Regel (MAX, MAX-1 usw.) auf den Ziel-Rang des aktuellen Charakters auflösen
	if ruleMode ~= SpellRanks.RULE_FIXED then
		if #group.entries == 1 then
			return group.entries[1], ruleMode
		end
		local targetEntry = SpellRanks.GetTargetEntryForRule(group, ruleMode)
		if targetEntry then
			return targetEntry, ruleMode
		end
	end

	-- Bei Fester-Rang-Regel (FIXED): Exakten Rang bevorzugen, sonst nächstniedrigeren gelernten Rang wählen
	if directEntry then
		return directEntry, ruleMode
	end
	local wantedRank = tonumber(importedEntry.rankNum) or 0
	if wantedRank > 0 then
		local bestMatch = nil
		for _, entry in ipairs(group.entries) do
			if entry.rankNum == wantedRank then
				return entry, ruleMode
			elseif entry.rankNum and entry.rankNum < wantedRank then
				bestMatch = entry
			end
		end
		if bestMatch then
			return bestMatch, ruleMode
		end
	end

	return group.maxEntry or group.entries[#group.entries], ruleMode
end

function SpellRanks.GetRuleForBinding(bindingInfo, rankEntry)
	rankEntry = rankEntry or (bindingInfo and SpellRanks.GetRankEntryForAction(bindingInfo.actionID))
	if not rankEntry or not rankEntry.group then
		return SpellRanks.RULE_FIXED
	end
	-- Einzelmenge (erst 1 Rang gelernt) wird bereits als Smart-Regel erfasst,
	-- sobald der Zauber eine echte Rangnummer besitzt (z. B. "Rang 1"), damit
	-- beim späteren Erlernen von Rang 2 zuverlässig die erste Hero-Card erscheint.
	if #rankEntry.group.entries <= 1 and not rankEntry.rankNum then
		return SpellRanks.RULE_FIXED
	end

	local key = SpellRanks.MakeBindingRuleKey(bindingInfo, rankEntry)
	if not key then
		return SpellRanks.RULE_FIXED
	end

	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	local rules = BetterClickCastingDB.rankRules
	if type(rules) ~= "table" then
		rules = {}
		BetterClickCastingDB.rankRules = rules
	end

	local saved = rules[key]
	if saved and VALID_RULES[saved] then
		return saved
	end

	-- Automatische Übernahme aus altem Vorname-Key (vor v0.7.0), falls vorhanden
	local legacyKey = MakeLegacyFirstNameRuleKey(bindingInfo, rankEntry)
	if legacyKey and legacyKey ~= key and rules[legacyKey] and VALID_RULES[rules[legacyKey]] then
		rules[key] = rules[legacyKey]
		return rules[key]
	end

	-- Smart-Hybrid (Option A): Bestehende Max-Rang-Belegungen starten als "Immer MAX",
	-- bereits bestehende Downranks starten als "Fester Rang", damit beim ersten Login
	-- nach der Installation kein unerwartetes Popup für gewollte Downranks erscheint.
	local isCurrentlyMax = (rankEntry.group.maxEntry and rankEntry.group.maxEntry.actionID == bindingInfo.actionID)
	local initialRule = isCurrentlyMax and SpellRanks.RULE_MAX or SpellRanks.RULE_FIXED
	rules[key] = initialRule
	return initialRule
end

function SpellRanks.SetRuleForBinding(bindingInfo, ruleMode, rankEntry)
	if not VALID_RULES[ruleMode] then
		return
	end
	local key = SpellRanks.MakeBindingRuleKey(bindingInfo, rankEntry)
	if not key then
		return
	end
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	if type(BetterClickCastingDB.rankRules) ~= "table" then
		BetterClickCastingDB.rankRules = {}
	end
	BetterClickCastingDB.rankRules[key] = ruleMode
end

function SpellRanks.GetTargetEntryForRule(group, ruleMode)
	if not group or not group.entries or #group.entries <= 1 then
		return nil
	end
	if not ruleMode or ruleMode == SpellRanks.RULE_FIXED then
		return nil
	end

	local maxEntry = group.maxEntry or group.entries[#group.entries]
	if not maxEntry then
		return nil
	end

	local maxIndex = maxEntry.rankIndex or #group.entries
	local offset = 0
	if ruleMode == SpellRanks.RULE_MAX_MINUS_1 then
		offset = 1
	elseif ruleMode == SpellRanks.RULE_MAX_MINUS_2 then
		offset = 2
	elseif ruleMode == SpellRanks.RULE_MAX_MINUS_3 then
		offset = 3
	end

	-- 3-Punkte-Randwert-Sicherung: Niemals unter Index 1 (Rang 1) fallen
	local targetIndex = math.max(1, maxIndex - offset)
	return group.entries[targetIndex] or maxEntry
end

function SpellRanks.GetPendingSmartRuleUpdates()
	local updates = {}
	if not Database.Get("enableSmartRankRules") then
		return updates
	end
	if not C_ClickBindings or not C_ClickBindings.GetProfileInfo then
		return updates
	end

	local profile = C_ClickBindings.GetProfileInfo()
	if type(profile) ~= "table" then
		return updates
	end

	for _, bindingInfo in ipairs(profile) do
		if bindingInfo and bindingInfo.button and bindingInfo.actionID and Constants.IsSpellOrPetBinding(bindingInfo) then
			local rankEntry = SpellRanks.GetRankEntryForAction(bindingInfo.actionID)
			if rankEntry and rankEntry.group then
				-- Regel schon bei Rang 1 initialisieren, damit sie beim Erlernen von Rang 2 als RULE_MAX bereitsteht
				local ruleMode = SpellRanks.GetRuleForBinding(bindingInfo, rankEntry)
				if #rankEntry.group.entries > 1 then
					local targetEntry = SpellRanks.GetTargetEntryForRule(rankEntry.group, ruleMode)
					if targetEntry and targetEntry.actionID and targetEntry.actionID ~= bindingInfo.actionID then
						table.insert(updates, {
							bindingInfo = bindingInfo,
							ruleKey = SpellRanks.MakeBindingRuleKey(bindingInfo, rankEntry),
							ruleMode = ruleMode,
							currentEntry = rankEntry,
							targetEntry = targetEntry,
							spellName = rankEntry.name,
							spellIcon = SpellRanks.GetSpellIconForAction(targetEntry.actionID) or SpellRanks.GetSpellIconForAction(bindingInfo.actionID),
						})
					end
				end
			end
		end
	end

	return updates
end

function SpellRanks.GetActiveBindingsByActionID()
	local map = {}

	local function AddBindingInfo(info)
		if info and info.button and info.actionID and Constants.IsSpellOrPetBinding(info) then
			local list = map[info.actionID]
			if not list then
				list = {}
				map[info.actionID] = list
			end
			table.insert(list, info)
		end
	end

	-- Solange das ClickBindingFrame geöffnet ist, hat dessen dataProvider Vorrang
	-- (damit auch noch ungespeicherte Änderungen live im Zauberbuch sichtbar sind).
	if ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingFrame.dataProvider then
		for _, element in ClickBindingFrame.dataProvider:Enumerate() do
			if element and not element.unbound then
				AddBindingInfo(element.bindingInfo)
			end
		end
		return map
	end

	-- Ist das ClickBindingFrame geschlossen oder noch nicht geladen, liefert die native
	-- C-API C_ClickBindings.GetProfileInfo() jederzeit alle gespeicherten Belegungen.
	if C_ClickBindings and C_ClickBindings.GetProfileInfo then
		local profile = C_ClickBindings.GetProfileInfo()
		if type(profile) == "table" then
			for _, bindingInfo in ipairs(profile) do
				AddBindingInfo(bindingInfo)
			end
		end
	end

	return map
end
