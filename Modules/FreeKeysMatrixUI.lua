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

local FreeKeysMatrixUI = {}
ns.FreeKeysMatrixUI = FreeKeysMatrixUI

--------------------------------------------------------------------------------
-- "Freie Tasten"-Spickzettel (4x5 Free Keys Matrix, Option A)
--------------------------------------------------------------------------------

local freeKeysMatrixFrame = nil
local matrixPreviewUnlocked = false
local matrixWasShownBeforePreview = false

local MATRIX_COLUMNS = {
	{ button = "LeftButton", short = "LMB" },
	{ button = "RightButton", short = "RMB" },
	{ button = "MiddleButton", short = "MMB" },
	{ button = "Button4", short = "MB4" },
	{ button = "Button5", short = "MB5" },
}

local MATRIX_MOD_ROWS = {
	{ modOrder = 1, shortPrefix = "", labelKey = "MATRIX_ROW_DIRECT", fallback = "Direct", isCombo = false, isMeta = false },
	{ modOrder = 2, shortPrefix = "S-", labelKey = "MATRIX_ROW_SHIFT", fallback = "Shift", isCombo = false, isMeta = false },
	{ modOrder = 3, shortPrefix = "C-", labelKey = "MATRIX_ROW_CTRL", fallback = "Ctrl", isCombo = false, isMeta = false },
	{ modOrder = 4, shortPrefix = "A-", labelKey = "MATRIX_ROW_ALT", fallback = "Alt", isCombo = false, isMeta = false },
	{ modOrder = 5, shortPrefix = "M-", labelKey = "MATRIX_ROW_META", fallback = "Meta", isCombo = false, isMeta = true },
	{ modOrder = 6, shortPrefix = "SC-", labelKey = "MATRIX_ROW_SHIFT_CTRL", fallback = "Shift + Ctrl", isCombo = true, isMeta = false },
	{ modOrder = 7, shortPrefix = "SA-", labelKey = "MATRIX_ROW_SHIFT_ALT", fallback = "Shift + Alt", isCombo = true, isMeta = false },
	{ modOrder = 8, shortPrefix = "CA-", labelKey = "MATRIX_ROW_CTRL_ALT", fallback = "Ctrl + Alt", isCombo = true, isMeta = false },
	{ modOrder = 9, shortPrefix = "SM-", labelKey = "MATRIX_ROW_SHIFT_META", fallback = "Shift + Meta", isCombo = true, isMeta = true },
	{ modOrder = 10, shortPrefix = "CM-", labelKey = "MATRIX_ROW_CTRL_META", fallback = "Ctrl + Meta", isCombo = true, isMeta = true },
	{ modOrder = 11, shortPrefix = "AM-", labelKey = "MATRIX_ROW_ALT_META", fallback = "Alt + Meta", isCombo = true, isMeta = true },
	{ modOrder = 12, shortPrefix = "SCA-", labelKey = "MATRIX_ROW_SHIFT_CTRL_ALT", fallback = "Shift + Ctrl + Alt", isCombo = true, isMeta = false },
	{ modOrder = 13, shortPrefix = "SCM-", labelKey = "MATRIX_ROW_SHIFT_CTRL_META", fallback = "S + C + M", isCombo = true, isMeta = true },
	{ modOrder = 14, shortPrefix = "SAM-", labelKey = "MATRIX_ROW_SHIFT_ALT_META", fallback = "S + A + M", isCombo = true, isMeta = true },
	{ modOrder = 15, shortPrefix = "CAM-", labelKey = "MATRIX_ROW_CTRL_ALT_META", fallback = "C + A + M", isCombo = true, isMeta = true },
}

local function NormalizeMatrixButton(buttonName)
	if buttonName == "Button1" then
		return "LeftButton"
	elseif buttonName == "Button2" then
		return "RightButton"
	elseif buttonName == "Button3" then
		return "MiddleButton"
	end
	return buttonName
end

local function CollectCurrentActiveBindings()
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
	return bindings
end

-- Ermittelt, ob die Matrix die macOS-Meta-(Cmd)-Zeilen anzeigen soll (automatisch auf macOS
-- oder sobald mindestens eine aktive Belegung META nutzt, sowie manuell per /bcc keys meta).
function FreeKeysMatrixUI.IsMatrixMetaActive(bindings)
	local mode = Database.Get("matrixMetaMode") or "auto"
	if mode == "on" then
		return true
	elseif mode == "off" then
		return false
	end
	if IsMacClient and IsMacClient() then
		return true
	end
	bindings = bindings or CollectCurrentActiveBindings()
	for _, info in ipairs(bindings) do
		if info and Constants.HasMetaModifier and Constants.HasMetaModifier(info.modifiers) then
			return true
		end
	end
	return false
end

function FreeKeysMatrixUI.GetMatrixModRowDefinitions()
	return MATRIX_MOD_ROWS
end

function FreeKeysMatrixUI.GetOrderedMatrixModRows()
	local byOrder = {}
	for rIdx, row in ipairs(MATRIX_MOD_ROWS) do
		byOrder[row.modOrder] = { rIdx = rIdx, row = row }
	end
	local orderedIDs = (Database.GetOrderedModifierIDs and Database.GetOrderedModifierIDs()) or {}
	local out = {}
	local seen = {}
	for _, id in ipairs(orderedIDs) do
		if byOrder[id] and not seen[id] then
			seen[id] = true
			table.insert(out, byOrder[id])
		end
	end
	for rIdx, row in ipairs(MATRIX_MOD_ROWS) do
		if not seen[row.modOrder] then
			seen[row.modOrder] = true
			table.insert(out, { rIdx = rIdx, row = row })
		end
	end
	return out
end

local function GetCurrentMatrixColumns()
	if Database.GetActiveMatrixColumns then
		return Database.GetActiveMatrixColumns()
	end
	return MATRIX_COLUMNS
end

function FreeKeysMatrixUI.GetFreeKeysSummaryList(bindings)
	bindings = bindings or CollectCurrentActiveBindings()
	local includeCombos = Database.Get("matrixShowCombos") and true or false
	local showMeta = ClickBindingUI.IsMatrixMetaActive(bindings)
	local activeCols = GetCurrentMatrixColumns()
	local orderedRows = ClickBindingUI.GetOrderedMatrixModRows()
	local lookup = {}
	for _, info in ipairs(bindings) do
		if info and info.button then
			local modOrder = Constants.GetModifierSortInfo(info.modifiers)
			local normBtn = NormalizeMatrixButton(info.button)
			lookup[tostring(modOrder) .. ":" .. tostring(normBtn)] = info
		end
	end

	local freeList = {}
	for _, item in ipairs(orderedRows) do
		local row = item.row
		local isPinned
		if Database.IsMatrixRowDefaultVisible then
			isPinned = Database.IsMatrixRowDefaultVisible(row.modOrder)
		else
			isPinned = not row.isCombo
		end
		if (showMeta or not row.isMeta) and (includeCombos or isPinned) then
			for _, col in ipairs(activeCols) do
				local key = tostring(row.modOrder) .. ":" .. col.button
				if not lookup[key] then
					table.insert(freeList, row.shortPrefix .. col.short)
				end
			end
		end
	end
	return freeList
end

local function FormatMatrixCellData(info)
	if not info then
		return nil
	end
	local bType = info.type
	local actionID = info.actionID
	local icon = 134400
	local shortLabel = "?"
	local subLabel = ""
	local isUnlearned = false
	local isInteraction = false

	if Constants.IsSpellOrPetBinding(info) and actionID then
		local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
		local isLearned = SpellRanks.IsBindingSpellLearned(info)
		isUnlearned = not isLearned
		icon = SpellRanks.GetSpellIconForAction(actionID) or 134400
		local baseName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(actionID) or "?"
		local subtext = (rankEntry and rankEntry.subName) or SpellRanks.GetSpellSubtextForAction(actionID) or ""
		local shortRank = SpellRanks.ExtractShortRankText(subtext) or subtext
		shortLabel = baseName
		if not isLearned then
			subLabel = Colors.WARN_UNLEARNED .. L["TAG_NOT_LEARNED"] .. Colors.RESET
		elseif shortRank and shortRank ~= "" then
			if rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
				if not rankEntry.isLowRank then
					subLabel = Colors.TAG_MAX .. shortRank .. " " .. L["TAG_MAX"] .. Colors.RESET
				else
					subLabel = Colors.RANK_DOWN .. shortRank .. Colors.RESET
				end
			else
				subLabel = Colors.RANK_MAX .. shortRank .. Colors.RESET
			end
		end
	elseif bType == (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Macro or 2) and actionID then
		local macroName, macroIcon = nil, nil
		if GetMacroInfo then
			macroName, macroIcon = GetMacroInfo(actionID)
		end
		icon = macroIcon or 134400
		shortLabel = macroName or (L["GROUP_HDR_MACROS"] or "Macro")
		subLabel = Colors.MUTED .. (L["GROUP_HDR_MACROS"] or "Macro") .. Colors.RESET
	elseif bType == (Enum and Enum.ClickBindingType and Enum.ClickBindingType.Interaction or 3) then
		isInteraction = true
		if actionID == (Enum and Enum.ClickBindingInteraction and Enum.ClickBindingInteraction.Target or 1) then
			icon = 132212
			shortLabel = CLICK_BINDING_TARGET_UNIT or BINDING_NAME_TARGETSELF or "Target"
		elseif actionID == (Enum and Enum.ClickBindingInteraction and Enum.ClickBindingInteraction.OpenContextMenu or 2) then
			icon = 134331
			shortLabel = CLICK_BINDING_OPEN_MENU or HUD_EDIT_MODE_MENU or "Menu"
		else
			icon = 132212
			shortLabel = "Interact"
		end
		subLabel = Colors.MUTED .. "Default" .. Colors.RESET
	end

	return {
		info = info,
		icon = icon,
		shortLabel = shortLabel,
		subLabel = subLabel,
		isUnlearned = isUnlearned,
		isInteraction = isInteraction,
	}
end

local function ShowMatrixCellTooltip(cellFrame)
	if not cellFrame or not GameTooltip then
		return
	end
	GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
	local cellData = cellFrame.cellData
	local comboText = cellFrame.comboLabel or "?"

	if not cellData or not cellData.info then
		GameTooltip_SetTitle(GameTooltip, comboText)
		GameTooltip:AddLine(L["MATRIX_CELL_FREE_TOOLTIP"], 0.25, 1.0, 0.35, true)
		GameTooltip:Show()
		return
	end

	local info = cellData.info
	local bType = info.type
	local actionID = info.actionID
	if Constants.IsSpellOrPetBinding(info) and actionID then
		local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
		if rankEntry and rankEntry.slotIndex and rankEntry.spellBank and GameTooltip.SetSpellBookItem then
			GameTooltip:SetSpellBookItem(rankEntry.slotIndex, rankEntry.spellBank)
		elseif GameTooltip.SetSpellByID then
			GameTooltip:SetSpellByID(actionID)
		else
			GameTooltip_SetTitle(GameTooltip, cellData.shortLabel)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L["TOOLTIP_CLICK_BINDING_LABEL"], Constants.GetFullBindingString(info), 0.8, 0.8, 0.8, 1, 1, 1)
		if cellData.isUnlearned then
			GameTooltip:AddDoubleLine(L["TOOLTIP_RANK_STATUS_LABEL"], L["TOOLTIP_STATUS_NOT_LEARNED"], 0.8, 0.8, 0.8, 1.0, 0.33, 0.33)
		end
	else
		GameTooltip_SetTitle(GameTooltip, cellData.shortLabel)
		GameTooltip:AddDoubleLine(L["TOOLTIP_CLICK_BINDING_LABEL"], Constants.GetFullBindingString(info), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	GameTooltip:Show()
end

local function ApplySavedMatrixPosition(f)
	if not f then
		return
	end
	f:ClearAllPoints()
	local pos = Database.Get("matrixWindowPos")
	if type(pos) == "table" and pos.point and pos.relativePoint and type(pos.x) == "number" and type(pos.y) == "number" then
		f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	elseif ClickBindingFrame and ClickBindingFrame:IsShown() then
		f:SetPoint("TOPLEFT", ClickBindingFrame, "TOPRIGHT", 14, -40)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	end
end

function FreeKeysMatrixUI.ResetMatrixPosition()
	Database.Set("matrixWindowPos", nil)
	if freeKeysMatrixFrame then
		ApplySavedMatrixPosition(freeKeysMatrixFrame)
	end
end

local function EnsureFreeKeysMatrixFrame()
	if freeKeysMatrixFrame then
		return freeKeysMatrixFrame
	end

	local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	f:SetSize(586, 320)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetFrameLevel(20)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnMouseDown", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	f:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" and matrixPreviewUnlocked then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ClickBindingUI.ResetMatrixPosition()
		end
	end)
	f:SetScript("OnDragStart", function(self)
		if self.Raise then
			self:Raise()
		end
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
		if point and relativePoint and xOfs and yOfs then
			Database.Set("matrixWindowPos", {
				point = point,
				relativePoint = relativePoint,
				x = math.floor(xOfs + 0.5),
				y = math.floor(yOfs + 0.5),
			})
		end
	end)

	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
		f:SetBackdropColor(0.06, 0.07, 0.10, 0.96)
		f:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
	end

	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
	icon:SetAtlas(Constants.ICON_ATLAS)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	title:SetText(L["MATRIX_POPUP_TITLE"])
	f.Title = title

	local statsText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statsText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -17)
	statsText:SetJustifyH("RIGHT")
	f.StatsText = statsText

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		f:Hide()
	end)

	local colStartX = 104
	local colW = 90
	local colGap = 4
	local rowStartY = -64
	local rowH = 44
	local rowGap = 4

	f.ColHeaders = {}
	for cIdx, col in ipairs(MATRIX_COLUMNS) do
		local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		local x = colStartX + ((cIdx - 1) * (colW + colGap))
		hdr:SetPoint("TOPLEFT", f, "TOPLEFT", x, -44)
		hdr:SetWidth(colW)
		hdr:SetJustifyH("CENTER")
		hdr:SetText("|cffffd100" .. col.short .. "|r")
		f.ColHeaders[cIdx] = hdr
	end

	local pinHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pinHdr:SetPoint("CENTER", f, "TOPLEFT", colStartX + (#MATRIX_COLUMNS * (colW + colGap)) + 20, -49)
	pinHdr:SetWidth(56)
	pinHdr:SetJustifyH("CENTER")
	pinHdr:SetWordWrap(false)
	pinHdr:SetText("|cff99ccff" .. (L["MATRIX_PIN_COL_HEADER"] or "Default") .. "|r")
	pinHdr:Hide()
	f.PinColHeader = pinHdr

	f.RowHeaders = {}
	f.RowPinChecks = {}
	f.Cells = {}
	for rIdx, row in ipairs(MATRIX_MOD_ROWS) do
		local y = rowStartY - ((rIdx - 1) * (rowH + rowGap))
		local rHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		rHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y - 14)
		rHdr:SetWidth(84)
		rHdr:SetJustifyH("LEFT")
		rHdr:SetWordWrap(false)
		rHdr.labelKey = row.labelKey
		rHdr.fallback = row.fallback
		f.RowHeaders[rIdx] = rHdr

		local pinCb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		pinCb:SetSize(22, 22)
		pinCb.modOrder = row.modOrder
		pinCb:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			if Database.SetMatrixRowDefaultVisible then
				Database.SetMatrixRowDefaultVisible(self.modOrder, self:GetChecked() and true or false)
			end
			ClickBindingUI.RefreshFreeKeysMatrix()
		end)
		pinCb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L["MATRIX_PIN_ROW_TOOLTIP_TITLE"])
			GameTooltip_AddNormalLine(GameTooltip, L["MATRIX_PIN_ROW_TOOLTIP_DESC"], true)
			GameTooltip:Show()
		end)
		pinCb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		pinCb:Hide()
		f.RowPinChecks[rIdx] = pinCb

		f.Cells[rIdx] = {}
		for cIdx, col in ipairs(MATRIX_COLUMNS) do
			local x = colStartX + ((cIdx - 1) * (colW + colGap))
			local cell = CreateFrame("Button", nil, f, "BackdropTemplate")
			cell:SetSize(colW, rowH)
			cell:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
			cell.comboLabel = row.shortPrefix .. col.short

			if cell.SetBackdrop then
				cell:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8x8",
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					tile = true,
					tileSize = 8,
					edgeSize = 10,
					insets = { left = 2, right = 2, top = 2, bottom = 2 },
				})
			end

			local cellIcon = cell:CreateTexture(nil, "ARTWORK")
			cellIcon:SetSize(22, 22)
			cellIcon:SetPoint("LEFT", cell, "LEFT", 6, 0)
			cellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			cell.Icon = cellIcon

			local topText = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			topText:SetPoint("TOPLEFT", cellIcon, "TOPRIGHT", 5, -1)
			topText:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
			topText:SetJustifyH("LEFT")
			topText:SetWordWrap(false)
			cell.TopText = topText

			local botText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			botText:SetPoint("BOTTOMLEFT", cellIcon, "BOTTOMRIGHT", 5, 1)
			botText:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
			botText:SetJustifyH("LEFT")
			botText:SetWordWrap(false)
			cell.BotText = botText

			local freeText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			freeText:SetPoint("CENTER", cell, "CENTER", 0, 0)
			freeText:SetJustifyH("CENTER")
			cell.FreeText = freeText

			cell:SetScript("OnEnter", function(self)
				ShowMatrixCellTooltip(self)
			end)
			cell:SetScript("OnLeave", function()
				if GameTooltip then
					GameTooltip:Hide()
				end
			end)

			f.Cells[rIdx][cIdx] = cell
		end
	end

	local comboCb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	comboCb:SetSize(24, 24)
	comboCb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 30)
	local comboLabel = comboCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	comboLabel:SetPoint("LEFT", comboCb, "RIGHT", 4, 0)
	comboLabel:SetJustifyH("LEFT")
	comboCb.Label = comboLabel
	comboCb:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Database.Set("matrixShowCombos", self:GetChecked() and true or false)
		ClickBindingUI.RefreshFreeKeysMatrix()
	end)
	comboCb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["MATRIX_SHOW_COMBOS_CHECKBOX"])
		GameTooltip_AddNormalLine(GameTooltip, L["MATRIX_SHOW_COMBOS_DESC"], true)
		GameTooltip:Show()
	end)
	comboCb:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.ComboCheckbox = comboCb

	local autoOpenCb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	autoOpenCb:SetSize(24, 24)
	autoOpenCb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 282, 30)
	local autoOpenLabel = autoOpenCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	autoOpenLabel:SetPoint("LEFT", autoOpenCb, "RIGHT", 4, 0)
	autoOpenLabel:SetJustifyH("LEFT")
	autoOpenCb.Label = autoOpenLabel
	autoOpenCb:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Database.Set("matrixAutoOpen", self:GetChecked() and true or false)
		ClickBindingUI.RefreshFreeKeysMatrix()
	end)
	autoOpenCb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["MATRIX_AUTO_OPEN_CHECKBOX"])
		GameTooltip_AddNormalLine(GameTooltip, L["MATRIX_AUTO_OPEN_DESC"], true)
		GameTooltip:Show()
	end)
	autoOpenCb:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.AutoOpenCheckbox = autoOpenCb

	local reorderBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	reorderBtn:SetSize(96, 22)
	reorderBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 31)
	reorderBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if ns.SettingsUI and ns.SettingsUI.ToggleReorderWindow then
			ns.SettingsUI.ToggleReorderWindow()
		end
	end)
	reorderBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, L["REORDER_WINDOW_TITLE"])
		GameTooltip_AddNormalLine(GameTooltip, L["SETTINGS_REORDER_DESC"], true)
		GameTooltip:Show()
	end)
	reorderBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	f.ReorderBtn = reorderBtn

	local extraText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	extraText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
	extraText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
	extraText:SetJustifyH("LEFT")
	extraText:SetWordWrap(false)
	f.ExtraText = extraText

	f:Hide()
	freeKeysMatrixFrame = f
	return f
end

local function EnsureMatrixColHeader(f, cIdx)
	if not f.ColHeaders then
		f.ColHeaders = {}
	end
	if f.ColHeaders[cIdx] then
		return f.ColHeaders[cIdx]
	end
	local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hdr:SetWidth(90)
	hdr:SetJustifyH("CENTER")
	f.ColHeaders[cIdx] = hdr
	return hdr
end

local function EnsureMatrixCell(f, rIdx, cIdx)
	if not f.Cells[rIdx] then
		f.Cells[rIdx] = {}
	end
	if f.Cells[rIdx][cIdx] then
		return f.Cells[rIdx][cIdx]
	end
	local cell = CreateFrame("Button", nil, f, "BackdropTemplate")
	cell:SetSize(90, 44)
	if cell.SetBackdrop then
		cell:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
	end

	local cellIcon = cell:CreateTexture(nil, "ARTWORK")
	cellIcon:SetSize(22, 22)
	cellIcon:SetPoint("LEFT", cell, "LEFT", 6, 0)
	cellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cell.Icon = cellIcon

	local topText = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	topText:SetPoint("TOPLEFT", cellIcon, "TOPRIGHT", 5, -1)
	topText:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
	topText:SetJustifyH("LEFT")
	topText:SetWordWrap(false)
	cell.TopText = topText

	local botText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	botText:SetPoint("BOTTOMLEFT", cellIcon, "BOTTOMRIGHT", 5, 1)
	botText:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
	botText:SetJustifyH("LEFT")
	botText:SetWordWrap(false)
	cell.BotText = botText

	local freeText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	freeText:SetPoint("CENTER", cell, "CENTER", 0, 0)
	freeText:SetJustifyH("CENTER")
	cell.FreeText = freeText

	cell:SetScript("OnEnter", function(self)
		ShowMatrixCellTooltip(self)
	end)
	cell:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	f.Cells[rIdx][cIdx] = cell
	return cell
end

function FreeKeysMatrixUI.RefreshFreeKeysMatrix()
	if not freeKeysMatrixFrame or not freeKeysMatrixFrame:IsShown() then
		return
	end
	local f = freeKeysMatrixFrame
	local bindings = CollectCurrentActiveBindings()
	local showCombos = Database.Get("matrixShowCombos") and true or false
	local showMeta = ClickBindingUI.IsMatrixMetaActive(bindings)
	local activeCols = GetCurrentMatrixColumns()
	local orderedRows = ClickBindingUI.GetOrderedMatrixModRows()

	local visibleRows = {}
	local activeModOrders = {}
	for _, item in ipairs(orderedRows) do
		local rIdx = item.rIdx
		local row = item.row
		local isPinned
		if Database.IsMatrixRowDefaultVisible then
			isPinned = Database.IsMatrixRowDefaultVisible(row.modOrder)
		else
			isPinned = not row.isCombo
		end
		if (showMeta or not row.isMeta) and (showCombos or isPinned) then
			table.insert(visibleRows, { rIdx = rIdx, row = row })
			activeModOrders[row.modOrder] = true
		end
	end
	if #visibleRows == 0 and MATRIX_MOD_ROWS[1] then
		table.insert(visibleRows, { rIdx = 1, row = MATRIX_MOD_ROWS[1] })
		activeModOrders[MATRIX_MOD_ROWS[1].modOrder] = true
	end
	local activeRowCount = #visibleRows

	local colCount = #activeCols
	if L["MATRIX_POPUP_TITLE_DYNAMIC_FORMAT"] then
		f.Title:SetText(string.format(L["MATRIX_POPUP_TITLE_DYNAMIC_FORMAT"], activeRowCount, colCount))
	else
		f.Title:SetText(L["MATRIX_POPUP_TITLE"])
	end

	local colStartX = 104
	local colW = 90
	local colGap = 4
	local rowStartY = -64
	local rowH = 44
	local rowGap = 4
	local iconSize = 22
	if activeRowCount > 12 then
		rowH = 30
		rowGap = 2
		iconSize = 18
	elseif activeRowCount > 8 then
		rowH = 34
		rowGap = 3
		iconSize = 20
	end
	local gridRightEdge = colStartX + (colCount * (colW + colGap)) - colGap
	local windowW = math.max(460, gridRightEdge + (showCombos and 64 or 16))
	local windowH = 128 + (activeRowCount * (rowH + rowGap))
	f:SetSize(windowW, windowH)

	for cIdx, col in ipairs(activeCols) do
		local hdr = EnsureMatrixColHeader(f, cIdx)
		local x = colStartX + ((cIdx - 1) * (colW + colGap))
		hdr:ClearAllPoints()
		hdr:SetPoint("TOPLEFT", f, "TOPLEFT", x, -44)
		hdr:SetWidth(colW)
		hdr:SetText("|cffffd100" .. col.short .. "|r")
		hdr:Show()
	end
	if f.ColHeaders then
		for cIdx = colCount + 1, #f.ColHeaders do
			if f.ColHeaders[cIdx] then
				f.ColHeaders[cIdx]:Hide()
			end
		end
	end

	if f.PinColHeader then
		f.PinColHeader:ClearAllPoints()
		f.PinColHeader:SetPoint("CENTER", f, "TOPLEFT", gridRightEdge + 23, -49)
		f.PinColHeader:SetText("|cff99ccff" .. (L["MATRIX_PIN_COL_HEADER"] or "Default") .. "|r")
		f.PinColHeader:SetShown(showCombos)
	end

	if f.ComboCheckbox then
		f.ComboCheckbox:SetChecked(showCombos)
		if f.ComboCheckbox.Label then
			local cbKey = showMeta and "MATRIX_SHOW_COMBOS_META_CHECKBOX" or "MATRIX_SHOW_COMBOS_CHECKBOX"
			f.ComboCheckbox.Label:SetText(L[cbKey] or L["MATRIX_SHOW_COMBOS_CHECKBOX"])
		end
	end
	if f.AutoOpenCheckbox then
		f.AutoOpenCheckbox:SetChecked(Database.Get("matrixAutoOpen") and true or false)
		if f.AutoOpenCheckbox.Label then
			f.AutoOpenCheckbox.Label:SetText(L["MATRIX_AUTO_OPEN_CHECKBOX"])
		end
	end
	if f.ReorderBtn then
		f.ReorderBtn:SetText(L["MATRIX_REORDER_BTN"] or "Reorder")
	end

	local lookup = {}
	local extraList = {}

	local knownCols = {}
	for _, col in ipairs(activeCols) do
		knownCols[col.button] = true
	end

	for _, info in ipairs(bindings) do
		if info and info.button then
			local modOrder = Constants.GetModifierSortInfo(info.modifiers)
			local normBtn = NormalizeMatrixButton(info.button)
			if activeModOrders[modOrder] and knownCols[normBtn] then
				lookup[tostring(modOrder) .. ":" .. tostring(normBtn)] = info
			else
				local shortBind = Constants.GetShortBindingString(info) or "?"
				local cellData = FormatMatrixCellData(info)
				if cellData then
					table.insert(extraList, string.format("|cffffd100%s:|r %s", shortBind, cellData.shortLabel))
				end
			end
		end
	end

	local boundCount = 0
	local totalSlots = activeRowCount * colCount

	local visibleIndexByRIdx = {}
	for vIdx, item in ipairs(visibleRows) do
		visibleIndexByRIdx[item.rIdx] = vIdx
	end

	for rIdx, row in ipairs(MATRIX_MOD_ROWS) do
		local vIdx = visibleIndexByRIdx[rIdx]
		local isRowVisible = (vIdx ~= nil)
		local y = isRowVisible and (rowStartY - ((vIdx - 1) * (rowH + rowGap))) or 0
		local rHdr = f.RowHeaders[rIdx]
		if rHdr then
			if isRowVisible then
				rHdr:ClearAllPoints()
				rHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y - math.floor((rowH - 12) / 2))
				rHdr:SetText("|cffb8d8ff" .. (L[row.labelKey] or row.fallback) .. "|r")
				rHdr:Show()
			else
				rHdr:Hide()
			end
		end
		local pinCb = f.RowPinChecks and f.RowPinChecks[rIdx]
		if pinCb then
			if isRowVisible and showCombos then
				local pinX = gridRightEdge + 12
				pinCb:ClearAllPoints()
				pinCb:SetPoint("TOPLEFT", f, "TOPLEFT", pinX, y - math.floor((rowH - 22) / 2))
				local isPinned = (Database.IsMatrixRowDefaultVisible and Database.IsMatrixRowDefaultVisible(row.modOrder)) or false
				pinCb:SetChecked(isPinned)
				pinCb:Show()
			else
				pinCb:Hide()
			end
		end
		for cIdx, col in ipairs(activeCols) do
			local cell = EnsureMatrixCell(f, rIdx, cIdx)
			if not isRowVisible then
				cell:Hide()
			else
				local x = colStartX + ((cIdx - 1) * (colW + colGap))
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
				cell:SetSize(colW, rowH)
				cell.Icon:SetSize(iconSize, iconSize)
				cell.comboLabel = row.shortPrefix .. col.short
				cell:Show()
				local key = tostring(row.modOrder) .. ":" .. col.button
				local info = lookup[key]
				local cellData = FormatMatrixCellData(info)
				cell.cellData = cellData

				if cellData then
					boundCount = boundCount + 1
					cell.FreeText:Hide()
					cell.Icon:SetTexture(cellData.icon)
					cell.Icon:SetDesaturated(cellData.isUnlearned and true or false)
					cell.Icon:Show()
					if cellData.isUnlearned then
						cell.TopText:SetText("|cff999999" .. cellData.shortLabel .. "|r")
						cell:SetBackdropColor(0.24, 0.08, 0.08, 0.92)
						cell:SetBackdropBorderColor(0.85, 0.28, 0.28, 0.95)
					elseif cellData.isInteraction then
						cell.TopText:SetText("|cffcccccc" .. cellData.shortLabel .. "|r")
						cell:SetBackdropColor(0.11, 0.13, 0.17, 0.90)
						cell:SetBackdropBorderColor(0.38, 0.42, 0.50, 0.85)
					else
						cell.TopText:SetText("|cffffffff" .. cellData.shortLabel .. "|r")
						cell:SetBackdropColor(0.12, 0.15, 0.22, 0.94)
						cell:SetBackdropBorderColor(0.45, 0.58, 0.78, 0.90)
					end
					cell.BotText:SetText(cellData.subLabel or "")
					cell.TopText:Show()
					cell.BotText:Show()
				else
					cell.Icon:Hide()
					cell.TopText:Hide()
					cell.BotText:Hide()
					cell.FreeText:SetText(string.format("|cff40ff59%s|r\n|cff77aa88%s|r", L["MATRIX_CELL_FREE"], cell.comboLabel))
					cell.FreeText:Show()
					cell:SetBackdropColor(0.06, 0.18, 0.09, 0.88)
					cell:SetBackdropBorderColor(0.25, 0.75, 0.38, 0.85)
				end
			end
		end
		if f.Cells[rIdx] then
			for cIdx = colCount + 1, #f.Cells[rIdx] do
				if f.Cells[rIdx][cIdx] then
					f.Cells[rIdx][cIdx]:Hide()
				end
			end
		end
	end

	local freeCount = totalSlots - boundCount
	f.StatsText:SetText(string.format(L["MATRIX_STATS_FORMAT"], boundCount, totalSlots, freeCount))

	if #extraList > 0 then
		f.ExtraText:SetText(string.format(L["MATRIX_EXTRA_BINDINGS_FORMAT"], table.concat(extraList, "  |  ")))
	else
		f.ExtraText:SetText("|cff888888" .. L["MATRIX_FOOTER_HINT"] .. "|r")
	end
end

function FreeKeysMatrixUI.IsMatrixPreviewUnlocked()
	return matrixPreviewUnlocked
end

function FreeKeysMatrixUI.SetMatrixPreviewUnlocked(unlocked)
	local target = unlocked and true or false
	local f = EnsureFreeKeysMatrixFrame()
	if target then
		if not matrixPreviewUnlocked then
			matrixWasShownBeforePreview = f:IsShown()
		end
		matrixPreviewUnlocked = true
		ApplySavedMatrixPosition(f)
		if f.SetBackdropBorderColor then
			f:SetBackdropBorderColor(0.35, 1.0, 0.45, 1.0)
		end
		f:Show()
		if f.Raise then
			f:Raise()
		end
		ClickBindingUI.RefreshFreeKeysMatrix()
	else
		matrixPreviewUnlocked = false
		if f.SetBackdropBorderColor then
			f:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
		end
		if not matrixWasShownBeforePreview and f:IsShown() then
			f:Hide()
		end
		matrixWasShownBeforePreview = false
	end
end

function FreeKeysMatrixUI.HideFreeKeysMatrix()
	matrixPreviewUnlocked = false
	matrixWasShownBeforePreview = false
	if freeKeysMatrixFrame then
		if freeKeysMatrixFrame.SetBackdropBorderColor then
			freeKeysMatrixFrame:SetBackdropBorderColor(0.85, 0.72, 0.40, 1.0)
		end
		if freeKeysMatrixFrame:IsShown() then
			freeKeysMatrixFrame:Hide()
		end
	end
end

function FreeKeysMatrixUI.ShowFreeKeysMatrix()
	if Constants.IsGamepadUIActive() then
		return
	end
	local f = EnsureFreeKeysMatrixFrame()
	ApplySavedMatrixPosition(f)
	f:Show()
	if f.Raise then
		f:Raise()
	end
	ClickBindingUI.RefreshFreeKeysMatrix()
end

function FreeKeysMatrixUI.ToggleFreeKeysMatrix()
	local f = EnsureFreeKeysMatrixFrame()
	if f:IsShown() then
		f:Hide()
		return
	end
	ClickBindingUI.ShowFreeKeysMatrix()
end

function FreeKeysMatrixUI.IsShown()
	return (freeKeysMatrixFrame and freeKeysMatrixFrame:IsShown()) and true or false
end

-- Kompatible Fassade auf ns.ClickBindingUI beibehalten
for k, fn in pairs(FreeKeysMatrixUI) do
	if type(fn) == "function" and k ~= "IsShown" then
		ClickBindingUI[k] = fn
	end
end
