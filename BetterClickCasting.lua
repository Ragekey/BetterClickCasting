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

SLASH_BETTERCLICKCASTING1 = "/bcc"
SLASH_BETTERCLICKCASTING2 = "/betterclickcasting"
SLASH_BETTERCLICKCASTING3 = "/betterclickcastings"
SlashCmdList["BETTERCLICKCASTING"] = function(msg)
	local cmd = string.lower(strtrim(msg or ""))
	if cmd == "minimap" or cmd == "mm" then
		Database.Toggle("showMinimapButton")
	elseif cmd == "test" or cmd == "testcard" then
		if ClickBindingUI and ClickBindingUI.PrepareSmartRuleTest then
			ClickBindingUI.PrepareSmartRuleTest()
		end
	elseif cmd == "debug" or string.sub(cmd, 1, 6) == "debug " then
		if ClickBindingUI and ClickBindingUI.RunTaintDiagnostics then
			local subArg = strtrim(string.sub(cmd, 7))
			ClickBindingUI.RunTaintDiagnostics(subArg)
		end
	elseif cmd == "help" or cmd == "?" then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_HELP_HINT"])
		end
	else
		MinimapButton.ToggleClickCastingWindow()
	end
end
