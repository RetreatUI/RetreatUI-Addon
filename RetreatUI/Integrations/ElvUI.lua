local RUI = RetreatUI

local function SafeHide(frame)
  if not frame then return false end
  if frame.Hide then pcall(frame.Hide, frame) end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  return true
end

local ELVUI_NAMEPLATE_ADDONS = {
  "ElvUI_NamePlates",
  "ElvUI_Nameplates",
  "ElvUINamePlates",
}

local function CurrentElvUIProfile(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return "RetreatUI"
end

local function DisablePrivateNamePlates(profile)
  if type(profile) ~= "table" then return false end
  if type(profile.nameplates) ~= "table" then profile.nameplates = {} end
  profile.nameplates.enable = false
  return true
end

function RUI:DisableElvUINamePlates()
  local changed = false
  local addonDisableOK = true

  -- Some Ascension ElvUI packages ship nameplates as a separate addon. Mark it
  -- disabled persistently; the installer's final reload then removes it fully.
  for _, addonName in ipairs(ELVUI_NAMEPLATE_ADDONS) do
    if GetAddOnInfo and GetAddOnInfo(addonName) then
      if DisableAddOn then
        local ok = pcall(DisableAddOn, addonName)
        changed = ok or changed
        if not ok then addonDisableOK = false end
      else
        addonDisableOK = false
      end
    end
  end

  local E = ElvUI and unpack(ElvUI)
  local profileName = CurrentElvUIProfile(E)

  -- Other builds bundle NamePlates inside ElvUI. Disable the private module
  -- setting in both live and persisted profile databases. Ascension ElvUI
  -- forks have used both public and private storage for this toggle.
  if E and E.private then changed = DisablePrivateNamePlates(E.private) or changed end
  if E and E.db then changed = DisablePrivateNamePlates(E.db) or changed end
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    local publicProfile = ElvDB.profiles[profileName] or ElvDB.profiles.RetreatUI
    if publicProfile then changed = DisablePrivateNamePlates(publicProfile) or changed end
  end
  if type(ElvPrivateDB) == "table" then
    ElvPrivateDB.profiles = ElvPrivateDB.profiles or {}
    local privateProfile = profileName
    if type(ElvPrivateDB.profileKeys) == "table" and UnitName then
      local character = UnitName("player")
      local realm = GetRealmName and GetRealmName()
      local key = character and realm and (character .. " - " .. realm) or character
      privateProfile = (key and ElvPrivateDB.profileKeys[key]) or privateProfile
    end
    privateProfile = privateProfile or "RetreatUI"
    ElvPrivateDB.profiles[privateProfile] = ElvPrivateDB.profiles[privateProfile] or {}
    changed = DisablePrivateNamePlates(ElvPrivateDB.profiles[privateProfile]) or changed
  end

  -- Stop an already loaded ElvUI NamePlates module immediately where the
  -- client exposes a normal Ace module Disable method.
  if E and E.GetModule then
    local module
    local ok, value = pcall(E.GetModule, E, "NamePlates", true)
    if ok then module = value end
    if not module then
      ok, value = pcall(E.GetModule, E, "Nameplates", true)
      if ok then module = value end
    end
    if module and module.Disable then
      local disabled = pcall(module.Disable, module)
      changed = disabled or changed
    end
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.nameplatesDisabled = true
  db.integrations.elvui.nameplateAddonDisableOK = addonDisableOK
  db.integrations.elvui.nameplatesDisabledVersion = self.version

  return true, changed
    and "ElvUI NamePlates disabled; TurboPlates will be the only active nameplate addon after reload"
    or "ElvUI NamePlates setting disabled for TurboPlates"
end

function RUI:AreElvUINamePlatesDisabled()
  local db = self:EnsureDB()
  local state = db.integrations and db.integrations.elvui
  if not state or state.nameplatesDisabled ~= true then return false end

  -- A separately loaded ElvUI NamePlates module can remain alive until the
  -- reload that completes installation. Validate the saved RetreatUI profile
  -- here and repair the live tables without turning that reload-only state into
  -- a fatal installer error.
  local profile = type(ElvDB) == "table"
    and type(ElvDB.profiles) == "table"
    and ElvDB.profiles.RetreatUI
  if type(profile) ~= "table" then return false end
  profile.nameplates = profile.nameplates or {}
  if profile.nameplates.enable ~= false then return false end

  local E = ElvUI and unpack(ElvUI)
  if E and E.private then DisablePrivateNamePlates(E.private) end
  if E and E.db then DisablePrivateNamePlates(E.db) end
  return true
end

-- Chat frame visibility and docking are intentionally not managed here.
-- ElvUI and Blizzard are the sole owners; ChatOwnershipSafety.lua contains
-- the state-only compatibility no-op and one-time dock visibility repair.

local PARTY_MOVER_OLD = "TOPLEFT,ElvUIParent,BOTTOMLEFT,24,603"
local PARTY_MOVER_INTERMEDIATE = "TOPLEFT,ElvUIParent,BOTTOMLEFT,250,603"
local PARTY_MOVER_FALLBACK = "TOPLEFT,ElvUIParent,BOTTOMLEFT,313,659"
local TARGET_TARGET_MOVER_OLD = "BOTTOM,ElvUIParent,BOTTOM,310,323"
local TARGET_TARGET_MOVER_FALLBACK = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,1408,350"
local TARGET_TARGET_WIDTH = 120
local TARGET_TARGET_HEIGHT = 24
local HUD_POLISH_REVISION = 6
local PET_MOVER = "BOTTOM,ElvUIParent,BOTTOM,-310,404"
local PLAYER_CASTBAR_MOVER = "BOTTOM,ElvUIParent,BOTTOM,-310,326"
local TARGET_CASTBAR_MOVER = "BOTTOM,ElvUIParent,BOTTOM,310,326"
local ACTIONBAR3_MOVER = "BOTTOM,ElvUIParent,BOTTOM,0,26"
local STANCE_BAR_MOVER = "TOPLEFT,ElvUIParent,BOTTOMLEFT,649,32"

local ELVUI_AURA_REPAIR_REVISION = 1
local AURA_REQUIRED_DEFAULTS = {
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "TOPLEFT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "",
  sizeOverride = 0,
  xOffset = 0,
  yOffset = 0,
}

local PARTY_BUFF_DEFAULTS = {
  enable = false,
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "LEFT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "Blacklist,TurtleBuffs",
  sizeOverride = 0,
  xOffset = 0,
  yOffset = 0,
}

local PARTY_DEBUFF_DEFAULTS = {
  enable = true,
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "RIGHT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "Blacklist,RaidDebuffs,CCDebuffs,Dispellable,Whitelist",
  sizeOverride = 20,
  xOffset = 0,
  yOffset = 0,
}

local function FillMissingAuraFields(aura, defaults)
  if type(aura) ~= "table" then return false end
  local changed = false
  for key, value in pairs(defaults or AURA_REQUIRED_DEFAULTS) do
    if aura[key] == nil then
      aura[key] = value
      changed = true
    end
  end
  return changed
end

local function RepairAuraProfile(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  local changed = false

  -- Sparse ElvUI exports omit values equal to defaults. Ascension-ElvUI 7.27
  -- directly indexes these fields and does not tolerate nil values after a raw
  -- profile table is installed, so complete every aura table that RetreatUI
  -- supplies before ElvUI creates or refreshes unit frames.
  for _, unit in pairs(units) do
    if type(unit) == "table" then
      for _, auraType in ipairs({"buffs", "debuffs"}) do
        local aura = unit[auraType]
        if type(aura) == "table" then
          changed = FillMissingAuraFields(aura, AURA_REQUIRED_DEFAULTS) or changed
        end
      end
    end
  end

  units.party = units.party or {}
  local party = units.party
  party.smartAuraPosition = party.smartAuraPosition or "DISABLED"
  party.buffs = party.buffs or {}
  party.debuffs = party.debuffs or {}
  changed = FillMissingAuraFields(party.buffs, PARTY_BUFF_DEFAULTS) or changed
  changed = FillMissingAuraFields(party.debuffs, PARTY_DEBUFF_DEFAULTS) or changed
  return changed
end

function RUI:RepairElvUIAuraProfiles(refreshLive)
  local changed = false
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = RepairAuraProfile(ElvDB.profiles.RetreatUI) or changed
  end

  local E = ElvUI and unpack(ElvUI)
  local currentProfile
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if currentProfile == "RetreatUI" and E and E.db then
    changed = RepairAuraProfile(E.db) or changed
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.auraRepairRevision = ELVUI_AURA_REPAIR_REVISION
  db.integrations.elvui.auraRepairVersion = self.version

  if refreshLive and changed and E then
    if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end
  return true, changed and "ElvUI unit-frame aura settings repaired" or "ElvUI unit-frame aura settings verified"
end


local function NumberOr(value, fallback)
  return type(value) == "number" and value or fallback
end

local function IsLegacyKnightFontColor(value)
  if type(value) ~= "table" then return true end
  local red = tonumber(value.r)
  local green = tonumber(value.g) or 0
  local blue = tonumber(value.b) or 0
  if red == nil then return green <= 0.08 and blue <= 0.08 end
  return red >= 0.88 and green <= 0.10 and blue <= 0.10
end

local function ClampColorChannel(value)
  value = tonumber(value) or 1
  if value < 0 then value = 0 elseif value > 1 then value = 1 end
  return math.floor((value * 255) + 0.5)
end

local function ThemeAccentHex()
  local theme = RUI:GetTheme()
  local color = theme and theme.accent or {1, 1, 1}
  return string.format("%02x%02x%02x",
    ClampColorChannel(color[1]),
    ClampColorChannel(color[2]),
    ClampColorChannel(color[3]))
end

local function StripInlineColor(value)
  if type(value) ~= "string" then return value end
  return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function ManagedColorFormat(baseFormat, hex)
  return "|cff" .. tostring(hex or "ffffff") .. tostring(baseFormat or "") .. "|r"
end

local function CanReplaceManagedFormat(current, baseFormat, force)
  if force or current == nil or current == "" then return true end
  return StripInlineColor(current) == baseFormat
end

local function ApplyManagedUnitTextColor(profile, force)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  local hex = ThemeAccentHex()
  local changed = false

  local managed = {
    player = {
      name = "[name:medium]",
      health = "[health:current]",
    },
    target = {
      name = "[name:medium]",
      health = "[health:current]",
    },
    targettarget = {
      name = "[name:short]",
    },
  }

  for unitName, fields in pairs(managed) do
    units[unitName] = units[unitName] or {}
    for fieldName, baseFormat in pairs(fields) do
      units[unitName][fieldName] = units[unitName][fieldName] or {}
      local field = units[unitName][fieldName]
      if CanReplaceManagedFormat(field.text_format, baseFormat, force) then
        local desired = ManagedColorFormat(baseFormat, hex)
        if field.text_format ~= desired then
          field.text_format = desired
          changed = true
        end
      end
    end
  end

  return changed
end

local function ApplyClassFontColor(profile, force)
  if type(profile) ~= "table" then return false end
  profile.general = profile.general or {}
  local changed = false

  if force or IsLegacyKnightFontColor(profile.general.valuecolor) then
    local theme = RUI:GetTheme()
    local color = theme and theme.accent or {1, 1, 1}
    profile.general.valuecolor = {
      r = NumberOr(color[1], 1),
      g = NumberOr(color[2], 1),
      b = NumberOr(color[3], 1),
      a = 1,
    }
    changed = true
  end

  -- ElvUI's general value color does not control the central unit-frame tags.
  -- Apply the active RetreatUI class accent directly to the managed name and
  -- health formats while preserving genuinely custom tag layouts.
  return ApplyManagedUnitTextColor(profile, force) or changed
end

local function BuildPartyMoverPosition(E)
  local baseline = RUI.ElvUIProfile and RUI.ElvUIProfile.movers
  return baseline and baseline.ElvUF_PartyMover or PARTY_MOVER_FALLBACK
end

function RUI:ApplyPartyFramePosition(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  E.db.movers = E.db.movers or {}
  local current = E.db.movers.ElvUF_PartyMover
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local previousManagedPosition = db.integrations.elvui.partyPosition
  local desired = BuildPartyMoverPosition(E)

  -- Migrate only RetreatUI-managed positions automatically. User-created
  -- mover positions remain untouched unless /rui repair is used.
  local managed = not current
    or current == PARTY_MOVER_OLD
    or current == PARTY_MOVER_INTERMEDIATE
    or current == PARTY_MOVER_FALLBACK
    or current == previousManagedPosition
  if not force and not managed then
    return true, "Custom ElvUI party position preserved"
  end

  E.db.movers.ElvUF_PartyMover = desired

  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    ElvDB.profiles.RetreatUI.movers = ElvDB.profiles.RetreatUI.movers or {}
    ElvDB.profiles.RetreatUI.movers.ElvUF_PartyMover = desired
  end

  db.integrations.elvui.partyPosition = desired
  db.integrations.elvui.partyPositionVersion = self.version

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  return true, "Party frame positioned directly left of the player frame"
end

local function BuildTargetTargetMoverPosition(E)
  local baseline = RUI.ElvUIProfile and RUI.ElvUIProfile.movers
  return baseline and baseline.ElvUF_TargetTargetMover or TARGET_TARGET_MOVER_FALLBACK
end

local function ConfigureTargetTargetFrame(units)
  if type(units) ~= "table" then return end
  local frame = units.targettarget or {}
  units.targettarget = frame

  frame.enable = true
  frame.width = TARGET_TARGET_WIDTH
  frame.height = TARGET_TARGET_HEIGHT
  frame.disableMouseoverGlow = true
  frame.threatStyle = "GLOW"

  frame.buffs = frame.buffs or {}
  frame.buffs.enable = false

  frame.debuffs = frame.debuffs or {}
  frame.debuffs.enable = false
  frame.debuffs.anchorPoint = "TOPRIGHT"

  frame.power = frame.power or {}
  frame.power.enable = false

  frame.health = frame.health or {}
  frame.health.frequentUpdates = true
  frame.health.position = "CENTER"
  frame.health.text_format = ""
  frame.health.xOffset = 0

  frame.name = frame.name or {}
  frame.name.font = "Fira Sans Heavy"
  frame.name.fontOutline = "OUTLINE"
  frame.name.fontSize = 10
  frame.name.position = "CENTER"
  frame.name.text_format = "[name:short]"
  frame.name.xOffset = 0

  frame.raidicon = frame.raidicon or {}
  frame.raidicon.enable = true
  frame.raidicon.attachTo = "TOP"
  frame.raidicon.size = 14
  frame.raidicon.xOffset = 0
  frame.raidicon.yOffset = 5
end


local function ConfigureCastbar(castbar, iconPosition, showLatency)
  if type(castbar) ~= "table" then return end
  castbar.enable = true
  castbar.width = 260
  castbar.height = 18
  castbar.insideInfoPanel = false
  castbar.icon = true
  castbar.iconAttached = true
  castbar.iconPosition = iconPosition
  castbar.format = "REMAINING"
  castbar.displayTarget = false
  castbar.spark = false
  castbar.timeToHold = 0
  if showLatency then
    castbar.latency = true
  else
    castbar.latency = nil
  end
end

local BASELINE_UNITFRAME_MOVERS = {
  "ElvUF_PlayerMover",
  "ElvUF_PlayerCastbarMover",
  "ElvUF_TargetMover",
  "ElvUF_TargetCastbarMover",
  "ElvUF_TargetTargetMover",
  "ElvUF_PetMover",
  "ElvUF_FocusMover",
  "ElvUF_PartyMover",
  "ElvUF_RaidMover",
  "ElvUF_Raid40Mover",
  "ElvUF_RaidpetMover",
  "ElvUF_BossMover",
  "ArenaHeaderMover",
  "BossHeaderMover",
  "ElvBar_Pet",
}

local function ApplySuppliedUnitFrameBaseline(profile)
  if type(profile) ~= "table" or type(RUI.ElvUIProfile) ~= "table" then return end
  local baseline = RUI.ElvUIProfile
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local sourceUnits = baseline.unitframe and baseline.unitframe.units or {}
  for unit, settings in pairs(sourceUnits) do
    profile.unitframe.units[unit] = RUI:DeepCopy(settings)
  end

  profile.movers = profile.movers or {}
  local sourceMovers = baseline.movers or {}
  for _, mover in ipairs(BASELINE_UNITFRAME_MOVERS) do
    if sourceMovers[mover] then profile.movers[mover] = sourceMovers[mover] end
  end
end

local function ConfigureHUDPolish(profile, applyMovers)
  if type(profile) ~= "table" then return end
  if applyMovers then ApplySuppliedUnitFrameBaseline(profile) end

  profile.actionbar = profile.actionbar or {}
  profile.actionbar.bar3 = profile.actionbar.bar3 or {}
  local bar3 = profile.actionbar.bar3
  bar3.enabled = true
  bar3.buttons = 12
  bar3.buttonsPerRow = 12
  bar3.buttonsize = 24
  bar3.counttext = true
  bar3.hotkeytext = true
  bar3.macrotext = false
  bar3.visibility = "[vehicleui] hide; show"

  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  units.player = units.player or {}

  -- Ascension/ElvUI can expose a class-resource percentage as classbar or
  -- power text even when the visible bar is disabled. On Necromancer this
  -- appeared as an extra "100%" directly on top of the character name.
  -- RetreatUI owns the class resources, so explicitly disable both text paths.
  units.player.classbar = units.player.classbar or {}
  units.player.classbar.enable = false
  units.player.classbar.height = 0
  units.player.power = units.player.power or {}
  units.player.power.enable = false
  units.player.power.text_format = ""
  units.player.power.position = "CENTER"
  units.player.power.xOffset = 0

  units.player.castbar = units.player.castbar or {}
  ConfigureCastbar(units.player.castbar, "LEFT", true)

  units.target = units.target or {}
  units.target.castbar = units.target.castbar or {}
  ConfigureCastbar(units.target.castbar, "RIGHT", false)
  ConfigureTargetTargetFrame(units)

  if applyMovers then
    profile.movers = profile.movers or {}
    profile.movers.ElvUF_PetMover = PET_MOVER
    profile.movers.ElvUF_PlayerCastbarMover = PLAYER_CASTBAR_MOVER
    profile.movers.ElvUF_TargetCastbarMover = TARGET_CASTBAR_MOVER
    profile.movers.ElvUF_PartyMover = BuildPartyMoverPosition()
    profile.movers.ElvUF_TargetTargetMover = BuildTargetTargetMoverPosition()
    profile.movers.ElvAB_3 = ACTIONBAR3_MOVER
    profile.movers.ShiftAB = STANCE_BAR_MOVER
  end
end

function RUI:ApplyElvUIHUDPolish(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local applyMovers = force or db.integrations.elvui.hudPolishRevision ~= HUD_POLISH_REVISION

  ConfigureHUDPolish(E.db, applyMovers)
  local classFontColorApplied = ApplyClassFontColor(E.db, false)
  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    ConfigureHUDPolish(ElvDB.profiles.RetreatUI, applyMovers)
    classFontColorApplied = ApplyClassFontColor(ElvDB.profiles.RetreatUI, false) or classFontColorApplied
  end

  if applyMovers then
    db.integrations.elvui.hudPolishRevision = HUD_POLISH_REVISION
    db.integrations.elvui.hudPolishVersion = self.version
  end
  if classFontColorApplied then
    db.integrations.elvui.classFontColorVersion = self.version
    db.integrations.elvui.classFontColorClass = type(self.GetDetectedClass) == "function" and self:GetDetectedClass() or nil
  end

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  if applyMovers then
    return true, "Supplied ElvUI unit-frame baseline, castbars and HUD positions applied"
  end
  return true, "RetreatUI castbar, stance bar, and frame styling refreshed"
end

function RUI:ApplyTargetTargetFrame(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  E.db.unitframe = E.db.unitframe or {}
  E.db.unitframe.units = E.db.unitframe.units or {}
  ConfigureTargetTargetFrame(E.db.unitframe.units)

  E.db.movers = E.db.movers or {}
  local current = E.db.movers.ElvUF_TargetTargetMover
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local previousManagedPosition = db.integrations.elvui.targetTargetPosition
  local desired = BuildTargetTargetMoverPosition(E)

  local managed = not current
    or current == TARGET_TARGET_MOVER_OLD
    or current == TARGET_TARGET_MOVER_FALLBACK
    or current == previousManagedPosition
  if force or managed then
    E.db.movers.ElvUF_TargetTargetMover = desired
    db.integrations.elvui.targetTargetPosition = desired
    db.integrations.elvui.targetTargetPositionVersion = self.version
  end

  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    local profile = ElvDB.profiles.RetreatUI
    profile.unitframe = profile.unitframe or {}
    profile.unitframe.units = profile.unitframe.units or {}
    ConfigureTargetTargetFrame(profile.unitframe.units)
    profile.movers = profile.movers or {}
    if force or managed then profile.movers.ElvUF_TargetTargetMover = desired end
  end

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  if not managed and not force then
    return true, "Target of Target enabled; custom position preserved"
  end
  return true, "Compact Target of Target frame enabled beside the target frame"
end

function RUI:InstallElvUIProfile()
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end
  local E = unpack(ElvUI)
  local profileName = "RetreatUI"
  ElvDB.profiles = ElvDB.profiles or {}
  local preservedTotemMover, preservedTotemMoverKey
  if type(self.GetTotemBarMoverPosition) == "function" then
    preservedTotemMover, preservedTotemMoverKey = self:GetTotemBarMoverPosition()
  end
  local profile = self:DeepCopy(self.ElvUIProfile)
  RepairAuraProfile(profile)
  profile.movers = profile.movers or {}
  profile.movers.ElvBar_Totem = nil
  profile.movers.TotemBarMover = nil
  if preservedTotemMover and preservedTotemMover ~= "" then
    profile.movers[preservedTotemMoverKey or "ElvBar_Totem"] = preservedTotemMover
  else
    profile.movers.ElvBar_Totem = "BOTTOM,ElvUIParent,BOTTOM,0,55"
  end
  self:ForceFontFields(profile)
  ApplyClassFontColor(profile, true)
  ElvDB.profiles[profileName] = profile

  ElvDB.profileKeys = ElvDB.profileKeys or {}
  if UnitName then
    local character = UnitName("player")
    local realm = GetRealmName and GetRealmName()
    local characterKey = character and realm and (character .. " - " .. realm) or character
    if characterKey and characterKey ~= "" then ElvDB.profileKeys[characterKey] = profileName end
  end

  local ok, err = pcall(function()
    if E and E.data and E.data.SetProfile then E.data:SetProfile(profileName) end
    if E and E.db then RepairAuraProfile(E.db) end
    self:DisableElvUINamePlates()
    if E and E.db then self:ForceFontFields(E.db) end
    if E and E.db and E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player then
      E.db.unitframe.units.player.health = E.db.unitframe.units.player.health or {}
      E.db.unitframe.units.player.health.text_format = ManagedColorFormat("[health:current]", ThemeAccentHex())
    end
    if E and E.UpdateAll then E:UpdateAll(true) end
    self:ApplyPartyFramePosition(true)
    self:ApplyTargetTargetFrame(true)
    self:ApplyElvUIHUDPolish(true)
    self:RemoveRightLootTradeChat()
    self:After(0.25, function() self:RemoveRightLootTradeChat() end)
    self:After(1.00, function() self:RemoveRightLootTradeChat() end)
  end)
  if not ok then
    local persisted = type(ElvDB.profiles) == "table"
      and type(ElvDB.profiles[profileName]) == "table"
      and type(ElvDB.profiles[profileName].nameplates) == "table"
      and ElvDB.profiles[profileName].nameplates.enable == false
    if persisted then
      local db = self:EnsureDB()
      db.integrations.elvui = db.integrations.elvui or {}
      db.integrations.elvui.activationWarning = tostring(err)
      db.integrations.elvui.activationPendingReload = true
      return true, "RetreatUI ElvUI profile saved; live frame activation will finish after reload"
    end
    return false, "Profile creation failed: " .. tostring(err)
  end
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.activationWarning = nil
  db.integrations.elvui.activationPendingReload = nil
  return true, "RetreatUI ElvUI profile installed; ElvUI NamePlates disabled, right chat panel preserved, and Loot/Trade chat windows removed"
end

function RUI:SyncThemeFonts()
  self.themeFontPath = self.preferredFontPath
  local results = {}

  if ElvUI then
    local E = unpack(ElvUI)
    local profile = ElvDB and ElvDB.profiles and ElvDB.profiles.RetreatUI
    if type(profile) == "table" then self:ForceFontFields(profile) end

    local currentProfile
    if E and E.data and E.data.GetCurrentProfile then
      local ok, value = pcall(E.data.GetCurrentProfile, E.data)
      if ok then currentProfile = value end
    end
    if currentProfile == "RetreatUI" and E and E.db then
      self:ForceFontFields(E.db)
      if E.UpdateAll then pcall(E.UpdateAll, E, true) end
    end
    table.insert(results, "ElvUI")
  end

  if TurboPlatesDB then
    TurboPlatesDB.font = self.fontName
    table.insert(results, "TurboPlates")
  end

  if self.ApplyDetailsFont then
    local ok = self:ApplyDetailsFont()
    if ok then table.insert(results, "Details") end
  end

  if self.ApplyDBMTheme then
    local ok = self:ApplyDBMTheme()
    if ok then table.insert(results, "DBM") end
  end

  -- Do not rebuild or destroy the installer here. Existing font strings remain
  -- valid, and the next /reload applies Fira Sans Heavy everywhere.
  return true, "Fira Sans Heavy applied to " .. table.concat(results, ", ")
end

-- Emergency migration for profiles installed by beta.12 or beta.13.
if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" and ElvDB.profiles.RetreatUI then
  pcall(RUI.RepairElvUIAuraProfiles, RUI, false)
end
