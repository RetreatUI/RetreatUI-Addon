local RUI = RetreatUI
if not RUI then return end

-- TurboPlates' caster overlay deliberately owns the plate color, so the native
-- threat color can no longer show through. Reapply a separate, unmistakable
-- orange-red palette only when the current tank does not own the mob.
local CASTER_FILL = {0.10, 0.46, 1.00, 1}
local CASTER_BACKGROUND = {0.02, 0.10, 0.24, 0.96}
local CASTER_BORDER = {0.16, 0.62, 1.00, 1}
local LOST_FILL = {1.00, 0.18, 0.06, 1}
local LOST_BACKGROUND = {0.28, 0.035, 0.015, 0.96}
local LOST_BORDER = {1.00, 0.48, 0.08, 1}

local function CurrentRoleIsTank()
  if type(UnitGroupRolesAssigned) == "function" then
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and role == "TANK" then return true end
    if ok and role and role ~= "NONE" then return false end
  end

  if type(GetSpecialization) == "function" and type(GetSpecializationRole) == "function" then
    local okSpec, specialization = pcall(GetSpecialization)
    if okSpec and specialization then
      local okRole, role = pcall(GetSpecializationRole, specialization)
      if okRole and role == "TANK" then return true end
      if okRole and role and role ~= "NONE" then return false end
    end
  end

  -- Ascension does not expose a standard specialization role on every build.
  -- A registered RetreatUI tank profile is the safest fallback for solo play.
  if type(RUI.GetTankProfile) == "function" then
    local ok, profile = pcall(RUI.GetTankProfile, RUI)
    if ok and type(profile) == "table" then return true end
  end
  return false
end

local function PlayerOwnsThreat(unit)
  if not unit or type(UnitExists) ~= "function" or not UnitExists(unit) then return nil end

  if type(UnitDetailedThreatSituation) == "function" then
    local ok, isTanking, status = pcall(UnitDetailedThreatSituation, "player", unit)
    if ok and (isTanking ~= nil or status ~= nil) then
      return isTanking == true or tonumber(status) == 3
    end
  end

  if type(UnitThreatSituation) == "function" then
    local ok, status = pcall(UnitThreatSituation, "player", unit)
    if ok and status ~= nil then return tonumber(status) == 3 end
  end

  local targetToken = unit .. "target"
  if type(UnitExists) == "function" and type(UnitIsUnit) == "function"
    and UnitExists(targetToken) then
    local ok, owns = pcall(UnitIsUnit, targetToken, "player")
    if ok then return owns == true end
  end
  return nil
end

local function ResolveTurboPlate(nameplate)
  local current = nameplate
  for _ = 1, 6 do
    if not current then break end
    if current.myPlate and current.myPlate.hp then return current.myPlate end
    if current.hp then return current end
    if type(current.GetParent) ~= "function" then break end
    current = current:GetParent()
  end
  return nil
end

local function NamePlateForUnit(unit)
  if C_NamePlateManager and type(C_NamePlateManager.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlateManager.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
  return nil
end

local function SetSurfaceColor(surface, color)
  if not surface then return end
  if type(surface.SetVertexColor) == "function" then
    pcall(surface.SetVertexColor, surface, color[1], color[2], color[3], color[4])
  elseif type(surface.SetColor) == "function" then
    pcall(surface.SetColor, surface, color[1], color[2], color[3], color[4], true)
  elseif type(surface.SetBackdropColor) == "function" then
    pcall(surface.SetBackdropColor, surface, color[1], color[2], color[3], color[4])
  end
end

local function RecolorUnit(unit, tankRole)
  local plate = ResolveTurboPlate(NamePlateForUnit(unit))
  local hp = plate and plate.hp
  if not hp or hp._ruiManaBlue ~= true then return end

  local ownsThreat = tankRole and PlayerOwnsThreat(unit) or nil
  local lost = ownsThreat == false
  local fill = lost and LOST_FILL or CASTER_FILL
  local background = lost and LOST_BACKGROUND or CASTER_BACKGROUND
  local border = lost and LOST_BORDER or CASTER_BORDER

  if hp._ruiManaFillOverlay then SetSurfaceColor(hp._ruiManaFillOverlay, fill) end
  if hp.bg then SetSurfaceColor(hp.bg, background) end
  if hp.border then SetSurfaceColor(hp.border, border) end
  hp._ruiThreatColorState = lost and "lost" or "caster"
end

local function RefreshThreatColors()
  local tankRole = CurrentRoleIsTank()
  for index = 1, 40 do
    local unit = "nameplate" .. index
    if type(UnitExists) == "function" and UnitExists(unit) then
      RecolorUnit(unit, tankRole)
    end
  end
end

local frame = CreateFrame("Frame", "RetreatUITurboPlatesThreatColoring", UIParent)
for _, eventName in ipairs({
  "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
  "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
  "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
}) do pcall(frame.RegisterEvent, frame, eventName) end

frame:SetScript("OnEvent", function()
  if type(RUI.After) == "function" then
    RUI:After(0.01, RefreshThreatColors)
    RUI:After(0.18, RefreshThreatColors)
  else
    RefreshThreatColors()
  end
end)

local elapsed = 0
frame:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.05 then return end
  elapsed = 0
  RefreshThreatColors()
end)

RUI.turboPlatesThreatColorVersion = 1
