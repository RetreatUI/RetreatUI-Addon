local RUI = RetreatUI
if not RUI or RUI._performanceRefreshCoordinatorLoaded then return end

-- BuildProfiles historically owned its own four-pass event driver while
-- Core/Events and every AdvancedHUD instance reacted to the same events. Keep
-- BuildProfiles as the profile engine, but make Core/Events the single owner of
-- scheduled build/HUD refreshes.
local buildDriver = _G.RetreatUIBuildProfileDriver
if buildDriver and type(buildDriver.UnregisterAllEvents) == "function" then
  buildDriver:UnregisterAllEvents()
  buildDriver:Hide()
end

local originalRefreshBuildProfile = RUI.RefreshBuildProfile
local originalScheduleBuildProfileRefresh = RUI.ScheduleBuildProfileRefresh

if type(originalRefreshBuildProfile) == "function" then
  function RUI:RefreshBuildProfile(reason, force, spellbookAlreadyScanned)
    if spellbookAlreadyScanned ~= true or not self.spellbook or type(self.ScanSpellbook) ~= "function" then
      return originalRefreshBuildProfile(self, reason, force)
    end

    -- The original profile engine asks for another spellbook scan internally.
    -- During a centralized refresh the live spellbook has already been scanned,
    -- so serve that cached snapshot for the duration of this call.
    local scanSpellbook = self.ScanSpellbook
    self.ScanSpellbook = function(owner)
      return owner.spellbook, false
    end

    local ok, changed, fingerprint, previous = pcall(originalRefreshBuildProfile, self, reason, force)
    self.ScanSpellbook = scanSpellbook

    if not ok then error(changed) end
    return changed, fingerprint, previous
  end
end

function RUI:ScheduleBuildProfileRefresh(reason)
  if type(self.ScheduleHUDRefresh) == "function" then
    return self:ScheduleHUDRefresh(reason or "BUILD_PROFILE_REFRESH")
  end
  if type(originalScheduleBuildProfileRefresh) == "function" then
    return originalScheduleBuildProfileRefresh(self, reason)
  end
  return false
end

RUI.buildProfileEventsCentralized = true
RUI._performanceRefreshCoordinatorLoaded = true
