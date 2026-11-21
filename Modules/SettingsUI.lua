local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Database = ns.Database

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

SettingsUI.GROUP_MODES = GROUP_MODES
SettingsUI.UNITHOVER_MODES = UNITHOVER_MODES
SettingsUI.UNITHOVER_ANCHORS = UNITHOVER_ANCHORS
SettingsUI.TRAINER_BEHAVIOR_OPTIONS = TRAINER_BEHAVIOR_OPTIONS
SettingsUI.SHARE_SCOPE_OPTIONS = SHARE_SCOPE_OPTIONS
SettingsUI.LOCALE_OPTIONS = LOCALE_OPTIONS

local settingsWindow = nil
local activeTabIndex = 1
local selectedSourceCharKey = nil
local selectedShareScope = "all"
local selectedPresetName = nil

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
	return string.format(L["PRESET_ENTRY_FORMAT"] or "%s (%d)", preset.name or "?", count)
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
	local current = Database.Get("groupingMode") or "modifier"
	return GetShortLabelFromList(GROUP_MODES, current, "GROUP_MODE_MODIFIER_SHORT")
end

function SettingsUI.GetCurrentUnitHoverModeShortLabel()
	local current = Database.Get("unitHoverMode") or "off"
	return GetShortLabelFromList(UNITHOVER_MODES, current, "UNITHOVER_MODE_OFF_SHORT")
end

function SettingsUI.GetCurrentUnitHoverAnchorShortLabel()
	local current = Database.Get("unitHoverAnchor") or "cursor"
	return GetShortLabelFromList(UNITHOVER_ANCHORS, current, "UNITHOVER_ANCHOR_CURSOR_SHORT")
end

function SettingsUI.GetCurrentTrainerBehaviorShortLabel()
	local current = Database.Get("trainerUpgradeBehavior") or "card"
	return GetShortLabelFromList(TRAINER_BEHAVIOR_OPTIONS, current, "TRAINER_BEHAVIOR_CARD_SHORT")
end

function SettingsUI.GetCurrentShareScopeShortLabel()
	return GetShortLabelFromList(SHARE_SCOPE_OPTIONS, selectedShareScope or "all", "SHARE_SCOPE_ALL_SHORT")
end

function SettingsUI.GetCurrentLocaleShortLabel()
	local current = Database.Get("addonLocale") or "auto"
	return GetShortLabelFromList(LOCALE_OPTIONS, current, "LOCALE_OPT_AUTO_SHORT")
end

local function PopulatePresetContextMenu(rootDescription, isQuickLoad)
	rootDescription:CreateTitle(L["PRESET_MENU_TITLE"])
	local selectedPreset, presets = GetSelectedPreset()
	local activeName = Database.GetActivePresetName()

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
			local label = FormatPresetLabel(preset)
			local radio = rootDescription:CreateRadio(label, IsSelected, SetSelected, preset.name)
			radio:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, preset.name)
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
			SettingsUI.OpenSettingsTab(4)
		end)
	end
end

function SettingsUI.OpenPresetMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		PopulatePresetContextMenu(rootDescription, true)
	end)
end

function SettingsUI.OpenTab4PresetMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		PopulatePresetContextMenu(rootDescription, false)
	end)
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
			local label = FormatCharProfileLabel(prof, currentKey)
			local radio = rootDescription:CreateRadio(label, IsSelected, SetSelected, prof.key)
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
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		rootDescription:CreateTitle(L["SHARE_SCOPE_MENU_TITLE"])
		local function IsSelected(val)
			return (selectedShareScope or "all") == val
		end
		local function SetSelected(val)
			selectedShareScope = val
			SettingsUI.RefreshWindow()
		end
		for _, entry in ipairs(SHARE_SCOPE_OPTIONS) do
			rootDescription:CreateRadio(L[entry.labelKey], IsSelected, SetSelected, entry.value)
		end
	end)
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

function SettingsUI.PopulateGroupingMenu(rootDescription)
	PopulateRadioMenu(rootDescription, "GROUP_MENU_TITLE", "groupingMode", "modifier", GROUP_MODES, "GROUP_TOOLTIP_DESC")
	if rootDescription and rootDescription.CreateDivider and rootDescription.CreateCheckbox then
		rootDescription:CreateDivider()
		local cb = rootDescription:CreateCheckbox(
			L["SETTING_COMPACT_LIST_MODE"],
			function()
				return Database.Get("compactListMode") and true or false
			end,
			function()
				Database.Toggle("compactListMode")
			end
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
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		SettingsUI.PopulateGroupingMenu(rootDescription)
	end)
end

function SettingsUI.OpenTrainerBehaviorMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		PopulateRadioMenu(rootDescription, "TRAINER_BEHAVIOR_MENU_TITLE", "trainerUpgradeBehavior", "card", TRAINER_BEHAVIOR_OPTIONS, "TRAINER_BEHAVIOR_TOOLTIP_DESC")
	end)
end

function SettingsUI.OpenLocaleMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end
	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		PopulateRadioMenu(rootDescription, "LOCALE_MENU_TITLE", "addonLocale", "auto", LOCALE_OPTIONS, "LOCALE_TOOLTIP_DESC")
	end)
end

--------------------------------------------------------------------------------
-- UI-Bausteine für das eigene Einstellungs-Fenster (BCCSettingsWindow)
--------------------------------------------------------------------------------

local function CreateSectionHeader(parent, labelKey, yOffset)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
	label:SetText("|cffffd100" .. (L[labelKey] or labelKey) .. "|r")

	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset - 16)
	line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset - 16)
	line:SetColorTexture(0.65, 0.55, 0.30, 0.30)

	label.RefreshValue = function(self)
		self:SetText("|cffffd100" .. (L[labelKey] or labelKey) .. "|r")
	end

	return label, line
end

local function CreateCheckboxControl(parent, yOffset, labelKey, descKey, getterFunc, setterFunc)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)

	local label = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:ClearAllPoints()
	label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	label:SetJustifyH("LEFT")
	label:SetText(L[labelKey])
	cb.Label = label

	cb:SetHitRectInsets(0, -320, 0, 0)

	cb:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		setterFunc(self:GetChecked() and true or false)
	end)

	if descKey and L[descKey] then
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L[labelKey])
			GameTooltip_AddNormalLine(GameTooltip, L[descKey], true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	cb.RefreshValue = function(self)
		local checked = getterFunc() and true or false
		self:SetChecked(checked)
		if self.Label then
			self.Label:SetText(L[labelKey])
			if checked then
				self.Label:SetTextColor(1.0, 0.96, 0.85)
			else
				self.Label:SetTextColor(0.80, 0.80, 0.80)
			end
		end
	end

	return cb
end

local function CreateDBCheckbox(parent, yOffset, dbKey, labelKey, descKey)
	return CreateCheckboxControl(
		parent,
		yOffset,
		labelKey,
		descKey,
		function()
			return Database.Get(dbKey)
		end,
		function(val)
			Database.Set(dbKey, val)
		end
	)
end

local function CreatePillSelectorButton(parent, yOffset, width, getTextFunc, openMenuFunc, tooltipTitleKey, tooltipDescKey)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 390, 26)
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetVertexColor(0.88, 0.88, 0.88, 0.96)
	btn.Bg = bg

	local border = btn:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetAtlas("common-dropdown-c-button-hover")
	border:SetAlpha(0.35)
	btn.Border = border

	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetAtlas("common-dropdown-c-button-hover")
	highlight:SetBlendMode("ADD")
	highlight:SetAlpha(0.55)

	local arrow = btn:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(11, 7)
	arrow:SetPoint("RIGHT", btn, "RIGHT", -12, -1)
	arrow:SetAtlas("common-dropdown-a-button-open")
	btn.Arrow = arrow

	local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", btn, "LEFT", 12, 0)
	text:SetPoint("RIGHT", arrow, "LEFT", -6, 0)
	text:SetJustifyH("LEFT")
	btn.Text = text

	btn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		openMenuFunc(self)
	end)

	if tooltipTitleKey and tooltipDescKey then
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L[tooltipTitleKey])
			GameTooltip_AddNormalLine(GameTooltip, L[tooltipDescKey], true)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	btn.RefreshValue = function(self)
		self.Text:SetText(getTextFunc())
	end

	return btn
end

local function CreateActionButton(parent, yOffset, width, getTextFunc, onClickFunc, tooltipDescKey)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 390, 26)
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
	btn:RegisterForClicks("LeftButtonUp")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetVertexColor(0.95, 0.90, 0.78, 0.98)
	btn.Bg = bg

	local border = btn:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetAtlas("common-dropdown-c-button-hover")
	border:SetAlpha(0.45)
	btn.Border = border

	local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetAtlas("common-dropdown-c-button-hover")
	highlight:SetBlendMode("ADD")
	highlight:SetAlpha(0.60)

	local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn.Text = text

	btn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClickFunc(self)
	end)

	if tooltipDescKey and L[tooltipDescKey] then
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, getTextFunc())
			GameTooltip_AddNormalLine(GameTooltip, L[tooltipDescKey], true)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	btn.RefreshValue = function(self)
		self.Text:SetFontObject("GameFontNormal")
		self.Text:SetText(getTextFunc())
		local maxTextWidth = (self:GetWidth() or 200) - 18
		if self.Text.GetUnboundedStringWidth and self.Text:GetUnboundedStringWidth() > maxTextWidth then
			self.Text:SetFontObject("GameFontNormalSmall")
		end
	end

	return btn
end

local function CreateSliderControl(parent, yOffset, dbKey, minVal, maxVal, stepVal, formatKey)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(492, 42)
	container:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)

	local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", container, "TOPLEFT", 2, 0)
	title:SetJustifyH("LEFT")
	container.Title = title

	local minLabel = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	minLabel:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 2, 0)
	minLabel:SetText(tostring(minVal) .. "%")

	local maxLabel = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	maxLabel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 0)
	maxLabel:SetText(tostring(maxVal) .. "%")

	local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(488, 12)
	slider:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -16)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(stepVal)
	slider:SetObeyStepOnDrag(true)

	if slider.SetBackdrop then
		slider:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 8,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		slider:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
		slider:SetBackdropBorderColor(0.55, 0.48, 0.28, 0.85)
	end

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(16, 20)
	thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	slider:SetThumbTexture(thumb)

	local isUpdatingSlider = false
	slider:SetScript("OnValueChanged", function(_, value)
		local rounded = math.floor((value / stepVal) + 0.5) * stepVal
		title:SetText(string.format(L[formatKey], rounded))
		if not isUpdatingSlider then
			Database.Set(dbKey, rounded)
		end
	end)

	container.RefreshValue = function()
		isUpdatingSlider = true
		local val = tonumber(Database.Get(dbKey)) or minVal
		val = math.max(minVal, math.min(maxVal, val))
		slider:SetValue(val)
		title:SetText(string.format(L[formatKey], val))
		isUpdatingSlider = false
	end

	return container
end

local function SelectTab(tabIndex)
	if not settingsWindow then
		return
	end
	activeTabIndex = tabIndex
	for i, tabBtn in ipairs(settingsWindow.TabButtons) do
		local isSelected = (i == tabIndex)
		if isSelected then
			tabBtn.Bg:SetVertexColor(1.0, 0.92, 0.72, 1.0)
			tabBtn.Border:SetAlpha(0.85)
			tabBtn.Text:SetTextColor(1.0, 0.82, 0.0)
		else
			tabBtn.Bg:SetVertexColor(0.65, 0.65, 0.65, 0.85)
			tabBtn.Border:SetAlpha(0.20)
			tabBtn.Text:SetTextColor(0.82, 0.82, 0.82)
		end
	end
	for i, page in ipairs(settingsWindow.Pages) do
		page:SetShown(i == tabIndex)
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
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

local function EnsureSettingsWindow()
	if settingsWindow then
		return settingsWindow
	end

	local win = CreateFrame("Frame", "BetterClickCastingSettingsFrame", UIParent, "BackdropTemplate")
	win:SetSize(528, 494)
	win:SetFrameStrata("MEDIUM")
	win:SetToplevel(true)
	win:SetFrameLevel(20)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnMouseDown", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	win:SetScript("OnDragStart", function(self)
		if self.Raise then
			self:Raise()
		end
		self:StartMoving()
	end)
	win:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SaveWindowPosition(self)
	end)

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
		win:SetBackdropColor(0.06, 0.07, 0.10, 0.96)
		win:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
	end

	-- Kopfzeile mit Maus-Atlas, Titel und Versionsnummer
	local icon = win:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -14)
	icon:SetAtlas(Constants.ICON_ATLAS)

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	title:SetText(string.format("%s  |cff888888v%s|r", L["SETTINGS_MENU_TITLE"], Constants.VERSION))
	win.TitleText = title

	local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
	-- Eigenes OnClick-Skript statt UIPanelCloseButton_OnClick (HideUIPanel), damit das Fenster auch im Kampf schließt
	closeBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		win:Hide()
	end)

	-- 4 Reiter-Buttons oben
	local tabLabelKeys = {
		"SETTINGS_TAB_CLICKCAST",
		"SETTINGS_TAB_SPELLBOOK",
		"SETTINGS_TAB_UNITHOVER",
		"SETTINGS_TAB_PROFILES",
	}
	win.TabButtons = {}
	win.Pages = {}
	win.Controls = {}

	local tabWidth = 120
	for i, tabKey in ipairs(tabLabelKeys) do
		local tabBtn = CreateFrame("Button", nil, win)
		tabBtn:SetSize(tabWidth, 26)
		tabBtn:SetPoint("TOPLEFT", win, "TOPLEFT", 15 + ((i - 1) * (tabWidth + 6)), -44)
		tabBtn:RegisterForClicks("LeftButtonUp")
		tabBtn.labelKey = tabKey

		local bg = tabBtn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetAtlas("common-dropdown-c-button")
		tabBtn.Bg = bg

		local border = tabBtn:CreateTexture(nil, "BORDER")
		border:SetAllPoints()
		border:SetAtlas("common-dropdown-c-button-hover")
		tabBtn.Border = border

		local highlight = tabBtn:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetAtlas("common-dropdown-c-button-hover")
		highlight:SetBlendMode("ADD")
		highlight:SetAlpha(0.45)

		local text = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("CENTER", tabBtn, "CENTER", 0, 0)
		text:SetText(L[tabKey])
		tabBtn.Text = text

		tabBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			SelectTab(i)
		end)

		win.TabButtons[i] = tabBtn

		local page = CreateFrame("Frame", nil, win)
		page:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -76)
		page:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 10)
		page:Hide()
		win.Pages[i] = page
	end

	local function RegisterControl(ctrl)
		table.insert(win.Controls, ctrl)
		return ctrl
	end

	----------------------------------------------------------------------------
	-- TAB 1: Klickbelegung & Ränge
	----------------------------------------------------------------------------
	local page1 = win.Pages[1]
	RegisterControl(CreateSectionHeader(page1, "SETTINGS_HEADER_CLICKCAST", -6))

	RegisterControl(CreatePillSelectorButton(
		page1,
		-30,
		240,
		function()
			return string.format(L["GROUP_BUTTON_FORMAT"], SettingsUI.GetCurrentGroupShortLabel())
		end,
		function(owner)
			SettingsUI.OpenGroupingMenu(owner)
		end,
		"GROUP_TOOLTIP_TITLE",
		"GROUP_TOOLTIP_DESC"
	))

	local trainerBtn = RegisterControl(CreatePillSelectorButton(
		page1,
		-30,
		240,
		function()
			return string.format(L["TRAINER_BEHAVIOR_BUTTON_FORMAT"], SettingsUI.GetCurrentTrainerBehaviorShortLabel())
		end,
		function(owner)
			SettingsUI.OpenTrainerBehaviorMenu(owner)
		end,
		"TRAINER_BEHAVIOR_MENU_TITLE",
		"TRAINER_BEHAVIOR_TOOLTIP_DESC"
	))
	trainerBtn:ClearAllPoints()
	trainerBtn:SetPoint("TOPLEFT", page1, "TOPLEFT", 270, -30)

	RegisterControl(CreateDBCheckbox(page1, -64, "showRankInName", "SETTING_SHOW_RANK_IN_NAME", "SETTING_SHOW_RANK_IN_NAME_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -92, "highlightDownranks", "SETTING_HIGHLIGHT_DOWNRANKS", "SETTING_HIGHLIGHT_DOWNRANKS_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -120, "showRankSwitcher", "SETTING_SHOW_RANK_SWITCHER", "SETTING_SHOW_RANK_SWITCHER_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -148, "showLineManaCost", "SETTING_SHOW_LINE_MANA_COST", "SETTING_SHOW_LINE_MANA_COST_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -176, "moveInteractionsToBottom", "SETTING_MOVE_INTERACTIONS_BOTTOM", "SETTING_MOVE_INTERACTIONS_BOTTOM_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -204, "enableSmartRankRules", "SETTING_ENABLE_SMART_RULES", "SETTING_ENABLE_SMART_RULES_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -232, "showLineTooltips", "SETTING_SHOW_LINE_TOOLTIPS", "SETTING_SHOW_LINE_TOOLTIPS_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -260, "compactListMode", "SETTING_COMPACT_LIST_MODE", "SETTING_COMPACT_LIST_MODE_DESC"))

	local upgradeBtn = RegisterControl(CreateActionButton(
		page1,
		-296,
		492,
		function()
			if ClickBindingFrame and ClickBindingFrame:IsShown() and ns.ClickBindingUI and ns.ClickBindingUI.CountUpgradeableBindings then
				local count = ns.ClickBindingUI.CountUpgradeableBindings()
				if count > 0 then
					return string.format(L["ACTION_UPGRADE_ALL_MAX_FORMAT"], count)
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
		"ACTION_UPGRADE_ALL_MAX_DESC"
	))
	win.UpgradeAllBtn = upgradeBtn

	RegisterControl(CreateActionButton(
		page1,
		-330,
		240,
		function()
			return L["SETTINGS_OPEN_CLICKCAST_BTN"]
		end,
		function()
			if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
				ns.MinimapButton.ToggleClickCastingWindow()
			end
		end,
		nil
	))

	local matrixBtn = RegisterControl(CreateActionButton(
		page1,
		-330,
		240,
		function()
			return L["SETTINGS_FREE_KEYS_MATRIX_BTN"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ToggleFreeKeysMatrix then
				ns.ClickBindingUI.ToggleFreeKeysMatrix()
			end
		end,
		"SETTINGS_FREE_KEYS_MATRIX_DESC"
	))
	matrixBtn:ClearAllPoints()
	matrixBtn:SetPoint("TOPLEFT", page1, "TOPLEFT", 270, -330)

	local exportBtn = RegisterControl(CreateActionButton(
		page1,
		-364,
		240,
		function()
			return L["SETTINGS_EXPORT_BINDINGS_BTN"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ShowBindingsExportPopup then
				ns.ClickBindingUI.ShowBindingsExportPopup()
			end
		end,
		"SETTINGS_EXPORT_BINDINGS_DESC"
	))

	local reorderBtn1 = RegisterControl(CreateActionButton(
		page1,
		-364,
		240,
		function()
			return L["SETTINGS_REORDER_BTN"]
		end,
		function()
			SettingsUI.ToggleReorderWindow()
		end,
		"SETTINGS_REORDER_DESC"
	))
	reorderBtn1:ClearAllPoints()
	reorderBtn1:SetPoint("TOPLEFT", page1, "TOPLEFT", 270, -364)

	----------------------------------------------------------------------------
	-- TAB 2: Zauberbuch & Allgemein
	----------------------------------------------------------------------------
	local page2 = win.Pages[2]
	RegisterControl(CreateSectionHeader(page2, "SETTINGS_HEADER_SPELLBOOK", -6))

	RegisterControl(CreateDBCheckbox(page2, -30, "quickBindSpellbook", "SETTING_QUICK_BIND_SPELLBOOK", "SETTING_QUICK_BIND_SPELLBOOK_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -58, "showSpellbookBadges", "SETTING_SHOW_SPELLBOOK_BADGES", "SETTING_SHOW_SPELLBOOK_BADGES_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -86, "autoShowAllRanks", "SETTING_AUTO_SHOW_ALL_RANKS", "SETTING_AUTO_SHOW_ALL_RANKS_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -114, "autoSelectPrimarySpellTab", "SETTING_AUTO_SELECT_PRIMARY_TAB", "SETTING_AUTO_SELECT_PRIMARY_TAB_DESC"))

	RegisterControl(CreateSectionHeader(page2, "SETTINGS_HEADER_GENERAL", -152))
	RegisterControl(CreateDBCheckbox(page2, -176, "showMinimapButton", "SETTING_SHOW_MINIMAP_BUTTON", "SETTING_SHOW_MINIMAP_BUTTON_DESC"))

	RegisterControl(CreatePillSelectorButton(
		page2,
		-210,
		492,
		function()
			return string.format(L["LOCALE_BUTTON_FORMAT"], SettingsUI.GetCurrentLocaleShortLabel())
		end,
		function(owner)
			SettingsUI.OpenLocaleMenu(owner)
		end,
		"LOCALE_MENU_TITLE",
		"LOCALE_TOOLTIP_DESC"
	))

	RegisterControl(CreateActionButton(
		page2,
		-248,
		290,
		function()
			if SettingsUI.IsOverlaysUnlocked() then
				return L["OVERLAY_UNLOCK_BTN_LOCK_ALL"]
			end
			return L["OVERLAY_UNLOCK_BTN_UNLOCK_ALL"]
		end,
		function()
			SettingsUI.ToggleOverlaysUnlocked()
		end,
		"SETTING_UNITHOVER_UNLOCK_MOVE_DESC"
	))

	local resetPosBtn = RegisterControl(CreateActionButton(
		page2,
		-248,
		190,
		function()
			return L["OVERLAY_UNLOCK_BTN_RESET_POS"]
		end,
		function()
			SettingsUI.ResetAllOverlayPositions()
		end,
		"OVERLAY_UNLOCK_BTN_RESET_POS_DESC"
	))
	resetPosBtn:ClearAllPoints()
	resetPosBtn:SetPoint("TOPLEFT", page2, "TOPLEFT", 320, -248)

	RegisterControl(CreateActionButton(
		page2,
		-284,
		492,
		function()
			return L["SETTINGS_RUN_DEBUG_BTN"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.RunTaintDiagnostics then
				ns.ClickBindingUI.RunTaintDiagnostics()
			end
		end,
		"SETTINGS_RUN_DEBUG_DESC"
	))

	----------------------------------------------------------------------------
	-- TAB 3: Unit-Frame Hover-Overlay
	----------------------------------------------------------------------------
	local page3 = win.Pages[3]
	RegisterControl(CreateSectionHeader(page3, "SETTINGS_HEADER_UNITHOVER", -6))

	RegisterControl(CreatePillSelectorButton(
		page3,
		-30,
		240,
		function()
			return string.format(L["UNITHOVER_MODE_BUTTON_FORMAT"], SettingsUI.GetCurrentUnitHoverModeShortLabel())
		end,
		function(owner)
			if MenuUtil and MenuUtil.CreateContextMenu then
				MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
					PopulateRadioMenu(rootDescription, "UNITHOVER_MODE_MENU_TITLE", "unitHoverMode", "off", UNITHOVER_MODES, "UNITHOVER_MODE_TOOLTIP_DESC")
				end)
			end
		end,
		"UNITHOVER_MODE_MENU_TITLE",
		"UNITHOVER_MODE_TOOLTIP_DESC"
	))

	local anchorBtn = RegisterControl(CreatePillSelectorButton(
		page3,
		-30,
		240,
		function()
			return string.format(L["UNITHOVER_ANCHOR_BUTTON_FORMAT"], SettingsUI.GetCurrentUnitHoverAnchorShortLabel())
		end,
		function(owner)
			if MenuUtil and MenuUtil.CreateContextMenu then
				MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
					PopulateRadioMenu(rootDescription, "UNITHOVER_ANCHOR_MENU_TITLE", "unitHoverAnchor", "cursor", UNITHOVER_ANCHORS, "UNITHOVER_ANCHOR_TOOLTIP_DESC")
				end)
			end
		end,
		"UNITHOVER_ANCHOR_MENU_TITLE",
		"UNITHOVER_ANCHOR_TOOLTIP_DESC"
	))
	anchorBtn:ClearAllPoints()
	anchorBtn:SetPoint("TOPLEFT", page3, "TOPLEFT", 270, -30)

	RegisterControl(CreateSliderControl(page3, -68, "unitHoverScale", 70, 150, 5, "SETTING_UNITHOVER_SCALE_FORMAT"))
	RegisterControl(CreateSliderControl(page3, -118, "unitHoverAlpha", 30, 100, 5, "SETTING_UNITHOVER_ALPHA_FORMAT"))

	RegisterControl(CreateDBCheckbox(page3, -168, "unitHoverShowMana", "SETTING_UNITHOVER_SHOW_MANA", "SETTING_UNITHOVER_SHOW_MANA_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -196, "unitHoverShowRankTags", "SETTING_UNITHOVER_SHOW_RANK_TAGS", "SETTING_UNITHOVER_SHOW_RANK_TAGS_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -224, "unitHoverShowRange", "SETTING_UNITHOVER_SHOW_RANGE", "SETTING_UNITHOVER_SHOW_RANGE_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -252, "unitHoverShowInCombat", "SETTING_UNITHOVER_SHOW_IN_COMBAT", "SETTING_UNITHOVER_SHOW_IN_COMBAT_DESC"))

	local unlockMoveCb = RegisterControl(CreateCheckboxControl(
		page3,
		-280,
		"SETTING_UNITHOVER_UNLOCK_MOVE",
		"SETTING_UNITHOVER_UNLOCK_MOVE_DESC",
		function()
			return SettingsUI.IsOverlaysUnlocked()
		end,
		function(val)
			SettingsUI.SetOverlaysUnlocked(val)
		end
	))
	win.UnlockMoveCheckbox = unlockMoveCb

	RegisterControl(CreateActionButton(
		page3,
		-318,
		492,
		function()
			return L["SETTINGS_REORDER_BTN"]
		end,
		function()
			SettingsUI.ToggleReorderWindow()
		end,
		"SETTINGS_REORDER_DESC"
	))

	----------------------------------------------------------------------------
	-- TAB 4: Binding-Presets, Charakter-Übernahme & Import/Export
	----------------------------------------------------------------------------
	local page4 = win.Pages[4]
	RegisterControl(CreateSectionHeader(page4, "SETTINGS_HEADER_PRESETS", -6))

	RegisterControl(CreatePillSelectorButton(
		page4,
		-28,
		492,
		function()
			local preset = GetSelectedPreset()
			return string.format(L["PRESET_SELECTED_FORMAT"], FormatPresetLabel(preset))
		end,
		function(owner)
			SettingsUI.OpenTab4PresetMenu(owner)
		end,
		"PRESET_TOOLTIP_TITLE",
		"PRESET_TOOLTIP_DESC"
	))

	RegisterControl(CreateActionButton(
		page4,
		-62,
		117,
		function()
			return L["PRESET_BTN_LOAD"]
		end,
		function()
			local preset = GetSelectedPreset()
			if preset and ns.ClickBindingUI and ns.ClickBindingUI.LoadPreset then
				ns.ClickBindingUI.LoadPreset(preset)
				SettingsUI.RefreshWindow()
			elseif ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
				ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
					if saved and saved.name then
						selectedPresetName = saved.name
					end
					SettingsUI.RefreshWindow()
				end)
			end
		end,
		"PRESET_BTN_LOAD_DESC"
	))

	local newPresetBtn = RegisterControl(CreateActionButton(
		page4,
		-62,
		117,
		function()
			return L["PRESET_BTN_NEW"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
				ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
					if saved and saved.name then
						selectedPresetName = saved.name
					end
					SettingsUI.RefreshWindow()
				end)
			end
		end,
		"PRESET_BTN_NEW_DESC"
	))
	newPresetBtn:ClearAllPoints()
	newPresetBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 143, -62)

	local overwritePresetBtn = RegisterControl(CreateActionButton(
		page4,
		-62,
		117,
		function()
			return L["PRESET_BTN_OVERWRITE"]
		end,
		function()
			local preset = GetSelectedPreset()
			if preset and preset.name and ns.ClickBindingUI and ns.ClickBindingUI.SavePresetByName then
				ns.ClickBindingUI.SavePresetByName(preset.name)
				SettingsUI.RefreshWindow()
			elseif ns.ClickBindingUI and ns.ClickBindingUI.ShowNewPresetPopup then
				ns.ClickBindingUI.ShowNewPresetPopup("", function(saved)
					if saved and saved.name then
						selectedPresetName = saved.name
					end
					SettingsUI.RefreshWindow()
				end)
			end
		end,
		"PRESET_BTN_OVERWRITE_DESC"
	))
	overwritePresetBtn:ClearAllPoints()
	overwritePresetBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 268, -62)

	local deletePresetBtn = RegisterControl(CreateActionButton(
		page4,
		-62,
		117,
		function()
			return L["PRESET_BTN_DELETE"]
		end,
		function()
			local preset = GetSelectedPreset()
			if preset and preset.name and ns.ClickBindingUI and ns.ClickBindingUI.DeletePresetByName then
				ns.ClickBindingUI.DeletePresetByName(preset.name)
				selectedPresetName = nil
				SettingsUI.RefreshWindow()
			end
		end,
		"PRESET_BTN_DELETE_DESC"
	))
	deletePresetBtn:ClearAllPoints()
	deletePresetBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 393, -62)

	RegisterControl(CreateSectionHeader(page4, "SETTINGS_HEADER_PROFILES", -98))

	RegisterControl(CreateCheckboxControl(
		page4,
		-120,
		"SETTING_USE_CHAR_SETTINGS",
		"SETTING_USE_CHAR_SETTINGS_DESC",
		function()
			return Database.IsUsingCharSettings()
		end,
		function(val)
			Database.SetUsingCharSettings(val)
		end
	))

	RegisterControl(CreateDBCheckbox(page4, -146, "importMergeBindings", "SETTING_IMPORT_MERGE_BINDINGS", "SETTING_IMPORT_MERGE_BINDINGS_DESC"))

	RegisterControl(CreatePillSelectorButton(
		page4,
		-178,
		492,
		function()
			local prof, currentKey = GetSelectedCharProfile()
			return string.format(L["PROFILE_SOURCE_CHAR_FORMAT"], FormatCharProfileLabel(prof, currentKey))
		end,
		function(owner)
			SettingsUI.OpenSourceCharMenu(owner)
		end,
		"PROFILE_SOURCE_MENU_TITLE",
		"PROFILE_SOURCE_CHAR_DESC"
	))

	RegisterControl(CreateActionButton(
		page4,
		-212,
		158,
		function()
			return L["PROFILE_BTN_COPY_ALL"]
		end,
		function()
			local prof = GetSelectedCharProfile()
			if prof and ns.ClickBindingUI and ns.ClickBindingUI.CopyFromCharacterProfile then
				ns.ClickBindingUI.CopyFromCharacterProfile(prof, "all")
				SettingsUI.RefreshWindow()
			end
		end,
		"PROFILE_BTN_COPY_ALL_DESC"
	))

	local copyBindsBtn = RegisterControl(CreateActionButton(
		page4,
		-212,
		158,
		function()
			return L["PROFILE_BTN_COPY_BINDINGS"]
		end,
		function()
			local prof = GetSelectedCharProfile()
			if prof and ns.ClickBindingUI and ns.ClickBindingUI.CopyFromCharacterProfile then
				ns.ClickBindingUI.CopyFromCharacterProfile(prof, "bindings")
				SettingsUI.RefreshWindow()
			end
		end,
		"PROFILE_BTN_COPY_BINDINGS_DESC"
	))
	copyBindsBtn:ClearAllPoints()
	copyBindsBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 185, -212)

	local copySettingsBtn = RegisterControl(CreateActionButton(
		page4,
		-212,
		158,
		function()
			return L["PROFILE_BTN_COPY_SETTINGS"]
		end,
		function()
			local prof = GetSelectedCharProfile()
			if prof and ns.ClickBindingUI and ns.ClickBindingUI.CopyFromCharacterProfile then
				ns.ClickBindingUI.CopyFromCharacterProfile(prof, "settings")
				SettingsUI.RefreshWindow()
			end
		end,
		"PROFILE_BTN_COPY_SETTINGS_DESC"
	))
	copySettingsBtn:ClearAllPoints()
	copySettingsBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 352, -212)

	RegisterControl(CreateSectionHeader(page4, "SETTINGS_HEADER_SHARE", -250))

	RegisterControl(CreatePillSelectorButton(
		page4,
		-272,
		492,
		function()
			return string.format(L["SHARE_SCOPE_BUTTON_FORMAT"], SettingsUI.GetCurrentShareScopeShortLabel())
		end,
		function(owner)
			SettingsUI.OpenShareScopeMenu(owner)
		end,
		"SHARE_SCOPE_MENU_TITLE",
		"SHARE_SCOPE_TOOLTIP_DESC"
	))

	RegisterControl(CreateActionButton(
		page4,
		-306,
		240,
		function()
			return L["SHARE_BTN_EXPORT_STRING"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ShowExportStringPopup then
				ns.ClickBindingUI.ShowExportStringPopup(selectedShareScope or "all")
			end
		end,
		"SHARE_BTN_EXPORT_STRING_DESC"
	))

	local importStrBtn = RegisterControl(CreateActionButton(
		page4,
		-306,
		240,
		function()
			return L["SHARE_BTN_IMPORT_STRING"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ShowImportStringPopup then
				ns.ClickBindingUI.ShowImportStringPopup(selectedShareScope or "all")
			end
		end,
		"SHARE_BTN_IMPORT_STRING_DESC"
	))
	importStrBtn:ClearAllPoints()
	importStrBtn:SetPoint("TOPLEFT", page4, "TOPLEFT", 270, -306)

	RegisterControl(CreateActionButton(
		page4,
		-340,
		492,
		function()
			return L["SETTINGS_EXPORT_BINDINGS_BTN"]
		end,
		function()
			if ns.ClickBindingUI and ns.ClickBindingUI.ShowBindingsExportPopup then
				ns.ClickBindingUI.ShowBindingsExportPopup()
			end
		end,
		"SETTINGS_EXPORT_BINDINGS_DESC"
	))

	win:Hide()
	settingsWindow = win
	SelectTab(1)
	return win
end

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
	if settingsWindow.TitleText then
		settingsWindow.TitleText:SetText(string.format("%s  |cff888888v%s|r", L["SETTINGS_MENU_TITLE"], Constants.VERSION))
	end
	if settingsWindow.TabButtons then
		for _, tabBtn in ipairs(settingsWindow.TabButtons) do
			if tabBtn.Text and tabBtn.labelKey then
				tabBtn.Text:SetText(L[tabBtn.labelKey])
			end
		end
	end
	for _, ctrl in ipairs(settingsWindow.Controls) do
		if ctrl.RefreshValue then
			ctrl:RefreshValue()
		end
	end
	if SettingsUI.RefreshReorderWindow then
		SettingsUI.RefreshReorderWindow()
	end
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
	if tabIndex and tabIndex >= 1 and tabIndex <= 4 then
		SelectTab(tabIndex)
	end
	SettingsUI.RefreshWindow()
end

function SettingsUI.HideWindow()
	if settingsWindow and settingsWindow:IsShown() then
		settingsWindow:Hide()
	end
	if SettingsUI.HideReorderWindow then
		SettingsUI.HideReorderWindow()
	end
end

--------------------------------------------------------------------------------
-- Drag-&-Drop Reorder-Editor für Maustasten (inkl. MB6..MB31) & Matrix-Modifikatoren
--------------------------------------------------------------------------------
local reorderWindow = nil
local REORDER_ROW_H = 26
local REORDER_ROW_GAP = 2

local function GetMouseButtonDisplayLabel(buttonName)
	local norm = Constants.NormalizeMouseButtonName(buttonName)
	local short = Constants.GetShortButtonName(norm)
	local full = short
	if norm == "LeftButton" then
		full = L["GROUP_BUTTON_LEFT"] or "Left Click"
	elseif norm == "RightButton" then
		full = L["GROUP_BUTTON_RIGHT"] or "Right Click"
	elseif norm == "MiddleButton" then
		full = L["GROUP_BUTTON_MIDDLE"] or "Middle Click"
	else
		local num = tonumber(string.match(tostring(norm), "^Button(%d+)$"))
		if num then
			full = string.format(L["GROUP_BUTTON_NUMBER_FORMAT"] or "Mouse Button %d", num)
		end
	end
	return string.format("|cffffd100%s|r  |cffffffff%s|r", short, full)
end

local function EnsureReorderListRow(scrollChild, rowsPool, idx, isButtonList)
	if rowsPool[idx] then
		return rowsPool[idx]
	end
	local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
	row:SetHeight(REORDER_ROW_H)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")

	if row.SetBackdrop then
		row:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		row:SetBackdropColor(0.11, 0.14, 0.20, 0.92)
		row:SetBackdropBorderColor(0.32, 0.42, 0.58, 0.85)
	end

	local handleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	handleText:SetPoint("LEFT", row, "LEFT", 6, 0)
	handleText:SetText("|cff8899bb::|r")
	row.HandleText = handleText

	local labelOffsetLeft = 22
	if isButtonList then
		local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		cb:SetSize(20, 20)
		cb:SetPoint("LEFT", row, "LEFT", 18, 0)
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
		cb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		row.ColCheckbox = cb
		labelOffsetLeft = 40
	end

	local downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	downBtn:SetSize(20, 20)
	downBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	downBtn:SetText("v")
	downBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if row.onMoveDelta then
			row.onMoveDelta(1)
		end
	end)
	row.DownBtn = downBtn

	local upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	upBtn:SetSize(20, 20)
	upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
	upBtn:SetText("^")
	upBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if row.onMoveDelta then
			row.onMoveDelta(-1)
		end
	end)
	row.UpBtn = upBtn

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", row, "LEFT", labelOffsetLeft, 0)
	label:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	row.Label = label

	row:SetScript("OnEnter", function(self)
		if not (reorderWindow and reorderWindow.dragState) then
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
		if not (reorderWindow and reorderWindow.dragState and reorderWindow.dragState.itemKey == self.itemKey) then
			if self.SetBackdropBorderColor then
				self:SetBackdropBorderColor(0.32, 0.42, 0.58, 0.85)
			end
		end
	end)

	row:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and reorderWindow and self.itemKey then
			GameTooltip:Hide()
			reorderWindow.dragState = {
				listType = isButtonList and "button" or "modifier",
				itemKey = self.itemKey,
				scrollChild = scrollChild,
			}
			SettingsUI.RefreshReorderWindow()
		end
	end)

	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and reorderWindow and reorderWindow.dragState then
			reorderWindow.dragState = nil
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			SettingsUI.RefreshReorderWindow()
		end
	end)

	rowsPool[idx] = row
	return row
end

local function EnsureReorderWindow()
	if reorderWindow then
		return reorderWindow
	end

	local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	f:SetSize(560, 490)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
		f:SetBackdropColor(0.06, 0.07, 0.10, 0.97)
		f:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
	end

	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
	icon:SetAtlas(Constants.ICON_ATLAS)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	f.Title = title

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		f:Hide()
	end)

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
	subtitle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetWordWrap(true)
	f.Subtitle = subtitle

	local function CreateListBox(xOffset, width, height)
		local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
		box:SetSize(width, height)
		box:SetPoint("TOPLEFT", f, "TOPLEFT", xOffset, -88)
		if box.SetBackdrop then
			box:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 8,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			box:SetBackdropColor(0.04, 0.05, 0.08, 0.90)
			box:SetBackdropBorderColor(0.45, 0.45, 0.55, 0.85)
		end

		local scrollFrame = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
		scrollFrame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

		local scrollChild = CreateFrame("Frame", nil, scrollFrame)
		scrollChild:SetSize(width - 34, 1)
		scrollFrame:SetScrollChild(scrollChild)

		box.ScrollFrame = scrollFrame
		box.ScrollChild = scrollChild
		box.Rows = {}
		return box
	end

	local leftHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	leftHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -70)
	f.LeftHeader = leftHeader

	local rightHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rightHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 288, -70)
	f.RightHeader = rightHeader

	f.LeftBox = CreateListBox(16, 256, 316)
	f.RightBox = CreateListBox(288, 256, 350)

	local addMmoBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	addMmoBtn:SetSize(256, 26)
	addMmoBtn:SetPoint("TOPLEFT", f.LeftBox, "BOTTOMLEFT", 0, -8)
	addMmoBtn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(self, function(_, rootDescription)
				rootDescription:CreateTitle(L["REORDER_ADD_MMO_MENU_TITLE"])
				rootDescription:SetScrollMode(280)
				for n = 6, 31 do
					local btnKey = "Button" .. tostring(n)
					local short = "MB" .. tostring(n)
					local full = string.format(L["GROUP_BUTTON_NUMBER_FORMAT"] or "Mouse Button %d", n)
					local isVisible = Database.IsMatrixButtonColumnVisible and Database.IsMatrixButtonColumnVisible(btnKey)
					local label = isVisible and string.format("|cff40ff59%s|r (%s)", short, full) or string.format("|cffffd100%s|r (%s)", short, full)
					rootDescription:CreateButton(label, function()
						if Database.AddMouseButtonToOrder then
							Database.AddMouseButtonToOrder(btnKey, true)
						end
						SettingsUI.RefreshReorderWindow()
					end)
				end
			end)
		end
	end)
	f.AddMmoBtn = addMmoBtn

	local presetMmbBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	presetMmbBtn:SetSize(256, 26)
	presetMmbBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
	presetMmbBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if Database.ApplyMiddleMouseCenterOrder then
			Database.ApplyMiddleMouseCenterOrder()
		end
		SettingsUI.RefreshReorderWindow()
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_ORDER_MMB_CENTER"])
		end
	end)
	f.PresetMmbBtn = presetMmbBtn

	local resetOrderBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	resetOrderBtn:SetSize(256, 26)
	resetOrderBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
	resetOrderBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if Database.ResetButtonAndModifierOrder then
			Database.ResetButtonAndModifierOrder()
		end
		SettingsUI.RefreshReorderWindow()
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_ORDER_RESET"])
		end
	end)
	f.ResetOrderBtn = resetOrderBtn

	-- Live Drag-&-Drop Tracking: Berechnet aus der Maus-Y-Position die Zielzeile und sortiert direkt um
	f:SetScript("OnUpdate", function(self)
		local ds = self.dragState
		if not ds then
			return
		end
		if not IsMouseButtonDown("LeftButton") then
			self.dragState = nil
			SettingsUI.RefreshReorderWindow()
			return
		end
		local sc = ds.scrollChild
		if not sc or not sc:GetTop() then
			return
		end
		local _, cursorY = GetCursorPosition()
		local scale = sc:GetEffectiveScale() or 1
		cursorY = cursorY / scale
		local relY = sc:GetTop() - cursorY
		local rowPitch = REORDER_ROW_H + REORDER_ROW_GAP
		local targetIdx = math.floor(relY / rowPitch) + 1
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
					if mId == ds.itemKey then
						curVisualIdx = i
						break
					end
				end
				if curVisualIdx and targetIdx ~= curVisualIdx then
					local targetModOrder = visibleMods[targetIdx]
					local fullOrder = Database.GetOrderedModifierIDs and Database.GetOrderedModifierIDs() or {}
					local fullTargetIdx = nil
					for i, id in ipairs(fullOrder) do
						if id == targetModOrder then
							fullTargetIdx = i
							break
						end
					end
					if fullTargetIdx and Database.MoveModifierInOrder then
						Database.MoveModifierInOrder(ds.itemKey, fullTargetIdx)
						SettingsUI.RefreshReorderWindow()
					end
				end
			end
		end
	end)

	f:SetScript("OnHide", function(self)
		self.dragState = nil
	end)

	f:Hide()
	reorderWindow = f
	return f
end

function SettingsUI.RefreshReorderWindow()
	if not reorderWindow or not reorderWindow:IsShown() then
		return
	end
	local f = reorderWindow
	f.Title:SetText(L["REORDER_WINDOW_TITLE"])
	f.Subtitle:SetText(L["REORDER_WINDOW_SUBTITLE"])
	f.LeftHeader:SetText("|cffffd100" .. L["REORDER_HDR_MOUSE_BUTTONS"] .. "|r")
	f.RightHeader:SetText("|cff99ccff" .. L["REORDER_HDR_MODIFIERS"] .. "|r")
	f.AddMmoBtn:SetText(L["REORDER_ADD_MMO_BTN"])
	f.PresetMmbBtn:SetText(L["REORDER_PRESET_MMB_CENTER_BTN"])
	f.ResetOrderBtn:SetText(L["REORDER_RESET_BTN"])

	local rowPitch = REORDER_ROW_H + REORDER_ROW_GAP

	-- 1. Linke Liste: Maustasten
	local buttons = Database.GetOrderedMouseButtons and Database.GetOrderedMouseButtons(true) or {}
	local leftChild = f.LeftBox.ScrollChild
	local leftWidth = leftChild:GetWidth()
	for idx, btnName in ipairs(buttons) do
		local row = EnsureReorderListRow(leftChild, f.LeftBox.Rows, idx, true)
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
		local isDragging = f.dragState and f.dragState.listType == "button" and f.dragState.itemKey == btnName
		if row.SetBackdropColor then
			if isDragging then
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

	-- 2. Rechte Liste: Matrix-Modifikatoren
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
		local row = EnsureReorderListRow(rightChild, f.RightBox.Rows, idx, false)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", rightChild, "TOPLEFT", 0, -((idx - 1) * rowPitch))
		row:SetWidth(rightWidth)
		row.itemKey = modRow.modOrder
		local modTitle = L[modRow.labelKey] or modRow.fallback
		row.Label:SetText(string.format("|cff888888%d.|r |cffb8d8ff%s|r", idx, modTitle))
		row.UpBtn:SetEnabled(idx > 1)
		row.DownBtn:SetEnabled(idx < #visibleMods)
		row.onMoveDelta = function(delta)
			local targetVisual = visibleMods[idx + delta]
			if targetVisual and Database.GetOrderedModifierIDs and Database.MoveModifierInOrder then
				local fullOrder = Database.GetOrderedModifierIDs()
				for fullIdx, id in ipairs(fullOrder) do
					if id == targetVisual.modOrder then
						Database.MoveModifierInOrder(modRow.modOrder, fullIdx)
						SettingsUI.RefreshReorderWindow()
						break
					end
				end
			end
		end
		local isDragging = f.dragState and f.dragState.listType == "modifier" and f.dragState.itemKey == modRow.modOrder
		if row.SetBackdropColor then
			if isDragging then
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
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_GAMEPAD_STANDBY"])
		end
		return
	end
	local f = EnsureReorderWindow()
	f:Show()
	if f.Raise then
		f:Raise()
	end
	SettingsUI.RefreshReorderWindow()
end

function SettingsUI.HideReorderWindow()
	if reorderWindow and reorderWindow:IsShown() then
		reorderWindow:Hide()
	end
end

function SettingsUI.ToggleReorderWindow()
	if reorderWindow and reorderWindow:IsShown() then
		reorderWindow:Hide()
		return
	end
	SettingsUI.ShowReorderWindow()
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

	-- Moderner runder Portrait-Button links neben MacrosPortrait mit nativem Zahnrad-Badge (questlog-icon-setting)
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
	btn.Portrait = portrait

	local border = btn:CreateTexture(nil, "OVERLAY", nil, 1)
	border:SetAtlas("Transmog-nav-slot-selected", true)
	border:SetPoint("CENTER")
	btn.Frame = border

	-- Kleines dunkles Badge unten rechts mit Blizzards scharfem Zahnrad-Atlas
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

	btn:SetScript("OnMouseDown", function(self)
		self.GearIcon:SetPoint("CENTER", self.GearBg, "CENTER", 1, -1)
	end)

	btn:SetScript("OnMouseUp", function(self)
		self.GearIcon:SetPoint("CENTER", self.GearBg, "CENTER", 0, 0)
	end)

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

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	clickBindingSettingsBtn = btn
end

local blizzardCategoryRegistered = false

-- Registriert Better Click Casting unter Esc -> Optionen -> AddOns über ein isoliertes CanvasLayout,
-- damit Blizzards geteilte SettingsList.ScrollBox und die globale Optionssuche zu 100 % ungetaintet bleiben.
function SettingsUI.RegisterBlizzardOptions()
	if blizzardCategoryRegistered then
		return
	end
	if not Settings
		or not Settings.RegisterCanvasLayoutCategory
		or not Settings.RegisterAddOnCategory
	then
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
	headerTitle:SetJustifyH("LEFT")

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
	local function CreateCanvasRow(index, getLabelFunc, getBtnTextFunc, getTooltipDescFunc, onClickFunc)
		local row = CreateFrame("Frame", nil, canvas)
		row:SetHeight(36)
		row:SetPoint("TOPLEFT", canvas, "TOPLEFT", 20, -64 - ((index - 1) * 42))
		row:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -64 - ((index - 1) * 42))

		local rowBg = row:CreateTexture(nil, "BACKGROUND")
		rowBg:SetAllPoints()
		rowBg:SetColorTexture(1, 1, 1, (index % 2 == 1) and 0.03 or 0.01)

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", row, "LEFT", 12, 0)
		label:SetPoint("RIGHT", row, "RIGHT", -240, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		row.Label = label

		local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn:SetSize(210, 26)
		btn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		btn:RegisterForClicks("LeftButtonUp")
		btn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			onClickFunc()
		end)
		btn:SetScript("OnEnter", function(self)
			local desc = getTooltipDescFunc and getTooltipDescFunc()
			if desc and desc ~= "" then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip_SetTitle(GameTooltip, getLabelFunc())
				GameTooltip_AddNormalLine(GameTooltip, desc, true)
				GameTooltip:Show()
			end
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		row.Button = btn

		row.RefreshRow = function()
			label:SetText(getLabelFunc() or "")
			btn:SetText(getBtnTextFunc() or "")
		end

		table.insert(rows, row)
	end

	-- 1. Tab 1: Klickbelegung & Zauberränge
	CreateCanvasRow(
		1,
		function() return L["BLIZZ_SETTINGS_ROW_CLICKCAST"] end,
		function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end,
		function() return L["SETTINGS_BUTTON_TOOLTIP_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(1)
		end
	)

	-- 2. Tab 2: Zauberbuch & Allgemein
	CreateCanvasRow(
		2,
		function() return L["BLIZZ_SETTINGS_ROW_SPELLBOOK"] end,
		function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end,
		function() return L["SETTING_QUICK_BIND_SPELLBOOK_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(2)
		end
	)

	-- 3. Tab 3: Unit-Frame Hover-Overlay
	CreateCanvasRow(
		3,
		function() return L["BLIZZ_SETTINGS_ROW_UNITHOVER"] end,
		function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end,
		function() return L["UNITHOVER_MODE_TOOLTIP_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(3)
		end
	)

	-- 4. Tab 4: Profile, Charakter-Übernahme & Import/Export
	CreateCanvasRow(
		4,
		function() return L["BLIZZ_SETTINGS_ROW_PROFILES"] end,
		function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end,
		function() return L["PROFILE_SOURCE_CHAR_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(4)
		end
	)

	-- 5. Direkt Blizzards Klickbelegungs-Fenster (/bcc) öffnen
	CreateCanvasRow(
		5,
		function() return L["BLIZZ_SETTINGS_ROW_WINDOW"] end,
		function() return L["SETTINGS_OPEN_CLICKCAST_BTN"] end,
		function() return L["MINIMAP_HINT_LEFT"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
				ns.MinimapButton.ToggleClickCastingWindow()
			end
		end
	)

	-- 6. Freie-Tasten-Matrix (/bcc keys) öffnen
	CreateCanvasRow(
		6,
		function() return L["SETTINGS_FREE_KEYS_MATRIX_BTN"] end,
		function() return L["BLIZZ_SETTINGS_OPEN_BTN"] end,
		function() return L["SETTINGS_FREE_KEYS_MATRIX_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			if ns.ClickBindingUI and ns.ClickBindingUI.ToggleFreeKeysMatrix then
				ns.ClickBindingUI.ToggleFreeKeysMatrix()
			end
		end
	)

	-- 7. Alle Overlays entsperren / sperren (/bcc move)
	CreateCanvasRow(
		7,
		function() return L["BLIZZ_SETTINGS_ROW_MOVE"] end,
		function()
			if SettingsUI.IsOverlaysUnlocked() then
				return L["OVERLAY_UNLOCK_BTN_LOCK_ALL"]
			end
			return L["OVERLAY_UNLOCK_BTN_UNLOCK_ALL"]
		end,
		function() return L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"] end,
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.ToggleOverlaysUnlocked()
		end
	)

	local function RefreshCanvas()
		headerTitle:SetText(string.format("%s  |cff888888v%s|r", L["ADDON_TITLE"] or "Better Click Casting", Constants.VERSION))
		for _, row in ipairs(rows) do
			row.RefreshRow()
		end
	end

	canvas:SetScript("OnShow", RefreshCanvas)
	RefreshCanvas()

	local category = Settings.RegisterCanvasLayoutCategory(canvas, L["ADDON_TITLE"] or "Better Click Casting")
	SettingsUI.BlizzardCategory = category
	Settings.RegisterAddOnCategory(category)
end
