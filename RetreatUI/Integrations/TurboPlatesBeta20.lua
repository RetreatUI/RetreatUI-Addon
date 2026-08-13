local RUI = RetreatUI
if not RUI then return end

-- beta.20 native TurboPlates profile for the RetreatUI CoA layout.
-- Only native TurboPlates settings are applied; no Plater mods or scripts are recreated.

local PROFILE = {
  width = 176,
  hpHeight = 13,
  castHeight = 10,
  scale = 1,
  targetScale = 1.13,
  friendlyScale = 1,
  healthBarBorder = true,

  raidMarkerSize = 26,
  raidMarkerAnchor = "LEFT",
  raidMarkerX = 0,
  raidMarkerY = 0,

  texture = "ElvUI Norm",
  backgroundAlpha = 1,
  castColor = {r = 1, g = 0.9333334, b = 0.4313726},
  noInterruptColor = {r = 0.7058824, g = 0.7333333, b = 0.6941177},

  font = "Fira Sans Heavy",
  fontSize = 11,
  fontOutline = "OUTLINE",
  friendlyNameOnly = true,
  friendlyGuild = false,
  friendlyFontSize = 13,
  guildFontSize = 9,
  healthValueFormat = "percent",
  healthValueFontSize = 10,
  nameTextYOffset = -5,
  nameInHealthbar = false,
  hidePercentWhenFull = false,
  levelMode = "disabled",

  classColoredHealth = true,
  classColoredName = false,
  nonTargetAlpha = 0.6,

  targetGlow = "border",
  targetArrow = "arrows_double",
  targetGlowColor = {r = 1, g = 1, b = 1},

  showCastbar = true,
  showCastIcon = false,
  showCastSpark = true,
  showCastTimer = false,

  tankMode = 0,
  secureColor = {r = 0.3803922, g = 0.8745099, b = 0.2313726},
  transColor = {r = 1, g = 0.9333334, b = 0.4313726},
  insecureColor = {r = 0.9960785, g = 0.2980392, b = 0.3098039},
  offTankColor = {r = 0.7333333, g = 0.1960784, b = 1},
}

local AURAS = {
  showDebuffs = true,
  maxDebuffs = 4,
  debuffIconWidth = 26,
  debuffIconHeight = 17,
  debuffFontSize = 10,
  debuffStackFontSize = 10,
  debuffXOffset = 1,
  debuffYOffset = 0,
  debuffBorderMode = "COLOR_CODED",
  debuffDurationAnchor = "BOTTOM",
  debuffStackAnchor = "TOPLEFT",

  showBuffs = true,
  buffFilterMode = "WHITELIST_DISPELLABLE",
  maxBuffs = 2,
  buffIconWidth = 26,
  buffIconHeight = 17,
  buffFontSize = 10,
  buffStackFontSize = 10,
  buffXOffset = -1,
  buffYOffset = 0,
  buffGrowDirection = "CENTER",
  buffDurationAnchor = "BOTTOM",
  buffStackAnchor = "TOPLEFT",
  buffIconSpacing = 0,
  buffMinDuration = 0,
  buffMaxDuration = 600,
  buffBorderMode = "COLOR_CODED",

  minDuration = 0,
  maxDuration = 0,
  growDirection = "CENTER",
  iconSpacing = 0,
  debuffSortMode = "LEAST_TIME",
  buffSortMode = "MOST_RECENT",
}

local STACKING = {
  enabled = true,
  preset = "balanced",
  xSpaceRatio = 1.0,
  ySpaceRatio = 1.6,
}

local function CopyColor(value)
  if type(value) ~= "table" then return value end
  return {r = value.r, g = value.g, b = value.b, a = value.a}
end

local function EnsureTurboTables(db)
  if type(db) ~= "table" then return nil end
  db.auras = db.auras or {}
  db.auras.whitelist = db.auras.whitelist or {}
  db.auras.blacklist = db.auras.blacklist or {}
  db.highlightSpells = db.highlightSpells or {}
  db.stacking = db.stacking or {}
  return db
end

local function ApplyFlatProfile(db)
  for key, value in pairs(PROFILE) do
    if type(value) == "table" then
      db[key] = CopyColor(value)
    else
      db[key] = value
    end
  end

  EnsureTurboTables(db)
  for key, value in pairs(AURAS) do
    db.auras[key] = value
  end

  for key, value in pairs(STACKING) do
    db.stacking[key] = value
  end
end

local function SafeSetCVar(name, value)
  if type(C_CVar) == "table" and type(C_CVar.Set) == "function" then
    local ok = pcall(C_CVar.Set, name, tostring(value))
    if ok then return true end
  end
  if type(SetCVar) == "function" then
    return pcall(SetCVar, name, tostring(value))
  end
  return false
end

local function ApplyProfileCVars()
  SafeSetCVar("nameplateMotion", 1)
  SafeSetCVar("nameplateOverlapH", 1.0)
  SafeSetCVar("nameplateOverlapV", 1.6)
  SafeSetCVar("nameplateMaxDistance", 45)
  SafeSetCVar("nameplateSelectedScale", 1.13)
end

-- beta.20 no longer loads the old TurboPlates runtime integration. Keep the
-- useful CoA MobSpells data import here as a one-time native DB operation so
-- enemy spell names/IDs survive without re-enabling any legacy frame scanner.
function RUI:ApplyMobSpellsToTurboPlates()
  local db = EnsureTurboTables(_G.TurboPlatesDB)
  if not db then return false, "TurboPlates is not loaded" end
  if type(_G.MobSpellsDB) ~= "table" then
    return false, "MobSpells is not loaded; NPC spell whitelisting is unavailable"
  end

  local spellCount, namedCount = 0, 0
  for _, records in pairs(_G.MobSpellsDB) do
    if type(records) == "table" then
      for _, record in ipairs(records) do
        local spellID = type(record) == "table" and tonumber(record[1]) or nil
        if spellID and spellID > 0 then
          if db.auras.whitelist[spellID] ~= true then
            db.auras.whitelist[spellID] = true
            spellCount = spellCount + 1
          end
          local spellName = type(GetSpellInfo) == "function" and GetSpellInfo(spellID) or nil
          if spellName and spellName ~= "" and db.highlightSpells[spellName] ~= true then
            db.highlightSpells[spellName] = true
            namedCount = namedCount + 1
          end
        end
      end
    end
  end

  local ruiDB = self.EnsureDB and self:EnsureDB() or nil
  if ruiDB then
    ruiDB.integrations = ruiDB.integrations or {}
    ruiDB.integrations.mobSpells = {
      enabled = true,
      whitelistEntries = spellCount,
      highlightEntries = namedCount,
      version = self.version,
    }
  end

  return true, string.format("CoA NPC spell data retained (%d IDs, %d names)", spellCount, namedCount)
end

local function RecordInstall(self, resolution, mobOK)
  local db = self.EnsureDB and self:EnsureDB() or nil
  if not db then return end

  db.integrations = db.integrations or {}
  db.integrations.turboBeta20 = {
    enabled = true,
    resolution = resolution,
    nativeSettingsOnly = true,
    externalScriptsImported = false,
    legacyRuntimeDisabled = true,
    mobSpells = mobOK == true,
    version = self.version,
  }
end

function RUI:InstallTurboPlatesProfile(resolution)
  resolution = tostring(resolution or "1440p"):lower()
  if resolution ~= "1440p" and resolution ~= "1080p" then
    return false, "TurboPlates profile must be 1440p or 1080p."
  end

  if type(self.DisableElvUINamePlates) == "function" then
    self:DisableElvUINamePlates()
  end
  if type(self.EnsureAddOnLoaded) == "function" then
    self:EnsureAddOnLoaded("TurboPlates")
  end
  if type(_G.TurboPlatesDB) ~= "table" then
    return false, "TurboPlates is not loaded."
  end

  ApplyFlatProfile(_G.TurboPlatesDB)
  ApplyProfileCVars()

  local mobOK = false
  if type(_G.MobSpellsDB) == "table" then
    mobOK = select(1, self:ApplyMobSpellsToTurboPlates()) == true
  end

  RecordInstall(self, resolution, mobOK)

  return true, mobOK
    and "RetreatUI TurboPlates layout applied; CoA NPC spell whitelist retained. Reload UI to finish."
    or "RetreatUI TurboPlates layout applied. Reload UI to finish."
end

-- beta.20 keeps one static TurboPlates owner so repair cannot restore legacy geometry.
function RUI:ApplyTurboPlatesRuntime(resolution)
  local db = self.EnsureDB and self:EnsureDB() or nil
  local installed = db and db.integrations and db.integrations.turboBeta20
  local selected = tostring(resolution or (installed and installed.resolution) or "1440p"):lower()
  if selected ~= "1080p" then selected = "1440p" end
  return self:InstallTurboPlatesProfile(selected)
end

RUI._turboPlatesBeta20Loaded = true
RUI._turboPlatesBeta20Revision = 22
