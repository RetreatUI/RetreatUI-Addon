local RUI = RetreatUI

-- ElvUI already owns the Blizzard player, target and party unit frames. RetreatUI
-- must not scan or manipulate arbitrary UI frames, because secure unit frames can
-- taint Blizzard's state driver and because a full EnumerateFrames scan is very
-- expensive whenever another addon is loaded.
--
-- Only explicitly named Blizzard/Ascension frames are eligible for cleanup.
-- Protected unit frames are made transparent and non-interactive without
-- touching SecureStateDriver attributes; unprotected resource frames are hidden.
local cosmeticCandidates = {
  -- Exact unit-frame names confirmed with /framestack on the Ascension client.
  -- These are handled directly; RetreatUI never enumerates the global frame tree.
  "playerFrame", "PlayerFrame", "TargetFrame",
  "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",

  -- Exact Ascension resource containers.
  "CoAResourceSegmentBar",
  "AscensionResourceBar", "AscensionResourceFrame",
  "AscensionClassResourceBar", "AscensionPowerBar",
  "AscensionBuffFrame", "AscensionAuraFrame",
  "ClasslessResourceBar", "ClasslessResourceFrame",
  "HeroArchitectResourceBar", "HeroArchitectResourceFrame",
  "ConquestResourceBar", "ConquestResourceFrame",
  "CoAResourceBar", "CoAResourceFrame",
  "ClassResourceBar", "CharacterResourceBar",
}

-- Ascension creates its segmented resource frames from a small named pool.
-- Checking a fixed set of known names is effectively free and avoids the old,
-- expensive and unsafe EnumerateFrames discovery code.
for index = 1, 12 do
  cosmeticCandidates[#cosmeticCandidates + 1] = "CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate" .. index
end
-- Saved frame names written by older versions are migrated by retaining only
-- this small explicit allow-list. Names discovered by the retired broad scan
-- are discarded instead of being touched again.

local cosmeticCandidateSet = {}
for _, name in ipairs(cosmeticCandidates) do cosmeticCandidateSet[name] = true end

local cleanupScheduled = false

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

local function InCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function ClearLegacyState()
  local db = RUI:EnsureDB()
  local cleared = 0

  for name in pairs(db.hiddenFrames) do
    -- Only the small explicit cosmetic allow-list remains valid. Every other
    -- saved entry came from the retired frame-discovery system.
    if not cosmeticCandidateSet[name] then
      db.hiddenFrames[name] = nil
      cleared = cleared + 1
    end
  end

  -- Old runtime hooks and visual changes do not survive a full client restart.
  -- Do not touch any legacy Blizzard or Ascension frame here; clearing the saved
  -- names is enough and guarantees this migration cannot taint secure UI code.

  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.legacyClearedVersion = RUI.version
  return cleared
end

local function HideCosmeticFrame(frame, name)
  if not frame or InCombat() then return false end

  local protected = IsProtectedFrame(frame)
  -- Alpha and mouse state are enough for protected Blizzard-style unit frames
  -- and avoid touching SecureStateDriver attributes. Unprotected Ascension
  -- resource frames can additionally be hidden normally.
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if not protected and frame.Hide then pcall(frame.Hide, frame) end

  frame.__RetreatUICosmeticHidden = true
  local db = RUI:EnsureDB()
  db.hiddenFrames[name] = true
  return true
end

local function RunLightweightCleanup()
  if InCombat() then return 0 end
  local hidden = 0
  for _, name in ipairs(cosmeticCandidates) do
    local frame = _G[name]
    if frame and HideCosmeticFrame(frame, name) then hidden = hidden + 1 end
  end

  local db = RUI:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.lastScanCount = hidden
  db.integrations.frameCleanup.lastHidden = nil
  db.integrations.frameCleanup.version = RUI.version
  return hidden
end

function RUI:RunFrameCleanupNow()
  ClearLegacyState()
  local hidden = RunLightweightCleanup()
  return true, tostring(hidden) .. " explicit duplicate frames hidden"
end

function RUI:ScheduleFrameCleanupPasses()
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  if db.integrations.frameCleanup.enabled == false or cleanupScheduled then return false end

  cleanupScheduled = true
  local delays = {0.25, 1.25, 3.0}
  for index, delay in ipairs(delays) do
    self:After(delay, function()
      if type(RetreatUI.IsSupportedCharacter) == "function" and not RetreatUI:IsSupportedCharacter() then
        if index == #delays then cleanupScheduled = false end
        return
      end
      RunLightweightCleanup()
      if index == #delays then cleanupScheduled = false end
    end)
  end
  return true
end

function RUI:HideDuplicateFrames()
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  db.integrations.frameCleanup.enabled = true
  ClearLegacyState()
  local hidden = RunLightweightCleanup()
  self:ScheduleFrameCleanupPasses()
  return true, tostring(hidden) .. " safe duplicate frames hidden"
end


function RUI:ApplyHiddenFrames()
  local db = self:EnsureDB()
  db.integrations.frameCleanup = db.integrations.frameCleanup or {}
  ClearLegacyState()
  if db.integrations.frameCleanup.enabled ~= false then
    RunLightweightCleanup()
    self:ScheduleFrameCleanupPasses()
  end
  return true
end


-- Blizzard can recreate or show party frames after the initial login passes.
-- Re-apply the tiny explicit allow-list when group state changes. This is not a
-- frame-tree scan and performs no work while the current class is unsupported.
local cleanupEvents = CreateFrame("Frame")
local cleanupPending = false
local cleanupEventNames = {
  "PLAYER_ENTERING_WORLD",
  "PARTY_MEMBERS_CHANGED",
  "RAID_ROSTER_UPDATE",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_REGEN_ENABLED",
}
for _, eventName in ipairs(cleanupEventNames) do
  pcall(cleanupEvents.RegisterEvent, cleanupEvents, eventName)
end
cleanupEvents:SetScript("OnEvent", function(_, event)
  if type(RUI.IsSupportedCharacter) == "function" and not RUI:IsSupportedCharacter() then return end
  if InCombat() then
    cleanupPending = true
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and not cleanupPending then return end
  cleanupPending = false
  RUI:After(0.05, RunLightweightCleanup)
  RUI:After(0.40, RunLightweightCleanup)
end)
