local addonName, ns = ...

local Constants = {}
ns.Constants = Constants

Constants.ADDON_NAME = addonName or "BetterClickCasting"
Constants.VERSION = "0.9.1"
-- Nativer gemipmappter Blizzard-Atlas aus Blizzard_ClickBindingUI.lua
Constants.ICON_ATLAS = "clickcast-icon-mouse"

Constants.Colors = {
	RANK_MAX = "|cff99ccff",       -- Hellblau für aktuellen oder einzigen Rang
	TAG_MAX = "|cff40ff40",        -- Grün für [MAX] bei Zaubern mit mehreren Rängen
	RANK_DOWN = "|cffffb833",      -- Gold/Orange für Downranks (niedrigerer Rang als gelernt)
	WARN_UNLEARNED = "|cffff5555", -- Leuchtendes Rot für nicht gelernte Zauber (z. B. nach Talent-Respec)
	BIND_BADGE = "|cff55ff66",     -- Leuchtendes Grün für gebundene Tasten im Zauberbuch
	HEADER_SUB = "|cffffd100",     -- Warmes Gold für Untergruppen-Header
	MUTED = "|cff999999",          -- Grau für Manakosten und Zähler
	RESET = "|r",
}

-- Lokaler Spiegel von ElementDataTypes aus Blizzard_ClickBindingUI.lua
Constants.ElementDataTypes = {
	DefaultsHeader = 1,
	InteractionBinding = 2,
	CustomsHeader = 3,
	CustomsBinding = 4,
	NewSlot = 5,
}

local ShortButtonNames = {
	LeftButton = "LMB",
	Button1 = "LMB",
	RightButton = "RMB",
	Button2 = "RMB",
	MiddleButton = "MMB",
	Button3 = "MMB",
}

local ButtonSortPriority = {
	LeftButton = 1,
	Button1 = 1,
	RightButton = 2,
	Button2 = 2,
	MiddleButton = 3,
	Button3 = 3,
}

function Constants.IsSpellOrPetBinding(bindingInfo)
	if not bindingInfo or not Enum or not Enum.ClickBindingType then
		return false
	end
	return bindingInfo.type == Enum.ClickBindingType.Spell
		or bindingInfo.type == Enum.ClickBindingType.PetAction
end

function Constants.NormalizeMouseButtonName(buttonName)
	if not buttonName or type(buttonName) ~= "string" then
		return nil
	end
	if buttonName == "Button1" then
		return "LeftButton"
	elseif buttonName == "Button2" then
		return "RightButton"
	elseif buttonName == "Button3" then
		return "MiddleButton"
	end
	return buttonName
end

function Constants.GetShortButtonName(buttonName)
	if not buttonName then
		return "?"
	end
	if ShortButtonNames[buttonName] then
		return ShortButtonNames[buttonName]
	end
	local num = string.match(buttonName, "Button(%d+)")
	return num and ("MB" .. num) or buttonName
end

function Constants.GetButtonSortOrder(buttonName)
	if not buttonName then
		return 999
	end
	local norm = Constants.NormalizeMouseButtonName(buttonName) or buttonName
	if ns.Database and ns.Database.GetButtonOrderIndex then
		local customIdx = ns.Database.GetButtonOrderIndex(norm)
		if customIdx then
			return customIdx
		end
	end
	if ButtonSortPriority[norm] then
		return ButtonSortPriority[norm]
	end
	local num = string.match(norm, "Button(%d+)")
	if num then
		return tonumber(num) or 50
	end
	return 100
end

function Constants.HasMetaModifier(modifiers)
	if not modifiers then
		return false
	end
	local modStr = ""
	if type(modifiers) == "string" then
		modStr = modifiers
	elseif type(modifiers) == "number" and modifiers ~= 0 and GetStringFromModifiers then
		modStr = GetStringFromModifiers(modifiers) or ""
	end
	if modStr == "" then
		return false
	end
	local upper = string.upper(modStr)
	return (string.find(upper, "META") ~= nil) or (string.find(upper, "CMD") ~= nil)
end

function Constants.GetModifierSortInfo(modifiers)
	local modStr = ""
	if type(modifiers) == "string" then
		modStr = modifiers
	elseif type(modifiers) == "number" and modifiers ~= 0 and GetStringFromModifiers then
		modStr = GetStringFromModifiers(modifiers) or ""
	end
	if modStr == "" then
		return 1, ""
	end

	local upper = string.upper(modStr)
	local hasShift = (string.find(upper, "SHIFT") ~= nil) or (string.find(upper, "MAY") ~= nil)
	local hasCtrl = (string.find(upper, "CTRL") ~= nil) or (string.find(upper, "STRG") ~= nil)
	local hasAlt = string.find(upper, "ALT") ~= nil
	local hasMeta = (string.find(upper, "META") ~= nil) or (string.find(upper, "CMD") ~= nil)

	local count = (hasShift and 1 or 0) + (hasCtrl and 1 or 0) + (hasAlt and 1 or 0) + (hasMeta and 1 or 0)
	local order = 99
	if count == 1 then
		if hasShift then
			order = 2
		elseif hasCtrl then
			order = 3
		elseif hasAlt then
			order = 4
		elseif hasMeta then
			order = 5
		end
	elseif count == 2 then
		if hasShift and hasCtrl then
			order = 6
		elseif hasShift and hasAlt then
			order = 7
		elseif hasCtrl and hasAlt then
			order = 8
		elseif hasShift and hasMeta then
			order = 9
		elseif hasCtrl and hasMeta then
			order = 10
		elseif hasAlt and hasMeta then
			order = 11
		end
	elseif count == 3 then
		if hasShift and hasCtrl and hasAlt then
			order = 12
		elseif hasShift and hasCtrl and hasMeta then
			order = 13
		elseif hasShift and hasAlt and hasMeta then
			order = 14
		elseif hasCtrl and hasAlt and hasMeta then
			order = 15
		end
	elseif count >= 4 then
		order = 16
	end

	-- Schön formatierter Modifier-String (z. B. "SHIFT + ALT" statt "SHIFT-ALT")
	local readable = string.gsub(modStr, "%-", " + ")
	return order, readable
end

function Constants.GetShortBindingString(bindingInfo)
	if not bindingInfo or not bindingInfo.button then
		return nil
	end
	local btn = ShortButtonNames[bindingInfo.button]
	if not btn then
		local num = string.match(bindingInfo.button, "Button(%d+)")
		btn = num and ("MB" .. num) or bindingInfo.button
	end

	local modPrefix = ""
	if GetStringFromModifiers and bindingInfo.modifiers then
		local modStr = GetStringFromModifiers(bindingInfo.modifiers) or ""
		if modStr ~= "" then
			local parts = {}
			for token in string.gmatch(modStr, "([^-]+)") do
				table.insert(parts, string.sub(token, 1, 1))
			end
			if #parts > 0 then
				modPrefix = table.concat(parts, "") .. "-"
			end
		end
	end
	return modPrefix .. btn
end

function Constants.GetButtonDisplayName(buttonName)
	if not buttonName then
		return CLICK_BINDINGS_UNBOUND_TEXT or "Unbound"
	end
	if buttonName == "LeftButton" or buttonName == "Button1" then
		return LEFT_BUTTON_STRING or "Left Button"
	elseif buttonName == "RightButton" or buttonName == "Button2" then
		return RIGHT_BUTTON_STRING or "Right Button"
	elseif buttonName == "MiddleButton" or buttonName == "Button3" then
		return MIDDLE_BUTTON_STRING or "Middle Button"
	else
		local num = string.match(buttonName, "Button(%d+)")
		if num and _G["BUTTON_" .. num .. "_STRING"] then
			return _G["BUTTON_" .. num .. "_STRING"]
		end
	end
	return _G[string.upper(buttonName) .. "_BUTTON_STRING"] or buttonName
end

function Constants.GetFullBindingString(bindingInfo)
	if not bindingInfo or not bindingInfo.button then
		return CLICK_BINDINGS_UNBOUND_TEXT or "Unbound"
	end

	local buttonString = Constants.GetButtonDisplayName(bindingInfo.button)
	local modifierText = GetStringFromModifiers and GetStringFromModifiers(bindingInfo.modifiers or 0) or ""
	if modifierText ~= "" and CLICK_BINDINGS_BINDING_TEXT_FORMAT then
		return CLICK_BINDINGS_BINDING_TEXT_FORMAT:format(modifierText, buttonString)
	elseif modifierText ~= "" then
		return modifierText .. "-" .. buttonString
	end
	return buttonString
end

-- Prüft ein Namenspaar (n, s) aus einer WoW-Unit-API auf Vor- und Nachname in WoW Forever
local function TryExtractFullName(n, s, realm, normRealm)
	if type(n) ~= "string" or n == "" then
		return nil
	end
	local sep = (_G.Constants and _G.Constants.CharacterNameSeparatorConsts and _G.Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "

	-- Fall 1: Nachname wird als 2. Rückgabewert geliefert (z. B. UnitFullName("player"))
	if type(s) == "string" and s ~= "" and s ~= realm and s ~= normRealm then
		if string.find(n, s, 1, true) then
			return string.gsub(n, "%-", " ")
		end
		return n .. " " .. s
	end

	-- Fall 2: Vor- und Nachname stecken bereits mit Leerzeichen getrennt im 1. Rückgabewert (z. B. UnitName("player"))
	if string.find(n, " ", 1, true) then
		return n
	end

	-- Fall 3: Vor- und Nachname sind durch CHARACTERNAME_SURNAME_SEPARATOR getrennt
	if sep ~= " " and sep ~= "" and string.find(n, sep, 1, true) then
		local first, last = string.match(n, "^(.-)" .. sep .. "(.+)$")
		if first and last and last ~= "" and last ~= realm and last ~= normRealm then
			return first .. " " .. last
		end
	end

	-- Fall 4: Vor- und Nachname sind durch Bindestrich getrennt (sofern der 2. Teil nicht der Realm ist)
	if string.find(n, "-", 1, true) then
		local first, last = string.match(n, "^([^-]+)-(.+)$")
		if first and last and last ~= "" and last ~= realm and last ~= normRealm then
			return first .. " " .. last
		end
	end

	return nil
end

-- Liefert ausschließlich den Vornamen des Spielers (für Legacy-Profil-Migration)
function Constants.GetPlayerFirstName()
	local name = (UnitNameUnmodified and UnitNameUnmodified("player")) or (UnitName and UnitName("player"))
	if type(name) == "string" and name ~= "" then
		local first = string.match(name, "^([^%s%-]+)")
		return first or name
	end
	return "Player"
end

-- Liefert den vollständigen Spielernamen inkl. Nachname in WoW Forever (z. B. "Rage Key")
function Constants.GetPlayerDisplayName()
	local realm = (GetRealmName and GetRealmName()) or ""
	local normRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
	local fallbackFirst = nil

	local function CheckPair(n, s)
		if type(n) == "string" and n ~= "" and not fallbackFirst then
			fallbackFirst = n
		end
		return TryExtractFullName(n, s, realm, normRealm)
	end

	-- 1. UnitFullName("player") liefert auch für "player" den 2. Rückgabewert (in WoW Forever den Nachnamen)
	if UnitFullName then
		local full = CheckPair(UnitFullName("player"))
		if full then return full end
	end

	-- 2. UnitName("player") und UnitNameUnmodified("player") (Camelot NameUtil.lua)
	if UnitName then
		local full = CheckPair(UnitName("player"))
		if full then return full end
	end
	if UnitNameUnmodified then
		local full = CheckPair(UnitNameUnmodified("player"))
		if full then return full end
	end

	-- 3. GUID-basierte Abfragen (UnitNameFromGUID / GetPlayerInfoByGUID)
	local guid = UnitGUID and UnitGUID("player")
	if guid then
		if UnitNameFromGUID then
			local full = CheckPair(UnitNameFromGUID(guid))
			if full then return full end
		end
		if GetPlayerInfoByGUID then
			local _, _, _, _, _, gName, gSurname = GetPlayerInfoByGUID(guid)
			local full = CheckPair(gName, gSurname)
			if full then return full end
		end
	end

	-- 4. C_PlayerInfo.GetName(PlayerLocation:CreateFromUnit("player"))
	if C_PlayerInfo and C_PlayerInfo.GetName and PlayerLocation and PlayerLocation.CreateFromUnit then
		local ok, loc = pcall(PlayerLocation.CreateFromUnit, PlayerLocation, "player")
		if ok and loc then
			local full = CheckPair(C_PlayerInfo.GetName(loc), nil)
			if full then return full end
		end
	end

	return fallbackFirst or "Player"
end

-- Liefert einen eindeutigen Charakter-Schlüssel (inkl. Vorname, Nachname und Realm) für SavedVariables
function Constants.GetPlayerProfileKey()
	local fullName = Constants.GetPlayerDisplayName()
	local rawRealm = GetRealmName and GetRealmName() or ""
	local realm = (rawRealm ~= "" and rawRealm) or "Realm"
	return fullName .. " (" .. realm .. ")"
end

function Constants.GetPlayerClassInfo()
	if UnitClass then
		local className, classFile = UnitClass("player")
		return className or "", classFile or ""
	end
	return "", ""
end

-- Prüft mehrstufig über InputUtil, C_InputInterfaceStyle und die Engine-CVar InputDeviceInterfaceStyle,
-- ob Blizzards Controller-/Gamepad-UI-Modus aktiv ist. Im aktiven Gamepad-Modus pausiert Better Click Casting
-- alle UI-Eingriffe, damit GamepadMode.FrameControlsManager und SmartNavigation niemals getaintet werden.
function Constants.IsGamepadUIActive()
	if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
		return true
	end
	if C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType then
		if C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad then
			return true
		end
	end
	if C_CVar and C_CVar.GetCVar then
		if tonumber(C_CVar.GetCVar("InputDeviceInterfaceStyle")) == 1 then
			return true
		end
	end
	return false
end

-- Liefert den aktiven Dual-Spec-Gruppenindex (1 = Primary Spec, 2 = Secondary Spec).
-- Wichtig: C_SpecializationInfo.GetActiveSpecGroup() immer ohne Argumente aufrufen,
-- damit niemals getaintete Argumente an die C-Funktion übergeben werden.
function Constants.GetActiveSpecGroupIndex()
	if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
		local idx = tonumber(C_SpecializationInfo.GetActiveSpecGroup())
		if idx == 2 then
			return 2
		end
		return 1
	end
	if GetActiveTalentGroup then
		local idx = tonumber(GetActiveTalentGroup())
		if idx == 2 then
			return 2
		end
	end
	return 1
end
