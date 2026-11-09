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

SettingsUI.GROUP_MODES = GROUP_MODES
SettingsUI.UNITHOVER_MODES = UNITHOVER_MODES
SettingsUI.UNITHOVER_ANCHORS = UNITHOVER_ANCHORS

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
		if descKey and L[descKey] then
			radio:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, L[entry.labelKey])
				GameTooltip_AddNormalLine(tooltip, L[descKey], true)
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

local function AddSettingCheckbox(rootDescription, key, labelKey, descKey)
	local function IsSelected()
		return Database.Get(key) and true or false
	end

	local function SetSelected()
		Database.Toggle(key)
	end

	local checkbox = rootDescription:CreateCheckbox(L[labelKey], IsSelected, SetSelected)
	if descKey and L[descKey] then
		checkbox:SetTooltip(function(tooltip)
			GameTooltip_SetTitle(tooltip, L[labelKey])
			GameTooltip_AddNormalLine(tooltip, L[descKey], true)
		end)
	end
	return checkbox
end

function SettingsUI.OpenSettingsMenu(ownerRegion)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end

	MenuUtil.CreateContextMenu(ownerRegion, function(_, rootDescription)
		rootDescription:CreateTitle(string.format("%s  |cff888888v%s|r", L["SETTINGS_MENU_TITLE"], Constants.VERSION))

		-- Sektion 1: ClickBindingFrame
		rootDescription:CreateTitle(L["SETTINGS_HEADER_CLICKCAST"])
		local groupSubmenu = rootDescription:CreateButton(
			string.format(L["GROUP_BUTTON_FORMAT"], SettingsUI.GetCurrentGroupShortLabel())
		)
		SettingsUI.PopulateGroupingMenu(groupSubmenu)

		AddSettingCheckbox(rootDescription, "showRankInName", "SETTING_SHOW_RANK_IN_NAME", "SETTING_SHOW_RANK_IN_NAME_DESC")
		AddSettingCheckbox(rootDescription, "highlightDownranks", "SETTING_HIGHLIGHT_DOWNRANKS", "SETTING_HIGHLIGHT_DOWNRANKS_DESC")
		AddSettingCheckbox(rootDescription, "showRankSwitcher", "SETTING_SHOW_RANK_SWITCHER", "SETTING_SHOW_RANK_SWITCHER_DESC")
		AddSettingCheckbox(rootDescription, "enableSmartRankRules", "SETTING_ENABLE_SMART_RULES", "SETTING_ENABLE_SMART_RULES_DESC")
		AddSettingCheckbox(rootDescription, "showLineTooltips", "SETTING_SHOW_LINE_TOOLTIPS", "SETTING_SHOW_LINE_TOOLTIPS_DESC")

		-- Sektion 2: Zauberbuch
		rootDescription:CreateDivider()
		rootDescription:CreateTitle(L["SETTINGS_HEADER_SPELLBOOK"])
		AddSettingCheckbox(rootDescription, "quickBindSpellbook", "SETTING_QUICK_BIND_SPELLBOOK", "SETTING_QUICK_BIND_SPELLBOOK_DESC")
		AddSettingCheckbox(rootDescription, "showSpellbookBadges", "SETTING_SHOW_SPELLBOOK_BADGES", "SETTING_SHOW_SPELLBOOK_BADGES_DESC")
		AddSettingCheckbox(rootDescription, "autoShowAllRanks", "SETTING_AUTO_SHOW_ALL_RANKS", "SETTING_AUTO_SHOW_ALL_RANKS_DESC")

		-- Sektion 3: Unit-Frame Hover-Overlay
		rootDescription:CreateDivider()
		rootDescription:CreateTitle(L["SETTINGS_HEADER_UNITHOVER"])
		local hoverModeSubmenu = rootDescription:CreateButton(
			string.format(L["UNITHOVER_MODE_BUTTON_FORMAT"], SettingsUI.GetCurrentUnitHoverModeShortLabel())
		)
		PopulateRadioMenu(hoverModeSubmenu, "UNITHOVER_MODE_MENU_TITLE", "unitHoverMode", "off", UNITHOVER_MODES, "UNITHOVER_MODE_TOOLTIP_DESC")

		local hoverAnchorSubmenu = rootDescription:CreateButton(
			string.format(L["UNITHOVER_ANCHOR_BUTTON_FORMAT"], SettingsUI.GetCurrentUnitHoverAnchorShortLabel())
		)
		PopulateRadioMenu(hoverAnchorSubmenu, "UNITHOVER_ANCHOR_MENU_TITLE", "unitHoverAnchor", "cursor", UNITHOVER_ANCHORS, "UNITHOVER_ANCHOR_TOOLTIP_DESC")

		if (Database.Get("unitHoverAnchor") or "cursor") == "free" and ns.UnitHoverTooltip then
			local function IsMoveUnlocked()
				return ns.UnitHoverTooltip.IsMoveUnlocked and ns.UnitHoverTooltip.IsMoveUnlocked() or false
			end
			local function ToggleMoveUnlocked()
				if ns.UnitHoverTooltip.SetMoveUnlocked then
					ns.UnitHoverTooltip.SetMoveUnlocked(not IsMoveUnlocked())
				end
			end
			local unlockCb = rootDescription:CreateCheckbox(L["SETTING_UNITHOVER_UNLOCK_MOVE"], IsMoveUnlocked, ToggleMoveUnlocked)
			unlockCb:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, L["SETTING_UNITHOVER_UNLOCK_MOVE"])
				GameTooltip_AddNormalLine(tooltip, L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"], true)
			end)
		end

		AddSettingCheckbox(rootDescription, "unitHoverShowInCombat", "SETTING_UNITHOVER_SHOW_IN_COMBAT", "SETTING_UNITHOVER_SHOW_IN_COMBAT_DESC")
		AddSettingCheckbox(rootDescription, "unitHoverShowInteractions", "SETTING_UNITHOVER_SHOW_INTERACTIONS", "SETTING_UNITHOVER_SHOW_INTERACTIONS_DESC")

		-- Sektion 4: Allgemein und Schnell-Aktion
		rootDescription:CreateDivider()
		rootDescription:CreateTitle(L["SETTINGS_HEADER_GENERAL"])
		AddSettingCheckbox(rootDescription, "showMinimapButton", "SETTING_SHOW_MINIMAP_BUTTON", "SETTING_SHOW_MINIMAP_BUTTON_DESC")

		if ClickBindingFrame and ClickBindingFrame:IsShown() and ns.ClickBindingUI and ns.ClickBindingUI.CountUpgradeableBindings then
			local upgradeCount = ns.ClickBindingUI.CountUpgradeableBindings()
			local actionLabel = upgradeCount > 0
				and string.format(L["ACTION_UPGRADE_ALL_MAX_FORMAT"], upgradeCount)
				or L["ACTION_UPGRADE_ALL_MAX_NONE"]

			local upgradeBtn = rootDescription:CreateButton(actionLabel, function()
				if upgradeCount > 0 and ns.ClickBindingUI.UpgradeAllBindingsToMaxRank then
					ns.ClickBindingUI.UpgradeAllBindingsToMaxRank()
				end
			end)
			upgradeBtn:SetEnabled(upgradeCount > 0)
			upgradeBtn:SetTooltip(function(tooltip)
				GameTooltip_SetTitle(tooltip, actionLabel)
				GameTooltip_AddNormalLine(tooltip, L["ACTION_UPGRADE_ALL_MAX_DESC"], true)
			end)
		end
	end)
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

	btn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		SettingsUI.OpenSettingsMenu(self)
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
