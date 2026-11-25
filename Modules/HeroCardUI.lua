local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Colors = Constants.Colors
local ElementDataTypes = Constants.ElementDataTypes
local Database = ns.Database
local SpellRanks = ns.SpellRanks
local SpellBookUI = ns.SpellBookUI
local ClickBindingUI = ns.ClickBindingUI

local HeroCardUI = {}
ns.HeroCardUI = HeroCardUI

local GetRuleShortTag = ClickBindingUI.GetRuleShortTag
local SetSaveButtonGlowShown = ClickBindingUI.SetSaveButtonGlowShown

local heroCardFrame = nil
local dismissedSignature = nil
local smartCheckPending = false

function HeroCardUI.GetFrame()
	return heroCardFrame
end

--------------------------------------------------------------------------------
-- Hero-Card für Smart-Rule-Updates (nach Klassenlehrer, Login oder /reload)
--------------------------------------------------------------------------------

local MAX_HERO_ROWS = 4

local function BuildUpdatesSignature(updates)
	local parts = {}
	for _, u in ipairs(updates) do
		table.insert(parts, string.format("%s:%s->%s", tostring(u.ruleKey or ""), tostring(u.currentEntry and u.currentEntry.actionID or 0), tostring(u.targetEntry and u.targetEntry.actionID or 0)))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

local heroCardPreviewUnlocked = false

local function ApplySavedHeroCardPosition(card)
	card:ClearAllPoints()
	local savedPos = Database.Get("heroCardPos")
	if type(savedPos) == "table" and savedPos.point and savedPos.relativePoint and type(savedPos.x) == "number" and type(savedPos.y) == "number" then
		card:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
	else
		card:SetPoint("TOP", UIParent, "TOP", 0, -95)
	end
end

local function EnsureHeroCardFrame()
	if heroCardFrame then
		return heroCardFrame
	end

	local card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	card:SetSize(390, 180)
	ApplySavedHeroCardPosition(card)
	card:SetFrameStrata("DIALOG")
	card:SetFrameLevel(120)
	card:SetClampedToScreen(true)
	card:SetMovable(true)
	card:EnableMouse(true)
	card:RegisterForDrag("LeftButton")
	card:SetScript("OnDragStart", card.StartMoving)
	card:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
		if point and relativePoint and xOfs and yOfs then
			Database.Set("heroCardPos", {
				point = point,
				relativePoint = relativePoint,
				x = math.floor(xOfs + 0.5),
				y = math.floor(yOfs + 0.5),
			})
		end
	end)
	card:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" and heroCardPreviewUnlocked then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ClickBindingUI.ResetHeroCardPosition()
		end
	end)

	if card.SetBackdrop then
		card:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
	end

	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetSize(24, 24)
	icon:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -13)
	icon:SetAtlas(Constants.ICON_ATLAS)
	card.Icon = icon

	local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	title:SetPoint("RIGHT", card, "RIGHT", -34, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText(L["HEROCARD_TITLE"])
	card.Title = title

	local closeBtn = CreateFrame("Button", nil, card, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		if heroCardPreviewUnlocked and ns.SettingsUI and ns.SettingsUI.SetOverlaysUnlocked then
			ns.SettingsUI.SetOverlaysUnlocked(false)
			return
		end
		if card.mode == "spec_preset" then
			card.pendingSpecPreset = nil
			card.mode = "smart_rules"
			card:Hide()
			return
		end
		if card.currentSignature then
			dismissedSignature = card.currentSignature
		end
		card:Hide()
	end)
	closeBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["HEROCARD_BTN_DISMISS_DESC"], 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	closeBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	card.CloseButton = closeBtn

	local subtitle = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -42)
	subtitle:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -42)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText(L["HEROCARD_SUBTITLE"])
	card.Subtitle = subtitle

	local divider = card:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -5)
	divider:SetPoint("TOPRIGHT", subtitle, "BOTTOMRIGHT", 0, -5)
	divider:SetAlpha(0.6)
	card.Divider = divider

	card.Rows = {}
	for i = 1, MAX_HERO_ROWS do
		local row = CreateFrame("Frame", nil, card)
		row:SetSize(358, 20)
		row:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -62 - ((i - 1) * 22))

		local rowIcon = row:CreateTexture(nil, "ARTWORK")
		rowIcon:SetSize(18, 18)
		rowIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.Icon = rowIcon

		local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		rowText:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
		rowText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		rowText:SetJustifyH("LEFT")
		rowText:SetWordWrap(false)
		row.Text = rowText

		row:Hide()
		card.Rows[i] = row
	end

	local moreText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	moreText:SetJustifyH("LEFT")
	moreText:Hide()
	card.MoreText = moreText

	local applyBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
	applyBtn:SetSize(172, 24)
	applyBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 14)
	applyBtn:SetText(L["HEROCARD_BTN_OPEN_APPLY"])
	applyBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if heroCardPreviewUnlocked then
			if ns.SettingsUI and ns.SettingsUI.SetOverlaysUnlocked then
				ns.SettingsUI.SetOverlaysUnlocked(false)
			else
				ClickBindingUI.SetHeroCardPreviewUnlocked(false)
			end
			return
		end
		if card.mode == "spec_preset" and card.pendingSpecPreset then
			local targetPreset = card.pendingSpecPreset
			card.pendingSpecPreset = nil
			card.mode = "smart_rules"
			card:Hide()
			ClickBindingUI.LoadPreset(targetPreset)
			return
		end
		card:Hide()
		if ClickBindingFrame and ClickBindingFrame:IsShown() then
			ClickBindingUI.ApplySmartRulesToDataProvider(false)
		elseif ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			ns.MinimapButton.ToggleClickCastingWindow()
			if ClickBindingFrame and ClickBindingFrame:IsShown() then
				ClickBindingUI.SetupHooks()
				ClickBindingUI.ApplySmartRulesToDataProvider(false)
			end
		end
	end)
	applyBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if heroCardPreviewUnlocked then
			GameTooltip_SetTitle(GameTooltip, L["OVERLAY_UNLOCK_BTN_LOCK_ALL"])
			GameTooltip_AddNormalLine(GameTooltip, L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"], true)
		elseif card.mode == "spec_preset" and card.pendingSpecPreset then
			GameTooltip_SetTitle(GameTooltip, string.format(L["HEROCARD_SPEC_BTN_LOAD_FORMAT"], tostring(card.pendingSpecPreset.name or "")))
			GameTooltip_AddNormalLine(GameTooltip, L["HEROCARD_SPEC_BTN_LOAD_DESC"], true)
		else
			GameTooltip_SetTitle(GameTooltip, L["HEROCARD_BTN_OPEN_APPLY"])
			GameTooltip_AddNormalLine(GameTooltip, L["HEROCARD_BTN_OPEN_APPLY_DESC"], true)
		end
		GameTooltip:Show()
	end)
	applyBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	card.ApplyButton = applyBtn

	local keepBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
	keepBtn:SetSize(172, 24)
	keepBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 14)
	keepBtn:SetText(L["HEROCARD_BTN_KEEP_CURRENT"])
	keepBtn:SetScript("OnClick", function()
		if heroCardPreviewUnlocked then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			if ns.SettingsUI and ns.SettingsUI.ResetAllOverlayPositions then
				ns.SettingsUI.ResetAllOverlayPositions()
			else
				ClickBindingUI.ResetHeroCardPosition()
			end
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		if card.mode == "spec_preset" then
			card.pendingSpecPreset = nil
			card.mode = "smart_rules"
			card:Hide()
			return
		end
		local updates = card.pendingUpdates or {}
		local lockedCount = 0
		for _, u in ipairs(updates) do
			if u.bindingInfo then
				SpellRanks.SetRuleForBinding(u.bindingInfo, SpellRanks.RULE_FIXED, u.currentEntry)
				lockedCount = lockedCount + 1
			end
		end
		card:Hide()
		ClickBindingUI.RefreshVisibleLines()
		if lockedCount > 0 and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_SMART_RULES_LOCKED_FIXED_FORMAT"], lockedCount))
		end
	end)
	keepBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if heroCardPreviewUnlocked then
			GameTooltip_SetTitle(GameTooltip, L["OVERLAY_UNLOCK_BTN_RESET_POS"])
			GameTooltip_AddNormalLine(GameTooltip, L["OVERLAY_UNLOCK_BTN_RESET_POS_DESC"], true)
		elseif card.mode == "spec_preset" then
			GameTooltip_SetTitle(GameTooltip, L["HEROCARD_SPEC_BTN_DISMISS"])
			GameTooltip_AddNormalLine(GameTooltip, L["HEROCARD_SPEC_BTN_DISMISS_DESC"], true)
		else
			GameTooltip_SetTitle(GameTooltip, L["HEROCARD_BTN_KEEP_CURRENT"])
			GameTooltip_AddNormalLine(GameTooltip, L["HEROCARD_BTN_KEEP_CURRENT_DESC"], true)
		end
		GameTooltip:Show()
	end)
	keepBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	card.KeepButton = keepBtn
	card.mode = "smart_rules"

	card:Hide()
	heroCardFrame = card
	return card
end

function HeroCardUI.ResetHeroCardPosition()
	if type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.heroCardPos = nil
	end
	Database.Set("heroCardPos", nil)
	if heroCardFrame then
		ApplySavedHeroCardPosition(heroCardFrame)
	end
end

function HeroCardUI.IsHeroCardPreviewUnlocked()
	return heroCardPreviewUnlocked
end

function HeroCardUI.SetHeroCardPreviewUnlocked(unlocked)
	heroCardPreviewUnlocked = unlocked and true or false
	local card = EnsureHeroCardFrame()

	if heroCardPreviewUnlocked then
		ApplySavedHeroCardPosition(card)
		if card.SetBackdropBorderColor then
			card:SetBackdropBorderColor(0.35, 1.0, 0.45, 1.0)
		end
		card.Title:SetText("|cff55ff66" .. L["HEROCARD_PREVIEW_TITLE"] .. "|r")
		card.Subtitle:SetText("|cff88ee99" .. L["HEROCARD_PREVIEW_SUBTITLE"] .. "|r")
		card.ApplyButton:SetText(L["OVERLAY_UNLOCK_BTN_LOCK_ALL"])
		card.KeepButton:SetText(L["OVERLAY_UNLOCK_BTN_RESET_POS"])

		for i = 1, MAX_HERO_ROWS do
			card.Rows[i]:Hide()
		end
		card.MoreText:Hide()

		card.Rows[1].Icon:SetTexture(135907)
		card.Rows[1].Text:SetText(L["HEROCARD_PREVIEW_ROW_1"])
		card.Rows[1]:Show()

		card.Rows[2].Icon:SetTexture(135953)
		card.Rows[2].Text:SetText(L["HEROCARD_PREVIEW_ROW_2"])
		card.Rows[2]:Show()

		card:SetHeight(110 + (2 * 22))
		card:Show()
	else
		if card.SetBackdropBorderColor then
			card:SetBackdropBorderColor(1.0, 1.0, 1.0, 1.0)
		end
		card.Title:SetText(L["HEROCARD_TITLE"])
		card.Subtitle:SetText(L["HEROCARD_SUBTITLE"])
		card.ApplyButton:SetText(L["HEROCARD_BTN_OPEN_APPLY"])
		card.KeepButton:SetText(L["HEROCARD_BTN_KEEP_CURRENT"])
		card:Hide()
		ClickBindingUI.CheckAndShowHeroCard(false)
	end
end

function HeroCardUI.HideHeroCard()
	if heroCardPreviewUnlocked then
		ClickBindingUI.SetHeroCardPreviewUnlocked(false)
	end
	if heroCardFrame then
		heroCardFrame.pendingSpecPreset = nil
		heroCardFrame.mode = "smart_rules"
		heroCardFrame:Hide()
	end
end

function HeroCardUI.CheckAndShowHeroCard(resetDismissed)
	if resetDismissed then
		dismissedSignature = nil
	end

	if Constants.IsGamepadUIActive() then
		ClickBindingUI.HideHeroCard()
		return
	end

	if heroCardPreviewUnlocked then
		return
	end

	-- Eine aktive Dual-Spec-Preset-Hero-Card darf durch einen nachfolgenden Hintergrund-Smart-Rule-Check
	-- nicht sofort wieder ausgeblendet werden.
	if heroCardFrame and heroCardFrame:IsShown() and heroCardFrame.mode == "spec_preset" then
		return
	end

	if not Database.Get("enableSmartRankRules") then
		ClickBindingUI.HideHeroCard()
		return
	end

	local trainerBehavior = Database.Get("trainerUpgradeBehavior") or "card"
	if trainerBehavior == "off" then
		ClickBindingUI.HideHeroCard()
		return
	end

	-- Niemals im Kampf oder während das Klassenlehrer- bzw. Klickbelegungs-Fenster offen ist einblenden
	if (InCombatLockdown and InCombatLockdown())
		or (ClassTrainerFrame and ClassTrainerFrame:IsShown())
		or (ClickBindingFrame and ClickBindingFrame:IsShown())
	then
		ClickBindingUI.HideHeroCard()
		return
	end

	local updates = SpellRanks.GetPendingSmartRuleUpdates()
	if #updates == 0 then
		dismissedSignature = nil
		ClickBindingUI.HideHeroCard()
		return
	end

	local sig = BuildUpdatesSignature(updates)
	if dismissedSignature and dismissedSignature == sig then
		return
	end

	-- Im Modus "Auto-Öffnen & Vorbereiten" (/bcc automatisch öffnen, Ränge eintragen und Speichern-Button hervorheben)
	if trainerBehavior == "auto" then
		dismissedSignature = sig
		ClickBindingUI.HideHeroCard()
		if ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			if not (ClickBindingFrame and ClickBindingFrame:IsShown()) then
				ns.MinimapButton.ToggleClickCastingWindow()
			end
		end
		ClickBindingUI.SetupHooks()
		ClickBindingUI.ApplySmartRulesToDataProvider(false)
		return
	end

	local card = EnsureHeroCardFrame()
	card.mode = "smart_rules"
	card.pendingSpecPreset = nil
	card.pendingUpdates = updates
	card.currentSignature = sig
	ApplySavedHeroCardPosition(card)
	if card.SetBackdropBorderColor then
		card:SetBackdropBorderColor(1.0, 1.0, 1.0, 1.0)
	end
	card.Title:SetText(L["HEROCARD_TITLE"])
	card.Subtitle:SetText(L["HEROCARD_SUBTITLE"])
	card.ApplyButton:SetText(L["HEROCARD_BTN_OPEN_APPLY"])
	card.KeepButton:SetText(L["HEROCARD_BTN_KEEP_CURRENT"])

	-- Alle Zeilen-Widgets zuerst verstecken (Frame-Recycling-Hygiene)
	for i = 1, MAX_HERO_ROWS do
		card.Rows[i]:Hide()
	end
	card.MoreText:Hide()

	local shownCount = math.min(#updates, MAX_HERO_ROWS)
	for i = 1, shownCount do
		local u = updates[i]
		local row = card.Rows[i]
		row.Icon:SetTexture(u.spellIcon or 134400)

		local shortBind = Constants.GetShortBindingString(u.bindingInfo) or ""
		local curSub = (u.currentEntry and u.currentEntry.subName ~= "" and u.currentEntry.subName) or "?"
		local tgtSub = (u.targetEntry and u.targetEntry.subName ~= "" and u.targetEntry.subName) or "?"
		local ruleTag = GetRuleShortTag(u.ruleMode, u.ruleMode == SpellRanks.RULE_MAX)

		row.Text:SetText(string.format(
			"%s %s[%s]%s: %s%s%s -> %s%s (%s)%s",
			u.spellName or "?",
			Colors.MUTED,
			shortBind,
			Colors.RESET,
			Colors.RANK_DOWN,
			curSub,
			Colors.RESET,
			Colors.TAG_MAX,
			tgtSub,
			ruleTag,
			Colors.RESET
		))
		row:Show()
	end

	local extraCount = #updates - shownCount
	local totalHeight = 110 + (shownCount * 22)
	if extraCount > 0 then
		card.MoreText:ClearAllPoints()
		card.MoreText:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -62 - (shownCount * 22))
		card.MoreText:SetText(string.format(L["HEROCARD_MORE_FORMAT"], extraCount))
		card.MoreText:Show()
		totalHeight = totalHeight + 18
	end

	card:SetHeight(totalHeight)
	card:Show()
end

function HeroCardUI.ScheduleSmartRuleCheck(delaySeconds, resetDismissed)
	if resetDismissed then
		dismissedSignature = nil
	end
	if Constants.IsGamepadUIActive() then
		return
	end
	if smartCheckPending then
		return
	end
	if not C_Timer or not C_Timer.After then
		ClickBindingUI.CheckAndShowHeroCard(false)
		return
	end
	smartCheckPending = true
	C_Timer.After(delaySeconds or 0.6, function()
		smartCheckPending = false
		ClickBindingUI.CheckAndShowHeroCard(false)
	end)
end

-- Test-Helfer (/bcc test): Bereitet im ClickBindingFrame genau 2 Zauber für die Regeln
-- "Immer MAX" und "Immer MAX - 1" mit abweichendem Ist-Rang vor, sodass nach Klick auf
-- "Speichern" sofort die Hero-Card mit beiden Regeln getestet werden kann.
function HeroCardUI.PrepareSmartRuleTest()
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	if not (ClickBindingFrame and ClickBindingFrame:IsShown()) and ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
		ns.MinimapButton.ToggleClickCastingWindow()
	end
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return
	end

	ClickBindingUI.SetupHooks()
	SpellRanks.InvalidateCache()

	local testRules = {
		SpellRanks.RULE_MAX,
		SpellRanks.RULE_MAX_MINUS_1,
	}
	local ruleIdx = 1

	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		if ruleIdx > #testRules then
			break
		end
		local info = element and not element.unbound and element.bindingInfo
		if info and info.button and info.actionID and Constants.IsSpellOrPetBinding(info) then
			local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
			local group = rankEntry and rankEntry.group
			if group and #group.entries > 1 then
				local mode = testRules[ruleIdx]
				local targetEntry = SpellRanks.GetTargetEntryForRule(group, mode)
				if targetEntry then
					-- Einen abweichenden Rang aus derselben Gruppe wählen, damit ein echtes Update ansteht
					local deviantEntry = nil
					for _, candidate in ipairs(group.entries) do
						if candidate.actionID ~= targetEntry.actionID then
							deviantEntry = candidate
							break
						end
					end
					if deviantEntry then
						info.actionID = deviantEntry.actionID
						SpellRanks.SetRuleForBinding(info, mode, deviantEntry)
						ruleIdx = ruleIdx + 1
					end
				end
			end
		end
	end

	local preparedCount = ruleIdx - 1
	if preparedCount > 0 then
		dismissedSignature = nil
		if ClickBindingFrame.CleanDataProvider then
			ClickBindingFrame:CleanDataProvider()
		end
		ClickBindingUI.RebuildGroups()
		ClickBindingFrame.pendingChanges = true
		SetSaveButtonGlowShown(true)
		ClickBindingUI.RefreshVisibleLines()
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff40ff40Better Click Casting (Test):|r " .. tostring(preparedCount) .. " Belegung(en) für Smart-Regel-Test (Immer MAX & Immer MAX - 1) vorbereitet. Klicke jetzt auf |cffffd100Speichern|r!")
		end
		elseif DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffb833Better Click Casting (Test):|r Keine mehrstufigen Zauber in deinen Klickbelegungen gefunden.")
	end
end

-- Zeigt nach einem Dual-Spec-Wechsel (Spec 1 <-> Spec 2) die Hero-Card mit einem 1-Klick-Button
-- zum Öffnen & Laden des mit dem neuen Spec verknüpften Presets an (da C_ClickBindings.SetProfileByInfo
-- geschützt ist und stets den Hardware-Klick des Spielers auf Blizzards Speichern-Button erfordert).
function HeroCardUI.ShowSpecPresetHeroCard(specIdx, linkedPreset)
	if Constants.IsGamepadUIActive() or heroCardPreviewUnlocked then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	if type(linkedPreset) ~= "table" or not linkedPreset.name or linkedPreset.name == "" then
		return false
	end

	local card = EnsureHeroCardFrame()
	card.mode = "spec_preset"
	card.pendingSpecPreset = linkedPreset
	card.pendingUpdates = nil
	card.currentSignature = nil

	ApplySavedHeroCardPosition(card)
	if card.SetBackdropBorderColor then
		card:SetBackdropBorderColor(0.35, 0.80, 1.0, 1.0)
	end

	local specNum = tonumber(specIdx) or 1
	local presetName = tostring(linkedPreset.name)
	local bCount = (type(linkedPreset.bindings) == "table") and #linkedPreset.bindings or 0

	card.Title:SetText(string.format(L["HEROCARD_SPEC_TITLE_FORMAT"], specNum))
	card.Subtitle:SetText(string.format(L["HEROCARD_SPEC_SUBTITLE_FORMAT"], presetName))
	card.ApplyButton:SetText(string.format(L["HEROCARD_SPEC_BTN_LOAD_FORMAT"], presetName))
	card.KeepButton:SetText(L["HEROCARD_SPEC_BTN_DISMISS"])

	for i = 1, MAX_HERO_ROWS do
		card.Rows[i]:Hide()
	end
	card.MoreText:Hide()

	-- Dominantes Talentbaum-Icon des Ziel-Specs (z. B. Schatten / Heilig / Disziplin);
	-- Fallback auf Blizzards neutrales Talent-Icon (132222), wenn Spec 2 nicht freigeschaltet oder ohne Punkte ist.
	local rowIconID = (Constants.GetPrimaryTalentTreeIconForSpecGroup and Constants.GetPrimaryTalentTreeIconForSpecGroup(specNum)) or 132222

	card.Rows[1].Icon:SetTexture(rowIconID)
	card.Rows[1].Text:SetText(string.format(L["HEROCARD_SPEC_ROW_FORMAT"], presetName, bCount))
	card.Rows[1]:Show()

	card:SetHeight(110 + 22)
	card:Show()
	return true
end

-- Interaktiver Live-Simulator (/bcc test spec [1|2]):
-- Simuliert einen Dual-Spec-Wechsel auf Spec 1 oder 2 und zeigt die echte Dual-Spec Hero-Card
-- (bzw. lädt im Modus "auto" direkt in /bcc), ohne SavedVariables zu verändern.
function HeroCardUI.SimulateDualSpecHeroCardTest(specIndexOverride, isSilentTest)
	if Constants.IsGamepadUIActive() then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		if not isSilentTest and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
		end
		return false
	end

	local curSpec = (Constants.GetActiveSpecGroupIndex and Constants.GetActiveSpecGroupIndex()) or 1
	local targetSpec = tonumber(specIndexOverride)
	if targetSpec ~= 1 and targetSpec ~= 2 then
		targetSpec = (curSpec == 1) and 2 or 1
	end

	local linkedPreset = Database.GetPresetForSpecGroup and Database.GetPresetForSpecGroup(targetSpec)
	local isDemoFallback = false
	if not linkedPreset then
		isDemoFallback = true
		local snapBindings = (Database.CaptureBindingsSnapshot and Database.CaptureBindingsSnapshot(false)) or {}
		linkedPreset = {
			name = "Demo Spec " .. tostring(targetSpec),
			bindings = snapBindings,
			_bccIsDemoTest = true,
		}
	end

	local behavior = Database.Get("trainerUpgradeBehavior") or "card"
	if not isSilentTest and behavior == "auto" then
		ClickBindingUI.LoadPreset(linkedPreset)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff40ff40Better Click Casting (Test):|r Dual-Spec-Wechsel auf Spec %d simuliert (Modus: Auto-Öffnen, Preset '%s').", targetSpec, tostring(linkedPreset.name)))
		end
		return true
	end

	local shown = ClickBindingUI.ShowSpecPresetHeroCard(targetSpec, linkedPreset)
	if shown and not isSilentTest and DEFAULT_CHAT_FRAME then
		local srcHint = isDemoFallback and "temporäres Demo-Preset ohne DB-Änderung" or "echtes verknüpftes Spec-Preset"
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff40ff40Better Click Casting (Test):|r Dual-Spec Hero-Card für Spec %d eingeblendet ('%s', %s).", targetSpec, tostring(linkedPreset.name), srcHint))
	end
	return shown
end

-- Reagiert auf einen Dual-Spec-Wechsel (ACTIVE_TALENT_GROUP_CHANGED / PLAYER_TALENT_UPDATE):
-- Stellt bei offenem ClickBindingFrame versehentlich durch Blizzard gelöschte Talent-Zauber wieder her,
-- aktualisiert Zauberbuch-Cache & UI und lädt (oder zeigt per Hero-Card) ein mit dem neuen Spec (1 oder 2) verknüpftes Preset.
function HeroCardUI.OnActiveSpecGroupChanged(specIndexOverride, isSilentTest)
	if Constants.IsGamepadUIActive() then
		SpellRanks.InvalidateCache()
		return false
	end
	SpellRanks.InvalidateCache()
	SpellRanks.EnsureCache()
	if ClickBindingFrame and ClickBindingFrame:IsShown() then
		ClickBindingUI.RestorePurgedUnlearnedBindings(isSilentTest)
	end
	ClickBindingUI.RefreshVisibleLines()
	if SpellBookUI and SpellBookUI.RefreshBadges then
		SpellBookUI.RefreshBadges()
	end

	local specIdx = tonumber(specIndexOverride) or (Constants.GetActiveSpecGroupIndex and Constants.GetActiveSpecGroupIndex()) or 1
	local linkedPreset = Database.GetPresetForSpecGroup and Database.GetPresetForSpecGroup(specIdx)
	if linkedPreset and linkedPreset.name then
		local activeName = Database.GetActivePresetName and Database.GetActivePresetName()
		if activeName ~= linkedPreset.name then
			local behavior = Database.Get("trainerUpgradeBehavior") or "card"
			if not isSilentTest and not (InCombatLockdown and InCombatLockdown()) then
				if behavior == "auto" or (ClickBindingFrame and ClickBindingFrame:IsShown()) then
					ClickBindingUI.LoadPreset(linkedPreset)
					return true, linkedPreset.name
				elseif behavior == "card" then
					ClickBindingUI.ShowSpecPresetHeroCard(specIdx, linkedPreset)
					return true, linkedPreset.name
				end
			end
			if not isSilentTest and DEFAULT_CHAT_FRAME and L["CHAT_DUAL_SPEC_PRESET_READY_FORMAT"] then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_DUAL_SPEC_PRESET_READY_FORMAT"], specIdx, linkedPreset.name, linkedPreset.name))
			end
			return true, linkedPreset.name
		end
	end
	if not isSilentTest and ClickBindingUI.ScheduleSmartRuleCheck then
		ClickBindingUI.ScheduleSmartRuleCheck(0.6, false)
	end
	return false, nil
end

-- Kompatible Fassade auf ns.ClickBindingUI beibehalten
for k, fn in pairs(HeroCardUI) do
	if type(fn) == "function" and k ~= "GetFrame" then
		ClickBindingUI[k] = fn
	end
end
