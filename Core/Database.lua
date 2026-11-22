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
	compactListMode = true,
	matrixShowCombos = false,
	matrixAutoOpen = false,
	matrixMetaMode = "auto", -- "auto", "on", "off"
	matrixDefaultRows = "1;2;3;4;5", -- Semikolon-separierte modOrder-IDs der in der Standard-Matrix sichtbaren Zeilen
	customButtonOrder = "LeftButton;RightButton;MiddleButton;Button4;Button5", -- Sortierreihenfolge der Maustasten für Matrix & Hover-Overlay
	matrixVisibleButtons = "LeftButton;RightButton;MiddleButton;Button4;Button5", -- In der Matrix als Spalte sichtbare Maustasten
	customModifierOrder = "1;2;3;4;5;6;7;8;9;10;11;12;13;14;15", -- Zeilen-Reihenfolge der Modifier in der Matrix
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
	unitHoverShowRange = true,
	unitHoverShowInCombat = false,
	unitHoverShowInteractions = false,
	unitHoverHiddenCombos = "", -- Pipe-separierte Liste ausgeblendeter "modifiers:button"-Kombos im Hover-Overlay
	showMinimapButton = true,
	minimapAngle = 225,
	addonLocale = "auto", -- "auto", "enUS", "deDE", "esES"
	importMergeBindings = false, -- false = Ersetzen (Standard), true = Zusammenführen
}

local POSITION_KEYS = {
	"heroCardPos",
	"unitHoverPos",
	"matrixWindowPos",
	"settingsWindowPos",
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
	if type(profile.presets) ~= "table" then
		profile.presets = {}
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
function Database.CaptureBindingsSnapshot(preferDataProvider)
	local result = {}
	local profileInfo = nil

	if preferDataProvider and ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingFrame.dataProvider then
		profileInfo = {}
		for _, element in ClickBindingFrame.dataProvider:Enumerate() do
			if element and not element.unbound and element.bindingInfo and element.bindingInfo.button then
				table.insert(profileInfo, element.bindingInfo)
			end
		end
	elseif C_ClickBindings and C_ClickBindings.GetProfileInfo then
		profileInfo = C_ClickBindings.GetProfileInfo()
	end

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

--------------------------------------------------------------------------------
-- Charakter-spezifische Binding-Presets (Loadouts)
--------------------------------------------------------------------------------

function Database.GetPresets()
	local profile = Database.GetCurrentCharProfile()
	local list = {}
	if not profile or type(profile.presets) ~= "table" then
		return list, nil
	end
	for key, preset in pairs(profile.presets) do
		if type(preset) == "table" then
			preset.name = (type(preset.name) == "string" and preset.name ~= "") and preset.name or tostring(key)
			if type(preset.bindings) ~= "table" then
				preset.bindings = {}
			end
			table.insert(list, preset)
		end
	end
	table.sort(list, function(a, b)
		return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
	end)
	local activeName = profile.activePreset
	if activeName and not profile.presets[activeName] then
		activeName = nil
		profile.activePreset = nil
	end
	return list, activeName
end

function Database.GetActivePresetName()
	local _, activeName = Database.GetPresets()
	return activeName
end

--------------------------------------------------------------------------------
-- Matrix Default-Visible Zeilen (#9A) & Ausgeblendete Hover-Overlay-Binds (#8C)
--------------------------------------------------------------------------------

local function ParseMatrixDefaultRowSet()
	local raw = Database.Get("matrixDefaultRows")
	if type(raw) ~= "string" or raw == "" then
		raw = DEFAULTS.matrixDefaultRows
	end
	local set = {}
	local count = 0
	for token in string.gmatch(raw, "(%d+)") do
		local id = tonumber(token)
		if id and id >= 1 and id <= 16 and not set[id] then
			set[id] = true
			count = count + 1
		end
	end
	if count == 0 then
		set[1] = true
	end
	return set
end

function Database.IsMatrixRowDefaultVisible(modOrder)
	local id = tonumber(modOrder)
	if not id then
		return false
	end
	local set = ParseMatrixDefaultRowSet()
	return set[id] and true or false
end

function Database.SetMatrixRowDefaultVisible(modOrder, isVisible)
	local id = tonumber(modOrder)
	if not id or id < 1 or id > 16 then
		return
	end
	local set = ParseMatrixDefaultRowSet()
	if isVisible then
		set[id] = true
	else
		set[id] = nil
	end
	local ordered = {}
	for i = 1, 16 do
		if set[i] then
			table.insert(ordered, tostring(i))
		end
	end
	-- Mindestens eine Zeile (Direct = 1) muss für die Standard-Matrix aktiv bleiben
	if #ordered == 0 then
		table.insert(ordered, "1")
	end
	Database.Set("matrixDefaultRows", table.concat(ordered, ";"))
end

function Database.NormalizeComboKey(modifiers, button)
	if type(button) ~= "string" or button == "" then
		return nil
	end
	local normBtn = button
	if button == "Button1" then
		normBtn = "LeftButton"
	elseif button == "Button2" then
		normBtn = "RightButton"
	elseif button == "Button3" then
		normBtn = "MiddleButton"
	end
	local modNum = tonumber(modifiers) or 0
	return tostring(modNum) .. ":" .. normBtn
end

local function ParseHiddenHoverComboSet()
	local raw = Database.Get("unitHoverHiddenCombos")
	local set = {}
	if type(raw) ~= "string" or raw == "" then
		return set
	end
	for token in string.gmatch(raw, "([^|;]+)") do
		if token ~= "" then
			set[token] = true
		end
	end
	return set
end

local function SaveHiddenHoverComboSet(set)
	local list = {}
	for k, v in pairs(set) do
		if v and type(k) == "string" and k ~= "" then
			table.insert(list, k)
		end
	end
	table.sort(list)
	Database.Set("unitHoverHiddenCombos", table.concat(list, "|"))
end

local function IsInteractionBindingInfo(bindingInfo)
	if type(bindingInfo) ~= "table" then
		return false
	end
	local interactionType = (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Interaction) or 3
	return bindingInfo.type == interactionType
end

function Database.IsBindingHiddenInHover(bindingInfo)
	if type(bindingInfo) ~= "table" or not bindingInfo.button then
		return false
	end
	local set = ParseHiddenHoverComboSet()
	if IsInteractionBindingInfo(bindingInfo) then
		local showKey = "+I:" .. tostring(tonumber(bindingInfo.actionID) or 0)
		return not set[showKey]
	end
	local key = Database.NormalizeComboKey(bindingInfo.modifiers, bindingInfo.button)
	if not key then
		return false
	end
	return set[key] and true or false
end

function Database.SetBindingHiddenInHover(bindingInfo, isHidden)
	if type(bindingInfo) ~= "table" or not bindingInfo.button then
		return
	end
	local set = ParseHiddenHoverComboSet()
	if IsInteractionBindingInfo(bindingInfo) then
		local showKey = "+I:" .. tostring(tonumber(bindingInfo.actionID) or 0)
		if isHidden then
			set[showKey] = nil
		else
			set[showKey] = true
		end
		SaveHiddenHoverComboSet(set)
		return
	end
	local key = Database.NormalizeComboKey(bindingInfo.modifiers, bindingInfo.button)
	if not key then
		return
	end
	if isHidden then
		set[key] = true
	else
		set[key] = nil
	end
	SaveHiddenHoverComboSet(set)
end

function Database.ToggleBindingHiddenInHover(bindingInfo)
	local isNowHidden = not Database.IsBindingHiddenInHover(bindingInfo)
	Database.SetBindingHiddenInHover(bindingInfo, isNowHidden)
	return isNowHidden
end

--------------------------------------------------------------------------------
-- Benutzerdefinierte Maustasten- & Modifier-Reihenfolge (Option 7A, inkl. MMO-Mäuse MB6..MB31)
--------------------------------------------------------------------------------

local BASE_MOUSE_BUTTONS = {
	"LeftButton",
	"RightButton",
	"MiddleButton",
	"Button4",
	"Button5",
}

local function IsValidMouseButtonToken(token)
	if token == "LeftButton" or token == "RightButton" or token == "MiddleButton" then
		return true
	end
	local num = tonumber(string.match(tostring(token or ""), "^Button(%d+)$"))
	return (num ~= nil and num >= 4 and num <= 31)
end

function Database.GetOrderedMouseButtons(includeActiveBindings)
	local raw = Database.Get("customButtonOrder")
	if type(raw) ~= "string" or raw == "" then
		raw = DEFAULTS.customButtonOrder
	end
	local list = {}
	local seen = {}
	for token in string.gmatch(raw, "([^;|,]+)") do
		local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(token) or token
		if IsValidMouseButtonToken(norm) and not seen[norm] then
			seen[norm] = true
			table.insert(list, norm)
		end
	end
	for _, baseBtn in ipairs(BASE_MOUSE_BUTTONS) do
		if not seen[baseBtn] then
			seen[baseBtn] = true
			table.insert(list, baseBtn)
		end
	end
	if includeActiveBindings ~= false then
		local extraNums = {}
		local function CheckBtn(rawBtn)
			local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(rawBtn) or rawBtn
			if IsValidMouseButtonToken(norm) and not seen[norm] then
				seen[norm] = true
				local n = tonumber(string.match(norm, "^Button(%d+)$"))
				if n then
					table.insert(extraNums, n)
				else
					table.insert(list, norm)
				end
			end
		end
		if ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingFrame.dataProvider then
			for _, element in ClickBindingFrame.dataProvider:Enumerate() do
				if element and not element.unbound and element.bindingInfo and element.bindingInfo.button then
					CheckBtn(element.bindingInfo.button)
				end
			end
		elseif C_ClickBindings and C_ClickBindings.GetProfileInfo then
			local prof = C_ClickBindings.GetProfileInfo()
			if type(prof) == "table" then
				for _, info in ipairs(prof) do
					if info and info.button then
						CheckBtn(info.button)
					end
				end
			end
		end
		table.sort(extraNums)
		for _, n in ipairs(extraNums) do
			table.insert(list, "Button" .. tostring(n))
		end
	end
	return list
end

function Database.GetButtonOrderIndex(buttonName)
	local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if not norm then
		return nil
	end
	local list = Database.GetOrderedMouseButtons(false)
	for idx, btn in ipairs(list) do
		if btn == norm then
			return idx
		end
	end
	local num = tonumber(string.match(tostring(norm), "^Button(%d+)$"))
	if num then
		return 100 + num
	end
	return nil
end

function Database.SetOrderedMouseButtons(orderedList)
	if type(orderedList) ~= "table" then
		return
	end
	local clean = {}
	local seen = {}
	for _, token in ipairs(orderedList) do
		local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(token) or token
		if IsValidMouseButtonToken(norm) and not seen[norm] then
			seen[norm] = true
			table.insert(clean, norm)
		end
	end
	for _, baseBtn in ipairs(BASE_MOUSE_BUTTONS) do
		if not seen[baseBtn] then
			seen[baseBtn] = true
			table.insert(clean, baseBtn)
		end
	end
	Database.Set("customButtonOrder", table.concat(clean, ";"))
end

function Database.MoveMouseButtonInOrder(buttonName, targetIndex)
	local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if not IsValidMouseButtonToken(norm) then
		return
	end
	local list = Database.GetOrderedMouseButtons(true)
	local currentIdx = nil
	for idx, b in ipairs(list) do
		if b == norm then
			currentIdx = idx
			break
		end
	end
	if not currentIdx then
		return
	end
	targetIndex = math.max(1, math.min(#list, tonumber(targetIndex) or currentIdx))
	if targetIndex == currentIdx then
		return
	end
	table.remove(list, currentIdx)
	table.insert(list, targetIndex, norm)
	Database.SetOrderedMouseButtons(list)
end

local function ParseMatrixVisibleButtonSet()
	local raw = Database.Get("matrixVisibleButtons")
	if type(raw) ~= "string" or raw == "" then
		raw = DEFAULTS.matrixVisibleButtons
	end
	local set = {}
	local count = 0
	for token in string.gmatch(raw, "([^;|,]+)") do
		local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(token) or token
		if IsValidMouseButtonToken(norm) and not set[norm] then
			set[norm] = true
			count = count + 1
		end
	end
	if count == 0 then
		set["LeftButton"] = true
	end
	return set
end

function Database.IsMatrixButtonColumnVisible(buttonName)
	local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if not norm then
		return false
	end
	local set = ParseMatrixVisibleButtonSet()
	return set[norm] and true or false
end

function Database.SetMatrixButtonColumnVisible(buttonName, isVisible)
	local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if not IsValidMouseButtonToken(norm) then
		return
	end
	local set = ParseMatrixVisibleButtonSet()
	if isVisible then
		set[norm] = true
	else
		set[norm] = nil
	end
	local ordered = Database.GetOrderedMouseButtons(true)
	local out = {}
	local seen = {}
	for _, btn in ipairs(ordered) do
		if set[btn] and not seen[btn] then
			seen[btn] = true
			table.insert(out, btn)
		end
	end
	for btn, v in pairs(set) do
		if v and not seen[btn] then
			seen[btn] = true
			table.insert(out, btn)
		end
	end
	if #out == 0 then
		table.insert(out, "LeftButton")
	end
	Database.Set("matrixVisibleButtons", table.concat(out, ";"))
end

function Database.AddMouseButtonToOrder(buttonName, enableInMatrix)
	local norm = Constants.NormalizeMouseButtonName and Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if not IsValidMouseButtonToken(norm) then
		return
	end
	local list = Database.GetOrderedMouseButtons(true)
	local found = false
	for _, b in ipairs(list) do
		if b == norm then
			found = true
			break
		end
	end
	if not found then
		table.insert(list, norm)
	end
	Database.SetOrderedMouseButtons(list)
	if enableInMatrix ~= false then
		Database.SetMatrixButtonColumnVisible(norm, true)
	end
end

function Database.GetActiveMatrixColumns()
	local ordered = Database.GetOrderedMouseButtons(true)
	local visibleSet = ParseMatrixVisibleButtonSet()
	local cols = {}
	for _, btn in ipairs(ordered) do
		if visibleSet[btn] then
			table.insert(cols, {
				button = btn,
				short = (Constants.GetShortButtonName and Constants.GetShortButtonName(btn)) or btn,
			})
		end
	end
	if #cols == 0 then
		table.insert(cols, { button = "LeftButton", short = "LMB" })
	end
	return cols
end

function Database.GetOrderedModifierIDs()
	local raw = Database.Get("customModifierOrder")
	if type(raw) ~= "string" or raw == "" then
		raw = DEFAULTS.customModifierOrder
	end
	local list = {}
	local seen = {}
	for token in string.gmatch(raw, "(%d+)") do
		local id = tonumber(token)
		if id and id >= 1 and id <= 15 and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for id = 1, 15 do
		if not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	return list
end

function Database.SetOrderedModifierIDs(idList)
	if type(idList) ~= "table" then
		return
	end
	local clean = {}
	local seen = {}
	for _, rawID in ipairs(idList) do
		local id = tonumber(rawID)
		if id and id >= 1 and id <= 15 and not seen[id] then
			seen[id] = true
			table.insert(clean, tostring(id))
		end
	end
	for id = 1, 15 do
		if not seen[id] then
			seen[id] = true
			table.insert(clean, tostring(id))
		end
	end
	Database.Set("customModifierOrder", table.concat(clean, ";"))
end

function Database.MoveModifierInOrder(modOrder, targetIndex)
	local id = tonumber(modOrder)
	if not id or id < 1 or id > 15 then
		return
	end
	local list = Database.GetOrderedModifierIDs()
	local currentIdx = nil
	for idx, m in ipairs(list) do
		if m == id then
			currentIdx = idx
			break
		end
	end
	if not currentIdx then
		return
	end
	targetIndex = math.max(1, math.min(#list, tonumber(targetIndex) or currentIdx))
	if targetIndex == currentIdx then
		return
	end
	table.remove(list, currentIdx)
	table.insert(list, targetIndex, id)
	Database.SetOrderedModifierIDs(list)
end

function Database.ApplyMiddleMouseCenterOrder()
	local list = Database.GetOrderedMouseButtons(true)
	local rest = {}
	for _, b in ipairs(list) do
		if b ~= "LeftButton" and b ~= "MiddleButton" and b ~= "RightButton" then
			table.insert(rest, b)
		end
	end
	local newOrder = { "LeftButton", "MiddleButton", "RightButton" }
	for _, b in ipairs(rest) do
		table.insert(newOrder, b)
	end
	Database.SetOrderedMouseButtons(newOrder)
end

function Database.ResetButtonAndModifierOrder()
	Database.Set("customButtonOrder", DEFAULTS.customButtonOrder)
	Database.Set("matrixVisibleButtons", DEFAULTS.matrixVisibleButtons)
	Database.Set("customModifierOrder", DEFAULTS.customModifierOrder)
end

function Database.SetActivePresetName(name)
	local profile = Database.GetCurrentCharProfile()
	if not profile then
		return
	end
	if type(name) == "string" and name ~= "" and profile.presets and profile.presets[name] then
		profile.activePreset = name
	else
		profile.activePreset = nil
	end
end

function Database.FindPreset(query)
	if type(query) ~= "string" then
		return nil
	end
	local trimmed = string.match(query, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end
	local lowerQuery = string.lower(trimmed)
	local presets = Database.GetPresets()
	for _, preset in ipairs(presets) do
		if string.lower(preset.name or "") == lowerQuery then
			return preset
		end
	end
	for _, preset in ipairs(presets) do
		if string.find(string.lower(preset.name or ""), lowerQuery, 1, true) then
			return preset
		end
	end
	return nil
end

function Database.SavePreset(rawName)
	if type(rawName) ~= "string" then
		return nil, 0
	end
	local cleanName = string.match(rawName, "^%s*(.-)%s*$") or ""
	if cleanName == "" then
		return nil, 0
	end

	local profile = Database.GetCurrentCharProfile()
	if not profile then
		return nil, 0
	end

	-- Falls bereits ein Preset mit identischem Namen (unabhängig von Groß-/Kleinschreibung) existiert, dessen Schlüssel aktualisieren
	local lowerTarget = string.lower(cleanName)
	local prevSpec1 = false
	local prevSpec2 = false
	for existingKey, existingPreset in pairs(profile.presets) do
		if string.lower(tostring(existingKey)) == lowerTarget or (type(existingPreset) == "table" and string.lower(tostring(existingPreset.name or "")) == lowerTarget) then
			if type(existingPreset) == "table" then
				prevSpec1 = existingPreset.spec1 and true or false
				prevSpec2 = existingPreset.spec2 and true or false
			end
			if existingKey ~= cleanName then
				profile.presets[existingKey] = nil
			end
			break
		end
	end

	local bindings = Database.CaptureBindingsSnapshot(true)
	local preset = {
		name = cleanName,
		updatedAt = (time and time()) or 0,
		bindings = bindings,
		spec1 = prevSpec1,
		spec2 = prevSpec2,
	}
	profile.presets[cleanName] = preset
	profile.activePreset = cleanName
	Database.SaveCharacterSnapshot()
	if ns.ClickBindingUI and ns.ClickBindingUI.UpdatePresetDropdownButton then
		ns.ClickBindingUI.UpdatePresetDropdownButton()
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
	return preset, #bindings
end

function Database.DeletePreset(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local profile = Database.GetCurrentCharProfile()
	if not profile or type(profile.presets) ~= "table" then
		return false
	end
	local targetPreset = Database.FindPreset(name)
	local keyToDelete = (targetPreset and targetPreset.name) or name
	if not profile.presets[keyToDelete] then
		return false
	end
	profile.presets[keyToDelete] = nil
	if profile.activePreset == keyToDelete then
		profile.activePreset = nil
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.UpdatePresetDropdownButton then
		ns.ClickBindingUI.UpdatePresetDropdownButton()
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
	return true, keyToDelete
end

-- Verknüpft ein Charakter-Preset optional mit einer Dual-Spec-Gruppe (1 = Primary Spec, 2 = Secondary Spec)
function Database.SetPresetSpecAssignment(presetName, specIndex, enabled)
	specIndex = tonumber(specIndex)
	if (specIndex ~= 1 and specIndex ~= 2) or type(presetName) ~= "string" or presetName == "" then
		return false
	end
	local profile = Database.GetCurrentCharProfile()
	if not profile or type(profile.presets) ~= "table" then
		return false
	end
	local targetPreset = Database.FindPreset(presetName)
	if not targetPreset then
		return false
	end
	local field = (specIndex == 2) and "spec2" or "spec1"
	if enabled then
		for _, p in pairs(profile.presets) do
			if type(p) == "table" then
				p[field] = (p == targetPreset)
			end
		end
	else
		targetPreset[field] = false
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.UpdatePresetDropdownButton then
		ns.ClickBindingUI.UpdatePresetDropdownButton()
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
	return true
end

function Database.GetPresetForSpecGroup(specIndex)
	specIndex = tonumber(specIndex) or ((Constants.GetActiveSpecGroupIndex and Constants.GetActiveSpecGroupIndex()) or 1)
	local field = (specIndex == 2) and "spec2" or "spec1"
	local presets = Database.GetPresets()
	for _, p in ipairs(presets) do
		if type(p) == "table" and p[field] then
			return p
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
	if Constants.IsGamepadUIActive() then
		if ns.ClickBindingUI and ns.ClickBindingUI.UpdateGamepadStandbyState then
			ns.ClickBindingUI.UpdateGamepadStandbyState()
		end
		return
	end
	if ns.ClickBindingUI then
		if ns.ClickBindingUI.SyncAutoShowAllRanks then
			ns.ClickBindingUI.SyncAutoShowAllRanks()
		end
		if ns.ClickBindingUI.ApplyScrollBoxLayout then
			ns.ClickBindingUI.ApplyScrollBoxLayout()
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
		if ns.ClickBindingUI.RefreshFreeKeysMatrix then
			ns.ClickBindingUI.RefreshFreeKeysMatrix()
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
	if ns.MinimapButton then
		if ns.MinimapButton.UpdateVisibility then
			ns.MinimapButton.UpdateVisibility()
		end
		if ns.MinimapButton.UpdatePosition then
			ns.MinimapButton.UpdatePosition()
		end
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
	if Constants.IsGamepadUIActive() then
		if ns.ClickBindingUI and ns.ClickBindingUI.UpdateGamepadStandbyState then
			ns.ClickBindingUI.UpdateGamepadStandbyState()
		end
		return
	end
	if ns.ClickBindingUI then
		if key == "autoShowAllRanks" and ns.ClickBindingUI.SyncAutoShowAllRanks then
			ns.ClickBindingUI.SyncAutoShowAllRanks()
		end
		if key == "compactListMode" and ns.ClickBindingUI.ApplyScrollBoxLayout then
			ns.ClickBindingUI.ApplyScrollBoxLayout()
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
		if ns.ClickBindingUI.RefreshFreeKeysMatrix then
			ns.ClickBindingUI.RefreshFreeKeysMatrix()
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
	if ns.MinimapButton then
		if ns.MinimapButton.UpdateVisibility then
			ns.MinimapButton.UpdateVisibility()
		end
		if ns.MinimapButton.UpdatePosition then
			ns.MinimapButton.UpdatePosition()
		end
	end
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.OnSettingChanged then
		ns.UnitHoverTooltip.OnSettingChanged(key, value)
	end
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
end
