local _, ns = ...

local Database = {}
ns.Database = Database

local DEFAULTS = {
	showRankInName = true,
	highlightDownranks = true,
	showRankSwitcher = true,
	showLineTooltips = true,
	groupingMode = "modifier", -- "modifier", "button", "type", "none"
	quickBindSpellbook = true,
	showSpellbookBadges = true,
	autoShowAllRanks = true,
	enableSmartRankRules = true,
	unitHoverMode = "off", -- "off", "modifier", "always"
	unitHoverAnchor = "cursor", -- "cursor", "top", "bottom", "left", "right", "free"
	unitHoverShowInCombat = false,
	unitHoverShowInteractions = false,
	showMinimapButton = true,
	minimapAngle = 225,
}

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
	BetterClickCastingsDB = BetterClickCastingDB
	return BetterClickCastingDB
end

function Database.Get(key)
	if type(BetterClickCastingDB) ~= "table" then
		Database.Init()
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
	BetterClickCastingDB[key] = value
	Database.NotifyChanged(key, value)
end

function Database.Toggle(key)
	local newVal = not Database.Get(key)
	Database.Set(key, newVal)
	return newVal
end

function Database.NotifyChanged(key, value)
	if ns.ClickBindingUI then
		if key == "autoShowAllRanks" and ns.ClickBindingUI.SyncAutoShowAllRanks then
			ns.ClickBindingUI.SyncAutoShowAllRanks()
		end
		if key == "groupingMode" and ns.ClickBindingUI.RebuildGroups then
			ns.ClickBindingUI.RebuildGroups()
		end
		if key == "enableSmartRankRules" and ns.ClickBindingUI.ScheduleSmartRuleCheck then
			ns.ClickBindingUI.ScheduleSmartRuleCheck(0.1)
		end
		if ns.ClickBindingUI.RefreshVisibleLines then
			ns.ClickBindingUI.RefreshVisibleLines()
		end
	end
	if ns.SpellBookUI and ns.SpellBookUI.RefreshBadges then
		ns.SpellBookUI.RefreshBadges()
	end
	if ns.MinimapButton and ns.MinimapButton.UpdateVisibility then
		ns.MinimapButton.UpdateVisibility()
	end
	if ns.UnitHoverTooltip and ns.UnitHoverTooltip.OnSettingChanged then
		ns.UnitHoverTooltip.OnSettingChanged(key, value)
	end
end
