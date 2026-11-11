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
local isRebuildingGroups = false
local heroCardFrame = nil
local dismissedSignature = nil
local smartCheckPending = false

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

function ClickBindingUI.RebuildGroups()
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
				ClickBindingUI.RebuildGroups()
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
	for _, element in provider:Enumerate() do
		if element and element.elementType == ElementDataTypes.CustomsBinding then
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

	isRebuildingGroups = false
end

--------------------------------------------------------------------------------
-- Visuelles Highlight auf Blizzards Speichern-Button (bei Smart-Rule-Updates)
--------------------------------------------------------------------------------

local function SetSaveButtonGlowShown(shown)
	if not ClickBindingFrame or not ClickBindingFrame.SaveButton then
		return
	end
	local saveBtn = ClickBindingFrame.SaveButton
	if shown and not saveBtn.BCCGlowFrame then
		-- Exaktes 3-Slice YellowGlow-Pattern aus Blizzard_SharedTalentFrameTemplates.xml (CommitButton.YellowGlow)
		local glowFrame = CreateFrame("Frame", nil, saveBtn)
		glowFrame:SetSize(1, 1)
		glowFrame:SetPoint("LEFT", saveBtn, "LEFT", -12, 0)
		glowFrame:SetPoint("RIGHT", saveBtn, "RIGHT", 12, 0)
		glowFrame:SetFrameLevel(saveBtn:GetFrameLevel() + 2)

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
		hint:SetPoint("BOTTOMRIGHT", saveBtn, "TOPRIGHT", 0, 5)
		hint:SetText(Colors.HEADER_SUB .. L["SAVE_BUTTON_GLOW_HINT"] .. Colors.RESET)
		glowFrame.Hint = hint

		saveBtn.BCCGlowFrame = glowFrame
	end
	if saveBtn.BCCGlowFrame then
		if saveBtn.BCCGlowFrame.Hint then
			saveBtn.BCCGlowFrame.Hint:SetText(Colors.HEADER_SUB .. L["SAVE_BUTTON_GLOW_HINT"] .. Colors.RESET)
		end
		saveBtn.BCCGlowFrame:SetShown(shown and true or false)
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
			local maxEntry = rankEntry and rankEntry.group and rankEntry.group.maxEntry
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
			local maxEntry = rankEntry and rankEntry.group and rankEntry.group.maxEntry
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
	if not MenuUtil or not MenuUtil.CreateContextMenu or not rankEntry or not rankEntry.group then
		return
	end

	local group = rankEntry.group
	if #group.entries <= 1 then
		return
	end

	MenuUtil.CreateContextMenu(rankButton, function(_, rootDescription)
		-- 1. Sektion: Smarte Rang-Regeln (wenn für diese gebundene Zeile aktiv)
		if Database.Get("enableSmartRankRules") and elementData and elementData.bindingInfo and elementData.bindingInfo.button then
			rootDescription:CreateTitle(L["SMART_RULE_HEADER"])

			local function IsRuleSelected(modeValue)
				return SpellRanks.GetRuleForBinding(elementData.bindingInfo, rankEntry) == modeValue
			end

			local function SetRuleSelected(modeValue)
				SpellRanks.SetRuleForBinding(elementData.bindingInfo, modeValue, rankEntry)
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
		if rankEntry and rankEntry.slotIndex and rankEntry.spellBank then
			GameTooltip:SetSpellBookItem(rankEntry.slotIndex, rankEntry.spellBank)
		else
			GameTooltip:SetSpellByID(actionID)
		end

		GameTooltip:AddLine(" ")
		local bindText = Constants.GetFullBindingString(bindingInfo)
		GameTooltip:AddDoubleLine(L["TOOLTIP_CLICK_BINDING_LABEL"], bindText, 0.8, 0.8, 0.8, 1, 1, 1)

		if rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
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
		return headerFrame.BCCGroupButton, headerFrame.BCCSubDivider
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
	return btn, divider
end

local function UpdateHeaderFrame(headerFrame, elementData)
	if not headerFrame then
		return
	end
	elementData = elementData or (headerFrame.GetElementData and headerFrame:GetElementData())
	local groupBtn, divider = EnsureHeaderGroupWidgets(headerFrame)

	-- Zuerst eigene Elemente zurücksetzen (ScrollBox-Recycling-Hygiene)
	groupBtn:Hide()
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

	-- In der 2. Zeile (auf derselben vertikalen Achse y = -8 wie BindingText) rechts außen platzieren,
	-- damit Zeile 1 (Zaubername + Rang) die volle Zeilenbreite ohne Überlappung nutzen kann.
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
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 1, -1)
		end
	end)

	delBtn:HookScript("OnMouseUp", function(self)
		if self.Icon then
			self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
		end
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

local function EnsureLineRankButton(lineFrame)
	if lineFrame.BCCRankButton then
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
		if not rankEntry or not rankEntry.group then
			return
		end

		if mouseButton == "RightButton" then
			local maxEntry = rankEntry.group.maxEntry
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

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["RANK_SWITCHER_TOOLTIP_TITLE"])
		if rankEntry and rankEntry.group and rankEntry.group.maxEntry then
			local maxEntry = rankEntry.group.maxEntry
			GameTooltip:AddLine(string.format(L["RANK_SWITCHER_CURRENT_FORMAT"], rankEntry.subName or "?", maxEntry.subName or "?"), 1, 1, 1)
			if Database.Get("enableSmartRankRules") and elementData.bindingInfo.button then
				local ruleMode = SpellRanks.GetRuleForBinding(elementData.bindingInfo, rankEntry)
				GameTooltip:AddLine(string.format(L["RANK_SWITCHER_RULE_FORMAT"], GetRuleDisplayName(ruleMode)), 0.6, 0.85, 1.0)
			end
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

local function ApplyRankToLine(lineFrame, elementData, subtext)
	local rankBtn = EnsureLineRankButton(lineFrame)
	local manaText = EnsureLineManaText(lineFrame)

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

	-- Live-Manakosten rechtsbündig in Zeile 1 einblenden (Option 1A)
	if manaText then
		local costStr = Database.Get("showLineManaCost") and SpellRanks.GetSpellPowerCostString(actionID) or nil
		if costStr and costStr ~= "" then
			if isDisabled then
				manaText:SetText("|cff777777" .. costStr .. "|r")
			else
				manaText:SetText("|cff80c8ff" .. costStr .. "|r")
			end
			manaText:Show()
			if lineFrame.Name and lineFrame.Icon then
				lineFrame.Name:ClearAllPoints()
				lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, 9)
				lineFrame.Name:SetPoint("RIGHT", manaText, "LEFT", -6, 0)
			end
		else
			manaText:Hide()
			if lineFrame.Name and lineFrame.Icon then
				lineFrame.Name:ClearAllPoints()
				lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, 9)
				lineFrame.Name:SetPoint("RIGHT", lineFrame, "RIGHT", -8, 9)
			end
		end
	end

	local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
	if (not subtext or subtext == "") and rankEntry and rankEntry.subName and rankEntry.subName ~= "" then
		subtext = rankEntry.subName
	end

	if not subtext or subtext == "" then
		if rankBtn then
			rankBtn:Hide()
		end
		return
	end

	local showRankInName = Database.Get("showRankInName")
	local highlightDownranks = Database.Get("highlightDownranks")
	local showRankSwitcher = Database.Get("showRankSwitcher")

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
end

function ClickBindingUI.UpdateLineWithRank(lineFrame, elementData)
	if not lineFrame then
		return
	end

	elementData = elementData or (lineFrame.GetElementData and lineFrame:GetElementData())
	local delBtn = EnsureDeleteButtonStyled(lineFrame)
	local showDelete = ShouldShowDeleteButton(lineFrame, elementData)
	if delBtn then
		delBtn._bccAllowHide = not showDelete
		delBtn:SetShown(showDelete)
		delBtn._bccAllowHide = false
	end

	if lineFrame.BCCRankButton then
		lineFrame.BCCRankButton:Hide()
	end
	if lineFrame.BCCManaText then
		lineFrame.BCCManaText:Hide()
	end
	if lineFrame.Name and lineFrame.Icon then
		lineFrame.Name:ClearAllPoints()
		lineFrame.Name:SetPoint("LEFT", lineFrame.Icon, "RIGHT", 5, 9)
		lineFrame.Name:SetPoint("RIGHT", lineFrame, "RIGHT", -8, 9)
	end

	if not elementData or not elementData.bindingInfo or not Constants.IsSpellOrPetBinding(elementData.bindingInfo) then
		return
	end

	local actionID = elementData.bindingInfo.actionID
	if not actionID then
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
			if self.DeleteButton and ShouldShowDeleteButton(self) then
				self.DeleteButton:Show()
			end
			if self.BCCRankButton and self.BCCRankButton:IsMouseMotionFocus() then
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

	card:Hide()
	heroCardFrame = card
	return card
end

function ClickBindingUI.ResetHeroCardPosition()
	if type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.heroCardPos = nil
	end
	Database.Set("heroCardPos", nil)
	if heroCardFrame then
		ApplySavedHeroCardPosition(heroCardFrame)
	end
end

function ClickBindingUI.IsHeroCardPreviewUnlocked()
	return heroCardPreviewUnlocked
end

function ClickBindingUI.SetHeroCardPreviewUnlocked(unlocked)
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

function ClickBindingUI.HideHeroCard()
	if heroCardPreviewUnlocked then
		ClickBindingUI.SetHeroCardPreviewUnlocked(false)
	end
	if heroCardFrame then
		heroCardFrame:Hide()
	end
end

function ClickBindingUI.CheckAndShowHeroCard(resetDismissed)
	if resetDismissed then
		dismissedSignature = nil
	end

	if heroCardPreviewUnlocked then
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
	card.pendingUpdates = updates
	card.currentSignature = sig

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

function ClickBindingUI.ScheduleSmartRuleCheck(delaySeconds, resetDismissed)
	if resetDismissed then
		dismissedSignature = nil
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
function ClickBindingUI.PrepareSmartRuleTest()
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

local debugCopyFrame = nil

local function ShowDebugCopyPopup(reportText, customTitle)
	if not debugCopyFrame then
		local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		f:SetSize(520, 240)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(200)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true,
				tileSize = 32,
				edgeSize = 24,
				insets = { left = 6, right = 6, top = 6, bottom = 6 },
			})
		end

		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
		title:SetText("Better Click Casting Debug (Strg+C zum Kopieren)")
		f.Title = title

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

		local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -42)
		scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 16)

		local editBox = CreateFrame("EditBox", nil, scrollFrame)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		editBox:SetWidth(460)
		editBox:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		scrollFrame:SetScrollChild(editBox)
		f.EditBox = editBox
		debugCopyFrame = f
	end

	if debugCopyFrame.Title then
		debugCopyFrame.Title:SetText(customTitle or "Better Click Casting Debug (Ctrl+C to Copy)")
	end
	debugCopyFrame:Show()
	debugCopyFrame.EditBox:SetText(reportText or "")
	debugCopyFrame.EditBox:SetFocus()
	debugCopyFrame.EditBox:HighlightText()
end

-- Erzeugt eine kopierbare Text-Übersicht aller aktiven Klickbelegungen inkl. Taste, Zaubername, Rang, Manakosten und Smart-Regel (/bcc list).
function ClickBindingUI.ShowBindingsExportPopup()
	local bindings = {}
	if ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingFrame.dataProvider then
		for _, element in ClickBindingFrame.dataProvider:Enumerate() do
			if element and not element.unbound and element.bindingInfo and element.bindingInfo.button then
				table.insert(bindings, element.bindingInfo)
			end
		end
	elseif C_ClickBindings and C_ClickBindings.GetProfileInfo then
		local profile = C_ClickBindings.GetProfileInfo()
		if type(profile) == "table" then
			for _, info in ipairs(profile) do
				if info and info.button then
					table.insert(bindings, info)
				end
			end
		end
	end

	if #bindings == 0 then
		ShowDebugCopyPopup(L["EXPORT_EMPTY"], L["EXPORT_POPUP_TITLE"])
		return
	end

	table.sort(bindings, function(a, b)
		local pA = (a.type == Enum.ClickBindingType.Interaction and Database.Get("moveInteractionsToBottom")) and 2 or 1
		local pB = (b.type == Enum.ClickBindingType.Interaction and Database.Get("moveInteractionsToBottom")) and 2 or 1
		if pA ~= pB then
			return pA < pB
		end
		local modA = Constants.GetModifierSortInfo(a.modifiers)
		local modB = Constants.GetModifierSortInfo(b.modifiers)
		if modA ~= modB then
			return modA < modB
		end
		local btnA = Constants.GetButtonSortOrder(a.button)
		local btnB = Constants.GetButtonSortOrder(b.button)
		if btnA ~= btnB then
			return btnA < btnB
		end
		return tostring(a.actionID or 0) < tostring(b.actionID or 0)
	end)

	local playerName = Constants.GetPlayerDisplayName()
	local classLoc = (UnitClass and select(1, UnitClass("player"))) or ""
	local lines = {
		string.format("Better Click Casting v%s (%s, %s, %d Bindings)", Constants.VERSION, playerName, classLoc, #bindings),
		string.rep("=", 56),
	}

	for _, info in ipairs(bindings) do
		local shortBind = Constants.GetShortBindingString(info) or "?"
		local fullBind = Constants.GetFullBindingString(info) or shortBind
		local actionDesc = "?"
		local details = {}

		if Constants.IsSpellOrPetBinding(info) and info.actionID then
			local rankEntry = SpellRanks.GetRankEntryForAction(info.actionID)
			local baseName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(info.actionID) or tostring(info.actionID)
			local subtext = (rankEntry and rankEntry.subName) or SpellRanks.GetSpellSubtextForAction(info.actionID) or ""
			actionDesc = (subtext ~= "") and string.format("%s (%s)", baseName, subtext) or baseName

			if rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
				local maxEntry = rankEntry.group.maxEntry
				if not rankEntry.isLowRank then
					table.insert(details, "MAX")
				elseif maxEntry and maxEntry.subName and maxEntry.subName ~= "" then
					table.insert(details, string.format("Downrank / Max: %s", maxEntry.subName))
				end
			end

			local spellID = (rankEntry and rankEntry.spellID) or info.actionID
			local costStr = SpellRanks.GetSpellPowerCostString and SpellRanks.GetSpellPowerCostString(spellID)
			if costStr and costStr ~= "" then
				table.insert(details, costStr)
			end

			if Database.Get("enableSmartRankRules") and rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
				local ruleMode = SpellRanks.GetRuleForBinding and SpellRanks.GetRuleForBinding(info, rankEntry)
				if ruleMode then
					table.insert(details, GetRuleShortTag(ruleMode, not rankEntry.isLowRank))
				end
			end
		elseif info.type == Enum.ClickBindingType.Macro and info.actionID then
			local macroName = GetMacroInfo and select(1, GetMacroInfo(info.actionID))
			actionDesc = string.format("%s: %s", L["GROUP_HDR_MACROS"] or "Macro", macroName or tostring(info.actionID))
		elseif info.type == Enum.ClickBindingType.Interaction then
			if info.actionID == Enum.ClickBindingInteraction.Target then
				actionDesc = BINDING_NAME_TARGETSELF or "Target Unit"
			elseif info.actionID == Enum.ClickBindingInteraction.OpenContextMenu then
				actionDesc = HUD_EDIT_MODE_MENU or "Open Context Menu"
			elseif C_ClickBindings and C_ClickBindings.GetStringFromType then
				actionDesc = C_ClickBindings.GetStringFromType(info.type) or "Interaction"
			end
		end

		local detailSuffix = (#details > 0) and ("  [" .. table.concat(details, " | ") .. "]") or ""
		table.insert(lines, string.format("[%s] %s: %s%s", shortBind, fullBind, actionDesc, detailSuffix))
	end

	ShowDebugCopyPopup(table.concat(lines, "\n"), L["EXPORT_POPUP_TITLE"])
end

-- Öffnet das Kopier-Popup mit einem teilbaren !BCC1:...!-Export-String für "all", "bindings" oder "settings"
function ClickBindingUI.ShowExportStringPopup(scope)
	scope = (scope == "bindings" or scope == "settings") and scope or "all"
	local exportStr = Database.ExportToString(scope)
	local titleKey = "EXPORT_STRING_TITLE_ALL"
	if scope == "bindings" then
		titleKey = "EXPORT_STRING_TITLE_BINDINGS"
	elseif scope == "settings" then
		titleKey = "EXPORT_STRING_TITLE_SETTINGS"
	end
	ShowDebugCopyPopup(exportStr, L[titleKey] or L["EXPORT_POPUP_TITLE"])
end

-- Spielt eine Liste importierter/kopierter Klickbelegungen taintfrei in ClickBindingFrame.dataProvider ein
function ClickBindingUI.ApplyImportedBindings(importedBindings, mergeMode)
	if InCombatLockdown and InCombatLockdown() then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
		end
		return 0, 0, false
	end
	if type(importedBindings) ~= "table" then
		return 0, 0, false
	end

	if not ClickBindingFrame and ClickBindingFrame_LoadUI then
		ClickBindingFrame_LoadUI()
	end
	ClickBindingUI.SetupHooks()

	if ClickBindingFrame and not ClickBindingFrame:IsShown() then
		ClickBindingUI.EnsureSpellBookTabForClickBinding()
		if ToggleClickBindingFrame then
			ToggleClickBindingFrame()
		elseif ShowUIPanel then
			ShowUIPanel(ClickBindingFrame)
		end
	end

	if not ClickBindingFrame or not ClickBindingFrame.dataProvider then
		return 0, 0, false
	end

	SpellRanks.InvalidateCache()
	SpellRanks.EnsureCache()

	local resolvedCustom = {}
	local resolvedInteractions = {}
	local resolvedRules = {}
	local seenCombo = {}
	local appliedCount = 0
	local skippedCount = 0

	for _, entry in ipairs(importedBindings) do
		local bType = tonumber(entry.type) or 0
		local button = entry.button
		local modifiers = tonumber(entry.modifiers) or 0
		if bType > 0 and type(button) == "string" and button ~= "" then
			local comboKey = tostring(modifiers) .. ":" .. button
			if not seenCombo[comboKey] then
				if bType == Enum.ClickBindingType.Interaction then
					local actID = tonumber(entry.actionID) or 0
					if actID == Enum.ClickBindingInteraction.Target or actID == Enum.ClickBindingInteraction.OpenContextMenu then
						resolvedInteractions[actID] = {
							type = bType,
							actionID = actID,
							button = button,
							modifiers = modifiers,
						}
						seenCombo[comboKey] = true
						appliedCount = appliedCount + 1
					end
				elseif Constants.IsSpellOrPetBinding(entry) then
					local targetEntry, ruleMode = SpellRanks.ResolveImportedSpellBinding(entry)
					if targetEntry and targetEntry.actionID then
						local bindInfo = {
							type = bType,
							actionID = targetEntry.actionID,
							button = button,
							modifiers = modifiers,
						}
						table.insert(resolvedCustom, bindInfo)
						if ruleMode then
							table.insert(resolvedRules, { bindInfo = bindInfo, ruleMode = ruleMode, rankEntry = targetEntry })
						end
						seenCombo[comboKey] = true
						appliedCount = appliedCount + 1
					else
						skippedCount = skippedCount + 1
					end
				elseif bType == Enum.ClickBindingType.Macro then
					local macroIdx = nil
					if entry.macroName and entry.macroName ~= "" and GetMacroIndexByName then
						local idx = GetMacroIndexByName(entry.macroName)
						if idx and idx > 0 then
							macroIdx = idx
						end
					end
					if not macroIdx and entry.actionID and GetMacroInfo then
						local mName = GetMacroInfo(entry.actionID)
						if mName and mName ~= "" then
							macroIdx = entry.actionID
						end
					end
					if macroIdx and macroIdx > 0 then
						table.insert(resolvedCustom, {
							type = bType,
							actionID = macroIdx,
							button = button,
							modifiers = modifiers,
						})
						seenCombo[comboKey] = true
						appliedCount = appliedCount + 1
					else
						skippedCount = skippedCount + 1
					end
				end
			end
		end
	end

	if appliedCount == 0 then
		return 0, skippedCount, true
	end

	local provider = ClickBindingFrame.dataProvider
	local toRemove = {}

	for _, element in provider:Enumerate() do
		if element.elementType == ElementDataTypes.CustomsBinding then
			if not mergeMode then
				table.insert(toRemove, element)
			elseif element.bindingInfo and element.bindingInfo.button then
				local cKey = tostring( tonumber(element.bindingInfo.modifiers) or 0 ) .. ":" .. tostring(element.bindingInfo.button)
				if seenCombo[cKey] then
					table.insert(toRemove, element)
				end
			end
		elseif element.elementType == ElementDataTypes.InteractionBinding and element.bindingInfo then
			local actID = element.bindingInfo.actionID
			if resolvedInteractions[actID] then
				element.bindingInfo.button = resolvedInteractions[actID].button
				element.bindingInfo.modifiers = resolvedInteractions[actID].modifiers
				element.unbound = false
			elseif element.bindingInfo.button then
				local cKey = tostring( tonumber(element.bindingInfo.modifiers) or 0 ) .. ":" .. tostring(element.bindingInfo.button)
				if seenCombo[cKey] then
					element.bindingInfo.button = nil
					element.bindingInfo.modifiers = nil
					element.unbound = true
				end
			end
		end
	end

	if #toRemove > 0 then
		provider:Remove(unpack(toRemove))
	end

	for _, bindInfo in ipairs(resolvedCustom) do
		provider:Insert({
			elementType = ElementDataTypes.CustomsBinding,
			bindingInfo = bindInfo,
			unbound = false,
		})
	end

	for _, r in ipairs(resolvedRules) do
		SpellRanks.SetRuleForBinding(r.bindInfo, r.ruleMode, r.rankEntry)
	end

	if ClickBindingFrame.ClearUnboundText then
		ClickBindingFrame:ClearUnboundText()
	end
	ClickBindingFrame.pendingChanges = true
	SetSaveButtonGlowShown(true)
	ClickBindingUI.RebuildGroups()
	ClickBindingUI.RefreshVisibleLines()
	if SpellBookUI and SpellBookUI.RefreshBadges then
		SpellBookUI.RefreshBadges()
	end

	return appliedCount, skippedCount, true
end

-- Übernimmt Settings und/oder Keybinds direkt von einem gespeicherten Charakter-Profil
function ClickBindingUI.CopyFromCharacterProfile(charProfile, scope, mergeMode)
	if type(charProfile) ~= "table" then
		return false
	end
	scope = (scope == "bindings" or scope == "settings") and scope or "all"
	if mergeMode == nil then
		mergeMode = Database.Get("importMergeBindings")
	end

	local settingsCount = 0
	local appliedBindings = 0
	local skippedBindings = 0

	if (scope == "all" or scope == "settings") and type(charProfile.settings) == "table" then
		settingsCount = Database.ApplySettingsSnapshot(charProfile.settings)
	end

	if (scope == "all" or scope == "bindings") and type(charProfile.bindings) == "table" then
		local ok
		appliedBindings, skippedBindings, ok = ClickBindingUI.ApplyImportedBindings(charProfile.bindings, mergeMode)
		if not ok then
			return false
		end
	end

	if DEFAULT_CHAT_FRAME then
		local srcName = charProfile.name or charProfile.key or "?"
		if scope == "settings" then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_SETTINGS_FORMAT"], settingsCount, srcName))
		elseif scope == "bindings" then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_BINDINGS_FORMAT"], appliedBindings, srcName, skippedBindings))
		else
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_ALL_FORMAT"], settingsCount, appliedBindings, srcName, skippedBindings))
		end
	end
	return true
end

-- Verarbeitet einen eingefügten !BCC1:...!-Import-String für den gewünschten Umfang
function ClickBindingUI.ExecuteImportString(rawStr, scopeOverride, mergeOverride)
	local parsed, err = Database.ParseImportString(rawStr)
	if not parsed then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_IMPORT_ERR_INVALID"])
		end
		return false
	end

	local scope = scopeOverride or parsed.scope or "all"
	local mergeMode = (mergeOverride ~= nil) and mergeOverride or Database.Get("importMergeBindings")
	local settingsCount = 0
	local appliedBindings = 0
	local skippedBindings = 0

	if (scope == "all" or scope == "settings") and type(parsed.settings) == "table" then
		settingsCount = Database.ApplySettingsSnapshot(parsed.settings)
	end

	if (scope == "all" or scope == "bindings") and type(parsed.bindings) == "table" then
		local ok
		appliedBindings, skippedBindings, ok = ClickBindingUI.ApplyImportedBindings(parsed.bindings, mergeMode)
		if not ok then
			return false
		end
	end

	if settingsCount == 0 and appliedBindings == 0 then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_IMPORT_NOTHING_APPLIED_FORMAT"], skippedBindings))
		end
		return false
	end

	if DEFAULT_CHAT_FRAME then
		local srcName = (parsed.meta and parsed.meta.n and parsed.meta.n ~= "") and parsed.meta.n or "Import"
		if scope == "settings" or not parsed.bindings then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_SETTINGS_FORMAT"], settingsCount, srcName))
		elseif scope == "bindings" or not parsed.settings then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_BINDINGS_FORMAT"], appliedBindings, srcName, skippedBindings))
		else
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PROFILE_COPIED_ALL_FORMAT"], settingsCount, appliedBindings, srcName, skippedBindings))
		end
	end
	return true
end

local importPopupFrame = nil

function ClickBindingUI.ShowImportStringPopup(defaultScope)
	if not importPopupFrame then
		local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		f:SetSize(520, 270)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(210)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true,
				tileSize = 32,
				edgeSize = 24,
				insets = { left = 6, right = 6, top = 6, bottom = 6 },
			})
		end

		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
		f.Title = title

		local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		hint:SetTextColor(0.75, 0.75, 0.75)
		f.Hint = hint

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

		local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -54)
		scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 48)

		local editBox = CreateFrame("EditBox", nil, scrollFrame)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		editBox:SetWidth(460)
		editBox:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		scrollFrame:SetScrollChild(editBox)
		f.EditBox = editBox

		local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		importBtn:SetSize(160, 26)
		importBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
		importBtn:SetScript("OnClick", function()
			local raw = f.EditBox:GetText() or ""
			if ClickBindingUI.ExecuteImportString(raw, f.targetScope) then
				f:Hide()
			end
		end)
		f.ImportBtn = importBtn

		local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		cancelBtn:SetSize(130, 26)
		cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
		cancelBtn:SetText(CANCEL or "Cancel")
		cancelBtn:SetScript("OnClick", function()
			f:Hide()
		end)
		f.CancelBtn = cancelBtn

		importPopupFrame = f
	end

	importPopupFrame.targetScope = defaultScope
	importPopupFrame.Title:SetText(L["IMPORT_POPUP_TITLE"])
	importPopupFrame.Hint:SetText(L["IMPORT_POPUP_HINT"])
	importPopupFrame.ImportBtn:SetText(L["IMPORT_BTN_CONFIRM"])
	importPopupFrame:Show()
	importPopupFrame.EditBox:SetText("")
	importPopupFrame.EditBox:SetFocus()
end

-- Diagnose-Werkzeug (/bcc debug, /bcc debug taintlog):
-- Prüft mit Blizzards issecurevariable() sofort außerhalb des Kampfes, ob globale Highlight-Tabellen,
-- Aktionsleisten (inkl. PetActionBar), EditModeManagerFrame oder PlayerSpellsFrame getaintete Felder besitzen.
function ClickBindingUI.RunTaintDiagnostics(subArg)
	if not DEFAULT_CHAT_FRAME then
		return
	end
	if subArg == "taintlog" and SetCVar and GetCVar then
		local current = tostring(GetCVar("taintLog") or "0")
		local nextVal = (current == "0") and "1" or "0"
		SetCVar("taintLog", nextVal)
		DEFAULT_CHAT_FRAME:AddMessage("|cff40ff40Better Click Casting (Debug):|r CVar taintLog = " .. nextVal .. " (Log file: Logs/taint.log after Reload/Logout).")
		return
	end

	if not issecurevariable then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff4040Better Click Casting (Debug):|r issecurevariable is not available in this environment.")
		return
	end

	local findings = {}
	local function checkVar(tbl, key, label)
		if tbl == nil then
			return
		end
		local ok, taintSource = issecurevariable(tbl, key)
		if not ok then
			table.insert(findings, string.format("%s.%s (by %s)", label, tostring(key), tostring(taintSource or "unknown")))
		end
	end

	-- 1. Globale Highlight-Tabellen prüfen
	local okPetGlobal, srcPetGlobal = issecurevariable("PET_ACTION_HIGHLIGHT_MARKS")
	if not okPetGlobal then
		table.insert(findings, string.format("_G.PET_ACTION_HIGHLIGHT_MARKS (by %s)", tostring(srcPetGlobal or "unknown")))
	end
	local okBarGlobal, srcBarGlobal = issecurevariable("ON_BAR_HIGHLIGHT_MARKS")
	if not okBarGlobal then
		table.insert(findings, string.format("_G.ON_BAR_HIGHLIGHT_MARKS (by %s)", tostring(srcBarGlobal or "unknown")))
	end

	-- 2. Kritische Felder auf Aktionsleisten und EditMode-Systemen prüfen
	local bars = {
		{ frame = _G.PetActionBar, name = "PetActionBar" },
		{ frame = _G.MainActionBar, name = "MainActionBar" },
		{ frame = _G.MultiBarBottomLeft, name = "MultiBarBottomLeft" },
		{ frame = _G.MultiBarBottomRight, name = "MultiBarBottomRight" },
		{ frame = _G.MultiBarRight, name = "MultiBarRight" },
		{ frame = _G.MultiBarLeft, name = "MultiBarLeft" },
		{ frame = _G.StanceBar, name = "StanceBar" },
		{ frame = _G.PossessActionBar, name = "PossessActionBar" },
	}
	local barKeys = {
		"isShownExternal",
		"visibility",
		"editModeForceShow",
		"showAllButtons",
		"snappedToFrame",
		"snappedFrames",
		"flyoutDirection",
		"rangeTimer",
		"mode",
		"completed",
		"slideTimer",
		"SetShownBase",
		"HideBase",
		"ShowBase",
	}

	for _, entry in ipairs(bars) do
		local bar = entry.frame
		if bar then
			for _, k in ipairs(barKeys) do
				if bar[k] ~= nil then
					checkVar(bar, k, entry.name)
				end
			end
			if type(bar.snappedFrames) == "table" then
				for snapKey in pairs(bar.snappedFrames) do
					-- issecurevariable akzeptiert nur String-Keys; da AddSnappedFrame() immer zusammen mit
					-- snapKey.snappedToFrame = frame läuft, prüfen wir zusätzlich den String-Key auf dem Ziel-Frame.
					if type(snapKey) == "string" then
						local okSnap, srcSnap = issecurevariable(bar.snappedFrames, snapKey)
						if not okSnap then
							table.insert(findings, string.format("%s.snappedFrames[%s] (by %s)", entry.name, snapKey, tostring(srcSnap or "unknown")))
						end
					elseif type(snapKey) == "table" then
						local okSnapTo, srcSnapTo = issecurevariable(snapKey, "snappedToFrame")
						if not okSnapTo then
							local snapName = (snapKey.GetName and snapKey:GetName()) or tostring(snapKey)
							table.insert(findings, string.format("%s.snappedFrames->%s.snappedToFrame (by %s)", entry.name, snapName, tostring(srcSnapTo or "unknown")))
						end
					end
				end
			end
		end
	end

	-- 3. EditModeManagerFrame, UnitFrames, PlayerSpellsFrame und SpellBookFrame prüfen
	if _G.EditModeManagerFrame then
		checkVar(_G.EditModeManagerFrame, "layoutApplyInProgress", "EditModeManagerFrame")
	end
	local unitFramesToCheck = {
		{ name = "PlayerFrame", frame = _G.PlayerFrame },
		{ name = "TargetFrame", frame = _G.TargetFrame },
		{ name = "FocusFrame", frame = _G.FocusFrame },
		{ name = "CompactPartyFrameMember1", frame = _G.CompactPartyFrameMember1 },
	}
	for _, ufEntry in ipairs(unitFramesToCheck) do
		if ufEntry.frame then
			if ufEntry.frame.unit ~= nil then
				checkVar(ufEntry.frame, "unit", ufEntry.name)
			end
			if ufEntry.frame.displayedUnit ~= nil then
				checkVar(ufEntry.frame, "displayedUnit", ufEntry.name)
			end
		end
	end
	local infoNotes = {}
	if _G.PlayerSpellsFrame then
		checkVar(_G.PlayerSpellsFrame, "isMinimized", "PlayerSpellsFrame")
		checkVar(_G.PlayerSpellsFrame, "minimizedOnNextShow", "PlayerSpellsFrame")
		local sbFrame = _G.PlayerSpellsFrame.SpellBookFrame
		if sbFrame then
			local sbKeys = { "spellDataDirty", "isUpdatingAllSpellData", "categoryMixins" }
			for _, k in ipairs(sbKeys) do
				if sbFrame[k] ~= nil then
					checkVar(sbFrame, k, "SpellBookFrame")
				end
			end
			if sbFrame.lastActiveTabID ~= nil then
				local okTab, srcTab = issecurevariable(sbFrame, "lastActiveTabID")
				if not okTab then
					table.insert(infoNotes, string.format("SpellBookFrame.lastActiveTabID (by %s, harmless)", tostring(srcTab or "unknown")))
				end
			end
			if sbFrame.PagedSpellsFrame and sbFrame.PagedSpellsFrame.EnumerateFrames then
				local taintedItems = 0
				local shieldedItems = 0
				local firstTaintSource = nil
				for _, itemFrame in sbFrame.PagedSpellsFrame:EnumerateFrames() do
					if itemFrame and itemFrame.elementData ~= nil then
						local okElem, srcElem = issecurevariable(itemFrame, "elementData")
						if not okElem then
							taintedItems = taintedItems + 1
							if itemFrame.BCCQuickBindButton and itemFrame.BCCQuickBindButton:IsShown() then
								shieldedItems = shieldedItems + 1
							end
							firstTaintSource = firstTaintSource or srcElem
						end
					end
				end
				if taintedItems > 0 then
					local itemSummary = string.format("SpellBookFrame.PagedSpellsFrame: %d item(s) with tainted elementData (%d shielded by overlay, by %s)", taintedItems, shieldedItems, tostring(firstTaintSource or "unknown"))
					if shieldedItems < taintedItems then
						table.insert(findings, itemSummary)
					else
						table.insert(infoNotes, itemSummary)
					end
				end
			end
		end
	end

	local taintLogVal = (GetCVar and GetCVar("taintLog")) or "0"
	local reportLines = {}
	if #findings == 0 then
		local okMsg = string.format("0 critical taints found on PetActionBar, ActionBars, EditModeManagerFrame, and highlight globals! (taintLog=%s)", tostring(taintLogVal))
		DEFAULT_CHAT_FRAME:AddMessage("|cff40ff40Better Click Casting (Debug):|r " .. okMsg)
		table.insert(reportLines, okMsg)
		for _, note in ipairs(infoNotes) do
			DEFAULT_CHAT_FRAME:AddMessage("  |cff80c0ff• Info:|r " .. note)
			table.insert(reportLines, "- Info: " .. note)
		end
	else
		local headerMsg = string.format("%d tainted field(s) found (taintLog=%s):", #findings, tostring(taintLogVal))
		DEFAULT_CHAT_FRAME:AddMessage("|cffff4040Better Click Casting (Debug):|r " .. headerMsg)
		table.insert(reportLines, headerMsg)
		for _, line in ipairs(findings) do
			DEFAULT_CHAT_FRAME:AddMessage("  |cffffb833•|r " .. line)
			table.insert(reportLines, "- " .. line)
		end
		for _, note in ipairs(infoNotes) do
			DEFAULT_CHAT_FRAME:AddMessage("  |cff80c0ff• Info:|r " .. note)
			table.insert(reportLines, "- Info: " .. note)
		end
	end

	local fullReport = table.concat(reportLines, "\n")
	if type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.lastDebugReport = fullReport
	end
	if #findings > 0 or subArg == "copy" then
		ShowDebugCopyPopup(fullReport)
	end
end

--------------------------------------------------------------------------------
-- Zauberbuch-Sync und Hooks
--------------------------------------------------------------------------------

function ClickBindingUI.EnsureSpellBookTabForClickBinding()
	if InCombatLockdown and InCombatLockdown() then
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
	-- In WoW Forever teilen sich Zauberbuch (area = "centerOrLeft") und Talentbaum (area = "center")
	-- denselben PlayerSpellsFrame. Wurde zuvor der Talentbaum geöffnet, muss vor ShowUIPanel(PlayerSpellsFrame)
	-- zurück auf den SpellBook-Tab gewechselt werden, da ShowUIPanel mit area = "center" sonst CloseWindows()
	-- ausführt und das ClickBindingFrame sofort wieder schließt.
	if PlayerSpellsFrame.IsFrameTabActive and not PlayerSpellsFrame:IsFrameTabActive(spellBookTab) then
		if PlayerSpellsFrame:IsShown() and HideUIPanel then
			HideUIPanel(PlayerSpellsFrame)
		end
		if PlayerSpellsFrame.TrySetTab then
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

	-- 0. Settings-Button im ClickBindingFrame einrichten
	if SettingsUI and SettingsUI.AttachToClickBindingFrame then
		SettingsUI.AttachToClickBindingFrame()
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
		ClickBindingUI.HideHeroCard()
		ClickBindingUI.SyncAutoShowAllRanks()
		ClickBindingUI.AutoSelectPrimarySpellBookTab()
		ClickBindingUI.RebuildGroups()
		if SpellBookUI and SpellBookUI.RefreshBadges then
			SpellBookUI.RefreshBadges()
		end
	end)

	ClickBindingFrame:HookScript("OnHide", function()
		SetSaveButtonGlowShown(false)
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

	if ClickBindingFrame.SaveButton and not ClickBindingFrame.SaveButton._bccSnapshotHooked then
		ClickBindingFrame.SaveButton:HookScript("OnClick", function()
			if C_Timer and C_Timer.After and Database and Database.SaveCharacterSnapshot then
				C_Timer.After(0.1, Database.SaveCharacterSnapshot)
			end
		end)
		ClickBindingFrame.SaveButton._bccSnapshotHooked = true
	end

	if ClickBindingFrame.CleanDataProvider then
		hooksecurefunc(ClickBindingFrame, "CleanDataProvider", function()
			ClickBindingUI.RebuildGroups()
		end)
	end

	if ClickBindingFrame.ResetToDefaultProfile then
		hooksecurefunc(ClickBindingFrame, "ResetToDefaultProfile", function()
			SetSaveButtonGlowShown(false)
			ClickBindingUI.RebuildGroups()
		end)
	end

	-- Falls ClickBindingFrame beim erstmaligen Laden bereits offen ist, sofort synchronisieren
	if ClickBindingFrame:IsShown() then
		ClickBindingUI.HideHeroCard()
		ClickBindingUI.SyncAutoShowAllRanks()
		ClickBindingUI.AutoSelectPrimarySpellBookTab()
		ClickBindingUI.RebuildGroups()
		ClickBindingUI.RefreshVisibleLines()
	end

	-- 4. Warnmeldung beim Überschreiben einer Taste ebenfalls mit Zauberrang versehen
	if ClickBindingFrame.SetUnboundText and CLICK_BINDING_UNBOUND_OUTPUT then
		hooksecurefunc(ClickBindingFrame, "SetUnboundText", function(self, elementData)
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
		end, ns)
	end
end
