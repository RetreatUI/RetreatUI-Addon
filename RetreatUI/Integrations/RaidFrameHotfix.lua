local RUI = RetreatUI
if not RUI then return end

-- Stable v1.1.1 raid-frame repair.
--
-- The supplied ElvUI baseline used the legacy Raid visibility rule
-- "[@raid6,noexists] hide;show" and explicitly disabled Raid-40. On some
-- Ascension ElvUI 7.27 clients that leaves every raid frame disabled in small
-- raids and never enables the large-raid layout. Repair only the RetreatUI
-- profile and only values that match the RetreatUI-managed legacy defaults.

local REVISION = 1
local LEGACY_RAID_VISIBILITY = "[@raid6,noexists] hide;show"
local RAID_VISIBILITY = "[@raid26,exists] hide; [@raid1,exists] show; hide"
local RAID40_VISIBILITY = "[@raid26,exists] show; hide"
local pendingCombat = false
local scheduledSerial = 0

local function InCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function CurrentProfileName(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return nil
end

local function RepairProfile(profile, forceManaged)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  local changed = false

  units.raid = units.raid or {}
  local raid = units.raid
  local managedRaid = forceManaged == true
    or raid.visibility == LEGACY_RAID_VISIBILITY
    or (raid.enable == nil and raid.visibility == nil)
  if managedRaid then
    if raid.enable ~= true then raid.enable = true; changed = true end
    if forceManaged == true or raid.visibility == nil or raid.visibility == LEGACY_RAID_VISIBILITY then
      if raid.visibility ~= RAID_VISIBILITY then raid.visibility = RAID_VISIBILITY; changed = true end
    end
    if raid.numGroups == nil then raid.numGroups = 8; changed = true end
  end

  units.raid40 = units.raid40 or {}
  local raid40 = units.raid40
  local managedRaid40 = forceManaged == true
    or (raid40.enable == false and raid40.visibility == nil)
    or (raid40.enable == nil and raid40.visibility == nil)
  if managedRaid40 then
    if raid40.enable ~= true then raid40.enable = true; changed = true end
    if forceManaged == true or raid40.visibility == nil then
      if raid40.visibility ~= RAID40_VISIBILITY then raid40.visibility = RAID40_VISIBILITY; changed = true end
    end
  end

  return changed
end

-- Patch the in-memory supplied baseline itself so every future profile install
-- starts with correct raid-frame defaults instead of requiring a later repair.
if type(RUI.ElvUIProfile) == "table" then
  RepairProfile(RUI.ElvUIProfile, true)
end

function RUI:RepairElvUIRaidFrames(refreshLive, forceManaged)
  if InCombat() then pendingCombat = true; return false, "Raid-frame repair deferred until combat ends" end

  local changed = false
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = RepairProfile(ElvDB.profiles.RetreatUI, forceManaged) or changed
  end

  local E = ElvUI and unpack(ElvUI)
  local currentProfile = CurrentProfileName(E)
  if currentProfile == "RetreatUI" and E and E.db then
    changed = RepairProfile(E.db, forceManaged) or changed
  end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.raidFrameRepairRevision = REVISION
  db.integrations.elvui.raidFrameRepairVersion = self.version

  if refreshLive and E and currentProfile == "RetreatUI" then
    if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E.UpdateAll then pcall(E.UpdateAll, E, true) end
    self:After(0.25, function()
      if InCombat() then pendingCombat = true; return end
      if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
      if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
    end)
  end

  return true, changed and "RetreatUI raid and Raid-40 frames enabled" or "RetreatUI raid-frame settings verified"
end

function RUI:ScheduleElvUIRaidFrameRepair(forceManaged)
  scheduledSerial = scheduledSerial + 1
  local serial = scheduledSerial
  for pass, delay in ipairs({0.05, 0.30, 0.80, 1.60}) do
    self:After(delay, function()
      if serial ~= scheduledSerial then return end
      self:RepairElvUIRaidFrames(pass == 1 or pass == 4, forceManaged == true)
    end)
  end
  return true
end

-- A fresh Unitframes & Layout installation and a forced HUD baseline refresh
-- both copy the managed baseline. Repair immediately afterwards so the broken
-- legacy values can never be reintroduced by RetreatUI itself.
local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local results = {originalInstallElvUIProfile(self, ...)}
    if results[1] ~= false then self:ScheduleElvUIRaidFrameRepair(true) end
    return unpack(results)
  end
end

local originalApplyElvUIHUDPolish = RUI.ApplyElvUIHUDPolish
if type(originalApplyElvUIHUDPolish) == "function" then
  function RUI:ApplyElvUIHUDPolish(force, ...)
    local results = {originalApplyElvUIHUDPolish(self, force, ...)}
    if results[1] ~= false then self:ScheduleElvUIRaidFrameRepair(force == true) end
    return unpack(results)
  end
end

local events = CreateFrame("Frame", "RetreatUIRaidFrameHotfixDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
  "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName, addonName)
  if eventName == "ADDON_LOADED" and addonName ~= "ElvUI" and addonName ~= "RetreatUI" then return end
  if InCombat() then pendingCombat = true; return end
  if eventName == "PLAYER_REGEN_ENABLED" and not pendingCombat then return end
  pendingCombat = false

  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = db.integrations.elvui or {}
  local needsMigration = tonumber(db.integrations.elvui.raidFrameRepairRevision) ~= REVISION
  if needsMigration or eventName == "GROUP_ROSTER_UPDATE" then
    RUI:ScheduleElvUIRaidFrameRepair(false)
  end
end)

-- Also cover reloads where ElvUI is already initialized before this file loads.
if type(ElvDB) == "table" then
  RUI:After(0.10, function() RUI:ScheduleElvUIRaidFrameRepair(false) end)
end

RUI._raidFrameHotfixLoaded = true
