local _, ns = ...

local L = ns.L
local Constants = ns.Constants
local Database = ns.Database
local SettingsUI = ns.SettingsUI

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local buttonFrame = nil

function MinimapButton.ToggleClickCastingWindow()
	-- Schutz vor UI-Taint und ADDON_ACTION_BLOCKED im Kampf
	if InCombatLockdown and InCombatLockdown() then
		if UIErrorsFrame and ERR_NOT_IN_COMBAT then
			UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
		end
		return
	end
	if not (ClickBindingFrame and ClickBindingFrame:IsShown()) and ns.ClickBindingUI and ns.ClickBindingUI.EnsureSpellBookTabForClickBinding then
		ns.ClickBindingUI.EnsureSpellBookTabForClickBinding()
	end
	if ToggleClickBindingFrame then
		ToggleClickBindingFrame()
	elseif ClickBindingFrame_Toggle then
		ClickBindingFrame_Toggle()
	end
end

local function UpdatePosition(overrideAngleDeg)
	if not buttonFrame or not Minimap then
		return
	end
	local angleDeg = overrideAngleDeg or Database.Get("minimapAngle") or 225
	local angleRad = math.rad(angleDeg)
	local radius = (math.max(Minimap:GetWidth() or 140, 140) / 2) + 5
	local x = math.cos(angleRad) * radius
	local y = math.sin(angleRad) * radius

	buttonFrame:ClearAllPoints()
	buttonFrame:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

MinimapButton.UpdatePosition = UpdatePosition

local function OnDragUpdate(self)
	if not Minimap then
		return
	end
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not mx or not my or not scale or scale == 0 then
		return
	end
	cx = cx / scale
	cy = cy / scale

	local angleRad = math.atan2(cy - my, cx - mx)
	local angleDeg = math.deg(angleRad)
	if angleDeg < 0 then
		angleDeg = angleDeg + 360
	end

	-- Während des Ziehens lokal zwischenspeichern und beim Loslassen über Database.Set
	-- sowohl für Account- als auch für Charakter-Profile (useCharSettings) persistieren.
	self.pendingAngle = angleDeg
	UpdatePosition(angleDeg)
end

function MinimapButton.UpdateVisibility()
	if not buttonFrame then
		return
	end
	buttonFrame:SetShown(Database.Get("showMinimapButton") and true or false)
end

function MinimapButton.Init()
	if buttonFrame or not Minimap then
		return
	end

	-- Nativer Minimap-Button nach Blizzard-/LibDBIcon-Standard mit gemipmapptem Atlas
	local btn = CreateFrame("Button", "BetterClickCastingMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(24, 24)
	bg:SetPoint("CENTER", 0, 1)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	btn.Background = bg

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetAtlas(Constants.ICON_ATLAS)
	btn.Icon = icon

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	btn.Border = border

	btn:SetScript("OnMouseDown", function(self)
		self.Icon:SetPoint("CENTER", 1, 0)
	end)

	btn:SetScript("OnMouseUp", function(self)
		self.Icon:SetPoint("CENTER", 0, 1)
	end)

	btn:SetScript("OnDragStart", function(self)
		self.isDragging = true
		self:LockHighlight()
		self.Icon:SetPoint("CENTER", 0, 1)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)

	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		self.isDragging = false
		if self.pendingAngle ~= nil then
			Database.Set("minimapAngle", self.pendingAngle)
			self.pendingAngle = nil
		end
	end)

	btn:SetScript("OnClick", function(self, mouseButton)
		if self.isDragging then
			return
		end
		if mouseButton == "RightButton" then
			SettingsUI.OpenSettingsMenu(self)
		else
			MinimapButton.ToggleClickCastingWindow()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		if self.isDragging then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip_SetTitle(GameTooltip, L["ADDON_TITLE"])
		GameTooltip:AddLine(L["MINIMAP_TOOLTIP_SUBTITLE"], 0.6, 0.85, 1.0)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["MINIMAP_HINT_LEFT"], 0.25, 1.0, 0.25)
		GameTooltip:AddLine(L["MINIMAP_HINT_RIGHT"], 1.0, 0.82, 0.0)
		GameTooltip:AddLine(L["MINIMAP_HINT_DRAG"], 0.75, 0.75, 0.75)
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	buttonFrame = btn
	UpdatePosition()
	MinimapButton.UpdateVisibility()
end

--------------------------------------------------------------------------------
-- Native AddonCompartment Callbacks (aus BetterClickCasting.toc)
--------------------------------------------------------------------------------

function BetterClickCasting_OnAddonCompartmentClick(_, mouseButton)
	if mouseButton == "RightButton" then
		SettingsUI.OpenSettingsMenu(AddonCompartmentFrame or Minimap)
	else
		MinimapButton.ToggleClickCastingWindow()
	end
end

function BetterClickCasting_OnAddonCompartmentEnter(_, menuButtonFrame)
	GameTooltip:SetOwner(menuButtonFrame or AddonCompartmentFrame or UIParent, "ANCHOR_LEFT")
	GameTooltip_SetTitle(GameTooltip, L["ADDON_TITLE"])
	GameTooltip:AddLine(L["MINIMAP_TOOLTIP_SUBTITLE"], 0.6, 0.85, 1.0)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["MINIMAP_HINT_LEFT"], 0.25, 1.0, 0.25)
	GameTooltip:AddLine(L["MINIMAP_HINT_RIGHT"], 1.0, 0.82, 0.0)
	GameTooltip:Show()
end

function BetterClickCasting_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

-- Rückwärtskompatible Alias-Namen
BetterClickCastings_OnAddonCompartmentClick = BetterClickCasting_OnAddonCompartmentClick
BetterClickCastings_OnAddonCompartmentEnter = BetterClickCasting_OnAddonCompartmentEnter
BetterClickCastings_OnAddonCompartmentLeave = BetterClickCasting_OnAddonCompartmentLeave
