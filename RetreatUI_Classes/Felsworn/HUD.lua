local RUI = RetreatUI
if not RUI then return end

local CLASS_NAME = "Felsworn"
local MAX_FELFURY = 6
local FELFURY_AURA_ID = 800058
local FELFURY_TEXTURE = "Interface\\Icons\\Spell_Shadow_FelArmour"

-- Felsworn uses the shared all-spec cooldown/proc HUD, but keeps a dedicated
-- Felfury mirror because Ascension exposes this resource differently between
-- client revisions. The dedicated reader preserves the established
-- aura/custom-power/native-frame fallbacks instead of relying on one source.
local module = RUI:RegisterAdvancedClassHUD(CLASS_NAME, {
  frameName = "RetreatUIFelswornHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {DEMONOLOGY=true,FELBLOOD=true,SLAYING=true},
})
if not module then return end

local BaseActivate = module.activate
local BaseDeactivate = module.deactivate
local resourceDriver, pollDriver
local segments = {}
local elapsed = 0
local lastStacks
local felfurySourceReady = false
local lastReady = false

function module.customResourcesComplete()
  return felfurySourceReady == true
end

local function ResourceRoot()
  return _G[module.frameName]
end

local function CreateSegment(index)
  local parent = ResourceRoot() or UIParent
  local frame = CreateFrame("Frame", "RetreatUIFelfurySegment" .. index, parent)
  frame:SetSize(25, 25)
  frame:SetFrameStrata("HIGH")
  frame:SetFrameLevel(120 + index)
  RUI:SkinFrame(frame, {0.01, 0.02, 0.01, 0.98}, {0, 0, 0, 1})

  frame.fill = frame:CreateTexture(nil, "BACKGROUND")
  frame.fill:SetPoint("TOPLEFT", 1, -1)
  frame.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.fill:SetVertexColor(0.025, 0.16, 0.025, 1)

  frame.texture = frame:CreateTexture(nil, "ARTWORK")
  frame.texture:SetPoint("TOPLEFT", 1, -1)
  frame.texture:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.texture:SetTexture(FELFURY_TEXTURE)
  frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  frame:Hide()
  return frame
end

local function AnchorSegments()
  local power = type(RUI.GetPrimaryPowerFrame) == "function" and RUI:GetPrimaryPowerFrame() or nil
  local spacing = 1
  local total = MAX_FELFURY * 25 + (MAX_FELFURY - 1) * spacing
  local firstX = -total / 2 + 12.5

  for index, frame in ipairs(segments) do
    frame:ClearAllPoints()
    if power then
      frame:SetPoint("BOTTOM", power, "TOP", firstX + (index - 1) * 26, 8)
    else
      frame:SetPoint("CENTER", UIParent, "CENTER", firstX + (index - 1) * 26, -118)
    end
  end
end

local function EnsureSegments()
  if #segments < MAX_FELFURY then
    for index = #segments + 1, MAX_FELFURY do
      segments[index] = CreateSegment(index)
    end
  end
  AnchorSegments()
end

local function AuraFelfury()
  if not UnitBuff then return nil end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local spellID = tonumber(values[11])
    local lower = string.lower(tostring(name or "")):gsub("[%s%-%_]", "")
    if spellID == FELFURY_AURA_ID or string.find(lower, "felfury", 1, true) then
      local count = tonumber(values[4]) or 0
      return math.max(0, math.min(MAX_FELFURY, count > 0 and count or 1))
    end
  end
  return nil
end

local function CustomPowerFelfury()
  if type(RUI.FindCustomPower) == "function" then
    local result = RUI:FindCustomPower({
      expectedMax = MAX_FELFURY,
      excludeToken = "ENERGY",
      scanMaximumType = 50,
    })
    if result then
      return math.max(0, math.min(MAX_FELFURY, tonumber(result.current) or 0))
    end
  end

  if not UnitPower or not UnitPowerMax then return nil end
  for powerType = 0, 50 do
    if powerType ~= 3 then
      local okMax, maximum = pcall(UnitPowerMax, "player", powerType)
      maximum = okMax and tonumber(maximum) or nil
      if maximum == MAX_FELFURY then
        local okCurrent, current = pcall(UnitPower, "player", powerType)
        if okCurrent then
          return math.max(0, math.min(MAX_FELFURY, tonumber(current) or 0))
        end
      end
    end
  end
  return nil
end

local function NativeFelfury(forceDiscovery)
  if type(RUI.ReadAscensionResourceSnapshot) ~= "function" then return nil end

  local snapshot = RUI:ReadAscensionResourceSnapshot(
    {"felfury", "fel fury"}, "FELFURY", forceDiscovery == true
  )

  -- Some Ascension revisions expose only a generic six-segment container and
  -- no readable Felfury label. The segment count is therefore the safe filter.
  if not snapshot then
    snapshot = RUI:ReadAscensionResourceSnapshot(nil, "FELFURY", forceDiscovery == true)
  end
  if not snapshot then return nil end

  local maximum = tonumber(snapshot.maximum)
  local current = tonumber(snapshot.current)
  if maximum == MAX_FELFURY and current ~= nil then
    return math.max(0, math.min(MAX_FELFURY, current))
  end
  if #(snapshot.segments or {}) == MAX_FELFURY then
    local active = 0
    for _, segment in ipairs(snapshot.segments) do
      if segment.active then active = active + 1 end
    end
    return active
  end
  return nil
end

local function ReadFelfury(forceDiscovery)
  local value = AuraFelfury()
  if value ~= nil then return value, true end

  value = CustomPowerFelfury()
  if value ~= nil then return value, true end

  value = NativeFelfury(forceDiscovery)
  if value ~= nil then return value, true end

  return 0, false
end

local function UpdateSegments(force, forceDiscovery)
  local root = ResourceRoot()
  if not root or not root:IsShown() then return end
  EnsureSegments()

  local stacks, ready = ReadFelfury(forceDiscovery)
  felfurySourceReady = ready == true
  stacks = math.max(0, math.min(MAX_FELFURY, tonumber(stacks) or 0))

  if felfurySourceReady and not lastReady and type(RUI.ScheduleFrameCleanupPasses) == "function" then
    RUI:ScheduleFrameCleanupPasses(true)
  end
  lastReady = felfurySourceReady

  if force or stacks ~= lastStacks then
    lastStacks = stacks
    for index, frame in ipairs(segments) do
      local active = index <= stacks
      frame.fill:SetVertexColor(
        active and 0.08 or 0.025,
        active and 0.78 or 0.16,
        active and 0.04 or 0.025,
        1
      )
      frame.texture:SetVertexColor(
        active and 0.35 or 0.18,
        active and 1.00 or 0.42,
        active and 0.18 or 0.18,
        1
      )
      if frame.texture.SetDesaturated then frame.texture:SetDesaturated(not active) end
      frame:SetAlpha(active and 1 or 0.38)
      frame:Show()
    end
  else
    for _, frame in ipairs(segments) do frame:Show() end
  end
end

local function EnsureEnergyBar()
  if type(RUI.ActivatePrimaryPower) == "function" then RUI:ActivatePrimaryPower() end
  if type(RUI.UpdatePrimaryPower) == "function" then RUI:UpdatePrimaryPower(true) end
  AnchorSegments()
end

local function BuildResourceDriver()
  if resourceDriver then return end

  resourceDriver = CreateFrame("Frame")
  for _, eventName in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "UNIT_AURA", "UNIT_POWER", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER",
    "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE", "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
  }) do pcall(resourceDriver.RegisterEvent, resourceDriver, eventName) end

  resourceDriver:SetScript("OnEvent", function(_, event, unit)
    if unit and unit ~= "player" then return end
    local root = ResourceRoot()
    if not root or not root:IsShown() then return end
    EnsureEnergyBar()
    local discovery = event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
      or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
    UpdateSegments(true, discovery)

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
      for _, delay in ipairs({0.10, 0.50, 1.00, 2.00, 4.00}) do
        RUI:After(delay, function()
          local activeRoot = ResourceRoot()
          if activeRoot and activeRoot:IsShown() then
            EnsureEnergyBar()
            UpdateSegments(true, true)
          end
        end)
      end
    end
  end)

  pollDriver = CreateFrame("Frame")
  pollDriver:Hide()
  pollDriver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.12 then return end
    elapsed = 0
    UpdateSegments(false, false)
  end)
end

function module:activate()
  local result = BaseActivate(self)
  BuildResourceDriver()
  resourceDriver:Show()
  pollDriver:Show()
  elapsed = 0
  lastStacks = nil
  felfurySourceReady = false
  lastReady = false
  EnsureEnergyBar()
  EnsureSegments()
  UpdateSegments(true, true)

  for _, delay in ipairs({0.10, 0.50, 1.00, 2.00, 4.00}) do
    RUI:After(delay, function()
      local root = ResourceRoot()
      if root and root:IsShown() then
        EnsureEnergyBar()
        UpdateSegments(true, true)
      end
    end)
  end
  return result ~= false
end

function module:deactivate()
  if resourceDriver then resourceDriver:Hide() end
  if pollDriver then pollDriver:Hide() end
  for _, frame in ipairs(segments) do frame:Hide() end
  elapsed = 0
  lastStacks = nil
  felfurySourceReady = false
  lastReady = false
  return BaseDeactivate(self)
end
