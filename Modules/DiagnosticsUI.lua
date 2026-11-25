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
local HeroCardUI = ns.HeroCardUI
local FreeKeysMatrixUI = ns.FreeKeysMatrixUI
local PresetsAndImportUI = ns.PresetsAndImportUI

local DiagnosticsUI = {}
ns.DiagnosticsUI = DiagnosticsUI

local SetSaveButtonGlowShown = ClickBindingUI.SetSaveButtonGlowShown
local ShowDebugCopyPopup = PresetsAndImportUI.ShowCopyPopup

-- Rein lesender Mitschnitt bei ADDON_ACTION_BLOCKED für BetterClickCasting:
-- Erfasst den exakten Laufzeit-Zustand (Combat, alle 6 C_RestrictedActions-Flags, Taint-Status von
-- dataProvider/SaveButton, SpellBook-Tab und aktives Preset) in BetterClickCastingDB.lastDebugReport.
function DiagnosticsUI.CaptureBlockedActionDiagnostics(blockedAddon, blockedFunc, silent)
	if blockedAddon ~= Constants.ADDON_NAME and blockedAddon ~= "BetterClickCasting" then
		return nil
	end
	local inCombat = (InCombatLockdown and InCombatLockdown()) and 1 or 0
	local uac = (UnitAffectingCombat and UnitAffectingCombat("player")) and 1 or 0
	local restrParts = {}
	for rIdx = 0, 5 do
		local active = 0
		if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
			local ok, val = pcall(C_RestrictedActions.IsAddOnRestrictionActive, rIdx)
			if ok and val then
				active = 1
			end
		end
		table.insert(restrParts, tostring(active))
	end
	local cbShown = (ClickBindingFrame and ClickBindingFrame:IsShown()) and 1 or 0
	local pending = (ClickBindingFrame and ClickBindingFrame.pendingChanges) and 1 or 0
	local dpSec, dpTaint = "nil", "nil"
	local sbSec, sbTaint = "nil", "nil"
	local dpCount = 0
	if ClickBindingFrame then
		if issecurevariable then
			local s1, t1 = issecurevariable(ClickBindingFrame, "dataProvider")
			dpSec, dpTaint = s1 and "1" or "0", tostring(t1 or "secure")
			local s2, t2 = issecurevariable(ClickBindingFrame, "SaveButton")
			sbSec, sbTaint = s2 and "1" or "0", tostring(t2 or "secure")
		end
		if ClickBindingFrame.dataProvider and ClickBindingFrame.dataProvider.GetSize then
			dpCount = ClickBindingFrame.dataProvider:GetSize() or 0
		end
	end
	local psShown = (PlayerSpellsFrame and PlayerSpellsFrame:IsShown()) and 1 or 0
	local psTab = (PlayerSpellsFrame and PlayerSpellsFrame.GetTab and tostring(PlayerSpellsFrame:GetTab() or "nil")) or "nil"
	local gp = Constants.IsGamepadUIActive() and 1 or 0
	local preset = ClickBindingUI.GetEffectiveActivePresetName() or "none"

	local line = string.format(
		"BCCBLOCK|v%s|fn=%s|c=%d,uac=%d|r=%s|cb=%d,pend=%d,dp=%s/%s,sb=%s/%s,n=%d|ps=%d,tab=%s|gp=%d|preset=%s",
		tostring(Constants.VERSION or "?"),
		tostring(blockedFunc or "?"),
		inCombat,
		uac,
		table.concat(restrParts, ","),
		cbShown,
		pending,
		dpSec,
		dpTaint,
		sbSec,
		sbTaint,
		dpCount,
		psShown,
		psTab,
		gp,
		tostring(preset)
	)

	if not silent then
		if BetterClickCastingDB then
			BetterClickCastingDB.lastDebugReport = line
		end
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Better Click Casting:|r " .. line)
		end
	end
	return line
end

local function ExtractFormatSignature(str)
	if type(str) ~= "string" then
		return ""
	end
	local cleaned = string.gsub(str, "%%%%", "")
	local specs = {}
	for spec in string.gmatch(cleaned, "%%[%d%.]*[sdfoxXegGcpuq]") do
		table.insert(specs, spec)
	end
	return table.concat(specs, ",")
end

local function RunDeepStressSelfTest(findings, infoNotes)
	-- 1. Lokalisierungs- und Format-String-Integrität über enUS, deDE und esES prüfen
	if type(ns.Locales) == "table" and type(ns.Locales["enUS"]) == "table" then
		local enTbl = ns.Locales["enUS"]
		local enCount = 0
		for _ in pairs(enTbl) do
			enCount = enCount + 1
		end
		for _, locCode in ipairs({ "deDE", "esES" }) do
			local locTbl = ns.Locales[locCode]
			if type(locTbl) ~= "table" then
				table.insert(findings, string.format("DeepTest Locale: missing table for %s", locCode))
			else
				local locCount = 0
				local missingKeys = 0
				local extraKeys = 0
				local sigMismatches = 0
				for k, v in pairs(locTbl) do
					locCount = locCount + 1
					if enTbl[k] == nil then
						extraKeys = extraKeys + 1
					elseif ExtractFormatSignature(v) ~= ExtractFormatSignature(enTbl[k]) then
						sigMismatches = sigMismatches + 1
						table.insert(findings, string.format("DeepTest Locale format mismatch in %s[%s]: '%s' vs enUS '%s'", locCode, tostring(k), ExtractFormatSignature(v), ExtractFormatSignature(enTbl[k])))
					end
				end
				for k in pairs(enTbl) do
					if locTbl[k] == nil then
						missingKeys = missingKeys + 1
					end
				end
				if missingKeys > 0 or extraKeys > 0 then
					table.insert(findings, string.format("DeepTest Locale key mismatch in %s: count=%d (enUS=%d, missing=%d, extra=%d)", locCode, locCount, enCount, missingKeys, extraKeys))
				elseif sigMismatches == 0 then
					table.insert(infoNotes, string.format("DeepTest Locale %s: %d/%d keys & format strings verified OK", locCode, locCount, enCount))
				end
			end
		end
	end

	-- 2. Export-/Import-Roundtrip (!BCC1:...!) für alle DEFAULTS und Bindings prüfen
	if Database and Database.ExportToString and Database.ParseImportString and Database.GetDefaults then
		local exportAll = Database.ExportToString("all")
		local parsed, err = Database.ParseImportString(exportAll)
		if not parsed or err then
			table.insert(findings, string.format("DeepTest Export/Import roundtrip failed: %s", tostring(err or "nil")))
		else
			local defaults = Database.GetDefaults()
			local verifiedKeys = 0
			for k in pairs(defaults) do
				if k ~= "importMergeBindings" then
					local expected = Database.Get(k)
					local actual = parsed.settings and parsed.settings[k]
					local isMatch = (actual == expected)
					if not isMatch and type(expected) == "number" and type(actual) == "number" then
						isMatch = (tonumber(tostring(expected)) == actual) or (math.abs(actual - expected) < 0.0001)
					end
					if not isMatch then
						table.insert(findings, string.format("DeepTest Export/Import setting mismatch for '%s': expected=%s, got=%s", tostring(k), tostring(expected), tostring(actual)))
					else
						verifiedKeys = verifiedKeys + 1
					end
				end
			end
			local bindCount = (type(parsed.bindings) == "table") and #parsed.bindings or 0
			table.insert(infoNotes, string.format("DeepTest Export/Import roundtrip OK (%d settings, %d bindings, %d bytes)", verifiedKeys, bindCount, string.len(exportAll or "")))
		end
	end

	-- 3. SpellRanks-Cache & Unit-Token Secret-Guard-Belastungstest
	SpellRanks.InvalidateCache()
	local cache = SpellRanks.EnsureCache()
	local groupCount = 0
	local entryCount = 0
	if cache and type(cache.bySpellKey) == "table" then
		for _ in pairs(cache.bySpellKey) do
			groupCount = groupCount + 1
		end
	end
	if cache and type(cache.byActionID) == "table" then
		for _ in pairs(cache.byActionID) do
			entryCount = entryCount + 1
		end
	end
	local pendingUpdates = SpellRanks.GetPendingSmartRuleUpdates and SpellRanks.GetPendingSmartRuleUpdates() or {}
	local freeKeys = ClickBindingUI.GetFreeKeysSummaryList and ClickBindingUI.GetFreeKeysSummaryList() or {}
	table.insert(infoNotes, string.format("DeepTest SpellRanks: %d spell group(s), %d rank entry(s), %d pending smart update(s), %d free slot(s)", groupCount, entryCount, #pendingUpdates, #freeKeys))

	-- 3b. Modifier-Sortierung inkl. macOS-META (alle 16 Kombinationen auf Kollisionsfreiheit prüfen)
	local modTestCases = {
		{ str = "", expected = 1 },
		{ str = "SHIFT", expected = 2 },
		{ str = "CTRL", expected = 3 },
		{ str = "ALT", expected = 4 },
		{ str = "META", expected = 5 },
		{ str = "SHIFT-CTRL", expected = 6 },
		{ str = "SHIFT-ALT", expected = 7 },
		{ str = "CTRL-ALT", expected = 8 },
		{ str = "SHIFT-META", expected = 9 },
		{ str = "CTRL-META", expected = 10 },
		{ str = "ALT-META", expected = 11 },
		{ str = "SHIFT-CTRL-ALT", expected = 12 },
		{ str = "SHIFT-CTRL-META", expected = 13 },
		{ str = "SHIFT-ALT-META", expected = 14 },
		{ str = "CTRL-ALT-META", expected = 15 },
		{ str = "SHIFT-CTRL-ALT-META", expected = 16 },
	}
	local modPassCount = 0
	for _, tc in ipairs(modTestCases) do
		local gotOrder = Constants.GetModifierSortInfo(tc.str)
		if gotOrder ~= tc.expected then
			table.insert(findings, string.format("DeepTest Modifier order mismatch for '%s': expected=%d, got=%s", tc.str, tc.expected, tostring(gotOrder)))
		else
			modPassCount = modPassCount + 1
		end
	end
	if modPassCount == #modTestCases then
		table.insert(infoNotes, string.format("DeepTest Modifiers (incl. macOS META): %d/%d combinations verified collision-free", modPassCount, #modTestCases))
	end

	-- 3c. Reorder-, MMO-Button- (MB6..MB31), Matrix-Default-Zeilen- und Hover-Augen-Invariante prüfen
	local savedBtnOrder = Database.Get("customButtonOrder")
	local savedVisBtns = Database.Get("matrixVisibleButtons")
	local savedModOrder = Database.Get("customModifierOrder")
	local savedDefRows = Database.Get("matrixDefaultRows")
	local savedHiddenHover = Database.Get("unitHoverHiddenCombos")

	local reorderChecksOk = true
	-- Test 1: Preset LMB | MMB | RMB + MMO-Maustaste Button12 (MB12)
	Database.ApplyMiddleMouseCenterOrder()
	if Constants.GetButtonSortOrder("MiddleButton") >= Constants.GetButtonSortOrder("RightButton") then
		table.insert(findings, "DeepTest Reorder: ApplyMiddleMouseCenterOrder failed to place MiddleButton before RightButton")
		reorderChecksOk = false
	end
	Database.AddMouseButtonToOrder("Button12", true)
	if not Database.IsMatrixButtonColumnVisible("Button12") then
		table.insert(findings, "DeepTest Reorder: AddMouseButtonToOrder('Button12', true) did not activate MB12 column")
		reorderChecksOk = false
	end
	Database.MoveMouseButtonInOrder("Button12", 1)
	if Constants.GetButtonSortOrder("Button12") ~= 1 then
		table.insert(findings, "DeepTest Reorder: MoveMouseButtonInOrder('Button12', 1) failed")
		reorderChecksOk = false
	end
	local dispBtn6 = Constants.GetButtonDisplayName and Constants.GetButtonDisplayName("Button6") or ""
	if dispBtn6 == "" or string.find(dispBtn6, "GROUP_BUTTON_", 1, true) then
		table.insert(findings, string.format("DeepTest Reorder: invalid button display label '%s'", tostring(dispBtn6)))
		reorderChecksOk = false
	end

	-- Test 2: Matrix-Modifikator-Zeilen umsortieren & Default-Zeilen-Sichtbarkeit (inkl. Guard für mindestens 1 aktive Zeile)
	Database.MoveModifierInOrder(5, 1)
	local modIds = Database.GetOrderedModifierIDs()
	if modIds[1] ~= 5 then
		table.insert(findings, "DeepTest Reorder: MoveModifierInOrder(5, 1) failed")
		reorderChecksOk = false
	end
	Database.SetMatrixRowDefaultVisible(5, false)
	if Database.IsMatrixRowDefaultVisible(5) then
		table.insert(findings, "DeepTest Matrix Default-Visible: unchecking Meta (row 5) failed")
		reorderChecksOk = false
	end
	Database.Set("matrixDefaultRows", "")
	if not Database.IsMatrixRowDefaultVisible(1) then
		table.insert(findings, "DeepTest Matrix Default-Visible: empty guard did not keep Direct (row 1) visible")
		reorderChecksOk = false
	end

	-- Test 3: Hover-Overlay Augen-Sichtbarkeit (Zauber standardmäßig sichtbar, Interaktion standardmäßig ausgeblendet)
	Database.Set("unitHoverHiddenCombos", "")
	local dummySpell = { type = (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Spell) or 1, actionID = 1, button = "LeftButton", modifiers = 0 }
	local dummyInteraction = { type = (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Interaction) or 3, actionID = 1, button = "LeftButton", modifiers = 0 }
	if Database.IsBindingHiddenInHover(dummySpell) then
		table.insert(findings, "DeepTest Hover Eye: spell binding should be visible by default")
		reorderChecksOk = false
	end
	Database.ToggleBindingHiddenInHover(dummySpell)
	if not Database.IsBindingHiddenInHover(dummySpell) then
		table.insert(findings, "DeepTest Hover Eye: toggling spell binding to hidden failed")
		reorderChecksOk = false
	end
	if not Database.IsBindingHiddenInHover(dummyInteraction) then
		table.insert(findings, "DeepTest Hover Eye: interaction binding should be hidden by default")
		reorderChecksOk = false
	end
	Database.ToggleBindingHiddenInHover(dummyInteraction)
	if Database.IsBindingHiddenInHover(dummyInteraction) then
		table.insert(findings, "DeepTest Hover Eye: toggling interaction binding to visible failed")
		reorderChecksOk = false
	end

	-- Originalwerte nach Logik-Tests wiederherstellen
	Database.Set("customButtonOrder", savedBtnOrder)
	Database.Set("matrixVisibleButtons", savedVisBtns)
	Database.Set("customModifierOrder", savedModOrder)
	Database.Set("matrixDefaultRows", savedDefRows)
	Database.Set("unitHoverHiddenCombos", savedHiddenHover)

	if reorderChecksOk then
		table.insert(infoNotes, string.format("DeepTest v%s logic: Reorder (MMB preset + MB12 MMO column + modifier move), Matrix Default-Visible & Hover Eye (Spell vs. Interaction) verified OK", tostring(Constants.VERSION or "0.9.0")))
	end

	-- 4. UI-Lebenszyklus-Kette (nur außerhalb des Kampfes und im MKB-Modus)
	if InCombatLockdown and InCombatLockdown() then
		table.insert(infoNotes, "DeepTest UI lifecycle skipped (InCombatLockdown active)")
	elseif Constants.IsGamepadUIActive() then
		ClickBindingUI.UpdateGamepadStandbyState()
		table.insert(infoNotes, "DeepTest UI lifecycle skipped (Gamepad Standby active & verified)")
	else
		local origGrouping = Database.Get("groupingMode")
		local origCompact = Database.Get("compactListMode")
		local origCombos = Database.Get("matrixShowCombos")
		local origMetaMode = Database.Get("matrixMetaMode")
		local wasCBShown = ClickBindingFrame and ClickBindingFrame:IsShown() or false
		local wasSettingsShown = _G.BetterClickCastingSettingsFrame and _G.BetterClickCastingSettingsFrame:IsShown() or false
		local wasMatrixShown = (FreeKeysMatrixUI and FreeKeysMatrixUI.IsShown and FreeKeysMatrixUI.IsShown()) or false
		local wasUnlocked = SettingsUI and SettingsUI.IsOverlaysUnlocked and SettingsUI.IsOverlaysUnlocked() or false

		if not wasCBShown and ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			ns.MinimapButton.ToggleClickCastingWindow()
		end
		if ClickBindingFrame and ClickBindingFrame:IsShown() then
			if not (PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and PlayerSpellsFrame.GetTab and PlayerSpellsFrame:GetTab() == PlayerSpellsFrame.spellBookTabID) then
				table.insert(findings, string.format("DeepTest SpellBookTab: expected SpellBook tab active alongside ClickBindingFrame (got tab=%s)", tostring(PlayerSpellsFrame and PlayerSpellsFrame.GetTab and PlayerSpellsFrame:GetTab())))
			end
		end
		ClickBindingUI.SetupHooks()

		for _, gMode in ipairs({ "modifier", "button", "type", "none" }) do
			Database.Set("groupingMode", gMode)
			ClickBindingUI.RebuildGroups()
			ClickBindingUI.RefreshVisibleLines()
		end
		Database.Set("compactListMode", not origCompact)
		ClickBindingUI.ApplyScrollBoxLayout()
		Database.Set("compactListMode", origCompact)
		ClickBindingUI.ApplyScrollBoxLayout()
		Database.Set("groupingMode", origGrouping)
		ClickBindingUI.RebuildGroups()

		if SettingsUI and SettingsUI.OpenSettingsTab then
			local maxTabs = SettingsUI.NAV_COUNT or 6
			local presetCount = (Database.GetPresetList and #Database.GetPresetList()) or 0
			for tabIdx = 1, maxTabs do
				SettingsUI.OpenSettingsTab(tabIdx)
				if SettingsUI.GetLayoutState then
					local st = SettingsUI.GetLayoutState()
					local expectSticky = (tabIdx == 1 or tabIdx == 2 or tabIdx == 4)
					if st then
						if st.stickyShown ~= expectSticky then
							table.insert(findings, string.format("DeepTest SettingsLayout: Tab %d stickyShown=%s (expected %s)", tabIdx, tostring(st.stickyShown), tostring(expectSticky)))
						end
						if (tabIdx ~= 5 or presetCount <= 12) and st.needsScroll then
							table.insert(findings, string.format("DeepTest SettingsLayout: Tab %d unexpectedly requires scrolling (content=%d > viewport=%d)", tabIdx, st.contentHeight or 0, st.viewportHeight or 0))
						end
					end
				end
			end
			if SettingsUI.SetSearchFilter and SettingsUI.GetSearchFilter then
				SettingsUI.SetSearchFilter("a")
				if SettingsUI.GetLayoutState then
					local stSearch = SettingsUI.GetLayoutState()
					if stSearch and stSearch.stickyShown then
						table.insert(findings, "DeepTest SettingsSearch: StickyPane should hide while search results are active")
					end
				end
				SettingsUI.SetSearchFilter("mana")
				if SettingsUI.GetSearchFilter() ~= "mana" then
					table.insert(findings, "DeepTest SettingsSearch: failed to apply search query 'mana'")
				end
				SettingsUI.SetSearchFilter("__no_match_xyz__")
				SettingsUI.SetSearchFilter("")
			end
			if SettingsUI.GetSelectedSourceCharProfile then
				local srcProf, curCharKey = SettingsUI.GetSelectedSourceCharProfile()
				if srcProf and srcProf.key == curCharKey then
					table.insert(findings, "DeepTest SourceCharPreselect: unexpectedly preselected active character itself")
				end
			end
		end
		if SettingsUI and SettingsUI.ShowReorderWindow and SettingsUI.HideReorderWindow then
			SettingsUI.ShowReorderWindow()
			SettingsUI.HideReorderWindow()
		end

		ClickBindingUI.ShowFreeKeysMatrix()
		for _, metaMode in ipairs({ "off", "on" }) do
			Database.Set("matrixMetaMode", metaMode)
			Database.Set("matrixShowCombos", false)
			ClickBindingUI.RefreshFreeKeysMatrix()
			Database.Set("matrixShowCombos", true)
			ClickBindingUI.RefreshFreeKeysMatrix()
		end
		-- Dynamische MMO-Spalte (MB6) und benutzerdefinierte Zeilen-Reihenfolge live im Matrix-UI rendern
		local origBtnOrderUI = Database.Get("customButtonOrder")
		local origVisBtnsUI = Database.Get("matrixVisibleButtons")
		Database.AddMouseButtonToOrder("Button6", true)
		ClickBindingUI.RefreshFreeKeysMatrix()
		Database.Set("customButtonOrder", origBtnOrderUI)
		Database.Set("matrixVisibleButtons", origVisBtnsUI)
		Database.Set("matrixMetaMode", origMetaMode)
		Database.Set("matrixShowCombos", origCombos)
		ClickBindingUI.RefreshFreeKeysMatrix()

		-- 4b. Vollständiger Dual-Spec- & Preset-Zyklus-Test (funktioniert auf jedem Charakter-Level):
		-- Prüft keepUnlearnedSpells=true (Presets) vs. keepUnlearnedSpells=false (Cross-Char-Import),
		-- Blizzards SPELLS_CHANGED-Löschschutz im offenen ClickBindingFrame, Spec-1/Spec-2-Preset-Verknüpfung
		-- und die vollständige Wiederherstellung des Ausgangszustands.
		if ClickBindingFrame and ClickBindingFrame.dataProvider then
			local origPending = ClickBindingFrame.pendingChanges
			local origGlowShown = (ClickBindingUI.IsSaveButtonGlowShown and ClickBindingUI.IsSaveButtonGlowShown()) or false
			local origActivePreset = Database.GetActivePresetName and Database.GetActivePresetName()
			local origProviderElements = {}
			for _, el in ClickBindingFrame.dataProvider:Enumerate() do
				if el and (el.elementType == ElementDataTypes.CustomsBinding or el.elementType == ElementDataTypes.InteractionBinding) and el.bindingInfo then
					table.insert(origProviderElements, {
						elementType = el.elementType,
						unbound = el.unbound and true or false,
						bindingInfo = {
							type = el.bindingInfo.type,
							actionID = el.bindingInfo.actionID,
							button = el.bindingInfo.button,
							modifiers = el.bindingInfo.modifiers,
						},
					})
				end
			end

			-- Nicht gelernte Talent-SpellID wählen (10060 = Power Infusion, Fallback 402174 = Penance)
			local unlearnedSpellID = 10060
			if SpellRanks.GetRankEntryForAction(unlearnedSpellID) then
				unlearnedSpellID = 402174
			end
			local spellType = (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Spell) or 1
			local dummyUnlearnedList = {
				{
					type = spellType,
					actionID = unlearnedSpellID,
					button = "Button31",
					modifiers = 0,
					spellName = "BCCDeepTestUnlearnedTalent",
					subName = "",
					rankNum = 0,
					ruleMode = SpellRanks.RULE_MAX,
				},
			}

			-- Test A: Cross-Character-Import (keepUnlearnedSpells = false) MUSS unbekannten Zauber überspringen
			local appCross, skipCross = ClickBindingUI.ApplyImportedBindings(dummyUnlearnedList, true, false)
			if appCross ~= 0 or skipCross ~= 1 then
				table.insert(findings, string.format("DeepTest DualSpec: Cross-char import should skip unlearned spell (got applied=%s, skipped=%s)", tostring(appCross), tostring(skipCross)))
			end

			-- Test B: Eigenes Charakter-Preset (keepUnlearnedSpells = true) MUSS nicht gelernten Talent-Zauber behalten
			local appPreset, skipPreset = ClickBindingUI.ApplyImportedBindings(dummyUnlearnedList, true, true)
			if appPreset ~= 1 or skipPreset ~= 0 then
				table.insert(findings, string.format("DeepTest DualSpec: Preset load with keepUnlearnedSpells=true failed (got applied=%s, skipped=%s)", tostring(appPreset), tostring(skipPreset)))
			end

			-- Test C: Blizzards SPELLS_CHANGED-Handler auf offenem ClickBindingFrame simulieren und Wiederherstellung prüfen
			if ClickBindingFrame.GetScript then
				local onEventScript = ClickBindingFrame:GetScript("OnEvent")
				if type(onEventScript) == "function" then
					onEventScript(ClickBindingFrame, "SPELLS_CHANGED")
				end
			end
			local foundAfterSpellsChanged = false
			for _, el in ClickBindingFrame.dataProvider:Enumerate() do
				if el and el.elementType == ElementDataTypes.CustomsBinding and el.bindingInfo and el.bindingInfo.actionID == unlearnedSpellID and el.bindingInfo.button == "Button31" then
					foundAfterSpellsChanged = true
					break
				end
			end
			if not foundAfterSpellsChanged then
				table.insert(findings, "DeepTest DualSpec: unlearned talent spell was purged by SPELLS_CHANGED and not restored by RestorePurgedUnlearnedBindings")
			end

			-- Test C2: Manuelles Löschen (isManualDeleteInProgress = true) darf durch SPELLS_CHANGED NICHT wiederhergestellt werden
			local dummyToManualDelete = nil
			for _, el in ClickBindingFrame.dataProvider:Enumerate() do
				if el and el.elementType == ElementDataTypes.CustomsBinding and el.bindingInfo and el.bindingInfo.actionID == unlearnedSpellID and el.bindingInfo.button == "Button31" then
					dummyToManualDelete = el
					break
				end
			end
			if dummyToManualDelete then
				ClickBindingUI.SetManualDeleteInProgress(true)
				ClickBindingFrame.dataProvider:Remove(dummyToManualDelete)
				ClickBindingUI.SetManualDeleteInProgress(false)
				ClickBindingUI.RebuildGroups(false)
				if ClickBindingFrame.GetScript then
					local onEventScript = ClickBindingFrame:GetScript("OnEvent")
					if type(onEventScript) == "function" then
						onEventScript(ClickBindingFrame, "SPELLS_CHANGED")
					end
				end
				for _, el in ClickBindingFrame.dataProvider:Enumerate() do
					if el and el.elementType == ElementDataTypes.CustomsBinding and el.bindingInfo and el.bindingInfo.actionID == unlearnedSpellID and el.bindingInfo.button == "Button31" then
						table.insert(findings, "DeepTest DualSpec: manually deleted binding was unexpectedly resurrected by SPELLS_CHANGED")
						break
					end
				end
			end

			-- Test D: Preset Spec-1 / Spec-2 Verknüpfung & OnActiveSpecGroupChanged-Auflösung
			local testPresetName = "__BCC_DEEP_TEST_SPEC__"
			local charProfile = Database.GetCurrentCharProfile()
			local prevSpec1Preset = Database.GetPresetForSpecGroup and Database.GetPresetForSpecGroup(1)
			local prevSpec2Preset = Database.GetPresetForSpecGroup and Database.GetPresetForSpecGroup(2)
			local prevSpec1Name = prevSpec1Preset and prevSpec1Preset.name
			local prevSpec2Name = prevSpec2Preset and prevSpec2Preset.name

			if charProfile and type(charProfile.presets) == "table" then
				charProfile.presets[testPresetName] = {
					name = testPresetName,
					updatedAt = 0,
					bindings = dummyUnlearnedList,
					spec1 = false,
					spec2 = false,
				}
				Database.SetPresetSpecAssignment(testPresetName, 2, true)
				local linked2 = Database.GetPresetForSpecGroup(2)
				if not linked2 or linked2.name ~= testPresetName then
					table.insert(findings, "DeepTest DualSpec: SetPresetSpecAssignment failed to link preset to Spec 2")
				end
				Database.SetActivePresetName("__OTHER__")
				local triggered, trigName = ClickBindingUI.OnActiveSpecGroupChanged(2, true)
				if not triggered or trigName ~= testPresetName then
					table.insert(findings, string.format("DeepTest DualSpec: OnActiveSpecGroupChanged(2) did not resolve linked preset (got %s, %s)", tostring(triggered), tostring(trigName)))
				end
				-- Test D2: Dual-Spec-Hero-Card-Lebenszyklus, Talentbaum-Icon-Abfrage & Live-Simulator (/bcc test spec)
				if Constants.GetPrimaryTalentTreeIconForSpecGroup then
					for sIdx = 1, 2 do
						local tIcon = Constants.GetPrimaryTalentTreeIconForSpecGroup(sIdx)
						if tIcon ~= nil and (type(tIcon) ~= "number" or tIcon <= 0) then
							table.insert(findings, string.format("DeepTest DualSpec: GetPrimaryTalentTreeIconForSpecGroup(%d) returned invalid icon %s", sIdx, tostring(tIcon)))
						end
					end
				end
				local hcFrame = HeroCardUI and HeroCardUI.GetFrame and HeroCardUI.GetFrame()
				local wasHeroShown = hcFrame and hcFrame:IsShown()
				local specCardShown = ClickBindingUI.SimulateDualSpecHeroCardTest(2, true)
				hcFrame = HeroCardUI and HeroCardUI.GetFrame and HeroCardUI.GetFrame()
				if not specCardShown or not (hcFrame and hcFrame:IsShown() and hcFrame.mode == "spec_preset" and hcFrame.pendingSpecPreset and hcFrame.pendingSpecPreset.name == testPresetName) then
					table.insert(findings, "DeepTest DualSpec: SimulateDualSpecHeroCardTest(2) failed to show linked preset heroCardFrame")
				end
				-- Demo-Fallback testen (wenn kein Preset an Spec 2 verknüpft ist)
				charProfile.presets[testPresetName] = nil
				local demoCardShown = ClickBindingUI.SimulateDualSpecHeroCardTest(2, true)
				hcFrame = HeroCardUI and HeroCardUI.GetFrame and HeroCardUI.GetFrame()
				if not demoCardShown or not (hcFrame and hcFrame:IsShown() and hcFrame.pendingSpecPreset and hcFrame.pendingSpecPreset._bccIsDemoTest == true) then
					table.insert(findings, "DeepTest DualSpec: SimulateDualSpecHeroCardTest(2) Demo fallback failed")
				end
				if hcFrame then
					hcFrame.pendingSpecPreset = nil
					hcFrame.mode = "smart_rules"
					if not wasHeroShown then
						hcFrame:Hide()
					end
				end
				if prevSpec1Name then
					Database.SetPresetSpecAssignment(prevSpec1Name, 1, true)
				end
				if prevSpec2Name then
					Database.SetPresetSpecAssignment(prevSpec2Name, 2, true)
				end
			end

			-- Test D3: Transaktionaler Preset-Commit (Blizzard ruft HideUIPanel/OnHide VOR SaveButton-Post-Hook auf!)
			if charProfile and type(charProfile.presets) == "table" then
				charProfile.presets["__BCC_PREV__"] = { name = "__BCC_PREV__", updatedAt = 0, bindings = {} }
				charProfile.presets["__BCC_COMMITTED__"] = { name = "__BCC_COMMITTED__", updatedAt = 0, bindings = {} }
				Database.SetActivePresetName("__BCC_PREV__")
				PresetsAndImportUI.SetPendingPresetForTest("__BCC_COMMITTED__")
				-- Fall 1: Abbruch ohne Save (OnHide allein darf DB-Wert nicht ändern)
				PresetsAndImportUI.OnClickBindingFrameHidePendingPreset()
				if Database.GetActivePresetName() ~= "__BCC_PREV__" then
					table.insert(findings, "DeepTest DualSpec: OnHide without Save unexpectedly modified activePresetName")
				end
				-- Fall 2: SaveButton-Klick (OnHide gefolgt von CommitPendingPresetOnSave MUSS neuen Namen übernehmen)
				PresetsAndImportUI.CommitPendingPresetOnSave()
				if Database.GetActivePresetName() ~= "__BCC_COMMITTED__" then
					table.insert(findings, string.format("DeepTest DualSpec: SaveButton commit after OnHide failed (got %s)", tostring(Database.GetActivePresetName())))
				end
				charProfile.presets["__BCC_PREV__"] = nil
				charProfile.presets["__BCC_COMMITTED__"] = nil
			end

			-- Ausgangszustand von ClickBindingFrame.dataProvider exakt wiederherstellen
			local toClear = {}
			for _, el in ClickBindingFrame.dataProvider:Enumerate() do
				if el and (el.elementType == ElementDataTypes.CustomsBinding or el.elementType == ElementDataTypes.InteractionBinding) then
					table.insert(toClear, el)
				end
			end
			if #toClear > 0 then
				ClickBindingFrame.dataProvider:Remove(unpack(toClear))
			end
			for _, savedEl in ipairs(origProviderElements) do
				ClickBindingFrame.dataProvider:Insert(savedEl)
			end
			Database.SetActivePresetName(origActivePreset)
			PresetsAndImportUI.ClearPendingPresetState()
			ClickBindingUI.RebuildGroups(false)
			ClickBindingFrame.pendingChanges = origPending
			SetSaveButtonGlowShown(origGlowShown)
			ClickBindingUI.RefreshVisibleLines()
			if SpellBookUI and SpellBookUI.RefreshBadges then
				SpellBookUI.RefreshBadges()
			end
			table.insert(infoNotes, "DeepTest DualSpec simulator: keepUnlearned preset load, SPELLS_CHANGED purge protection, manual-delete non-resurrection & Spec 1/2 preset linking verified OK")
		end

		if SettingsUI and SettingsUI.SetOverlaysUnlocked then
			SettingsUI.SetOverlaysUnlocked(true, true)
			SettingsUI.SetOverlaysUnlocked(wasUnlocked, true)
		end

		-- Combat-Save-Shield-Lebenszyklus & SaveButton-Hygiene testen (taintfreies UIParent-Overlay)
		if ClickBindingFrame and ClickBindingFrame.SaveButton then
			if ClickBindingFrame.SaveButton.BCCGlowFrame ~= nil or ClickBindingFrame.SaveButton._bccSnapshotHooked ~= nil then
				table.insert(findings, "DeepTest SaveButton: unexpected custom fields written directly onto ClickBindingFrame.SaveButton")
			end
			if issecurevariable then
				local sbSec, sbTaint = issecurevariable(ClickBindingFrame, "SaveButton")
				if not sbSec then
					table.insert(findings, string.format("DeepTest SaveButton: ClickBindingFrame.SaveButton tainted by %s", tostring(sbTaint)))
				end
			end
		end
		ClickBindingUI.UpdateSaveButtonCombatShield(true)
		local combatShield = ClickBindingUI.GetSaveCombatShield and ClickBindingUI.GetSaveCombatShield()
		if not (combatShield and combatShield:IsShown()) then
			table.insert(findings, "DeepTest SaveCombatShield: shield failed to show when forceCombatState=true")
		else
			-- Race-Condition-Prüfung: OnUpdate darf den Schild bei aktivem combatLockActive vor InCombatLockdown() nicht verstecken
			local shieldOnUpdate = combatShield:GetScript("OnUpdate")
			if type(shieldOnUpdate) == "function" then
				shieldOnUpdate(combatShield, 0.016)
			end
			if not combatShield:IsShown() then
				table.insert(findings, "DeepTest SaveCombatShield: OnUpdate prematurely hid shield while combatLockActive=true")
			end
		end
		ClickBindingUI.UpdateSaveButtonCombatShield(false)
		combatShield = ClickBindingUI.GetSaveCombatShield and ClickBindingUI.GetSaveCombatShield()
		if combatShield and combatShield:IsShown() then
			table.insert(findings, "DeepTest SaveCombatShield: shield failed to hide when forceCombatState=false")
		end
		-- Modul-Architektur-Prüfung (BF-01: alle 5 Fachmodule + Fassade vorhanden)
		for _, modName in ipairs({ "SettingsWidgets", "SettingsUI", "ClickBindingUI", "HeroCardUI", "FreeKeysMatrixUI", "PresetsAndImportUI", "DiagnosticsUI" }) do
			if type(ns[modName]) ~= "table" then
				table.insert(findings, "DeepTest Modules: missing ns." .. modName)
			end
		end
		local blockedDiag = ClickBindingUI.CaptureBlockedActionDiagnostics("BetterClickCasting", "SetProfileByInfo()", true)
		if type(blockedDiag) ~= "string" or not string.find(blockedDiag, "^BCCBLOCK|") then
			table.insert(findings, "DeepTest BlockedDiag: CaptureBlockedActionDiagnostics returned invalid format")
		end
		-- SecureActionButton-Prüfung für den Minimap-Button (taintfreies /clickcast-Öffnen)
		local mmBtn = _G.BetterClickCastingMinimapButton
		if mmBtn and mmBtn.GetAttribute then
			if mmBtn:GetAttribute("useOnKeyDown") ~= false then
				table.insert(findings, "DeepTest MinimapButton: expected useOnKeyDown=false on SecureActionButton")
			end
			if not Constants.IsGamepadUIActive() then
				local mmType = mmBtn:GetAttribute("type1")
				local mmMacro = mmBtn:GetAttribute("macrotext1")
				if mmType ~= "macro" or type(mmMacro) ~= "string" or not string.find(mmMacro, "/stopmacro %[combat%]") then
					table.insert(findings, string.format("DeepTest MinimapButton: unexpected secure macro attributes (type1=%s)", tostring(mmType)))
				end
			end
		end

		if not wasMatrixShown then
			ClickBindingUI.HideFreeKeysMatrix()
		end
		if not wasSettingsShown and SettingsUI and SettingsUI.HideWindow then
			SettingsUI.HideWindow()
		end
		if not wasCBShown and ClickBindingFrame and ClickBindingFrame:IsShown() and ns.MinimapButton and ns.MinimapButton.ToggleClickCastingWindow then
			ns.MinimapButton.ToggleClickCastingWindow()
		end
		table.insert(infoNotes, "DeepTest UI lifecycle: ClickBindingFrame (4 group modes + compact toggle + SpellBook tab sync), SettingsUI (Tabs 1-6 + Sticky/Search), Matrix (4x5/8x5/5x5/12x5) & Overlays cycled OK")
	end
end

-- Diagnose-Werkzeug (/bcc debug, /bcc debug taintlog):
-- Prüft mit Blizzards issecurevariable() sofort außerhalb des Kampfes, ob globale Highlight-Tabellen,
-- Aktionsleisten (inkl. PetActionBar), EditModeManagerFrame oder PlayerSpellsFrame getaintete Felder besitzen.
function DiagnosticsUI.RunTaintDiagnostics(subArg)
	if not DEFAULT_CHAT_FRAME then
		return
	end
	if subArg == "taintlog" and SetCVar and GetCVar then
		if InCombatLockdown and InCombatLockdown() then
			DEFAULT_CHAT_FRAME:AddMessage(L["CHAT_COMBAT_ERR"])
			return
		end
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
	local infoNotes = {}
	local isDeepMode = (subArg == "deep" or subArg == "full" or subArg == "stress")
	if isDeepMode then
		RunDeepStressSelfTest(findings, infoNotes)
	end
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
	local okActGlobal, srcActGlobal = issecurevariable("ACTION_HIGHLIGHT_MARKS")
	if not okActGlobal then
		table.insert(findings, string.format("_G.ACTION_HIGHLIGHT_MARKS (by %s)", tostring(srcActGlobal or "unknown")))
	end
	if _G.ActionBarButtonEventsFrame and type(_G.ActionBarButtonEventsFrame.frames) == "table" then
		for _, btn in pairs(_G.ActionBarButtonEventsFrame.frames) do
			if type(btn) == "table" and btn.action ~= nil then
				local btnName = (btn.GetName and btn:GetName()) or tostring(btn)
				checkVar(btn, "action", btnName)
			end
		end
	end

	-- 2. Kritische Felder auf Aktionsleisten und EditMode-Systemen prüfen
	local bars = {
		{ frame = _G.PetActionBar, name = "PetActionBar" },
		{ frame = _G.MainActionBar, name = "MainActionBar" },
		{ frame = _G.MultiBarBottomLeft, name = "MultiBarBottomLeft", isMultiBar = true },
		{ frame = _G.MultiBarBottomRight, name = "MultiBarBottomRight", isMultiBar = true },
		{ frame = _G.MultiBarRight, name = "MultiBarRight", isMultiBar = true },
		{ frame = _G.MultiBarLeft, name = "MultiBarLeft", isMultiBar = true },
		{ frame = _G.MultiBar5, name = "MultiBar5", isMultiBar = true },
		{ frame = _G.MultiBar6, name = "MultiBar6", isMultiBar = true },
		{ frame = _G.MultiBar7, name = "MultiBar7", isMultiBar = true },
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

	local expectedShowAllBars = {}
	for _, entry in ipairs(bars) do
		local bar = entry.frame
		if bar then
			for _, k in ipairs(barKeys) do
				if bar[k] ~= nil then
					if k == "showAllButtons" and entry.isMultiBar then
						local okShowAll, srcShowAll = issecurevariable(bar, k)
						if not okShowAll then
							if srcShowAll == Constants.ADDON_NAME then
								-- Bekannter Blizzard-Seiteneffekt: Sobald /bcc (oder /bcc debug deep) PlayerSpellsFrame
								-- öffnet, ruft Blizzard_PlayerSpellsFrame:OnShow() MultiActionBar_ShowAllGrids(4) auf.
								-- Als transparente [WARN]-Meldung statt [ERR] ausweisen.
								table.insert(expectedShowAllBars, entry.name)
							else
								table.insert(findings, string.format("%s.%s (by %s)", entry.name, tostring(k), tostring(srcShowAll or "unknown")))
							end
						end
					else
						checkVar(bar, k, entry.name)
					end
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
	if #expectedShowAllBars > 0 then
		table.insert(infoNotes, string.format(
			"MultiBar.showAllButtons: %d bar(s) tainted by %s (%s; expected Blizzard side-effect when /bcc opens Spellbook; use /clickcast for untainted combat-visibility bars)",
			#expectedShowAllBars,
			tostring(Constants.ADDON_NAME),
			table.concat(expectedShowAllBars, ", ")
		))
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
	if _G.SettingsPanel and _G.SettingsPanel.Container and _G.SettingsPanel.Container.SettingsList and _G.SettingsPanel.Container.SettingsList.ScrollBox then
		local spScrollBox = _G.SettingsPanel.Container.SettingsList.ScrollBox
		if spScrollBox.ForEachFrame then
			spScrollBox:ForEachFrame(function(frame)
				local ed = frame.GetElementData and frame:GetElementData()
				if type(ed) == "table" and ed.searchTags ~= nil then
					checkVar(ed, "searchTags", "SettingsList.ElementData")
				end
			end)
		end
	end
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
							if (itemFrame.BCCQuickBindButton and itemFrame.BCCQuickBindButton:IsShown())
								or (itemFrame.BCCSecureCastButton and itemFrame.BCCSecureCastButton:IsShown())
							then
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

	-- 4. Gamepad-Fokus- und Binding-Stack sowie Standby-Abkopplung prüfen
	local isGamepadActive = Constants.IsGamepadUIActive()
	table.insert(infoNotes, string.format("GamepadUI active: %s", tostring(isGamepadActive)))
	if isGamepadActive then
		local pDropBtn = PresetsAndImportUI and PresetsAndImportUI.GetPresetDropdownButton and PresetsAndImportUI.GetPresetDropdownButton()
		if pDropBtn and pDropBtn:GetParent() ~= nil then
			table.insert(findings, "ClickBindingUI.presetDropdownButton still parented in Gamepad mode")
		end
		local gpBadge = ClickBindingUI.GetGamepadStandbyBadge and ClickBindingUI.GetGamepadStandbyBadge()
		if gpBadge and gpBadge:GetParent() ~= UIParent then
			table.insert(findings, "ClickBindingUI.gamepadStandbyBadge not parented to UIParent")
		end
	end
	if _G.GamepadMode and type(_G.GamepadMode.FrameControlsManager) == "table" then
		local fcm = _G.GamepadMode.FrameControlsManager
		for _, k in ipairs({ "shownFrames", "focusedFrame", "fallThroughCatcherActive", "isUIFocused" }) do
			if fcm[k] ~= nil then
				checkVar(fcm, k, "GamepadMode.FrameControlsManager")
			end
		end
	end
	if _G.GamepadSharedUtility and type(_G.GamepadSharedUtility.InputBindingManager) == "table" then
		local ibm = _G.GamepadSharedUtility.InputBindingManager
		for _, k in ipairs({ "currentCoreBindingActive", "bindingSetStack" }) do
			if ibm[k] ~= nil then
				checkVar(ibm, k, "GamepadSharedUtility.InputBindingManager")
			end
		end
	end

	local taintLogVal = (GetCVar and GetCVar("taintLog")) or "0"
	local compactParts = {}
	local colorLines = {}
	local okCount = 0
	local warnCount = 0
	local errCount = #findings

	local sepHeavy = string.rep("=", 62)
	local sepLight = string.rep("-", 78)
	local playerName = Constants.GetPlayerDisplayName and Constants.GetPlayerDisplayName() or "Player"
	local specIdx = Constants.GetActiveSpecGroupIndex and Constants.GetActiveSpecGroupIndex() or 1
	local modeTitle = isDeepMode and "DEEP SELF-TEST & TAINT DIAGNOSTICS" or "LIVE TAINT DIAGNOSTICS"

	local function AddHeader()
		table.insert(colorLines, "|cffd4af37" .. sepHeavy .. "|r")
		table.insert(colorLines, string.format("  |cffffd100BETTER CLICK CASTING v%s|r  |cff888888/|r  |cffffffff%s|r", tostring(Constants.VERSION or "?"), modeTitle))
		table.insert(colorLines, string.format("  |cff99ccffCharacter:|r %s  |cff888888/|r  |cff99ccffSpec:|r %d  |cff888888/|r  |cff99ccffGamepadUI:|r %s  |cff888888/|r  |cff99ccfftaintLog:|r %s", tostring(playerName), specIdx, isGamepadActive and "|cffff5555ON|r" or "|cff40ff59OFF|r", tostring(taintLogVal)))
		table.insert(colorLines, "|cffd4af37" .. sepHeavy .. "|r")
		table.insert(colorLines, "")
	end

	local function WrapIndentedDetail(text, maxChars, indentStr)
		local out = {}
		local cur = ""
		for word in string.gmatch(tostring(text or ""), "%S+") do
			if cur == "" then
				cur = word
			elseif string.len(cur) + 1 + string.len(word) <= maxChars then
				cur = cur .. " " .. word
			else
				table.insert(out, indentStr .. "|cffaaaaaa" .. cur .. "|r")
				cur = word
			end
		end
		if cur ~= "" then
			table.insert(out, indentStr .. "|cffaaaaaa" .. cur .. "|r")
		end
		return out
	end

	local function AddTestLine(status, label, detail)
		local shortTag = "OK"
		local cTag = "|cff40ff59[ OK ]|r"
		if status == "WARN" then
			warnCount = warnCount + 1
			shortTag = "WARN"
			cTag = "|cffffb833[WARN]|r"
		elseif status == "ERR" then
			shortTag = "ERR"
			cTag = "|cffff4444[ERR ]|r"
		else
			okCount = okCount + 1
		end
		table.insert(colorLines, string.format("%s  |cffffffff%s|r", cTag, tostring(label)))
		if detail and detail ~= "" then
			local wrapped = WrapIndentedDetail(detail, 94, "            ")
			for _, wLine in ipairs(wrapped) do
				table.insert(colorLines, wLine)
			end
		end
		-- Komprimierter Copy-Block: nur Status + Kerninfo (OK-Details stark verkürzt, WARN/ERR vollständig)
		if status == "OK" then
			table.insert(compactParts, string.format("%s:%s", shortTag, tostring(label)))
		else
			local d = (detail and detail ~= "") and ("=" .. tostring(detail)) or ""
			table.insert(compactParts, string.format("%s:%s%s", shortTag, tostring(label), d))
		end
	end

	AddHeader()

	-- Info-Zeilen sauber nach [ OK ] vs. [WARN] klassifizieren:
	-- Vollständig durch unser Overlay abgeschirmte SpellBook-Slots ("shielded by overlay") sind ein erwartetes [ OK ].
	for _, note in ipairs(infoNotes) do
		local titlePart, detailPart = string.match(note, "^([^:]+):%s*(.+)$")
		titlePart = titlePart or note
		detailPart = detailPart or ""
		local lowerNote = string.lower(note)
		local isShieldedOk = string.find(lowerNote, "shielded by overlay", 1, true) ~= nil
		if string.find(lowerNote, "skipped", 1, true)
			or (string.find(lowerNote, "tainted", 1, true) and not isShieldedOk)
		then
			AddTestLine("WARN", titlePart, detailPart)
		else
			AddTestLine("OK", titlePart, detailPart)
		end
	end

	-- Globale Sicherheitsprüfung (issecurevariable) als eigenen Testblock ausweisen
	if #findings == 0 then
		AddTestLine("OK", "SecurityScan", "0 critical taints on PetActionBar, ActionBars, UnitFrames, EditMode & Globals")
	else
		AddTestLine("ERR", string.format("SecurityScan(%d)", #findings), table.concat(findings, " ; "))
		for _, failLine in ipairs(findings) do
			table.insert(colorLines, "       |cffff5555[ERR ]|r |cffffcccc" .. tostring(failLine) .. "|r")
		end
	end

	local overallPass = (errCount == 0)
	local resultWord = overallPass and "PASS" or "FAIL"
	local resultColor = overallPass and "|cff40ff59PASS|r" or "|cffff4444FAIL|r"

	table.insert(colorLines, "")
	table.insert(colorLines, "|cff556677" .. sepLight .. "|r")
	table.insert(colorLines, string.format("  RESULT: %s  |cff888888/|r  |cff40ff59%d OK|r  |cff888888/|r  |cffffb833%d WARN|r  |cff888888/|r  |cffff4444%d ERR|r", resultColor, okCount, warnCount, errCount))
	table.insert(colorLines, "|cff556677" .. sepLight .. "|r")

	-- Komprimierter Einzeiler für Copy (nur für uns zum schnellen Einfügen in den Chat/Bugreport)
	local fullCompactReport = string.format(
		"BCCDBG|v%s|%s|spec=%d|gp=%d|tl=%s|%s(ok=%d,w=%d,e=%d)|%s",
		tostring(Constants.VERSION or "?"),
		isDeepMode and "DEEP" or "DBG",
		specIdx,
		isGamepadActive and 1 or 0,
		tostring(taintLogVal),
		resultWord,
		okCount,
		warnCount,
		errCount,
		table.concat(compactParts, " | ")
	)

	-- Kompakte Zusammenfassung im Chat
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff99ccffBetter Click Casting (%s):|r %s |cff888888(|r|cff40ff59%d OK|r, |cffffb833%d WARN|r, |cffff4444%d ERR|r|cff888888)|r",
		isDeepMode and "Deep Test" or "Debug",
		resultColor,
		okCount,
		warnCount,
		errCount
	))

	local fullColorReport = table.concat(colorLines, "\n")
	if type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.lastDebugReport = fullCompactReport
	end
	if #findings > 0 or subArg == "copy" or isDeepMode then
		local winTitle = isDeepMode
			and string.format("Better Click Casting v%s: Deep Self-Test Console", tostring(Constants.VERSION or "?"))
			or string.format("Better Click Casting v%s: Debug Diagnostics", tostring(Constants.VERSION or "?"))
		ShowDebugCopyPopup(fullCompactReport, winTitle, fullColorReport)
	end
end

-- Kompatible Fassade auf ns.ClickBindingUI beibehalten
for k, fn in pairs(DiagnosticsUI) do
	if type(fn) == "function" then
		ClickBindingUI[k] = fn
	end
end
