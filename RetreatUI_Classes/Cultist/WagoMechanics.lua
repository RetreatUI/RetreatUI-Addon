local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

-- Native equivalents of the Cultist-only resource mechanics in
-- https://wago.io/dGSLgbxJP. This file does not load WeakAuras or scan party
-- members. It reads only the player's Total Madness debuff and four totem slots.
local W = RUI.HUDWidgets
local container
local madness
local tentacles = {}
local elapsed = 0

local MADNESS_ID = 803061
local TENTACLE_SIZE = 28
local TENTACLE_SPACING = 2
local TENTACLE_Y = -118

local TENTACLE_DEFINITIONS = {
  {slot=1, name="Tentacle of C'Thun", spellID=801153},
  {slot=2, name="Tentacle of Yogg-Saron", spellID=802042},
  {slot=3, name="Tentacle of N'Zoth", spellID=500707},
  {slot=4, name="Tentacle of Y'Shaarj", spellID=802044},
}

local function IsCultistActive()
  if type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() ~= "Cultist" then return false end
  if type(RUI.IsInstallerModuleEnabled) == "function" and not RUI:IsInstallerModuleEnabled("classHUD") then return false end
  local root = _G.RetreatUICultistHUD
  return root and root.IsShown and root:IsShown() == true
end

local function AuraByID(unit, harmful, wantedID)
  local getter = harmful and UnitDebuff or UnitBuff
  if type(getter) ~= "function" then return nil end
  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    local spellID = tonumber(values[11])
    if spellID == wantedID then
      return {
        name=name,
        icon=values[3],
        count=tonumber(values[4]) or 0,
        duration=tonumber(values[6]) or 0,
        expires=tonumber(values[7]) or 0,
        spellID=spellID,
      }
    end
  end
end

local function CreateTrackerIcon(parent, size)
  local frame = W:CreateIcon(parent, size)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  return frame
end

local function EnsureFrames()
  if container then return end

  container = CreateFrame("Frame", "RetreatUICultistWagoMechanics", UIParent)
  container:SetAllPoints(UIParent)
  container:SetFrameStrata("MEDIUM")
  container:Hide()

  for index, definition in ipairs(TENTACLE_DEFINITIONS) do
    local frame = CreateTrackerIcon(container, TENTACLE_SIZE)
    frame.definition = definition
    tentacles[index] = frame
  end

  madness = CreateTrackerIcon(container, 32)
  madness:SetPoint("CENTER", UIParent, "CENTER", 78, TENTACLE_Y)

  if type(RUI.RegisterHUDVisibilityFrame) == "function" then
    RUI:RegisterHUDVisibilityFrame(container)
  end
end

local function FormatRemaining(remaining)
  if W.FormatCooldown then return W:FormatCooldown(remaining) end
  return tostring(math.max(0, math.ceil(remaining or 0)))
end

local function SetIconTimer(frame, remaining)
  frame.cooldownText:SetText(remaining > 0.05 and FormatRemaining(remaining) or "")
  frame.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
end

local function UpdateTentacles()
  local now = GetTime()
  local active = 0

  for index, definition in ipairs(TENTACLE_DEFINITIONS) do
    local frame = tentacles[index]
    local haveTotem, name, startTime, duration, icon
    if type(GetTotemInfo) == "function" then
      haveTotem, name, startTime, duration, icon = GetTotemInfo(definition.slot)
    end

    startTime = tonumber(startTime) or 0
    duration = tonumber(duration) or 0
    local remaining = startTime > 0 and duration > 0 and math.max(0, startTime + duration - now) or 0
    local shown = (haveTotem == true or haveTotem == 1) and remaining > 0.05

    if shown then
      active = active + 1
      local width = #TENTACLE_DEFINITIONS * TENTACLE_SIZE + (#TENTACLE_DEFINITIONS - 1) * TENTACLE_SPACING
      local firstX = -width / 2 + TENTACLE_SIZE / 2
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER",
        firstX + (index - 1) * (TENTACLE_SIZE + TENTACLE_SPACING), TENTACLE_Y)
      frame.texture:SetTexture(icon or (GetSpellInfo and select(3, GetSpellInfo(definition.spellID))))
      if frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
      frame.stackText:SetText("")
      SetIconTimer(frame, remaining)
      W:SetBorder(frame, RUI:GetTheme().accent2, 1)
      frame:Show()
    else
      frame:Hide()
    end
  end

  return active
end

local function UpdateMadness()
  local aura = AuraByID("player", true, MADNESS_ID)
  if not aura then
    madness:Hide()
    return false
  end

  local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
  madness.texture:SetTexture(aura.icon or (GetSpellInfo and select(3, GetSpellInfo(MADNESS_ID))))
  if madness.texture.SetDesaturated then madness.texture:SetDesaturated(false) end
  madness.stackText:SetText(aura.count and aura.count > 0 and tostring(aura.count) or "")
  SetIconTimer(madness, remaining)

  local theme = RUI:GetTheme()
  if (tonumber(aura.count) or 0) >= 10 then
    W:SetBorder(madness, theme.accent2, 1)
    W:SetGlow(madness, theme.accent2, 0.95)
  else
    W:SetGlow(madness, nil, 0)
    W:SetBorder(madness, theme.accent, 1)
  end
  madness:Show()
  return true
end

local function Update()
  EnsureFrames()
  if not IsCultistActive() then
    container:Hide()
    return
  end

  container:Show()
  UpdateTentacles()
  UpdateMadness()
end

local events = CreateFrame("Frame", "RetreatUICultistWagoMechanicsDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_TOTEM_UPDATE",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName, unit)
  if eventName == "UNIT_AURA" and unit and unit ~= "player" then return end
  Update()
end)

events:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.10 then return end
  elapsed = 0
  Update()
end)

RUI._cultistWagoMechanicsLoaded = true
