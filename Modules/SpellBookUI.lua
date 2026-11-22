local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Colors = Constants.Colors
local Database = ns.Database
local SpellRanks = ns.SpellRanks

local SpellBookUI = {}
ns.SpellBookUI = SpellBookUI

local isHooked = false
local quickBindCheckbox = nil
local pendingPostCombatRefresh = false

local function AppendSpellBookBindingTooltip(spellBookItemFrame)
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		return
	end
	if not Database.Get("showSpellbookBadges") then
		return
	end
	if not spellBookItemFrame or not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() or spellBookItemFrame.isUnlearned then
		return
	end
	local itemInfo = spellBookItemFrame.spellBookItemInfo
	local actionID = itemInfo and itemInfo.actionID
	local spellID = itemInfo and itemInfo.spellID
	if not actionID and not spellID then
		return
	end

	local bindingsMap = SpellRanks.GetActiveBindingsByActionID()
	local bindings = (actionID and bindingsMap[actionID]) or (spellID and bindingsMap[spellID])
	local inClickBind = InClickBindingMode and InClickBindingMode()
	local showQuickHint = inClickBind and Database.Get("quickBindSpellbook") and spellBookItemFrame.canClickBind

	if (bindings and #bindings > 0) or showQuickHint then
		GameTooltip:AddLine(" ")
		if bindings and #bindings > 0 then
			for _, bInfo in ipairs(bindings) do
				GameTooltip:AddDoubleLine(
					L["SPELLBOOK_ALREADY_BOUND_LABEL"],
					Constants.GetFullBindingString(bInfo),
					0.25, 1.0, 0.25,
					1.0, 1.0, 1.0
				)
			end
		end
		if showQuickHint then
			GameTooltip:AddLine(L["SPELLBOOK_QUICK_BIND_HINT"], 0.6, 0.85, 1.0, true)
		end
		GameTooltip:Show()
	end
end

-- Taint-freier Tooltip-Helfer für unser Quick-Bind-Overlay:
-- Ruft ausschließlich GameTooltip-APIs auf, ohne SpellBookItemMixin:OnIconEnter/OnIconLeave
-- auszulösen (welche sonst PetActionBar:ClearPetActionHighlightMarks() und PetActionBar:Update()
-- aus dem Addon-Kontext aufrufen und PetActionBar.isShownExternal für den Kampf tainten).
local function ShowQuickBindSpellBookTooltip(spellBookItemFrame)
	if not spellBookItemFrame or not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
		return
	end
	if not GameTooltip or not spellBookItemFrame.Button then
		return
	end

	GameTooltip:SetOwner(spellBookItemFrame.Button, "ANCHOR_RIGHT")
	if spellBookItemFrame.inClickBindMode and not spellBookItemFrame.canClickBind and CLICK_BINDING_NOT_AVAILABLE then
		if GameTooltip_AddErrorLine then
			GameTooltip_AddErrorLine(GameTooltip, CLICK_BINDING_NOT_AVAILABLE)
		else
			GameTooltip:SetText(CLICK_BINDING_NOT_AVAILABLE, 1.0, 0.1, 0.1, 1.0, true)
		end
		GameTooltip:Show()
		return
	end

	if spellBookItemFrame.slotIndex and spellBookItemFrame.spellBank then
		GameTooltip:SetSpellBookItem(spellBookItemFrame.slotIndex, spellBookItemFrame.spellBank)
	end
	AppendSpellBookBindingTooltip(spellBookItemFrame)
	GameTooltip:Show()
end

-- Zerlegt eine Klickbelegung für das 40px-Zauberbuch-Badge in eine optionale obere Modifier-Zeile
-- (max. 5 Zeichen, z. B. "SHIFT", "CTRL", "S+C", "S+C+A") und eine untere Maustasten-Zeile (z. B. "MMB", "LMB +1").
local function GetBadgeLinesForBindings(bindings)
	if not bindings or #bindings == 0 then
		return nil, nil
	end
	local first = bindings[1]
	if not first or not first.button then
		return nil, "✓"
	end

	local btnShort = Constants.GetShortBindingString({ button = first.button, modifiers = 0 }) or first.button
	if #bindings > 1 then
		btnShort = string.format("%s +%d", btnShort, #bindings - 1)
	end

	local modLine = nil
	if GetStringFromModifiers and first.modifiers and first.modifiers ~= 0 then
		local modStr = GetStringFromModifiers(first.modifiers) or ""
		if modStr ~= "" then
			local tokens = {}
			for token in string.gmatch(modStr, "([^-]+)") do
				table.insert(tokens, token)
			end
			if #tokens == 1 then
				modLine = tokens[1]
			elseif #tokens > 1 then
				local initials = {}
				for _, t in ipairs(tokens) do
					table.insert(initials, string.sub(t, 1, 1))
				end
				modLine = table.concat(initials, "+")
			end
		end
	end

	return modLine, btnShort
end

local function EnsureSpellBookBindBadge(spellBookItemFrame)
	if not spellBookItemFrame or not spellBookItemFrame.Button then
		return nil
	end
	if spellBookItemFrame.BCCBindBadge then
		return spellBookItemFrame.BCCBindBadge
	end

	local iconAnchor = spellBookItemFrame.Button.Icon or spellBookItemFrame.Button
	local badgeFrame = CreateFrame("Frame", nil, spellBookItemFrame.Button)
	badgeFrame:SetSize(44, 15)
	badgeFrame:SetPoint("BOTTOM", iconAnchor, "TOP", 0, -1)
	badgeFrame:SetFrameLevel(spellBookItemFrame.Button:GetFrameLevel() + 6)

	-- Adaptives 44px Pill-Banner (exakt bündig mit dem äußeren Icon-Rahmen):
	-- Der Atlas "common-dropdown-c-button" besitzt intern ca. 4px transparenten Rand,
	-- weshalb die Textur ringsum 4px über badgeFrame hinaus gespannt wird.
	local bg = badgeFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	bg:SetAtlas("common-dropdown-c-button")
	bg:SetVertexColor(0.06, 0.09, 0.13, 0.96)
	bg:SetPoint("TOPLEFT", badgeFrame, "TOPLEFT", -4, 4)
	bg:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", 4, -4)

	local topText = badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local fontPath, fontSize = topText:GetFont()
	local baseFontSize = (fontSize and math.max(9, fontSize - 1)) or 10
	local smallFontSize = math.max(8, baseFontSize - 1)
	if fontPath then
		topText:SetFont(fontPath, smallFontSize, "OUTLINE")
	end
	topText:SetPoint("TOPLEFT", badgeFrame, "TOPLEFT", 1, -2)
	topText:SetPoint("TOPRIGHT", badgeFrame, "TOPRIGHT", -1, -2)
	topText:SetJustifyH("CENTER")
	topText:SetJustifyV("TOP")
	topText:SetWordWrap(false)

	local botText = badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	if fontPath then
		botText:SetFont(fontPath, baseFontSize, "OUTLINE")
	end
	botText:SetPoint("BOTTOMLEFT", badgeFrame, "BOTTOMLEFT", 1, 2)
	botText:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", -1, 2)
	botText:SetJustifyH("CENTER")
	botText:SetJustifyV("BOTTOM")
	botText:SetWordWrap(false)

	badgeFrame.iconAnchor = iconAnchor
	badgeFrame.fontPath = fontPath
	badgeFrame.baseFontSize = baseFontSize
	badgeFrame.smallFontSize = smallFontSize
	badgeFrame.Bg = bg
	badgeFrame.TopText = topText
	badgeFrame.Text = botText
	badgeFrame:Hide()
	spellBookItemFrame.BCCBindBadge = badgeFrame
	return badgeFrame
end

-- Gemeinsame Hover-, Press- und Drag-Skripte für beide Zauberbuch-Overlays (1-Klick-QuickBind in /bcc
-- sowie SecureActionButton-Schild außerhalb von /bcc). Niemals spellBookItemFrame:OnIconEnter() oder
-- :OnIconLeave() aufrufen, da Blizzard dort PetActionBar:ClearPetActionHighlightMarks() und
-- PetActionBar:Update() -> :Hide() aufruft und damit PET_ACTION_HIGHLIGHT_MARKS sowie PetActionBar taintet.
local function AttachOverlayHoverAndDragScripts(overlay, spellBookItemFrame)
	overlay:SetScript("OnEnter", function()
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		ShowQuickBindSpellBookTooltip(spellBookItemFrame)
		if not spellBookItemFrame.isUnlearned then
			if spellBookItemFrame.Button and spellBookItemFrame.Button.IconHighlight then
				spellBookItemFrame.Button.IconHighlight:Show()
			end
			if spellBookItemFrame.Backplate and spellBookItemFrame.hoverBackplateAlpha then
				spellBookItemFrame.Backplate:SetAlpha(spellBookItemFrame.hoverBackplateAlpha)
			end
		end
	end)

	overlay:SetScript("OnLeave", function()
		if spellBookItemFrame.Button and spellBookItemFrame.Button.IconHighlight then
			spellBookItemFrame.Button.IconHighlight:Hide()
			if spellBookItemFrame.iconHighlightHoverAlpha then
				spellBookItemFrame.Button.IconHighlight:SetAlpha(spellBookItemFrame.iconHighlightHoverAlpha)
			end
		end
		if spellBookItemFrame.Backplate and spellBookItemFrame.defaultBackplateAlpha then
			spellBookItemFrame.Backplate:SetAlpha(spellBookItemFrame.defaultBackplateAlpha)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	overlay:SetScript("OnMouseDown", function()
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		if not spellBookItemFrame.isUnlearned and spellBookItemFrame.Button and spellBookItemFrame.Button.IconHighlight and spellBookItemFrame.iconHighlightPressAlpha then
			spellBookItemFrame.Button.IconHighlight:SetAlpha(spellBookItemFrame.iconHighlightPressAlpha)
		end
	end)

	overlay:SetScript("OnMouseUp", function()
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		if not spellBookItemFrame.isUnlearned and spellBookItemFrame.Button and spellBookItemFrame.Button.IconHighlight and spellBookItemFrame.iconHighlightHoverAlpha then
			spellBookItemFrame.Button.IconHighlight:SetAlpha(spellBookItemFrame.iconHighlightHoverAlpha)
		end
	end)

	overlay:SetScript("OnDragStart", function()
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		if C_SpellBook and C_SpellBook.PickupSpellBookItem and spellBookItemFrame.slotIndex and spellBookItemFrame.spellBank then
			C_SpellBook.PickupSpellBookItem(spellBookItemFrame.slotIndex, spellBookItemFrame.spellBank)
		end
	end)
end

local function EnsureSpellBookQuickBindOverlay(spellBookItemFrame)
	if not spellBookItemFrame or not spellBookItemFrame.Button then
		return nil
	end
	if spellBookItemFrame.BCCQuickBindButton then
		local existing = spellBookItemFrame.BCCQuickBindButton
		if existing:GetParent() ~= spellBookItemFrame.Button then
			existing:SetParent(spellBookItemFrame.Button)
			existing:SetAllPoints(spellBookItemFrame.Button)
			existing:SetFrameLevel(spellBookItemFrame.Button:GetFrameLevel() + 5)
		end
		return existing
	end

	-- Overlay 1 (BCCQuickBindButton): Ist ausschließlich sichtbar, solange ClickBindingFrame (/bcc)
	-- geöffnet ist (inClickBind == true), um alle Maustasten (LMB, RMB, MMB, MB4, MB5 + Modifier)
	-- für das 1-Klick-Direktbinden abzufangen. Außerhalb von /bcc immer versteckt (:Hide()).
	local overlay = CreateFrame("Button", nil, spellBookItemFrame.Button)
	overlay:SetAllPoints(spellBookItemFrame.Button)
	overlay:SetFrameLevel(spellBookItemFrame.Button:GetFrameLevel() + 5)
	overlay:RegisterForClicks("AnyUp")
	overlay:RegisterForDrag("LeftButton")
	AttachOverlayHoverAndDragScripts(overlay, spellBookItemFrame)

	overlay:SetScript("OnClick", function(_, mouseButton)
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		if not spellBookItemFrame.inClickBindMode or not spellBookItemFrame.canClickBind or spellBookItemFrame.isUnlearned then
			return
		end
		local actionID = spellBookItemFrame.spellBookItemInfo and spellBookItemFrame.spellBookItemInfo.actionID
		if not actionID then
			return
		end

		local actionType = nil
		if spellBookItemFrame.spellBank == Enum.SpellBookSpellBank.Player then
			actionType = Enum.ClickBindingType.Spell
		elseif spellBookItemFrame.spellBank == Enum.SpellBookSpellBank.Pet then
			actionType = Enum.ClickBindingType.PetAction
		end
		if not actionType then
			return
		end

		if Database.Get("quickBindSpellbook") then
			if ns.ClickBindingUI and ns.ClickBindingUI.QuickBindSpell then
				local modifiers = (MakeModifiers and MakeModifiers()) or 0
				ns.ClickBindingUI.QuickBindSpell(actionType, actionID, mouseButton, modifiers)
				if GameTooltip and GameTooltip:IsOwned(spellBookItemFrame.Button) then
					ShowQuickBindSpellBookTooltip(spellBookItemFrame)
				end
			end
		elseif (mouseButton == "LeftButton" or mouseButton == "RightButton") and ClickBindingFrame and ClickBindingFrame.AddNewAction then
			ClickBindingFrame:AddNewAction(actionType, actionID)
		end
	end)

	overlay:Hide()
	spellBookItemFrame.BCCQuickBindButton = overlay
	return overlay
end

-- Overlay 2 (BCCSecureCastButton): Erbt von Blizzards "SecureActionButtonTemplate" und liegt ausschließlich
-- außerhalb von /bcc (not inClickBind and isItemTainted) über bereits getainteten Zauberbuch-Slots.
-- Wichtig: Niemals SetScript("OnClick") aufrufen, damit Blizzards natives SecureActionButton_OnClick
-- aus SecureTemplates.xml zu 100 % [SECURE] bleibt und Zauber ohne CastSpellBookItem()-Taint wirkt.
local function EnsureSpellBookSecureCastOverlay(spellBookItemFrame)
	if not spellBookItemFrame or not spellBookItemFrame.Button then
		return nil
	end
	local inCombat = InCombatLockdown and InCombatLockdown() or false
	if spellBookItemFrame.BCCSecureCastButton then
		local existing = spellBookItemFrame.BCCSecureCastButton
		if not inCombat and existing:GetParent() ~= spellBookItemFrame.Button then
			existing:SetParent(spellBookItemFrame.Button)
			existing:SetAllPoints(spellBookItemFrame.Button)
			existing:SetFrameLevel(spellBookItemFrame.Button:GetFrameLevel() + 4)
		elseif inCombat and existing:GetParent() ~= spellBookItemFrame.Button then
			pendingPostCombatRefresh = true
		end
		return existing
	end
	if inCombat then
		pendingPostCombatRefresh = true
		return nil
	end

	local secureBtn = CreateFrame("Button", nil, spellBookItemFrame.Button, "SecureActionButtonTemplate")
	secureBtn:SetAllPoints(spellBookItemFrame.Button)
	secureBtn:SetFrameLevel(spellBookItemFrame.Button:GetFrameLevel() + 4)
	secureBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	secureBtn:RegisterForDrag("LeftButton")
	secureBtn:SetAttribute("useOnKeyDown", false)
	secureBtn:SetAttribute("checkselfcast", true)
	secureBtn:SetAttribute("shift-type*", ATTRIBUTE_NOOP or "")
	AttachOverlayHoverAndDragScripts(secureBtn, spellBookItemFrame)

	-- Nicht-geschützte Zusatzaktionen (Shift-Klick Chat-/Makro-Link oder Pickup) über PostClick bedienen
	secureBtn:SetScript("PostClick", function(_, mouseButton)
		if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
			return
		end
		if IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("PICKUPACTION")) then
			if spellBookItemFrame.OnModifiedIconClick then
				spellBookItemFrame:OnModifiedIconClick(mouseButton)
			end
		end
	end)

	secureBtn:Hide()
	spellBookItemFrame.BCCSecureCastButton = secureBtn
	return secureBtn
end

local function ConfigureSecureCastOverlay(secureBtn, spellBookItemFrame)
	if not secureBtn or not spellBookItemFrame or (InCombatLockdown and InCombatLockdown()) then
		return
	end
	local noop = ATTRIBUTE_NOOP or ""
	secureBtn:SetAttribute("type1", noop)
	secureBtn:SetAttribute("type2", noop)
	secureBtn:SetAttribute("spell", nil)
	secureBtn:SetAttribute("spell1", nil)
	secureBtn:SetAttribute("macrotext2", nil)

	local info = spellBookItemFrame.spellBookItemInfo
	if not info or spellBookItemFrame.isUnlearned or spellBookItemFrame.isOffSpec then
		return
	end

	local itemType = info.itemType
	local spellID = info.spellID or info.actionID
	if Enum and Enum.SpellBookItemType then
		if itemType == Enum.SpellBookItemType.Spell and not info.isPassive and spellID then
			secureBtn:SetAttribute("type1", "spell")
			secureBtn:SetAttribute("type2", "spell")
			secureBtn:SetAttribute("spell", spellID)
		elseif itemType == Enum.SpellBookItemType.PetAction and not info.isPassive then
			if spellID then
				secureBtn:SetAttribute("type1", "spell")
				secureBtn:SetAttribute("spell1", spellID)
			end
			if info.name and info.name ~= "" then
				secureBtn:SetAttribute("type2", "macro")
				secureBtn:SetAttribute("macrotext2", "/petautocasttoggle " .. info.name)
			end
		elseif itemType == Enum.SpellBookItemType.Flyout and info.actionID then
			secureBtn:SetAttribute("type1", "flyout")
			secureBtn:SetAttribute("type2", "flyout")
			secureBtn:SetAttribute("spell", info.actionID)
		end
	end
end

local function EnsureSpellBookQuickBindCheckbox()
	if not PlayerSpellsFrame or not PlayerSpellsFrame.SpellBookFrame then
		return nil
	end
	local sbFrame = PlayerSpellsFrame.SpellBookFrame
	if quickBindCheckbox then
		if quickBindCheckbox:GetParent() ~= sbFrame then
			quickBindCheckbox:SetParent(sbFrame)
			quickBindCheckbox:ClearAllPoints()
			quickBindCheckbox:SetPoint("BOTTOMLEFT", sbFrame, "BOTTOMLEFT", 36, 35)
			quickBindCheckbox:SetFrameLevel(sbFrame.PagedSpellsFrame and (sbFrame.PagedSpellsFrame:GetFrameLevel() + 10) or 20)
		end
		return quickBindCheckbox
	end

	-- Moderne abgerundete Pill-Leiste mit Checkbox und Maus-Icon unten links im Zauberbuch
	local cb = CreateFrame("CheckButton", nil, sbFrame, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("BOTTOMLEFT", sbFrame, "BOTTOMLEFT", 36, 35)
	cb:SetFrameLevel(sbFrame.PagedSpellsFrame and (sbFrame.PagedSpellsFrame:GetFrameLevel() + 10) or 20)

	local pillBg = cb:CreateTexture(nil, "BACKGROUND")
	pillBg:SetAtlas("common-dropdown-c-button")
	pillBg:SetVertexColor(0.12, 0.10, 0.08, 0.88)

	local mouseIcon = cb:CreateTexture(nil, "ARTWORK")
	mouseIcon:SetSize(16, 16)
	mouseIcon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	mouseIcon:SetAtlas(Constants.ICON_ATLAS)
	cb.MouseIcon = mouseIcon

	local label = cb.Text or cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:ClearAllPoints()
	label:SetPoint("LEFT", mouseIcon, "RIGHT", 4, 0)
	label:SetText(L["SPELLBOOK_QUICK_BIND_CHECKBOX"])
	cb.Label = label

	pillBg:SetPoint("TOPLEFT", cb, "TOPLEFT", -6, 3)
	pillBg:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 10, -5)
	cb.PillBg = pillBg

	cb:SetHitRectInsets(-4, -180, -2, -2)

	cb:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Database.Set("quickBindSpellbook", self:GetChecked() and true or false)
	end)

	cb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip_SetTitle(GameTooltip, L["SETTING_QUICK_BIND_SPELLBOOK"])
		GameTooltip_AddNormalLine(GameTooltip, L["SETTING_QUICK_BIND_SPELLBOOK_DESC"], true)
		GameTooltip:Show()
	end)

	cb:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	cb:Hide()
	quickBindCheckbox = cb
	return cb
end

function SpellBookUI.UpdateQuickBindCheckbox()
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if quickBindCheckbox then
			quickBindCheckbox:Hide()
			quickBindCheckbox:SetParent(nil)
		end
		return
	end
	local cb = EnsureSpellBookQuickBindCheckbox()
	if not cb then
		return
	end
	local inClickBind = (InClickBindingMode and InClickBindingMode()) and true or false
	local isChecked = Database.Get("quickBindSpellbook") and true or false
	cb:SetChecked(isChecked)
	if cb.Label then
		cb.Label:SetText(L["SPELLBOOK_QUICK_BIND_CHECKBOX"])
		if isChecked then
			cb.Label:SetTextColor(0.35, 1.0, 0.45)
		else
			cb.Label:SetTextColor(0.85, 0.85, 0.85)
		end
	end
	cb:SetShown(inClickBind)
end

function SpellBookUI.UpdateItemClickBindVisuals(spellBookItemFrame, bindingsMap)
	if not spellBookItemFrame then
		return
	end
	local inCombat = InCombatLockdown and InCombatLockdown() or false
	if Constants.IsGamepadUIActive and Constants.IsGamepadUIActive() then
		if spellBookItemFrame.BCCBindBadge then
			spellBookItemFrame.BCCBindBadge:Hide()
		end
		if spellBookItemFrame.BCCQuickBindButton then
			spellBookItemFrame.BCCQuickBindButton:Hide()
			spellBookItemFrame.BCCQuickBindButton:SetParent(nil)
		end
		if spellBookItemFrame.BCCSecureCastButton then
			if not inCombat then
				spellBookItemFrame.BCCSecureCastButton:Hide()
				spellBookItemFrame.BCCSecureCastButton:SetParent(nil)
			else
				pendingPostCombatRefresh = true
			end
		end
		return
	end

	local badgeFrame = EnsureSpellBookBindBadge(spellBookItemFrame)
	local quickBindOverlay = EnsureSpellBookQuickBindOverlay(spellBookItemFrame)

	if not spellBookItemFrame.HasValidData or not spellBookItemFrame:HasValidData() then
		if badgeFrame then
			badgeFrame:Hide()
		end
		if quickBindOverlay then
			quickBindOverlay:Hide()
		end
		if spellBookItemFrame.BCCSecureCastButton then
			if not inCombat then
				spellBookItemFrame.BCCSecureCastButton:Hide()
			else
				pendingPostCombatRefresh = true
			end
		end
		return
	end

	local inClickBind = (InClickBindingMode and InClickBindingMode()) and true or false
	local quickBindActive = inClickBind and Database.Get("quickBindSpellbook") and spellBookItemFrame.canClickBind and not spellBookItemFrame.isUnlearned
	local isItemTainted = false
	if issecurevariable then
		if (spellBookItemFrame.elementData ~= nil and not issecurevariable(spellBookItemFrame, "elementData"))
			or (spellBookItemFrame.spellBookItemInfo ~= nil and not issecurevariable(spellBookItemFrame, "spellBookItemInfo"))
			or (spellBookItemFrame.slotIndex ~= nil and not issecurevariable(spellBookItemFrame, "slotIndex"))
		then
			isItemTainted = true
		end
	end

	-- Auf getainteten Zauberbuch-Slots SPELL_UPDATE_COOLDOWN abmelden, damit Blizzards UpdateCooldown()
	-- im Kampf keine geschützten Secret-Cooldown-Werte (SecretWhenCooldownsRestricted) an SetCooldown() übergibt.
	if spellBookItemFrame.UnregisterEvent then
		if isItemTainted then
			spellBookItemFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
		elseif spellBookItemFrame:IsShown() and spellBookItemFrame.RegisterEvent then
			spellBookItemFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		end
	end

	-- 1. Lückenloser 2-Schicht-Schild: Auf jedem getainteten Zauberbuch-Slot (isItemTainted) wird
	-- BCCSecureCastButton (SecureActionButtonTemplate, FrameLevel + 4) bereits außerhalb des Kampfes
	-- fertig konfiguriert und sichtbar gehalten (auch während /bcc offen ist, direkt unter BCCQuickBindButton).
	-- Schließt /bcc (selbst mitten im Kampf), verschwindet BCCQuickBindButton (Level + 5) und legt den
	-- bereits aktiven BCCSecureCastButton ohne 1 ms Lücke frei, sodass SpellBookItemMixin:OnIconEnter()
	-- niemals auf einem getainteten Slot feuert und _G.ON_BAR_HIGHLIGHT_MARKS / ActionBars zu 100 % [SECURE] bleiben.
	local secureShieldActive = false
	if isItemTainted then
		local secureBtn = EnsureSpellBookSecureCastOverlay(spellBookItemFrame)
		if secureBtn then
			if not inCombat then
				ConfigureSecureCastOverlay(secureBtn, spellBookItemFrame)
				secureBtn:Show()
				secureShieldActive = true
			else
				secureShieldActive = secureBtn:IsShown() and true or false
				if not secureShieldActive then
					pendingPostCombatRefresh = true
				end
			end
		end
	elseif spellBookItemFrame.BCCSecureCastButton then
		if not inCombat then
			spellBookItemFrame.BCCSecureCastButton:Hide()
		else
			pendingPostCombatRefresh = true
		end
	end

	-- 2. Solange /bcc offen ist (inClickBind == true), liegt BCCQuickBindButton (Level + 5) über
	-- BCCSecureCastButton und fängt alle Maustasten zum 1-Klick-Direktbinden ab.
	-- Fallback im Kampf: Falls ein getainteter Slot im Kampf noch keinen aktiven SecureCastButton hat,
	-- bleibt BCCQuickBindButton als Notfall-Hover-Schild aktiv bis PLAYER_REGEN_ENABLED.
	if quickBindOverlay then
		quickBindOverlay:SetShown(inClickBind or (isItemTainted and inCombat and not secureShieldActive))
	end

	-- Im 1-Klick-Direktbinde-Modus leuchten alle bindbaren Zauber im Zauberbuch
	if quickBindActive and spellBookItemFrame.Button and spellBookItemFrame.Button.ClickBindingHighlight then
		spellBookItemFrame.Button.ClickBindingHighlight:SetShown(true)
	end

	if not badgeFrame then
		return
	end

	if spellBookItemFrame.isUnlearned or not Database.Get("showSpellbookBadges") then
		badgeFrame:Hide()
		return
	end

	bindingsMap = bindingsMap or SpellRanks.GetActiveBindingsByActionID()
	local itemInfo = spellBookItemFrame.spellBookItemInfo
	local actionID = itemInfo and itemInfo.actionID
	local spellID = itemInfo and itemInfo.spellID
	local bindings = (actionID and bindingsMap[actionID]) or (spellID and bindingsMap[spellID])
	if bindings and #bindings > 0 then
		local modLine, btnLine = GetBadgeLinesForBindings(bindings)
		local anchor = badgeFrame.iconAnchor or spellBookItemFrame.Button.Icon or spellBookItemFrame.Button
		local btnFontSize = (btnLine and string.len(btnLine) > 4) and badgeFrame.smallFontSize or badgeFrame.baseFontSize
		badgeFrame:ClearAllPoints()
		if modLine and modLine ~= "" then
			badgeFrame:SetSize(44, 23)
			badgeFrame:SetPoint("BOTTOM", anchor, "TOP", 0, -5)
			if badgeFrame.TopText then
				badgeFrame.TopText:SetText("|cffffd100" .. modLine .. "|r")
				badgeFrame.TopText:Show()
			end
			badgeFrame.Text:ClearAllPoints()
			badgeFrame.Text:SetPoint("BOTTOMLEFT", badgeFrame, "BOTTOMLEFT", 1, 2)
			badgeFrame.Text:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", -1, 2)
			badgeFrame.Text:SetJustifyV("BOTTOM")
			if badgeFrame.fontPath and btnFontSize then
				badgeFrame.Text:SetFont(badgeFrame.fontPath, btnFontSize, "OUTLINE")
			end
			badgeFrame.Text:SetText(Colors.BIND_BADGE .. (btnLine or "✓") .. Colors.RESET)
		else
			badgeFrame:SetSize(44, 15)
			badgeFrame:SetPoint("BOTTOM", anchor, "TOP", 0, -1)
			if badgeFrame.TopText then
				badgeFrame.TopText:SetText("")
				badgeFrame.TopText:Hide()
			end
			badgeFrame.Text:ClearAllPoints()
			badgeFrame.Text:SetPoint("TOPLEFT", badgeFrame, "TOPLEFT", 1, -1)
			badgeFrame.Text:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", -1, 1)
			badgeFrame.Text:SetJustifyV("MIDDLE")
			if badgeFrame.fontPath and btnFontSize then
				badgeFrame.Text:SetFont(badgeFrame.fontPath, btnFontSize, "OUTLINE")
			end
			badgeFrame.Text:SetText(Colors.BIND_BADGE .. (btnLine or "✓") .. Colors.RESET)
		end
		badgeFrame:Show()
	else
		badgeFrame:Hide()
	end
end

function SpellBookUI.OnCombatEnded()
	if pendingPostCombatRefresh then
		pendingPostCombatRefresh = false
		SpellBookUI.RefreshBadges()
	end
end

function SpellBookUI.RefreshBadges()
	SpellBookUI.UpdateQuickBindCheckbox()
	if not PlayerSpellsFrame or not PlayerSpellsFrame.SpellBookFrame then
		return
	end
	local sbFrame = PlayerSpellsFrame.SpellBookFrame
	if not sbFrame.ForEachDisplayedSpell then
		return
	end
	local bindingsMap = SpellRanks.GetActiveBindingsByActionID()
	sbFrame:ForEachDisplayedSpell(function(itemFrame)
		SpellBookUI.UpdateItemClickBindVisuals(itemFrame, bindingsMap)
	end)
end

function SpellBookUI.SetupHooks()
	if isHooked or not SpellBookItemMixin then
		return
	end
	isHooked = true

	-- 1. Hooks auf Mixin-Ebene für alle künftig erzeugten Frames
	hooksecurefunc(SpellBookItemMixin, "UpdateClickBindState", function(self)
		SpellBookUI.UpdateItemClickBindVisuals(self)
	end)

	if SpellBookItemMixin.OnShow then
		hooksecurefunc(SpellBookItemMixin, "OnShow", function(self)
			if self and issecurevariable and self.UnregisterEvent then
				if (self.elementData ~= nil and not issecurevariable(self, "elementData"))
					or (self.slotIndex ~= nil and not issecurevariable(self, "slotIndex"))
				then
					self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
				end
			end
		end)
	end

	if SpellBookItemMixin.ClearSpellData then
		hooksecurefunc(SpellBookItemMixin, "ClearSpellData", function(self)
			if self and self.BCCBindBadge then
				self.BCCBindBadge:Hide()
			end
			if self and self.BCCQuickBindButton then
				self.BCCQuickBindButton:Hide()
			end
			if self and self.BCCSecureCastButton then
				if not (InCombatLockdown and InCombatLockdown()) then
					self.BCCSecureCastButton:Hide()
				else
					pendingPostCombatRefresh = true
				end
			end
		end)
	end

	hooksecurefunc(SpellBookItemMixin, "ShowSpellBookTooltip", function(self)
		AppendSpellBookBindingTooltip(self)
	end)

	-- 2. EventRegistry-Callbacks des Zauberbuchs (deckt auch bereits vorab erzeugte Pool-Frames ab)
	if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged", function()
			SpellBookUI.RefreshBadges()
		end, ns)
		EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.Show", function()
			SpellBookUI.RefreshBadges()
		end, ns)
	end

	SpellBookUI.RefreshBadges()
end
