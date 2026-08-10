local RUI = RetreatUI
if not RUI then return end

-- Target debuffs are an ElvUI unitframe concern, not a RetreatUI HUD/WeakAura
-- concern. Keep only the player's own debuffs (after ElvUI's Blacklist filter)
-- on the target frame.
local PRIORITY = "Blacklist,Personal"

local function ConfigureTargetDebuffs(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  profile.unitframe.units.target = profile.unitframe.units.target or {}
  local target = profile.unitframe.units.target
  target.debuffs = target.debuffs or {}
  local debuffs = target.debuffs
  debuffs.enable = true
  debuffs.anchorPoint = debuffs.anchorPoint or "TOPLEFT"
  debuffs.attachTo = debuffs.attachTo or "FRAME"
  debuffs.countFont = debuffs.countFont or "Fira Sans Heavy"
  debuffs.perrow = tonumber(debuffs.perrow) or 4
  debuffs.priority = PRIORITY
  debuffs.maxDuration = 0
  debuffs.sizeOverride = tonumber(debuffs.sizeOverride) or 0
  return true
end

-- Patch the clean profile before the installer imports it.
ConfigureTargetDebuffs(RUI.ElvUIProfile)

-- Also patch an already-existing RetreatUI profile table. No protected frame is
-- touched here; the next /reload or ElvUI profile import applies the settings.
if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
  ConfigureTargetDebuffs(ElvDB.profiles.RetreatUI)
end

function RUI:ConfigureElvUITargetPersonalDebuffs(profile)
  return ConfigureTargetDebuffs(profile or self.ElvUIProfile)
end

RUI._elvUITargetDebuffsLoaded = true
RUI._elvUITargetDebuffsRevision = 1
