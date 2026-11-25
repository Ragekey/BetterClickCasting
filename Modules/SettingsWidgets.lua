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
-- Live-Vorschau 1: Echte Klickbelegungs-Musterzeile (Seite 1)
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

	local y = card:Advance(48, 4)
	local holder = CreateFrame("Frame", nil, card)
	holder:SetSize(card.innerWidth, 48)
	holder:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	local mockRow = CreateFrame("Frame", nil, holder, "BackdropTemplate")
	mockRow:SetPoint("LEFT", holder, "LEFT", 0, 0)
	mockRow:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
	SettingsWidgets.ApplyBoxBackdrop(mockRow, { 0.05, 0.06, 0.09, 0.96 }, { 0.34, 0.40, 0.52, 0.90 }, false)

	local icon = mockRow:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("LEFT", mockRow, "LEFT", 8, 0)
	icon:SetTexture(135907)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local spellText = mockRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	spellText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	spellText:SetJustifyH("LEFT")

	local bindText = mockRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bindText:SetPoint("RIGHT", mockRow, "RIGHT", -10, 0)
	bindText:SetText("|cffffd100SHIFT-LMB|r")

	local eyeTex = mockRow:CreateTexture(nil, "ARTWORK")
	eyeTex:SetSize(15, 15)
	eyeTex:SetPoint("RIGHT", bindText, "LEFT", -8, 0)
	eyeTex:SetAtlas("Raid-Icon-SummonPending")
	eyeTex:SetAlpha(0.85)

	local rankPill = CreateFrame("Frame", nil, mockRow, "BackdropTemplate")
	rankPill:SetSize(64, 18)
	rankPill:SetPoint("RIGHT", eyeTex, "LEFT", -6, 0)
	SettingsWidgets.ApplyBoxBackdrop(rankPill, { 0.14, 0.17, 0.24, 0.95 }, { 0.50, 0.58, 0.72, 0.90 }, false)
	local rankPillText = rankPill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rankPillText:SetPoint("CENTER", 0, 0)

	local manaText = mockRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	manaText:SetText("|cff66bbff" .. L["UX_PREVIEW_MANA"] .. "|r")

	holder.RefreshValue = function()
		toggleBtn:RefreshValue()
		local compact = Database.Get("compactListMode")
		local showRank = Database.Get("showRankInName")
		local hlDown = Database.Get("highlightDownranks")
		local showSwitcher = Database.Get("showRankSwitcher")
		local showMana = Database.Get("showLineManaCost")
		local smartRules = Database.Get("enableSmartRankRules")

		mockRow:SetHeight(compact and 30 or 44)
		icon:SetSize(compact and 22 or 30, compact and 22 or 30)

		local baseName = L["UX_PREVIEW_SPELL_NAME"]
		local rLabel = isDownrankPreview and L["UX_PREVIEW_RANK_DOWN"] or L["UX_PREVIEW_RANK_MAX"]
		local namePart = baseName
		if showRank then
			local rColor = (isDownrankPreview and hlDown) and Colors.RANK_DOWN or (not isDownrankPreview and Colors.RANK_MAX or "|cffcccccc")
			namePart = string.format("%s %s(%s)%s", baseName, rColor, rLabel, Colors.RESET)
		elseif isDownrankPreview and hlDown then
			namePart = Colors.RANK_DOWN .. baseName .. Colors.RESET
		end
		spellText:SetText(namePart)

		manaText:SetText("|cff66bbff" .. L["UX_PREVIEW_MANA"] .. "|r")
		manaText:SetShown(showMana and true or false)

		if showSwitcher then
			rankPill:Show()
			local shortR = isDownrankPreview and "R2" or "R4"
			if smartRules then
				local tag = isDownrankPreview and (Colors.RANK_DOWN .. (L["TAG_RULE_FIX_SHORT"] or "FIX") .. Colors.RESET)
					or (Colors.TAG_MAX .. (L["TAG_MAX_SHORT"] or "MAX") .. Colors.RESET)
				rankPillText:SetText(shortR .. " " .. tag)
				rankPill:SetWidth(68)
			else
				rankPillText:SetText(shortR .. " v")
				rankPill:SetWidth(44)
			end
			manaText:ClearAllPoints()
			manaText:SetPoint("RIGHT", rankPill, "LEFT", -8, 0)
		else
			rankPill:Hide()
			manaText:ClearAllPoints()
			manaText:SetPoint("RIGHT", eyeTex, "LEFT", -8, 0)
		end
	end

	card.previewFrame = holder
	holder:RefreshValue()
	return holder
end

--------------------------------------------------------------------------------
-- Live-Vorschau 2: Zauberbuch-Musterslots (Seite 2)
--------------------------------------------------------------------------------

function SettingsWidgets.CreateSpellbookLivePreview(card)
	local y = card:Advance(54, 4)
	local holder = CreateFrame("Frame", nil, card)
	holder:SetSize(card.innerWidth, 54)
	holder:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)

	local function MakeMockSlot(xOffset, rankKey, badgeLabel)
		local slot = CreateFrame("Frame", nil, holder, "BackdropTemplate")
		slot:SetSize(218, 48)
		slot:SetPoint("TOPLEFT", holder, "TOPLEFT", xOffset, -2)
		SettingsWidgets.ApplyBoxBackdrop(slot, { 0.06, 0.07, 0.10, 0.95 }, { 0.30, 0.34, 0.44, 0.85 }, false)

		local icon = slot:CreateTexture(nil, "ARTWORK")
		icon:SetSize(34, 34)
		icon:SetPoint("LEFT", slot, "LEFT", 8, 0)
		icon:SetTexture(135907)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		local qbBorder = slot:CreateTexture(nil, "OVERLAY")
		qbBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
		qbBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
		qbBorder:SetColorTexture(0.25, 1.0, 0.45, 0.22)
		slot.QuickBindGlow = qbBorder

		local badge = CreateFrame("Frame", nil, slot, "BackdropTemplate")
		badge:SetSize(42, 15)
		badge:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -6, -5)
		SettingsWidgets.ApplyBoxBackdrop(badge, { 0.06, 0.24, 0.12, 0.95 }, { 0.30, 0.90, 0.45, 0.95 }, false)
		local bText = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bText:SetPoint("CENTER", 0, 0)
		bText:SetText("|cff40ff59" .. badgeLabel .. "|r")
		slot.Badge = badge

		local name = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -3)
		name:SetJustifyH("LEFT")
		slot.Name = name

		local sub = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
		sub:SetJustifyH("LEFT")
		slot.Sub = sub
		slot.rankKey = rankKey
		return slot
	end

	local slotMax = MakeMockSlot(0, "UX_PREVIEW_RANK_MAX", "S-LMB")
	local slotDown = MakeMockSlot(232, "UX_PREVIEW_RANK_DOWN", "MMB")

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
		slotDown:SetAlpha(allRanks and 1.0 or 0.28)
	end
	holder:RefreshValue()
	return holder
end

--------------------------------------------------------------------------------
-- Live-Vorschau 3: Visuelles Anker-Schaubild für das Hover-Overlay (Seite 4)
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
