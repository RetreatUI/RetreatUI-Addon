local RUI = RetreatUI

RUI.layout = {
  -- Final 1920x1080 on-screen coordinates for the native RetreatUI HUD.
  power = {x=0, y=-152, width=360, height=16},
  custom = {y=-183},
  counters = {imp={x=-105, y=-118}, blood={x=105, y=-118}},
  -- Secondary class counters use ICON / NAME / VALUE. Their text extends
  -- below the icon, so this higher row keeps the value clear of the power bar.
  secondaryCounters = {left={x=-105, y=-96}, right={x=105, y=-96}},
  core = {x=0, y=-183},
  utility = {x=0, y=-224},
  targetDebuffs = {x=310, y=-59},
  demonfire = {x=0, y=-118},
  auraTrackers = {x=0, y=-83, size=30, spacing=3},
  stanceTracker = {size=38, gap=6},
  tankFramework = {
    build={x=-105, y=-96},
    core={x=105, y=-96},
    state={x=-167, y=-96},
  },
}

local powerFrame
local powerDriver
local powerElapsed = 0
local lastPowerCurrent, lastPowerMaximum, lastPowerToken
local hudVisibilityDriver
local hudVisibilityElapsed = 0
local hudOverlaySuppressed

local RESOURCE_COLORS = RUI.resourceColors or {
  MANA = {0.10, 0.42, 0.95}, RAGE = {0.95, 0.20, 0.06}, FURY = {1.00, 0.34, 0.04},
  ENERGY = {0.95, 0.82, 0.08}, FOCUS = {0.28, 0.82, 0.22}, RUNICPOWER = {0.10, 0.78, 0.92},
}

function RUI:GetPrimaryResourceToken()
  local info = self:GetClassInfo()
  local definition = info and info.definition or {}
  local configured = definition and definition.primaryResource

  -- Form-driven classes such as Venomancer must follow the power token exposed
  -- by the live player unit. The configured token is only a safe fallback.
  if definition and definition.dynamicPrimaryResource and UnitPowerType then
    local ok, _, token = pcall(UnitPowerType, "player")
    if ok and token and token ~= "" then
      return string.upper(tostring(token)):gsub("[^A-Z]", "")
    end
  end

  if configured and configured ~= "" then return string.upper(tostring(configured)):gsub("[^A-Z]", "") end
  if UnitPowerType then
    local ok, _, token = pcall(UnitPowerType, "player")
    if ok and token then return string.upper(tostring(token)):gsub("[^A-Z]", "") end
  end
  return "MANA"
end

function RUI:GetPrimaryResourceColor()
  local token = self:GetPrimaryResourceToken()
  if self.GetResourceColor then return self:GetResourceColor(token) end
  return RESOURCE_COLORS[token] or RESOURCE_COLORS.MANA
end

local function PowerTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function CreatePowerFrame()
  if powerFrame then return powerFrame end
  local layout = RUI.layout.power
  local frame = CreateFrame("StatusBar", "RetreatUIPrimaryPowerBar", UIParent)
  frame:SetSize(layout.width, layout.height)
  frame:SetPoint("CENTER", UIParent, "CENTER", layout.x, layout.y)
  frame:SetStatusBarTexture(PowerTexture())
  frame:SetMinMaxValues(0, 100)
  frame:SetValue(0)
  RUI:SkinFrame(frame, {0.018,0.018,0.022,0.96}, {0,0,0,1})

  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")
  RUI:ApplyFont(frame.text, 10, "OUTLINE")
  frame.text:SetTextColor(1,1,1,1)
  frame:Hide()
  powerFrame = frame
  return frame
end

local POWER_NAMES = {
  [0]="MANA", [1]="RAGE", [2]="FOCUS", [3]="ENERGY", [6]="RUNIC POWER",
}

local function ReadPrimaryPower()
  local token = RUI:GetPrimaryResourceToken()
  local powerType = type(RUI.GetPowerTypeForToken) == "function" and RUI:GetPowerTypeForToken(token) or nil
  if powerType == nil and UnitPowerType then
    local ok, value = pcall(UnitPowerType, "player")
    if ok and type(value) == "number" then powerType = value end
  end
  powerType = tonumber(powerType) or 0

  local current, maximum
  if UnitPower and UnitPowerMax then
    local okCurrent, valueCurrent = pcall(UnitPower, "player", powerType)
    local okMaximum, valueMaximum = pcall(UnitPowerMax, "player", powerType)
    if okCurrent then current = valueCurrent end
    if okMaximum then maximum = valueMaximum end
  end

  -- Ascension's classless resource layer does not consistently fire retail
  -- power events, and some builds expose the active resource through the
  -- legacy UnitMana API. Keep this fallback, but only read it once per poll.
  if not maximum or tonumber(maximum) == nil or maximum <= 0 then
    if UnitMana then
      local ok, value = pcall(UnitMana, "player")
      if ok then current = value end
    end
    if UnitManaMax then
      local ok, value = pcall(UnitManaMax, "player")
      if ok then maximum = value end
    end
  end

  current = math.max(0, tonumber(current) or 0)
  maximum = math.max(1, tonumber(maximum) or 100)
  if current > maximum then current = maximum end
  return math.floor(current + 0.5), math.floor(maximum + 0.5)
end

function RUI:UpdatePrimaryPower(force)
  if not powerFrame or not powerFrame:IsShown() then return end
  local current, maximum = ReadPrimaryPower()
  local token = self:GetPrimaryResourceToken()
  if not force and current == lastPowerCurrent and maximum == lastPowerMaximum and token == lastPowerToken then return end
  lastPowerCurrent, lastPowerMaximum, lastPowerToken = current, maximum, token

  local color = self:GetPrimaryResourceColor()
  powerFrame:SetStatusBarColor(color[1], color[2], color[3], 1)
  powerFrame:SetMinMaxValues(0, maximum)
  powerFrame:SetValue(current)
  powerFrame.text:SetText(string.format("%d / %d", current, maximum))
end

function RUI:ActivatePrimaryPower()
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    self:DeactivatePrimaryPower()
    return false
  end
  local frame = CreatePowerFrame()
  frame:Show()
  lastPowerCurrent, lastPowerMaximum, lastPowerToken = nil, nil, nil
  self:UpdatePrimaryPower(true)
  if not powerDriver then
    powerDriver = CreateFrame("Frame")
    powerDriver:RegisterEvent("UNIT_POWER")
    powerDriver:RegisterEvent("UNIT_POWER_FREQUENT")
    powerDriver:RegisterEvent("UNIT_DISPLAYPOWER")
    powerDriver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    powerDriver:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    powerDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
    powerDriver:SetScript("OnEvent", function(_, event, unit)
      if unit and unit ~= "player" then return end
      RUI:UpdatePrimaryPower(true)
    end)
    powerDriver:SetScript("OnUpdate", function(_, elapsed)
      powerElapsed = powerElapsed + elapsed
      if powerElapsed < 0.12 then return end
      powerElapsed = 0
      RUI:UpdatePrimaryPower(false)
    end)
  end
  powerDriver:Show()
  return true
end

function RUI:DeactivatePrimaryPower()
  if powerFrame then powerFrame:Hide() end
  if powerDriver then powerDriver:Hide() end
  powerElapsed = 0
end

function RUI:GetPrimaryPowerFrame()
  return powerFrame
end

local function FrameIsShown(frame)
  if not frame then return false end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and shown then return true end
  end
  if type(frame.IsVisible) == "function" then
    local ok, visible = pcall(frame.IsVisible, frame)
    if ok and visible then return true end
  end
  return false
end

function RUI:IsHUDOverlaySuppressed()
  -- RetreatUI should behave like a normal gameplay HUD, not like a top-layer
  -- WeakAura. The world map must fully cover class icons, trackers and power.
  return FrameIsShown(_G.WorldMapFrame)
end

function RUI:UpdateHUDOverlayVisibility(force)
  local suppressed = self:IsHUDOverlaySuppressed()
  if not force and suppressed == hudOverlaySuppressed then return not suppressed end
  hudOverlaySuppressed = suppressed

  local alpha = suppressed and 0 or 1
  if powerFrame and powerFrame.SetAlpha then powerFrame:SetAlpha(alpha) end

  local module = self.activeModule
  local root = module and module.frameName and _G[module.frameName]
  if root and root.SetAlpha then root:SetAlpha(alpha) end
  return not suppressed
end

function RUI:StartHUDVisibilityDriver()
  if not hudVisibilityDriver then
    hudVisibilityDriver = CreateFrame("Frame")
    hudVisibilityDriver:SetScript("OnUpdate", function(_, elapsed)
      hudVisibilityElapsed = hudVisibilityElapsed + elapsed
      if hudVisibilityElapsed < 0.10 then return end
      hudVisibilityElapsed = 0
      RUI:UpdateHUDOverlayVisibility(false)
    end)
  end
  hudVisibilityElapsed = 0
  hudOverlaySuppressed = nil
  hudVisibilityDriver:Show()
  self:UpdateHUDOverlayVisibility(true)
end

function RUI:StopHUDVisibilityDriver()
  if hudVisibilityDriver then hudVisibilityDriver:Hide() end
  hudVisibilityElapsed = 0
  hudOverlaySuppressed = nil
  if powerFrame and powerFrame.SetAlpha then powerFrame:SetAlpha(1) end
end

function RUI:DeactivateAllHUD()
  if self.activeModule and self.activeModule.deactivate then
    pcall(self.activeModule.deactivate, self.activeModule)
  end
  self.activeModule = nil
  self.activeClass = nil
  self:DeactivatePrimaryPower()
  self:StopHUDVisibilityDriver()
end

function RUI:ActivateClassHUD(force)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    self:DeactivateAllHUD()
    return false, "unsupported"
  end

  local className = self:GetDetectedClass()
  local module = self.GetClassModule and self:GetClassModule(className) or self.classModules[className]
  if not module or type(module.activate) ~= "function" then
    self:DeactivateAllHUD()
    return false, "missing-module"
  end

  if self.activeModule and self.activeClass ~= className and self.activeModule.deactivate then
    pcall(self.activeModule.deactivate, self.activeModule)
  end

  if module.usesPrimaryPower ~= false then
    if not self:ActivatePrimaryPower() then return false, "unsupported" end
  else
    self:DeactivatePrimaryPower()
  end

  local ok, result = pcall(module.activate, module, force)
  if not ok then
    self:Print(className .. " HUD failed: " .. tostring(result))
    self:DeactivateAllHUD()
    return false, "error"
  end
  self.activeClass = className
  self.activeModule = module
  self:StartHUDVisibilityDriver()
  return result ~= false, "complete"
end
