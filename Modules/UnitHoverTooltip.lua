local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Database = ns.Database
local SpellRanks = ns.SpellRanks
local Colors = Constants.Colors

local UnitHoverTooltip = {}
ns.UnitHoverTooltip = UnitHoverTooltip

local ShortButtonNames = {
	LeftButton = "LMB",
	Button1 = "LMB",
	RightButton = "RMB",
	Button2 = "RMB",
	MiddleButton = "MMB",
	Button3 = "MMB",
}

local hoverCard = nil
local eventFrame = nil
local isTrackingActive = false
local isMoveUnlocked = false
local isDraggingCard = false
local lastHoveredUnitFrame = nil
local lastModifierMask = -1
local pollElapsed = 0
local POLL_INTERVAL = 0.05

local function GetShortButtonName(buttonName)
	if not buttonName then
		return "?"
	end
	if ShortButtonNames[buttonName] then
		return ShortButtonNames[buttonName]
	end
	local num = string.match(buttonName, "Button(%d+)")
	return num and ("MB" .. num) or buttonName
end

local function GetCurrentModifierMask()
	if MakeModifiers then
		return MakeModifiers() or 0
	end
	if C_ClickBindings and C_ClickBindings.MakeModifiers then
		return C_ClickBindings.MakeModifiers() or 0
	end
	return 0
end

local function IsAnyModifierDown()
	local mask = GetCurrentModifierMask()
	if mask ~= 0 then
		return true
	end
	return (IsShiftKeyDown and IsShiftKeyDown())
		or (IsControlKeyDown and IsControlKeyDown())
		or (IsAltKeyDown and IsAltKeyDown())
		or false
end

local function IsPlayerInCombat()
	return (InCombatLockdown and InCombatLockdown())
		or (UnitAffectingCombat and UnitAffectingCombat("player"))
		or false
end

local function IsFreeMoveActive()
	if isMoveUnlocked then
		return true
	end
	if (Database.Get("unitHoverMode") or "off") == "off" then
		return false
	end
	if (Database.Get("unitHoverAnchor") or "cursor") ~= "free" then
		return false
	end
	return (ClickBindingFrame and ClickBindingFrame:IsShown()) and true or false
end

function UnitHoverTooltip.IsMoveUnlocked()
	return isMoveUnlocked
end

function UnitHoverTooltip.SetMoveUnlocked(unlocked)
	isMoveUnlocked = unlocked and true or false
	UnitHoverTooltip.UpdateTrackingState()
	if ns.SettingsUI and ns.SettingsUI.RefreshWindow then
		ns.SettingsUI.RefreshWindow()
	end
end

function UnitHoverTooltip.ResetPosition()
	if type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.unitHoverPos = nil
	end
	if hoverCard and hoverCard:IsShown() then
		EvaluateHoverState(true)
	end
end

local function GetModifierHeaderText(modMask)
	if modMask == 0 then
		return L["UNITHOVER_NO_MODIFIER"]
	end
	local _, readable = Constants.GetModifierSortInfo(modMask)
	if readable and readable ~= "" then
		return readable
	end
	return L["UNITHOVER_NO_MODIFIER"]
end

local function IsLikelyUnitFrameByName(frame)
	local okName, name = pcall(frame.GetName, frame)
	if not okName or type(name) ~= "string" or name == "" then
		return false
	end
	if string.find(name, "^CompactPartyFrameMember")
		or string.find(name, "^CompactRaidFrame")
		or string.find(name, "^CompactRaidGroup")
		or string.find(name, "^PlayerFrame")
		or string.find(name, "^TargetFrame")
		or string.find(name, "^FocusFrame")
		or string.find(name, "^PartyMemberFrame")
		or string.find(name, "^PetFrame") then
		return true
	end
	return false
end

-- Ermittelt passiv und ohne Schreibzugriff das aktuell gehoverte UnitFrame.
-- Wandert bei Unter-Frames (z. B. Buff-Icons oder HealthBars) bis zum äußersten UnitFrame
-- derselben Einheit hoch, damit Kanten-Anker (Top/Bottom/Left/Right) nicht an Buff-Icons springen.
-- Ignoriert 3D-Namensplaketten (nameplate*), damit das Overlay nur auf echten HUD-UnitFrames erscheint.
local function ExtractUnitFromFrame(frame)
	if SecureButton_GetUnit then
		local ok, res = pcall(SecureButton_GetUnit, frame)
		if ok and type(res) == "string" and res ~= "" then
			if not canaccessvalue or canaccessvalue(res) then
				return res
			end
		end
	end
	local okUnit, rawUnit = pcall(function()
		return frame.unit or frame.displayedUnit
	end)
	if okUnit and type(rawUnit) == "string" and rawUnit ~= "" then
		if not canaccessvalue or canaccessvalue(rawUnit) then
			return rawUnit
		end
	end
	return nil
end

local function FindHoveredUnitFrame()
	local foci = GetMouseFoci and GetMouseFoci()
	local topFrame = foci and foci[1]
	if not topFrame and GetMouseFocus then
		topFrame = GetMouseFocus()
	end
	if not topFrame or topFrame == WorldFrame or topFrame == UIParent then
		return nil
	end

	local matchedFrame = nil
	local matchedUnit = nil
	local current = topFrame

	for _ = 1, 8 do
		if not current or current == UIParent or current == WorldFrame then
			break
		end
		if current.IsForbidden and current:IsForbidden() then
			break
		end

		local unit = ExtractUnitFromFrame(current)
		if unit and string.find(unit, "^nameplate") then
			return nil
		end

		if unit then
			if (UnitExists and UnitExists(unit))
				or (EditModeManagerFrame and EditModeManagerFrame:IsShown())
				or IsLikelyUnitFrameByName(current) then
				if not matchedUnit or unit == matchedUnit then
					matchedFrame = current
					matchedUnit = unit
				end
			end
		elseif not matchedFrame and (EditModeManagerFrame and EditModeManagerFrame:IsShown()) and IsLikelyUnitFrameByName(current) then
			matchedFrame = current
		end

		local okParent, parent = pcall(current.GetParent, current)
		current = okParent and parent or nil
	end

	return matchedFrame
end

local function CollectBindingsForModifier(modMask)
	local list = {}
	local includeInteractions = Database.Get("unitHoverShowInteractions") and true or false

	local function TryAddBinding(bindingInfo)
		if not bindingInfo or not bindingInfo.button then
			return
		end
		local bindMod = tonumber(bindingInfo.modifiers) or 0
		if bindMod ~= modMask then
			return
		end
		if Enum and Enum.ClickBindingType and bindingInfo.type == Enum.ClickBindingType.Interaction and not includeInteractions then
			return
		end
		table.insert(list, bindingInfo)
	end

	if ClickBindingFrame and ClickBindingFrame:IsShown() and ClickBindingFrame.dataProvider then
		for _, element in ClickBindingFrame.dataProvider:Enumerate() do
			if element and not element.unbound and element.bindingInfo then
				TryAddBinding(element.bindingInfo)
			end
		end
	elseif C_ClickBindings and C_ClickBindings.GetProfileInfo then
		local profile = C_ClickBindings.GetProfileInfo()
		if type(profile) == "table" then
			for _, bindingInfo in ipairs(profile) do
				TryAddBinding(bindingInfo)
			end
		end
	end

	table.sort(list, function(a, b)
		local orderA = Constants.GetButtonSortOrder(a.button)
		local orderB = Constants.GetButtonSortOrder(b.button)
		if orderA ~= orderB then
			return orderA < orderB
		end
		return tostring(a.button) < tostring(b.button)
	end)

	return list
end

local function FormatBindingRowData(bindingInfo)
	local btnShort = GetShortButtonName(bindingInfo.button)
	local bType = bindingInfo.type
	local actionID = bindingInfo.actionID

	if Constants.IsSpellOrPetBinding(bindingInfo) and actionID then
		local rankEntry = SpellRanks.GetRankEntryForAction(actionID)
		local spellName = (rankEntry and rankEntry.name) or SpellRanks.GetSpellBaseNameForAction(actionID) or "?"
		local iconID = SpellRanks.GetSpellIconForAction(actionID)
		local subtext = (rankEntry and rankEntry.subName) or SpellRanks.GetSpellSubtextForAction(actionID)
		if (not subtext or subtext == "") and rankEntry and rankEntry.rankNum then
			subtext = string.format(L["RANK_FALLBACK_FORMAT"], rankEntry.rankNum)
		end

		local rankStatusTag = ""
		if Database.Get("unitHoverShowRankTags") and rankEntry and rankEntry.group and #rankEntry.group.entries > 1 then
			local maxEntry = rankEntry.group.maxEntry
			if maxEntry and maxEntry.actionID == actionID then
				rankStatusTag = " " .. Colors.TAG_MAX .. L["TAG_MAX"] .. Colors.RESET
			elseif maxEntry and maxEntry.rankIndex and rankEntry.rankIndex then
				local diff = math.max(1, maxEntry.rankIndex - rankEntry.rankIndex)
				rankStatusTag = " " .. Colors.RANK_DOWN .. string.format(L["UNITHOVER_TAG_DOWNRANK_FORMAT"], diff) .. Colors.RESET
			end
		end

		local insufficientPower = false
		if C_Spell and C_Spell.IsSpellUsable then
			local _, noMana = C_Spell.IsSpellUsable(actionID)
			insufficientPower = noMana and true or false
		end

		local costStr = ""
		if Database.Get("unitHoverShowMana") then
			costStr = SpellRanks.GetSpellPowerCostString(actionID) or ""
		end
		local iconPrefix = iconID and string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t ", tostring(iconID)) or ""

		local namePart = spellName
		if subtext and subtext ~= "" then
			if insufficientPower then
				namePart = string.format("|cff777777%s (%s)|r", spellName, subtext)
			else
				local rankColor = (rankEntry and rankEntry.isLowRank) and Colors.RANK_DOWN or Colors.RANK_MAX
				namePart = string.format("|cffffffff%s|r %s(%s)%s", spellName, rankColor, subtext, Colors.RESET)
			end
		else
			if insufficientPower then
				namePart = "|cff777777" .. spellName .. "|r"
			else
				namePart = "|cffffffff" .. spellName .. "|r"
			end
		end

		local btnColor = insufficientPower and "|cff777777" or Colors.BIND_BADGE
		local keyText = string.format("%s%s|r", btnColor, btnShort)
		local spellText = string.format("%s%s%s", iconPrefix, namePart, rankStatusTag)

		local rightText = ""
		if costStr ~= "" then
			if insufficientPower then
				rightText = "|cffff5555" .. costStr .. "|r"
			else
				rightText = "|cff80c8ff" .. costStr .. "|r"
			end
		end

		return keyText, spellText, rightText
	elseif Enum and Enum.ClickBindingType and bType == Enum.ClickBindingType.Macro and actionID then
		local macroName, macroIcon = GetMacroInfo and GetMacroInfo(actionID)
		macroName = macroName or MACRO or "Macro"
		local iconPrefix = macroIcon and string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t ", tostring(macroIcon)) or ""
		local keyText = string.format("%s%s|r", Colors.BIND_BADGE, btnShort)
		local spellText = string.format("%s|cffffffff%s|r", iconPrefix, macroName)
		local rightText = Colors.MUTED .. (L["GROUP_HDR_MACROS"] or "Macro") .. Colors.RESET
		return keyText, spellText, rightText
	elseif Enum and Enum.ClickBindingType and bType == Enum.ClickBindingType.Interaction and actionID then
		local interactionName = "?"
		if Enum.ClickBindingInteraction and actionID == Enum.ClickBindingInteraction.Target then
			interactionName = CLICK_BINDING_TARGET_UNIT or "Target Unit"
		elseif Enum.ClickBindingInteraction and actionID == Enum.ClickBindingInteraction.OpenContextMenu then
			interactionName = CLICK_BINDING_OPEN_MENU or "Open Menu"
		end
		local keyText = string.format("%s%s|r", Colors.BIND_BADGE, btnShort)
		local spellText = string.format("|cffcccccc%s|r", interactionName)
		return keyText, spellText, ""
	end

	return string.format("%s%s|r", Colors.BIND_BADGE, btnShort), "", ""
end

local function SaveFreeCardPosition(card)
	local point, _, relativePoint, xOfs, yOfs = card:GetPoint(1)
	if point and type(BetterClickCastingDB) == "table" then
		BetterClickCastingDB.unitHoverPos = {
			point = point,
			relativePoint = relativePoint or point,
			x = xOfs or 0,
			y = yOfs or 0,
		}
	end
end

local function ApplySavedFreePosition(card)
	local pos = (type(BetterClickCastingDB) == "table") and BetterClickCastingDB.unitHoverPos or nil
	if type(pos) == "table" and pos.point then
		card:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
	else
		card:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
	end
end

local function EnsureHoverCard()
	if hoverCard then
		return hoverCard
	end

	-- Komplett passives, maus-durchlässiges Overlay-Frame (0 % Taint auf GameTooltip oder UnitFrames)
	local card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	card:SetFrameStrata("TOOLTIP")
	card:SetFrameLevel(120)
	card:SetClampedToScreen(true)
	card:SetMovable(true)
	card:EnableMouse(false)
	card:RegisterForDrag("LeftButton")

	card:SetScript("OnDragStart", function(self)
		if IsFreeMoveActive() then
			isDraggingCard = true
			self:StartMoving()
		end
	end)

	card:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		isDraggingCard = false
		SaveFreeCardPosition(self)
		if (Database.Get("unitHoverAnchor") or "cursor") ~= "free" then
			Database.Set("unitHoverAnchor", "free")
		end
	end)

	card:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" and IsFreeMoveActive() then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			UnitHoverTooltip.ResetPosition()
		end
	end)

	if card.SetBackdrop then
		card:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 8,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		card:SetBackdropColor(0.06, 0.07, 0.10, 0.94)
		card:SetBackdropBorderColor(0.65, 0.55, 0.30, 0.90)
	end

	local headerLeft = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerLeft:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
	headerLeft:SetJustifyH("LEFT")
	card.HeaderLeft = headerLeft

	local headerRight = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	headerRight:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
	headerRight:SetJustifyH("RIGHT")
	card.HeaderRight = headerRight

	local divider = card:CreateTexture(nil, "ARTWORK")
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -23)
	divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -23)
	divider:SetColorTexture(0.65, 0.55, 0.30, 0.35)
	card.Divider = divider

	local dragHint = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	dragHint:SetJustifyH("CENTER")
	dragHint:Hide()
	card.DragHint = dragHint

	card.Rows = {}
	card:Hide()
	hoverCard = card
	return card
end

local function EnsureCardRow(card, index)
	local row = card.Rows[index]
	if row then
		return row
	end

	row = {}
	local keyFS = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyFS:SetJustifyH("LEFT")
	row.Key = keyFS

	local spellFS = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spellFS:SetJustifyH("LEFT")
	row.Spell = spellFS

	local rightFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rightFS:SetJustifyH("RIGHT")
	row.Right = rightFS

	card.Rows[index] = row
	return row
end

local function UpdateCardPosition(card, unitFrame)
	if isDraggingCard then
		return
	end

	local anchorMode = Database.Get("unitHoverAnchor") or "cursor"
	card:ClearAllPoints()

	if anchorMode == "free" or IsFreeMoveActive() then
		ApplySavedFreePosition(card)
	elseif anchorMode == "cursor" or not unitFrame then
		local x, y = GetCursorPosition()
		local effScale = card:GetEffectiveScale()
		if not effScale or effScale <= 0 then
			effScale = UIParent:GetEffectiveScale()
		end
		card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / effScale) + 18, (y / effScale) - 18)
	elseif anchorMode == "top" then
		card:SetPoint("BOTTOM", unitFrame, "TOP", 0, 6)
	elseif anchorMode == "bottom" then
		card:SetPoint("TOP", unitFrame, "BOTTOM", 0, -6)
	elseif anchorMode == "left" then
		card:SetPoint("RIGHT", unitFrame, "LEFT", -6, 0)
	elseif anchorMode == "right" then
		card:SetPoint("LEFT", unitFrame, "RIGHT", 6, 0)
	else
		card:SetPoint("BOTTOM", unitFrame, "TOP", 0, 6)
	end
end

local function RenderHoverCard(unitFrame, modMask)
	local card = EnsureHoverCard()
	local modLabel = GetModifierHeaderText(modMask)
	local bindings = CollectBindingsForModifier(modMask)
	local freeMove = IsFreeMoveActive()

	local scalePct = tonumber(Database.Get("unitHoverScale")) or 100
	scalePct = math.max(70, math.min(150, scalePct))
	card:SetScale(scalePct / 100)

	local alphaPct = tonumber(Database.Get("unitHoverAlpha")) or 94
	alphaPct = math.max(30, math.min(100, alphaPct))

	card:EnableMouse(freeMove)
	if card.SetBackdropColor then
		card:SetBackdropColor(0.06, 0.07, 0.10, alphaPct / 100)
	end
	if card.SetBackdropBorderColor then
		if freeMove then
			card:SetBackdropBorderColor(0.35, 1.0, 0.45, 0.95)
		else
			card:SetBackdropBorderColor(0.65, 0.55, 0.30, 0.90)
		end
	end

	if isMoveUnlocked then
		card.HeaderLeft:SetText("|cff55ff66" .. L["UNITHOVER_PREVIEW_HEADER"] .. "|r")
	else
		card.HeaderLeft:SetText("|cffffd100" .. L["UNITHOVER_HDR_PREFIX"] .. "|r")
	end
	if modMask == 0 then
		card.HeaderRight:SetText(Colors.MUTED .. modLabel .. Colors.RESET)
	else
		card.HeaderRight:SetText("|cff40ff40" .. modLabel .. "|r")
	end

	for _, existingRow in ipairs(card.Rows) do
		existingRow.Key:Hide()
		existingRow.Spell:Hide()
		existingRow.Right:Hide()
	end

	local maxRowWidth = (card.HeaderLeft:GetStringWidth() or 70) + (card.HeaderRight:GetStringWidth() or 70) + 24
	local yOffset = -29
	local rowCount = #bindings

	if rowCount == 0 and isMoveUnlocked then
		local previewRows = {
			{ key = Colors.BIND_BADGE .. "LMB|r", spell = "|T135907:14:14:0:0:64:64:4:60:4:60|t |cffffffff" .. L["UNITHOVER_PREVIEW_ROW_1"] .. "|r " .. Colors.TAG_MAX .. L["TAG_MAX"] .. Colors.RESET, right = "|cff80c8ff215 Mana|r" },
			{ key = Colors.BIND_BADGE .. "RMB|r", spell = "|T135953:14:14:0:0:64:64:4:60:4:60|t |cffffffff" .. L["UNITHOVER_PREVIEW_ROW_2"] .. "|r " .. Colors.TAG_MAX .. L["TAG_MAX"] .. Colors.RESET, right = "|cff80c8ff305 Mana|r" },
		}
		local maxKeyColWidth = 34
		local spellColX = 10 + maxKeyColWidth + 8
		for i, pRow in ipairs(previewRows) do
			local row = EnsureCardRow(card, i)
			row.Key:SetText(pRow.key)
			row.Spell:SetText(pRow.spell)
			row.Right:SetText(Database.Get("unitHoverShowMana") and pRow.right or "")

			row.Key:ClearAllPoints()
			row.Key:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
			row.Key:Show()

			row.Spell:ClearAllPoints()
			row.Spell:SetPoint("TOPLEFT", card, "TOPLEFT", spellColX, yOffset)
			row.Spell:Show()

			row.Right:ClearAllPoints()
			row.Right:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, yOffset)
			row.Right:Show()

			local spellW = row.Spell:GetStringWidth() or 90
			local rightW = (row.Right:GetText() ~= "" and ((row.Right:GetStringWidth() or 0) + 16)) or 0
			local combinedW = (maxKeyColWidth + 8) + spellW + rightW
			if combinedW > maxRowWidth then
				maxRowWidth = combinedW
			end
			yOffset = yOffset - 17
		end
	elseif rowCount == 0 then
		local emptyRow = EnsureCardRow(card, 1)
		emptyRow.Key:ClearAllPoints()
		emptyRow.Key:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
		emptyRow.Key:SetText(Colors.MUTED .. string.format(L["UNITHOVER_EMPTY_MODIFIER_FORMAT"], modLabel) .. Colors.RESET)
		emptyRow.Key:Show()
		emptyRow.Spell:SetText("")
		emptyRow.Spell:Hide()
		emptyRow.Right:SetText("")
		emptyRow.Right:Hide()

		local w = (emptyRow.Key:GetStringWidth() or 120)
		if w > maxRowWidth then
			maxRowWidth = w
		end
		yOffset = yOffset - 18
	else
		local maxKeyColWidth = 30
		for i, bindingInfo in ipairs(bindings) do
			local row = EnsureCardRow(card, i)
			local keyText, spellText, rightText = FormatBindingRowData(bindingInfo)

			row.Key:SetText(keyText)
			row.Spell:SetText(spellText)
			row.Right:SetText(rightText)

			local keyW = row.Key:GetStringWidth() or 28
			if keyW > maxKeyColWidth then
				maxKeyColWidth = keyW
			end
		end

		local spellColX = 10 + maxKeyColWidth + 8
		for i = 1, rowCount do
			local row = EnsureCardRow(card, i)

			row.Key:ClearAllPoints()
			row.Key:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
			row.Key:Show()

			row.Spell:ClearAllPoints()
			row.Spell:SetPoint("TOPLEFT", card, "TOPLEFT", spellColX, yOffset)
			row.Spell:Show()

			row.Right:ClearAllPoints()
			row.Right:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, yOffset)
			row.Right:Show()

			local spellW = row.Spell:GetStringWidth() or 90
			local rightW = (row.Right:GetText() ~= "" and ((row.Right:GetStringWidth() or 0) + 16)) or 0
			local combinedW = (maxKeyColWidth + 8) + spellW + rightW
			if combinedW > maxRowWidth then
				maxRowWidth = combinedW
			end

			yOffset = yOffset - 17
		end
	end

	if freeMove and card.DragHint then
		yOffset = yOffset - 4
		card.DragHint:ClearAllPoints()
		card.DragHint:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
		card.DragHint:SetText("|cff55ff66" .. L["UNITHOVER_DRAG_HINT"] .. "|r")
		card.DragHint:Show()
		local hintW = card.DragHint:GetStringWidth() or 140
		if hintW > maxRowWidth then
			maxRowWidth = hintW
		end
		yOffset = yOffset - 16
	elseif card.DragHint then
		card.DragHint:Hide()
	end

	card:SetSize(math.max(190, maxRowWidth + 24), math.abs(yOffset) + 7)
	UpdateCardPosition(card, unitFrame)
	card:Show()
end

local function HideHoverCard()
	if isDraggingCard and hoverCard then
		hoverCard:StopMovingOrSizing()
		isDraggingCard = false
	end
	lastHoveredUnitFrame = nil
	lastModifierMask = -1
	if hoverCard and hoverCard:IsShown() then
		hoverCard:EnableMouse(false)
		hoverCard:Hide()
	end
end

local function EvaluateHoverState(forceRedraw)
	local mode = Database.Get("unitHoverMode") or "off"
	local freeMove = IsFreeMoveActive()

	if mode == "off" and not freeMove then
		HideHoverCard()
		return
	end

	-- Standardmäßig im Kampf ausgeblendet, sofern "Auch im Kampf anzeigen" nicht aktiviert ist
	if IsPlayerInCombat() and not Database.Get("unitHoverShowInCombat") then
		HideHoverCard()
		return
	end

	if freeMove then
		local modMask = GetCurrentModifierMask()
		if forceRedraw or modMask ~= lastModifierMask or not (hoverCard and hoverCard:IsShown()) then
			lastModifierMask = modMask
			RenderHoverCard(nil, modMask)
		end
		return
	end

	if mode == "modifier" and not IsAnyModifierDown() then
		HideHoverCard()
		return
	end

	local unitFrame = FindHoveredUnitFrame()
	if not unitFrame then
		HideHoverCard()
		return
	end

	local modMask = GetCurrentModifierMask()
	if forceRedraw or unitFrame ~= lastHoveredUnitFrame or modMask ~= lastModifierMask or not (hoverCard and hoverCard:IsShown()) then
		lastHoveredUnitFrame = unitFrame
		lastModifierMask = modMask
		RenderHoverCard(unitFrame, modMask)
	elseif (Database.Get("unitHoverAnchor") or "cursor") == "cursor" and hoverCard and hoverCard:IsShown() then
		UpdateCardPosition(hoverCard, unitFrame)
	end
end

local function EnsureEventFrame()
	if eventFrame then
		return eventFrame
	end

	local f = CreateFrame("Frame")
	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "MODIFIER_STATE_CHANGED"
			or event == "UPDATE_MOUSEOVER_UNIT"
			or event == "PLAYER_REGEN_DISABLED"
			or event == "PLAYER_REGEN_ENABLED" then
			EvaluateHoverState(true)
		elseif event == "UNIT_POWER_FREQUENT" and arg1 == "player" then
			if hoverCard and hoverCard:IsShown() then
				EvaluateHoverState(true)
			end
		end
	end)

	f:SetScript("OnUpdate", function(_, elapsed)
		if hoverCard and hoverCard:IsShown() and (Database.Get("unitHoverAnchor") or "cursor") == "cursor" then
			UpdateCardPosition(hoverCard, lastHoveredUnitFrame)
		end
		pollElapsed = pollElapsed + elapsed
		if pollElapsed >= POLL_INTERVAL then
			pollElapsed = 0
			EvaluateHoverState(false)
		end
	end)

	f:Hide()
	eventFrame = f
	return f
end

function UnitHoverTooltip.UpdateTrackingState()
	local mode = Database.Get("unitHoverMode") or "off"
	local shouldTrack = (mode ~= "off") or IsFreeMoveActive()

	if not shouldTrack then
		if isTrackingActive and eventFrame then
			eventFrame:UnregisterAllEvents()
			eventFrame:Hide()
		end
		isTrackingActive = false
		HideHoverCard()
		return
	end

	local f = EnsureEventFrame()
	if not isTrackingActive then
		isTrackingActive = true
		f:RegisterEvent("MODIFIER_STATE_CHANGED")
		f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		f:RegisterEvent("PLAYER_REGEN_DISABLED")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
		f:Show()
	end
	EvaluateHoverState(true)
end

function UnitHoverTooltip.OnSettingChanged(key)
	if key == "unitHoverMode"
		or key == "unitHoverAnchor"
		or key == "unitHoverScale"
		or key == "unitHoverAlpha"
		or key == "unitHoverShowMana"
		or key == "unitHoverShowRankTags"
		or key == "unitHoverShowInCombat"
		or key == "unitHoverShowInteractions" then
		UnitHoverTooltip.UpdateTrackingState()
	end
end

function UnitHoverTooltip.Init()
	UnitHoverTooltip.UpdateTrackingState()
end
