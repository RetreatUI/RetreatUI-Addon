local RUI = RetreatUI
if not RUI then return end

-- Beta.17: class-resource cleanup may only mutate unprotected Ascension frames.
-- A protected frame (or a child of a protected ancestor) is never hidden,
-- faded, reparented, mouse-disabled, or restored by RetreatUI.
local knownNames = {
  "CoAResourceSegmentBar",
  "CoAResourceSegmentBarContainer", "CoAResourceSegmentContainer",
  "CoAResourceBar", "CoAResourceFrame", "CoAResourceAnchor", "CoAResourceHolder",
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
  knownNames[#knownNames + 1] = "CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate" .. index
  knownNames[#knownNames + 1] = string.format("CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate%02d", index)
end

local discovered = {}
local guarded = setmetatable({}, {__mode="k"})
local managed = setmetatable({}, {__mode="k"})
local scheduledSerial = 0
local pendingCombat = false

local function InCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function FrameLike(frame)
  local kind = type(frame)
  return (kind == "table" or kind == "userdata")
    and frame.GetObjectType ~= nil
    and (frame.SetAlpha ~= nil or frame.Hide ~= nil)
end

local function Shown(frame)
  if not frame or type(frame.IsShown) ~= "function" then return false end
  local ok, value = pcall(frame.IsShown, frame)
  return ok and value == true
end

local function Protected(frame)
  local current, depth = frame, 0
  while current and depth < 12 do
    if current.IsProtected then
      local ok, value = pcall(current.IsProtected, current)
      if ok and value then return true end
    end
    if current == UIParent or current == WorldFrame then break end
    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end
  return false
end

local function DynamicResourceName(name)
  if type(name) ~= "string" or name == "" then return false end
  local lower = string.lower(name)
  if string.find(lower, "retreatui", 1, true) then return false end
  local namespace = string.find(lower, "coa", 1, true)
    or string.find(lower, "ascension", 1, true)
    or string.find(lower, "classless", 1, true)
    or string.find(lower, "conquest", 1, true)
    or string.find(lower, "heroarchitect", 1, true)
  if not namespace then return false end
  return string.find(lower, "resource", 1, true)
    or string.find(lower, "powerbar", 1, true)
    or string.find(lower, "powerframe", 1, true)
    or string.find(lower, "segmentbar", 1, true)
    or string.find(lower, "segmenttemplate", 1, true)
    or string.find(lower, "classbar", 1, true)
end

local function ClassHUDEnabled()
  return type(RUI.IsInstallerModuleEnabled) ~= "function"
    or RUI:IsInstallerModuleEnabled("classHUD")
end

local function CompleteReplacement()
  if not ClassHUDEnabled() then return false end
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

local function RememberFrame(frame)
  if managed[frame] or Protected(frame) then return end
  local alpha = 1
  if frame.GetAlpha then
    local ok, value = pcall(frame.GetAlpha, frame)
    if ok and tonumber(value) then alpha = tonumber(value) end
  end
  managed[frame] = {alpha=alpha, shown=Shown(frame)}
end

local function RestoreFrame(frame, state)
  if not frame or not state or Protected(frame) then return end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, tonumber(state.alpha) or 1) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
  if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, true) end
  if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, true) end
  if state.shown and frame.Show then pcall(frame.Show, frame) end
end

function RUI:RestoreNativeClassResourceFrames()
  if InCombat() then pendingCombat = true; return false end
  for frame, state in pairs(managed) do
    if not Protected(frame) then RestoreFrame(frame, state) end
    managed[frame] = nil
  end
  if type(self.RestoreNativeResourceMirrorSources) == "function" then
    pcall(self.RestoreNativeResourceMirrorSources, self)
  end
  return true
end

local function HideFrame(frame, name)
  if not frame or not FrameLike(frame) or InCombat() or not CompleteReplacement() then return false end

  -- Secure boundary: do not call any mutating method on protected frames.
  if Protected(frame) then return false end

  RememberFrame(frame)
  local mirrored = type(RUI.IsNativeResourceMirrorSource) == "function"
    and RUI:IsNativeResourceMirrorSource(frame)

  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
  if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, false) end
  if not mirrored and frame.Hide then pcall(frame.Hide, frame) end

  if not guarded[frame] and frame.HookScript then
    local ok = pcall(frame.HookScript, frame, "OnShow", function(shown)
      if InCombat() or Protected(shown) or not CompleteReplacement() then return end
      RememberFrame(shown)
      local source = type(RUI.IsNativeResourceMirrorSource) == "function"
        and RUI:IsNativeResourceMirrorSource(shown)
      if shown.SetAlpha then pcall(shown.SetAlpha, shown, 0) end
      if shown.EnableMouse then pcall(shown.EnableMouse, shown, false) end
      if not source and shown.Hide then pcall(shown.Hide, shown) end
    end)
    if ok then guarded[frame] = true end
  end

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.classResourceCleanup = db.integrations.classResourceCleanup or {}
  db.integrations.classResourceCleanup.lastFrame = tostring(name or "unknown")
  db.integrations.classResourceCleanup.version = RUI.version
  db.integrations.classResourceCleanup.secureFrameSafety = true
  return true
end

local function Discover()
  for _, name in ipairs(knownNames) do
    local frame = _G[name]
    if FrameLike(frame) and not Protected(frame) then discovered[frame] = name end
  end
  for name, frame in pairs(_G) do
    if DynamicResourceName(name) and FrameLike(frame) and not Protected(frame) then
      discovered[frame] = name
    end
  end
end

function RUI:HideNativeClassResourceFrames(forceDiscovery)
  if InCombat() then pendingCombat = true; return false, 0 end
  if not CompleteReplacement() then
    self:RestoreNativeClassResourceFrames()
    return false, 0
  end
  if forceDiscovery or not next(discovered) then Discover() end

  local hidden = 0
  for frame, name in pairs(discovered) do
    if not Protected(frame) and HideFrame(frame, name) then hidden = hidden + 1 end
  end
  return hidden > 0, hidden
end

function RUI:ScheduleNativeClassResourceCleanup(forceDiscovery)
  scheduledSerial = scheduledSerial + 1
  local serial = scheduledSerial
  for pass, delay in ipairs({0.05, 0.30, 0.80, 1.60, 3.00}) do
    self:After(delay, function()
      if serial ~= scheduledSerial then return end
      self:HideNativeClassResourceFrames(forceDiscovery == true and pass == 1)
    end)
  end
  return true
end

local events = CreateFrame("Frame", "RetreatUIClassResourceCleanupDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED", "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
  "ASCENSION_KNOWN_ENTRIES_UPDATED", "UNIT_DISPLAYPOWER", "UNIT_POWER_BAR_SHOW",
  "PLAYER_REGEN_ENABLED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName)
  if InCombat() then pendingCombat = true; return end
  if eventName == "PLAYER_REGEN_ENABLED" and not pendingCombat then return end
  pendingCombat = false
  local rediscover = eventName == "PLAYER_LOGIN"
    or eventName == "PLAYER_ENTERING_WORLD"
    or eventName == "ADDON_LOADED"
    or eventName == "SPELLS_CHANGED"
    or eventName == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED"
  RUI:ScheduleNativeClassResourceCleanup(rediscover)
end)

RUI._classResourceSecureSafetyBeta17 = true
