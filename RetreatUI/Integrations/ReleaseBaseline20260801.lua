local RUI = RetreatUI
if not RUI then return end

-- Runtime repairs paired with the user-approved 2026-08-01 ElvUI baseline.
-- These corrections are intentionally scoped to the RetreatUI profile and do
-- not delete profiles, SavedVariables, or unrelated user configuration.

local BASELINE_REVISION = 1
local MOBSPELLS_REVISION = 1
local RAID_REVISION = 2

local RAID_VISIBILITY = "[@raid26,exists] hide; [@raid1,exists] show; hide"
local RAID40_VISIBILITY = "[@raid26,exists] show; hide"

local PYRO_RESOURCE_NAMES = {
  "CoAResourceBar",
  "CoAResourceSegmentBar",
  "CoAResourceSegmentBarContainer",
  "CoAResourceSegmentContainer",
}

for index = 1, 24 do
  PYRO_RESOURCE_NAMES[#PYRO_RESOURCE_NAMES + 1] =
    "CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate" .. index
  PYRO_RESOURCE_NAMES[#PYRO_RESOURCE_NAMES + 1] =
    string.format("CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate%02d", index)
end

local pyroManaged = setmetatable({}, {__mode = "k"})
local pendingRaidRepair = false
local elapsed = 0

local function InCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function CurrentElvUI()
  if not ElvUI then return nil end
  local ok, E = pcall(unpack, ElvUI)
  return ok and E or nil
end

local function CurrentProfileName(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return nil
end

local function RetreatUIProfileTables()
  local E = CurrentElvUI()
  local persisted = type(ElvDB) == "table"
    and type(ElvDB.profiles) == "table"
    and ElvDB.profiles.RetreatUI
    or nil
  local live = CurrentProfileName(E) == "RetreatUI" and E and E.db or nil
  return E, persisted, live
end

local function ApplyApprovedLayout(profile)
  if type(profile) ~= "table" or type(RUI.ElvUIProfile) ~= "table" then return false end
  local baseline = RUI.ElvUIProfile
  local changed = false

  profile.chat = profile.chat or {}
  if profile.chat.editBoxPosition ~= nil then
    profile.chat.editBoxPosition = nil
    changed = true
  end

  profile.movers = profile.movers or {}
  local managedMovers = {
    "ElvUF_PlayerCastbarMover",
    "ElvUF_PetMover",
    "ElvUF_FocusMover",
    "ElvUF_RaidMover",
    "ElvUF_Raid40Mover",
    "TimeManagerFrameMover",
    "TotemBarMover",
    "WatchFrameMover",
  }
  for _, mover in ipairs(managedMovers) do
    local desired = baseline.movers and baseline.movers[mover]
    if desired and profile.movers[mover] ~= desired then
      profile.movers[mover] = desired
      changed = true
    end
  end

  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  units.player = units.player or {}
  units.player.castbar = units.player.castbar or {}
  local desiredWidth = baseline.unitframe
    and baseline.unitframe.units
    and baseline.unitframe.units.player
    and baseline.unitframe.units.player.castbar
    and baseline.unitframe.units.player.castbar.width
    or 365
  if units.player.castbar.width ~= desiredWidth then
    units.player.castbar.width = desiredWidth
    changed = true
  end

  return changed
end

function RUI:ApplyApprovedElvUIBaseline(refreshLive)
  local E, persisted, live = RetreatUIProfileTables()
  local changed = false
  if persisted then changed = ApplyApprovedLayout(persisted) or changed end
  if live and live ~= persisted then changed = ApplyApprovedLayout(live) or changed end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.approvedBaselineRevision = BASELINE_REVISION
  db.integrations.elvui.approvedBaselineVersion = self.version

  if refreshLive and E and live and not InCombat() then
    if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end

  return true, changed and "Approved ElvUI baseline applied" or "Approved ElvUI baseline verified"
end

local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local results = {originalInstallElvUIProfile(self, ...)}
    if results[1] ~= false then
      self:ApplyApprovedElvUIBaseline(true)
      if type(self.ScheduleElvUIRaidFrameRepairV2) == "function" then
        self:ScheduleElvUIRaidFrameRepairV2(true)
      end
    end
    return unpack(results)
  end
end

local originalApplyElvUIHUDPolish = RUI.ApplyElvUIHUDPolish
if type(originalApplyElvUIHUDPolish) == "function" then
  function RUI:ApplyElvUIHUDPolish(force, ...)
    local results = {originalApplyElvUIHUDPolish(self, force, ...)}
    if results[1] ~= false and force == true then
      self:ApplyApprovedElvUIBaseline(true)
    end
    return unpack(results)
  end
end

function RUI:ApplyMobSpellsTooltipBaseline(force)
  if type(MobSpellsCfg) ~= "table" then
    return false, "MobSpells settings are not loaded"
  end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.mobSpells = db.integrations.mobSpells or {}
  local state = db.integrations.mobSpells

  if not force and tonumber(state.tooltipBaselineRevision) == MOBSPELLS_REVISION then
    return true, "MobSpells compact tooltip baseline already applied"
  end

  MobSpellsCfg.showAbilitiesDesc = false
  MobSpellsCfg.modifierKey = 4
  MobSpellsCfg.showAbilitiesLabel = false

  state.tooltipBaselineRevision = MOBSPELLS_REVISION
  state.tooltipBaselineVersion = self.version
  return true, "MobSpells descriptions and Abilities label disabled"
end

local originalApplyMobSpellsToTurboPlates = RUI.ApplyMobSpellsToTurboPlates
if type(originalApplyMobSpellsToTurboPlates) == "function" then
  function RUI:ApplyMobSpellsToTurboPlates(...)
    self:ApplyMobSpellsTooltipBaseline(true)
    return originalApplyMobSpellsToTurboPlates(self, ...)
  end
end

local function RepairRaidProfile(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  local changed = false

  units.raid = units.raid or {}
  if units.raid.enable ~= true then units.raid.enable = true; changed = true end
  if units.raid.visibility ~= RAID_VISIBILITY then
    units.raid.visibility = RAID_VISIBILITY
    changed = true
  end
  if units.raid.numGroups == nil then units.raid.numGroups = 8; changed = true end

  units.raid40 = units.raid40 or {}
  if units.raid40.enable ~= true then units.raid40.enable = true; changed = true end
  if units.raid40.visibility ~= RAID40_VISIBILITY then
    units.raid40.visibility = RAID40_VISIBILITY
    changed = true
  end
  if units.raid40.numGroups == nil then units.raid40.numGroups = 8; changed = true end

  return changed
end

local function RefreshRaidHeaders(E)
  if not E or InCombat() then return false end
  local UF
  if E.GetModule then
    local ok, value = pcall(E.GetModule, E, "UnitFrames", true)
    if ok then UF = value end
  end
  if not UF then return false end

  if E.UpdateAll then pcall(E.UpdateAll, E, true) end

  if UF.CreateAndUpdateHeaderGroup then
    pcall(UF.CreateAndUpdateHeaderGroup, UF, "raid")
    pcall(UF.CreateAndUpdateHeaderGroup, UF, "raid40")
  end

  local raidHeader = _G.ElvUF_Raid
  local raidHolder = raidHeader and raidHeader.GetParent and raidHeader:GetParent() or nil
  if raidHolder and UF.RaidSmartVisibility then
    pcall(UF.RaidSmartVisibility, raidHolder, "GROUP_ROSTER_UPDATE")
  end

  local raid40Header = _G.ElvUF_Raid40
  local raid40Holder = raid40Header and raid40Header.GetParent and raid40Header:GetParent() or nil
  if raid40Holder and UF.Raid40SmartVisibility then
    pcall(UF.Raid40SmartVisibility, raid40Holder, "GROUP_ROSTER_UPDATE")
  end

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  return true
end

function RUI:RepairElvUIRaidFramesV2(refreshLive)
  if InCombat() then
    pendingRaidRepair = true
    return false, "Raid-frame repair deferred until combat ends"
  end

  local E, persisted, live = RetreatUIProfileTables()
  local changed = false
  if persisted then changed = RepairRaidProfile(persisted) or changed end
  if live and live ~= persisted then changed = RepairRaidProfile(live) or changed end

  if E and E.private then
    E.private.unitframe = E.private.unitframe or {}
    E.private.unitframe.enable = true
    E.private.unitframe.disabledBlizzardFrames =
      E.private.unitframe.disabledBlizzardFrames or {}
    E.private.unitframe.disabledBlizzardFrames.raid = true
  end

  if refreshLive and live then RefreshRaidHeaders(E) end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.elvui = db.integrations.elvui or {}
  local state = db.integrations.elvui
  state.raidFrameRepairRevision = RAID_REVISION
  state.raidFrameRepairVersion = self.version
  state.raidFrameExists = _G.ElvUF_Raid ~= nil
  state.raid40FrameExists = _G.ElvUF_Raid40 ~= nil

  return true, changed and "Raid and Raid-40 frames repaired" or "Raid-frame settings verified"
end

function RUI:ScheduleElvUIRaidFrameRepairV2(forceRefresh)
  for _, delay in ipairs({0.05, 0.35, 1.00, 2.50}) do
    self:After(delay, function()
      if InCombat() then pendingRaidRepair = true; return end
      self:RepairElvUIRaidFramesV2(forceRefresh == true)
    end)
  end
  return true
end

local function NormalizedClass()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
  if RUI.NormalizeClassName then className = RUI:NormalizeClassName(className) or className end
  return string.lower(tostring(className or "")):gsub("[^%a%d]", "")
end

local function PyromancerReplacementReady()
  if NormalizedClass() ~= "pyromancer" then return false end
  if type(RUI.IsInstallerModuleEnabled) == "function"
    and not RUI:IsInstallerModuleEnabled("classHUD") then return false end
  local root = _G.RetreatUIPyromancerHUD
  local bar = root and root.resourceBar
  return root and root.IsShown and root:IsShown()
    and bar and bar.IsShown and bar:IsShown()
end

local function FrameAlpha(frame)
  if frame and frame.GetAlpha then
    local ok, value = pcall(frame.GetAlpha, frame)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return 1
end

local function SuppressPyroFrame(frame)
  if not frame then return false end
  if not pyroManaged[frame] then
    local alpha = FrameAlpha(frame)
    pyroManaged[frame] = {alpha = alpha > 0 and alpha or 1}
  end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
  if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, false) end
  return true
end

local function RestorePyroFrames()
  for frame, state in pairs(pyroManaged) do
    if frame and frame.SetAlpha then pcall(frame.SetAlpha, frame, state.alpha or 1) end
    if frame and frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
    if frame and frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, true) end
    if frame and frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, true) end
    pyroManaged[frame] = nil
  end
end

function RUI:EnforcePyromancerNativeResourceSuppression()
  if InCombat() then return false, 0 end
  if not PyromancerReplacementReady() then
    RestorePyroFrames()
    return false, 0
  end

  local hidden = 0
  for _, name in ipairs(PYRO_RESOURCE_NAMES) do
    if SuppressPyroFrame(_G[name]) then hidden = hidden + 1 end
  end

  local segmentBar = _G.CoAResourceSegmentBar
  if segmentBar and segmentBar.GetChildren then
    for _, child in ipairs({segmentBar:GetChildren()}) do
      if SuppressPyroFrame(child) then hidden = hidden + 1 end
    end
  end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.classResourceCleanup = db.integrations.classResourceCleanup or {}
  db.integrations.classResourceCleanup.pyromancerExactFrames = hidden
  db.integrations.classResourceCleanup.pyromancerExactVersion = self.version
  return hidden > 0, hidden
end

local events = CreateFrame("Frame", "RetreatUIReleaseBaselineDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
  "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
  "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName, addonName)
  if eventName == "ADDON_LOADED" then
    if addonName == "MobSpells"
      and (type(RUI.IsInstallerModuleEnabled) ~= "function"
        or RUI:IsInstallerModuleEnabled("npcTracking")) then
      RUI:ApplyMobSpellsTooltipBaseline(false)
    elseif addonName ~= "ElvUI" and addonName ~= "RetreatUI"
      and addonName ~= "RetreatUI_Classes" then
      return
    end
  end

  if eventName == "PLAYER_REGEN_ENABLED" then
    if pendingRaidRepair then
      pendingRaidRepair = false
      RUI:ScheduleElvUIRaidFrameRepairV2(true)
    end
  elseif eventName == "PLAYER_LOGIN" or eventName == "PLAYER_ENTERING_WORLD"
    or eventName == "GROUP_ROSTER_UPDATE" or eventName == "ADDON_LOADED" then
    RUI:ScheduleElvUIRaidFrameRepairV2(true)
  end

  RUI:After(0.10, function() RUI:EnforcePyromancerNativeResourceSuppression() end)
end)

events:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.20 then return end
  elapsed = 0
  RUI:EnforcePyromancerNativeResourceSuppression()
end)

SLASH_RETREATUIRAIDDIAG1 = "/ruiraid"
SlashCmdList.RETREATUIRAIDDIAG = function()
  local E, _, live = RetreatUIProfileTables()
  local units = live and live.unitframe and live.unitframe.units or {}
  local raid = units and units.raid or {}
  local raid40 = units and units.raid40 or {}
  local raidShown = _G.ElvUF_Raid and _G.ElvUF_Raid.IsShown
    and _G.ElvUF_Raid:IsShown() or false
  local raid40Shown = _G.ElvUF_Raid40 and _G.ElvUF_Raid40.IsShown
    and _G.ElvUF_Raid40:IsShown() or false
  RUI:Print("ElvUI profile: " .. tostring(CurrentProfileName(E) or "unknown"))
  RUI:Print("Raid enabled: " .. tostring(raid.enable)
    .. " | frame: " .. tostring(_G.ElvUF_Raid ~= nil)
    .. " | shown: " .. tostring(raidShown))
  RUI:Print("Raid visibility: " .. tostring(raid.visibility))
  RUI:Print("Raid40 enabled: " .. tostring(raid40.enable)
    .. " | frame: " .. tostring(_G.ElvUF_Raid40 ~= nil)
    .. " | shown: " .. tostring(raid40Shown))
  RUI:Print("Raid40 visibility: " .. tostring(raid40.visibility))
end

RUI._releaseBaseline20260801Loaded = true
