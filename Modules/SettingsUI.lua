local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Database = ns.Database
local Widgets = ns.SettingsWidgets

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local GROUP_MODES = {
	{ value = "modifier", labelKey = "GROUP_MODE_MODIFIER", shortKey = "GROUP_MODE_MODIFIER_SHORT" },
	{ value = "button",   labelKey = "GROUP_MODE_BUTTON",   shortKey = "GROUP_MODE_BUTTON_SHORT" },
	{ value = "type",     labelKey = "GROUP_MODE_TYPE",     shortKey = "GROUP_MODE_TYPE_SHORT" },
	{ value = "none",     labelKey = "GROUP_MODE_NONE",     shortKey = "GROUP_MODE_NONE_SHORT" },
}

local UNITHOVER_MODES = {
	{ value = "off",      labelKey = "UNITHOVER_MODE_OFF",      shortKey = "UNITHOVER_MODE_OFF_SHORT" },
	{ value = "modifier", labelKey = "UNITHOVER_MODE_MODIFIER", shortKey = "UNITHOVER_MODE_MODIFIER_SHORT" },
	{ value = "always",   labelKey = "UNITHOVER_MODE_ALWAYS",   shortKey = "UNITHOVER_MODE_ALWAYS_SHORT" },
}

local UNITHOVER_ANCHORS = {
	{ value = "cursor", labelKey = "UNITHOVER_ANCHOR_CURSOR", shortKey = "UNITHOVER_ANCHOR_CURSOR_SHORT" },
	{ value = "top",    labelKey = "UNITHOVER_ANCHOR_TOP",    shortKey = "UNITHOVER_ANCHOR_TOP_SHORT" },
	{ value = "bottom", labelKey = "UNITHOVER_ANCHOR_BOTTOM", shortKey = "UNITHOVER_ANCHOR_BOTTOM_SHORT" },
	{ value = "left",   labelKey = "UNITHOVER_ANCHOR_LEFT",   shortKey = "UNITHOVER_ANCHOR_LEFT_SHORT" },
	{ value = "right",  labelKey = "UNITHOVER_ANCHOR_RIGHT",  shortKey = "UNITHOVER_ANCHOR_RIGHT_SHORT" },
	{ value = "free",   labelKey = "UNITHOVER_ANCHOR_FREE",   shortKey = "UNITHOVER_ANCHOR_FREE_SHORT" },
}

local TRAINER_BEHAVIOR_OPTIONS = {
	{ value = "card", labelKey = "TRAINER_BEHAVIOR_CARD", shortKey = "TRAINER_BEHAVIOR_CARD_SHORT", descKey = "TRAINER_BEHAVIOR_CARD_DESC" },
	{ value = "auto", labelKey = "TRAINER_BEHAVIOR_AUTO", shortKey = "TRAINER_BEHAVIOR_AUTO_SHORT", descKey = "TRAINER_BEHAVIOR_AUTO_DESC" },
	{ value = "off",  labelKey = "TRAINER_BEHAVIOR_OFF",  shortKey = "TRAINER_BEHAVIOR_OFF_SHORT",  descKey = "TRAINER_BEHAVIOR_OFF_DESC" },
}

local SHARE_SCOPE_OPTIONS = {
	{ value = "all",      labelKey = "SHARE_SCOPE_ALL",      shortKey = "SHARE_SCOPE_ALL_SHORT" },
	{ value = "bindings", labelKey = "SHARE_SCOPE_BINDINGS", shortKey = "SHARE_SCOPE_BINDINGS_SHORT" },
	{ value = "settings", labelKey = "SHARE_SCOPE_SETTINGS", shortKey = "SHARE_SCOPE_SETTINGS_SHORT" },
}

local LOCALE_OPTIONS = {
	{ value = "auto", labelKey = "LOCALE_OPT_AUTO", shortKey = "LOCALE_OPT_AUTO_SHORT" },
	{ value = "enUS", labelKey = "LOCALE_OPT_ENUS", shortKey = "LOCALE_OPT_ENUS_SHORT" },
	{ value = "deDE", labelKey = "LOCALE_OPT_DEDE", shortKey = "LOCALE_OPT_DEDE_SHORT" },
	{ value = "esES", labelKey = "LOCALE_OPT_ESES", shortKey = "LOCALE_OPT_ESES_SHORT" },
}

local MATRIX_META_OPTIONS = {
	{ value = "auto", labelKey = "UX_META_AUTO", shortKey = "UX_META_AUTO" },
	{ value = "on",   labelKey = "UX_META_ON",   shortKey = "UX_META_ON" },
	{ value = "off",  labelKey = "UX_META_OFF",  shortKey = "UX_META_OFF" },
}

SettingsUI.GROUP_MODES = GROUP_MODES
SettingsUI.UNITHOVER_MODES = UNITHOVER_MODES
SettingsUI.UNITHOVER_ANCHORS = UNITHOVER_ANCHORS
SettingsUI.TRAINER_BEHAVIOR_OPTIONS = TRAINER_BEHAVIOR_OPTIONS
SettingsUI.SHARE_SCOPE_OPTIONS = SHARE_SCOPE_OPTIONS
SettingsUI.LOCALE_OPTIONS = LOCALE_OPTIONS

local NAV_SECTIONS = {
	{ index = 1, labelKey = "UX_NAV_CLICKCAST", atlas = Constants.ICON_ATLAS },
	{ index = 2, labelKey = "UX_NAV_SPELLBOOK", texture = 133741 },
	{ index = 3, labelKey = "UX_NAV_MATRIX",    texture = 134414 },
	{ index = 4, labelKey = "UX_NAV_HOVER",     atlas = "Raid-Icon-SummonPending" },
	{ index = 5, labelKey = "UX_NAV_PRESETS",   texture = 134327 },
	{ index = 6, labelKey = "UX_NAV_PROFILES",  atlas = "questlog-icon-setting" },
}
SettingsUI.NAV_COUNT = #NAV_SECTIONS

local settingsWindow = nil
local activeTabIndex = 1
local selectedSourceCharKey = nil
local selectedShareScope = "all"
local selectedPresetName = nil
local currentSearchQuery = ""
local searchCatalog = {}
local searchResultRows = {}
local presetListRows = {}

local REORDER_ROW_H = 24
local REORDER_ROW_GAP = 2

--------------------------------------------------------------------------------
-- Hilfsfunktionen & Kontextmenüs (Abwärtskompatibel für externe Module)
--------------------------------------------------------------------------------

local function GetSelectedPreset()
	local presets, activeName = Database.GetPresets()
	if selectedPresetName then
		for _, preset in ipairs(presets) do
			if preset.name == selectedPresetName then
				return preset, presets
			end
		end
	end
	if activeName then
		for _, preset in ipairs(presets) do
			if preset.name == activeName then
				selectedPresetName = preset.name
				return preset, presets
			end
		end
	end
	if presets[1] then
		selectedPresetName = presets[1].name
		return presets[1], presets
	end
	selectedPresetName = nil
	return nil, presets
end

local function FormatPresetLabel(preset)
	if not preset then
		return L["PRESET_NO_PRESETS_SAVED"] or "None"
	end
	local count = (type(preset.bindings) == "table") and #preset.bindings or 0
	local base = string.format(L["PRESET_ENTRY_FORMAT"] or "%s (%d)", preset.name or "?", count)
	local specTag = ""
	if preset.spec1 and preset.spec2 then
		specTag = " " .. (L["PRESET_SPEC_TAG_BOTH"] or "[Spec 1+2]")
	elseif preset.spec1 then
		specTag = " " .. (L["PRESET_SPEC_TAG_1"] or "[Spec 1]")
	elseif preset.spec2 then
		specTag = " " .. (L["PRESET_SPEC_TAG_2"] or "[Spec 2]")
	end
	return base .. specTag
end

local function FormatCharProfileLabel(prof, currentKey)
	if not prof then
		return L["PROFILE_NO_CHAR_SAVED"] or "None"
	end
	local nameText = prof.name or prof.key or "?"
	if prof.classFile and C_ClassColor and C_ClassColor.GetClassColor then
		local color = C_ClassColor.GetClassColor(prof.classFile)
		if color and color.WrapTextInColorCode then
			nameText = color:WrapTextInColorCode(nameText)
		end
	end
	local bindCount = (type(prof.bindings) == "table") and #prof.bindings or 0
	local activeTag = (prof.key == currentKey) and (" " .. (L["PROFILE_CURRENT_TAG"] or "(Active)")) or ""
	return string.format("%s (%d)%s", nameText, bindCount, activeTag)
end

local function GetSelectedCharProfile()
	local list, currentKey = Database.GetSavedCharProfiles()
	if selectedSourceCharKey then
		for _, prof in ipairs(list) do
			if prof.key == selectedSourceCharKey then
				return prof, currentKey
			end
		end
	end
	for _, prof in ipairs(list) do
		if prof.key ~= currentKey then
			selectedSourceCharKey = prof.key
			return prof, currentKey
		end
	end
	if list[1] then
		selectedSourceCharKey = list[1].key
		return list[1], currentKey
	end
	return nil, currentKey
end

local function GetShortLabelFromList(list, currentVal, fallbackKey)
	for _, entry in ipairs(list) do
		if entry.value == currentVal then
			return L[entry.shortKey]
		end
	end
	return L[fallbackKey]
end

function SettingsUI.GetCurrentGroupShortLabel()
	return GetShortLabelFromList(GROUP_MODES, Database.Get("groupingMode") or "modifier", "GROUP_MODE_MODIFIER_SHORT")
end

function SettingsUI.GetCurrentUnitHoverModeShortLabel()
	return GetShortLabelFromList(UNITHOVER_MODES, Database.Get("unitHoverMode") or "off", "UNITHOVER_MODE_OFF_SHORT")
end

function SettingsUI.GetCurrentUnitHoverAnchorShortLabel()
	return GetShortLabelFromList(UNITHOVER_ANCHORS, Database.Get("unitHoverAnchor") or "cursor", "UNITHOVER_ANCHOR_CURSOR_SHORT")
end

function SettingsUI.GetCurrentTrainerBehaviorShortLabel()
	return GetShortLabelFromList(TRAINER_BEHAVIOR_OPTIONS, Database.Get("trainerUpgradeBehavior") or "card", "TRAINER_BEHAVIOR_CARD_SHORT")
end

function SettingsUI.GetCurrentShareScopeShortLabel()
	return GetShortLabelFromList(SHARE_SCOPE_OPTIONS, selectedShareScope or "all", "SHARE_SCOPE_ALL_SHORT")
end

function SettingsUI.GetCurrentLocaleShortLabel()
	return GetShortLabelFromList(LOCALE_OPTIONS, Database.Get("addonLocale") or "auto", "LOCALE_OPT_AUTO_SHORT")
end

local function PopulateRadioMenu(rootDescription, titleKey, dbKey, defaultValue, list, descKey)
	rootDescription:CreateTitle(L[titleKey])
	local function IsSelected(val)
		return (Database.Get(dbKey) or defaultValue) == val
	end
	local function SetSelected(val)
		Database.Set(dbKey, val)
	end
	for _, entry in ipairs(list) do
		local radio = rootDescription:CreateRadio(L[entry.labelKey], IsSelected, SetSelected, entry.value)
		local itemDescKey = entry.descKey or descKey
		if itemDescKey and L[itemDescKey] then
			radio:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, L[entry.labelKey])
				GameTooltip_AddNormalLine(tooltip, L[itemDescKey], true)
			end)
		end
	end
end

local function PopulatePresetContextMenu(rootDescription, isQuickLoad)
	rootDescription:CreateTitle(L["PRESET_MENU_TITLE"])
	local selectedPreset, presets = GetSelectedPreset()
	local activeName = (ns.ClickBindingUI and ns.ClickBindingUI.GetEffectiveActivePresetName and ns.ClickBindingUI.GetEffectiveActivePresetName()) or Database.GetActivePresetName()

	if #presets == 0 then
		rootDescription:CreateTitle(L["PRESET_NO_PRESETS_SAVED"])
	else
		local function IsSelected(presetName)
			if isQuickLoad then
				return activeName == presetName
			end
			return selectedPreset and selectedPreset.name == presetName
		end
		local function SetSelected(presetName)
			selectedPresetName = presetName
			if isQuickLoad and ns.ClickBindingUI and ns.ClickBindingUI.LoadPreset then
				ns.ClickBindingUI.LoadPreset(presetName)
			end
			SettingsUI.RefreshWindow()
		end

		for _, preset in ipairs(presets) do
			local pName = preset.name
			local radio = rootDescription:CreateRadio(FormatPresetLabel(preset), IsSelected, SetSelected, pName)
			if radio.AddInitializer then
				radio:AddInitializer(function(button)
					if button and button.fontString then
						local livePreset = (Database.FindPreset and Database.FindPreset(pName)) or preset
						local liveLabel = FormatPresetLabel(livePreset)
						if button.fontString.SetTextToFit then
							button.fontString:SetTextToFit(liveLabel)
						else
							button.fontString:SetText(liveLabel)
						end
					end
				end)
			end
			radio:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, pName)
				GameTooltip_AddNormalLine(tooltip, L["PRESET_BTN_LOAD_DESC"], true)
			end)
		end
	end

	rootDescription:CreateDivider()
	rootDescription:CreateButton(L["PRESET_ACT_SAVE_NEW"], function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
			ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
				if saved and saved.name then
					selectedPresetName = saved.name
				end
				SettingsUI.RefreshWindow()
			end)
		end
	end)

	local targetForAction = isQuickLoad and (activeName and Database.FindPreset(activeName)) or selectedPreset
	if targetForAction and targetForAction.name then
		if rootDescription.CreateCheckbox and Database.SetPresetSpecAssignment then
			for sIdx = 1, 2 do
				local fmtKey = (sIdx == 1) and "PRESET_ACT_LINK_SPEC_1_FORMAT" or "PRESET_ACT_LINK_SPEC_2_FORMAT"
				local field = (sIdx == 1) and "spec1" or "spec2"
				rootDescription:CreateCheckbox(
					string.format(L[fmtKey], targetForAction.name),
					function() return targetForAction[field] and true or false end,
					function()
						local newVal = not (targetForAction[field] and true or false)
						Database.SetPresetSpecAssignment(targetForAction.name, sIdx, newVal)
						SettingsUI.RefreshWindow()
						if DEFAULT_CHAT_FRAME then
							local fmt = newVal and L["CHAT_PRESET_SPEC_LINKED_FORMAT"] or L["CHAT_PRESET_SPEC_UNLINKED_FORMAT"]
							DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, targetForAction.name, sIdx))
						end
					end
				)
			end
		end
		rootDescription:CreateButton(string.format(L["PRESET_ACT_UPDATE_FORMAT"], targetForAction.name), function()
			if ns.ClickBindingUI and ns.ClickBindingUI.SavePresetByName then
				ns.ClickBindingUI.SavePresetByName(targetForAction.name)
				selectedPresetName = targetForAction.name
				SettingsUI.RefreshWindow()
			end
		end)
		rootDescription:CreateButton(string.format(L["PRESET_ACT_DELETE_FORMAT"], targetForAction.name), function()
			if ns.ClickBindingUI and ns.ClickBindingUI.DeletePresetByName then
				ns.ClickBindingUI.DeletePresetByName(targetForAction.name)
				if selectedPresetName == targetForAction.name then
					selectedPresetName = nil
				end
				SettingsUI.RefreshWindow()
			end
		end)
	end

	if isQuickLoad then
		rootDescription:CreateDivider()
		rootDescription:CreateButton(L["PRESET_ACT_OPEN_MANAGER"], function()
			SettingsUI.OpenSettingsTab(5)
		end)
	end
end

function SettingsUI.OpenPresetMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			PopulatePresetContextMenu(rootDescription, true)
		end)
	end
end

function SettingsUI.OpenTab4PresetMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			PopulatePresetContextMenu(rootDescription, false)
		end)
	end
end

function SettingsUI.OpenSourceCharMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	if Database and Database.SaveCharacterSnapshot then
		Database.SaveCharacterSnapshot()
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		rootDescription:CreateTitle(L["PROFILE_SOURCE_MENU_TITLE"])
		local list, currentKey = Database.GetSavedCharProfiles()
		if #list == 0 then
			rootDescription:CreateTitle(L["PROFILE_NO_CHAR_SAVED"])
			return
		end
		local function IsSelected(key)
			local prof = GetSelectedCharProfile()
			return prof and prof.key == key
		end
		local function SetSelected(key)
			selectedSourceCharKey = key
			SettingsUI.RefreshWindow()
		end
		for _, prof in ipairs(list) do
			local radio = rootDescription:CreateRadio(FormatCharProfileLabel(prof, currentKey), IsSelected, SetSelected, prof.key)
			if prof.key ~= currentKey then
				radio:CreateButton(L["PROFILE_DELETE_SNAPSHOT"], function()
					Database.DeleteCharProfile(prof.key)
					if selectedSourceCharKey == prof.key then
						selectedSourceCharKey = nil
					end
					SettingsUI.RefreshWindow()
				end)
			end
		end
	end)
end

function SettingsUI.OpenShareScopeMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			rootDescription:CreateTitle(L["SHARE_SCOPE_MENU_TITLE"])
			for _, entry in ipairs(SHARE_SCOPE_OPTIONS) do
				rootDescription:CreateRadio(
					L[entry.labelKey],
					function(v) return (selectedShareScope or "all") == v end,
					function(v) selectedShareScope = v; SettingsUI.RefreshWindow() end,
					entry.value
				)
			end
		end)
	end
end

function SettingsUI.PopulateGroupingMenu(rootDescription)
	PopulateRadioMenu(rootDescription, "GROUP_MENU_TITLE", "groupingMode", "modifier", GROUP_MODES, "GROUP_TOOLTIP_DESC")
	if rootDescription and rootDescription.CreateDivider and rootDescription.CreateCheckbox then
		rootDescription:CreateDivider()
		local cb = rootDescription:CreateCheckbox(
			L["SETTING_COMPACT_LIST_MODE"],
			function() return Database.Get("compactListMode") and true or false end,
			function() Database.Toggle("compactListMode") end
		)
		if cb and cb.SetTooltip then
			cb:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, L["SETTING_COMPACT_LIST_MODE"])
				GameTooltip_AddNormalLine(tooltip, L["SETTING_COMPACT_LIST_MODE_DESC"], true)
			end)
		end
		if rootDescription.CreateButton then
			rootDescription:CreateButton(L["SETTINGS_FREE_KEYS_MATRIX_BTN"], function()
				if ns.ClickBindingUI and ns.ClickBindingUI.ToggleFreeKeysMatrix then
					ns.ClickBindingUI.ToggleFreeKeysMatrix()
				end
			end)
		end
	end
end

function SettingsUI.OpenGroupingMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			SettingsUI.PopulateGroupingMenu(rootDescription)
		end)
	end
end

function SettingsUI.OpenTrainerBehaviorMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			PopulateRadioMenu(rootDescription, "TRAINER_BEHAVIOR_MENU_TITLE", "trainerUpgradeBehavior", "card", TRAINER_BEHAVIOR_OPTIONS, "TRAINER_BEHAVIOR_TOOLTIP_DESC")
		end)
	end
end

function SettingsUI.OpenLocaleMenu(ownerRegion)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
			PopulateRadioMenu(rootDescription, "LOCALE_MENU_TITLE", "addonLocale", "auto", LOCALE_OPTIONS, "LOCALE_TOOLTIP_DESC")
		end)
	end
end

--------------------------------------------------------------------------------
-- Eingebetteter Drag-&-Drop Reorder-Editor (auf Seite 3: Matrix & Reihenfolge)
--------------------------------------------------------------------------------

local function GetMouseButtonDisplayLabel(buttonName)
	local norm = Constants.NormalizeMouseButtonName(buttonName)
	local short = Constants.GetShortButtonName(norm)
	local full = (Constants.GetButtonDisplayName and Constants.GetButtonDisplayName(norm)) or short
	return string.format("|cffffd100%s|r  |cffffffff%s|r", short, full)
end

local function EnsureReorderListRow(scrollChild, rowsPool, idx, isButtonList, reorderStateOwner)
	if rowsPool[idx] then
		return rowsPool[idx]
	end
	local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
	row:SetHeight(REORDER_ROW_H)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")
	Widgets.ApplyBoxBackdrop(row, { 0.11, 0.14, 0.20, 0.92 }, { 0.32, 0.42, 0.58, 0.85 }, false)

	local handleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	handleText:SetPoint("LEFT", row, "LEFT", 5, 0)
	handleText:SetText("|cff8899bb::|r")

	local labelOffsetLeft = 20
	if isButtonList then
		local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		cb:SetSize(18, 18)
		cb:SetPoint("LEFT", row, "LEFT", 16, 0)
		cb:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			if row.itemKey and Database.SetMatrixButtonColumnVisible then
				Database.SetMatrixButtonColumnVisible(row.itemKey, self:GetChecked() and true or false)
				SettingsUI.RefreshReorderWindow()
			end
		end)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L["MATRIX_PIN_COL_HEADER"] or "Matrix")
			GameTooltip_AddNormalLine(GameTooltip, L["REORDER_COL_CHECK_TOOLTIP"], true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.ColCheckbox = cb
		labelOffsetLeft = 36
	end

	local downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	downBtn:SetSize(18, 18)
	downBtn:SetPoint("RIGHT", row, "RIGHT", -3, 0)
	downBtn:SetText("v")
	downBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if row.onMoveDelta then row.onMoveDelta(1) end
	end)
	row.DownBtn = downBtn

	local upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	upBtn:SetSize(18, 18)
	upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
	upBtn:SetText("^")
	upBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if row.onMoveDelta then row.onMoveDelta(-1) end
	end)
	row.UpBtn = upBtn

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", row, "LEFT", labelOffsetLeft, 0)
	label:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	row.Label = label

	row:SetScript("OnEnter", function(self)
		if not reorderStateOwner.dragState then
			if self.SetBackdropBorderColor then
				self:SetBackdropBorderColor(0.75, 0.85, 1.0, 1.0)
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L["REORDER_WINDOW_TITLE"])
			GameTooltip_AddNormalLine(GameTooltip, L["REORDER_DRAG_HINT_TOOLTIP"], true)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		if not (reorderStateOwner.dragState and reorderStateOwner.dragState.itemKey == self.itemKey) then
			if self.SetBackdropBorderColor then
				self:SetBackdropBorderColor(0.32, 0.42, 0.58, 0.85)
			end
		end
	end)
	row:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and self.itemKey then
			GameTooltip:Hide()
			reorderStateOwner.dragState = {
				listType = isButtonList and "button" or "modifier",
				itemKey = self.itemKey,
				scrollChild = scrollChild,
			}
			SettingsUI.RefreshReorderWindow()
		end
	end)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and reorderStateOwner.dragState then
			reorderStateOwner.dragState = nil
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			SettingsUI.RefreshReorderWindow()
		end
	end)

	rowsPool[idx] = row
	return row
end

local function BuildEmbeddedReorderCard(page, topY)
	local card = Widgets.CreateCard(page, "REORDER_WINDOW_TITLE", topY)

	local subY = card:Advance(28, 4)
	local subtitle = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	subtitle:SetPoint("TOPLEFT", card, "TOPLEFT", 14, subY)
	subtitle:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, subY)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetWordWrap(true)
	card.Subtitle = subtitle

	local hdrY = card:Advance(18, 2)
	local colW = 222
	local leftHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	leftHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 14, hdrY)
	card.LeftHeader = leftHeader

	local rightHeader = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rightHeader:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + colW + 14, hdrY)
	card.RightHeader = rightHeader

	local function CreateListBox(xOff, height)
		local box = CreateFrame("Frame", nil, card, "BackdropTemplate")
		box:SetSize(colW, height)
		Widgets.ApplyBoxBackdrop(box, { 0.04, 0.05, 0.08, 0.94 }, { 0.34, 0.40, 0.52, 0.85 }, false)

		local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", box, "TOPLEFT", 5, -5)
		sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -25, 5)

		local sc = CreateFrame("Frame", nil, sf)
		sc:SetSize(colW - 32, 1)
		sf:SetScrollChild(sc)

		box.ScrollFrame = sf
		box.ScrollChild = sc
		box.Rows = {}
		box:SetPoint("TOPLEFT", card, "TOPLEFT", xOff, card.cursorY)
		return box
	end

	card.LeftBox = CreateListBox(14, 210)
	card.RightBox = CreateListBox(14 + colW + 14, 240)
	card:Advance(242, 8)

	local addMmoBtn = Widgets.CreateStyledButton(card, colW, 22, function() return L["REORDER_ADD_MMO_BTN"] end, function(self)
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(self, function(_, rootDescription)
				rootDescription:CreateTitle(L["REORDER_ADD_MMO_MENU_TITLE"])
				rootDescription:SetScrollMode(280)
				for n = 6, 31 do
					local btnKey = "Button" .. tostring(n)
					local short = "MB" .. tostring(n)
					local full = (Constants.GetButtonDisplayName and Constants.GetButtonDisplayName(btnKey)) or ("Mouse Button " .. tostring(n))
					local isVis = Database.IsMatrixButtonColumnVisible and Database.IsMatrixButtonColumnVisible(btnKey)
					local label = isVis and string.format("|cff40ff59%s|r (%s)", short, full) or string.format("|cffffd100%s|r (%s)", short, full)
					rootDescription:CreateButton(label, function()
						if Database.AddMouseButtonToOrder then
							Database.AddMouseButtonToOrder(btnKey, true)
						end
						SettingsUI.RefreshReorderWindow()
					end)
				end
			end)
		end
	end, "secondary")
	addMmoBtn:SetPoint("TOPLEFT", card.LeftBox, "BOTTOMLEFT", 0, -6)
	card.AddMmoBtn = addMmoBtn

	local btnRowY = card:Advance(24, 4)
	local mmbBtn = Widgets.CreateStyledButton(card, colW, 24, function() return L["REORDER_PRESET_MMB_CENTER_BTN"] end, function()
		if Database.ApplyMiddleMouseCenterOrder then
			Database.ApplyMiddleMouseCenterOrder()
		end
		SettingsUI.RefreshReorderWindow()
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_ORDER_MMB_CENTER"])
		end
	end, "secondary")
	mmbBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14, btnRowY)
	card.PresetMmbBtn = mmbBtn

	local rstBtn = Widgets.CreateStyledButton(card, colW, 24, function() return L["REORDER_RESET_BTN"] end, function()
		if Database.ResetButtonAndModifierOrder then
			Database.ResetButtonAndModifierOrder()
		end
		SettingsUI.RefreshReorderWindow()
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_ORDER_RESET"])
		end
	end, "secondary")
	rstBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + colW + 14, btnRowY)
	card.ResetOrderBtn = rstBtn

	card:SetScript("OnUpdate", function(self)
		local ds = self.dragState
		if not ds then return end
		if not IsMouseButtonDown("LeftButton") then
			self.dragState = nil
			SettingsUI.RefreshReorderWindow()
			return
		end
		local sc = ds.scrollChild
		if not sc or not sc:GetTop() then return end
		local _, cursorY = GetCursorPosition()
		cursorY = cursorY / (sc:GetEffectiveScale() or 1)
		local rowPitch = REORDER_ROW_H + REORDER_ROW_GAP
		local targetIdx = math.floor((sc:GetTop() - cursorY) / rowPitch) + 1
		if ds.listType == "button" then
			local list = Database.GetOrderedMouseButtons and Database.GetOrderedMouseButtons(true) or {}
			if #list > 0 then
				targetIdx = math.max(1, math.min(#list, targetIdx))
				local curIdx = Database.GetButtonOrderIndex and Database.GetButtonOrderIndex(ds.itemKey) or targetIdx
				if targetIdx ~= curIdx and Database.MoveMouseButtonInOrder then
					Database.MoveMouseButtonInOrder(ds.itemKey, targetIdx)
					SettingsUI.RefreshReorderWindow()
				end
			end
		elseif ds.listType == "modifier" then
			local visibleMods = self.visibleModOrders or {}
			if #visibleMods > 0 then
				targetIdx = math.max(1, math.min(#visibleMods, targetIdx))
				local curVisualIdx = nil
				for i, mId in ipairs(visibleMods) do
					if mId == ds.itemKey then curVisualIdx = i; break end
				end
				if curVisualIdx and targetIdx ~= curVisualIdx then
					local targetModOrder = visibleMods[targetIdx]
					local fullOrder = Database.GetOrderedModifierIDs and Database.GetOrderedModifierIDs() or {}
					for i, id in ipairs(fullOrder) do
						if id == targetModOrder and Database.MoveModifierInOrder then
							Database.MoveModifierInOrder(ds.itemKey, i)
							SettingsUI.RefreshReorderWindow()
							break
						end
					end
				end
			end
		end
	end)
	card:SetScript("OnHide", function(self)
		self.dragState = nil
	end)

	local nextY = card:Finalize(10)
	return card, nextY
end

function SettingsUI.RefreshReorderWindow()
	if not settingsWindow or not settingsWindow.ReorderCard or not settingsWindow:IsShown() then
		return
	end
	local f = settingsWindow.ReorderCard
	f.HeaderText:SetText("|cffffd100" .. L["REORDER_WINDOW_TITLE"] .. "|r")
	f.Subtitle:SetText(L["REORDER_WINDOW_SUBTITLE"])
	f.LeftHeader:SetText("|cffffd100" .. L["REORDER_HDR_MOUSE_BUTTONS"] .. "|r")
	f.RightHeader:SetText("|cff99ccff" .. L["REORDER_HDR_MODIFIERS"] .. "|r")
	f.AddMmoBtn:RefreshValue()
	f.PresetMmbBtn:RefreshValue()
	f.ResetOrderBtn:RefreshValue()

	local rowPitch = REORDER_ROW_H + REORDER_ROW_GAP

	local buttons = Database.GetOrderedMouseButtons and Database.GetOrderedMouseButtons(true) or {}
	local leftChild = f.LeftBox.ScrollChild
	local leftWidth = leftChild:GetWidth()
	for idx, btnName in ipairs(buttons) do
		local row = EnsureReorderListRow(leftChild, f.LeftBox.Rows, idx, true, f)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", leftChild, "TOPLEFT", 0, -((idx - 1) * rowPitch))
		row:SetWidth(leftWidth)
		row.itemKey = btnName
		row.Label:SetText(string.format("|cff888888%d.|r %s", idx, GetMouseButtonDisplayLabel(btnName)))
		if row.ColCheckbox then
			local isVis = Database.IsMatrixButtonColumnVisible and Database.IsMatrixButtonColumnVisible(btnName)
			row.ColCheckbox:SetChecked(isVis and true or false)
		end
		row.UpBtn:SetEnabled(idx > 1)
		row.DownBtn:SetEnabled(idx < #buttons)
		row.onMoveDelta = function(delta)
			if Database.MoveMouseButtonInOrder then
				Database.MoveMouseButtonInOrder(btnName, idx + delta)
				SettingsUI.RefreshReorderWindow()
			end
		end
		local isDrag = f.dragState and f.dragState.listType == "button" and f.dragState.itemKey == btnName
		if row.SetBackdropColor then
			if isDrag then
				row:SetBackdropColor(0.26, 0.22, 0.08, 0.96)
				row:SetBackdropBorderColor(1.0, 0.82, 0.25, 1.0)
			else
				row:SetBackdropColor(0.11, 0.14, 0.20, 0.92)
				row:SetBackdropBorderColor(0.32, 0.42, 0.58, 0.85)
			end
		end
		row:Show()
	end
	for idx = #buttons + 1, #f.LeftBox.Rows do
		f.LeftBox.Rows[idx]:Hide()
	end
	leftChild:SetHeight(math.max(1, #buttons * rowPitch))

	local orderedMods = (ns.ClickBindingUI and ns.ClickBindingUI.GetOrderedMatrixModRows and ns.ClickBindingUI.GetOrderedMatrixModRows()) or {}
	local showMeta = (ns.ClickBindingUI and ns.ClickBindingUI.IsMatrixMetaActive and ns.ClickBindingUI.IsMatrixMetaActive()) or false
	local visibleMods = {}
	f.visibleModOrders = {}
	for _, item in ipairs(orderedMods) do
		if showMeta or not item.row.isMeta then
			table.insert(visibleMods, item.row)
			table.insert(f.visibleModOrders, item.row.modOrder)
		end
	end

	local rightChild = f.RightBox.ScrollChild
	local rightWidth = rightChild:GetWidth()
	for idx, modRow in ipairs(visibleMods) do
		local row = EnsureReorderListRow(rightChild, f.RightBox.Rows, idx, false, f)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -((idx - 1) * rowPitch))
		row:SetWidth(rightWidth)
		row.itemKey = modRow.modOrder
		row.Label:SetText(string.format("|cff888888%d.|r |cffb8d8ff%s|r", idx, L[modRow.labelKey] or modRow.fallback))
		row.UpBtn:SetEnabled(idx > 1)
		row.DownBtn:SetEnabled(idx < #visibleMods)
		row.onMoveDelta = function(delta)
			local targetVisual = visibleMods[idx + delta]
			if targetVisual and Database.GetOrderedModifierIDs and Database.MoveModifierInOrder then
				for fullIdx, id in ipairs(Database.GetOrderedModifierIDs()) do
					if id == targetVisual.modOrder then
						Database.MoveModifierInOrder(modRow.modOrder, fullIdx)
						SettingsUI.RefreshReorderWindow()
						break
					end
				end
			end
		end
		local isDrag = f.dragState and f.dragState.listType == "modifier" and f.dragState.itemKey == modRow.modOrder
		if row.SetBackdropColor then
			if isDrag then
				row:SetBackdropColor(0.26, 0.22, 0.08, 0.96)
				row:SetBackdropBorderColor(1.0, 0.82, 0.25, 1.0)
			else
				row:SetBackdropColor(0.11, 0.14, 0.20, 0.92)
				row:SetBackdropBorderColor(0.32, 0.42, 0.58, 0.85)
			end
		end
		row:Show()
	end
	for idx = #visibleMods + 1, #f.RightBox.Rows do
		f.RightBox.Rows[idx]:Hide()
	end
	rightChild:SetHeight(math.max(1, #visibleMods * rowPitch))
end

function SettingsUI.ShowReorderWindow()
	SettingsUI.OpenSettingsTab(3)
end

function SettingsUI.HideReorderWindow()
	-- Integriert in Seite 3 des Command-Centers; separater Schließ-Aufruf ist ein sicherer No-Op.
end

function SettingsUI.ToggleReorderWindow()
	if settingsWindow and settingsWindow:IsShown() and activeTabIndex == 3 and currentSearchQuery == "" then
		settingsWindow:Hide()
		return
	end
	SettingsUI.OpenSettingsTab(3)
end

--------------------------------------------------------------------------------
-- Inline-Preset-Liste auf Seite 5 (Presets & Dual-Spec)
--------------------------------------------------------------------------------

local function EnsurePresetListRow(card, idx)
	if presetListRows[idx] then
		return presetListRows[idx]
	end
	local row = CreateFrame("Frame", nil, card, "BackdropTemplate")
	row:SetSize(card.innerWidth, 34)
	Widgets.ApplyBoxBackdrop(row, { 0.06, 0.08, 0.12, 0.95 }, { 0.26, 0.32, 0.44, 0.85 }, false)

	local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameFs:SetPoint("LEFT", row, "LEFT", 10, 0)
	nameFs:SetWidth(155)
	nameFs:SetJustifyH("LEFT")
	nameFs:SetWordWrap(false)
	row.NameText = nameFs

	local delBtn = Widgets.CreateStyledButton(row, 26, 22, function() return "X" end, function()
		if row.presetName and ns.ClickBindingUI and ns.ClickBindingUI.DeletePresetByName then
			ns.ClickBindingUI.DeletePresetByName(row.presetName)
			SettingsUI.RefreshWindow()
		end
	end, "danger", "PRESET_BTN_DELETE_DESC")
	delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.DelBtn = delBtn

	local saveBtn = Widgets.CreateStyledButton(row, 74, 22, function() return L["PRESET_BTN_OVERWRITE"] end, function()
		if row.presetName and ns.ClickBindingUI and ns.ClickBindingUI.SavePresetByName then
			ns.ClickBindingUI.SavePresetByName(row.presetName)
			SettingsUI.RefreshWindow()
		end
	end, "secondary", "PRESET_BTN_OVERWRITE_DESC")
	saveBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
	row.SaveBtn = saveBtn

	local loadBtn = Widgets.CreateStyledButton(row, 62, 22, function() return L["PRESET_BTN_LOAD"] end, function()
		if row.presetData and ns.ClickBindingUI and ns.ClickBindingUI.LoadPreset then
			ns.ClickBindingUI.LoadPreset(row.presetData)
			SettingsUI.RefreshWindow()
		end
	end, "primary", "PRESET_BTN_LOAD_DESC")
	loadBtn:SetPoint("RIGHT", saveBtn, "LEFT", -4, 0)
	row.LoadBtn = loadBtn

	local function MakeSpecBtn(specIdx)
		local b = CreateFrame("Button", nil, row, "BackdropTemplate")
		b:SetSize(60, 22)
		b:RegisterForClicks("LeftButtonUp")
		Widgets.ApplyBoxBackdrop(b, Widgets.THEME.segBgIdle, Widgets.THEME.segBrdIdle, false)

		local ic = b:CreateTexture(nil, "ARTWORK")
		ic:SetSize(14, 14)
		ic:SetPoint("LEFT", b, "LEFT", 4, 0)
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.Icon = ic

		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", ic, "RIGHT", 3, 0)
		fs:SetPoint("RIGHT", b, "RIGHT", -2, 0)
		fs:SetJustifyH("CENTER")
		b.Text = fs

		b:SetScript("OnClick", function()
			if not row.presetData or not Database.SetPresetSpecAssignment then
				return
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			local cur = (specIdx == 1) and row.presetData.spec1 or row.presetData.spec2
			local nextVal = not (cur and true or false)
			Database.SetPresetSpecAssignment(row.presetData.name, specIdx, nextVal)
			SettingsUI.RefreshWindow()
			if DEFAULT_CHAT_FRAME then
				local fmt = nextVal and L["CHAT_PRESET_SPEC_LINKED_FORMAT"] or L["CHAT_PRESET_SPEC_UNLINKED_FORMAT"]
				DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, row.presetData.name, specIdx))
			end
		end)
		b:SetScript("OnEnter", function(self)
			if row.presetData then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				local fmt = (specIdx == 1) and L["PRESET_ACT_LINK_SPEC_1_FORMAT"] or L["PRESET_ACT_LINK_SPEC_2_FORMAT"]
				GameTooltip_SetTitle(GameTooltip, string.format(fmt, row.presetData.name))
				GameTooltip:Show()
			end
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end

	local spec2Btn = MakeSpecBtn(2)
	spec2Btn:SetPoint("RIGHT", loadBtn, "LEFT", -6, 0)
	row.Spec2Btn = spec2Btn

	local spec1Btn = MakeSpecBtn(1)
	spec1Btn:SetPoint("RIGHT", spec2Btn, "LEFT", -4, 0)
	row.Spec1Btn = spec1Btn

	presetListRows[idx] = row
	return row
end

local function RefreshPresetManagerCard()
	if not settingsWindow or not settingsWindow.PresetCard then
		return
	end
	local card = settingsWindow.PresetCard
	card.HeaderText:SetText("|cffffd100" .. L["SETTINGS_HEADER_PRESETS"] .. "|r")
	if card.NewBtn then
		card.NewBtn:RefreshValue()
	end

	local _, presets = GetSelectedPreset()
	local activeName = (ns.ClickBindingUI and ns.ClickBindingUI.GetEffectiveActivePresetName and ns.ClickBindingUI.GetEffectiveActivePresetName()) or Database.GetActivePresetName()
	local spec1Icon = Constants.GetPrimaryTalentTreeIconForSpecGroup and Constants.GetPrimaryTalentTreeIconForSpecGroup(1)
	local spec2Icon = Constants.GetPrimaryTalentTreeIconForSpecGroup and Constants.GetPrimaryTalentTreeIconForSpecGroup(2)

	if #presets == 0 then
		for _, r in ipairs(presetListRows) do
			r:Hide()
		end
		card.EmptyHint:SetText(L["UX_PRESET_EMPTY_HINT"])
		card.EmptyHint:Show()
		card.EmptyCreateBtn:RefreshValue()
		card.EmptyCreateBtn:Show()
		card:SetHeight(140)
		if settingsWindow.Pages[5] then
			settingsWindow.Pages[5].contentHeight = 160
		end
		return
	end

	card.EmptyHint:Hide()
	card.EmptyCreateBtn:Hide()

	local y = -42
	for idx, preset in ipairs(presets) do
		local row = EnsurePresetListRow(card, idx)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
		row.presetName = preset.name
		row.presetData = preset

		local bCount = (type(preset.bindings) == "table") and #preset.bindings or 0
		local isAct = (activeName == preset.name)
		local actBadge = isAct and (" " .. L["UX_PRESET_ACTIVE_BADGE"]) or ""
		row.NameText:SetText(string.format("|cffffffff%s|r  |cff888888(%d)|r%s", preset.name or "?", bCount, actBadge))
		if isAct then
			Widgets.ApplyBoxBackdrop(row, { 0.09, 0.16, 0.11, 0.96 }, { 0.35, 0.80, 0.45, 0.95 }, false)
		else
			Widgets.ApplyBoxBackdrop(row, { 0.06, 0.08, 0.12, 0.95 }, { 0.26, 0.32, 0.44, 0.85 }, false)
		end

		local function StyleSpecBtn(b, linked, iconID, labelStr)
			b.Icon:SetTexture(iconID or 134400)
			b.Text:SetText(labelStr)
			if linked then
				Widgets.ApplyBoxBackdrop(b, { 0.10, 0.24, 0.36, 0.98 }, { 0.38, 0.80, 1.0, 1.0 }, false)
				b.Text:SetTextColor(0.45, 0.88, 1.0)
			else
				Widgets.ApplyBoxBackdrop(b, Widgets.THEME.segBgIdle, Widgets.THEME.segBrdIdle, false)
				b.Text:SetTextColor(0.68, 0.72, 0.80)
			end
		end
		StyleSpecBtn(row.Spec1Btn, preset.spec1, spec1Icon, L["UX_PRESET_SPEC1_SHORT"])
		StyleSpecBtn(row.Spec2Btn, preset.spec2, spec2Icon, L["UX_PRESET_SPEC2_SHORT"])

		row.LoadBtn:RefreshValue()
		row.SaveBtn:RefreshValue()
		row.DelBtn:RefreshValue()
		row:Show()
		y = y - 38
	end

	for idx = #presets + 1, #presetListRows do
		presetListRows[idx]:Hide()
	end

	local totalH = math.abs(y) + 10
	card:SetHeight(totalH)
	if settingsWindow.Pages[5] then
		settingsWindow.Pages[5].contentHeight = totalH + 20
	end
end

--------------------------------------------------------------------------------
-- Globale Live-Suche über alle 6 Kategorien (Ebene 1)
--------------------------------------------------------------------------------

local function RegisterSearchEntry(entry)
	table.insert(searchCatalog, entry)
end

local function MatchesSearchEntry(entry, needle)
	local enTbl = ns.Locales and ns.Locales["enUS"] or {}
	local hayParts = {
		L[entry.labelKey] or "",
		entry.descKey and L[entry.descKey] or "",
		L[entry.navKey] or "",
		enTbl[entry.labelKey] or "",
		entry.descKey and enTbl[entry.descKey] or "",
		entry.keywords or "",
	}
	local haystack = string.lower(Widgets.StripColorCodes(table.concat(hayParts, " ")))
	return string.find(haystack, needle, 1, true) ~= nil
end

local function EnsureSearchResultRow(parent, idx)
	if searchResultRows[idx] then
		return searchResultRows[idx]
	end
	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetSize(486, 52)
	Widgets.ApplyBoxBackdrop(row, Widgets.THEME.cardBg, Widgets.THEME.cardBorder, false)

	local catBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	catBadge:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -7)
	catBadge:SetJustifyH("LEFT")
	row.CatBadge = catBadge

	local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", catBadge, "BOTTOMLEFT", 0, -3)
	title:SetWidth(290)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	row.Title = title

	local jumpBtn = Widgets.CreateStyledButton(row, 86, 22, function() return L["UX_SEARCH_JUMP_BTN"] end, function()
		if row.targetTab then
			SettingsUI.SetSearchFilter("")
			SettingsUI.OpenSettingsTab(row.targetTab)
		end
	end, "secondary")
	jumpBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row.JumpBtn = jumpBtn

	local actionBtn = Widgets.CreateStyledButton(row, 96, 22, function()
		return row.getQuickValueText and row.getQuickValueText() or ""
	end, function()
		if row.onQuickToggle then
			row.onQuickToggle()
			SettingsUI.RefreshWindow()
		end
	end, "primary")
	actionBtn:SetPoint("RIGHT", jumpBtn, "LEFT", -6, 0)
	row.ActionBtn = actionBtn

	searchResultRows[idx] = row
	return row
end

local function RenderSearchResults()
	if not settingsWindow or not settingsWindow.SearchPage then
		return
	end
	local sPage = settingsWindow.SearchPage
	local needle = string.lower(strtrim(currentSearchQuery or ""))
	if needle == "" then
		sPage:Hide()
		return
	end

	local matches = {}
	for _, entry in ipairs(searchCatalog) do
		if MatchesSearchEntry(entry, needle) then
			table.insert(matches, entry)
		end
	end

	sPage.Header:SetText("|cffffd100" .. string.format(L["UX_SEARCH_RESULTS_FORMAT"], #matches) .. "|r")
	if #matches == 0 then
		for _, r in ipairs(searchResultRows) do r:Hide() end
		sPage.EmptyText:SetText(string.format(L["UX_SEARCH_NO_RESULTS_FORMAT"], currentSearchQuery))
		sPage.EmptyText:Show()
		sPage.contentHeight = 120
		return
	end
	sPage.EmptyText:Hide()

	local y = -34
	for idx, entry in ipairs(matches) do
		local row = EnsureSearchResultRow(sPage, idx)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", sPage, "TOPLEFT", 10, y)
		row.targetTab = entry.tabIndex
		row.CatBadge:SetText("|cff66bbff" .. (L[entry.navKey] or "") .. "|r")
		row.Title:SetText(L[entry.labelKey] or entry.labelKey)
		row.JumpBtn:RefreshValue()

		if entry.kind == "toggle" then
			row.getQuickValueText = function()
				local v = entry.getter and entry.getter() or Database.Get(entry.dbKey)
				return v and L["CHAT_STATE_ON"] or L["CHAT_STATE_OFF"]
			end
			row.onQuickToggle = function()
				local v = entry.getter and entry.getter() or Database.Get(entry.dbKey)
				if entry.setter then entry.setter(not v) else Database.Set(entry.dbKey, not v) end
			end
			row.ActionBtn:Show()
			row.ActionBtn:RefreshValue()
		elseif entry.kind == "segmented" and entry.options then
			row.getQuickValueText = function()
				local cur = entry.getter and entry.getter() or Database.Get(entry.dbKey) or entry.defaultValue
				for _, o in ipairs(entry.options) do
					if o.value == cur then
						return L[o.shortKey or o.labelKey] or tostring(cur)
					end
				end
				return tostring(cur)
			end
			row.onQuickToggle = function()
				local cur = entry.getter and entry.getter() or Database.Get(entry.dbKey) or entry.defaultValue
				local nextIdx = 1
				for i, o in ipairs(entry.options) do
					if o.value == cur then nextIdx = (i % #entry.options) + 1; break end
				end
				local nextVal = entry.options[nextIdx].value
				if entry.setter then entry.setter(nextVal) else Database.Set(entry.dbKey, nextVal) end
			end
			row.ActionBtn:Show()
			row.ActionBtn:RefreshValue()
		else
			row.ActionBtn:Hide()
		end

		row:Show()
		y = y - 58
	end

	for idx = #matches + 1, #searchResultRows do
		searchResultRows[idx]:Hide()
	end
	sPage.contentHeight = math.abs(y) + 16
end

function SettingsUI.SetSearchFilter(queryText)
	currentSearchQuery = strtrim(queryText or "")
	if settingsWindow and settingsWindow.SearchBox and settingsWindow.SearchBox:GetText() ~= currentSearchQuery then
		settingsWindow.SearchBox:SetText(currentSearchQuery)
	end
	SettingsUI.RefreshWindow()
end

function SettingsUI.GetSearchFilter()
	return currentSearchQuery
end

--------------------------------------------------------------------------------
-- Hauptfenster: Sidebar Command Center (BetterClickCastingSettingsFrame)
--------------------------------------------------------------------------------

local function UpdateScrollChildHeight()
	if not settingsWindow or not settingsWindow.ScrollChild then
		return
	end
	local activePage = (currentSearchQuery ~= "") and settingsWindow.SearchPage or settingsWindow.Pages[activeTabIndex]
	local h = (activePage and activePage.contentHeight) or 460
	settingsWindow.ScrollChild:SetHeight(math.max(460, h))
end

local function SelectTab(tabIndex)
	if not settingsWindow then
		return
	end
	activeTabIndex = math.max(1, math.min(#NAV_SECTIONS, tonumber(tabIndex) or 1))
	if settingsWindow.ScrollFrame and settingsWindow.ScrollFrame.SetVerticalScroll then
		settingsWindow.ScrollFrame:SetVerticalScroll(0)
	end
	SettingsUI.RefreshWindow()
end

local function SaveWindowPosition(frame)
	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
	if point then
		Database.Set("settingsWindowPos", {
			point = point,
			relativePoint = relativePoint or point,
			x = math.floor((xOfs or 0) + 0.5),
			y = math.floor((yOfs or 0) + 0.5),
		})
	end
end

local function PositionSettingsWindow(frame)
	frame:ClearAllPoints()
	local saved = Database.Get("settingsWindowPos")
	if type(saved) == "table" and saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
	elseif ClickBindingFrame and ClickBindingFrame:IsShown() then
		frame:SetPoint("TOPLEFT", ClickBindingFrame, "TOPRIGHT", 12, 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	end
end

local function EnsureSettingsWindow()
	if settingsWindow then
		return settingsWindow
	end
	searchCatalog = {}

	local win = CreateFrame("Frame", "BetterClickCastingSettingsFrame", UIParent, "BackdropTemplate")
	win:SetSize(716, 556)
	win:SetFrameStrata("MEDIUM")
	win:SetToplevel(true)
	win:SetFrameLevel(20)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnMouseDown", function(self) if self.Raise then self:Raise() end end)
	win:SetScript("OnDragStart", function(self) if self.Raise then self:Raise() end; self:StartMoving() end)
	win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveWindowPosition(self) end)

	if UISpecialFrames then
		table.insert(UISpecialFrames, "BetterClickCastingSettingsFrame")
	end

	if win.SetBackdrop then
		win:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
		win:SetBackdropColor(0.045, 0.055, 0.085, 0.97)
		win:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
	end

	-- Kopfzeile + Globale Suchbox
	local headerBg = win:CreateTexture(nil, "BACKGROUND", nil, 1)
	headerBg:SetPoint("TOPLEFT", win, "TOPLEFT", 7, -7)
	headerBg:SetPoint("TOPRIGHT", win, "TOPRIGHT", -7, -7)
	headerBg:SetHeight(40)
	headerBg:SetColorTexture(0.07, 0.09, 0.14, 0.95)

	local headerLine = win:CreateTexture(nil, "ARTWORK")
	headerLine:SetHeight(1)
	headerLine:SetPoint("TOPLEFT", win, "TOPLEFT", 7, -47)
	headerLine:SetPoint("TOPRIGHT", win, "TOPRIGHT", -7, -47)
	headerLine:SetColorTexture(0.65, 0.55, 0.30, 0.45)

	local icon = win:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -16)
	icon:SetAtlas(Constants.ICON_ATLAS)

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	win.TitleText = title

	local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		win:Hide()
	end)

	-- Globales Live-Suchfeld oben rechts
	local searchWrap = CreateFrame("Frame", nil, win, "BackdropTemplate")
	searchWrap:SetSize(244, 24)
	searchWrap:SetPoint("RIGHT", closeBtn, "LEFT", -8, -1)
	Widgets.ApplyBoxBackdrop(searchWrap, { 0.03, 0.04, 0.06, 0.96 }, { 0.34, 0.42, 0.58, 0.90 }, false)

	local searchIcon = searchWrap:CreateTexture(nil, "ARTWORK")
	searchIcon:SetSize(13, 13)
	searchIcon:SetPoint("LEFT", searchWrap, "LEFT", 7, 0)
	searchIcon:SetAtlas("common-search-magnifyingglass")

	local clearSearchBtn = CreateFrame("Button", nil, searchWrap)
	clearSearchBtn:SetSize(16, 16)
	clearSearchBtn:SetPoint("RIGHT", searchWrap, "RIGHT", -5, 0)
	local clearFs = clearSearchBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clearFs:SetPoint("CENTER", 0, 0)
	clearFs:SetText("|cffaaaaaaX|r")
	clearSearchBtn:Hide()

	local searchBox = CreateFrame("EditBox", nil, searchWrap)
	searchBox:SetAutoFocus(false)
	searchBox:SetFontObject("ChatFontNormal")
	searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
	searchBox:SetPoint("RIGHT", clearSearchBtn, "LEFT", -2, 0)
	searchBox:SetHeight(20)

	local searchPlaceholder = searchWrap:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	searchPlaceholder:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
	searchPlaceholder:SetJustifyH("LEFT")
	win.SearchPlaceholder = searchPlaceholder

	clearSearchBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		searchBox:SetText("")
		searchBox:ClearFocus()
	end)

	searchBox:SetScript("OnEditFocusGained", function()
		searchWrap:SetBackdropBorderColor(0.95, 0.78, 0.25, 1.0)
	end)
	searchBox:SetScript("OnEditFocusLost", function()
		searchWrap:SetBackdropBorderColor(0.34, 0.42, 0.58, 0.90)
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then
			self:SetText("")
		end
		self:ClearFocus()
	end)
	searchBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	searchBox:SetScript("OnTextChanged", function(self)
		local txt = self:GetText() or ""
		currentSearchQuery = strtrim(txt)
		clearSearchBtn:SetShown(currentSearchQuery ~= "")
		searchPlaceholder:SetShown(currentSearchQuery == "")
		if win.ScrollFrame and win.ScrollFrame.SetVerticalScroll then
			win.ScrollFrame:SetVerticalScroll(0)
		end
		SettingsUI.RefreshWindow()
	end)
	win.SearchBox = searchBox

	-- Linke Navigations-Sidebar (6 Kategorien + feste Schnell-Toolbar unten)
	local sidebar = CreateFrame("Frame", nil, win)
	sidebar:SetWidth(182)
	sidebar:SetPoint("TOPLEFT", win, "TOPLEFT", 7, -48)
	sidebar:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 7, 7)

	local sideBg = sidebar:CreateTexture(nil, "BACKGROUND")
	sideBg:SetAllPoints()
	sideBg:SetColorTexture(0.032, 0.040, 0.064, 0.96)

	local sideBorder = sidebar:CreateTexture(nil, "ARTWORK")
	sideBorder:SetWidth(1)
	sideBorder:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
	sideBorder:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
	sideBorder:SetColorTexture(0.32, 0.38, 0.50, 0.45)

	win.TabButtons = {}
	for i, nav in ipairs(NAV_SECTIONS) do
		local b = CreateFrame("Button", nil, sidebar)
		b:SetSize(168, 32)
		b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 7, -10 - ((i - 1) * 35))
		b:RegisterForClicks("LeftButtonUp")
		b.labelKey = nav.labelKey

		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		b.Bg = bg

		local bar = b:CreateTexture(nil, "ARTWORK")
		bar:SetSize(3, 22)
		bar:SetPoint("LEFT", b, "LEFT", 2, 0)
		bar:SetColorTexture(1.0, 0.82, 0.18, 1.0)
		b.ActiveBar = bar

		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.06)

		local ic = b:CreateTexture(nil, "ARTWORK")
		ic:SetSize(16, 16)
		ic:SetPoint("LEFT", b, "LEFT", 11, 0)
		if nav.atlas then
			ic:SetAtlas(nav.atlas)
		elseif nav.texture then
			ic:SetTexture(nav.texture)
			ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end

		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", ic, "RIGHT", 8, 0)
		fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		b.Text = fs

		b:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			if currentSearchQuery ~= "" then
				searchBox:SetText("")
				searchBox:ClearFocus()
			end
			SelectTab(i)
		end)
		win.TabButtons[i] = b
	end

	-- Feste Schnell-Werkzeuge unten in der Sidebar (0 Duplikate auf den Seiten)
	local quickLine = sidebar:CreateTexture(nil, "ARTWORK")
	quickLine:SetHeight(1)
	quickLine:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 10, 108)
	quickLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -10, 108)
	quickLine:SetColorTexture(0.35, 0.42, 0.56, 0.35)

	local quickHdr = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	quickHdr:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 92)
	win.QuickHeader = quickHdr

	local qClickBtn = Widgets.CreateStyledButton(sidebar, 164, 24, function() return L["UX_QUICK_CLICKCAST"] end, function()
		if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			ns.MinimapButton.ToggleClickCastingWindow()
		end
	end, "secondary")
	qClickBtn:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 9, 64)

	local qMatrixBtn = Widgets.CreateStyledButton(sidebar, 164, 24, function() return L["UX_QUICK_MATRIX"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ToggleFreeKeysMatrix then
			ns.ClickBindingUI.ToggleFreeKeysMatrix()
		end
	end, "secondary", "SETTINGS_FREE_KEYS_MATRIX_DESC")
	qMatrixBtn:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 9, 36)

	local qMoveBtn = Widgets.CreateStyledButton(sidebar, 164, 24, function()
		return SettingsUI.IsOverlaysUnlocked() and L["UX_QUICK_MOVE_ACTIVE"] or L["UX_QUICK_MOVE"]
	end, function()
		SettingsUI.ToggleOverlaysUnlocked()
	end, "primary", "SETTING_UNITHOVER_UNLOCK_MOVE_DESC")
	qMoveBtn:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 9, 8)
	win.QuickButtons = { qClickBtn, qMatrixBtn, qMoveBtn }

	-- Rechter Scroll-Bereich für die 6 Kategorie-Seiten + globale Suchseite
	local scrollFrame = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 2, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 10)
	win.ScrollFrame = scrollFrame

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(502, 460)
	scrollFrame:SetScrollChild(scrollChild)
	win.ScrollChild = scrollChild

	win.Pages = {}
	win.Controls = {}
	local function Reg(ctrl)
		table.insert(win.Controls, ctrl)
		return ctrl
	end

	for i = 1, #NAV_SECTIONS do
		local p = CreateFrame("Frame", nil, scrollChild)
		p:SetAllPoints(scrollChild)
		p:Hide()
		win.Pages[i] = p
	end

	local searchPage = CreateFrame("Frame", nil, scrollChild)
	searchPage:SetAllPoints(scrollChild)
	searchPage.Header = searchPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	searchPage.Header:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 12, -8)
	searchPage.EmptyText = searchPage:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	searchPage.EmptyText:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 12, -44)
	searchPage:Hide()
	win.SearchPage = searchPage

	local function AddIndexedToggle(card, tabIdx, spec, keywords)
		RegisterSearchEntry({
			tabIndex = tabIdx,
			navKey = NAV_SECTIONS[tabIdx].labelKey,
			labelKey = spec.labelKey,
			descKey = spec.descKey,
			keywords = keywords,
			kind = "toggle",
			dbKey = spec.dbKey,
			getter = spec.getter,
			setter = spec.setter,
		})
		return Reg(Widgets.CreateToggleRow(card, spec))
	end

	local function AddIndexedSegmented(card, tabIdx, spec, keywords)
		RegisterSearchEntry({
			tabIndex = tabIdx,
			navKey = NAV_SECTIONS[tabIdx].labelKey,
			labelKey = spec.labelKey,
			descKey = spec.descKey,
			keywords = keywords,
			kind = "segmented",
			dbKey = spec.dbKey,
			defaultValue = spec.defaultValue,
			options = spec.options,
			getter = spec.getter,
			setter = spec.setter,
		})
		return Reg(Widgets.CreateSegmentedRow(card, spec))
	end

	----------------------------------------------------------------------------
	-- SEITE 1: Klickbelegung & Ränge (Live-Zeilen-Vorschau + 2 Themen-Karten)
	----------------------------------------------------------------------------
	local p1 = win.Pages[1]
	local y1 = -6

	local c1Prev = Reg(Widgets.CreateCard(p1, "UX_CARD_PREVIEW", y1))
	Reg(Widgets.CreateLineLivePreview(c1Prev))
	y1 = c1Prev:Finalize(8)

	local c1Layout = Reg(Widgets.CreateCard(p1, "UX_CARD_LIST_LAYOUT", y1))
	AddIndexedSegmented(c1Layout, 1, {
		dbKey = "groupingMode",
		defaultValue = "modifier",
		labelKey = "GROUP_MENU_TITLE",
		descKey = "GROUP_TOOLTIP_DESC",
		options = GROUP_MODES,
	}, "group sort modifier button type")
	AddIndexedToggle(c1Layout, 1, { dbKey = "compactListMode", labelKey = "SETTING_COMPACT_LIST_MODE", descKey = "SETTING_COMPACT_LIST_MODE_DESC" }, "compact row height small")
	AddIndexedToggle(c1Layout, 1, { dbKey = "moveInteractionsToBottom", labelKey = "SETTING_MOVE_INTERACTIONS_BOTTOM", descKey = "SETTING_MOVE_INTERACTIONS_BOTTOM_DESC" }, "target menu interaction bottom")
	AddIndexedToggle(c1Layout, 1, { dbKey = "showLineTooltips", labelKey = "SETTING_SHOW_LINE_TOOLTIPS", descKey = "SETTING_SHOW_LINE_TOOLTIPS_DESC" }, "tooltip spell")
	y1 = c1Layout:Finalize(8)

	local c1Ranks = Reg(Widgets.CreateCard(p1, "UX_CARD_RANKS_RULES", y1))
	AddIndexedSegmented(c1Ranks, 1, {
		dbKey = "trainerUpgradeBehavior",
		defaultValue = "card",
		labelKey = "TRAINER_BEHAVIOR_MENU_TITLE",
		descKey = "TRAINER_BEHAVIOR_TOOLTIP_DESC",
		options = TRAINER_BEHAVIOR_OPTIONS,
	}, "trainer upgrade hero card learn")
	AddIndexedToggle(c1Ranks, 1, { dbKey = "showRankInName", labelKey = "SETTING_SHOW_RANK_IN_NAME", descKey = "SETTING_SHOW_RANK_IN_NAME_DESC" }, "rank name")
	AddIndexedToggle(c1Ranks, 1, { dbKey = "highlightDownranks", labelKey = "SETTING_HIGHLIGHT_DOWNRANKS", descKey = "SETTING_HIGHLIGHT_DOWNRANKS_DESC" }, "downrank highlight color")
	AddIndexedToggle(c1Ranks, 1, { dbKey = "showRankSwitcher", labelKey = "SETTING_SHOW_RANK_SWITCHER", descKey = "SETTING_SHOW_RANK_SWITCHER_DESC" }, "switcher dropdown inline")
	AddIndexedToggle(c1Ranks, 1, { dbKey = "showLineManaCost", labelKey = "SETTING_SHOW_LINE_MANA_COST", descKey = "SETTING_SHOW_LINE_MANA_COST_DESC" }, "mana cost power")
	AddIndexedToggle(c1Ranks, 1, { dbKey = "enableSmartRankRules", labelKey = "SETTING_ENABLE_SMART_RULES", descKey = "SETTING_ENABLE_SMART_RULES_DESC" }, "smart rules max fixed")

	local upgY = c1Ranks:Advance(28, 4)
	local upgradeBtn = Reg(Widgets.CreateStyledButton(
		c1Ranks,
		c1Ranks.innerWidth,
		26,
		function()
			if ClickBindingFrame and ClickBindingFrame:IsShown() and ns.ClickBindingUI and ns.ClickBindingUI.CountUpgradeableBindings then
				local cnt = ns.ClickBindingUI.CountUpgradeableBindings()
				if cnt > 0 then
					return string.format(L["ACTION_UPGRADE_ALL_MAX_FORMAT"], cnt)
				end
			end
			return L["ACTION_UPGRADE_ALL_MAX_NONE"]
		end,
		function()
			if ClickBindingFrame and ClickBindingFrame:IsShown() and ns.ClickBindingUI and ns.ClickBindingUI.UpgradeAllBindingsToMaxRank then
				ns.ClickBindingUI.UpgradeAllBindingsToMaxRank()
				SettingsUI.RefreshWindow()
			elseif ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
				ns.MinimapButton.ToggleClickCastingWindow()
				SettingsUI.RefreshWindow()
			end
		end,
		"primary",
		"ACTION_UPGRADE_ALL_MAX_DESC"
	))
	upgradeBtn:SetPoint("TOPLEFT", c1Ranks, "TOPLEFT", 14, upgY)
	y1 = c1Ranks:Finalize(10)
	p1.contentHeight = math.abs(y1) + 12

	----------------------------------------------------------------------------
	-- SEITE 2: Zauberbuch (eigene prominente Kategorie + Live-Slot-Vorschau)
	----------------------------------------------------------------------------
	local p2 = win.Pages[2]
	local y2 = -6

	local c2Prev = Reg(Widgets.CreateCard(p2, "UX_CARD_PREVIEW", y2))
	Reg(Widgets.CreateSpellbookLivePreview(c2Prev))
	y2 = c2Prev:Finalize(8)

	local c2Sb = Reg(Widgets.CreateCard(p2, "SETTINGS_HEADER_SPELLBOOK", y2))
	AddIndexedToggle(c2Sb, 2, { dbKey = "quickBindSpellbook", labelKey = "SETTING_QUICK_BIND_SPELLBOOK", descKey = "SETTING_QUICK_BIND_SPELLBOOK_DESC" }, "spellbook quick bind click")
	AddIndexedToggle(c2Sb, 2, { dbKey = "showSpellbookBadges", labelKey = "SETTING_SHOW_SPELLBOOK_BADGES", descKey = "SETTING_SHOW_SPELLBOOK_BADGES_DESC" }, "spellbook badge key")
	AddIndexedToggle(c2Sb, 2, { dbKey = "autoShowAllRanks", labelKey = "SETTING_AUTO_SHOW_ALL_RANKS", descKey = "SETTING_AUTO_SHOW_ALL_RANKS_DESC" }, "spellbook all ranks cvar")
	AddIndexedToggle(c2Sb, 2, { dbKey = "autoSelectPrimarySpellTab", labelKey = "SETTING_AUTO_SELECT_PRIMARY_TAB", descKey = "SETTING_AUTO_SELECT_PRIMARY_TAB_DESC" }, "spellbook primary class tab")
	y2 = c2Sb:Finalize(10)
	p2.contentHeight = math.abs(y2) + 12

	----------------------------------------------------------------------------
	-- SEITE 3: Matrix & Reihenfolge (klar vom Zauberbuch getrennt + Reorder eingebettet)
	----------------------------------------------------------------------------
	local p3 = win.Pages[3]
	local y3 = -6

	local c3Mat = Reg(Widgets.CreateCard(p3, "UX_CARD_MATRIX_SETTINGS", y3))
	AddIndexedToggle(c3Mat, 3, { dbKey = "matrixAutoOpen", labelKey = "MATRIX_AUTO_OPEN_CHECKBOX", descKey = "MATRIX_AUTO_OPEN_DESC" }, "matrix auto open free keys")
	AddIndexedToggle(c3Mat, 3, { dbKey = "matrixShowCombos", labelKey = "MATRIX_SHOW_COMBOS_CHECKBOX", descKey = "MATRIX_SHOW_COMBOS_DESC" }, "matrix combos 8x5 12x5 default")
	AddIndexedSegmented(c3Mat, 3, {
		dbKey = "matrixMetaMode",
		defaultValue = "auto",
		labelKey = "UX_META_LABEL",
		descKey = "UX_META_DESC",
		options = MATRIX_META_OPTIONS,
	}, "mac macos cmd command meta matrix")
	y3 = c3Mat:Finalize(8)

	local reorderCard
	reorderCard, y3 = BuildEmbeddedReorderCard(p3, y3)
	win.ReorderCard = reorderCard
	RegisterSearchEntry({ tabIndex = 3, navKey = "UX_NAV_MATRIX", labelKey = "REORDER_WINDOW_TITLE", descKey = "SETTINGS_REORDER_DESC", keywords = "reorder mouse button mmb mmo mb6 modifier drag" })
	p3.contentHeight = math.abs(y3) + 12

	----------------------------------------------------------------------------
	-- SEITE 4: Unit-Frame Hover-Overlay (Anker-Schaubild + Abhängigkeits-Dimming)
	----------------------------------------------------------------------------
	local p4 = win.Pages[4]
	local y4 = -6
	local isHoverEnabled = function()
		return (Database.Get("unitHoverMode") or "off") ~= "off"
	end

	local c4Mode = Reg(Widgets.CreateCard(p4, "SETTINGS_HEADER_UNITHOVER", y4))
	AddIndexedSegmented(c4Mode, 4, {
		dbKey = "unitHoverMode",
		defaultValue = "off",
		labelKey = "UNITHOVER_MODE_MENU_TITLE",
		descKey = "UNITHOVER_MODE_TOOLTIP_DESC",
		options = UNITHOVER_MODES,
	}, "hover overlay unit frame mode")
	Reg(Widgets.CreateHoverAnchorDiagram(c4Mode))
	RegisterSearchEntry({ tabIndex = 4, navKey = "UX_NAV_HOVER", labelKey = "UNITHOVER_ANCHOR_MENU_TITLE", descKey = "UNITHOVER_ANCHOR_TOOLTIP_DESC", keywords = "anchor cursor top bottom left right free position" })
	y4 = c4Mode:Finalize(8)

	local c4Disp = Reg(Widgets.CreateCard(p4, "UX_CARD_HOVER_DISPLAY", y4))
	c4Disp.enabledFunc = isHoverEnabled
	local hintFs = c4Disp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hintFs:SetPoint("TOPRIGHT", c4Disp, "TOPRIGHT", -14, -12)
	hintFs:SetText(L["UX_HOVER_DISABLED_HINT"])
	c4Disp.disabledHintText = hintFs

	Reg(Widgets.CreateSliderRow(c4Disp, { dbKey = "unitHoverScale", minVal = 70, maxVal = 150, stepVal = 5, formatKey = "SETTING_UNITHOVER_SCALE_FORMAT", enabledFunc = isHoverEnabled }))
	RegisterSearchEntry({ tabIndex = 4, navKey = "UX_NAV_HOVER", labelKey = "SETTING_UNITHOVER_SCALE_FORMAT", keywords = "scale size zoom hover" })
	Reg(Widgets.CreateSliderRow(c4Disp, { dbKey = "unitHoverAlpha", minVal = 30, maxVal = 100, stepVal = 5, formatKey = "SETTING_UNITHOVER_ALPHA_FORMAT", enabledFunc = isHoverEnabled }))
	RegisterSearchEntry({ tabIndex = 4, navKey = "UX_NAV_HOVER", labelKey = "SETTING_UNITHOVER_ALPHA_FORMAT", keywords = "opacity alpha transparency hover" })

	AddIndexedToggle(c4Disp, 4, { dbKey = "unitHoverShowMana", labelKey = "SETTING_UNITHOVER_SHOW_MANA", descKey = "SETTING_UNITHOVER_SHOW_MANA_DESC", enabledFunc = isHoverEnabled }, "hover mana")
	AddIndexedToggle(c4Disp, 4, { dbKey = "unitHoverShowRankTags", labelKey = "SETTING_UNITHOVER_SHOW_RANK_TAGS", descKey = "SETTING_UNITHOVER_SHOW_RANK_TAGS_DESC", enabledFunc = isHoverEnabled }, "hover rank max tag")
	AddIndexedToggle(c4Disp, 4, { dbKey = "unitHoverShowRange", labelKey = "SETTING_UNITHOVER_SHOW_RANGE", descKey = "SETTING_UNITHOVER_SHOW_RANGE_DESC", enabledFunc = isHoverEnabled }, "hover range oor out of range")
	AddIndexedToggle(c4Disp, 4, { dbKey = "unitHoverShowInCombat", labelKey = "SETTING_UNITHOVER_SHOW_IN_COMBAT", descKey = "SETTING_UNITHOVER_SHOW_IN_COMBAT_DESC", enabledFunc = isHoverEnabled }, "hover combat infight")
	y4 = c4Disp:Finalize(10)
	p4.contentHeight = math.abs(y4) + 12

	----------------------------------------------------------------------------
	-- SEITE 5: Presets & Dual-Spec (Sichtbare Inline-Preset-Liste)
	----------------------------------------------------------------------------
	local p5 = win.Pages[5]
	local c5Presets = Widgets.CreateCard(p5, "SETTINGS_HEADER_PRESETS", -6)
	local newPBtn = Widgets.CreateStyledButton(c5Presets, 145, 22, function() return L["PRESET_BTN_NEW"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
			ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
				if saved and saved.name then selectedPresetName = saved.name end
				SettingsUI.RefreshWindow()
			end)
		end
	end, "primary", "PRESET_BTN_NEW_DESC")
	newPBtn:SetPoint("TOPRIGHT", c5Presets, "TOPRIGHT", -12, -5)
	c5Presets.NewBtn = newPBtn

	local emptyHint = c5Presets:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	emptyHint:SetPoint("TOPLEFT", c5Presets, "TOPLEFT", 18, -48)
	emptyHint:SetPoint("TOPRIGHT", c5Presets, "TOPRIGHT", -18, -48)
	emptyHint:SetJustifyH("CENTER")
	emptyHint:SetWordWrap(true)
	c5Presets.EmptyHint = emptyHint

	local emptyBtn = Widgets.CreateStyledButton(c5Presets, 200, 26, function() return L["PRESET_BTN_NEW"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
			ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
				if saved and saved.name then selectedPresetName = saved.name end
				SettingsUI.RefreshWindow()
			end)
		end
	end, "primary")
	emptyBtn:SetPoint("TOP", emptyHint, "BOTTOM", 0, -14)
	c5Presets.EmptyCreateBtn = emptyBtn
	win.PresetCard = c5Presets
	RegisterSearchEntry({ tabIndex = 5, navKey = "UX_NAV_PRESETS", labelKey = "SETTINGS_HEADER_PRESETS", descKey = "PRESET_TOOLTIP_DESC", keywords = "preset loadout dual spec spec1 spec2 talent" })

	----------------------------------------------------------------------------
	-- SEITE 6: Profile, Teilen & System
	----------------------------------------------------------------------------
	local p6 = win.Pages[6]
	local y6 = -6

	local c6Prof = Reg(Widgets.CreateCard(p6, "SETTINGS_HEADER_PROFILES", y6))
	AddIndexedToggle(c6Prof, 6, {
		labelKey = "SETTING_USE_CHAR_SETTINGS",
		descKey = "SETTING_USE_CHAR_SETTINGS_DESC",
		getter = function() return Database.IsUsingCharSettings() end,
		setter = function(v) Database.SetUsingCharSettings(v) end,
	}, "character specific profile account")
	AddIndexedToggle(c6Prof, 6, { dbKey = "importMergeBindings", labelKey = "SETTING_IMPORT_MERGE_BINDINGS", descKey = "SETTING_IMPORT_MERGE_BINDINGS_DESC" }, "merge replace import copy")

	local srcDropY = c6Prof:Advance(26, 6)
	local srcCharBtn = Reg(Widgets.CreateStyledButton(c6Prof, c6Prof.innerWidth, 26, function()
		local prof, curKey = GetSelectedCharProfile()
		return string.format(L["PROFILE_SOURCE_CHAR_FORMAT"], FormatCharProfileLabel(prof, curKey)) .. "  |cffaaaaaa[v]|r"
	end, function(self)
		SettingsUI.OpenSourceCharMenu(self)
	end, "secondary", "PROFILE_SOURCE_CHAR_DESC"))
	srcCharBtn:SetPoint("TOPLEFT", c6Prof, "TOPLEFT", 14, srcDropY)

	local cpRowY = c6Prof:Advance(26, 4)
	local cpW = math.floor((c6Prof.innerWidth - 12) / 3)
	for idx, cpDef in ipairs({
		{ key = "PROFILE_BTN_COPY_ALL",      desc = "PROFILE_BTN_COPY_ALL_DESC",      scope = "all",      variant = "primary" },
		{ key = "PROFILE_BTN_COPY_BINDINGS", desc = "PROFILE_BTN_COPY_BINDINGS_DESC", scope = "bindings", variant = "secondary" },
		{ key = "PROFILE_BTN_COPY_SETTINGS", desc = "PROFILE_BTN_COPY_SETTINGS_DESC", scope = "settings", variant = "secondary" },
	}) do
		local b = Reg(Widgets.CreateStyledButton(c6Prof, cpW, 24, function() return L[cpDef.key] end, function()
			local prof = GetSelectedCharProfile()
			if prof and ns.ClickBindingUI and ns.ClickBindingUI.CopyFromCharacterProfile then
				ns.ClickBindingUI.CopyFromCharacterProfile(prof, cpDef.scope)
				SettingsUI.RefreshWindow()
			end
		end, cpDef.variant, cpDef.desc))
		b:SetPoint("TOPLEFT", c6Prof, "TOPLEFT", 14 + ((idx - 1) * (cpW + 6)), cpRowY)
	end
	y6 = c6Prof:Finalize(8)

	local c6Share = Reg(Widgets.CreateCard(p6, "SETTINGS_HEADER_SHARE", y6))
	AddIndexedSegmented(c6Share, 6, {
		labelKey = "SHARE_SCOPE_MENU_TITLE",
		descKey = "SHARE_SCOPE_TOOLTIP_DESC",
		options = SHARE_SCOPE_OPTIONS,
		getter = function() return selectedShareScope or "all" end,
		setter = function(v) selectedShareScope = v; SettingsUI.RefreshWindow() end,
	}, "export import string share scope")

	local shRowY = c6Share:Advance(26, 4)
	local shW = math.floor((c6Share.innerWidth - 12) / 3)
	local expBtn = Reg(Widgets.CreateStyledButton(c6Share, shW, 24, function() return L["SHARE_BTN_EXPORT_STRING"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowExportStringPopup then
			ns.ClickBindingUI.ShowExportStringPopup(selectedShareScope or "all")
		end
	end, "primary", "SHARE_BTN_EXPORT_STRING_DESC"))
	expBtn:SetPoint("TOPLEFT", c6Share, "TOPLEFT", 14, shRowY)

	local impBtn = Reg(Widgets.CreateStyledButton(c6Share, shW, 24, function() return L["SHARE_BTN_IMPORT_STRING"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowImportStringPopup then
			ns.ClickBindingUI.ShowImportStringPopup(selectedShareScope or "all")
		end
	end, "secondary", "SHARE_BTN_IMPORT_STRING_DESC"))
	impBtn:SetPoint("TOPLEFT", c6Share, "TOPLEFT", 14 + shW + 6, shRowY)

	local sumBtn = Reg(Widgets.CreateStyledButton(c6Share, shW, 24, function() return L["SETTINGS_EXPORT_BINDINGS_BTN"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.ShowBindingsExportPopup then
			ns.ClickBindingUI.ShowBindingsExportPopup()
		end
	end, "secondary", "SETTINGS_EXPORT_BINDINGS_DESC"))
	sumBtn:SetPoint("TOPLEFT", c6Share, "TOPLEFT", 14 + ((shW + 6) * 2), shRowY)
	y6 = c6Share:Finalize(8)

	local c6Sys = Reg(Widgets.CreateCard(p6, "SETTINGS_HEADER_GENERAL", y6))
	AddIndexedSegmented(c6Sys, 6, {
		dbKey = "addonLocale",
		defaultValue = "auto",
		labelKey = "LOCALE_MENU_TITLE",
		descKey = "LOCALE_TOOLTIP_DESC",
		options = LOCALE_OPTIONS,
	}, "language locale english deutsch espanol spanish")
	AddIndexedToggle(c6Sys, 6, { dbKey = "showMinimapButton", labelKey = "SETTING_SHOW_MINIMAP_BUTTON", descKey = "SETTING_SHOW_MINIMAP_BUTTON_DESC" }, "minimap icon button")

	local sysRowY = c6Sys:Advance(26, 4)
	local sysHalfW = math.floor((c6Sys.innerWidth - 6) / 2)
	local rstPosBtn = Reg(Widgets.CreateStyledButton(c6Sys, sysHalfW, 24, function() return L["OVERLAY_UNLOCK_BTN_RESET_POS"] end, function()
		SettingsUI.ResetAllOverlayPositions()
	end, "secondary", "OVERLAY_UNLOCK_BTN_RESET_POS_DESC"))
	rstPosBtn:SetPoint("TOPLEFT", c6Sys, "TOPLEFT", 14, sysRowY)

	local dbgBtn = Reg(Widgets.CreateStyledButton(c6Sys, sysHalfW, 24, function() return L["SETTINGS_RUN_DEBUG_BTN"] end, function()
		if ns.ClickBindingUI and ns.ClickBindingUI.RunTaintDiagnostics then
			ns.ClickBindingUI.RunTaintDiagnostics()
		end
	end, "secondary", "SETTINGS_RUN_DEBUG_DESC"))
	dbgBtn:SetPoint("TOPLEFT", c6Sys, "TOPLEFT", 14 + sysHalfW + 6, sysRowY)
	y6 = c6Sys:Finalize(10)
	p6.contentHeight = math.abs(y6) + 12

	win:Hide()
	settingsWindow = win
	SelectTab(1)
	return win
end

--------------------------------------------------------------------------------
-- Overlay-Steuerung & Fenster-Lebenszyklus
--------------------------------------------------------------------------------

function SettingsUI.IsOverlaysUnlocked()
	local hoverUnlocked = ns.UnitHoverTooltip and ns.UnitHoverTooltip.IsMoveUnlocked and ns.UnitHoverTooltip.IsMoveUnlocked() or false
	local heroUnlocked = ns.ClickBindingUI and ns.ClickBindingUI.IsHeroCardPreviewUnlocked and ns.ClickBindingUI.IsHeroCardPreviewUnlocked() or false
	local matrixUnlocked = ns.ClickBindingUI and ns.ClickBindingUI.IsMatrixPreviewUnlocked and ns.ClickBindingUI.IsMatrixPreviewUnlocked() or false
	return hoverUnlocked or heroUnlocked or matrixUnlocked
end

function SettingsUI.SetOverlaysUnlocked(unlocked, silent)
	local target = unlocked and true or false
	if target and InCombatLockdown and InCombatLockdown() then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
		end
		return
	end
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.SetMoveUnlocked then
		ns.UnitHoverTooltip.SetMoveUnlocked(target)
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.SetHeroCardPreviewUnlocked then
		ns.ClickBindingUI.SetHeroCardPreviewUnlocked(target)
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.SetMatrixPreviewUnlocked then
		ns.ClickBindingUI.SetMatrixPreviewUnlocked(target)
	end
	SettingsUI.RefreshWindow()
	if not silent and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(target and L["CHAT_OVERLAYS_UNLOCKED"] or L["CHAT_OVERLAYS_LOCKED"])
	end
end

function SettingsUI.ToggleOverlaysUnlocked(silent)
	SettingsUI.SetOverlaysUnlocked(not SettingsUI.IsOverlaysUnlocked(), silent)
end

function SettingsUI.ResetAllOverlayPositions(silent)
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.ResetPosition then
		ns.UnitHoverTooltip.ResetPosition()
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.ResetHeroCardPosition then
		ns.ClickBindingUI.ResetHeroCardPosition()
	end
	if ns.ClickBindingUI and ns.ClickBindingUI.ResetMatrixPosition then
		ns.ClickBindingUI.ResetMatrixPosition()
	end
	Database.Set("settingsWindowPos", nil)
	if settingsWindow and settingsWindow:IsShown() then
		PositionSettingsWindow(settingsWindow)
	end
	if not silent and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_OVERLAYS_RESET"])
	end
end

function SettingsUI.RefreshWindow()
	if not settingsWindow or not settingsWindow:IsShown() then
		return
	end
	settingsWindow.TitleText:SetText(string.format("%s  |cff888888v%s|r", L["SETTINGS_MENU_TITLE"], Constants.VERSION))
	if settingsWindow.SearchPlaceholder then
		settingsWindow.SearchPlaceholder:SetText(L["UX_SEARCH_PLACEHOLDER"])
	end
	if settingsWindow.QuickHeader then
		settingsWindow.QuickHeader:SetText(L["UX_QUICK_HEADER"])
	end
	for _, qb in ipairs(settingsWindow.QuickButtons or {}) do
		qb:RefreshValue()
	end

	local isSearching = (currentSearchQuery ~= "")
	for i, tabBtn in ipairs(settingsWindow.TabButtons) do
		tabBtn.Text:SetText(L[tabBtn.labelKey] or tabBtn.labelKey)
		local isSelected = (not isSearching) and (i == activeTabIndex)
		tabBtn.ActiveBar:SetShown(isSelected)
		if isSelected then
			tabBtn.Bg:SetColorTexture(0.18, 0.16, 0.08, 0.90)
			tabBtn.Text:SetTextColor(1.0, 0.85, 0.25)
		else
			tabBtn.Bg:SetColorTexture(0, 0, 0, 0)
			tabBtn.Text:SetTextColor(0.82, 0.85, 0.90)
		end
		settingsWindow.Pages[i]:SetShown(isSelected)
	end

	if isSearching then
		settingsWindow.SearchPage:Show()
		RenderSearchResults()
	else
		settingsWindow.SearchPage:Hide()
		for _, ctrl in ipairs(settingsWindow.Controls) do
			if ctrl.RefreshValue then
				ctrl:RefreshValue()
			end
		end
		if activeTabIndex == 3 then
			SettingsUI.RefreshReorderWindow()
		elseif activeTabIndex == 5 then
			RefreshPresetManagerCard()
		end
	end
	UpdateScrollChildHeight()
end

function SettingsUI.OpenSettingsTab(tabIndex)
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_GAMEPAD_STANDBY"])
		end
		return
	end
	local win = EnsureSettingsWindow()
	if Database and Database.SaveCharacterSnapshot then
		Database.SaveCharacterSnapshot()
	end
	if not win:IsShown() then
		PositionSettingsWindow(win)
		win:Show()
	end
	if win.Raise then
		win:Raise()
	end
	if win.SearchBox and currentSearchQuery ~= "" then
		win.SearchBox:SetText("")
	end
	if tabIndex and tabIndex >= 1 and tabIndex <= #NAV_SECTIONS then
		SelectTab(tabIndex)
	else
		SettingsUI.RefreshWindow()
	end
end

function SettingsUI.OpenSettingsMenu()
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_GAMEPAD_STANDBY"])
		end
		return
	end
	local win = EnsureSettingsWindow()
	if win:IsShown() then
		win:Hide()
	else
		if Database and Database.SaveCharacterSnapshot then
			Database.SaveCharacterSnapshot()
		end
		PositionSettingsWindow(win)
		win:Show()
		if win.Raise then
			win:Raise()
		end
		SettingsUI.RefreshWindow()
	end
end

function SettingsUI.HideWindow()
	if settingsWindow and settingsWindow:IsShown() then
		settingsWindow:Hide()
	end
end

--------------------------------------------------------------------------------
-- Zahnrad-Portrait am ClickBindingFrame & Blizzard-Optionen (CanvasLayout)
--------------------------------------------------------------------------------

local clickBindingSettingsBtn = nil

function SettingsUI.AttachToClickBindingFrame()
	if not ClickBindingFrame then
		return
	end
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if clickBindingSettingsBtn then
			clickBindingSettingsBtn:Hide()
			clickBindingSettingsBtn:SetParent(nil)
		end
		return
	end
	if clickBindingSettingsBtn then
		if clickBindingSettingsBtn:GetParent() ~= ClickBindingFrame then
			clickBindingSettingsBtn:SetParent(ClickBindingFrame)
			clickBindingSettingsBtn:ClearAllPoints()
			if ClickBindingFrame.MacrosPortrait then
				clickBindingSettingsBtn:SetPoint("RIGHT", ClickBindingFrame.MacrosPortrait, "LEFT", -5, 0)
			else
				clickBindingSettingsBtn:SetPoint("TOPRIGHT", ClickBindingFrame, "TOPRIGHT", -115, -40)
			end
		end
		clickBindingSettingsBtn:Show()
		return
	end

	local btn = CreateFrame("Button", nil, ClickBindingFrame)
	btn:SetSize(31, 31)
	if ClickBindingFrame.MacrosPortrait then
		btn:SetPoint("RIGHT", ClickBindingFrame.MacrosPortrait, "LEFT", -5, 0)
	else
		btn:SetPoint("TOPRIGHT", ClickBindingFrame, "TOPRIGHT", -115, -40)
	end
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local portrait = btn:CreateTexture(nil, "ARTWORK")
	portrait:SetAllPoints(btn)
	portrait:SetAtlas(Constants.ICON_ATLAS)

	local border = btn:CreateTexture(nil, "OVERLAY", nil, 1)
	border:SetAtlas("Transmog-nav-slot-selected", true)
	border:SetPoint("CENTER")

	local gearBg = btn:CreateTexture(nil, "OVERLAY", nil, 2)
	gearBg:SetSize(16, 16)
	gearBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
	gearBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	btn.GearBg = gearBg

	local gearIcon = btn:CreateTexture(nil, "OVERLAY", nil, 3)
	gearIcon:SetSize(13, 13)
	gearIcon:SetPoint("CENTER", gearBg, "CENTER", 0, 0)
	gearIcon:SetAtlas("questlog-icon-setting")
	btn.GearIcon = gearIcon

	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAtlas("bags-roundhighlight")
	highlight:SetBlendMode("ADD")
	highlight:SetSize(31, 31)
	highlight:SetPoint("CENTER", 0, 1)

	btn:SetScript("OnMouseDown", function(self) self.GearIcon:SetPoint("CENTER", self.GearBg, "CENTER", 1, -1) end)
	btn:SetScript("OnMouseUp", function(self) self.GearIcon:SetPoint("CENTER", self.GearBg, "CENTER", 0, 0) end)
	btn:SetScript("OnClick", function(_, mouseButton)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if mouseButton == "RightButton" and ns.ClickBindingUI and ns.ClickBindingUI.ToggleFreeKeysMatrix then
			ns.ClickBindingUI.ToggleFreeKeysMatrix()
		else
			SettingsUI.OpenSettingsMenu()
		end
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["SETTINGS_BUTTON_TOOLTIP_TITLE"])
		GameTooltip_AddNormalLine(GameTooltip, L["SETTINGS_BUTTON_TOOLTIP_DESC"], true)
		if L["SETTINGS_BUTTON_TOOLTIP_HINT_RIGHT"] then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["SETTINGS_BUTTON_TOOLTIP_HINT_RIGHT"], 0.25, 1.0, 0.35)
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	clickBindingSettingsBtn = btn
end

local blizzardCategoryRegistered = false

function SettingsUI.RegisterBlizzardOptions()
	if blizzardCategoryRegistered or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
		return
	end
	blizzardCategoryRegistered = true

	local canvas = CreateFrame("Frame")
	canvas:Hide()

	local headerIcon = canvas:CreateTexture(nil, "ARTWORK")
	headerIcon:SetSize(24, 24)
	headerIcon:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	headerIcon:SetAtlas(Constants.ICON_ATLAS)

	local headerTitle = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	headerTitle:SetPoint("LEFT", headerIcon, "RIGHT", 10, 0)

	local divider = canvas:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -50)
	divider:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -16, -50)

	local function CloseBlizzardSettingsIfSafe()
		if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel and not (InCombatLockdown and InCombatLockdown()) then
			HideUIPanel(SettingsPanel)
		end
	end

	local rows = {}
	local function CreateCanvasRow(index, getLabelFunc, getBtnTextFunc, onClickFunc)
		local row = CreateFrame("Frame", nil, canvas)
		row:SetHeight(34)
		row:SetPoint("TOPLEFT", canvas, "TOPLEFT", 20, -62 - ((index - 1) * 38))
		row:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -62 - ((index - 1) * 38))

		local rowBg = row:CreateTexture(nil, "BACKGROUND")
		rowBg:SetAllPoints()
		rowBg:SetColorTexture(1, 1, 1, (index % 2 == 1) and 0.03 or 0.01)

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", row, "LEFT", 12, 0)
		label:SetPoint("RIGHT", row, "RIGHT", -230, 0)
		label:SetJustifyH("LEFT")

		local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn:SetSize(200, 24)
		btn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		btn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			onClickFunc()
		end)

		row.RefreshRow = function()
			label:SetText(getLabelFunc() or "")
			btn:SetText(getBtnTextFunc() or "")
		end
		table.insert(rows, row)
	end

	for i, nav in ipairs(NAV_SECTIONS) do
		local tabIdx = i
		CreateCanvasRow(i, function() return L[nav.labelKey] end, function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end, function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(tabIdx)
		end)
	end
	CreateCanvasRow(7, function() return L["BLIZZ_SETTINGS_ROW_WINDOW"] end, function() return L["SETTINGS_OPEN_CLICKCAST_BTN"] end, function()
		CloseBlizzardSettingsIfSafe()
		if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			ns.MinimapButton.ToggleClickCastingWindow()
		end
	end)

	local function RefreshCanvas()
		headerTitle:SetText(string.format("%s  |cff888888v%s|r", L["ADDON_TITLE"] or "Better Click Casting", Constants.VERSION))
		for _, row in ipairs(rows) do row.RefreshRow() end
	end
	canvas:SetScript("OnShow", RefreshCanvas)
	RefreshCanvas()

	local category = Settings.RegisterCanvasLayoutCategory(canvas, L["ADDON_TITLE"] or "Better Click Casting")
	SettingsUI.BlizzardCategory = category
	Settings.RegisterAddOnCategory(category)
end
