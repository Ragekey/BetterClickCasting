local _, ns = ...

local Constants = ns.Constants
local Database = {}
ns.Database = Database

local DEFAULTS = {
	showRankInName = true,
	highlightDownranks = true,
	showRankSwitcher = true,
	showLineManaCost = true,
	moveInteractionsToBottom = true,
	showLineTooltips = true,
	groupingMode = "modifier", -- "modifier", "button", "type", "none"
	quickBindSpellbook = true,
	showSpellbookBadges = true,
	autoShowAllRanks = true,
	autoSelectPrimarySpellTab = true,
	enableSmartRankRules = true,
	trainerUpgradeBehavior = "card", -- "card", "auto", "off"
	unitHoverMode = "off", -- "off", "modifier", "always"
	unitHoverAnchor = "cursor", -- "cursor", "top", "bottom", "left", "right", "free"
	unitHoverScale = 100, -- 70 bis 150 (%)
	unitHoverAlpha = 94, -- 30 bis 100 (%)
	unitHoverShowMana = true,
	unitHoverShowRankTags = true,
	unitHoverShowInCombat = false,
	unitHoverShowInteractions = false,
	showMinimapButton = true,
	minimapAngle = 225,
	addonLocale = "auto", -- "auto", "enUS", "deDE", "esES"
	importMergeBindings = false, -- false = Ersetzen (Standard), true = Zusammenführen
}

local POSITION_KEYS = {
	"heroCardPos",
	"unitHoverPos",
}

local function CopyTableShallow(src)
	if type(src) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(src) do
		out[k] = v
	end
	return out
end

function Database.GetDefaults()
	return DEFAULTS
end

function Database.Init()
	-- Automatische Migration bestehender Einstellungen aus BetterClickCastingsDB
	if type(BetterClickCastingDB) ~= "table" then
		if type(BetterClickCastingsDB) == "table" then
			BetterClickCastingDB = BetterClickCastingsDB
		else
			BetterClickCastingDB = {}
		end
	end
	for k, v in pairs(DEFAULTS) do
		if BetterClickCastingDB[k] == nil then
			BetterClickCastingDB[k] = v
		end
	end
	if type(BetterClickCastingDB.rankRules) ~= "table" then
		BetterClickCastingDB.rankRules = {}
	end
	if type(BetterClickCastingDB.charProfiles) ~= "table" then
		BetterClickCastingDB.charProfiles = {}
	end
	BetterClickCastingsDB = BetterClickCastingDB
	if ns.ApplyLocale then
		ns.ApplyLocale(BetterClickCastingDB.addonLocale)
	end
	return BetterClickCastingDB
end

-- Liefert oder initialisiert den Profil-Eintrag des aktuell eingeloggten Charakters (inkl. Vor- und Nachname)
function Database.GetCurrentCharProfile()
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	local fullName = Constants.GetPlayerDisplayName()
	local realm = (GetRealmName and GetRealmName()) or "Realm"
	local charKey = Constants.GetPlayerProfileKey()

	-- Automatische Migration älterer Nur-Vorname-Profile desselben Charakters und Realms
	local firstName = Constants.GetPlayerFirstName and Constants.GetPlayerFirstName() or nil
	if firstName and firstName ~= fullName then
		local legacyKey = firstName .. " (" .. realm .. ")"
		local legacyProfile = BetterClickCastingDB.charProfiles[legacyKey]
		if type(legacyProfile) == "table" then
			if type(BetterClickCastingDB.charProfiles[charKey]) ~= "table" then
				BetterClickCastingDB.charProfiles[charKey] = legacyProfile
			end
			BetterClickCastingDB.charProfiles[legacyKey] = nil
		end
	end

	local profile = BetterClickCastingDB.charProfiles[charKey]
	if type(profile) ~= "table" then
		profile = {
			key = charKey,
			name = fullName,
			realm = (GetRealmName and GetRealmName()) or "",
			useCharSettings = false,
			settings = {},
			bindings = {},
			rankRules = {},
		}
		BetterClickCastingDB.charProfiles[charKey] = profile
	end
	profile.key = charKey
	profile.name = fullName
	profile.realm = (GetRealmName and GetRealmName()) or profile.realm or ""
	local className, classFile = Constants.GetPlayerClassInfo()
	if className ~= "" then
		profile.className = className
	end
	if classFile ~= "" then
		profile.classFile = classFile
	end
	if type(profile.settings) ~= "table" then
		profile.settings = {}
	end
	if type(profile.bindings) ~= "table" then
		profile.bindings = {}
	end
	if type(profile.rankRules) ~= "table" then
		profile.rankRules = {}
	end
	return profile, charKey
end

function Database.IsUsingCharSettings()
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	local charKey = Constants.GetPlayerProfileKey()
	local profile = BetterClickCastingDB.charProfiles and BetterClickCastingDB.charProfiles[charKey]
	return (profile and profile.useCharSettings == true) or false
end

function Database.SetUsingCharSettings(enabled)
	local profile = Database.GetCurrentCharProfile()
	local newVal = (enabled == true)
	if newVal and not profile.useCharSettings then
		-- Aktuelle effektive Einstellungen als Startbasis in das Charakter-Profil übernehmen
		for k, defaultVal in pairs(DEFAULTS) do
			if profile.settings[k] == nil then
				local globalVal = BetterClickCastingDB[k]
				profile.settings[k] = (globalVal ~= nil) and globalVal or defaultVal
			end
		end
		for _, posKey in ipairs(POSITION_KEYS) do
			if profile.settings[posKey] == nil and type(BetterClickCastingDB[posKey]) == "table" then
				profile.settings[posKey] = CopyTableShallow(BetterClickCastingDB[posKey])
			end
		end
	end
	profile.useCharSettings = newVal
	Database.SaveCharacterSnapshot()
	Database.NotifyAllChanged()
end

function Database.Get(key)
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	if Database.IsUsingCharSettings() then
		local profile = Database.GetCurrentCharProfile()
		if profile and profile.settings and profile.settings[key] ~= nil then
			return profile.settings[key]
		end
	end
	local val = BetterClickCastingDB[key]
	if val == nil then
		return DEFAULTS[key]
	end
	return val
end

function Database.Set(key, value)
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
	end
	local profile = Database.GetCurrentCharProfile()
	if profile and profile.useCharSettings then
		profile.settings[key] = value
	else
		BetterClickCastingDB[key] = value
		if profile and profile.settings then
			profile.settings[key] = value
		end
	end
	Database.NotifyChanged(key, value)
end

function Database.Toggle(key)
	local newVal = not Database.Get(key)
	Database.Set(key, newVal)
	return newVal
end

-- Exportiert alle Einstellungen des aktuellen Charakters als flache Tabelle
function Database.CaptureSettingsSnapshot()
	local snap = {}
	for k in pairs(DEFAULTS) do
		if k ~= "importMergeBindings" then
			snap[k] = Database.Get(k)
		end
	end
	for _, posKey in ipairs(POSITION_KEYS) do
		local pos = Database.Get(posKey)
		if type(pos) == "table" then
			snap[posKey] = CopyTableShallow(pos)
		end
	end
	return snap
end

-- Wendet ein Einstellungen-Snapshot auf das aktive Profil (Charakter oder Global) an
function Database.ApplySettingsSnapshot(snap)
	if type(snap) ~= "table" then
		return 0
	end
	local count = 0
	local profile = Database.GetCurrentCharProfile()
	local targetTable = (profile and profile.useCharSettings) and profile.settings or BetterClickCastingDB

	for k, defaultVal in pairs(DEFAULTS) do
		if k ~= "importMergeBindings" and snap[k] ~= nil and type(snap[k]) == type(defaultVal) then
			targetTable[k] = snap[k]
			if profile and profile.settings then
				profile.settings[k] = snap[k]
			end
			count = count + 1
		end
	end
	for _, posKey in ipairs(POSITION_KEYS) do
		if type(snap[posKey]) == "table" then
			local posCopy = CopyTableShallow(snap[posKey])
			targetTable[posKey] = posCopy
			BetterClickCastingDB[posKey] = posCopy
			if profile and profile.settings then
				profile.settings[posKey] = CopyTableShallow(snap[posKey])
			end
		end
	end
	Database.SaveCharacterSnapshot()
	Database.NotifyAllChanged()
	return count
end

-- Erstellt einen portablen Snapshot der aktuellen Klickbelegungen inkl. Zaubernamen, Rängen, Regeln und Makronamen
function Database.CaptureBindingsSnapshot()
	local result = {}
	if not C_ClickBindings or not C_ClickBindings.GetProfileInfo then
		return result
	end
	local profileInfo = C_ClickBindings.GetProfileInfo()
	if type(profileInfo) ~= "table" then
		return result
	end

	local SpellRanks = ns.SpellRanks
	if SpellRanks and SpellRanks.EnsureCache then
		SpellRanks.EnsureCache()
	end

	for _, info in ipairs(profileInfo) do
		if info and info.type and info.button then
			local entry = {
				type = tonumber(info.type) or 0,
				actionID = tonumber(info.actionID) or 0,
				button = tostring(info.button),
				modifiers = tonumber(info.modifiers) or 0,
			}
			if Constants.IsSpellOrPetBinding(info) and SpellRanks then
				local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
				entry.spellName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(info.actionID) or ""
				entry.subName = (rankEntry and rankEntry.subName) or SpellRanks.GetSpellSubtextForAction(info.actionID) or ""
				entry.rankNum = (rankEntry and rankEntry.rankNum) or SpellRanks.ExtractRankNumber(entry.subName) or 0
				if rankEntry then
					entry.ruleMode = SpellRanks.GetRuleForBinding(info, rankEntry)
				end
			elseif info.type == (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Macro or 2) then
				if GetMacroInfo and info.actionID then
					local macroName = GetMacroInfo(info.actionID)
					if macroName and macroName ~= "" then
						entry.macroName = macroName
					end
				end
			end
			table.insert(result, entry)
		end
	end
	return result
end

-- Aktualisiert den gespeicherten Snapshot des aktuellen Charakters in BetterClickCastingDB.charProfiles
function Database.SaveCharacterSnapshot()
	local profile = Database.GetCurrentCharProfile()
	if not profile then
		return
	end
	profile.updatedAt = (time and time()) or 0
	for k in pairs(DEFAULTS) do
		if k ~= "importMergeBindings" then
			profile.settings[k] = Database.Get(k)
		end
	end
	for _, posKey in ipairs(POSITION_KEYS) do
		local pos = Database.Get(posKey)
		if type(pos) == "table" then
			profile.settings[posKey] = CopyTableShallow(pos)
		end
	end
	local bindings = Database.CaptureBindingsSnapshot()
	if #bindings > 0 or (C_ClickBindings and C_ClickBindings.GetProfileInfo) then
		profile.bindings = bindings
	end
	if type(BetterClickCastingDB.rankRules) == "table" then
		profile.rankRules = CopyTableShallow(BetterClickCastingDB.rankRules) or {}
	end
	return profile
end

-- Liefert eine sortierte Liste aller gespeicherten Charakter-Profile (aktueller Charakter zuerst, danach alphabetisch)
function Database.GetSavedCharProfiles()
	if type(BetterClickCastingDB) ~= "table" or type(BetterClickCastingDB.charProfiles) ~= "table" then
		Database.Init()
	end
	local currentKey = Constants.GetPlayerProfileKey()
	local list = {}
	for key, prof in pairs(BetterClickCastingDB.charProfiles) do
		if type(prof) == "table" and prof.name and prof.name ~= "" then
			prof.key = key
			table.insert(list, prof)
		end
	end
	table.sort(list, function(a, b)
		if (a.key == currentKey) ~= (b.key == currentKey) then
			return a.key == currentKey
		end
		return tostring(a.name or a.key) < tostring(b.name or b.key)
	end)
	return list, currentKey
end

function Database.DeleteCharProfile(charKey)
	if type(BetterClickCastingDB) ~= "table" or type(BetterClickCastingDB.charProfiles) ~= "table" then
		return false
	end
	local currentKey = Constants.GetPlayerProfileKey()
	if not charKey or charKey == currentKey or not BetterClickCastingDB.charProfiles[charKey] then
		return false
	end
	BetterClickCastingDB.charProfiles[charKey] = nil
	return true
end

-- Findet ein gespeichertes Charakter-Profil anhand von Schlüssel oder (Vor- und Nach-)Namen
function Database.FindCharProfile(query)
	if type(query) ~= "string" then
		return nil
	end
	local trimmed = string.match(query, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end
	local lowerQuery = string.lower(trimmed)
	local lowerSpaced = string.gsub(lowerQuery, "%-", " ")
	local profiles = Database.GetSavedCharProfiles()

	for _, prof in ipairs(profiles) do
		local keyLower = string.lower(prof.key or "")
		local nameLower = string.lower(prof.name or "")
		if keyLower == lowerQuery or nameLower == lowerQuery or nameLower == lowerSpaced then
			return prof
		end
	end
	for _, prof in ipairs(profiles) do
		local keyLower = string.lower(prof.key or "")
		local nameLower = string.lower(prof.name or "")
		if string.find(nameLower, lowerSpaced, 1, true) or string.find(keyLower, lowerQuery, 1, true) then
			return prof
		end
	end
	return nil
end

-- Sichere URL-Hex-Kodierung für Sonderzeichen in Export-Strings (ohne loadstring)
local function EscapeToken(str)
	if str == nil then
		return ""
	end
	return (string.gsub(tostring(str), "([^%w%._%-])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function UnescapeToken(str)
	if type(str) ~= "string" or str == "" then
		return ""
	end
	return (string.gsub(str, "%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) or 32)
	end))
end

-- Erzeugt einen kompakten, teilbaren Export-String für "all", "bindings" oder "settings"
function Database.ExportToString(scope)
	scope = (scope == "bindings" or scope == "settings") and scope or "all"
	Database.SaveCharacterSnapshot()

	local playerName = Constants.GetPlayerDisplayName()
	local _, classFile = Constants.GetPlayerClassInfo()
	local chunks = {
		string.format("!BCC1:%s:v=%s,n=%s,c=%s", scope, EscapeToken(Constants.VERSION), EscapeToken(playerName), EscapeToken(classFile)),
	}

	if scope == "all" or scope == "settings" then
		local snap = Database.CaptureSettingsSnapshot()
		local sParts = {}
		local keys = {}
		for k in pairs(DEFAULTS) do
			if k ~= "importMergeBindings" then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = snap[k]
			local t = type(v)
			if t == "boolean" then
				table.insert(sParts, k .. "=b:" .. (v and "1" or "0"))
			elseif t == "number" then
				table.insert(sParts, k .. "=n:" .. tostring(v))
			elseif t == "string" then
				table.insert(sParts, k .. "=s:" .. EscapeToken(v))
			end
		end
		for _, posKey in ipairs(POSITION_KEYS) do
			local pos = snap[posKey]
			if type(pos) == "table" and pos.point and pos.x and pos.y then
				local posStr = string.format("%s,%s,%.1f,%.1f", tostring(pos.point), tostring(pos.relativePoint or pos.point), tonumber(pos.x) or 0, tonumber(pos.y) or 0)
				table.insert(sParts, posKey .. "=p:" .. EscapeToken(posStr))
			end
		end
		table.insert(chunks, "S:" .. table.concat(sParts, ","))
	end

	if scope == "all" or scope == "bindings" then
		local bindings = Database.CaptureBindingsSnapshot()
		local bParts = {}
		for _, b in ipairs(bindings) do
			local item = string.format(
				"%d,%d,%s,%d,%s,%s,%d,%s,%s",
				tonumber(b.type) or 0,
				tonumber(b.actionID) or 0,
				EscapeToken(b.button or ""),
				tonumber(b.modifiers) or 0,
				EscapeToken(b.spellName or ""),
				EscapeToken(b.subName or ""),
				tonumber(b.rankNum) or 0,
				EscapeToken(b.ruleMode or ""),
				EscapeToken(b.macroName or "")
			)
			table.insert(bParts, item)
		end
		table.insert(chunks, "B:" .. table.concat(bParts, "|"))
	end

	return table.concat(chunks, ";") .. "!"
end

-- Parst einen !BCC1:...!-Export-String sicher ohne loadstring
function Database.ParseImportString(rawStr)
	if type(rawStr) ~= "string" then
		return nil, "INVALID"
	end
	local trimmed = string.match(rawStr, "!BCC1:(.-)!")
	if not trimmed or trimmed == "" then
		return nil, "INVALID"
	end

	local sections = {}
	for part in string.gmatch(trimmed, "([^;]+)") do
		table.insert(sections, part)
	end
	if #sections < 1 then
		return nil, "INVALID"
	end

	local header = sections[1]
	local scope, metaStr = string.match(header, "^(%a+):(.*)$")
	if not scope then
		return nil, "INVALID"
	end

	local parsed = {
		scope = scope,
		meta = {},
		settings = nil,
		bindings = nil,
	}

	if metaStr and metaStr ~= "" then
		for kv in string.gmatch(metaStr, "([^,]+)") do
			local k, v = string.match(kv, "^([^=]+)=(.*)$")
			if k and v then
				parsed.meta[k] = UnescapeToken(v)
			end
		end
	end

	for i = 2, #sections do
		local sec = sections[i]
		local prefix = string.sub(sec, 1, 2)
		local body = string.sub(sec, 3)

		if prefix == "S:" then
			parsed.settings = {}
			for kv in string.gmatch(body, "([^,]+)") do
				local k, t, val = string.match(kv, "^([^=]+)=(%a):(.*)$")
				if k and t and val ~= nil then
					if t == "b" then
						parsed.settings[k] = (val == "1")
					elseif t == "n" then
						parsed.settings[k] = tonumber(val)
					elseif t == "s" then
						parsed.settings[k] = UnescapeToken(val)
					elseif t == "p" then
						local unescaped = UnescapeToken(val)
						local pt, relPt, xStr, yStr = string.match(unescaped, "^([^,]+),([^,]+),([^,]+),([^,]+)$")
						if pt and xStr and yStr then
							parsed.settings[k] = {
								point = pt,
								relativePoint = relPt or pt,
								x = tonumber(xStr) or 0,
								y = tonumber(yStr) or 0,
							}
						end
					end
				end
			end
		elseif prefix == "B:" then
			parsed.bindings = {}
			if body ~= "" then
				for item in string.gmatch(body, "([^|]+)") do
					local fields = {}
					local startIdx = 1
					while true do
						local commaIdx = string.find(item, ",", startIdx, true)
						if commaIdx then
							table.insert(fields, string.sub(item, startIdx, commaIdx - 1))
							startIdx = commaIdx + 1
						else
							table.insert(fields, string.sub(item, startIdx))
							break
						end
					end
					if #fields >= 4 then
						local bType = tonumber(fields[1]) or 0
						local actionID = tonumber(fields[2]) or 0
						local button = UnescapeToken(fields[3] or "")
						local modifiers = tonumber(fields[4]) or 0
						if bType > 0 and button ~= "" then
							table.insert(parsed.bindings, {
								type = bType,
								actionID = actionID,
								button = button,
								modifiers = modifiers,
								spellName = UnescapeToken(fields[5] or ""),
								subName = UnescapeToken(fields[6] or ""),
								rankNum = tonumber(fields[7]) or 0,
								ruleMode = UnescapeToken(fields[8] or ""),
								macroName = UnescapeToken(fields[9] or ""),
							})
						end
					end
				end
			end
		end
	end

	if not parsed.settings and not parsed.bindings then
		return nil, "EMPTY"
	end
	return parsed, nil
end

function Database.NotifyAllChanged()
	if ns.ApplyLocale then
		ns.ApplyLocale(Database.Get("addonLocale"))
	end
	if ns.ClickBindingUI then
		if ns.ClickBindingUI.SyncAutoShowAllRanks then
			ns.ClickBindingUI.SyncAutoShowAllRanks()
		end
		if ns.ClickBindingUI.RebuildGroups then
			ns.ClickBindingUI.RebuildGroups()
		end
		if ns.ClickBindingUI.ScheduleSmartRuleCheck then
			ns.ClickBindingUI.ScheduleSmartRuleCheck(0.1)
		end
		if ns.ClickBindingUI.RefreshVisibleLines then
			ns.ClickBindingUI.RefreshVisibleLines()
		end
	end
	if ns.SpellBookUI then
		if ns.SpellBookUI.UpdateQuickBindCheckbox then
			ns.SpellBookUI.UpdateQuickBindCheckbox()
		end
		if ns.SpellBookUI.RefreshBadges then
			ns.SpellBookUI.RefreshBadges()
		end
	end
	if ns.MinimapButton and ns.MinimapButton.UpdateVisibility then
		ns.MinimapButton.UpdateVisibility()
	end
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.OnSettingChanged then
		ns.UnitHoverTooltip.OnSettingChanged("unitHoverMode", Database.Get("unitHoverMode"))
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
end

function Database.NotifyChanged(key, value)
	if key == "addonLocale" and ns.ApplyLocale then
		ns.ApplyLocale(value)
	end
	if ns.ClickBindingUI then
		if key == "autoShowAllRanks" and ns.ClickBindingUI.SyncAutoShowAllRanks then
			ns.ClickBindingUI.SyncAutoShowAllRanks()
		end
		if (key == "groupingMode" or key == "moveInteractionsToBottom" or key == "addonLocale") and ns.ClickBindingUI.RebuildGroups then
			ns.ClickBindingUI.RebuildGroups()
		end
		if (key == "enableSmartRankRules" or key == "trainerUpgradeBehavior" or key == "addonLocale") and ns.ClickBindingUI.ScheduleSmartRuleCheck then
			ns.ClickBindingUI.ScheduleSmartRuleCheck(0.1)
		end
		if ns.ClickBindingUI.RefreshVisibleLines then
			ns.ClickBindingUI.RefreshVisibleLines()
		end
	end
	if ns.SpellBookUI then
		if key == "addonLocale" and ns.SpellBookUI.UpdateQuickBindCheckbox then
			ns.SpellBookUI.UpdateQuickBindCheckbox()
		end
		if ns.SpellBookUI.RefreshBadges then
			ns.SpellBookUI.RefreshBadges()
		end
	end
	if ns.MinimapButton and ns.MinimapButton.UpdateVisibility then
		ns.MinimapButton.UpdateVisibility()
	end
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.OnSettingChanged then
		ns.UnitHoverTooltip.OnSettingChanged(key, value)
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
end
