local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Colors = Constants.Colors
local ElementDataTypes = Constants.ElementDataTypes
local Database = ns.Database
local SpellRanks = ns.SpellRanks
local SpellBookUI = ns.SpellBookUI
local SettingsUI = ns.SettingsUI
local ClickBindingUI = ns.ClickBindingUI

local PresetsAndImportUI = {}
ns.PresetsAndImportUI = PresetsAndImportUI

local GetRuleShortTag = ClickBindingUI.GetRuleShortTag
local SetSaveButtonGlowShown = ClickBindingUI.SetSaveButtonGlowShown

local presetDropdownButton = nil
local pendingActivePresetName = nil
local lastHiddenPendingPresetName = nil

local function OnClickBindingFrameHidePendingPreset()
	-- Blizzards SaveButton:OnClick ruft zuerst HideUIPanel(ClickBindingFrame) (= OnHide) auf,
	-- bevor unser SaveButton-Post-Hook läuft. Deshalb puffern wir pendingActivePresetName für
	-- genau diesen synchronen Klick-Frame in lastHiddenPendingPresetName und leeren es per Timer(0).
	if pendingActivePresetName then
		lastHiddenPendingPresetName = pendingActivePresetName
		pendingActivePresetName = nil
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				lastHiddenPendingPresetName = nil
			end)
		end
	end
end

local function CommitPendingPresetOnSave()
	local committedName = pendingActivePresetName or lastHiddenPendingPresetName
	if committedName then
		Database.SetActivePresetName(committedName)
		pendingActivePresetName = nil
		lastHiddenPendingPresetName = nil
		ClickBindingUI.UpdatePresetDropdownButton()
		if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
			ns.SettingsUI.RefreshWindow()
		end
	end
end

function PresetsAndImportUI.GetEffectiveActivePresetName()
	if pendingActivePresetName and pendingActivePresetName ~= "" then
		return pendingActivePresetName
	end
	return Database.GetActivePresetName and Database.GetActivePresetName() or nil
end

local debugCopyFrame = nil
local importPopupFrame = nil
local newPresetPopupFrame = nil

local function ShowDebugCopyPopup(reportText, customTitle, coloredReportText)
	if not debugCopyFrame then
		local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		f:SetSize(680, 440)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(200)
		f:SetClampedToScreen(true)
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
			f:SetBackdropColor(0.05, 0.06, 0.09, 0.97)
			f:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
		end

		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
		title:SetText("Better Click Casting Debug")
		f.Title = title

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
		closeBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			f:Hide()
		end)

		local consoleBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
		consoleBg:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
		consoleBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 46)
		if consoleBg.SetBackdrop then
			consoleBg:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 8,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			consoleBg:SetBackdropColor(0.03, 0.04, 0.06, 0.96)
			consoleBg:SetBackdropBorderColor(0.35, 0.42, 0.55, 0.85)
		end
		f.ConsoleBg = consoleBg

		local scrollFrame = CreateFrame("ScrollFrame", nil, consoleBg, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", consoleBg, "TOPLEFT", 10, -8)
		scrollFrame:SetPoint("BOTTOMRIGHT", consoleBg, "BOTTOMRIGHT", -28, 8)
		f.ScrollFrame = scrollFrame

		local editBox = CreateFrame("EditBox", nil, scrollFrame)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		editBox:SetWidth(604)
		editBox:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		scrollFrame:SetScrollChild(editBox)
		f.EditBox = editBox

		local modeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		modeBtn:SetSize(210, 26)
		modeBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
		modeBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			f.plainCopyMode = not f.plainCopyMode
			if f.plainCopyMode then
				f.EditBox:SetText(f.plainReportText or "")
				f.EditBox:SetFocus()
				f.EditBox:HighlightText()
				f.ModeBtn:SetText("Back to Console View")
			else
				f.EditBox:SetText(f.coloredReportText or f.plainReportText or "")
				f.EditBox:ClearFocus()
				f.ModeBtn:SetText("Compact Report (Ctrl+C)")
			end
			if f.ScrollFrame and f.ScrollFrame.SetVerticalScroll then
				f.ScrollFrame:SetVerticalScroll(0)
			end
		end)
		f.ModeBtn = modeBtn

		local closeFooterBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		closeFooterBtn:SetSize(120, 26)
		closeFooterBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
		closeFooterBtn:SetText(CLOSE or "Close")
		closeFooterBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			f:Hide()
		end)
		f.CloseFooterBtn = closeFooterBtn

		debugCopyFrame = f
	end

	local isConsoleReport = (type(coloredReportText) == "string" and coloredReportText ~= "")
	if isConsoleReport then
		debugCopyFrame:SetSize(680, 440)
		debugCopyFrame.EditBox:SetWidth(604)
		debugCopyFrame.ModeBtn:Show()
	else
		debugCopyFrame:SetSize(560, 280)
		debugCopyFrame.EditBox:SetWidth(484)
		debugCopyFrame.ModeBtn:Hide()
	end

	debugCopyFrame.plainReportText = reportText or ""
	debugCopyFrame.coloredReportText = coloredReportText
	debugCopyFrame.plainCopyMode = not isConsoleReport

	if debugCopyFrame.Title then
		debugCopyFrame.Title:SetText(customTitle or "Better Click Casting Debug (Ctrl+C to Copy)")
	end
	debugCopyFrame:Show()
	if debugCopyFrame.Raise then
		debugCopyFrame:Raise()
	end
	if isConsoleReport then
		debugCopyFrame.EditBox:SetText(coloredReportText)
		debugCopyFrame.EditBox:ClearFocus()
		debugCopyFrame.ModeBtn:SetText("Compact Report (Ctrl+C)")
	else
		debugCopyFrame.EditBox:SetText(reportText or "")
		debugCopyFrame.EditBox:SetFocus()
		debugCopyFrame.EditBox:HighlightText()
	end
	if debugCopyFrame.ScrollFrame and debugCopyFrame.ScrollFrame.SetVerticalScroll then
		debugCopyFrame.ScrollFrame:SetVerticalScroll(0)
	end
end

-- Erzeugt eine kopierbare Text-Übersicht aller aktiven Klickbelegungen inkl. Taste, Zaubername, Rang, Manakosten und Smart-Regel (/bcc list).
function PresetsAndImportUI.ShowBindingsExportPopup()
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

	local freeKeysList = ClickBindingUI.GetFreeKeysSummaryList and ClickBindingUI.GetFreeKeysSummaryList(bindings) or {}
	if #freeKeysList > 0 then
		table.insert(lines, "")
		table.insert(lines, string.format("%s (%d): %s", L["FREE_KEYS_SUMMARY_PREFIX"] or "Free Slots (4x5 Grid)", #freeKeysList, table.concat(freeKeysList, ", ")))
	end

	ShowDebugCopyPopup(table.concat(lines, "\n"), L["EXPORT_POPUP_TITLE"])
end

-- Öffnet das Kopier-Popup mit einem teilbaren !BCC1:...!-Export-String für "all", "bindings" oder "settings"
function PresetsAndImportUI.ShowExportStringPopup(scope)
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

-- Spielt eine Liste importierter/kopierter Klickbelegungen taintfrei in ClickBindingFrame.dataProvider ein.
-- keepUnlearnedSpells = true (für eigene Charakter-Presets bei Dual-Spec) behält Talent-Zauber mit gültiger actionID
-- auch dann in der Liste (als [NOT LEARNED]), wenn das Talent im aktuell aktiven Spec gerade nicht geskillt ist.
function PresetsAndImportUI.ApplyImportedBindings(importedBindings, mergeMode, keepUnlearnedSpells)
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
					elseif keepUnlearnedSpells and tonumber(entry.actionID) and tonumber(entry.actionID) > 0 then
						-- Dual-Spec-Erhalt: Eigene Talent-Zauber des anderen Specs (wie Penance / Power Infusion)
						-- behalten ihre gespeicherte actionID, damit sie nach dem Spec-Wechsel sofort wieder aktiv sind.
						local rawActID = tonumber(entry.actionID)
						local bindInfo = {
							type = bType,
							actionID = rawActID,
							button = button,
							modifiers = modifiers,
						}
						table.insert(resolvedCustom, bindInfo)
						if entry.ruleMode then
							table.insert(resolvedRules, { bindInfo = bindInfo, ruleMode = entry.ruleMode, rankEntry = nil })
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
function PresetsAndImportUI.CopyFromCharacterProfile(charProfile, scope, mergeMode)
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
function PresetsAndImportUI.ExecuteImportString(rawStr, scopeOverride, mergeOverride)
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

function PresetsAndImportUI.ShowImportStringPopup(defaultScope)
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
		closeBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			f:Hide()
		end)

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

--------------------------------------------------------------------------------
-- Charakter-spezifische Binding-Presets (Loadouts) & Schnellwahl im ClickBindingFrame
--------------------------------------------------------------------------------

function PresetsAndImportUI.SavePresetByName(rawName)
	local preset, count = Database.SavePreset(rawName)
	if not preset then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_PRESET_ERR_EMPTY_NAME"])
		end
		return false, nil
	end
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_SAVED_FORMAT"], preset.name, count or 0))
	end
	return true, preset
end

function PresetsAndImportUI.LoadPreset(presetOrName)
	local preset = (type(presetOrName) == "table") and presetOrName or Database.FindPreset(presetOrName)
	if not preset or type(preset.bindings) ~= "table" then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_NOT_FOUND_FORMAT"], tostring(presetOrName or "")))
		end
		return false
	end

	-- Ein eigenes Charakter-Preset ersetzt die aktuelle Liste vollständig (mergeMode = false)
	-- und behält auch aktuell nicht gelernte Dual-Spec-Talent-Zauber (keepUnlearnedSpells = true).
	local appliedCount, skippedCount, ok = ClickBindingUI.ApplyImportedBindings(preset.bindings, false, true)
	if not ok then
		return false
	end

	-- Das geladene Preset zunächst nur als Vorschau (pendingActivePresetName) merken und erst
	-- beim echten Hardware-Klick auf Blizzards Speichern-Button dauerhaft in die DB übernehmen.
	-- Bei einem temporären In-Memory-Demo-Preset (/bcc test spec) wird nichts vorgemerkt.
	if not preset._bccIsDemoTest then
		pendingActivePresetName = preset.name
		lastHiddenPendingPresetName = nil
		ClickBindingUI.UpdatePresetDropdownButton()
		if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
			ns.SettingsUI.RefreshWindow()
		end
	end

	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_LOADED_FORMAT"], preset.name, appliedCount or 0, skippedCount or 0))
	end
	return true
end

function PresetsAndImportUI.DeletePresetByName(name)
	local ok, deletedKey = Database.DeletePreset(name)
	if not ok then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_NOT_FOUND_FORMAT"], tostring(name or "")))
		end
		return false
	end
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["CHAT_PRESET_DELETED_FORMAT"], deletedKey or tostring(name)))
	end
	return true
end

function PresetsAndImportUI.ShowNewPresetPopup(initialName, onSavedCallback)
	if not newPresetPopupFrame then
		local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		f:SetSize(390, 150)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetFrameLevel(250)
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
		hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
		hint:SetPoint("RIGHT", f, "RIGHT", -16, 0)
		hint:SetJustifyH("LEFT")
		hint:SetTextColor(0.80, 0.80, 0.80)
		f.Hint = hint

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
		closeBtn:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			f:Hide()
		end)

		local inputBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
		inputBg:SetSize(354, 28)
		inputBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -62)
		if inputBg.SetBackdrop then
			inputBg:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			inputBg:SetBackdropColor(0.05, 0.06, 0.08, 0.95)
			inputBg:SetBackdropBorderColor(0.55, 0.55, 0.60, 1.0)
		end

		local editBox = CreateFrame("EditBox", nil, inputBg)
		editBox:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 8, -4)
		editBox:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -8, 4)
		editBox:SetAutoFocus(false)
		editBox:SetMaxLetters(40)
		editBox:SetFontObject(ChatFontNormal or GameFontHighlight)
		editBox:SetScript("OnEscapePressed", function()
			f:Hide()
		end)
		editBox:SetScript("OnEnterPressed", function(self)
			local ok, savedPreset = ClickBindingUI.SavePresetByName(self:GetText() or "")
			if ok then
				if f.onSavedCallback then
					f.onSavedCallback(savedPreset)
				end
				f:Hide()
			end
		end)
		f.EditBox = editBox

		local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		saveBtn:SetSize(150, 26)
		saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
		saveBtn:SetScript("OnClick", function()
			local ok, savedPreset = ClickBindingUI.SavePresetByName(f.EditBox:GetText() or "")
			if ok then
				if f.onSavedCallback then
					f.onSavedCallback(savedPreset)
				end
				f:Hide()
			end
		end)
		f.SaveBtn = saveBtn

		local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		cancelBtn:SetSize(130, 26)
		cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
		cancelBtn:SetText(CANCEL or "Cancel")
		cancelBtn:SetScript("OnClick", function()
			f:Hide()
		end)
		f.CancelBtn = cancelBtn

		newPresetPopupFrame = f
	end

	newPresetPopupFrame.onSavedCallback = onSavedCallback
	newPresetPopupFrame.Title:SetText(L["PRESET_POPUP_NEW_TITLE"])
	newPresetPopupFrame.Hint:SetText(L["PRESET_POPUP_NEW_HINT"])
	newPresetPopupFrame.SaveBtn:SetText(L["PRESET_POPUP_BTN_SAVE"])
	newPresetPopupFrame:Show()
	newPresetPopupFrame.EditBox:SetText(type(initialName) == "string" and initialName or "")
	newPresetPopupFrame.EditBox:SetFocus()
	newPresetPopupFrame.EditBox:HighlightText()
end

local function UpdatePresetDropdownAnchor(btn)
	if not btn or not ClickBindingFrame then
		return
	end
	btn:ClearAllPoints()
	local mouseoverDropShown = ClickBindingFrame.MouseoverCastKeyDropdown and ClickBindingFrame.MouseoverCastKeyDropdown:IsShown()
	if mouseoverDropShown and ClickBindingFrame.PlayerSpellsPortrait then
		btn:SetSize(150, 20)
		btn:SetPoint("TOPRIGHT", ClickBindingFrame.PlayerSpellsPortrait, "BOTTOMRIGHT", 0, -6)
	elseif ClickBindingFrame.EnableMouseoverCastCheckbox then
		btn:SetSize(172, 20)
		btn:SetPoint("TOPLEFT", ClickBindingFrame.EnableMouseoverCastCheckbox, "BOTTOMLEFT", 4, -2)
	else
		btn:SetSize(165, 20)
		btn:SetPoint("TOPLEFT", ClickBindingFrame, "TOPLEFT", 64, -58)
	end
end

local function EnsurePresetDropdownButton()
	if not ClickBindingFrame then
		return nil
	end
	if presetDropdownButton then
		if not Constants.IsGamepadUIActive() and presetDropdownButton:GetParent() ~= ClickBindingFrame then
			presetDropdownButton:SetParent(ClickBindingFrame)
		end
		return presetDropdownButton
	end

	local btn = CreateFrame("Button", nil, ClickBindingFrame)
	btn:SetSize(172, 20)
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
		if ns.SettingsUI and ns.SettingsUI.OpenPresetMenu then
			ns.SettingsUI.OpenPresetMenu(self)
		end
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["PRESET_TOOLTIP_TITLE"])
		GameTooltip_AddNormalLine(GameTooltip, L["PRESET_TOOLTIP_DESC"], true)
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	presetDropdownButton = btn
	UpdatePresetDropdownAnchor(btn)
	return btn
end

function PresetsAndImportUI.UpdatePresetDropdownButton()
	if not ClickBindingFrame then
		return
	end
	if Constants.IsGamepadUIActive() then
		if presetDropdownButton then
			presetDropdownButton:Hide()
			presetDropdownButton:SetParent(nil)
		end
		return
	end
	local btn = EnsurePresetDropdownButton()
	if not btn then
		return
	end
	UpdatePresetDropdownAnchor(btn)
	local activeName = ClickBindingUI.GetEffectiveActivePresetName()
	local labelStr = (activeName and activeName ~= "") and activeName or L["PRESET_NONE_SELECTED"]
	btn.Text:SetText(string.format(L["PRESET_BUTTON_FORMAT"], labelStr))
	btn:Show()
end

PresetsAndImportUI.ShowCopyPopup = ShowDebugCopyPopup
PresetsAndImportUI.OnClickBindingFrameHidePendingPreset = OnClickBindingFrameHidePendingPreset
PresetsAndImportUI.CommitPendingPresetOnSave = CommitPendingPresetOnSave

function PresetsAndImportUI.ClearPendingPresetState()
	pendingActivePresetName = nil
	lastHiddenPendingPresetName = nil
end

function PresetsAndImportUI.SetPendingPresetForTest(presetName)
	pendingActivePresetName = presetName
	lastHiddenPendingPresetName = nil
end

function PresetsAndImportUI.GetPresetDropdownButton()
	return presetDropdownButton
end

function PresetsAndImportUI.HidePopups()
	if newPresetPopupFrame and newPresetPopupFrame:IsShown() then
		newPresetPopupFrame:Hide()
	end
	if importPopupFrame and importPopupFrame:IsShown() then
		importPopupFrame:Hide()
	end
	if debugCopyFrame and debugCopyFrame:IsShown() then
		debugCopyFrame:Hide()
	end
end

-- Kompatible Fassade auf ns.ClickBindingUI beibehalten
for k, fn in pairs(PresetsAndImportUI) do
	if type(fn) == "function" and k ~= "GetPresetDropdownButton" and k ~= "HidePopups" and k ~= "SetPendingPresetForTest" then
		ClickBindingUI[k] = fn
	end
end
