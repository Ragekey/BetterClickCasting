local addonName, ns = ...

if SlashCmdList["BETTERCLICKCASTING"] then
	return
end

local L = ns.L
local Database = ns.Database
local SpellRanks = ns.SpellRanks
local ClickBindingUI = ns.ClickBindingUI
local SpellBookUI = ns.SpellBookUI
local MinimapButton = ns.MinimapButton
local UnitHoverTooltip = ns.UnitHoverTooltip

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("ADDON_LOADED")
loaderFrame:RegisterEvent("PLAYER_LOGIN")
loaderFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loaderFrame:RegisterEvent("SPELLS_CHANGED")
loaderFrame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
loaderFrame:RegisterEvent("TRAINER_CLOSED")
loaderFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
loaderFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

loaderFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName or arg1 == "BetterClickCasting" or arg1 == "BetterClickCastings" then
			Database.Init()
			MinimapButton.Init()
			if ns.SettingsUI and ns.SettingsUI.RegisterBlizzardOptions then
				ns.SettingsUI.RegisterBlizzardOptions()
			end
			if UnitHoverTooltip and UnitHoverTooltip.Init then
				UnitHoverTooltip.Init()
			end
			if ClickBindingUI and ClickBindingUI.SyncAutoShowAllRanks then
				ClickBindingUI.SyncAutoShowAllRanks()
			end
		end
		-- Wichtig: Nicht während arg1 == "Blizzard_MacroUI" aufrufen, da MacroFrame_LoadUI() mitten in
		-- ClickBindingFrameMixin:OnLoad() läuft, noch bevor self:InitializeScrollBox() die ScrollBox-View erzeugt hat.
		if (arg1 == "Blizzard_ClickBindingUI" or arg1 == addonName or arg1 == "BetterClickCasting") and ClickBindingFrame then
			ClickBindingUI.SetupHooks()
		end
		if SpellBookItemMixin then
			SpellBookUI.SetupHooks()
		end
	elseif event == "PLAYER_LOGIN" then
		Database.Init()
		MinimapButton.Init()
		if ns.SettingsUI and ns.SettingsUI.RegisterBlizzardOptions then
			ns.SettingsUI.RegisterBlizzardOptions()
		end
		if UnitHoverTooltip and UnitHoverTooltip.Init then
			UnitHoverTooltip.Init()
		end
		if ClickBindingUI and ClickBindingUI.SyncAutoShowAllRanks then
			ClickBindingUI.SyncAutoShowAllRanks()
		end
		if ClickBindingFrame then
			ClickBindingUI.SetupHooks()
		end
		if SpellBookItemMixin then
			SpellBookUI.SetupHooks()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		SpellRanks.InvalidateCache()
		if C_Timer and C_Timer.After and Database and Database.SaveCharacterSnapshot then
			C_Timer.After(1.0, Database.SaveCharacterSnapshot)
		end
		if ClickBindingUI and ClickBindingUI.ScheduleSmartRuleCheck then
			ClickBindingUI.ScheduleSmartRuleCheck(1.2, false)
		end
	elseif event == "SPELLS_CHANGED" then
		SpellRanks.InvalidateCache()
		ClickBindingUI.RefreshVisibleLines()
		SpellBookUI.RefreshBadges()
		if ClickBindingUI and ClickBindingUI.ScheduleSmartRuleCheck then
			ClickBindingUI.ScheduleSmartRuleCheck(0.8, false)
		end
	elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
		SpellRanks.InvalidateCache()
		ClickBindingUI.RefreshVisibleLines()
		SpellBookUI.RefreshBadges()
		if ClickBindingUI and ClickBindingUI.ScheduleSmartRuleCheck then
			-- Neuer Zauberrang gelernt: auch dann wieder erinnern, wenn zuvor X geklickt wurde
			ClickBindingUI.ScheduleSmartRuleCheck(0.8, true)
		end
	elseif event == "TRAINER_CLOSED" then
		if ClickBindingUI and ClickBindingUI.ScheduleSmartRuleCheck then
			ClickBindingUI.ScheduleSmartRuleCheck(0.3, false)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.SettingsUI and ns.SettingsUI.IsOverlaysUnlocked and ns.SettingsUI.IsOverlaysUnlocked() then
			ns.SettingsUI.SetOverlaysUnlocked(false, true)
		end
		if ClickBindingUI and ClickBindingUI.HideHeroCard then
			ClickBindingUI.HideHeroCard()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if ClickBindingUI and ClickBindingUI.ScheduleSmartRuleCheck then
			ClickBindingUI.ScheduleSmartRuleCheck(0.6, false)
		end
	end
end)

if ToggleClickBindingFrame then
	hooksecurefunc("ToggleClickBindingFrame", function()
		if ClickBindingFrame then
			ClickBindingUI.SetupHooks()
		end
	end)
end

--------------------------------------------------------------------------------
-- Slash-Commands (/bcc, /betterclickcasting)
--------------------------------------------------------------------------------

local function PrintSettingState(labelKey, isOn)
	if not DEFAULT_CHAT_FRAME then
		return
	end
	local stateStr = isOn and L["CHAT_STATE_ON"] or L["CHAT_STATE_OFF"]
	DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_SETTING_CHANGED_FORMAT"], L[labelKey] or labelKey, stateStr))
end

local function PrintSettingValue(labelKey, valueText)
	if not DEFAULT_CHAT_FRAME then
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_SETTING_CHANGED_FORMAT"], L[labelKey] or labelKey, "|cffffd100" .. tostring(valueText) .. "|r"))
end

local function ToggleBoolCommand(dbKey, labelKey)
	local newVal = Database.Toggle(dbKey)
	PrintSettingState(labelKey, newVal)
end

local GROUP_CYCLE = { "modifier", "button", "type", "none" }
local HOVER_MODE_CYCLE = { "off", "modifier", "always" }
local HOVER_ANCHOR_CYCLE = { "cursor", "top", "bottom", "left", "right", "free" }
local TRAINER_BEHAVIOR_CYCLE = { "card", "auto", "off" }
local LOCALE_CYCLE = { "auto", "enUS", "deDE", "esES" }

local function CycleOrSetOption(dbKey, currentVal, cycleList, aliasMap, arg)
	if arg and arg ~= "" and aliasMap[arg] then
		Database.Set(dbKey, aliasMap[arg])
		return
	end
	local nextIdx = 1
	for i, v in ipairs(cycleList) do
		if v == currentVal then
			nextIdx = (i % #cycleList) + 1
			break
		end
	end
	Database.Set(dbKey, cycleList[nextIdx])
end

SLASH_BETTERCLICKCASTING1 = "/bcc"
SLASH_BETTERCLICKCASTING2 = "/betterclickcasting"
SLASH_BETTERCLICKCASTING3 = "/betterclickcastings"
SlashCmdList["BETTERCLICKCASTING"] = function(msg)
	local raw = strtrim(msg or "")
	local cmd, rawArg = string.match(raw, "^(%S+)%s*(.-)$")
	cmd = string.lower(cmd or "")
	rawArg = strtrim(rawArg or "")
	local arg = string.lower(rawArg)

	if cmd == "" then
		MinimapButton.ToggleClickCastingWindow()
	elseif cmd == "config" or cmd == "cfg" or cmd == "opt" or cmd == "options" or cmd == "settings" then
		local tabNum = tonumber(arg)
		if tabNum and ns.SettingsUI and ns.SettingsUI.OpenSettingsTab then
			ns.SettingsUI.OpenSettingsTab(tabNum)
		elseif ns.SettingsUI and ns.SettingsUI.OpenSettingsMenu then
			ns.SettingsUI.OpenSettingsMenu()
		end
	elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
		if ns.SettingsUI and ns.SettingsUI.SetOverlaysUnlocked and ns.SettingsUI.ToggleOverlaysUnlocked then
			if cmd == "unlock" then
				ns.SettingsUI.SetOverlaysUnlocked(true)
			elseif cmd == "lock" and ns.SettingsUI.IsOverlaysUnlocked and ns.SettingsUI.IsOverlaysUnlocked() then
				ns.SettingsUI.SetOverlaysUnlocked(false)
			else
				ns.SettingsUI.ToggleOverlaysUnlocked()
			end
		end
	elseif cmd == "reset" or cmd == "resetpos" then
		if ns.SettingsUI and ns.SettingsUI.ResetAllOverlayPositions then
			ns.SettingsUI.ResetAllOverlayPositions()
		end
	elseif cmd == "max" or cmd == "upgrade" then
		if InCombatLockdown and InCombatLockdown() then
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
			end
			return
		end
		if not (ClickBindingFrame and ClickBindingFrame:IsShown()) then
			MinimapButton.ToggleClickCastingWindow()
		end
		if ClickBindingUI and ClickBindingUI.UpgradeAllBindingsToMaxRank then
			local count = ClickBindingUI.UpgradeAllBindingsToMaxRank()
			if count == 0 and DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBetter Click Casting:|r " .. L["ACTION_UPGRADE_ALL_MAX_NONE"])
			end
		end
	elseif cmd == "group" or cmd == "grouping" then
		local aliases = {
			mod = "modifier", modifier = "modifier",
			btn = "button", button = "button",
			type = "type", action = "type",
			none = "none", off = "none", flat = "none",
		}
		CycleOrSetOption("groupingMode", Database.Get("groupingMode") or "modifier", GROUP_CYCLE, aliases, arg)
		if ns.SettingsUI and ns.SettingsUI.GetCurrentGroupShortLabel then
			PrintSettingValue("GROUP_MENU_TITLE", ns.SettingsUI.GetCurrentGroupShortLabel())
		end
	elseif cmd == "hover" then
		local aliases = {
			off = "off", ["0"] = "off", disable = "off",
			mod = "modifier", modifier = "modifier", ["1"] = "modifier",
			always = "always", on = "always", ["2"] = "always",
		}
		CycleOrSetOption("unitHoverMode", Database.Get("unitHoverMode") or "off", HOVER_MODE_CYCLE, aliases, arg)
		if ns.SettingsUI and ns.SettingsUI.GetCurrentUnitHoverModeShortLabel then
			PrintSettingValue("UNITHOVER_MODE_MENU_TITLE", ns.SettingsUI.GetCurrentUnitHoverModeShortLabel())
		end
	elseif cmd == "anchor" then
		local aliases = {
			cursor = "cursor", mouse = "cursor",
			top = "top",
			bottom = "bottom", bot = "bottom",
			left = "left",
			right = "right",
			free = "free",
		}
		CycleOrSetOption("unitHoverAnchor", Database.Get("unitHoverAnchor") or "cursor", HOVER_ANCHOR_CYCLE, aliases, arg)
		if ns.SettingsUI and ns.SettingsUI.GetCurrentUnitHoverAnchorShortLabel then
			PrintSettingValue("UNITHOVER_ANCHOR_MENU_TITLE", ns.SettingsUI.GetCurrentUnitHoverAnchorShortLabel())
		end
	elseif cmd == "scale" then
		local val = tonumber(arg)
		if val then
			val = math.max(70, math.min(150, math.floor((val / 5) + 0.5) * 5))
			Database.Set("unitHoverScale", val)
		end
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBetter Click Casting:|r " .. string.format(L["SETTING_UNITHOVER_SCALE_FORMAT"], Database.Get("unitHoverScale") or 100))
		end
	elseif cmd == "alpha" or cmd == "opacity" then
		local val = tonumber(arg)
		if val then
			val = math.max(30, math.min(100, math.floor((val / 5) + 0.5) * 5))
			Database.Set("unitHoverAlpha", val)
		end
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffBetter Click Casting:|r " .. string.format(L["SETTING_UNITHOVER_ALPHA_FORMAT"], Database.Get("unitHoverAlpha") or 94))
		end
	elseif cmd == "qb" or cmd == "quickbind" then
		ToggleBoolCommand("quickBindSpellbook", "SETTING_QUICK_BIND_SPELLBOOK")
	elseif cmd == "mana" or cmd == "manacost" then
		ToggleBoolCommand("showLineManaCost", "SETTING_SHOW_LINE_MANA_COST")
	elseif cmd == "bottom" or cmd == "interactions" then
		ToggleBoolCommand("moveInteractionsToBottom", "SETTING_MOVE_INTERACTIONS_BOTTOM")
	elseif cmd == "trainer" then
		local aliases = {
			card = "card", hero = "card", ["1"] = "card",
			auto = "auto", open = "auto", ["2"] = "auto",
			off = "off", none = "off", ["0"] = "off",
		}
		CycleOrSetOption("trainerUpgradeBehavior", Database.Get("trainerUpgradeBehavior") or "card", TRAINER_BEHAVIOR_CYCLE, aliases, arg)
		if ns.SettingsUI and ns.SettingsUI.GetCurrentTrainerBehaviorShortLabel then
			PrintSettingValue("TRAINER_BEHAVIOR_MENU_TITLE", ns.SettingsUI.GetCurrentTrainerBehaviorShortLabel())
		end
	elseif cmd == "autotab" or cmd == "tab" then
		ToggleBoolCommand("autoSelectPrimarySpellTab", "SETTING_AUTO_SELECT_PRIMARY_TAB")
	elseif cmd == "list" or cmd == "summary" then
		if ClickBindingUI and ClickBindingUI.ShowBindingsExportPopup then
			ClickBindingUI.ShowBindingsExportPopup()
		end
	elseif cmd == "keys" or cmd == "free" or cmd == "matrix" then
		if arg == "combos" or arg == "combo" or arg == "8x5" or arg == "all" then
			ToggleBoolCommand("matrixShowCombos", "MATRIX_SHOW_COMBOS_CHECKBOX")
			if ClickBindingUI and ClickBindingUI.RefreshFreeKeysMatrix then
				ClickBindingUI.RefreshFreeKeysMatrix()
			end
		elseif arg == "auto" or arg == "autoopen" then
			ToggleBoolCommand("matrixAutoOpen", "MATRIX_AUTO_OPEN_CHECKBOX")
			if Database.Get("matrixAutoOpen") and ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingUI and ClickBindingUI.ShowFreeKeysMatrix then
				ClickBindingUI.ShowFreeKeysMatrix()
			elseif ClickBindingUI and ClickBindingUI.RefreshFreeKeysMatrix then
				ClickBindingUI.RefreshFreeKeysMatrix()
			end
		elseif ClickBindingUI and ClickBindingUI.ToggleFreeKeysMatrix then
			ClickBindingUI.ToggleFreeKeysMatrix()
		end
	elseif cmd == "export" then
		local scope = "all"
		if arg == "bindings" or arg == "binds" or arg == "keys" or arg == "keybinds" then
			scope = "bindings"
		elseif arg == "settings" or arg == "cfg" or arg == "config" then
			scope = "settings"
		end
		if ClickBindingUI and ClickBindingUI.ShowExportStringPopup then
			ClickBindingUI.ShowExportStringPopup(scope)
		end
	elseif cmd == "import" then
		local scope = "all"
		if arg == "bindings" or arg == "binds" or arg == "keys" or arg == "keybinds" then
			scope = "bindings"
		elseif arg == "settings" or arg == "cfg" or arg == "config" then
			scope = "settings"
		end
		if ClickBindingUI and ClickBindingUI.ShowImportStringPopup then
			ClickBindingUI.ShowImportStringPopup(scope)
		end
	elseif cmd == "copy" then
		local firstWord, restWords = string.match(arg, "^(%S+)%s*(.-)$")
		local scope = "all"
		local charQuery = arg
		if firstWord == "all" or firstWord == "bindings" or firstWord == "binds" or firstWord == "keys" or firstWord == "settings" then
			if firstWord == "bindings" or firstWord == "binds" or firstWord == "keys" then
				scope = "bindings"
			elseif firstWord == "settings" then
				scope = "settings"
			end
			charQuery = restWords or ""
		end
		if not charQuery or charQuery == "" then
			if ns.SettingsUI and ns.SettingsUI.OpenSettingsTab then
				ns.SettingsUI.OpenSettingsTab(4)
			end
		else
			local prof = Database.FindCharProfile(charQuery)
			if prof and ClickBindingUI and ClickBindingUI.CopyFromCharacterProfile then
				ClickBindingUI.CopyFromCharacterProfile(prof, scope)
			elseif DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_NOT_FOUND_FORMAT"], charQuery))
			end
		end
	elseif cmd == "profile" or cmd == "profiles" then
		if ns.SettingsUI and ns.SettingsUI.OpenSettingsTab then
			ns.SettingsUI.OpenSettingsTab(4)
		end
	elseif cmd == "preset" or cmd == "presets" or cmd == "loadout" or cmd == "loadouts" then
		local subCmd, restRaw = string.match(rawArg, "^(%S+)%s*(.-)$")
		local subLower = string.lower(subCmd or "")
		restRaw = strtrim(restRaw or "")
		if rawArg == "" or subLower == "list" then
			local presets, activeName = Database.GetPresets()
			if #presets == 0 then
				if DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_PRESET_LIST_EMPTY"])
				end
			elseif DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_LIST_HEADER_FORMAT"], ns.Constants.GetPlayerDisplayName(), #presets))
				for _, p in ipairs(presets) do
					local bCount = (type(p.bindings) == "table") and #p.bindings or 0
					local activeTag = (p.name == activeName) and (" |cff40ff59" .. (L["PROFILE_CURRENT_TAG"] or "[Active]") .. "|r") or ""
					DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffd100%s|r |cff888888(%d)|r%s", tostring(p.name), bCount, activeTag))
				end
			end
		elseif subLower == "save" or subLower == "new" then
			if restRaw == "" then
				if ClickBindingUI and ClickBindingUI.ShowNewPresetPopup then
					ClickBindingUI.ShowNewPresetPopup("")
				end
			elseif ClickBindingUI and ClickBindingUI.SavePresetByName then
				ClickBindingUI.SavePresetByName(restRaw)
			end
		elseif subLower == "delete" or subLower == "del" or subLower == "remove" or subLower == "rm" then
			if ClickBindingUI and ClickBindingUI.DeletePresetByName then
				ClickBindingUI.DeletePresetByName(restRaw)
			end
		elseif subLower == "load" then
			if ClickBindingUI and ClickBindingUI.LoadPreset then
				ClickBindingUI.LoadPreset(restRaw)
			end
		else
			if ClickBindingUI and ClickBindingUI.LoadPreset then
				ClickBindingUI.LoadPreset(rawArg)
			end
		end
	elseif cmd == "charsettings" or cmd == "charspecific" then
		local newVal = not Database.IsUsingCharSettings()
		Database.SetUsingCharSettings(newVal)
		PrintSettingState("SETTING_USE_CHAR_SETTINGS", newVal)
	elseif cmd == "merge" then
		ToggleBoolCommand("importMergeBindings", "SETTING_IMPORT_MERGE_BINDINGS")
	elseif cmd == "rules" or cmd == "smartrules" then
		ToggleBoolCommand("enableSmartRankRules", "SETTING_ENABLE_SMART_RULES")
	elseif cmd == "ranks" then
		ToggleBoolCommand("showRankInName", "SETTING_SHOW_RANK_IN_NAME")
	elseif cmd == "downrank" or cmd == "downranks" then
		ToggleBoolCommand("highlightDownranks", "SETTING_HIGHLIGHT_DOWNRANKS")
	elseif cmd == "switcher" then
		ToggleBoolCommand("showRankSwitcher", "SETTING_SHOW_RANK_SWITCHER")
	elseif cmd == "tooltips" or cmd == "tooltip" then
		ToggleBoolCommand("showLineTooltips", "SETTING_SHOW_LINE_TOOLTIPS")
	elseif cmd == "badges" then
		ToggleBoolCommand("showSpellbookBadges", "SETTING_SHOW_SPELLBOOK_BADGES")
	elseif cmd == "allranks" then
		ToggleBoolCommand("autoShowAllRanks", "SETTING_AUTO_SHOW_ALL_RANKS")
	elseif cmd == "minimap" or cmd == "mm" then
		ToggleBoolCommand("showMinimapButton", "SETTING_SHOW_MINIMAP_BUTTON")
	elseif cmd == "range" or cmd == "oor" then
		ToggleBoolCommand("unitHoverShowRange", "SETTING_UNITHOVER_SHOW_RANGE")
	elseif cmd == "compact" or cmd == "compactrows" then
		ToggleBoolCommand("compactListMode", "SETTING_COMPACT_LIST_MODE")
	elseif cmd == "lang" or cmd == "locale" or cmd == "language" then
		local aliases = {
			auto = "auto", client = "auto", default = "auto",
			en = "enUS", enus = "enUS", engb = "enUS", english = "enUS",
			de = "deDE", dede = "deDE", deutsch = "deDE", german = "deDE",
			es = "esES", eses = "esES", esmx = "esES", espanol = "esES", spanish = "esES",
		}
		CycleOrSetOption("addonLocale", Database.Get("addonLocale") or "auto", LOCALE_CYCLE, aliases, arg)
		if DEFAULT_CHAT_FRAME and ns.SettingsUI and ns.SettingsUI.GetCurrentLocaleShortLabel then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_LOCALE_CHANGED_FORMAT"], ns.SettingsUI.GetCurrentLocaleShortLabel()))
		end
	elseif cmd == "status" then
		if DEFAULT_CHAT_FRAME and ns.SettingsUI then
			if ns.SettingsUI.GetCurrentLocaleShortLabel then
				PrintSettingValue("LOCALE_MENU_TITLE", ns.SettingsUI.GetCurrentLocaleShortLabel())
			end
			PrintSettingValue("GROUP_MENU_TITLE", ns.SettingsUI.GetCurrentGroupShortLabel())
			if ns.SettingsUI.GetCurrentTrainerBehaviorShortLabel then
				PrintSettingValue("TRAINER_BEHAVIOR_MENU_TITLE", ns.SettingsUI.GetCurrentTrainerBehaviorShortLabel())
			end
			PrintSettingState("SETTING_SHOW_LINE_MANA_COST", Database.Get("showLineManaCost"))
			PrintSettingState("SETTING_COMPACT_LIST_MODE", Database.Get("compactListMode"))
			PrintSettingState("SETTING_MOVE_INTERACTIONS_BOTTOM", Database.Get("moveInteractionsToBottom"))
			PrintSettingState("SETTING_QUICK_BIND_SPELLBOOK", Database.Get("quickBindSpellbook"))
			PrintSettingState("SETTING_AUTO_SELECT_PRIMARY_TAB", Database.Get("autoSelectPrimarySpellTab"))
			PrintSettingState("SETTING_ENABLE_SMART_RULES", Database.Get("enableSmartRankRules"))
			PrintSettingValue("UNITHOVER_MODE_MENU_TITLE", ns.SettingsUI.GetCurrentUnitHoverModeShortLabel())
			PrintSettingValue("UNITHOVER_ANCHOR_MENU_TITLE", ns.SettingsUI.GetCurrentUnitHoverAnchorShortLabel())
			PrintSettingState("SETTING_UNITHOVER_SHOW_RANGE", Database.Get("unitHoverShowRange"))
		end
	elseif cmd == "test" or cmd == "testcard" then
		if ClickBindingUI and ClickBindingUI.PrepareSmartRuleTest then
			ClickBindingUI.PrepareSmartRuleTest()
		end
	elseif cmd == "debug" then
		if ClickBindingUI and ClickBindingUI.RunTaintDiagnostics then
			ClickBindingUI.RunTaintDiagnostics(arg)
		end
	elseif cmd == "help" or cmd == "?" then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_HEADER"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_1"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_2"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_3"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_4"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_5"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_6"])
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_LINE_7"])
			DEFAULT_CHAT_FRAME:AddMessage(L["SLASH_HELP_LANG"])
		end
	else
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_HINT"])
		end
	end
end
