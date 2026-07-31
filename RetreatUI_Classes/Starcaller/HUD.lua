local RUI = RetreatUI
if not RUI then return end

local CLASS_NAME = "Starcaller"
local W = RUI.HUDWidgets
local module = RUI:RegisterAdvancedClassHUD(CLASS_NAME, {
  frameName = "RetreatUIStarcallerHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {ASTRALWARFARE=true,HYDROMANCY=true,MOONBOW=true,TIDES=true},
})

local tracker
local trackerEvents
local trackerDriver
local trackerElapsed = 0
local lastSignature

local FALLBACK_CONFIG = {
  title = "SCATTERED STARS",
  spellIDs = {804378, 254271, 807301},
  auraNames = {"Scattered Stars", "Shattered Stars"},
  maximum = 8,
  size = 24,
  spacing = 2,
  x = 0,
  y = -118,
  labelY = -136,
  icon = "Interface\\Icons\\Spell_Arcane_StarFire",
}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function Config()
  local database = RUI:GetClassSpellDatabase(CLASS_NAME) or {}
  return database.targetResource or FALLBACK_CONFIG
end

local function IsValidTarget()
  if type(UnitExists) ~= "function" or not UnitExists("target") then return false end
  if type(UnitIsDeadOrGhost) == "function" then
    local ok, dead = pcall(UnitIsDeadOrGhost, "target")
    if ok and dead == true then return false end
  elseif type(UnitIsDead) == "function" then
    local ok, dead = pcall(UnitIsDead, "target")
    if ok and dead == true then return false end
  end
  -- Ascension may briefly report hostile units as non-attackable while the
  -- target token changes. Only reject a target when it is confirmed friendly.
  if type(UnitIsFriend) == "function" then
    local ok, friendly = pcall(UnitIsFriend, "player", "target")
    if ok and friendly == true then return false end
  end
  return true
end

local function IsOwnCaster(caster)
  return caster == "player" or caster == "vehicle" or caster == "pet"
end

local function ReadTargetStars(config)
  if not IsValidTarget() or type(UnitDebuff) ~= "function" then return nil end

  local ids, names = {}, {}
  for _, spellID in ipairs(config.spellIDs or {}) do ids[tonumber(spellID)] = true end
  for _, name in ipairs(config.auraNames or {}) do names[Normalize(name)] = true end

  local fallback
  for index = 1, 40 do
    local values = {UnitDebuff("target", index)}
    local name = values[1]
    if not name then break end
    local aura = {
      name = name,
      icon = values[3],
      count = tonumber(values[4]) or 0,
      duration = tonumber(values[6]) or 0,
      expires = tonumber(values[7]) or 0,
      caster = values[8],
      spellID = tonumber(values[11]),
    }
    local matched = (aura.spellID and ids[aura.spellID]) or names[Normalize(aura.name)]
    if matched then
      if IsOwnCaster(aura.caster) then return aura end
      -- Some Ascension aura builds omit the caster token. Keep this as a safe
      -- fallback, but never use an aura explicitly owned by another unit.
      if aura.caster == nil and not fallback then fallback = aura end
    end
  end
  return fallback
end

local function BuildTracker()
  if tracker then return tracker end
  local config = Config()
  local parent = _G.RetreatUIStarcallerHUD or UIParent
  local theme = RUI:GetTheme()

  tracker = CreateFrame("Frame", "RetreatUIStarcallerScatteredStars", parent)
  tracker:SetSize(260, 50)
  tracker:SetPoint("CENTER", UIParent, "CENTER", tonumber(config.x) or 0, tonumber(config.y) or -118)
  tracker:SetFrameStrata("MEDIUM")
  tracker.segments = {}

  tracker.label = tracker:CreateFontString(nil, "OVERLAY")
  tracker.label:SetPoint("CENTER", UIParent, "CENTER", tonumber(config.x) or 0, tonumber(config.labelY) or -136)
  RUI:ApplyFont(tracker.label, 8, "OUTLINE")
  tracker.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

  local maximum = math.max(1, math.floor(tonumber(config.maximum) or 8))
  local size = math.max(16, math.floor(tonumber(config.size) or 24))
  local spacing = math.max(0, math.floor(tonumber(config.spacing) or 2))
  local total = maximum * size + (maximum - 1) * spacing
  local firstX = -total / 2 + size / 2

  for index = 1, maximum do
    local segment = W:CreateIcon(tracker, size)
    segment:SetPoint("CENTER", tracker, "CENTER", firstX + (index - 1) * (size + spacing), 0)
    segment.texture:SetTexture(config.icon or FALLBACK_CONFIG.icon)
    segment.cooldownShade:Hide()
    segment.cooldownText:SetText("")
    segment.stackText:SetText("")
    tracker.segments[index] = segment
  end

  tracker:Hide()
  return tracker
end

local function HideTracker()
  if not tracker then return end
  tracker:Hide()
  tracker.label:Hide()
  for _, segment in ipairs(tracker.segments or {}) do segment:Hide() end
  lastSignature = nil
end

local function UpdateTracker(force)
  local frame = BuildTracker()
  local config = Config()
  if not IsValidTarget() then HideTracker(); return end

  local aura = ReadTargetStars(config)
  local maximum = math.max(1, math.floor(tonumber(config.maximum) or 8))
  local current = aura and (tonumber(aura.count) or 0) or 0
  if aura and current <= 0 then current = 1 end
  current = math.max(0, math.min(maximum, math.floor(current + 0.5)))

  local targetGUID = type(UnitGUID) == "function" and UnitGUID("target") or ""
  local signature = table.concat({tostring(targetGUID or ""), tostring(aura and aura.spellID or ""), tostring(current), tostring(aura and aura.icon or "")}, "|")
  if not force and signature == lastSignature then return end
  lastSignature = signature

  local theme = RUI:GetTheme()
  local icon = (aura and aura.icon) or config.icon or FALLBACK_CONFIG.icon
  frame.label:SetText(string.format("STARS  %d / %d", current, maximum))
  if current >= maximum then
    frame.label:SetTextColor(theme.accent2[1], theme.accent2[2], theme.accent2[3], 1)
  elseif current >= 4 then
    frame.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  else
    frame.label:SetTextColor(0.72, 0.76, 0.88, 1)
  end

  for index, segment in ipairs(frame.segments or {}) do
    local active = index <= current
    segment.texture:SetTexture(icon)
    segment.texture:SetVertexColor(active and 1 or 0.42, active and 1 or 0.42, active and 1 or 0.48, 1)
    if segment.texture.SetDesaturated then segment.texture:SetDesaturated(not active) end
    segment:SetAlpha(active and 1 or 0.24)
    W:SetBorder(segment, active and (current >= 4 and theme.accent2 or theme.accent) or {0.16, 0.18, 0.24, 1}, active and 1 or 0.65)
    W:SetGlow(segment, current >= maximum and active and theme.accent2 or nil, current >= maximum and active and 0.30 or 0)
    segment:Show()
  end

  frame:Show()
  frame.label:Show()
end

local function ActivateTracker()
  BuildTracker()
  if not trackerEvents then
    trackerEvents = CreateFrame("Frame")
    for _, eventName in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_AURA", "UNIT_TARGET"}) do
      pcall(trackerEvents.RegisterEvent, trackerEvents, eventName)
    end
    trackerEvents:SetScript("OnEvent", function(_, event, unit)
      if event == "UNIT_AURA" and unit ~= "target" then return end
      if event == "UNIT_TARGET" and unit ~= "player" then return end
      UpdateTracker(true)
    end)
  end
  if not trackerDriver then
    trackerDriver = CreateFrame("Frame")
    trackerDriver:SetScript("OnUpdate", function(_, elapsed)
      trackerElapsed = trackerElapsed + elapsed
      if trackerElapsed < 0.12 then return end
      trackerElapsed = 0
      UpdateTracker(false)
    end)
  end
  trackerEvents:Show()
  trackerDriver:Show()
  trackerElapsed = 0
  UpdateTracker(true)
  if type(RUI.ScheduleFrameCleanupPasses) == "function" then
    RUI:After(0.05, function() RUI:ScheduleFrameCleanupPasses(true) end)
  end
end

local function DeactivateTracker()
  if trackerEvents then trackerEvents:Hide() end
  if trackerDriver then trackerDriver:Hide() end
  trackerElapsed = 0
  HideTracker()
end

local baseActivate = module.activate
function module:activate()
  local result = baseActivate(self)
  ActivateTracker()
  return result
end

local baseDeactivate = module.deactivate
function module:deactivate()
  DeactivateTracker()
  return baseDeactivate(self)
end

-- Scattered Stars replaces Starcaller's native segmented class-resource frame.
-- Lunar Phase and Lunar Charge remain in the normal Procs/Buffs row.
function module.customResourcesComplete()
  return tracker ~= nil
end
