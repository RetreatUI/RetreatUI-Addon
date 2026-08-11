local RUI = RetreatUI
if not RUI then return end

-- Beta.17 secure-frame safety.
--
-- RetreatUI must never mutate Blizzard/ElvUI protected unit frames directly.
-- Hiding PlayerFrame, TargetFrame, party frames, action bars, or any protected
-- ancestor can taint the secure execution path even when the mutation happens
-- out of combat. ElvUI owns its unit-frame visibility; this cleanup is limited
-- to unprotected Ascension/CoA cosmetic resource containers only.
local cosmeticCandidates = {
  "CoAResourceSegmentBar",
  "CoAResourceSegmentBarContainer", "CoAResourceSegmentContainer",
  "CoAResourceBar", "CoAResourceFrame", "CoAResourceAnchor", "CoAResourceHolder",
  "CoAResourceOrb",
  "CoAClassResourceBar", "CoAClassResourceFrame", "CoAClassBar",
  "AscensionResourceBar", "AscensionResourceFrame", "AscensionResourceAnchor",
  "AscensionClassResourceBar", "AscensionClassResourceFrame", "AscensionClassBar",
  "AscensionPowerBar", "AscensionPowerFrame",
  "ClasslessResourceBar", "ClasslessResourceFrame", "ClasslessPowerBar",
  "HeroArchitectResourceBar", "HeroArchitectResourceFrame",
  "ConquestResourceBar", "ConquestResourceFrame",
  "ClassResourceBar", "ClassResourceFrame", "ClassResourceContainer",
  "CharacterResourceBar", "CharacterResourceFrame",
}

for index = 1, 24 do
  cosmeticCandidates[#cosmeticCandidates + 1] = "CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate" .. index
  cosmeticCandidates[#cosmeticCandidates + 1] = string.format("CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate%02d", index)
end

local cosmeticCandidateSet = {}
for _, name in ipairs(cosmeticCandidates) do cosmeticCandidateSet[name] = true end

local discoveredResourceNames = {}
local discoveryDirty = true
local cleanupScheduled = false
local eventCleanupPending = false
local guardedResourceFrames = setmetatable({}, {__mode = "k"})

local function InCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function HasCompleteClassResourceReplacement()
  local module = RUI.activeModule
  if not module and type(RUI.GetClassModule) == "function" then
    local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
    module = className and RUI:GetClassModule(className) or nil
  end
  if not module then return false end
  if type(module.customResourcesComplete) == "function" then
    local ok, complete = pcall(module.customResourcesComplete, module)
    return ok and complete == true
  end
  return module.customResourcesComplete == true
end

local function LooksLikeResourceFrameName(name)
  if type(name) ~= "string" or name == "" then return false end
  local lower = string.lower(name)
  if string.find(lower, "retreatui", 1, true) then return false end

  local hasNamespace = string.find(lower, "coa", 1, true)
    or string.find(lower, "ascension", 1, true)
    or string.find(lower, "classless", 1, true)
    or string.find(lower, "conquest", 1, true)
    or string.find(lower, "heroarchitect", 1, true)
  if not hasNamespace then return false end

  return string.find(lower, "resource", 1, true)
    or string.find(lower, "powerbar", 1, true)
    or string.find(lower, "powerframe", 1, true)
    or string.find(lower, "segmentbar", 1, true)
    or string.find(lower, "segmenttemplate", 1, true)
    or string.find(lower, "classbar", 1, true)
end

local function IsNativeClassResourceName(name)
  if LooksLikeResourceFrameName(name) then return true end
  if type(name) ~= "string" or name == "" then return false end
  local lower = string.lower(name)
  return string.find(lower, "resource", 1, true)
    or string.find(lower, "powerbar", 1, true)
    or string.find(lower, "powerframe", 1, true)
    or string.find(lower, "segmentbar", 1, true)
    or string.find(lower, "segmenttemplate", 1, true)
    or string.find(lower, "classbar", 1, true)
end

local function IsFrameLike(value)
  local kind = type(value)
  if kind ~= "table" and kind ~= "userdata" then return false end
  return value.GetObjectType ~= nil and (value.SetAlpha ~= nil or value.Hide ~= nil)
end

local function IsProtectedFrame(frame)
  local current = frame
  local depth = 0
  while current and depth < 12 do
    if current.IsProtected then
      local ok, protected = pcall(current.IsProtected, current)
      if ok and protected then return true end
    end
    if current == UIParent or current == WorldFrame then break end
    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end
  return false
end

local function ClearLegacyState()
  local db = RUI:EnsureDB()
  db.hiddenFrames = db.hiddenFrames or {}
  local cleared = 0

  -- Old builds persisted Blizzard unit-frame names here. They are deliberately
  -- discarded rather than re-applied by beta.17.
  for name in pairs(db.hiddenFrames) do
    if not cosmeticCandidateSet[name] and not discoveredResourceNames[name] then
      db.hiddenFrames[name] = nil
      cleared = cleared + 1
    end
  end

  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.legacyClearedVersion = RUI.version
  db.integrations.frameCleanup.secureFrameSafety = true
  return cleared
end

local function GuardResourceFrame(frame, name)
  if not frame or guardedResourceFrames[frame] or IsProtectedFrame(frame) then return end
  if not LooksLikeResourceFrameName(name) or not frame.HookScript then return end

  local ok = pcall(frame.HookScript, frame, "OnShow", function(shownFrame)
    if InCombat() or IsProtectedFrame(shownFrame) or not HasCompleteClassResourceReplacement() then return end
    local mirrored = type(RUI.IsNativeResourceMirrorSource) == "function" and RUI:IsNativeResourceMirrorSource(shownFrame)
    if shownFrame.SetAlpha then pcall(shownFrame.SetAlpha, shownFrame, 0) end
    if shownFrame.EnableMouse then pcall(shownFrame.EnableMouse, shownFrame, false) end
    if not mirrored and shownFrame.Hide then pcall(shownFrame.Hide, shownFrame) end
  end)
  if ok then guardedResourceFrames[frame] = true end
end

local function HideCosmeticFrame(frame, name)
  if not frame or InCombat() then return false end

  -- Critical beta.17 rule: do absolutely nothing to a protected frame or any
  -- frame parented beneath a protected ancestor. Even harmless-looking visual
  -- calls can taint secure execution for the rest of the session.
  if IsProtectedFrame(frame) then return false end

  local mirrored = type(RUI.IsNativeResourceMirrorSource) == "function" and RUI:IsNativeResourceMirrorSource(frame)
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
  if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, false) end
  if not mirrored and frame.Hide then pcall(frame.Hide, frame) end

  GuardResourceFrame(frame, name)
  local db = RUI:EnsureDB()
  db.hiddenFrames = db.hiddenFrames or {}
  db.hiddenFrames[name] = true
  return true
end

local function DiscoverResourceGlobals()
  if not discoveryDirty then return 0 end
  discoveryDirty = false
  local found = 0

  for name, value in pairs(_G) do
    if LooksLikeResourceFrameName(name) and IsFrameLike(value) and not IsProtectedFrame(value) then
      if not discoveredResourceNames[name] then found = found + 1 end
      discoveredResourceNames[name] = true
      cosmeticCandidateSet[name] = true
    end
  end
  return found
end

local function RunLightweightCleanup(forceDiscovery)
  if InCombat() then return 0 end
  if forceDiscovery then discoveryDirty = true end
  DiscoverResourceGlobals()

  local hidden = 0
  local seen = {}
  local function TryHide(name)
    if not name or seen[name] then return end
    seen[name] = true
    if IsNativeClassResourceName(name) and not HasCompleteClassResourceReplacement() then return end
    local frame = _G[name]
    if frame and IsFrameLike(frame) and not IsProtectedFrame(frame) and HideCosmeticFrame(frame, name) then
      hidden = hidden + 1
    end
  end

  for _, name in ipairs(cosmeticCandidates) do TryHide(name) end
  for name in pairs(discoveredResourceNames) do TryHide(name) end

  local db = RUI:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.lastScanCount = hidden
  db.integrations.frameCleanup.discoveredResourceCount = 0
  for _ in pairs(discoveredResourceNames) do
    db.integrations.frameCleanup.discoveredResourceCount = db.integrations.frameCleanup.discoveredResourceCount + 1
  end
  db.integrations.frameCleanup.version = RUI.version
  db.integrations.frameCleanup.secureFrameSafety = true
  return hidden
end

function RUI:RunFrameCleanupNow()
  discoveryDirty = true
  ClearLegacyState()
  local hidden = RunLightweightCleanup(true)
  return true, tostring(hidden) .. " unprotected duplicate resource frames hidden"
end

function RUI:ScheduleFrameCleanupPasses(forceDiscovery)
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  if db.integrations.frameCleanup.enabled == false or cleanupScheduled then return false end

  if forceDiscovery then discoveryDirty = true end
  cleanupScheduled = true
  local delays = {0.05, 0.35, 1.0, 2.5, 5.0}
  for index, delay in ipairs(delays) do
    self:After(delay, function()
      if type(RetreatUI.IsSupportedCharacter) == "function" and not RetreatUI:IsSupportedCharacter() then
        if index == #delays then cleanupScheduled = false end
        return
      end
      RunLightweightCleanup(index == 1 and forceDiscovery)
      if index == #delays then cleanupScheduled = false end
    end)
  end
  return true
end

function RUI:HideDuplicateFrames()
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.enabled = true
  discoveryDirty = true
  ClearLegacyState()
  local hidden = RunLightweightCleanup(true)
  self:ScheduleFrameCleanupPasses(true)
  return true, tostring(hidden) .. " safe duplicate resource frames hidden"
end

function RUI:ApplyHiddenFrames()
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  discoveryDirty = true
  ClearLegacyState()
  if db.integrations.frameCleanup.enabled ~= false then
    RunLightweightCleanup(true)
    self:ScheduleFrameCleanupPasses(true)
  end
  return true
end

local function QueueEventCleanup(forceDiscovery)
  local db = RUI:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  if db.integrations.frameCleanup.enabled == false then return end
  if forceDiscovery then discoveryDirty = true end
  if eventCleanupPending then return end
  eventCleanupPending = true
  RUI:After(0.05, function()
    eventCleanupPending = false
    RunLightweightCleanup(forceDiscovery)
  end)
  RUI:After(0.45, function() RunLightweightCleanup(false) end)
end

local cleanupEvents = CreateFrame("Frame", "RetreatUISafeCleanupDriver")
local cleanupPendingCombat = false
local cleanupEventNames = {
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
  "SPELLS_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "CHARACTER_POINTS_CHANGED",
  "UPDATE_SHAPESHIFT_FORM",
  "UNIT_DISPLAYPOWER",
  "UNIT_POWER_BAR_SHOW",
  "UNIT_POWER_BAR_HIDE",
  "PLAYER_LEVEL_UP",
  "PLAYER_REGEN_ENABLED",
}
for _, eventName in ipairs(cleanupEventNames) do
  pcall(cleanupEvents.RegisterEvent, cleanupEvents, eventName)
end

cleanupEvents:SetScript("OnEvent", function(_, event)
  if type(RUI.IsSupportedCharacter) == "function" and not RUI:IsSupportedCharacter() then return end
  if InCombat() then
    cleanupPendingCombat = true
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and not cleanupPendingCombat then return end
  cleanupPendingCombat = false

  local rediscover = event == "ADDON_LOADED"
    or event == "PLAYER_ENTERING_WORLD"
    or event == "SPELLS_CHANGED"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "CHARACTER_POINTS_CHANGED"
    or event == "UPDATE_SHAPESHIFT_FORM"
  QueueEventCleanup(rediscover)
end)

RUI._secureFrameCleanupBeta17 = true
