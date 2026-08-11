local RUI = RetreatUI
if not RUI then return end

-- RetreatUI does NOT use ElvUI's target-frame debuff row.
--
-- The clean profile already shipped with target debuffs disabled. A later patch
-- accidentally forced `enable = true`, which produced a large row of target
-- debuff icons and duplicated class HUD information. Keep the target frame clean;
-- any future target mechanic tracking must be explicitly curated in the HUD and
-- must never re-enable the generic ElvUI debuff container.
local function DisableTargetDebuffs(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  profile.unitframe.units.target = profile.unitframe.units.target or {}
  local target = profile.unitframe.units.target
  target.debuffs = target.debuffs or {}
  local debuffs = target.debuffs
  debuffs.enable = false
  debuffs.priority = ""
  debuffs.maxDuration = 0
  debuffs.perrow = 4
  debuffs.numrows = 1
  return true
end

DisableTargetDebuffs(RUI.ElvUIProfile)

if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
  DisableTargetDebuffs(ElvDB.profiles.RetreatUI)
end

local E = ElvUI and unpack(ElvUI)
if E and E.db then
  local currentProfile
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if currentProfile == nil or currentProfile == "RetreatUI" then
    DisableTargetDebuffs(E.db)
  end
end

function RUI:ConfigureElvUITargetPersonalDebuffs(profile)
  -- Retained as a compatibility entry point for older callers. The operation is
  -- intentionally a disable now; generic target-frame debuffs are not part of
  -- the RetreatUI layout contract.
  return DisableTargetDebuffs(profile or self.ElvUIProfile)
end

function RUI:DisableElvUITargetDebuffs(profile)
  return DisableTargetDebuffs(profile or self.ElvUIProfile)
end

RUI._elvUITargetDebuffsLoaded = true
RUI._elvUITargetDebuffsRevision = 2
