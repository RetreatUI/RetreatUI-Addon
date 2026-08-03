local RUI = RetreatUI
if not RUI then return end

-- Pyrolancer and Flameweaving are Pyromancer builds. The supplied WeakAura
-- packs load on PYROMANCER, so RetreatUI keeps normal class detection while
-- preserving the tester-curated row limits and clean Heat + Ember layout.
local module = RUI:RegisterAdvancedClassHUD("Pyromancer", {
  frameName = "RetreatUIPyromancerHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {DESTRUCTION=true,DRACONIC=true,INCINERATION=true,PYROLANCER=true,FLAMEWEAVING=true},
  maxCore = 18,
  maxUtility = 14,
  maxProcs = 12,
  maxTargetDebuffs = 12,
})

local PYROLANCER_TALENT_ID = 800796
local EMBER_AURA_ID = 807533
local HEAT_AURA_ID = 807389
local emberFrame
local eventFrame
local elapsed = 0

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("[^%a%d]", "")
end

local function IsPyromancer()
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass() or nil
  if RUI.NormalizeClassName then className = RUI:NormalizeClassName(className) or className end
  return Normalize(className) == "pyromancer"
end

local function FindPlayerAura(referenceID, referenceName)
  for _, getter in ipairs({UnitDebuff, UnitBuff}) do
    if getter then
      for index = 1, 40 do
        local values = {getter("player", index)}
        local name = values[1]
        if not name then break end
        local spellID = tonumber(values[11])
        if (referenceID and spellID == referenceID)
          or (referenceName and Normalize(name) == Normalize(referenceName))
        then
          return {
            name=name,
            icon=values[3],
            count=tonumber(values[4]) or 0,
            duration=tonumber(values[6]) or 0,
            expirationTime=tonumber(values[7]) or 0,
            spellID=spellID,
          }
        end
      end
    end
  end
end

local function IsPyrolancerBuild()
  if not IsPyromancer() then return false end
  if FindPlayerAura(EMBER_AURA_ID, "Embers") or FindPlayerAura(HEAT_AURA_ID, "Heat") then return true end
  if RUI.IsAdvancementEntryLearned then
    local known = RUI:IsAdvancementEntryLearned(PYROLANCER_TALENT_ID)
    if known == true then return true end
  end
  for _, spell in ipairs({800103, 503233, 800808, 804230}) do
    if RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(spell) then return true end
  end
  return false
end

local function CreateEmberFrame()
  if emberFrame then return emberFrame end
  emberFrame = CreateFrame("Frame", "RetreatUIPyrolancerEmbers", UIParent)
  emberFrame:SetSize(360, 9)
  emberFrame:SetFrameStrata("MEDIUM")
  emberFrame.segments = {}

  -- The five segments are self-explanatory and intentionally have no EMBERS
  -- label. This keeps the resource block compact and aligned with the Heat bar.
  for index = 1, 5 do
    local segment = CreateFrame("Frame", nil, emberFrame)
    segment:SetHeight(9)
    segment:SetBackdrop({
      bgFile="Interface\\Buttons\\WHITE8X8",
      edgeFile="Interface\\Buttons\\WHITE8X8",
      edgeSize=1,
    })
    segment:SetBackdropColor(0.035, 0.018, 0.010, 0.94)
    segment:SetBackdropBorderColor(0, 0, 0, 1)
    if index == 1 then
      segment:SetPoint("TOPLEFT", emberFrame, "TOPLEFT", 0, 0)
    else
      segment:SetPoint("LEFT", emberFrame.segments[index - 1], "RIGHT", 2, 0)
    end
    emberFrame.segments[index] = segment
  end
  emberFrame:Hide()
  return emberFrame
end

local function PositionEmbers()
  local frame = CreateEmberFrame()
  local layout = RUI.layout and RUI.layout.demonfire or {x=0, y=-118}
  local width = 360
  local primary = _G.RetreatUIPrimaryPowerBar
  if primary and primary.GetWidth then width = primary:GetWidth() end
  local spacing = 2
  local segmentWidth = (width - spacing * 4) / 5
  frame:SetSize(width, 9)
  for _, segment in ipairs(frame.segments) do segment:SetWidth(segmentWidth) end

  frame:ClearAllPoints()
  local heatBar = _G.RetreatUIPyromancerHUD and _G.RetreatUIPyromancerHUD.resourceBar
  if heatBar and heatBar.IsShown and heatBar:IsShown() then
    frame:SetPoint("BOTTOM", heatBar, "TOP", 0, 2)
  elseif primary and primary.GetHeight then
    frame:SetPoint("BOTTOM", primary, "TOP", tonumber(layout.x) or 0, 14)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(layout.x) or 0, (tonumber(layout.y) or -118) + 14)
  end
  if RUI.ApplyHUDFrameScale then RUI:ApplyHUDFrameScale(frame, "demonfire") end
end

local function UpdateEmbers()
  local frame = CreateEmberFrame()
  if not IsPyrolancerBuild() then
    frame:Hide()
    return
  end

  local aura = FindPlayerAura(EMBER_AURA_ID, "Embers") or FindPlayerAura(nil, "Ember")
  local count = aura and tonumber(aura.count) or 0
  count = math.max(0, math.min(5, count))
  local theme = RUI.GetTheme and RUI:GetTheme() or {accent={1,0.28,0.04}, accent2={1,0.68,0.10}}
  for index, segment in ipairs(frame.segments) do
    if index <= count then
      segment:SetBackdropColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.95)
      segment:SetBackdropBorderColor(theme.accent2[1], theme.accent2[2], theme.accent2[3], 1)
    else
      segment:SetBackdropColor(0.035, 0.018, 0.010, 0.94)
      segment:SetBackdropBorderColor(0, 0, 0, 1)
    end
  end
  PositionEmbers()
  frame:Show()
end

-- Pyromancer always renders a visible 0 / 100 Heat bar through the shared HUD.
-- Once that bar exists, the native Ascension class-resource widget is a true
-- duplicate and may be suppressed even while Heat is currently zero.
if module then
  module.customResourcesComplete = function()
    local root = _G.RetreatUIPyromancerHUD
    local heatBar = root and root.resourceBar
    return heatBar and heatBar.IsShown and heatBar:IsShown() == true
  end
end

local function EnsureEvents()
  if eventFrame then return end
  eventFrame = CreateFrame("Frame")
  for _, eventName in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
    "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "ASCENSION_KNOWN_ENTRIES_UPDATED",
  }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
  end
  eventFrame:SetScript("OnEvent", function(_, eventName, unit)
    if eventName ~= "UNIT_AURA" or unit == "player" then UpdateEmbers() end
  end)
  eventFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    UpdateEmbers()
  end)
end

EnsureEvents()
