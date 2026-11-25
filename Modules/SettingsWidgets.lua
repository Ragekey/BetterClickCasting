local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Colors = Constants.Colors
local Database = ns.Database

local SettingsWidgets = {}
ns.SettingsWidgets = SettingsWidgets

local THEME = {
	cardBg       = { 0.085, 0.105, 0.150, 0.92 },
	cardBorder   = { 0.24,  0.30,  0.42,  0.80 },
	segBgIdle    = { 0.11,  0.13,  0.19,  0.95 },
	segBgActive  = { 0.28,  0.23,  0.09,  0.98 },
	segBrdIdle   = { 0.25,  0.30,  0.40,  0.75 },
	segBrdActive = { 0.95,  0.78,  0.22,  1.00 },
	btnPrimaryBg = { 0.26,  0.21,  0.08,  0.96 },
	btnPrimaryBr = { 0.90,  0.74,  0.24,  0.95 },
	btnSecBg     = { 0.12,  0.16,  0.23,  0.95 },
	btnSecBr     = { 0.34,  0.44,  0.60,  0.85 },
	btnDangerBg  = { 0.26,  0.09,  0.09,  0.95 },
	btnDangerBr  = { 0.75,  0.26,  0.26,  0.90 },
}
SettingsWidgets.THEME = THEME

local SMALL_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 10,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local CARD_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function SettingsWidgets.ApplyBoxBackdrop(frame, bg, brd, isCard)
	if not frame or not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop(isCard and CARD_BACKDROP or SMALL_BACKDROP)
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(brd[1], brd[2], brd[3], brd[4] or 1)
end

local function StripColorCodes(text)
	if type(text) ~= "string" then
		return ""
	end
	local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return s
end
SettingsWidgets.StripColorCodes = StripColorCodes

--------------------------------------------------------------------------------
-- Karten-Container mit automatischem Höhen-Tracking
--------------------------------------------------------------------------------

function SettingsWidgets.CreateCard(parent, titleKey, topY, width)
	local cardWidth = width or 486
	local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	card:SetWidth(cardWidth)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, topY)
	SettingsWidgets.ApplyBoxBackdrop(card, THEME.cardBg, THEME.cardBorder, true)

	local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -11)
	header:SetJustifyH("LEFT")
	card.HeaderText = header
	card.titleKey = titleKey

	local line = card:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -30)
	line:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -30)
	line:SetColorTexture(0.45, 0.52, 0.68, 0.28)
	card.Divider = line

	card.cursorY = -38
	card.innerWidth = cardWidth - 28

	function card:Advance(height, gap)
		local used = self.cursorY
		self.cursorY = self.cursorY - height - (gap or 6)
		return used
	end

	function card:Finalize(bottomPad)
		local totalH = math.abs(self.cursorY) + (bottomPad or 8)
		self:SetHeight(totalH)
		return topY - totalH - 10
	end

	card.RefreshValue = function(self)
		if self.titleKey then
			self.HeaderText:SetText("|cffffd100" .. (L[self.titleKey] or self.titleKey) .. "|r")
		end
		if self.disabledHintText and self.enabledFunc then
			local en = self.enabledFunc()
			self.disabledHintText:SetShown(not en)
		end
	end
	card:RefreshValue()

	return card
end

--------------------------------------------------------------------------------
-- Stil-Buttons (Primary / Secondary / Danger)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateStyledButton(parent, width, height, getTextFunc, onClickFunc, variant, tooltipDescKey)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetSize(width or 140, height or 24)
	btn:RegisterForClicks("LeftButtonUp")

	local bg, brd = THEME.btnSecBg, THEME.btnSecBr
	if variant == "primary" then
		bg, brd = THEME.btnPrimaryBg, THEME.btnPrimaryBr
	elseif variant == "danger" then
		bg, brd = THEME.btnDangerBg, THEME.btnDangerBr
	end
	btn.baseBg, btn.baseBrd = bg, brd
	SettingsWidgets.ApplyBoxBackdrop(btn, bg, brd, false)

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 2, -2)
	hl:SetPoint("BOTTOMRIGHT", -2, 2)
	hl:SetColorTexture(1, 1, 1, 0.09)

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", btn, "LEFT", 6, 0)
	fs:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
	fs:SetJustifyH("CENTER")
	fs:SetWordWrap(false)
	btn.Text = fs

	btn:SetScript("OnClick", function(self)
		if not self:IsEnabled() then
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if onClickFunc then
			onClickFunc(self)
		end
	end)

	btn:SetScript("OnEnter", function(self)
		if self:IsEnabled() and self.SetBackdropBorderColor then
			self:SetBackdropBorderColor(1.0, 0.86, 0.38, 1.0)
		end
		if tooltipDescKey and L[tooltipDescKey] then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, StripColorCodes(getTextFunc and getTextFunc() or ""))
			GameTooltip_AddNormalLine(GameTooltip, L[tooltipDescKey], true)
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function(self)
		if self.SetBackdropBorderColor then
			self:SetBackdropBorderColor(self.baseBrd[1], self.baseBrd[2], self.baseBrd[3], self.baseBrd[4] or 1)
		end
		GameTooltip:Hide()
	end)

	btn.RefreshValue = function(self)
		local txt = getTextFunc and getTextFunc() or ""
		self.Text:SetText(txt)
		if variant == "primary" then
			self.Text:SetTextColor(1.0, 0.88, 0.35)
		elseif variant == "danger" then
			self.Text:SetTextColor(1.0, 0.55, 0.55)
		else
			self.Text:SetTextColor(0.90, 0.94, 1.0)
		end
	end
	btn:RefreshValue()

	return btn
end

--------------------------------------------------------------------------------
-- Toggle-Zeile (Checkbox + Titel + 1-zeilige Kurzbeschreibung + Abhängigkeits-Dimming)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateToggleRow(card, spec)
	local hasSub = (spec.descKey ~= nil)
	local rowH = hasSub and 36 or 24
	local y = card:Advance(rowH, 4)

	local row = CreateFrame("Button", nil, card)
	row:SetSize(card.innerWidth, rowH)
	row:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
	row:RegisterForClicks("LeftButtonUp")

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.04)

	local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	cb:SetSize(22, 22)
	cb:SetPoint("TOPLEFT", row, "TOPLEFT", -2, hasSub and -1 or -1)

	local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", row, "TOPLEFT", 24, hasSub and -2 or -5)
	title:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	row.Title = title

	if hasSub then
		local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
		sub:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		sub:SetJustifyH("LEFT")
		sub:SetWordWrap(false)
		row.Sub = sub
	end

	local function GetVal()
		if spec.getter then
			return spec.getter() and true or false
		end
		return Database.Get(spec.dbKey) and true or false
	end

	local function SetVal(v)
		if spec.setter then
			spec.setter(v)
		elseif spec.dbKey then
			Database.Set(spec.dbKey, v)
		end
	end

	local function ToggleAction()
		if spec.enabledFunc and not spec.enabledFunc() then
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		SetVal(not GetVal())
	end

	cb:SetScript("OnClick", function(self)
		if spec.enabledFunc and not spec.enabledFunc() then
			self:SetChecked(GetVal())
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		SetVal(self:GetChecked() and true or false)
	end)
	row:SetScript("OnClick", ToggleAction)

	local function ShowTip(owner)
		if spec.descKey and L[spec.descKey] then
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, L[spec.labelKey] or spec.labelKey)
			GameTooltip_AddNormalLine(GameTooltip, L[spec.descKey], true)
			GameTooltip:Show()
		end
	end
	row:SetScript("OnEnter", ShowTip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cb:SetScript("OnEnter", function() ShowTip(row) end)
	cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

	row.RefreshValue = function(self)
		local enabled = (not spec.enabledFunc) or spec.enabledFunc()
		local checked = GetVal()
		cb:SetChecked(checked)
		cb:SetEnabled(enabled)
		self:SetAlpha(enabled and 1.0 or 0.38)
		self.Title:SetText(L[spec.labelKey] or spec.labelKey)
		if checked then
			self.Title:SetTextColor(1.0, 0.96, 0.84)
		else
			self.Title:SetTextColor(0.84, 0.86, 0.90)
		end
		if self.Sub and spec.descKey then
			self.Sub:SetText(StripColorCodes(L[spec.descKey] or ""))
		end
	end
	row:RefreshValue()

	return row
end

--------------------------------------------------------------------------------
-- 1-Klick Segmented Control (ersetzt versteckte Radio-Dropdowns)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateSegmentedRow(card, spec)
	local rowH = 44
	local y = card:Advance(rowH, 6)

	local container = CreateFrame("Frame", nil, card)
	container:SetSize(card.innerWidth, rowH)
	container:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	label:SetJustifyH("LEFT")
	container.Label = label

	local options = spec.options or {}
	local count = math.max(1, #options)
	local gap = 4
	local segWidth = math.floor((card.innerWidth - ((count - 1) * gap)) / count)
	container.Buttons = {}

	local function GetVal()
		if spec.getter then
			return spec.getter()
		end
		return Database.Get(spec.dbKey) or spec.defaultValue
	end

	local function SetVal(v)
		if spec.setter then
			spec.setter(v)
		elseif spec.dbKey then
			Database.Set(spec.dbKey, v)
		end
	end

	for i, opt in ipairs(options) do
		local seg = CreateFrame("Button", nil, container, "BackdropTemplate")
		seg:SetSize(segWidth, 24)
		seg:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * (segWidth + gap), -18)
		seg:RegisterForClicks("LeftButtonUp")
		SettingsWidgets.ApplyBoxBackdrop(seg, THEME.segBgIdle, THEME.segBrdIdle, false)

		local hl = seg:CreateTexture(nil, "HIGHLIGHT")
		hl:SetPoint("TOPLEFT", 2, -2)
		hl:SetPoint("BOTTOMRIGHT", -2, 2)
		hl:SetColorTexture(1, 1, 1, 0.07)

		local fs = seg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", seg, "LEFT", 4, 0)
		fs:SetPoint("RIGHT", seg, "RIGHT", -4, 0)
		fs:SetJustifyH("CENTER")
		fs:SetWordWrap(false)
		seg.Text = fs
		seg.opt = opt

		seg:SetScript("OnClick", function()
			if spec.enabledFunc and not spec.enabledFunc() then
				return
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			SetVal(opt.value)
		end)

		seg:SetScript("OnEnter", function(self)
			local tipTitle = L[opt.labelKey or opt.shortKey or spec.labelKey] or ""
			local tipDesc = (opt.descKey and L[opt.descKey]) or (spec.descKey and L[spec.descKey])
			if tipDesc then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip_SetTitle(GameTooltip, tipTitle)
				GameTooltip_AddNormalLine(GameTooltip, tipDesc, true)
				GameTooltip:Show()
			end
		end)
		seg:SetScript("OnLeave", function() GameTooltip:Hide() end)

		container.Buttons[i] = seg
	end

	container.RefreshValue = function(self)
		local enabled = (not spec.enabledFunc) or spec.enabledFunc()
		self:SetAlpha(enabled and 1.0 or 0.38)
		self.Label:SetText(L[spec.labelKey] or spec.labelKey)
		self.Label:SetTextColor(0.75, 0.82, 0.94)
		local cur = GetVal()
		for _, seg in ipairs(self.Buttons) do
			local active = (seg.opt.value == cur)
			seg:SetEnabled(enabled)
			local txtKey = seg.opt.shortKey or seg.opt.labelKey
			seg.Text:SetText(L[txtKey] or txtKey or tostring(seg.opt.value))
			if active then
				SettingsWidgets.ApplyBoxBackdrop(seg, THEME.segBgActive, THEME.segBrdActive, false)
				seg.Text:SetTextColor(1.0, 0.86, 0.25)
			else
				SettingsWidgets.ApplyBoxBackdrop(seg, THEME.segBgIdle, THEME.segBrdIdle, false)
				seg.Text:SetTextColor(0.80, 0.84, 0.90)
			end
		end
	end
	container:RefreshValue()

	return container
end

--------------------------------------------------------------------------------
-- Slider-Zeile mit +/- Fein-Schaltflächen & Abhängigkeits-Dimming
--------------------------------------------------------------------------------

function SettingsWidgets.CreateSliderRow(card, spec)
	local rowH = 42
	local y = card:Advance(rowH, 6)

	local container = CreateFrame("Frame", nil, card)
	container:SetSize(card.innerWidth, rowH)
	container:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	title:SetJustifyH("LEFT")
	container.Title = title

	local minusBtn = SettingsWidgets.CreateStyledButton(container, 22, 18, function() return "-" end, nil, "secondary")
	minusBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -18)

	local plusBtn = SettingsWidgets.CreateStyledButton(container, 22, 18, function() return "+" end, nil, "secondary")
	plusBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -18)

	local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetHeight(12)
	slider:SetPoint("LEFT", minusBtn, "RIGHT", 8, 0)
	slider:SetPoint("RIGHT", plusBtn, "LEFT", -8, 0)
	slider:SetMinMaxValues(spec.minVal, spec.maxVal)
	slider:SetValueStep(spec.stepVal)
	slider:SetObeyStepOnDrag(true)
	SettingsWidgets.ApplyBoxBackdrop(slider, { 0.05, 0.07, 0.11, 0.96 }, { 0.35, 0.42, 0.56, 0.85 }, false)

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(14, 18)
	thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	slider:SetThumbTexture(thumb)

	local isSyncing = false
	local function ApplySliderVal(rawVal)
		local rounded = math.floor((rawVal / spec.stepVal) + 0.5) * spec.stepVal
		rounded = math.max(spec.minVal, math.min(spec.maxVal, rounded))
		title:SetText(string.format(L[spec.formatKey] or "%d%%", rounded))
		if not isSyncing then
			Database.Set(spec.dbKey, rounded)
		end
	end

	slider:SetScript("OnValueChanged", function(_, value)
		ApplySliderVal(value)
	end)
	minusBtn:SetScript("OnClick", function()
		if spec.enabledFunc and not spec.enabledFunc() then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local cur = tonumber(Database.Get(spec.dbKey)) or spec.minVal
		Database.Set(spec.dbKey, math.max(spec.minVal, cur - spec.stepVal))
	end)
	plusBtn:SetScript("OnClick", function()
		if spec.enabledFunc and not spec.enabledFunc() then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local cur = tonumber(Database.Get(spec.dbKey)) or spec.minVal
		Database.Set(spec.dbKey, math.min(spec.maxVal, cur + spec.stepVal))
	end)

	container.RefreshValue = function(self)
		local enabled = (not spec.enabledFunc) or spec.enabledFunc()
		self:SetAlpha(enabled and 1.0 or 0.38)
		slider:SetEnabled(enabled)
		minusBtn:SetEnabled(enabled)
		plusBtn:SetEnabled(enabled)
		isSyncing = true
		local val = tonumber(Database.Get(spec.dbKey)) or spec.minVal
		val = math.max(spec.minVal, math.min(spec.maxVal, val))
		slider:SetValue(val)
		title:SetText(string.format(L[spec.formatKey] or "%d%%", val))
		isSyncing = false
	end
	container:RefreshValue()

	return container
end

--------------------------------------------------------------------------------
-- Live-Vorschau 1: Originalgetreue ClickBindingFrame-Zeile (2-zeilig + Gruppen-Header)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateLineLivePreview(card)
	local isDownrankPreview = true

	local toggleBtn = SettingsWidgets.CreateStyledButton(
		card,
		148,
		20,
		function()
			return isDownrankPreview and L["UX_PREVIEW_TOGGLE_DOWNRANK"] or L["UX_PREVIEW_TOGGLE_MAX"]
		end,
		function(self)
			isDownrankPreview = not isDownrankPreview
			if card.previewFrame and card.previewFrame.RefreshValue then
				card.previewFrame:RefreshValue()
			end
			self:RefreshValue()
		end,
		"secondary"
	)
	toggleBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -7)

	local y = card:Advance(74, 4)
	local holder = CreateFrame("Frame", nil, card)
	holder:SetSize(card.innerWidth, 74)
	holder:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	-- Echter Untergruppen-Header wie im ClickBindingFrame
	local groupHdr = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	groupHdr:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -2)
	groupHdr:SetJustifyH("LEFT")

	-- Originales 2-zeiliges ClickBindingLineTemplate-Layout (450px breit)
	local mockRow = CreateFrame("Frame", nil, holder)
	mockRow:SetWidth(math.min(450, card.innerWidth - 4))
	mockRow:SetPoint("TOP", holder, "TOP", 0, -22)

	local rowBg = mockRow:CreateTexture(nil, "BACKGROUND")
	rowBg:SetAtlas("ClickCastList-ButtonBackground")
	rowBg:SetPoint("TOPLEFT", mockRow, "TOPLEFT", 0, 0)
	rowBg:SetPoint("BOTTOMRIGHT", mockRow, "BOTTOMRIGHT", 0, 0)

	local icon = mockRow:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("LEFT", mockRow, "LEFT", 0, 0)
	icon:SetTexture(135907)

	local nameFS = mockRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameFS:SetJustifyH("LEFT")
	nameFS:SetWordWrap(false)

	local bindFS = mockRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bindFS:SetJustifyH("LEFT")
	bindFS:SetWordWrap(false)

	-- Obere Zeile rechts: Freistehendes Augen-Icon ("friends-icon-eye") + Manakosten links daneben
	local eyeHolder = CreateFrame("Frame", nil, mockRow)
	eyeHolder:SetSize(22, 18)
	local eyeIcon = eyeHolder:CreateTexture(nil, "ARTWORK")
	eyeIcon:SetAtlas("friends-icon-eye")
	eyeIcon:SetPoint("CENTER", eyeHolder, "CENTER", 0, 0)
	eyeIcon:SetVertexColor(0.55, 0.90, 1.0)

	local manaFS = mockRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	manaFS:SetJustifyH("RIGHT")
	manaFS:SetWordWrap(false)

	-- Untere Zeile rechts: Gestylter DeleteButton ("groupfinder-icon-redx") + BCCRankButton links daneben
	local delBtn = CreateFrame("Frame", nil, mockRow)
	local delBg = delBtn:CreateTexture(nil, "BACKGROUND")
	delBg:SetAtlas("common-dropdown-c-button")
	delBg:SetPoint("TOPLEFT", -2, 2)
	delBg:SetPoint("BOTTOMRIGHT", 2, -2)
	local delIcon = delBtn:CreateTexture(nil, "ARTWORK")
	delIcon:SetAtlas("groupfinder-icon-redx", true)
	delIcon:SetPoint("CENTER", 0, 0)
	delIcon:SetScale(0.8)

	local rankBtn = CreateFrame("Frame", nil, mockRow)
	local rankBg = rankBtn:CreateTexture(nil, "BACKGROUND")
	rankBg:SetAtlas("common-dropdown-c-button")
	rankBg:SetPoint("TOPLEFT", -2, 2)
	rankBg:SetPoint("BOTTOMRIGHT", 2, -2)
	local rankArrow = rankBtn:CreateTexture(nil, "OVERLAY")
	rankArrow:SetAtlas("common-dropdown-a-button")
	rankArrow:SetSize(10, 10)
	rankArrow:SetPoint("RIGHT", rankBtn, "RIGHT", -5, -1)
	local rankText = rankBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rankText:SetPoint("LEFT", rankBtn, "LEFT", 6, 0)
	rankText:SetPoint("RIGHT", rankArrow, "LEFT", -2, 0)
	rankText:SetJustifyH("CENTER")
	rankText:SetWordWrap(false)

	holder.RefreshValue = function()
		toggleBtn:RefreshValue()
		local compact = Database.Get("compactListMode") and true or false
		local showRank = Database.Get("showRankInName")
		local hlDown = Database.Get("highlightDownranks")
		local showSwitcher = Database.Get("showRankSwitcher")
		local showMana = Database.Get("showLineManaCost")
		local smartRules = Database.Get("enableSmartRankRules")
		local groupMode = Database.Get("groupingMode") or "modifier"
		local hoverOn = (Database.Get("unitHoverMode") or "off") ~= "off"

		-- Gruppen-Header oberhalb der Zeile live passend zu groupingMode anzeigen
		if groupMode == "none" then
			groupHdr:Hide()
			mockRow:ClearAllPoints()
			mockRow:SetPoint("CENTER", holder, "CENTER", 0, 0)
		else
			local gTitle = ""
			if groupMode == "modifier" then
				gTitle = string.format(L["GROUP_HDR_MOD_FORMAT"] or "%s", "Shift")
			elseif groupMode == "button" then
				local btnDisp = (Constants.GetButtonDisplayName and Constants.GetButtonDisplayName("LeftButton")) or "Left Button"
				gTitle = string.format("%s (LMB)", btnDisp)
			else
				gTitle = L["GROUP_HDR_SPELLS"] or "Spells"
			end
			groupHdr:SetText(string.format("%s%s%s  %s(1)%s", Colors.HEADER_SUB, gTitle, Colors.RESET, Colors.MUTED, Colors.RESET))
			groupHdr:Show()
			mockRow:ClearAllPoints()
			mockRow:SetPoint("TOP", holder, "TOP", 0, -20)
		end

		-- Exakte Metriken aus ApplyLineCompactMetrics (ClickBindingUI.lua:1376-1383)
		local lineH = compact and 32 or 46
		local iconSz = compact and 26 or 35
		local topRowY = compact and 6 or 9
		local botRowY = compact and -6 or -8
		local btnH = compact and 15 or 18
		local delW = compact and 20 or 22
		local rankW = compact and 88 or 92

		mockRow:SetHeight(lineH)
		icon:SetSize(iconSz, iconSz)
		nameFS:SetFontObject(compact and "GameFontNormalSmall" or "GameFontNormal")

		-- Obere Zeile: Name links, Auge + Mana rechts
		eyeHolder:SetSize(delW, btnH)
		eyeIcon:SetSize(compact and 12 or 14, compact and 12 or 14)
		eyeHolder:ClearAllPoints()
		eyeHolder:SetPoint("RIGHT", mockRow, "RIGHT", -6, topRowY)
		eyeHolder:SetShown(hoverOn)

		manaFS:SetText("|cff80c8ff" .. L["UX_PREVIEW_MANA"] .. "|r")
		manaFS:ClearAllPoints()
		if hoverOn then
			manaFS:SetPoint("RIGHT", eyeHolder, "LEFT", -4, 0)
		else
			manaFS:SetPoint("RIGHT", mockRow, "RIGHT", -8, topRowY)
		end
		manaFS:SetShown(showMana and true or false)

		local baseName = L["UX_PREVIEW_SPELL_NAME"]
		local subtext = isDownrankPreview and L["UX_PREVIEW_RANK_DOWN"] or L["UX_PREVIEW_RANK_MAX"]
		local formattedName = baseName
		if showRank then
			if hlDown then
				if not isDownrankPreview then
					formattedName = string.format("%s %s(%s)%s %s%s%s", baseName, Colors.RANK_MAX, subtext, Colors.RESET, Colors.TAG_MAX, L["TAG_MAX"], Colors.RESET)
				else
					local maxHint = L["MAX_RANK_HINT_FORMAT"] and string.format(L["MAX_RANK_HINT_FORMAT"], 4) or ""
					formattedName = string.format("%s %s(%s%s)%s", baseName, Colors.RANK_DOWN, subtext, maxHint, Colors.RESET)
				end
			else
				formattedName = string.format("%s %s(%s)%s", baseName, Colors.RANK_MAX, subtext, Colors.RESET)
			end
		end
		nameFS:SetText(formattedName)
		nameFS:ClearAllPoints()
		nameFS:SetPoint("LEFT", icon, "RIGHT", 5, topRowY)
		if showMana then
			nameFS:SetPoint("RIGHT", manaFS, "LEFT", -6, 0)
		elseif hoverOn then
			nameFS:SetPoint("RIGHT", eyeHolder, "LEFT", -6, 0)
		else
			nameFS:SetPoint("RIGHT", mockRow, "RIGHT", -8, topRowY)
		end

		-- Untere Zeile: BindingText links, RankSwitcher + DeleteButton rechts
		local fullBind = (Constants.GetFullBindingString and Constants.GetFullBindingString({ button = "LeftButton", modifiers = 1 })) or "SHIFT - Left Button"
		bindFS:SetText(fullBind)
		bindFS:ClearAllPoints()
		bindFS:SetPoint("LEFT", icon, "RIGHT", 5, botRowY)

		delBtn:SetSize(delW, btnH)
		delBtn:ClearAllPoints()
		delBtn:SetPoint("RIGHT", mockRow, "RIGHT", -6, botRowY)

		rankBtn:SetSize(rankW, btnH)
		rankBtn:ClearAllPoints()
		rankBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
		if showSwitcher then
			local shortRank = isDownrankPreview and "R2" or "R4"
			local shortTag = isDownrankPreview and (L["TAG_RULE_FIX_SHORT"] or "FIX") or (L["TAG_MAX_SHORT"] or "MAX")
			if smartRules then
				if hlDown and not isDownrankPreview then
					rankText:SetText(string.format("%s%s (%s)%s", Colors.TAG_MAX, shortRank, shortTag, Colors.RESET))
					rankBg:SetVertexColor(0.82, 1.0, 0.85, 1.0)
				elseif hlDown and isDownrankPreview then
					rankText:SetText(string.format("%s%s (%s)%s", Colors.RANK_DOWN, shortRank, shortTag, Colors.RESET))
					rankBg:SetVertexColor(1.0, 0.88, 0.72, 1.0)
				else
					rankText:SetText(string.format("%s%s (%s)%s", Colors.RANK_MAX, shortRank, shortTag, Colors.RESET))
					rankBg:SetVertexColor(1.0, 1.0, 1.0, 1.0)
				end
			else
				rankText:SetText(string.format("%s%s%s", isDownrankPreview and Colors.RANK_DOWN or Colors.RANK_MAX, shortRank, Colors.RESET))
				rankBg:SetVertexColor(1.0, 1.0, 1.0, 1.0)
			end
			rankBtn:Show()
		else
			rankBtn:Hide()
		end
	end

	card.previewFrame = holder
	holder:RefreshValue()
	return holder
end

--------------------------------------------------------------------------------
-- Live-Vorschau 2: Originalgetreue SpellBookItemTemplate-Slots + BCCBindBadge
--------------------------------------------------------------------------------

function SettingsWidgets.CreateSpellbookLivePreview(card)
	local y = card:Advance(68, 4)
	local holder = CreateFrame("Frame", nil, card)
	holder:SetSize(card.innerWidth, 68)
	holder:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	-- Pergament-Hintergrund im Stil von PlayerSpellsFrame.SpellBookFrame
	local pageBg = CreateFrame("Frame", nil, holder, "BackdropTemplate")
	pageBg:SetAllPoints(holder)
	SettingsWidgets.ApplyBoxBackdrop(pageBg, { 0.14, 0.11, 0.08, 0.85 }, { 0.42, 0.34, 0.22, 0.80 }, false)

	local function MakeMockSpellBookItem(xOffset, rankKey, modLine, btnLine)
		local item = CreateFrame("Frame", nil, pageBg)
		item:SetSize(214, 56)
		item:SetPoint("TOPLEFT", pageBg, "TOPLEFT", xOffset, -8)

		local backplate = item:CreateTexture(nil, "BACKGROUND")
		backplate:SetAtlas("spellbook-item-backplate", true)
		backplate:SetAlpha(0.35)
		backplate:SetPoint("CENTER", item, "CENTER", 5, -3)

		local iconBtn = CreateFrame("Frame", nil, item)
		iconBtn:SetSize(37, 37)
		iconBtn:SetPoint("LEFT", item, "LEFT", 6, -2)

		local icon = iconBtn:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints(iconBtn)
		icon:SetTexture(135907)

		local iconBorder = iconBtn:CreateTexture(nil, "OVERLAY", nil, 1)
		iconBorder:SetAtlas("spellbook-item-iconframe")
		iconBorder:SetPoint("TOPLEFT", iconBtn, "TOPLEFT", -4, 4)
		iconBorder:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", 4, -4)

		local qbHighlight = iconBtn:CreateTexture(nil, "OVERLAY", nil, 2)
		qbHighlight:SetAtlas("clickcast-highlight-binding", true)
		qbHighlight:SetBlendMode("ADD")
		qbHighlight:SetPoint("CENTER", iconBtn, "CENTER", 0, 0)
		qbHighlight:SetScale(0.92)
		item.QuickBindGlow = qbHighlight

		-- Originales BCCBindBadge (SpellBookUI.lua:135-171): sitzt oben mittig AUF der Icon-Kante!
		local badgeFrame = CreateFrame("Frame", nil, iconBtn)
		badgeFrame:SetSize(44, modLine and 20 or 14)
		badgeFrame:SetPoint("BOTTOM", icon, "TOP", 0, -2)
		badgeFrame:SetFrameLevel(iconBtn:GetFrameLevel() + 6)

		local bBg = badgeFrame:CreateTexture(nil, "OVERLAY", nil, 1)
		bBg:SetAtlas("common-dropdown-c-button")
		bBg:SetVertexColor(0.06, 0.09, 0.13, 0.96)
		bBg:SetPoint("TOPLEFT", badgeFrame, "TOPLEFT", -4, 4)
		bBg:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", 4, -4)

		local fontPath, fontSize = GameFontNormalSmall:GetFont()
		local baseSz = (fontSize and math.max(9, fontSize - 1)) or 10
		local smallSz = math.max(8, baseSz - 1)

		if modLine then
			local topFs = badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			if fontPath then topFs:SetFont(fontPath, smallSz, "OUTLINE") end
			topFs:SetPoint("TOP", badgeFrame, "TOP", 0, -1)
			topFs:SetText(Colors.MUTED .. modLine .. Colors.RESET)
		end

		local botFs = badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		if fontPath then botFs:SetFont(fontPath, baseSz, "OUTLINE") end
		botFs:SetPoint("BOTTOM", badgeFrame, "BOTTOM", 0, 1)
		botFs:SetText(Colors.BIND_BADGE .. btnLine .. Colors.RESET)
		item.Badge = badgeFrame

		local nameFs = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		nameFs:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -3)
		nameFs:SetPoint("RIGHT", item, "RIGHT", -4, 0)
		nameFs:SetJustifyH("LEFT")
		nameFs:SetWordWrap(false)
		nameFs:SetTextColor(1.0, 0.88, 0.55)
		item.Name = nameFs

		local subFs = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		subFs:SetPoint("TOPLEFT", nameFs, "BOTTOMLEFT", 0, -2)
		subFs:SetJustifyH("LEFT")
		subFs:SetTextColor(0.78, 0.72, 0.60)
		item.Sub = subFs
		item.rankKey = rankKey
		return item
	end

	local slotMax = MakeMockSpellBookItem(8, "UX_PREVIEW_RANK_MAX", "SHIFT", "LMB")
	local slotDown = MakeMockSpellBookItem(236, "UX_PREVIEW_RANK_DOWN", nil, "MMB")

	holder.RefreshValue = function()
		local qb = Database.Get("quickBindSpellbook")
		local badges = Database.Get("showSpellbookBadges")
		local allRanks = Database.Get("autoShowAllRanks")

		for _, s in ipairs({ slotMax, slotDown }) do
			s.Name:SetText(L["UX_PREVIEW_SPELL_NAME"])
			s.Sub:SetText(L[s.rankKey])
			s.QuickBindGlow:SetShown(qb and true or false)
			s.Badge:SetShown(badges and true or false)
		end
		slotDown:SetShown(allRanks and true or false)
	end
	holder:RefreshValue()
	return holder
end

--------------------------------------------------------------------------------
-- Live-Vorschau 3a: Echte Unit-Frame Hover-Karte (Seite 4: Hover-Overlay)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateHoverOverlayLivePreview(card)
	local y = card:Advance(112, 4)
	local stage = CreateFrame("Frame", nil, card, "BackdropTemplate")
	stage:SetSize(card.innerWidth, 112)
	stage:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
	stage:SetClipsChildren(true)
	SettingsWidgets.ApplyBoxBackdrop(stage, { 0.035, 0.045, 0.07, 0.92 }, { 0.22, 0.28, 0.38, 0.75 }, false)

	-- Exakter Nachbau von hoverCard aus Modules/UnitHoverTooltip.lua:556-785
	local mockCard = CreateFrame("Frame", nil, stage, "BackdropTemplate")
	mockCard:SetPoint("CENTER", stage, "CENTER", 0, 0)
	mockCard:SetBackdrop(CARD_BACKDROP)

	local hdrLeft = mockCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hdrLeft:SetPoint("TOPLEFT", mockCard, "TOPLEFT", 10, -8)
	hdrLeft:SetJustifyH("LEFT")

	local hdrRight = mockCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hdrRight:SetPoint("TOPRIGHT", mockCard, "TOPRIGHT", -10, -8)
	hdrRight:SetJustifyH("RIGHT")

	local div = mockCard:CreateTexture(nil, "ARTWORK")
	div:SetHeight(1)
	div:SetPoint("TOPLEFT", mockCard, "TOPLEFT", 8, -23)
	div:SetPoint("TOPRIGHT", mockCard, "TOPRIGHT", -8, -23)
	div:SetColorTexture(0.65, 0.55, 0.30, 0.35)

	local rows = {}
	for i = 1, 3 do
		local r = {
			Key   = mockCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
			Spell = mockCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
			Right = mockCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"),
		}
		r.Key:SetJustifyH("LEFT")
		r.Spell:SetJustifyH("LEFT")
		r.Right:SetJustifyH("RIGHT")
		rows[i] = r
	end

	stage.RefreshValue = function()
		local mode = Database.Get("unitHoverMode") or "off"
		local scalePct = tonumber(Database.Get("unitHoverScale")) or 100
		local alphaPct = tonumber(Database.Get("unitHoverAlpha")) or 94
		local showMana = Database.Get("unitHoverShowMana") and true or false
		local showTags = Database.Get("unitHoverShowRankTags") and true or false
		local showRange = Database.Get("unitHoverShowRange") and true or false

		mockCard:SetBackdropColor(0.06, 0.07, 0.10, math.max(0.30, math.min(1.0, alphaPct / 100)))
		mockCard:SetBackdropBorderColor(0.65, 0.55, 0.30, 0.90)
		mockCard:SetAlpha((mode == "off") and 0.40 or 1.0)

		-- Sanft geklemmte Live-Skalierung innerhalb der Vorschau-Bühne, damit die Karte nie den Rahmen sprengt
		local previewScale = math.max(0.75, math.min(1.16, scalePct / 100))
		mockCard:SetScale(previewScale)

		hdrLeft:SetText("|cffffd100" .. (L["UNITHOVER_HDR_PREFIX"] or "Click Cast") .. "|r")
		hdrRight:SetText("|cff40ff40Shift|r")

		local sName = L["UX_PREVIEW_SPELL_NAME"]
		local rMax = L["UX_PREVIEW_RANK_MAX"]
		local rDown = L["UX_PREVIEW_RANK_DOWN"]
		local tagMax = showTags and (" " .. Colors.TAG_MAX .. L["TAG_MAX"] .. Colors.RESET) or ""
		local tagDown = showTags and (" " .. Colors.RANK_DOWN .. string.format(L["UNITHOVER_TAG_DOWNRANK_FORMAT"] or "[-%d]", 2) .. Colors.RESET) or ""

		local rowDefs = {
			{
				key = Colors.BIND_BADGE .. "LMB|r",
				spell = string.format("|T135907:14:14:0:0:64:64:4:60:4:60|t |cffffffff%s|r %s(%s)%s%s", sName, Colors.RANK_MAX, rMax, Colors.RESET, tagMax),
				mana = "|cff80c8ff215 Mana|r",
			},
			{
				key = Colors.BIND_BADGE .. "RMB|r",
				spell = string.format("|T135953:14:14:0:0:64:64:4:60:4:60|t |cffffffff%s|r %s(%s)%s%s", sName, Colors.RANK_DOWN, rDown, Colors.RESET, tagDown),
				mana = "|cff80c8ff" .. L["UX_PREVIEW_MANA"] .. "|r",
			},
		}

		if showRange then
			table.insert(rowDefs, {
				key = Colors.WARN_UNLEARNED .. "MMB|r",
				spell = string.format("|T135987:14:14:0:0:64:64:4:60:4:60:255:130:130|t |cff777777%s (%s)|r%s %s%s|r", sName, rMax, tagMax, Colors.WARN_UNLEARNED, L["UNITHOVER_TAG_OOR"] or "[OOR]"),
				mana = "|cff777777305 Mana|r",
			})
		else
			table.insert(rowDefs, {
				key = Colors.BIND_BADGE .. "MMB|r",
				spell = string.format("|T135987:14:14:0:0:64:64:4:60:4:60|t |cffffffff%s|r %s(%s)%s%s", sName, Colors.RANK_MAX, rMax, Colors.RESET, tagMax),
				mana = "|cff80c8ff305 Mana|r",
			})
		end

		local maxRowW = 190
		local keyColW = 34
		local spellColX = 10 + keyColW + 8
		local yOff = -29

		for i, def in ipairs(rowDefs) do
			local r = rows[i]
			r.Key:SetText(def.key)
			r.Spell:SetText(def.spell)
			r.Right:SetText(showMana and def.mana or "")

			r.Key:ClearAllPoints()
			r.Key:SetPoint("TOPLEFT", mockCard, "TOPLEFT", 10, yOff)
			r.Spell:ClearAllPoints()
			r.Spell:SetPoint("TOPLEFT", mockCard, "TOPLEFT", spellColX, yOff)
			r.Right:ClearAllPoints()
			r.Right:SetPoint("TOPRIGHT", mockCard, "TOPRIGHT", -10, yOff)

			local sw = r.Spell:GetStringWidth() or 120
			local rw = showMana and ((r.Right:GetStringWidth() or 55) + 16) or 0
			local totalW = spellColX + sw + rw
			if totalW > maxRowW then
				maxRowW = totalW
			end
			yOff = yOff - 17
		end

		mockCard:SetSize(math.min(390, maxRowW + 14), math.abs(yOff) + 7)
	end
	stage:RefreshValue()
	return stage
end

--------------------------------------------------------------------------------
-- Live-Vorschau 3b: Visuelles Anker-Schaubild für das Hover-Overlay (Seite 4)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateHoverAnchorDiagram(card)
	local y = card:Advance(106, 6)
	local wrap = CreateFrame("Frame", nil, card)
	wrap:SetSize(card.innerWidth, 106)
	wrap:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	local unitBox = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
	unitBox:SetSize(134, 42)
	unitBox:SetPoint("CENTER", wrap, "LEFT", 155, -2)
	SettingsWidgets.ApplyBoxBackdrop(unitBox, { 0.08, 0.22, 0.13, 0.95 }, { 0.35, 0.72, 0.45, 0.95 }, false)

	local unitLabel = unitBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	unitLabel:SetPoint("CENTER", 0, 0)

	local anchorDefs = {
		{ value = "top",    shortKey = "UNITHOVER_ANCHOR_TOP_SHORT",    point = "BOTTOM", rel = unitBox, relPoint = "TOP",    x = 0,  y = 5,  w = 76 },
		{ value = "bottom", shortKey = "UNITHOVER_ANCHOR_BOTTOM_SHORT", point = "TOP",    rel = unitBox, relPoint = "BOTTOM", x = 0,  y = -5, w = 76 },
		{ value = "left",   shortKey = "UNITHOVER_ANCHOR_LEFT_SHORT",   point = "RIGHT",  rel = unitBox, relPoint = "LEFT",   x = -6, y = 0,  w = 72 },
		{ value = "right",  shortKey = "UNITHOVER_ANCHOR_RIGHT_SHORT",  point = "LEFT",   rel = unitBox, relPoint = "RIGHT",  x = 6,  y = 0,  w = 72 },
		{ value = "cursor", shortKey = "UNITHOVER_ANCHOR_CURSOR_SHORT", point = "TOPLEFT", rel = wrap,   relPoint = "TOPLEFT", x = 330, y = -22, w = 126 },
		{ value = "free",   shortKey = "UNITHOVER_ANCHOR_FREE_SHORT",   point = "TOPLEFT", rel = wrap,   relPoint = "TOPLEFT", x = 330, y = -54, w = 126 },
	}

	local buttons = {}
	for _, def in ipairs(anchorDefs) do
		local b = CreateFrame("Button", nil, wrap, "BackdropTemplate")
		b:SetSize(def.w, 22)
		b:SetPoint(def.point, def.rel, def.relPoint, def.x, def.y)
		b:RegisterForClicks("LeftButtonUp")
		b.def = def
		SettingsWidgets.ApplyBoxBackdrop(b, THEME.segBgIdle, THEME.segBrdIdle, false)

		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("CENTER", 0, 0)
		b.Text = fs

		b:SetScript("OnClick", function()
			if Database.Get("unitHoverMode") == "off" then
				return
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			Database.Set("unitHoverAnchor", def.value)
		end)
		buttons[#buttons + 1] = b
	end

	wrap.RefreshValue = function(self)
		local enabled = (Database.Get("unitHoverMode") ~= "off")
		self:SetAlpha(enabled and 1.0 or 0.38)
		unitLabel:SetText(L["UX_ANCHOR_UNITFRAME_BOX"])
		local cur = Database.Get("unitHoverAnchor") or "cursor"
		for _, b in ipairs(buttons) do
			b:SetEnabled(enabled)
			b.Text:SetText(L[b.def.shortKey] or b.def.value)
			if b.def.value == cur then
				SettingsWidgets.ApplyBoxBackdrop(b, THEME.segBgActive, THEME.segBrdActive, false)
				b.Text:SetTextColor(1.0, 0.86, 0.25)
			else
				SettingsWidgets.ApplyBoxBackdrop(b, THEME.segBgIdle, THEME.segBrdIdle, false)
				b.Text:SetTextColor(0.82, 0.86, 0.92)
			end
		end
	end
	wrap:RefreshValue()
	return wrap
end
