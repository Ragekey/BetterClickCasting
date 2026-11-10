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

SettingsUI.GROUP_MODES = GROUP_MODES
SettingsUI.UNITHOVER_MODES = UNITHOVER_MODES
SettingsUI.UNITHOVER_ANCHORS = UNITHOVER_ANCHORS
SettingsUI.TRAINER_BEHAVIOR_OPTIONS = TRAINER_BEHAVIOR_OPTIONS

local settingsWindow = nil
local activeTabIndex = 1

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

--------------------------------------------------------------------------------
-- UI-Bausteine für das eigene Einstellungs-Fenster (BCCSettingsWindow)
--------------------------------------------------------------------------------

local function CreateSectionHeader(parent, text, yOffset)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
	label:SetText("|cffffd100" .. text .. "|r")

	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset - 16)
	line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset - 16)
	line:SetColorTexture(0.65, 0.55, 0.30, 0.30)

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
		self.Text:SetText(getTextFunc())
	end

	return btn
end

local function CreateSliderControl(parent, yOffset, dbKey, minVal, maxVal, stepVal, formatKey)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(390, 42)
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
	slider:SetSize(386, 12)
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
	if point and type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.settingsWindowPos = {
			point = point,
			relativePoint = relativePoint or point,
			x = xOfs or 0,
			y = yOfs or 0,
		}
	end
end

local function PositionSettingsWindow(frame)
	frame:ClearAllPoints()
	local saved = (type(BetterClickCastingDB) == "table") and BetterClickCastingDB.settingsWindowPos or nil
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
	win:SetSize(430, 445)
	win:SetFrameStrata("DIALOG")
	win:SetFrameLevel(130)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
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

	local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)

	-- 3 Reiter-Buttons oben
	local tabLabels = {
		L["SETTINGS_TAB_CLICKCAST"],
		L["SETTINGS_TAB_SPELLBOOK"],
		L["SETTINGS_TAB_UNITHOVER"],
	}
	win.TabButtons = {}
	win.Pages = {}
	win.Controls = {}

	local tabWidth = 128
	for i, tabTitle in ipairs(tabLabels) do
		local tabBtn = CreateFrame("Button", nil, win)
		tabBtn:SetSize(tabWidth, 26)
		tabBtn:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + ((i - 1) * (tabWidth + 7)), -44)
		tabBtn:RegisterForClicks("LeftButtonUp")

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
		text:SetText(tabTitle)
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
	CreateSectionHeader(page1, L["SETTINGS_HEADER_CLICKCAST"], -6)

	RegisterControl(CreatePillSelectorButton(
		page1,
		-30,
		192,
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
		192,
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
	trainerBtn:SetPoint("TOPLEFT", page1, "TOPLEFT", 220, -30)

	RegisterControl(CreateDBCheckbox(page1, -64, "showRankInName", "SETTING_SHOW_RANK_IN_NAME", "SETTING_SHOW_RANK_IN_NAME_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -92, "highlightDownranks", "SETTING_HIGHLIGHT_DOWNRANKS", "SETTING_HIGHLIGHT_DOWNRANKS_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -120, "showRankSwitcher", "SETTING_SHOW_RANK_SWITCHER", "SETTING_SHOW_RANK_SWITCHER_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -148, "showLineManaCost", "SETTING_SHOW_LINE_MANA_COST", "SETTING_SHOW_LINE_MANA_COST_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -176, "moveInteractionsToBottom", "SETTING_MOVE_INTERACTIONS_BOTTOM", "SETTING_MOVE_INTERACTIONS_BOTTOM_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -204, "enableSmartRankRules", "SETTING_ENABLE_SMART_RULES", "SETTING_ENABLE_SMART_RULES_DESC"))
	RegisterControl(CreateDBCheckbox(page1, -232, "showLineTooltips", "SETTING_SHOW_LINE_TOOLTIPS", "SETTING_SHOW_LINE_TOOLTIPS_DESC"))

	local upgradeBtn = RegisterControl(CreateActionButton(
		page1,
		-272,
		394,
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
		-308,
		192,
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

	local exportBtn = RegisterControl(CreateActionButton(
		page1,
		-308,
		192,
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
	exportBtn:ClearAllPoints()
	exportBtn:SetPoint("TOPLEFT", page1, "TOPLEFT", 220, -308)

	----------------------------------------------------------------------------
	-- TAB 2: Zauberbuch & Allgemein
	----------------------------------------------------------------------------
	local page2 = win.Pages[2]
	CreateSectionHeader(page2, L["SETTINGS_HEADER_SPELLBOOK"], -6)

	RegisterControl(CreateDBCheckbox(page2, -30, "quickBindSpellbook", "SETTING_QUICK_BIND_SPELLBOOK", "SETTING_QUICK_BIND_SPELLBOOK_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -58, "showSpellbookBadges", "SETTING_SHOW_SPELLBOOK_BADGES", "SETTING_SHOW_SPELLBOOK_BADGES_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -86, "autoShowAllRanks", "SETTING_AUTO_SHOW_ALL_RANKS", "SETTING_AUTO_SHOW_ALL_RANKS_DESC"))
	RegisterControl(CreateDBCheckbox(page2, -114, "autoSelectPrimarySpellTab", "SETTING_AUTO_SELECT_PRIMARY_TAB", "SETTING_AUTO_SELECT_PRIMARY_TAB_DESC"))

	CreateSectionHeader(page2, L["SETTINGS_HEADER_GENERAL"], -152)
	RegisterControl(CreateDBCheckbox(page2, -176, "showMinimapButton", "SETTING_SHOW_MINIMAP_BUTTON", "SETTING_SHOW_MINIMAP_BUTTON_DESC"))

	RegisterControl(CreateActionButton(
		page2,
		-214,
		246,
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
		-214,
		140,
		function()
			return L["OVERLAY_UNLOCK_BTN_RESET_POS"]
		end,
		function()
			SettingsUI.ResetAllOverlayPositions()
		end,
		"OVERLAY_UNLOCK_BTN_RESET_POS_DESC"
	))
	resetPosBtn:ClearAllPoints()
	resetPosBtn:SetPoint("TOPLEFT", page2, "TOPLEFT", 272, -214)

	RegisterControl(CreateActionButton(
		page2,
		-250,
		394,
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
	CreateSectionHeader(page3, L["SETTINGS_HEADER_UNITHOVER"], -6)

	RegisterControl(CreatePillSelectorButton(
		page3,
		-30,
		192,
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
		192,
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
	anchorBtn:SetPoint("TOPLEFT", page3, "TOPLEFT", 220, -30)

	RegisterControl(CreateSliderControl(page3, -68, "unitHoverScale", 70, 150, 5, "SETTING_UNITHOVER_SCALE_FORMAT"))
	RegisterControl(CreateSliderControl(page3, -118, "unitHoverAlpha", 30, 100, 5, "SETTING_UNITHOVER_ALPHA_FORMAT"))

	RegisterControl(CreateDBCheckbox(page3, -168, "unitHoverShowMana", "SETTING_UNITHOVER_SHOW_MANA", "SETTING_UNITHOVER_SHOW_MANA_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -196, "unitHoverShowRankTags", "SETTING_UNITHOVER_SHOW_RANK_TAGS", "SETTING_UNITHOVER_SHOW_RANK_TAGS_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -224, "unitHoverShowInCombat", "SETTING_UNITHOVER_SHOW_IN_COMBAT", "SETTING_UNITHOVER_SHOW_IN_COMBAT_DESC"))
	RegisterControl(CreateDBCheckbox(page3, -252, "unitHoverShowInteractions", "SETTING_UNITHOVER_SHOW_INTERACTIONS", "SETTING_UNITHOVER_SHOW_INTERACTIONS_DESC"))

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

	win:Hide()
	settingsWindow = win
	SelectTab(1)
	return win
end

function SettingsUI.IsOverlaysUnlocked()
	local hoverUnlocked = ns.UnitHoverTooltip and ns.UnitHoverTooltip.IsMoveUnlocked and ns.UnitHoverTooltip.IsMoveUnlocked() or false
	local heroUnlocked = ns.ClickBindingUI and ns.ClickBindingUI.IsHeroCardPreviewUnlocked and ns.ClickBindingUI.IsHeroCardPreviewUnlocked() or false
	return hoverUnlocked or heroUnlocked
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
	if not silent and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_OVERLAYS_RESET"])
	end
end

function SettingsUI.RefreshWindow()
	if not settingsWindow or not settingsWindow:IsShown() then
		return
	end
	for _, ctrl in ipairs(settingsWindow.Controls) do
		if ctrl.RefreshValue then
			ctrl:RefreshValue()
		end
	end
end

function SettingsUI.OpenSettingsTab(tabIndex)
	local win = EnsureSettingsWindow()
	if not win:IsShown() then
		PositionSettingsWindow(win)
		win:Show()
	end
	if tabIndex and tabIndex >= 1 and tabIndex <= 3 then
		SelectTab(tabIndex)
	end
	SettingsUI.RefreshWindow()
end

function SettingsUI.OpenSettingsMenu()
	local win = EnsureSettingsWindow()
	if win:IsShown() then
		win:Hide()
	else
		PositionSettingsWindow(win)
		win:Show()
		SettingsUI.RefreshWindow()
	end
end

function SettingsUI.AttachToClickBindingFrame()
	if not ClickBindingFrame or ClickBindingFrame.BCCSettingsButton then
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

	btn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		SettingsUI.OpenSettingsMenu()
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["SETTINGS_BUTTON_TOOLTIP_TITLE"])
		GameTooltip_AddNormalLine(GameTooltip, L["SETTINGS_BUTTON_TOOLTIP_DESC"], true)
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	ClickBindingFrame.BCCSettingsButton = btn
end

local blizzardCategoryRegistered = false

-- Registriert Better Click Casting unter Esc -> Optionen -> AddOns über Blizzards VerticalLayout,
-- sodass alle Einträge auch direkt über die globale Suchleiste oben rechts im Optionen-Fenster gefunden werden.
function SettingsUI.RegisterBlizzardOptions()
	if blizzardCategoryRegistered then
		return
	end
	if not Settings
		or not Settings.RegisterVerticalLayoutCategory
		or not Settings.RegisterInitializer
		or not Settings.RegisterAddOnCategory
		or not CreateSettingsButtonInitializer
	then
		return
	end
	blizzardCategoryRegistered = true

	local category = Settings.RegisterVerticalLayoutCategory(L["ADDON_TITLE"] or "Better Click Casting")
	SettingsUI.BlizzardCategory = category

	local function CloseBlizzardSettingsIfSafe()
		if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel and not (InCombatLockdown and InCombatLockdown()) then
			HideUIPanel(SettingsPanel)
		end
	end

	local function AddActionRow(rowName, buttonLabel, tooltipDesc, onClickFunc, extraTags)
		local initializer = CreateSettingsButtonInitializer(
			rowName,
			buttonLabel,
			onClickFunc,
			tooltipDesc,
			true
		)
		if initializer and initializer.AddSearchTags then
			initializer:AddSearchTags("Better Click Casting", "BetterClickCasting", "BCC", "Click Cast", "Klickbelegung")
			if type(extraTags) == "table" then
				for _, tag in ipairs(extraTags) do
					initializer:AddSearchTags(tag)
				end
			end
		end
		Settings.RegisterInitializer(category, initializer)
	end

	-- 1. Tab 1: Klickbelegung & Zauberränge
	AddActionRow(
		L["BLIZZ_SETTINGS_ROW_CLICKCAST"],
		L["BLIZZ_SETTINGS_OPEN_BTN"],
		L["SETTINGS_BUTTON_TOOLTIP_DESC"],
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(1)
		end,
		{ "Downrank", "Zauberrang", "Smart Rules", "Mana", "Manakosten", "Rank", "Rang", "Trainer" }
	)

	-- 2. Tab 2: Zauberbuch & Allgemein
	AddActionRow(
		L["BLIZZ_SETTINGS_ROW_SPELLBOOK"],
		L["BLIZZ_SETTINGS_OPEN_BTN"],
		L["SETTING_QUICK_BIND_SPELLBOOK_DESC"],
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(2)
		end,
		{ "Spellbook", "Zauberbuch", "Quick Bind", "Direktbinden", "Minimap", "Badges" }
	)

	-- 3. Tab 3: Unit-Frame Hover-Overlay
	AddActionRow(
		L["BLIZZ_SETTINGS_ROW_UNITHOVER"],
		L["BLIZZ_SETTINGS_OPEN_BTN"],
		L["UNITHOVER_MODE_TOOLTIP_DESC"],
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.OpenSettingsTab(3)
		end,
		{ "Hover", "Unit Frame", "Einheitenfenster", "Overlay", "Tooltip", "Cursor" }
	)

	-- 4. Direkt Blizzards Klickbelegungs-Fenster (/bcc) öffnen
	AddActionRow(
		L["BLIZZ_SETTINGS_ROW_WINDOW"],
		L["SETTINGS_OPEN_CLICKCAST_BTN"],
		L["MINIMAP_HINT_LEFT"],
		function()
			CloseBlizzardSettingsIfSafe()
			if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
				ns.MinimapButton.ToggleClickCastingWindow()
			end
		end,
		{ "Bindings", "Belegung", "Window", "Fenster" }
	)

	-- 5. Alle Overlays entsperren / sperren (/bcc move)
	AddActionRow(
		L["BLIZZ_SETTINGS_ROW_MOVE"],
		L["OVERLAY_UNLOCK_BTN_UNLOCK_ALL"],
		L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"],
		function()
			CloseBlizzardSettingsIfSafe()
			SettingsUI.ToggleOverlaysUnlocked()
		end,
		{ "Move", "Unlock", "Lock", "Verschieben", "Platzhalter", "Placeholder" }
	)

	Settings.RegisterAddOnCategory(category)
end
