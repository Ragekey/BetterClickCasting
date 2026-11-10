local addonName, ns = ...

local Constants = {}
ns.Constants = Constants

Constants.ADDON_NAME = addonName or "BetterClickCasting"
Constants.VERSION = "0.6.0"
-- Nativer gemipmappter Blizzard-Atlas aus Blizzard_ClickBindingUI.lua
Constants.ICON_ATLAS = "clickcast-icon-mouse"

Constants.Colors = {
	RANK_MAX = "|cff99ccff",   -- Hellblau für aktuellen oder einzigen Rang
	TAG_MAX = "|cff40ff40",    -- Grün für [MAX] bei Zaubern mit mehreren Rängen
	RANK_DOWN = "|cffffb833",  -- Gold/Orange für Downranks (niedrigerer Rang als gelernt)
	BIND_BADGE = "|cff55ff66", -- Leuchtendes Grün für gebundene Tasten im Zauberbuch
	HEADER_SUB = "|cffffd100", -- Warmes Gold für Untergruppen-Header
	MUTED = "|cff999999",      -- Grau für Manakosten und Zähler
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

function Constants.GetButtonSortOrder(buttonName)
	if not buttonName then
		return 999
	end
	if ButtonSortPriority[buttonName] then
		return ButtonSortPriority[buttonName]
	end
	local num = string.match(buttonName, "Button(%d+)")
	if num then
		return tonumber(num) or 50
	end
	return 100
end

function Constants.GetModifierSortInfo(modifiers)
	modifiers = modifiers or 0
	if modifiers == 0 or not GetStringFromModifiers then
		return 1, ""
	end
	local modStr = GetStringFromModifiers(modifiers) or ""
	if modStr == "" then
		return 1, ""
	end

	local upper = string.upper(modStr)
	local hasShift = string.find(upper, "SHIFT") ~= nil
	local hasCtrl = (string.find(upper, "CTRL") ~= nil) or (string.find(upper, "STRG") ~= nil)
	local hasAlt = string.find(upper, "ALT") ~= nil

	local count = (hasShift and 1 or 0) + (hasCtrl and 1 or 0) + (hasAlt and 1 or 0)
	local order = 9
	if count == 1 then
		if hasShift then
			order = 2
		elseif hasCtrl then
			order = 3
		elseif hasAlt then
			order = 4
		end
	elseif count == 2 then
		if hasShift and hasCtrl then
			order = 5
		elseif hasShift and hasAlt then
			order = 6
		elseif hasCtrl and hasAlt then
			order = 7
		end
	elseif count >= 3 then
		order = 8
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
