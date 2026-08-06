local RUI = RetreatUI
if not RUI then return end

-- Threat is deliberately rendered as an independent border instead of reusing
-- the health fill. Caster/mana identification may therefore remain blue while
-- tank threat remains readable at a glance.
local UPDATE_INTERVAL = 0.12
local NO_AGGRO = {0.95, 0.08, 0.05, 1}
local LOSING_AGGRO = {1.00, 0.48, 0.04, 1}
local overlays = setmetatable({}, {__mode = "k"})
local driver

local function NamePlateForUnit(unit)
  if C_NamePlateManager and type(C_NamePlateManager.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlateManager.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
end

local function ResolveTurboHealthBar(nameplate)
  local current = nameplate
  for _ = 1, 7 do
    if not current then break end
    if current.myPlate and current.myPlate.hp then return current.myPlate.hp end
    if current.hp and type(current.hp.SetStatusBarColor) == "function" then return current.hp end
    if type(current.GetParent) ~= "function" then break end
    current = current:GetParent()
  end
end

local function EnsureOverlay(healthBar)
  local overlay = overlays[healthBar]
  if overlay then return overlay end

  overlay = CreateFrame("Frame", nil, healthBar)
  overlay:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
  overlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
  if overlay.SetFrameLevel and healthBar.GetFrameLevel then
    overlay:SetFrameLevel((healthBar:GetFrameLevel() or 1) + 12)
  end
  if overlay.SetBackdrop then
    overlay:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
  end
  overlay:Hide()
  overlays[healthBar] = overlay
  return overlay
end

local function ThreatSituation(unit)
  if type(UnitThreatSituation) ~= "function" then return nil end
  local ok, value = pcall(UnitThreatSituation, "player", unit)
  return ok and tonumber(value) or nil
end

local function HostileUnit(unit)
  if type(UnitExists) ~= "function" or not UnitExists(unit) then return false end
  if type(UnitCanAttack) == "function" then
    local ok, attackable = pcall(UnitCanAttack, "player", unit)
    if ok and not attackable then return false end
  end
  if type(UnitIsDeadOrGhost) == "function" then
    local ok, dead = pcall(UnitIsDeadOrGhost, unit)
    if ok and dead then return false end
  end
  return true
end

local function PaintUnit(unit, seen)
  if not HostileUnit(unit) then return end
  local healthBar = ResolveTurboHealthBar(NamePlateForUnit(unit))
  if not healthBar then return end

  local overlay = EnsureOverlay(healthBar)
  seen[overlay] = true
  local status = ThreatSituation(unit)

  if status == 3 then
    overlay:Hide()
  elseif status == 1 or status == 2 then
    if overlay.SetBackdropBorderColor then
      overlay:SetBackdropBorderColor(LOSING_AGGRO[1], LOSING_AGGRO[2], LOSING_AGGRO[3], LOSING_AGGRO[4])
    end
    overlay:Show()
  else
    if overlay.SetBackdropBorderColor then
      overlay:SetBackdropBorderColor(NO_AGGRO[1], NO_AGGRO[2], NO_AGGRO[3], NO_AGGRO[4])
    end
    overlay:Show()
  end
end

local function Refresh()
  local seen = setmetatable({}, {__mode = "k"})
  for index = 1, 40 do PaintUnit("nameplate" .. index, seen) end
  PaintUnit("target", seen)
  PaintUnit("mouseover", seen)

  for _, overlay in pairs(overlays) do
    if not seen[overlay] then overlay:Hide() end
  end
end

function RUI:InitializeTurboPlatesThreatClarity()
  if driver then
    Refresh()
    return true
  end

  driver = CreateFrame("Frame", "RetreatUITurboPlatesThreatClarity", UIParent)
  for _, eventName in ipairs({
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
  }) do
    pcall(driver.RegisterEvent, driver, eventName)
  end

  driver:SetScript("OnEvent", function()
    if RUI.After then RUI:After(0.03, Refresh) else Refresh() end
  end)

  local elapsed = 0
  driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (tonumber(delta) or 0)
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    Refresh()
  end)

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.turboThreatClarity = {
    enabled = true,
    noAggro = "red border",
    losingAggro = "amber border",
    secureAggro = "no override",
    casterIdentityPreserved = true,
  }

  Refresh()
  return true
end

for _, delay in ipairs({0.40, 1.50, 4.00}) do
  if RUI.After then
    RUI:After(delay, function()
      if RUI and RUI.InitializeTurboPlatesThreatClarity then
        RUI:InitializeTurboPlatesThreatClarity()
      end
    end)
  end
end
