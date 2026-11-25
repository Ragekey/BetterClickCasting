local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Colors = Constants.Colors
local ElementDataTypes = Constants.ElementDataTypes
local Database = ns.Database
local SpellRanks = ns.SpellRanks
local SpellBookUI = ns.SpellBookUI
local SettingsUI = ns.SettingsUI

local ClickBindingUI = {}
ns.ClickBindingUI = ClickBindingUI

local isHooked = false
local isSaveButtonHooked = false
local isRebuildingGroups = false
local gamepadStandbyBadge = nil
local saveButtonGlowFrame = nil
local combatLockActive = false
local lastKnownProviderCustomBindings = {}
local isManualDeleteInProgress = false

local SMART_RULE_OPTIONS = {
	{ mode = SpellRanks.RULE_MAX,         labelKey = "SMART_RULE_MAX" },
	{ mode = SpellRanks.RULE_MAX_MINUS_1, labelKey = "SMART_RULE_MAX_MINUS_1" },
	{ mode = SpellRanks.RULE_MAX_MINUS_2, labelKey = "SMART_RULE_MAX_MINUS_2" },
	{ mode = SpellRanks.RULE_MAX_MINUS_3, labelKey = "SMART_RULE_MAX_MINUS_3" },
	{ mode = SpellRanks.RULE_FIXED,       labelKey = "SMART_RULE_FIXED" },
}

local function GetRuleDisplayName(ruleMode)
	for _, opt in ipairs(SMART_RULE_OPTIONS) do
		if opt.mode == ruleMode then
			return L[opt.labelKey]
		end
	end
	return L["SMART_RULE_MAX"]
end

local function GetRuleShortTag(ruleMode, isMaxRank)
	if ruleMode == SpellRanks.RULE_MAX_MINUS_1 then
		return L["TAG_RULE_M1_SHORT"]
	elseif ruleMode == SpellRanks.RULE_MAX_MINUS_2 then
		return L["TAG_RULE_M2_SHORT"]
	elseif ruleMode == SpellRanks.RULE_MAX_MINUS_3 then
		return L["TAG_RULE_M3_SHORT"]
	elseif ruleMode == SpellRanks.RULE_FIXED then
		return isMaxRank and L["TAG_MAX_SHORT"] or L["TAG_RULE_FIX_SHORT"]
	end
	return L["TAG_MAX_SHORT"]
end

--------------------------------------------------------------------------------
-- Logische Gruppierung und Sortierung im ClickBindingFrame
--------------------------------------------------------------------------------

local function GetElementGroupMetadata(elementData, groupingMode)
	if not elementData or elementData.elementType ~= ElementDataTypes.CustomsBinding then
		return 0, "", 999, 999
	end

	local info = elementData.bindingInfo
	if not info or elementData.unbound or not info.button then
		return 900, L["GROUP_HDR_UNBOUND"], 999, 999
	end

	local btnOrder = Constants.GetButtonSortOrder(info.button)
	local modOrder, modReadable = Constants.GetModifierSortInfo(info.modifiers)

	if groupingMode == "modifier" then
		if modOrder == 1 or modReadable == "" then
			return 100, L["GROUP_HDR_NO_MOD"], btnOrder, modOrder
		else
			-- Eindeutige Gruppen-Ordnung pro Modifier-Kombination (z. B. Shift = 200, Strg = 300, Alt = 400)
			return (modOrder * 100), string.format(L["GROUP_HDR_MOD_FORMAT"], modReadable), btnOrder, modOrder
		end
	elseif groupingMode == "button" then
		local btnTitle = Constants.GetButtonDisplayName(info.button)
		local shortBtn = Constants.GetShortBindingString({ button = info.button, modifiers = 0 })
		if shortBtn and shortBtn ~= "" then
			btnTitle = string.format("%s (%s)", btnTitle, shortBtn)
		end
		return (btnOrder * 100), btnTitle, btnOrder, modOrder
	elseif groupingMode == "type" then
		if Enum and Enum.ClickBindingType then
			if info.type == Enum.ClickBindingType.Spell then
				return 100, L["GROUP_HDR_SPELLS"], btnOrder, modOrder
			elseif info.type == Enum.ClickBindingType.PetAction then
				return 200, L["GROUP_HDR_PET"], btnOrder, modOrder
			elseif info.type == Enum.ClickBindingType.Macro then
				return 300, L["GROUP_HDR_MACROS"], btnOrder, modOrder
			end
		end
		return 400, L["GROUP_HDR_SPELLS"], btnOrder, modOrder
	end

	-- Modus "none" (flache Liste, aber logisch sortiert)
	return 100, "", btnOrder, modOrder
end

local function GetPrimarySectionRank(e)
	if not e then
		return 99
	end
	local moveBottom = Database.Get("moveInteractionsToBottom")
	if e.elementType == ElementDataTypes.DefaultsHeader then
		return moveBottom and 60 or 10
	elseif e.elementType == ElementDataTypes.InteractionBinding then
		return moveBottom and 70 or 20
	elseif e.elementType == ElementDataTypes.CustomsHeader and not e.isBCCGroupHeader then
		return 30
	elseif e.isBCCNewSlotHeader then
		return 45
	elseif e.elementType == ElementDataTypes.NewSlot then
		return 50
	end
	-- Sowohl eigene Untergruppen-Header (isBCCGroupHeader) als auch CustomsBinding liegen in Sektion 40
	return 40
end

local function GetSortTupleForSection40(e, mode)
	if e.isBCCGroupHeader then
		return e._bccGroupOrder or 100, e.bccGroupTitle or "", true, 0, 0
	end
	local groupOrder, groupTitle, btnOrder, modOrder = GetElementGroupMetadata(e, mode)
	return groupOrder, groupTitle, false, btnOrder, modOrder
end

local function BCCElementSortComparator(e1, e2)
	if e1 == e2 then
		return false
	end

	local r1 = GetPrimarySectionRank(e1)
	local r2 = GetPrimarySectionRank(e2)
	if r1 ~= r2 then
		return r1 < r2
	end

	if r1 == 20 or r1 == 70 then
		local id1 = (e1.bindingInfo and e1.bindingInfo.actionID) or 0
		local id2 = (e2.bindingInfo and e2.bindingInfo.actionID) or 0
		if id1 ~= id2 then
			return id1 < id2
		end
		return false
	end

	if r1 ~= 40 then
		return false
	end

	local mode = Database.Get("groupingMode") or "modifier"
	local g1, title1, isHdr1, b1, m1 = GetSortTupleForSection40(e1, mode)
	local g2, title2, isHdr2, b2, m2 = GetSortTupleForSection40(e2, mode)

	-- 1. Gruppen-Reihenfolge (inkl. Titel-Feinunterscheidung bei gleichem numerischen Rang)
	if g1 ~= g2 then
		return g1 < g2
	end
	if mode ~= "none" and title1 ~= title2 then
		return title1 < title2
	end

	-- 2. Innerhalb derselben Gruppe steht der Untergruppen-Header immer vor seinen Einträgen
	if isHdr1 ~= isHdr2 then
		return isHdr1
	end
	if isHdr1 and isHdr2 then
		return false
	end

	-- 3. Gebundene Einträge vor ungebundenen Einträgen
	local u1 = e1.unbound and true or false
	local u2 = e2.unbound and true or false
	if u1 ~= u2 then
		return not u1
	end

	-- 4. Logische Sortierung nach Maustaste (LMB -> RMB -> MMB -> MB4 -> MB5) und Modifier
	if mode == "button" then
		if m1 ~= m2 then
			return m1 < m2
		end
		if b1 ~= b2 then
			return b1 < b2
		end
	else
		if b1 ~= b2 then
			return b1 < b2
		end
		if m1 ~= m2 then
			return m1 < m2
		end
	end

	local modRaw1 = (e1.bindingInfo and e1.bindingInfo.modifiers) or 0
	local modRaw2 = (e2.bindingInfo and e2.bindingInfo.modifiers) or 0
	if modRaw1 ~= modRaw2 then
		return modRaw1 < modRaw2
	end

	local btnRaw1 = (e1.bindingInfo and e1.bindingInfo.button) or ""
	local btnRaw2 = (e2.bindingInfo and e2.bindingInfo.button) or ""
	if btnRaw1 ~= btnRaw2 then
		return btnRaw1 < btnRaw2
	end

	local type1 = (e1.bindingInfo and e1.bindingInfo.type) or 0
	local type2 = (e2.bindingInfo and e2.bindingInfo.type) or 0
	if type1 ~= type2 then
		return type1 < type2
	end

	local act1 = (e1.bindingInfo and e1.bindingInfo.actionID) or 0
	local act2 = (e2.bindingInfo and e2.bindingInfo.actionID) or 0
	if act1 ~= act2 then
		return act1 < act2
	end

	return false
end

function ClickBindingUI.RebuildGroups(preserveSnapshot)
	if Constants.IsGamepadUIActive() then
		return
	end
	if isRebuildingGroups or not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return
	end
	isRebuildingGroups = true

	local provider = ClickBindingFrame.dataProvider
	local mode = Database.Get("groupingMode") or "modifier"

	-- Falls eine Zeile über DeleteButton oder SPELLS_CHANGED direkt aus dem DataProvider entfernt wird,
	-- Gruppen und Zähler automatisch nachziehen.
	if not provider._bccRemoveHooked and type(provider.Remove) == "function" then
		hooksecurefunc(provider, "Remove", function()
			if not isRebuildingGroups then
				-- Wichtig: Wenn nicht manuell über DeleteButton gelöscht wurde (also z. B. durch Blizzards
				-- SPELLS_CHANGED-Handler), den Snapshot NICHT überschreiben, damit RestorePurgedUnlearnedBindings
				-- den gelöschten Talent-Zauber unmittelbar danach wiederherstellen kann!
				ClickBindingUI.RebuildGroups(not isManualDeleteInProgress)
			end
		end)
		provider._bccRemoveHooked = true
	end

	-- Wichtig: Vor dem Entfernen/Einfügen von Headern den SortComparator leeren,
	-- damit Blizzards Standard-ElementSortComparator nicht während provider:Insert() auf Header ohne bindingInfo läuft.
	if provider.ClearSortComparator then
		provider:ClearSortComparator()
	end

	-- 1. Alte eigene Untergruppen-Header entfernen
	local oldHeaders = {}
	for _, element in provider:Enumerate() do
		if element and element.isBCCGroupHeader then
			table.insert(oldHeaders, element)
		end
	end
	if #oldHeaders > 0 then
		provider:Remove(unpack(oldHeaders))
	end

	-- 2. Gruppen-Metadaten und Gesamtzähler auf allen Custom-Bindings berechnen
	local groups = {}
	local totalCustomCount = 0
	local hasNewSlot = false
	for _, element in provider:Enumerate() do
		if element and element.elementType == ElementDataTypes.NewSlot then
			hasNewSlot = true
		elseif element and element.elementType == ElementDataTypes.CustomsBinding then
			totalCustomCount = totalCustomCount + 1
			local groupOrder, groupTitle = GetElementGroupMetadata(element, mode)
			if mode ~= "none" and groupTitle ~= "" then
				local groupKey = tostring(groupOrder) .. ":" .. tostring(groupTitle)
				local grp = groups[groupKey]
				if not grp then
					grp = {
						order = groupOrder,
						title = groupTitle,
						count = 0,
					}
					groups[groupKey] = grp
				end
				grp.count = grp.count + 1
			end
		end
	end

	-- Gesamtzähler auch auf dem Haupt-CustomsHeader aktualisieren
	for _, element in provider:Enumerate() do
		if element and element.elementType == ElementDataTypes.CustomsHeader and not element.isBCCGroupHeader then
			element._bccTotalCustomCount = totalCustomCount
		end
	end

	-- 3. Neue Untergruppen-Header gesammelt einfügen (wenn Gruppierung aktiv)
	if mode ~= "none" then
		local newHeaders = {}
		for _, grp in pairs(groups) do
			table.insert(newHeaders, {
				elementType = ElementDataTypes.CustomsHeader,
				isBCCGroupHeader = true,
				_bccGroupOrder = grp.order,
				bccGroupTitle = grp.title,
				bccGroupCount = grp.count,
				bccHeaderText = string.format("%s%s%s  %s(%d)%s", Colors.HEADER_SUB, grp.title, Colors.RESET, Colors.MUTED, grp.count, Colors.RESET),
			})
		end
		-- Bei aktiver Gruppierung und vorhandenen Gruppen den grünen "Neuen Slot hinzufügen"-Eintrag
		-- optisch sauber durch einen eigenen Sektions-Header von der letzten Gruppe absetzen.
		if hasNewSlot and totalCustomCount > 0 then
			local newSlotLabel = (CLICK_BINDING_ADD_BINDING or "Add Binding")
			table.insert(newHeaders, {
				elementType = ElementDataTypes.CustomsHeader,
				isBCCGroupHeader = true,
				isBCCNewSlotHeader = true,
				_bccGroupOrder = 9999,
				bccGroupTitle = newSlotLabel,
				bccGroupCount = 0,
				bccHeaderText = string.format("%s%s%s", Colors.TAG_MAX, newSlotLabel, Colors.RESET),
			})
		end
		if #newHeaders > 0 then
			if provider.InsertTable then
				provider:InsertTable(newHeaders)
			else
				provider:Insert(unpack(newHeaders))
			end
		end
	end

	-- 4. Eigenen Comparator setzen und einmalig sortieren
	provider:SetSortComparator(BCCElementSortComparator, false)

	-- 5. Sichtbare Header- und Zeilen-Frames sofort aktualisieren
	ClickBindingUI.RefreshVisibleLines()

	-- 6. Snapshot der aktuell im DataProvider vorhandenen Custom-Bindings sichern,
	-- damit Blizzards SPELLS_CHANGED-Handler bei offenem /bcc (z. B. beim Dual-Spec-Wechsel)
	-- nicht gelernte Talent-Zauber nicht unbemerkt aus dem DataProvider löschen kann.
	if not preserveSnapshot then
		local snap = {}
		for _, element in provider:Enumerate() do
			if element and element.elementType == ElementDataTypes.CustomsBinding and element.bindingInfo then
				local bInfo = element.bindingInfo
				table.insert(snap, {
					type = bInfo.type,
					actionID = bInfo.actionID,
					button = bInfo.button,
					modifiers = bInfo.modifiers,
					unbound = element.unbound and true or false,
				})
			end
		end
		lastKnownProviderCustomBindings = snap
	end

	isRebuildingGroups = false
end

-- Stellt Custom-Bindings wieder her, die Blizzards ClickBindingFrameMixin:OnEvent("SPELLS_CHANGED")
-- während eines offenen ClickBindingFrame wegen vorübergehend fehlendem Zauberbuch-Eintrag (Dual-Spec) entfernt hat.
function ClickBindingUI.RestorePurgedUnlearnedBindings(silent)
	if Constants.IsGamepadUIActive() then
		return 0
	end
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider or isManualDeleteInProgress then
		return 0
	end
	if type(lastKnownProviderCustomBindings) ~= "table" or #lastKnownProviderCustomBindings == 0 then
		return 0
	end

	local provider = ClickBindingFrame.dataProvider
	local presentKeys = {}
	for _, element in provider:Enumerate() do
		if element and element.elementType == ElementDataTypes.CustomsBinding and element.bindingInfo then
			local info = element.bindingInfo
			local key = string.format("%s:%s:%s:%s", tostring(info.type or 0), tostring(info.actionID or 0), tostring(info.button or ""), tostring(info.modifiers or 0))
			presentKeys[key] = true
		end
	end

	local restored = 0
	for _, saved in ipairs(lastKnownProviderCustomBindings) do
		local key = string.format("%s:%s:%s:%s", tostring(saved.type or 0), tostring(saved.actionID or 0), tostring(saved.button or ""), tostring(saved.modifiers or 0))
		if not presentKeys[key] and saved.type == (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Spell or 1) and saved.actionID then
			provider:Insert({
				elementType = ElementDataTypes.CustomsBinding,
				bindingInfo = {
					type = saved.type,
					actionID = saved.actionID,
					button = saved.button,
					modifiers = saved.modifiers,
				},
				unbound = saved.unbound and true or false,
			})
			presentKeys[key] = true
			restored = restored + 1
		end
	end

	if restored > 0 then
		ClickBindingUI.RebuildGroups()
		ClickBindingUI.RefreshVisibleLines()
		if not silent and DEFAULT_CHAT_FRAME and L["CHAT_DUAL_SPEC_RESTORED_FORMAT"] then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_DUAL_SPEC_RESTORED_FORMAT"], restored))
		end
	end
	return restored
end

--------------------------------------------------------------------------------
-- Visuelles Highlight auf Blizzards Speichern-Button (bei Smart-Rule-Updates)
--------------------------------------------------------------------------------

local function SetSaveButtonGlowShown(shown)
	if Constants.IsGamepadUIActive()
		or not shown
		or not ClickBindingFrame
		or not ClickBindingFrame:IsShown()
		or not ClickBindingFrame.SaveButton
	then
		if saveButtonGlowFrame then
			saveButtonGlowFrame:Hide()
		end
		return
	end
	local saveBtn = ClickBindingFrame.SaveButton
	if not saveButtonGlowFrame then
		-- Exaktes 3-Slice YellowGlow-Pattern aus Blizzard_SharedTalentFrameTemplates.xml (CommitButton.YellowGlow),
		-- aber strikt auf UIParent geparentet (keine Felder oder Kinder auf Blizzards SaveButton).
		local glowFrame = CreateFrame("Frame", nil, UIParent)
		glowFrame:SetSize(1, 1)
		glowFrame:EnableMouse(false)

		local left = glowFrame:CreateTexture(nil, "ARTWORK")
		left:SetAtlas("newplayertutorial-yellowGlow-redbutton-left", true)
		left:SetBlendMode("ADD")
		left:SetPoint("LEFT")
		glowFrame.Left = left

		local right = glowFrame:CreateTexture(nil, "ARTWORK")
		right:SetAtlas("newplayertutorial-yellowGlow-redbutton-right", true)
		right:SetBlendMode("ADD")
		right:SetPoint("RIGHT")
		glowFrame.Right = right

		local middle = glowFrame:CreateTexture(nil, "ARTWORK")
		middle:SetAtlas("newplayertutorial-yellowGlow-redbutton-middle", false)
		middle:SetBlendMode("ADD")
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		glowFrame.Middle = middle

		local hint = glowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		hint:SetPoint("BOTTOMRIGHT", glowFrame, "TOPRIGHT", -12, 14)
		hint:SetText(Colors.HEADER_SUB .. L["SAVE_BUTTON_GLOW_HINT"] .. Colors.RESET)
		glowFrame.Hint = hint

		saveButtonGlowFrame = glowFrame
	end
	saveButtonGlowFrame:SetFrameStrata(saveBtn:GetFrameStrata() or "MEDIUM")
	saveButtonGlowFrame:SetFrameLevel((saveBtn:GetFrameLevel() or 1) + 2)
	saveButtonGlowFrame:ClearAllPoints()
	saveButtonGlowFrame:SetPoint("LEFT", saveBtn, "LEFT", -12, 0)
	saveButtonGlowFrame:SetPoint("RIGHT", saveBtn, "RIGHT", 12, 0)
	if saveButtonGlowFrame.Hint then
		saveButtonGlowFrame.Hint:ClearAllPoints()
		saveButtonGlowFrame.Hint:SetPoint("BOTTOMRIGHT", saveBtn, "TOPRIGHT", 0, 5)
		saveButtonGlowFrame.Hint:SetText(Colors.HEADER_SUB .. L["SAVE_BUTTON_GLOW_HINT"] .. Colors.RESET)
	end
	saveButtonGlowFrame:Show()
end

-- Schützt Blizzards SaveButton während InCombatLockdown() durch ein reines, auf UIParent
-- geparentetes Schutz-Overlay (taintfrei, keine Änderung am SaveButton selbst), damit ein versehentlicher
-- Klick auf "Speichern" im Kampf kein ADDON_ACTION_BLOCKED: SetProfileByInfo() auslöst.
local saveCombatShield = nil

function ClickBindingUI.UpdateSaveButtonCombatShield(forceCombatState)
	if forceCombatState ~= nil then
		combatLockActive = forceCombatState and true or false
	end
	local inCombat = combatLockActive or ((InCombatLockdown and InCombatLockdown()) and true or false)
	if forceCombatState == false then
		inCombat = false
	end
	if Constants.IsGamepadUIActive()
		or not inCombat
		or not ClickBindingFrame
		or not ClickBindingFrame:IsShown()
		or not ClickBindingFrame.SaveButton
	then
		if saveCombatShield then
			saveCombatShield:Hide()
		end
		return
	end

	local saveBtn = ClickBindingFrame.SaveButton
	if not saveCombatShield then
		local shield = CreateFrame("Button", nil, UIParent)
		shield:SetFrameStrata("DIALOG")
		shield:SetFrameLevel(500)
		shield:EnableMouse(true)
		shield:RegisterForClicks("AnyDown", "AnyUp")

		local dim = shield:CreateTexture(nil, "ARTWORK")
		dim:SetAllPoints()
		dim:SetColorTexture(0.18, 0.02, 0.02, 0.55)

		local hint = shield:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		hint:SetPoint("BOTTOMRIGHT", shield, "TOPRIGHT", 0, 5)
		hint:SetJustifyH("RIGHT")
		shield.Hint = hint

		shield:SetScript("OnClick", function(_, _, down)
			if down then
				return
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
			end
		end)
		shield:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip_SetTitle(GameTooltip, L["SAVE_COMBAT_LOCKED_HINT"])
			GameTooltip_AddNormalLine(GameTooltip, L["SAVE_COMBAT_LOCKED_TOOLTIP"], true)
			GameTooltip:Show()
		end)
		shield:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		-- Wichtig: Bei PLAYER_REGEN_DISABLED feuert das Event oft kurz vor InCombatLockdown() == true.
		-- Solange combatLockActive gesetzt ist, darf OnUpdate den Schild niemals vorzeitig ausblenden.
		shield:SetScript("OnUpdate", function(self)
			if not ClickBindingFrame or not ClickBindingFrame:IsShown() or (not combatLockActive and not (InCombatLockdown and InCombatLockdown())) then
				self:Hide()
			end
		end)
		saveCombatShield = shield
	end

	saveCombatShield:ClearAllPoints()
	saveCombatShield:SetAllPoints(saveBtn)
	if saveCombatShield.Hint then
		saveCombatShield.Hint:SetText(L["SAVE_COMBAT_LOCKED_HINT"])
	end
	saveCombatShield:Show()
end

ClickBindingUI.GetRuleDisplayName = GetRuleDisplayName
ClickBindingUI.GetRuleShortTag = GetRuleShortTag
ClickBindingUI.SetSaveButtonGlowShown = SetSaveButtonGlowShown

function ClickBindingUI.IsSaveButtonGlowShown()
	return (saveButtonGlowFrame and saveButtonGlowFrame:IsShown()) and true or false
end

function ClickBindingUI.GetSaveCombatShield()
	return saveCombatShield
end

function ClickBindingUI.GetGamepadStandbyBadge()
	return gamepadStandbyBadge
end

function ClickBindingUI.SetManualDeleteInProgress(inProgress)
	isManualDeleteInProgress = inProgress and true or false
end

function ClickBindingUI.HideChildPopups()
	if ClickBindingUI.HideFreeKeysMatrix then
		ClickBindingUI.HideFreeKeysMatrix()
	end
	if ns.SettingsUI and ns.SettingsUI.HideReorderWindow then
		ns.SettingsUI.HideReorderWindow()
	end
	if ns.PresetsAndImportUI and ns.PresetsAndImportUI.HidePopups then
		ns.PresetsAndImportUI.HidePopups()
	end
end

--------------------------------------------------------------------------------
-- Rang einer bestehenden Zeile ändern (ohne Taste neu zu binden)
--------------------------------------------------------------------------------

local function SetLineSpellRank(lineFrame, elementData, newActionID, explicitRuleMode)
	if not lineFrame or not elementData or not elementData.bindingInfo or not newActionID then
		return
	end

	local rankEntry = SpellRanks.GetRankEntryForAction(newActionID)
	if explicitRuleMode then
		SpellRanks.SetRuleForBinding(elementData.bindingInfo, explicitRuleMode, rankEntry)
	elseif rankEntry and rankEntry.group and rankEntry.group.maxEntry then
		-- Manueller Klick auf einen spezifischen Rang setzt bei Max-Rang "Immer MAX", sonst "Fester Rang"
		if rankEntry.group.maxEntry.actionID == newActionID then
			SpellRanks.SetRuleForBinding(elementData.bindingInfo, SpellRanks.RULE_MAX, rankEntry)
		else
			SpellRanks.SetRuleForBinding(elementData.bindingInfo, SpellRanks.RULE_FIXED, rankEntry)
		end
	end

	if elementData.bindingInfo.actionID == newActionID then
		ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
		ClickBindingUI.ScheduleSmartRuleCheck(0.1)
		return
	end

	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	elementData.bindingInfo.actionID = newActionID

	if lineFrame.Init then
		lineFrame:Init(elementData)
	else
		ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
	end

	if ClickBindingFrame then
		if ClickBindingFrame.CleanDataProvider then
			ClickBindingFrame:CleanDataProvider()
		end
		ClickBindingUI.RebuildGroups()
		ClickBindingFrame.pendingChanges = true
	end

	if EventRegistry and EventRegistry.TriggerEvent then
		EventRegistry:TriggerEvent("ClickBindingFrame.UpdateFrames")
	end
	if SpellBookUI and SpellBookUI.RefreshBadges then
		SpellBookUI.RefreshBadges()
	end
	ClickBindingUI.ScheduleSmartRuleCheck(0.1)
end

--------------------------------------------------------------------------------
-- 1-Klick Direkt-Binden aus dem Zauberbuch (inkl. LMB, RMB, MMB, MB4+)
--------------------------------------------------------------------------------

function ClickBindingUI.QuickBindSpell(actionType, actionID, buttonName, modifiers)
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider or not actionType or not actionID or not buttonName then
		return false
	end

	modifiers = modifiers or (MakeModifiers and MakeModifiers()) or 0

	-- Prüfen, ob genau dieser Zauber bereits auf exakt dieser Taste + Modifier liegt
	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		local info = element and element.bindingInfo
		if info and not element.unbound and info.type == actionType and info.actionID == actionID and info.button == buttonName and (info.modifiers or 0) == modifiers then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			return true
		end
	end

	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if ClickBindingFrame.ClearUnboundText then
		ClickBindingFrame:ClearUnboundText()
	end

	-- 1. Falls eine andere Zeile bereits diese Taste + Modifier belegt hat, diese freigeben
	for _, otherData in ClickBindingFrame.dataProvider:Enumerate() do
		local otherInfo = otherData and otherData.bindingInfo
		if otherInfo and not otherData.unbound and otherInfo.button == buttonName and (otherInfo.modifiers or 0) == modifiers then
			otherInfo.button = nil
			otherInfo.modifiers = nil
			otherData.unbound = true
			if ClickBindingFrame.ScrollBox and ClickBindingFrame.ScrollBox.FindFrame then
				local otherButton = ClickBindingFrame.ScrollBox:FindFrame(otherData)
				if otherButton and otherButton.Init then
					otherButton:Init(otherData)
				end
			end
			if ClickBindingFrame.SetUnboundText then
				ClickBindingFrame:SetUnboundText(otherData)
			end
		end
	end

	-- 2. Vorhandenen ungebundenen Eintrag für denselben Zauber oder leeren NewSlot wiederverwenden
	local targetElement = nil
	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		local info = element and element.bindingInfo
		if element and element.unbound and info and info.type == actionType and info.actionID == actionID then
			targetElement = element
			break
		end
	end

	if not targetElement and ClickBindingFrame.HasEmptySlot and ClickBindingFrame:HasEmptySlot() then
		targetElement = ClickBindingFrame:GetLastElement()
	end

	local newBindingInfo = {
		type = actionType,
		actionID = actionID,
		button = buttonName,
		modifiers = modifiers,
	}

	-- Wird im Zauberbuch gezielt ein niedrigerer Rang gebunden, wird dieser automatisch als "Fester Rang" gespeichert;
	-- bei Rang 1 (oder aktuellem Max-Rang) wird sofort "Immer MAX" verankert.
	local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
	if rankEntry and rankEntry.group and (#rankEntry.group.entries > 1 or rankEntry.rankNum) then
		local isMax = (rankEntry.group.maxEntry and rankEntry.group.maxEntry.actionID == actionID)
		SpellRanks.SetRuleForBinding(newBindingInfo, isMax and SpellRanks.RULE_MAX or SpellRanks.RULE_FIXED, rankEntry)
	end

	if targetElement then
		targetElement.bindingInfo = newBindingInfo
		targetElement.unbound = false
		if targetElement.elementType == ElementDataTypes.NewSlot then
			targetElement.elementType = ElementDataTypes.CustomsBinding
			if ClickBindingFrame.SetHasNewSlot then
				ClickBindingFrame:SetHasNewSlot(false)
			end
		end
	else
		ClickBindingFrame.dataProvider:Insert({
			elementType = ElementDataTypes.CustomsBinding,
			bindingInfo = newBindingInfo,
			unbound = false,
		})
	end

	if ClickBindingFrame.CleanDataProvider then
		ClickBindingFrame:CleanDataProvider()
	end
	ClickBindingUI.RebuildGroups()
	ClickBindingFrame.pendingChanges = true

	ClickBindingUI.RefreshVisibleLines()
	if EventRegistry and EventRegistry.TriggerEvent then
		EventRegistry:TriggerEvent("ClickBindingFrame.UpdateFrames")
	end
	if SpellBookUI and SpellBookUI.RefreshBadges then
		SpellBookUI.RefreshBadges()
	end
	return true
end

function ClickBindingUI.CountUpgradeableBindings()
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return 0
	end
	local count = 0
	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		local info = element and element.bindingInfo
		if info and Constants.IsSpellOrPetBinding(info) and info.actionID then
			local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
			local group = (rankEntry and rankEntry.group) or SpellRanks.GetSpellGroupForAction(info.actionID, info.type)
			local maxEntry = group and group.maxEntry
			if maxEntry and maxEntry.actionID ~= info.actionID then
				count = count + 1
			end
		end
	end
	return count
end

function ClickBindingUI.UpgradeAllBindingsToMaxRank()
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return 0
	end
	local upgraded = 0
	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		local info = element and element.bindingInfo
		if info and Constants.IsSpellOrPetBinding(info) and info.actionID then
			local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
			local group = (rankEntry and rankEntry.group) or SpellRanks.GetSpellGroupForAction(info.actionID, info.type)
			local maxEntry = group and group.maxEntry
			if maxEntry and maxEntry.actionID ~= info.actionID then
				info.actionID = maxEntry.actionID
				SpellRanks.SetRuleForBinding(info, SpellRanks.RULE_MAX, maxEntry)
				upgraded = upgraded + 1
			end
		end
	end

	if upgraded > 0 then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if ClickBindingFrame.CleanDataProvider then
			ClickBindingFrame:CleanDataProvider()
		end
		ClickBindingUI.RebuildGroups()
		ClickBindingFrame.pendingChanges = true
		SetSaveButtonGlowShown(true)
		ClickBindingUI.RefreshVisibleLines()
		if EventRegistry and EventRegistry.TriggerEvent then
			EventRegistry:TriggerEvent("ClickBindingFrame.UpdateFrames")
		end
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_UPGRADED_COUNT_FORMAT"], upgraded))
		end
	end
	return upgraded
end

function ClickBindingUI.ApplySmartRulesToDataProvider(silentChat)
	if not Database.Get("enableSmartRankRules") then
		return 0
	end
	if not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return 0
	end

	local updated = 0
	for _, element in ClickBindingFrame.dataProvider:Enumerate() do
		local info = element and not element.unbound and element.bindingInfo
		if info and info.button and info.actionID and Constants.IsSpellOrPetBinding(info) then
			local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
			if rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
				local ruleMode = SpellRanks.GetRuleForBinding(info, rankEntry)
				local targetEntry = SpellRanks.GetTargetEntryForRule(rankEntry.group, ruleMode)
				if targetEntry and targetEntry.actionID and targetEntry.actionID ~= info.actionID then
					info.actionID = targetEntry.actionID
					updated = updated + 1
				end
			end
		end
	end

	if updated > 0 then
		if ClickBindingFrame.CleanDataProvider then
			ClickBindingFrame:CleanDataProvider()
		end
		ClickBindingUI.RebuildGroups()
		ClickBindingFrame.pendingChanges = true
		SetSaveButtonGlowShown(true)
		ClickBindingUI.RefreshVisibleLines()
		if EventRegistry and EventRegistry.TriggerEvent then
			EventRegistry:TriggerEvent("ClickBindingFrame.UpdateFrames")
		end
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
		if not silentChat and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_SMART_RULES_APPLIED_FORMAT"], updated))
		end
	end

	return updated
end

local function OpenRankContextMenu(rankButton, lineFrame, elementData, rankEntry)
	if not MenuUtil or not MenuUtil.CreateContextMenu then
		return
	end

	local group = (rankEntry and rankEntry.group)
		or (elementData and elementData.bindingInfo and SpellRanks.GetSpellGroupForAction(elementData.bindingInfo.actionID, elementData.bindingInfo.type))
	if not group or not group.entries or #group.entries == 0 then
		return
	end
	if rankEntry and #group.entries <= 1 then
		return
	end
	local refEntry = rankEntry or group.maxEntry or group.entries[1]

	MenuUtil.CreateContextMenu(rankButton, function(_, rootDescription)
		-- 1. Sektion: Smarte Rang-Regeln (wenn für diese gebundene Zeile aktiv)
		if Database.Get("enableSmartRankRules") and elementData and elementData.bindingInfo and elementData.bindingInfo.button and #group.entries > 1 then
			rootDescription:CreateTitle(L["SMART_RULE_HEADER"])

			local function IsRuleSelected(modeValue)
				return SpellRanks.GetRuleForBinding(elementData.bindingInfo, refEntry) == modeValue
			end

			local function SetRuleSelected(modeValue)
				SpellRanks.SetRuleForBinding(elementData.bindingInfo, modeValue, refEntry)
				local targetEntry = SpellRanks.GetTargetEntryForRule(group, modeValue)
				if targetEntry and targetEntry.actionID then
					SetLineSpellRank(lineFrame, elementData, targetEntry.actionID, modeValue)
				else
					ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
					ClickBindingUI.ScheduleSmartRuleCheck(0.1)
				end
			end

			for _, opt in ipairs(SMART_RULE_OPTIONS) do
				local targetEntry = SpellRanks.GetTargetEntryForRule(group, opt.mode)
				local labelText = L[opt.labelKey]
				if targetEntry and targetEntry.subName and targetEntry.subName ~= "" then
					labelText = string.format("%s %s(%s)%s", labelText, Colors.MUTED, targetEntry.subName, Colors.RESET)
				end
				local ruleRadio = rootDescription:CreateRadio(labelText, IsRuleSelected, SetRuleSelected, opt.mode)
				ruleRadio:SetTooltip(function(tooltip)
					GameTooltip_SetTitle(tooltip, L[opt.labelKey])
					GameTooltip_AddNormalLine(tooltip, L["SMART_RULE_TOOLTIP_DESC"], true)
				end)
			end

			rootDescription:CreateDivider()
		end

		-- 2. Sektion: Direkte Auswahl der gelernten Ränge
		rootDescription:CreateTitle(string.format(L["SELECT_RANK_TITLE_FORMAT"], group.name))

		local function IsSelected(entryActionID)
			return elementData and elementData.bindingInfo and elementData.bindingInfo.actionID == entryActionID
		end

		local function SetSelected(entryActionID)
			SetLineSpellRank(lineFrame, elementData, entryActionID)
		end

		for _, entry in ipairs(group.entries) do
			local label = (entry.subName and entry.subName ~= "")
				and entry.subName
				or string.format(L["RANK_FALLBACK_FORMAT"], entry.rankIndex or 1)
			local isMax = (group.maxEntry == entry)
			local costStr = SpellRanks.GetSpellPowerCostString(entry.spellID or entry.actionID)

			local displayParts = { label }
			if costStr then
				table.insert(displayParts, string.format("%s(%s)%s", Colors.MUTED, costStr, Colors.RESET))
			end
			if isMax then
				table.insert(displayParts, Colors.TAG_MAX .. L["TAG_MAX"] .. Colors.RESET)
			end

			local radioText = table.concat(displayParts, " ")
			local radio = rootDescription:CreateRadio(radioText, IsSelected, SetSelected, entry.actionID)
			radio:SetTooltip(function(tooltip)
				if entry.slotIndex and entry.spellBank and tooltip.SetSpellBookItem then
					tooltip:SetSpellBookItem(entry.slotIndex, entry.spellBank)
				elseif tooltip.SetSpellByID then
					tooltip:SetSpellByID(entry.spellID or entry.actionID)
				end
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- Tooltips für Zeilen im ClickBindingFrame
--------------------------------------------------------------------------------

function ClickBindingUI.ShowLineTooltip(lineFrame)
	if Constants.IsGamepadUIActive() then
		return
	end
	if not lineFrame or not Database.Get("showLineTooltips") then
		return
	end
	local elementData = lineFrame.GetElementData and lineFrame:GetElementData()
	if not elementData or not elementData.bindingInfo then
		return
	end

	local bindingInfo = elementData.bindingInfo
	local bType = bindingInfo.type
	local actionID = bindingInfo.actionID
	if not actionID or not Enum or not Enum.ClickBindingType then
		return
	end

	GameTooltip:SetOwner(lineFrame, "ANCHOR_RIGHT")

	if bType == Enum.ClickBindingType.Spell or bType == Enum.ClickBindingType.PetAction then
		local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
		local isLearned = SpellRanks.IsBindingSpellLearned(bindingInfo)
		if rankEntry and rankEntry.slotIndex and rankEntry.spellBank then
			GameTooltip:SetSpellBookItem(rankEntry.slotIndex, rankEntry.spellBank)
		else
			GameTooltip:SetSpellByID(actionID)
		end

		GameTooltip:AddLine(" ")
		local bindText = Constants.GetFullBindingString(bindingInfo)
		GameTooltip:AddDoubleLine(L["TOOLTIP_CLICK_BINDING_LABEL"], bindText, 0.8, 0.8, 0.8, 1, 1, 1)

		if not isLearned then
			GameTooltip:AddDoubleLine(
				L["TOOLTIP_RANK_STATUS_LABEL"],
				L["TOOLTIP_STATUS_NOT_LEARNED"],
				0.8, 0.8, 0.8,
				1.0, 0.33, 0.33
			)
			GameTooltip:AddLine(L["TOOLTIP_NOT_LEARNED_HINT"], 1.0, 0.5, 0.5, true)
			local fallbackGroup = SpellRanks.GetSpellGroupForAction(actionID, bType)
			if fallbackGroup and fallbackGroup.entries and #fallbackGroup.entries >= 1 and Database.Get("showRankSwitcher") then
				GameTooltip:AddLine(L["TOOLTIP_SWITCH_RANK_HINT"], 0.6, 0.85, 1.0, true)
			end
		elseif rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
			local group = rankEntry.group
			local maxEntry = group.maxEntry
			if maxEntry and maxEntry.actionID == rankEntry.actionID then
				GameTooltip:AddDoubleLine(
					L["TOOLTIP_RANK_STATUS_LABEL"],
					string.format(L["TOOLTIP_STATUS_MAX_RANK_FORMAT"], rankEntry.subName ~= "" and rankEntry.subName or L["TAG_MAX_SHORT"]),
					0.8, 0.8, 0.8,
					0.25, 1.0, 0.25
				)
			elseif maxEntry then
				GameTooltip:AddDoubleLine(
					L["TOOLTIP_RANK_STATUS_LABEL"],
					string.format(L["TOOLTIP_STATUS_DOWNRANK_FORMAT"], rankEntry.subName or "?", maxEntry.subName or "?"),
					0.8, 0.8, 0.8,
					1.0, 0.72, 0.2
				)
			end
			if Database.Get("enableSmartRankRules") and bindingInfo.button then
				local ruleMode = SpellRanks.GetRuleForBinding(bindingInfo, rankEntry)
				GameTooltip:AddDoubleLine(L["TOOLTIP_SMART_RULE_LABEL"], GetRuleDisplayName(ruleMode), 0.8, 0.8, 0.8, 0.6, 0.85, 1.0)
			end
			if Database.Get("showRankSwitcher") then
				GameTooltip:AddLine(L["TOOLTIP_SWITCH_RANK_HINT"], 0.6, 0.85, 1.0, true)
			end
		end

		GameTooltip:Show()
	elseif bType == Enum.ClickBindingType.Macro then
		local macroName, _, macroBody = GetMacroInfo(actionID)
		if macroName then
			GameTooltip_SetTitle(GameTooltip, string.format(CLICK_BINDING_MACRO_TITLE or "Macro: %s", macroName))
			if macroBody and macroBody ~= "" then
				GameTooltip:AddLine(macroBody, 0.9, 0.9, 0.9, true)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(L["TOOLTIP_CLICK_BINDING_LABEL"], Constants.GetFullBindingString(bindingInfo), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:Show()
		else
			GameTooltip:Hide()
		end
	else
		GameTooltip:Hide()
	end
end

--------------------------------------------------------------------------------
-- Moderne UI-Widgets auf Header- und Zeilen-Frames
--------------------------------------------------------------------------------

local function EnsureHeaderGroupWidgets(headerFrame)
	if headerFrame.BCCGroupButton then
		if not Constants.IsGamepadUIActive() then
			if headerFrame.BCCGroupButton:GetParent() ~= headerFrame then
				headerFrame.BCCGroupButton:SetParent(headerFrame)
				headerFrame.BCCGroupButton:ClearAllPoints()
				headerFrame.BCCGroupButton:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
			end
			if headerFrame.BCCMatrixButton and headerFrame.BCCMatrixButton:GetParent() ~= headerFrame then
				headerFrame.BCCMatrixButton:SetParent(headerFrame)
				headerFrame.BCCMatrixButton:ClearAllPoints()
				headerFrame.BCCMatrixButton:SetPoint("RIGHT", headerFrame.BCCGroupButton, "LEFT", -6, 0)
			end
		end
		return headerFrame.BCCGroupButton, headerFrame.BCCMatrixButton, headerFrame.BCCSubDivider
	end

	-- Dezent schimmernde Trennlinie unter eigenen Untergruppen-Headern
	local divider = headerFrame:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, -1)
	divider:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", -6, -1)
	divider:SetAlpha(0.55)
	divider:Hide()
	headerFrame.BCCSubDivider = divider

	-- Moderner Pill-Dropdown-Button rechts im Haupt-"Benutzerdefinierte Belegungen"-Header
	local btn = CreateFrame("Button", nil, headerFrame)
	btn:SetSize(134, 19)
	btn:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetPoint("TOPLEFT", -3, 3)
	bg:SetPoint("BOTTOMRIGHT", 3, -3)
	btn.Bg = bg

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAtlas("common-dropdown-c-button-hover-1")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.45)
	hl:SetPoint("TOPLEFT", -3, 3)
	hl:SetPoint("BOTTOMRIGHT", 3, -3)

	local arrow = btn:CreateTexture(nil, "OVERLAY")
	arrow:SetAtlas("common-dropdown-a-button")
	arrow:SetSize(11, 11)
	arrow:SetPoint("RIGHT", btn, "RIGHT", -5, -1)
	btn.Arrow = arrow

	local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", btn, "LEFT", 8, 0)
	label:SetPoint("RIGHT", arrow, "LEFT", -3, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	btn.Text = label

	btn:SetScript("OnMouseDown", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 9, -1)
		self.Arrow:SetPoint("RIGHT", self, "RIGHT", -4, -2)
	end)

	btn:SetScript("OnMouseUp", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 8, 0)
		self.Arrow:SetPoint("RIGHT", self, "RIGHT", -5, -1)
	end)

	btn:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if SettingsUI and SettingsUI.OpenGroupingMenu then
			SettingsUI.OpenGroupingMenu(self)
		end
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["GROUP_TOOLTIP_TITLE"])
		GameTooltip_AddNormalLine(GameTooltip, L["GROUP_TOOLTIP_DESC"], true)
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	btn:Hide()
	headerFrame.BCCGroupButton = btn

	-- 1-Klick-Pill-Button für die Tasten-Matrix direkt links neben dem Group-Dropdown
	local matrixBtn = CreateFrame("Button", nil, headerFrame)
	matrixBtn:SetSize(64, 19)
	matrixBtn:SetPoint("RIGHT", btn, "LEFT", -6, 0)
	matrixBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local mBg = matrixBtn:CreateTexture(nil, "BACKGROUND")
	mBg:SetAtlas("common-dropdown-c-button")
	mBg:SetPoint("TOPLEFT", -3, 3)
	mBg:SetPoint("BOTTOMRIGHT", 3, -3)
	matrixBtn.Bg = mBg

	local mHl = matrixBtn:CreateTexture(nil, "HIGHLIGHT")
	mHl:SetAtlas("common-dropdown-c-button-hover-1")
	mHl:SetBlendMode("ADD")
	mHl:SetAlpha(0.45)
	mHl:SetPoint("TOPLEFT", -3, 3)
	mHl:SetPoint("BOTTOMRIGHT", 3, -3)

	local mLabel = matrixBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mLabel:SetPoint("LEFT", matrixBtn, "LEFT", 6, 0)
	mLabel:SetPoint("RIGHT", matrixBtn, "RIGHT", -6, 0)
	mLabel:SetJustifyH("CENTER")
	mLabel:SetWordWrap(false)
	matrixBtn.Text = mLabel

	matrixBtn:SetScript("OnMouseDown", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 7, -1)
		self.Text:SetPoint("RIGHT", self, "RIGHT", -5, -1)
	end)

	matrixBtn:SetScript("OnMouseUp", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 6, 0)
		self.Text:SetPoint("RIGHT", self, "RIGHT", -6, 0)
	end)

	matrixBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ClickBindingUI.ToggleFreeKeysMatrix()
	end)

	matrixBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["SETTINGS_FREE_KEYS_MATRIX_BTN"])
		GameTooltip_AddNormalLine(GameTooltip, L["SETTINGS_FREE_KEYS_MATRIX_DESC"], true)
		GameTooltip:Show()
	end)

	matrixBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	matrixBtn:Hide()
	headerFrame.BCCMatrixButton = matrixBtn
	return btn, matrixBtn, divider
end

local function UpdateHeaderFrame(headerFrame, elementData)
	if not headerFrame then
		return
	end
	if Constants.IsGamepadUIActive() then
		if headerFrame.BCCGroupButton then
			headerFrame.BCCGroupButton:Hide()
			headerFrame.BCCGroupButton:SetParent(nil)
		end
		if headerFrame.BCCMatrixButton then
			headerFrame.BCCMatrixButton:Hide()
			headerFrame.BCCMatrixButton:SetParent(nil)
		end
		if headerFrame.BCCSubDivider then
			headerFrame.BCCSubDivider:Hide()
		end
		return
	end
	elementData = elementData or (headerFrame.GetElementData and headerFrame:GetElementData())
	local groupBtn, matrixBtn, divider = EnsureHeaderGroupWidgets(headerFrame)
	local compact = Database.Get("compactListMode") and true or false
	local hHeight = (compact and elementData and elementData.isBCCGroupHeader) and 17 or 20
	headerFrame:SetHeight(hHeight)

	-- Zuerst eigene Elemente zurücksetzen (ScrollBox-Recycling-Hygiene)
	groupBtn:Hide()
	matrixBtn:Hide()
	divider:Hide()
	if headerFrame.Name then
		headerFrame.Name:ClearAllPoints()
		headerFrame.Name:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
	end

	if not elementData then
		return
	end

	if elementData.isBCCGroupHeader then
		if headerFrame.Name then
			headerFrame.Name:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
			headerFrame.Name:SetText(elementData.bccHeaderText or "")
		end
		divider:Show()
	elseif elementData.elementType == ElementDataTypes.CustomsHeader then
		if headerFrame.Name and elementData._bccTotalCustomCount and elementData._bccTotalCustomCount > 0 then
			local baseTitle = CLICK_BINDINGS_CUSTOMS_HEADER or headerFrame.Name:GetText() or ""
			headerFrame.Name:SetText(string.format("%s %s(%d)%s", baseTitle, Colors.MUTED, elementData._bccTotalCustomCount, Colors.RESET))
		end
		if SettingsUI and SettingsUI.GetCurrentGroupShortLabel then
			groupBtn.Text:SetText(string.format(L["GROUP_BUTTON_FORMAT"], SettingsUI.GetCurrentGroupShortLabel()))
			groupBtn:Show()
		end
		matrixBtn.Text:SetText("|cffffd100" .. (L["MATRIX_HEADER_BTN"] or "Matrix") .. "|r")
		matrixBtn:Show()
	end
end

local LEGACY_BUTTON_REGIONS = {
	"TopLeft",
	"TopRight",
	"BottomLeft",
	"BottomRight",
	"TopMiddle",
	"MiddleLeft",
	"MiddleRight",
	"BottomMiddle",
	"MiddleMiddle",
}

local function ShouldShowDeleteButton(lineFrame, elementData)
	if Constants.IsGamepadUIActive() then
		return false
	end
	elementData = elementData or (lineFrame and lineFrame.GetElementData and lineFrame:GetElementData())
	if not elementData then
		return false
	end
	return elementData.elementType ~= ElementDataTypes.InteractionBinding
end

local function EnsureDeleteButtonStyled(lineFrame)
	local delBtn = lineFrame and lineFrame.DeleteButton
	if not delBtn then
		return nil
	end
	if delBtn._bccStyled then
		return delBtn
	end
	delBtn._bccStyled = true

	-- Alte 9-Slice-Silbertexturen aus UIMenuButtonStretchTemplate unsichtbar schalten
	for _, key in ipairs(LEGACY_BUTTON_REGIONS) do
		if delBtn[key] and delBtn[key].SetAlpha then
			delBtn[key]:SetAlpha(0)
		end
	end

	-- In der 2. Zeile rechts außen platzieren, damit Zeile 1 (Zaubername + Rang)
	-- die volle Zeilenbreite ohne Überlappung nutzen kann.
	delBtn:SetSize(22, 18)
	delBtn:ClearAllPoints()
	delBtn:SetPoint("RIGHT", lineFrame, "RIGHT", -6, -8)

	if lineFrame.Name and lineFrame.Icon then
		lineFrame.Name:ClearAllPoints()
		lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, 9)
		lineFrame.Name:SetPoint("RIGHT", lineFrame, "RIGHT", -8, 9)
		lineFrame.Name:SetWordWrap(false)
	end
	if lineFrame.BindingText and lineFrame.Icon then
		lineFrame.BindingText:ClearAllPoints()
		lineFrame.BindingText:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, -8)
		lineFrame.BindingText:SetWordWrap(false)
	end

	local bg = delBtn:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetPoint("TOPLEFT", -2, 2)
	bg:SetPoint("BOTTOMRIGHT", 2, -2)
	delBtn.BCCBg = bg

	local hl = delBtn:GetHighlightTexture()
	if hl and hl.SetAtlas then
		hl:SetAtlas("common-dropdown-c-button-hover-1")
		hl:SetBlendMode("ADD")
		hl:SetAlpha(0.45)
		hl:ClearAllPoints()
		hl:SetPoint("TOPLEFT", -2, 2)
		hl:SetPoint("BOTTOMRIGHT", 2, -2)
	end

	if delBtn.Icon then
		delBtn.Icon:ClearAllPoints()
		delBtn.Icon:SetPoint("CENTER", delBtn, "CENTER", 0, 0)
	end

	delBtn:HookScript("OnMouseDown", function(self)
		isManualDeleteInProgress = true
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 1, -1)
		end
	end)

	delBtn:HookScript("OnMouseUp", function(self)
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, function()
				isManualDeleteInProgress = false
			end)
		else
			isManualDeleteInProgress = false
		end
	end)

	-- Zusätzlicher OnClick-Guard: Nach einem bestätigten Klick auf DeleteButton den Snapshot
	-- direkt mit dem neuen Zustand ohne die gelöschte Zeile synchronisieren.
	delBtn:HookScript("OnClick", function()
		isManualDeleteInProgress = false
		ClickBindingUI.RebuildGroups(false)
	end)

	-- Blizzards XML-Skript und ClickBindingLineMixin:OnLeave verstecken DeleteButton bei OnLeave;
	-- für löschbare Zeilen dauerhaft sichtbar halten.
	delBtn:HookScript("OnLeave", function(self)
		if ShouldShowDeleteButton(lineFrame) then
			self:Show()
		end
	end)
	delBtn:HookScript("OnHide", function(self)
		if not self._bccAllowHide and ShouldShowDeleteButton(lineFrame) then
			self:Show()
		end
	end)

	return delBtn
end

local function ApplyLineCompactMetrics(lineFrame)
	if not lineFrame then
		return
	end
	local compact = Database.Get("compactListMode") and true or false
	local lineH = compact and 32 or 46
	local iconSize = compact and 26 or 35
	local topRowY = compact and 6 or 9
	local bottomRowY = compact and -6 or -8
	local btnH = compact and 15 or 18
	local delW = compact and 20 or 22
	local rankW = compact and 88 or 92

	lineFrame._bccTopRowY = topRowY
	lineFrame._bccBottomRowY = bottomRowY
	lineFrame:SetHeight(lineH)

	if lineFrame.Icon then
		lineFrame.Icon:SetSize(iconSize, iconSize)
	end
	if lineFrame.Background and lineFrame.Background.SetHeight then
		lineFrame.Background:SetHeight(lineH)
	end
	if lineFrame.FrameHighlight and lineFrame.FrameHighlight.SetHeight then
		lineFrame.FrameHighlight:SetHeight(lineH)
	end
	if lineFrame.NewOutline and lineFrame.NewOutline.SetHeight then
		lineFrame.NewOutline:SetHeight(lineH)
	end
	if lineFrame.IconHighlight and lineFrame.IconHighlight.SetSize then
		local hlSize = compact and 30 or 40
		lineFrame.IconHighlight:SetSize(hlSize, hlSize)
	end
	if lineFrame.Name and lineFrame.Name.SetFontObject then
		lineFrame.Name:SetFontObject(compact and "GameFontNormalSmall" or "GameFontNormal")
	end
	if lineFrame.BindingText and lineFrame.Icon then
		lineFrame.BindingText:ClearAllPoints()
		lineFrame.BindingText:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, bottomRowY)
		lineFrame.BindingText:SetWordWrap(false)
	end
	if lineFrame.DeleteButton then
		lineFrame.DeleteButton:SetSize(delW, btnH)
		lineFrame.DeleteButton:ClearAllPoints()
		lineFrame.DeleteButton:SetPoint("RIGHT", lineFrame, "RIGHT", -6, bottomRowY)
	end
	if lineFrame.BCCRankButton then
		lineFrame.BCCRankButton:SetSize(rankW, btnH)
		lineFrame.BCCRankButton:ClearAllPoints()
		if lineFrame.DeleteButton then
			lineFrame.BCCRankButton:SetPoint("RIGHT", lineFrame.DeleteButton, "LEFT", -4, 0)
		else
			lineFrame.BCCRankButton:SetPoint("RIGHT", lineFrame, "RIGHT", -6, bottomRowY)
		end
	end
	if lineFrame.BCCEyeButton then
		lineFrame.BCCEyeButton:SetSize(delW, btnH)
		lineFrame.BCCEyeButton:ClearAllPoints()
		lineFrame.BCCEyeButton:SetPoint("RIGHT", lineFrame, "RIGHT", -6, topRowY)
		if lineFrame.BCCEyeButton.Icon then
			local eyeIconSz = compact and 12 or 14
			lineFrame.BCCEyeButton.Icon:SetSize(eyeIconSz, eyeIconSz)
		end
	end
	if lineFrame.BCCManaText then
		lineFrame.BCCManaText:ClearAllPoints()
		if lineFrame.BCCEyeButton and lineFrame.BCCEyeButton:IsShown() then
			lineFrame.BCCManaText:SetPoint("RIGHT", lineFrame.BCCEyeButton, "LEFT", -4, 0)
		else
			lineFrame.BCCManaText:SetPoint("RIGHT", lineFrame, "RIGHT", -8, topRowY)
		end
	end
end

function ClickBindingUI.ApplyScrollBoxLayout()
	if Constants.IsGamepadUIActive() then
		return
	end
	if not ClickBindingFrame or not ClickBindingFrame.ScrollBox or not ClickBindingFrame.ScrollBox.GetView then
		return
	end
	local view = ClickBindingFrame.ScrollBox:GetView()
	if not view then
		return
	end

	local compact = Database.Get("compactListMode") and true or false
	if view.SetPadding then
		view:SetPadding(compact and 5 or 7, compact and 40 or 53, 7, 7, compact and 2 or 4)
	end
	if view.SetElementExtentCalculator then
		view:SetElementExtentCalculator(function(_, elementData)
			local isCompact = Database.Get("compactListMode") and true or false
			local eType = elementData and elementData.elementType
			if eType == ElementDataTypes.DefaultsHeader or eType == ElementDataTypes.CustomsHeader then
				if isCompact and elementData and elementData.isBCCGroupHeader then
					return 17
				end
				return 20
			end
			return isCompact and 32 or 46
		end)
	end

	if ClickBindingFrame.ScrollBox.ForEachFrame then
		ClickBindingFrame.ScrollBox:ForEachFrame(function(frame)
			local elementData = frame.GetElementData and frame:GetElementData()
			local eType = elementData and elementData.elementType
			if eType == ElementDataTypes.DefaultsHeader or eType == ElementDataTypes.CustomsHeader then
				local hHeight = (compact and elementData and elementData.isBCCGroupHeader) and 17 or 20
				frame:SetHeight(hHeight)
			else
				ApplyLineCompactMetrics(frame)
			end
		end)
	end

	if ClickBindingFrame:IsShown() then
		if ClickBindingFrame.ScrollBox.Rebuild and view.GetDataProvider and view:GetDataProvider() then
			ClickBindingFrame.ScrollBox:Rebuild(true)
		elseif ClickBindingFrame.ScrollBox.FullUpdate then
			ClickBindingFrame.ScrollBox:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately or true)
		end
		ClickBindingUI.RefreshVisibleLines()
	end
end

local function EnsureLineRankButton(lineFrame)
	if lineFrame.BCCRankButton then
		if not Constants.IsGamepadUIActive() and lineFrame.BCCRankButton:GetParent() ~= lineFrame then
			lineFrame.BCCRankButton:SetParent(lineFrame)
			ApplyLineCompactMetrics(lineFrame)
		end
		return lineFrame.BCCRankButton
	end

	EnsureDeleteButtonStyled(lineFrame)

	-- Kompaktes Dark-Pill-Dropdown in der 2. Zeile direkt links neben dem DeleteButton (Höhe 18px)
	local btn = CreateFrame("Button", nil, lineFrame)
	btn:SetSize(92, 18)
	if lineFrame.DeleteButton then
		btn:SetPoint("RIGHT", lineFrame.DeleteButton, "LEFT", -4, 0)
	else
		btn:SetPoint("RIGHT", lineFrame, "RIGHT", -6, -8)
	end
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetPoint("TOPLEFT", -2, 2)
	bg:SetPoint("BOTTOMRIGHT", 2, -2)
	btn.Bg = bg

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAtlas("common-dropdown-c-button-hover-1")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.45)
	hl:SetPoint("TOPLEFT", -2, 2)
	hl:SetPoint("BOTTOMRIGHT", 2, -2)

	local arrow = btn:CreateTexture(nil, "OVERLAY")
	arrow:SetAtlas("common-dropdown-a-button")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", btn, "RIGHT", -5, -1)
	btn.Arrow = arrow

	local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", btn, "LEFT", 6, 0)
	label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
	label:SetJustifyH("CENTER")
	label:SetWordWrap(false)
	btn.Text = label

	btn:SetScript("OnMouseDown", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 7, -1)
		self.Arrow:SetPoint("RIGHT", self, "RIGHT", -4, -2)
	end)

	btn:SetScript("OnMouseUp", function(self)
		self.Text:SetPoint("LEFT", self, "LEFT", 6, 0)
		self.Arrow:SetPoint("RIGHT", self, "RIGHT", -5, -1)
	end)

	btn:SetScript("OnClick", function(self, mouseButton)
		local elementData = lineFrame.GetElementData and lineFrame:GetElementData()
		if not elementData or not elementData.bindingInfo then
			return
		end
		local rankEntry = SpellRanks.GetRankEntryForAction(elementData.bindingInfo.actionID)
		local group = (rankEntry and rankEntry.group)
			or SpellRanks.GetSpellGroupForAction(elementData.bindingInfo.actionID, elementData.bindingInfo.type)
		if not group then
			return
		end

		if mouseButton == "RightButton" then
			local maxEntry = group.maxEntry
			if maxEntry then
				SetLineSpellRank(lineFrame, elementData, maxEntry.actionID, SpellRanks.RULE_MAX)
				ClickBindingUI.ShowLineTooltip(lineFrame)
			end
		else
			OpenRankContextMenu(self, lineFrame, elementData, rankEntry)
		end
	end)

	btn:SetScript("OnEnter", function(self)
		if lineFrame.DeleteButton and lineFrame.elementType ~= ElementDataTypes.InteractionBinding then
			lineFrame.DeleteButton:Show()
		end
		local elementData = lineFrame.GetElementData and lineFrame:GetElementData()
		local rankEntry = elementData and elementData.bindingInfo and SpellRanks.GetRankEntryForAction(elementData.bindingInfo.actionID)
		local group = (rankEntry and rankEntry.group)
			or (elementData and elementData.bindingInfo and SpellRanks.GetSpellGroupForAction(elementData.bindingInfo.actionID, elementData.bindingInfo.type))

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["RANK_SWITCHER_TOOLTIP_TITLE"])
		if rankEntry and group and group.maxEntry then
			local maxEntry = group.maxEntry
			GameTooltip:AddLine(string.format(L["RANK_SWITCHER_CURRENT_FORMAT"], rankEntry.subName or "?", maxEntry.subName or "?"), 1, 1, 1)
			if Database.Get("enableSmartRankRules") and elementData.bindingInfo.button then
				local ruleMode = SpellRanks.GetRuleForBinding(elementData.bindingInfo, rankEntry)
				GameTooltip:AddLine(string.format(L["RANK_SWITCHER_RULE_FORMAT"], GetRuleDisplayName(ruleMode)), 0.6, 0.85, 1.0)
			end
		elseif not rankEntry and group and group.maxEntry then
			local unlearnedSub = SpellRanks.GetSpellSubtextForAction(elementData.bindingInfo.actionID) or L["TOOLTIP_STATUS_NOT_LEARNED"]
			GameTooltip:AddLine(string.format(L["RANK_SWITCHER_CURRENT_FORMAT"], unlearnedSub, group.maxEntry.subName or "?"), 1.0, 0.4, 0.4)
		end
		GameTooltip:AddLine(L["RANK_SWITCHER_HINT_LEFT"], 0.6, 0.85, 1.0)
		GameTooltip:AddLine(L["RANK_SWITCHER_HINT_RIGHT"], 0.25, 1.0, 0.25)
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
		if lineFrame:IsMouseMotionFocus() then
			ClickBindingUI.ShowLineTooltip(lineFrame)
		end
		if lineFrame.DeleteButton and ShouldShowDeleteButton(lineFrame) then
			lineFrame.DeleteButton:Show()
		end
	end)

	btn:Hide()
	lineFrame.BCCRankButton = btn
	return btn
end

local function EnsureLineManaText(lineFrame)
	if lineFrame.BCCManaText then
		return lineFrame.BCCManaText
	end

	local manaFS = lineFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	manaFS:SetPoint("RIGHT", lineFrame, "RIGHT", -8, 9)
	manaFS:SetJustifyH("RIGHT")
	manaFS:SetWordWrap(false)
	manaFS:Hide()
	lineFrame.BCCManaText = manaFS
	return manaFS
end

local function ApplyEyeButtonVisualState(eyeBtn, isHidden)
	if not eyeBtn then
		return
	end
	if isHidden then
		eyeBtn:SetAlpha(0.28)
		if eyeBtn.Icon then
			eyeBtn.Icon:SetDesaturated(true)
			eyeBtn.Icon:SetVertexColor(0.65, 0.65, 0.65)
		end
	else
		eyeBtn:SetAlpha(1.0)
		if eyeBtn.Icon then
			eyeBtn.Icon:SetDesaturated(false)
			eyeBtn.Icon:SetVertexColor(0.55, 0.90, 1.0)
		end
	end
end

local function ShowEyeButtonTooltip(eyeBtn, lineFrame)
	if not eyeBtn or not lineFrame or not GameTooltip then
		return
	end
	local elementData = lineFrame.GetElementData and lineFrame:GetElementData()
	local info = elementData and elementData.bindingInfo
	local isHidden = (info and Database.IsBindingHiddenInHover and Database.IsBindingHiddenInHover(info)) and true or false

	GameTooltip:SetOwner(eyeBtn, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, L["HOVER_EYE_TOOLTIP_TITLE"])
	GameTooltip:AddLine(isHidden and L["HOVER_EYE_STATUS_HIDDEN"] or L["HOVER_EYE_STATUS_VISIBLE"], 1, 1, 1, true)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["HOVER_EYE_TOOLTIP_HINT"], 0.75, 0.85, 1.0, true)
	GameTooltip:Show()
end

local function EnsureLineEyeButton(lineFrame)
	if lineFrame.BCCEyeButton then
		if not Constants.IsGamepadUIActive() and lineFrame.BCCEyeButton:GetParent() ~= lineFrame then
			lineFrame.BCCEyeButton:SetParent(lineFrame)
			ApplyLineCompactMetrics(lineFrame)
		end
		return lineFrame.BCCEyeButton
	end

	local compact = Database.Get("compactListMode") and true or false
	local btnW = compact and 20 or 22
	local btnH = compact and 15 or 18
	local iconSz = compact and 12 or 14

	local btn = CreateFrame("Button", nil, lineFrame)
	btn:SetSize(btnW, btnH)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Freistehendes Augen-Icon ohne Pill-Kasten (Option A), damit zwischen oberer Textzeile
	-- und unterem DeleteButton ("X") keine Kasten-auf-Kasten-Quetschung entsteht.
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAtlas("friends-icon-eye")
	icon:SetSize(iconSz, iconSz)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn.Icon = icon

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAtlas("friends-icon-eye")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.45)
	hl:SetAllPoints(icon)
	btn.Highlight = hl

	btn:SetScript("OnMouseDown", function(self)
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 1, -1)
		end
	end)
	btn:SetScript("OnMouseUp", function(self)
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
		end
	end)
	btn:SetScript("OnClick", function(self)
		local elementData = lineFrame.GetElementData and lineFrame:GetElementData()
		local info = elementData and not elementData.unbound and elementData.bindingInfo
		if not info or not info.button or not Database.ToggleBindingHiddenInHover then
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local isNowHidden = Database.ToggleBindingHiddenInHover(info)
		ApplyEyeButtonVisualState(self, isNowHidden)
		if GameTooltip and GameTooltip:IsOwned(self) then
			ShowEyeButtonTooltip(self, lineFrame)
		end
	end)
	btn:SetScript("OnEnter", function(self)
		if lineFrame.DeleteButton and ShouldShowDeleteButton(lineFrame) then
			lineFrame.DeleteButton:Show()
		end
		ShowEyeButtonTooltip(self, lineFrame)
	end)
	btn:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
		if lineFrame:IsMouseMotionFocus() then
			ClickBindingUI.ShowLineTooltip(lineFrame)
		end
		if lineFrame.DeleteButton and ShouldShowDeleteButton(lineFrame) then
			lineFrame.DeleteButton:Show()
		end
	end)

	btn:Hide()
	lineFrame.BCCEyeButton = btn
	return btn
end

local function UpdateLineEyeButton(lineFrame, elementData)
	if not lineFrame then
		return
	end
	if Constants.IsGamepadUIActive() then
		if lineFrame.BCCEyeButton then
			lineFrame.BCCEyeButton:Hide()
			lineFrame.BCCEyeButton:SetParent(nil)
		end
		return
	end
	local eyeBtn = EnsureLineEyeButton(lineFrame)
	if not eyeBtn then
		return
	end
	local hoverMode = Database.Get("unitHoverMode") or "off"
	local info = elementData and not elementData.unbound and elementData.bindingInfo
	if hoverMode == "off" or not info or not info.button then
		eyeBtn:Hide()
		return
	end

	local topRowY = lineFrame._bccTopRowY or 9
	eyeBtn:ClearAllPoints()
	eyeBtn:SetPoint("RIGHT", lineFrame, "RIGHT", -6, topRowY)

	local isHidden = Database.IsBindingHiddenInHover and Database.IsBindingHiddenInHover(info) or false
	ApplyEyeButtonVisualState(eyeBtn, isHidden)
	eyeBtn:Show()
end

local function ApplyRankToLine(lineFrame, elementData, subtext)
	local rankBtn = EnsureLineRankButton(lineFrame)
	local manaText = EnsureLineManaText(lineFrame)
	UpdateLineEyeButton(lineFrame, elementData)

	if not elementData or not elementData.bindingInfo or not Constants.IsSpellOrPetBinding(elementData.bindingInfo) then
		if rankBtn then
			rankBtn:Hide()
		end
		if manaText then
			manaText:Hide()
		end
		return
	end

	local actionID = elementData.bindingInfo.actionID
	local baseName = SpellRanks.GetSpellBaseNameForAction(actionID)
	if not baseName then
		if rankBtn then
			rankBtn:Hide()
		end
		if manaText then
			manaText:Hide()
		end
		return
	end

	local isDisabled = elementData.unbound
	local isLearned = SpellRanks.IsBindingSpellLearned(elementData.bindingInfo)
	if lineFrame.Icon and lineFrame.Icon.SetDesaturated then
		local shouldDesaturate = (isDisabled and elementData.elementType ~= ElementDataTypes.NewSlot) or (not isLearned)
		lineFrame.Icon:SetDesaturated(shouldDesaturate)
	end

	-- Live-Manakosten rechtsbündig links neben dem Augen-Button (oder am rechten Zeilenrand, wenn das Hover-Overlay aus ist)
	local topRowY = lineFrame._bccTopRowY or 9
	local eyeShown = (lineFrame.BCCEyeButton and lineFrame.BCCEyeButton:IsShown()) and true or false
	if manaText then
		manaText:ClearAllPoints()
		if eyeShown then
			manaText:SetPoint("RIGHT", lineFrame.BCCEyeButton, "LEFT", -4, 0)
		else
			manaText:SetPoint("RIGHT", lineFrame, "RIGHT", -8, topRowY)
		end
		local costStr = Database.Get("showLineManaCost") and SpellRanks.GetSpellPowerCostString(actionID) or nil
		if costStr and costStr ~= "" then
			if isDisabled or not isLearned then
				manaText:SetText("|cff777777" .. costStr .. "|r")
			else
				manaText:SetText("|cff80c8ff" .. costStr .. "|r")
			end
			manaText:Show()
			if lineFrame.Name and lineFrame.Icon then
				lineFrame.Name:ClearAllPoints()
				lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, topRowY)
				lineFrame.Name:SetPoint("RIGHT", manaText, "LEFT", -6, 0)
			end
		else
			manaText:Hide()
			if lineFrame.Name and lineFrame.Icon then
				lineFrame.Name:ClearAllPoints()
				lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, topRowY)
				if eyeShown then
					lineFrame.Name:SetPoint("RIGHT", lineFrame.BCCEyeButton, "LEFT", -6, 0)
				else
					lineFrame.Name:SetPoint("RIGHT", lineFrame, "RIGHT", -8, topRowY)
				end
			end
		end
	end

	local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
	if (not subtext or subtext == "") and rankEntry and rankEntry.subName and rankEntry.subName ~= "" then
		subtext = rankEntry.subName
	end

	local showRankInName = Database.Get("showRankInName")
	local highlightDownranks = Database.Get("highlightDownranks")
	local showRankSwitcher = Database.Get("showRankSwitcher")

	-- Nicht gelernter Zauber (z. B. nach Talent-Respec, während das ClickBindingFrame geschlossen war):
	-- Funktioniert auch für ranglose Talent-Zauber (ohne Subtext) und hebt die Zeile in Rot hervor.
	if not isLearned then
		local unlearnedName
		if showRankInName and subtext and subtext ~= "" then
			unlearnedName = string.format("|cff999999%s (%s)|r %s%s%s", baseName, subtext, Colors.WARN_UNLEARNED, L["TAG_NOT_LEARNED"], Colors.RESET)
		else
			unlearnedName = string.format("|cff999999%s|r %s%s%s", baseName, Colors.WARN_UNLEARNED, L["TAG_NOT_LEARNED"], Colors.RESET)
		end
		if lineFrame.Name then
			lineFrame.Name:SetText(unlearnedName)
		end
		if rankBtn then
			local fallbackGroup = SpellRanks.GetSpellGroupForAction(actionID, elementData.bindingInfo.type)
			if showRankSwitcher and fallbackGroup and fallbackGroup.entries and #fallbackGroup.entries >= 1 then
				local shortRank = (subtext and subtext ~= "" and (SpellRanks.ExtractShortRankText(subtext) or subtext)) or "?"
				rankBtn.Text:SetText(string.format("%s%s (!)%s", Colors.WARN_UNLEARNED, shortRank, Colors.RESET))
				if rankBtn.Bg then
					rankBtn.Bg:SetVertexColor(1.0, 0.72, 0.72, 1.0)
				end
				rankBtn:Show()
			else
				rankBtn:Hide()
			end
		end
		UpdateLineEyeButton(lineFrame, elementData)
		return
	end

	if not subtext or subtext == "" then
		if rankBtn then
			rankBtn:Hide()
		end
		UpdateLineEyeButton(lineFrame, elementData)
		return
	end

	local hasMultipleRanks = rankEntry and rankEntry.group and #rankEntry.group.entries > 1
	local maxEntry = hasMultipleRanks and rankEntry.group.maxEntry or nil
	local isMaxRank = (not hasMultipleRanks) or (maxEntry and maxEntry.actionID == rankEntry.actionID)

	local formattedName
	if not showRankInName then
		formattedName = (isDisabled and DISABLED_FONT_COLOR)
			and DISABLED_FONT_COLOR:WrapTextInColorCode(baseName)
			or baseName
	elseif isDisabled and DISABLED_FONT_COLOR then
		if highlightDownranks and hasMultipleRanks and not isMaxRank and maxEntry and maxEntry.rankNum then
			local maxHint = string.format(L["MAX_RANK_HINT_FORMAT"], maxEntry.rankNum)
			formattedName = DISABLED_FONT_COLOR:WrapTextInColorCode(string.format("%s (%s%s)", baseName, subtext, maxHint))
		else
			formattedName = DISABLED_FONT_COLOR:WrapTextInColorCode(string.format("%s (%s)", baseName, subtext))
		end
	else
		if highlightDownranks and hasMultipleRanks then
			if isMaxRank then
				formattedName = string.format("%s %s(%s)%s %s%s%s", baseName, Colors.RANK_MAX, subtext, Colors.RESET, Colors.TAG_MAX, L["TAG_MAX"], Colors.RESET)
			else
				local maxHint = (maxEntry and maxEntry.rankNum) and string.format(L["MAX_RANK_HINT_FORMAT"], maxEntry.rankNum) or ""
				formattedName = string.format("%s %s(%s%s)%s", baseName, Colors.RANK_DOWN, subtext, maxHint, Colors.RESET)
			end
		else
			formattedName = string.format("%s %s(%s)%s", baseName, Colors.RANK_MAX, subtext, Colors.RESET)
		end
	end

	if lineFrame.Name then
		lineFrame.Name:SetText(formattedName)
	end

	-- Smart-Regel auch für einzelne Rang-1-Zauber im Hintergrund initialisieren (Option A)
	if Database.Get("enableSmartRankRules") and elementData.bindingInfo.button and rankEntry and (#rankEntry.group.entries > 1 or rankEntry.rankNum) then
		SpellRanks.GetRuleForBinding(elementData.bindingInfo, rankEntry)
	end

	if rankBtn then
		if showRankSwitcher and hasMultipleRanks then
			local shortRank = SpellRanks.ExtractShortRankText(subtext) or subtext
			local ruleMode = (Database.Get("enableSmartRankRules") and elementData.bindingInfo.button)
				and SpellRanks.GetRuleForBinding(elementData.bindingInfo, rankEntry)
				or (isMaxRank and SpellRanks.RULE_MAX or SpellRanks.RULE_FIXED)
			local shortTag = GetRuleShortTag(ruleMode, isMaxRank)

			if highlightDownranks and isMaxRank then
				rankBtn.Text:SetText(string.format("%s%s (%s)%s", Colors.TAG_MAX, shortRank, shortTag, Colors.RESET))
				if rankBtn.Bg then
					rankBtn.Bg:SetVertexColor(0.82, 1.0, 0.85, 1.0)
				end
			elseif ruleMode == SpellRanks.RULE_MAX_MINUS_1 or ruleMode == SpellRanks.RULE_MAX_MINUS_2 or ruleMode == SpellRanks.RULE_MAX_MINUS_3 then
				rankBtn.Text:SetText(string.format("%s%s (%s)%s", Colors.RANK_MAX, shortRank, shortTag, Colors.RESET))
				if rankBtn.Bg then
					rankBtn.Bg:SetVertexColor(0.82, 0.94, 1.0, 1.0)
				end
			elseif highlightDownranks and not isMaxRank then
				rankBtn.Text:SetText(string.format("%s%s (%s)%s", Colors.RANK_DOWN, shortRank, shortTag, Colors.RESET))
				if rankBtn.Bg then
					rankBtn.Bg:SetVertexColor(1.0, 0.88, 0.72, 1.0)
				end
			else
				rankBtn.Text:SetText(string.format("%s%s%s", Colors.RANK_MAX, shortRank, Colors.RESET))
				if rankBtn.Bg then
					rankBtn.Bg:SetVertexColor(1.0, 1.0, 1.0, 1.0)
				end
			end
			rankBtn:Show()
		else
			rankBtn:Hide()
		end
	end
	UpdateLineEyeButton(lineFrame, elementData)
end

function ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
	if not lineFrame then
		return
	end
	if Constants.IsGamepadUIActive() then
		if lineFrame.BCCRankButton then
			lineFrame.BCCRankButton:Hide()
			lineFrame.BCCRankButton:SetParent(nil)
		end
		if lineFrame.BCCEyeButton then
			lineFrame.BCCEyeButton:Hide()
			lineFrame.BCCEyeButton:SetParent(nil)
		end
		if lineFrame.BCCManaText then
			lineFrame.BCCManaText:Hide()
		end
		return
	end

	elementData = elementData or (lineFrame.GetElementData and lineFrame:GetElementData())
	local delBtn = EnsureDeleteButtonStyled(lineFrame)
	ApplyLineCompactMetrics(lineFrame)
	local topRowY = lineFrame._bccTopRowY or 9
	local showDelete = ShouldShowDeleteButton(lineFrame, elementData)
	if delBtn then
		delBtn._bccAllowHide = not showDelete
		delBtn:SetShown(showDelete)
		delBtn._bccAllowHide = false
	end

	if lineFrame.BCCRankButton then
		lineFrame.BCCRankButton:Hide()
	end
	if lineFrame.BCCEyeButton then
		lineFrame.BCCEyeButton:Hide()
	end
	if lineFrame.BCCManaText then
		lineFrame.BCCManaText:Hide()
	end
	if lineFrame.Icon and lineFrame.Icon.SetDesaturated then
		local isUnboundAction = (elementData and elementData.unbound and elementData.elementType ~= ElementDataTypes.NewSlot) and true or false
		lineFrame.Icon:SetDesaturated(isUnboundAction)
	end
	if lineFrame.Name and lineFrame.Icon then
		lineFrame.Name:ClearAllPoints()
		lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, topRowY)
		lineFrame.Name:SetPoint("RIGHT", lineFrame, "RIGHT", -8, topRowY)
	end

	if not elementData or not elementData.bindingInfo or not Constants.IsSpellOrPetBinding(elementData.bindingInfo) then
		UpdateLineEyeButton(lineFrame, elementData)
		if lineFrame.Name and lineFrame.Icon and lineFrame.BCCEyeButton and lineFrame.BCCEyeButton:IsShown() then
			lineFrame.Name:ClearAllPoints()
			lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, topRowY)
			lineFrame.Name:SetPoint("RIGHT", lineFrame.BCCEyeButton, "LEFT", -6, 0)
		end
		return
	end

	local actionID = elementData.bindingInfo.actionID
	if not actionID then
		UpdateLineEyeButton(lineFrame, elementData)
		return
	end

	local subtext = SpellRanks.GetSpellSubtextForAction(actionID)
	if subtext then
		ApplyRankToLine(lineFrame, elementData, subtext)
		return
	end

	local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
	if rankEntry and rankEntry.subName and rankEntry.subName ~= "" then
		ApplyRankToLine(lineFrame, elementData, rankEntry.subName)
		return
	end

	-- Auch ranglose Zauber (ohne Subtext) sofort auf Manakosten aktualisieren
	ApplyRankToLine(lineFrame, elementData, "")

	-- C_Spell.GetSpellSubtext lädt laut Blizzard-Dokumentation asynchron nach;
	-- vor dem Schreiben wird geprüft, ob das recycelte Frame noch dasselbe elementData hält.
	if Spell and Spell.CreateFromSpellID then
		local spell = Spell:CreateFromSpellID(actionID)
		spell:ContinueOnSpellLoad(function()
			local currentData = lineFrame.GetElementData and lineFrame:GetElementData() or elementData
			if currentData ~= elementData then
				return
			end
			if not elementData.bindingInfo or elementData.bindingInfo.actionID ~= actionID then
				return
			end
			local loadedSubtext = SpellRanks.GetSpellSubtextForAction(actionID)
			if loadedSubtext then
				ApplyRankToLine(lineFrame, elementData, loadedSubtext)
			end
		end)
	end
end

local function HookHeaderFrame(headerFrame)
	if Constants.IsGamepadUIActive() then
		return
	end
	if not headerFrame or headerFrame._bccHeaderHooked then
		return
	end
	if type(headerFrame.Init) == "function" and (not ClickBindingHeaderMixin or headerFrame.Init ~= ClickBindingHeaderMixin.Init) then
		hooksecurefunc(headerFrame, "Init", function(self, elementData)
			UpdateHeaderFrame(self, elementData)
		end)
	end
	headerFrame._bccHeaderHooked = true
end

local function HookLineFrame(lineFrame)
	if Constants.IsGamepadUIActive() then
		return
	end
	if not lineFrame then
		return
	end

	if not lineFrame._bccInitHooked and type(lineFrame.Init) == "function" then
		if not ClickBindingLineMixin or lineFrame.Init ~= ClickBindingLineMixin.Init then
			hooksecurefunc(lineFrame, "Init", function(self, elementData)
				ClickBindingUI.UpdateLineWithRank(self, elementData)
			end)
		end
		lineFrame._bccInitHooked = true
	end

	if not lineFrame._bccHoverHooked then
		lineFrame:HookScript("OnEnter", function(self)
			ClickBindingUI.ShowLineTooltip(self)
		end)
		lineFrame:HookScript("OnLeave", function(self)
			if Constants.IsGamepadUIActive() then
				return
			end
			if self.DeleteButton and ShouldShowDeleteButton(self) then
				self.DeleteButton:Show()
			end
			if (self.BCCRankButton and self.BCCRankButton:IsMouseMotionFocus())
				or (self.BCCEyeButton and self.BCCEyeButton:IsMouseMotionFocus())
			then
				return
			end
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
		end)
		lineFrame._bccHoverHooked = true
	end
end

function ClickBindingUI.RefreshVisibleLines()
	if ClickBindingFrame and ClickBindingFrame:IsShown() then
		ClickBindingUI.UpdatePresetDropdownButton()
	end
	if ClickBindingUI.RefreshFreeKeysMatrix then
		ClickBindingUI.RefreshFreeKeysMatrix()
	end
	if ClickBindingFrame
		and ClickBindingFrame:IsShown()
		and ClickBindingFrame.ScrollBox
		and ClickBindingFrame.ScrollBox.GetView
		and ClickBindingFrame.ScrollBox:GetView()
		and ClickBindingFrame.ScrollBox.ForEachFrame
	then
		ClickBindingFrame.ScrollBox:ForEachFrame(function(frame)
			local elementData = frame.GetElementData and frame:GetElementData()
			if elementData and (elementData.elementType == ElementDataTypes.DefaultsHeader or elementData.elementType == ElementDataTypes.CustomsHeader) then
				HookHeaderFrame(frame)
				UpdateHeaderFrame(frame, elementData)
			else
				HookLineFrame(frame)
				ClickBindingUI.UpdateLineWithRank(frame, elementData)
			end
		end)
	end
end

local gamepadStandbyTooltip = nil

local function EnsureGamepadStandbyTooltip()
	if gamepadStandbyTooltip then
		return gamepadStandbyTooltip
	end
	-- Eigenes reines Anzeige-Tooltip-Frame auf TOOLTIP-Strata mit FrameLevel 9500,
	-- damit es garantiert oberhalb von Blizzards SmartNavigation-Bouncy-Pfeil (TOOLTIP-Strata)
	-- liegt und GameTooltip im Controller-Modus nicht einmal berührt.
	local tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	tip:SetSize(330, 120)
	tip:SetFrameStrata("TOOLTIP")
	tip:SetFrameLevel(9500)
	tip:SetClampedToScreen(true)
	tip:EnableMouse(false)

	if tip.SetBackdrop then
		tip:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		tip:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
		tip:SetBackdropBorderColor(0.95, 0.32, 0.32, 1.0)
	end

	local title = tip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", tip, "TOPLEFT", 12, -10)
	title:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -12, -10)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(true)
	tip.Title = title

	local desc = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetWidth(306)
	desc:SetJustifyH("LEFT")
	desc:SetWordWrap(true)
	tip.Desc = desc

	tip:Hide()
	gamepadStandbyTooltip = tip
	return tip
end

local function ShowGamepadStandbyTooltip(ownerBadge)
	local tip = EnsureGamepadStandbyTooltip()
	tip.Title:SetText("|cffff6666" .. (L["GAMEPAD_STANDBY_TOOLTIP_TITLE"] or "") .. "|r")
	tip.Desc:SetText(L["GAMEPAD_STANDBY_TOOLTIP_DESC"] or "")
	local h = 28 + (tip.Title:GetStringHeight() or 14) + (tip.Desc:GetStringHeight() or 60)
	tip:SetSize(330, math.max(84, math.floor(h + 0.5)))
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", ownerBadge, "TOPRIGHT", 8, 0)
	tip:Show()
end

local function HideGamepadStandbyTooltip()
	if gamepadStandbyTooltip then
		gamepadStandbyTooltip:Hide()
	end
end

local function EnsureGamepadStandbyBadge()
	if gamepadStandbyBadge then
		return gamepadStandbyBadge
	end
	-- Absichtlich als einfaches Frame (kein Button!) auf UIParent (nicht auf ClickBindingFrame!) erstellt,
	-- damit ClickBindingFrame:GetChildren() und SmartNavigation_CanFocusFrame im Gamepad-Modus
	-- keinerlei AddOn-Child-Frames sehen und der Fokus-Stack zu 100 % untainted bleibt.
	local badge = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	badge:SetSize(210, 22)
	badge:SetFrameStrata("TOOLTIP")
	badge:SetFrameLevel(9000)
	badge:EnableMouse(true)

	if badge.SetBackdrop then
		badge:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		badge:SetBackdropColor(0.26, 0.05, 0.05, 0.95)
		badge:SetBackdropBorderColor(0.95, 0.28, 0.28, 1.0)
	end

	local label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("CENTER", badge, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	label:SetWordWrap(false)
	badge.Text = label

	badge:SetScript("OnEnter", function(self)
		ShowGamepadStandbyTooltip(self)
	end)
	badge:SetScript("OnLeave", function()
		HideGamepadStandbyTooltip()
	end)
	badge:SetScript("OnHide", function()
		HideGamepadStandbyTooltip()
	end)
	badge:SetScript("OnUpdate", function(self)
		if not ClickBindingFrame or not ClickBindingFrame:IsShown() or not Constants.IsGamepadUIActive() then
			self:Hide()
		end
	end)

	badge:Hide()
	gamepadStandbyBadge = badge
	return badge
end

function ClickBindingUI.UpdateGamepadStandbyState()
	local isGamepad = Constants.IsGamepadUIActive()
	if isGamepad then
		SetSaveButtonGlowShown(false)
		ClickBindingUI.HideHeroCard()
		ClickBindingUI.HideChildPopups()
		if SettingsUI and SettingsUI.HideWindow then
			SettingsUI.HideWindow()
		end
		if SettingsUI and SettingsUI.AttachToClickBindingFrame then
			SettingsUI.AttachToClickBindingFrame()
		end
		ClickBindingUI.UpdatePresetDropdownButton()
		if ClickBindingFrame
			and ClickBindingFrame.ScrollBox
			and ClickBindingFrame.ScrollBox.GetView
			and ClickBindingFrame.ScrollBox:GetView()
			and ClickBindingFrame.ScrollBox.ForEachFrame
		then
			ClickBindingFrame.ScrollBox:ForEachFrame(function(frame)
				local elementData = frame.GetElementData and frame:GetElementData()
				if elementData and (elementData.elementType == ElementDataTypes.DefaultsHeader or elementData.elementType == ElementDataTypes.CustomsHeader) then
					UpdateHeaderFrame(frame, elementData)
				else
					ClickBindingUI.UpdateLineWithRank(frame, elementData)
				end
			end)
		end
		if ClickBindingFrame and ClickBindingFrame:IsShown() then
			local badge = EnsureGamepadStandbyBadge()
			badge.Text:SetText(L["GAMEPAD_STANDBY_BADGE"])
			local textW = badge.Text:GetStringWidth() or 180
			badge:SetSize(math.max(190, math.floor(textW + 22)), 22)
			badge:ClearAllPoints()
			if ClickBindingFrame.EnableMouseoverCastCheckbox then
				badge:SetPoint("TOPLEFT", ClickBindingFrame.EnableMouseoverCastCheckbox, "BOTTOMLEFT", 4, -2)
			else
				badge:SetPoint("TOPLEFT", ClickBindingFrame, "TOPLEFT", 64, -58)
			end
			badge:Show()
		elseif gamepadStandbyBadge then
			gamepadStandbyBadge:Hide()
		end
	else
		if gamepadStandbyBadge then
			gamepadStandbyBadge:Hide()
		end
		if SettingsUI and SettingsUI.AttachToClickBindingFrame then
			SettingsUI.AttachToClickBindingFrame()
		end
		ClickBindingUI.UpdatePresetDropdownButton()
		if ClickBindingFrame and ClickBindingFrame:IsShown() then
			ClickBindingUI.ApplyScrollBoxLayout()
			ClickBindingUI.RebuildGroups()
			ClickBindingUI.RefreshVisibleLines()
			ClickBindingUI.UpdateSaveButtonCombatShield()
		end
	end
end

--------------------------------------------------------------------------------
-- Zauberbuch-Sync und Hooks
--------------------------------------------------------------------------------

function ClickBindingUI.EnsureSpellBookTabForClickBinding()
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	-- Im Controller-Modus (GamepadUI) wird das TabSystem von PlayerSpellsFrame ausgeblendet
	-- und durch GamepadMode.FrameControlsManager verwaltet; dort niemals per AddOn eingreifen.
	if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
		return
	end
	if not PlayerSpellsFrame or not PlayerSpellsUtil or not PlayerSpellsUtil.FrameTabs then
		return
	end
	local spellBookTab = PlayerSpellsUtil.FrameTabs.SpellBook
	if not spellBookTab then
		return
	end
	if PlayerSpellsFrame.ClearInspectUnit and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then
		PlayerSpellsFrame:ClearInspectUnit()
	end
	-- In WoW Forever teilen sich Zauberbuch und Talentbaum denselben PlayerSpellsFrame.
	-- Wurde zuvor der Talentbaum geöffnet (und ist das Fenster nicht schon als Zauberbuch offen),
	-- wechseln wir über SetTab(spellBookTabID) auf den SpellBook-Tab, ohne SetUIPanelAttribute via TrySetTab zu tainten.
	local currentTabID = PlayerSpellsFrame.GetTab and PlayerSpellsFrame:GetTab()
	local spellBookTabID = PlayerSpellsFrame.spellBookTabID
	if currentTabID and spellBookTabID and currentTabID ~= spellBookTabID then
		if PlayerSpellsFrame:IsShown() and HideUIPanel then
			HideUIPanel(PlayerSpellsFrame)
		end
		if PlayerSpellsFrame.SetTab then
			PlayerSpellsFrame:SetTab(spellBookTabID)
		elseif PlayerSpellsFrame.TrySetTab then
			PlayerSpellsFrame:TrySetTab(spellBookTab)
		end
	end
end

function ClickBindingUI.SyncAutoShowAllRanks()
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	if not GetCVarBool or not SetCVar then
		return
	end
	-- Wichtig: Niemals PlayerSpellsFrame.SpellBookFrame:UpdateDisplayedSpells(true, false) aus AddOn-Code aufrufen,
	-- da dies den DataProvider des Zauberbuchs taintet und beim Hover über Zauber im Zauberbuch via
	-- PetActionBar:ClearPetActionHighlightMarks() das globale _G.PET_ACTION_HIGHLIGHT_MARKS infiziert.
	if Database.Get("autoShowAllRanks") and not GetCVarBool("ShowAllSpellRanks") then
		SetCVar("ShowAllSpellRanks", 1)
	end
end

-- Wählt beim Öffnen von /bcc automatisch den Klassen-Tab im Zauberbuch (den Reiter mit den meisten gebundenen
-- Klick-Zaubern oder den ersten Klassen-Tab), sofern das Zauberbuch noch auf dem Reiter "Allgemein" steht.
function ClickBindingUI.AutoSelectPrimarySpellBookTab()
	if not Database.Get("autoSelectPrimarySpellTab") then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	-- Im Controller-Modus nicht in die Zauberbuch-Kategorieauswahl eingreifen
	if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
		return
	end
	if not PlayerSpellsFrame or not PlayerSpellsFrame.SpellBookFrame then
		return
	end
	local sbFrame = PlayerSpellsFrame.SpellBookFrame
	if not sbFrame.categoryMixins or not sbFrame.GetActiveCategoryMixin or not sbFrame.SetTab then
		return
	end

	local generalIndex = (Enum and Enum.SpellBookSkillLineIndex and Enum.SpellBookSkillLineIndex.General) or 1
	local activeMixin = sbFrame:GetActiveCategoryMixin()
	-- Wenn der Spieler bereits manuell einen Klassen- oder Pet-Reiter gewählt hat, niemals überschreiben
	if not activeMixin or activeMixin.skillLineIndex ~= generalIndex then
		return
	end

	local classCandidates = {}
	for _, mixin in ipairs(sbFrame.categoryMixins) do
		if mixin.skillLineIndex
			and mixin.skillLineIndex > generalIndex
			and mixin.spellBank == Enum.SpellBookSpellBank.Player
			and (not mixin.IsAvailable or mixin:IsAvailable())
		then
			table.insert(classCandidates, { mixin = mixin, boundCount = 0 })
		end
	end

	if #classCandidates == 0 then
		return
	end

	-- Zählen, welcher Klassen-Tab die meisten aktuell gebundenen Klick-Zauber enthält
	if C_ClickBindings and C_ClickBindings.GetProfileInfo then
		local profile = C_ClickBindings.GetProfileInfo()
		if type(profile) == "table" then
			for _, info in ipairs(profile) do
				if info and info.actionID and Constants.IsSpellOrPetBinding(info) then
					local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
					if rankEntry and rankEntry.slotIndex and rankEntry.spellBank == Enum.SpellBookSpellBank.Player then
						for _, cand in ipairs(classCandidates) do
							if cand.mixin.ContainsSlot and cand.mixin:ContainsSlot(rankEntry.slotIndex, rankEntry.spellBank) then
								cand.boundCount = cand.boundCount + 1
								break
							end
						end
					end
				end
			end
		end
	end

	local bestMixin = classCandidates[1].mixin
	local bestCount = classCandidates[1].boundCount
	for i = 2, #classCandidates do
		if classCandidates[i].boundCount > bestCount then
			bestCount = classCandidates[i].boundCount
			bestMixin = classCandidates[i].mixin
		end
	end

	local targetTabID = bestMixin and bestMixin.GetTabID and bestMixin:GetTabID()
	if targetTabID then
		if SpellBookUI and SpellBookUI.SetupHooks then
			SpellBookUI.SetupHooks()
		end
		sbFrame:SetTab(targetTabID)
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
	end
end

function ClickBindingUI.SetupHooks()
	if isHooked
		or not ClickBindingFrame
		or not ClickBindingLineMixin
		or not ClickBindingFrame.ScrollBox
		or (ClickBindingFrame.ScrollBox.GetView and not ClickBindingFrame.ScrollBox:GetView())
	then
		return
	end
	isHooked = true

	-- 0. Settings-Button und Preset-Dropdown im ClickBindingFrame einrichten
	if SettingsUI and SettingsUI.AttachToClickBindingFrame then
		SettingsUI.AttachToClickBindingFrame()
	end
	ClickBindingUI.UpdatePresetDropdownButton()
	if ClickBindingFrame.UpdateMouseoverCastUI then
		hooksecurefunc(ClickBindingFrame, "UpdateMouseoverCastUI", function()
			ClickBindingUI.UpdatePresetDropdownButton()
		end)
	end

	-- Beim Klick auf das Zauberbuch-Portrait im ClickBindingFrame sicherstellen, dass der SpellBook-Tab aktiv ist,
	-- und Blizzards irreführenden Tooltip-Titel ("Talents" via PLAYERSPELLS_BUTTON) zu "Spellbook" / "Zauberbuch" (SPELLBOOK) korrigieren.
	if ClickBindingFrame.PlayerSpellsPortrait and ClickBindingFrame.PlayerSpellsPortrait.HookScript then
		ClickBindingFrame.PlayerSpellsPortrait:HookScript("OnMouseDown", function()
			ClickBindingUI.EnsureSpellBookTabForClickBinding()
		end)
		ClickBindingFrame.PlayerSpellsPortrait:HookScript("OnEnter", function(self)
			if GameTooltip and GameTooltip:IsOwned(self) and SPELLBOOK then
				GameTooltip_SetTitle(GameTooltip, SPELLBOOK)
				GameTooltip:Show()
			end
		end)
	end

	-- Auto-Show-All-Spell-Ranks, Smart-Rule-Sync und Zauberbuch-Sync beim Öffnen und Schließen des ClickBindingFrames
	ClickBindingFrame:HookScript("OnShow", function()
		if ClickBindingUI.ClearPendingPresetState then
			ClickBindingUI.ClearPendingPresetState()
		end
		ClickBindingUI.HideHeroCard()
		if Constants.IsGamepadUIActive() then
			ClickBindingUI.UpdateGamepadStandbyState()
			return
		end
		ClickBindingUI.UpdateGamepadStandbyState()
		ClickBindingUI.UpdatePresetDropdownButton()
		ClickBindingUI.SyncAutoShowAllRanks()
		ClickBindingUI.AutoSelectPrimarySpellBookTab()
		ClickBindingUI.ApplyScrollBoxLayout()
		ClickBindingUI.RebuildGroups()
		if Database.Get("matrixAutoOpen") then
			ClickBindingUI.ShowFreeKeysMatrix()
		end
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
		ClickBindingUI.UpdateSaveButtonCombatShield()
	end)

	ClickBindingFrame:HookScript("OnHide", function()
		if gamepadStandbyBadge then
			gamepadStandbyBadge:Hide()
		end
		if saveCombatShield then
			saveCombatShield:Hide()
		end
		-- Snapshot beim Schließen leeren, damit keine veralteten Zeilen aus einer früheren Sitzung kleben bleiben
		lastKnownProviderCustomBindings = {}
		isManualDeleteInProgress = false
		-- Pending-Preset für den synchron nachfolgenden SaveButton-Hook puffern; bei Abbruch ohne Speichern
		-- bleibt Database.GetActivePresetName() komplett unverändert.
		if ClickBindingUI.OnClickBindingFrameHidePendingPreset then
			ClickBindingUI.OnClickBindingFrameHidePendingPreset()
		end
		if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
			ns.SettingsUI.RefreshWindow()
		end
		SetSaveButtonGlowShown(false)
		ClickBindingUI.HideChildPopups()
		if SettingsUI and SettingsUI.HideWindow then
			SettingsUI.HideWindow()
		end
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
		-- Falls das Fenster ohne Speichern geschlossen wurde, prüft die Hero-Card kurz darauf, ob noch Updates offen sind
		ClickBindingUI.ScheduleSmartRuleCheck(0.4)
	end)

	-- 1. Hooks auf Mixin-Ebene für Zeilen und Header
	hooksecurefunc(ClickBindingLineMixin, "Init", function(lineFrame, elementData)
		HookLineFrame(lineFrame)
		ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
	end)

	if ClickBindingHeaderMixin and ClickBindingHeaderMixin.Init then
		hooksecurefunc(ClickBindingHeaderMixin, "Init", function(headerFrame, elementData)
			HookHeaderFrame(headerFrame)
			UpdateHeaderFrame(headerFrame, elementData)
		end)
	end

	-- 2. Bestehende und neu erworbene Frames in der ScrollBox nachrüsten
	if ClickBindingFrame.ScrollBox then
		ClickBindingUI.ApplyScrollBoxLayout()
		if ClickBindingFrame.ScrollBox.GetView and ClickBindingFrame.ScrollBox:GetView() and ClickBindingFrame.ScrollBox.ForEachFrame then
			ClickBindingFrame.ScrollBox:ForEachFrame(function(frame)
				local elementData = frame.GetElementData and frame:GetElementData()
				if elementData and (elementData.elementType == ElementDataTypes.DefaultsHeader or elementData.elementType == ElementDataTypes.CustomsHeader) then
					HookHeaderFrame(frame)
					UpdateHeaderFrame(frame, elementData)
				else
					HookLineFrame(frame)
					ClickBindingUI.UpdateLineWithRank(frame, elementData)
				end
			end)
		end

		if ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnAcquiredFrame then
			ClickBindingFrame.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame, elementData)
				if elementData and (elementData.elementType == ElementDataTypes.DefaultsHeader or elementData.elementType == ElementDataTypes.CustomsHeader) then
					HookHeaderFrame(frame)
					UpdateHeaderFrame(frame, elementData)
				else
					HookLineFrame(frame)
					ClickBindingUI.UpdateLineWithRank(frame, elementData)
				end
			end, ns)
		end
	end

	-- 3. Bei Refresh, CleanDataProvider und ResetToDefaultProfile Gruppen und Cache aktualisieren
	-- Wichtig: Normales Öffnen/Refresh verändert keine Ränge ungefragt; erst der Klick auf die Hero-Card
	-- ruft ApplySmartRulesToDataProvider() auf.
	if ClickBindingFrame.Refresh then
		hooksecurefunc(ClickBindingFrame, "Refresh", function()
			SpellRanks.InvalidateCache()
			SetSaveButtonGlowShown(false)
			ClickBindingUI.RebuildGroups()
			if SpellBookUI and SpellBookUI.RefreshBadges then
				SpellBookUI.RefreshBadges()
			end
			if Database and Database.SaveCharacterSnapshot then
				Database.SaveCharacterSnapshot()
			end
		end)
	end

	if ClickBindingFrame.SaveButton and not isSaveButtonHooked then
		ClickBindingFrame.SaveButton:HookScript("OnClick", function()
			-- Geladenes Preset wurde per Hardware-Klick auf "Speichern" bestätigt (auch wenn HideUIPanel/OnHide zuvor lief)
			if ClickBindingUI.CommitPendingPresetOnSave then
				ClickBindingUI.CommitPendingPresetOnSave()
			end
			if C_Timer and C_Timer.After and Database and Database.SaveCharacterSnapshot then
				C_Timer.After(0.1, Database.SaveCharacterSnapshot)
			end
		end)
		isSaveButtonHooked = true
	end

	if ClickBindingFrame.CleanDataProvider then
		hooksecurefunc(ClickBindingFrame, "CleanDataProvider", function()
			ClickBindingUI.RebuildGroups()
		end)
	end

	if ClickBindingFrame.ResetToDefaultProfile then
		hooksecurefunc(ClickBindingFrame, "ResetToDefaultProfile", function()
			lastKnownProviderCustomBindings = {}
			if ClickBindingUI.ClearPendingPresetState then
				ClickBindingUI.ClearPendingPresetState()
			end
			SetSaveButtonGlowShown(false)
			ClickBindingUI.RebuildGroups()
		end)
	end

	-- Dual-Spec-Schutz gegen Blizzards ClickBindingFrameMixin:OnEvent("SPELLS_CHANGED"),
	-- das bei geöffnetem ClickBindingFrame alle aktuell nicht gelernten Talent-Zauber aus dataProvider löscht.
	ClickBindingFrame:HookScript("OnEvent", function(self, event)
		if event == "SPELLS_CHANGED" and self:IsShown() and not Constants.IsGamepadUIActive() then
			ClickBindingUI.RestorePurgedUnlearnedBindings(true)
		end
	end)

	-- Falls ClickBindingFrame beim erstmaligen Laden bereits offen ist, sofort synchronisieren
	if ClickBindingFrame:IsShown() then
		ClickBindingUI.HideHeroCard()
		if Constants.IsGamepadUIActive() then
			ClickBindingUI.UpdateGamepadStandbyState()
		else
			ClickBindingUI.UpdateGamepadStandbyState()
			ClickBindingUI.SyncAutoShowAllRanks()
			ClickBindingUI.AutoSelectPrimarySpellBookTab()
			ClickBindingUI.RebuildGroups()
			ClickBindingUI.RefreshVisibleLines()
			ClickBindingUI.UpdateSaveButtonCombatShield()
		end
	end

	-- 4. Warnmeldung beim Überschreiben einer Taste ebenfalls mit Zauberrang versehen
	if ClickBindingFrame.SetUnboundText and CLICK_BINDING_UNBOUND_OUTPUT then
		hooksecurefunc(ClickBindingFrame, "SetUnboundText", function(self, elementData)
			if Constants.IsGamepadUIActive() then
				return
			end
			if not elementData or not elementData.bindingInfo or not Constants.IsSpellOrPetBinding(elementData.bindingInfo) then
				return
			end
			local actionID = elementData.bindingInfo.actionID
			local baseName = SpellRanks.GetSpellBaseNameForAction(actionID)
			local subtext = SpellRanks.GetSpellSubtextForAction(actionID)
			if baseName and subtext and subtext ~= "" and self.UnboundText then
				local fullSpellName = string.format("%s (%s)", baseName, subtext)
				self.UnboundText:SetText(string.format(CLICK_BINDING_UNBOUND_OUTPUT, fullSpellName))
			end
		end)
	end

		if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback("ClickBindingFrame.UpdateFrames", function()
			if SpellBookUI and SpellBookUI.RefreshBadges then
				SpellBookUI.RefreshBadges()
			end
			if ClickBindingUI.RefreshFreeKeysMatrix then
				ClickBindingUI.RefreshFreeKeysMatrix()
			end
		end, ns)
	end
end
