local RUI = RetreatUI
if not RUI then return end

-- beta.20 native TurboPlates translation of the NaowhUI TBC Plater profile.
-- The source 1440p and 1080p Plater profiles use the same visual geometry;
-- only profile metadata differs. Plater mods/scripts are intentionally not ported.
-- Values in this file are mapped from the decoded !PLATER:2! profile rather than
-- inferred from screenshots.

local NAOWH = {
  -- plate_config.enemynpc / enemyplayer: health [186,14], cast [186,11]
  width = 186,
  hpHeight = 14,
  castHeight = 11,
  scale = 1,
  targetScale = 1.15,
  friendlyScale = 1,
  healthBarBorder = true,

  -- indicator_raidmark_scale = 1.4. TurboPlates' 20px baseline maps to 28px.
  raidMarkerSize = 28,
  raidMarkerAnchor = "LEFT",
  raidMarkerX = 0,
  raidMarkerY = 0,

  -- NaowhGradient/NaowhLeft are not bundled with RetreatUI. ElvUI Norm is the
  -- closest flat native TurboPlates texture already shipped with the addon.
  texture = "ElvUI Norm",
  backgroundAlpha = 1,
  castColor = {r = 1, g = 0.9333334, b = 0.4313726},
  noInterruptColor = {r = 0.7058824, g = 0.7333333, b = 0.6941177},

  -- Enemy NPC/player text from plate_config.
  font = "Fira Sans Heavy",
  fontSize = 12,
  fontOutline = "OUTLINE",
  friendlyNameOnly = true,
  friendlyGuild = false,
  friendlyFontSize = 14,
  guildFontSize = 9,
  healthValueFormat = "percent",
  healthValueFontSize = 11,
  nameTextYOffset = -5,
  nameInHealthbar = false,
  hidePercentWhenFull = false,
  levelMode = "disabled",

  -- enemyplayer.use_playerclass_color = true.
  classColoredHealth = true,
  classColoredName = false,
  nonTargetAlpha = 0.6,

  -- Naowh has target_highlight + "Double Arrows". TurboPlates has no identical
  -- selection_indicator3 texture, so its native white border + double arrows is
  -- the closest script-free equivalent.
  targetGlow = "border",
  targetArrow = "arrows_double",
  targetGlowColor = {r = 1, g = 1, b = 1},

  showCastbar = true,
  -- castbar_icon_show = false in both enemy profiles.
  showCastIcon = false,
  showCastSpark = true,
  -- spellpercent_text_enabled = false: no numeric cast timer in the Naowh enemy plate.
  showCastTimer = false,

  -- tank_threat_colors = false in the source profile. Keep the decoded colors
  -- available but do not enable TurboPlates threat recoloring.
  tankMode = 0,
  secureColor = {r = 0.3803922, g = 0.8745099, b = 0.2313726},
  transColor = {r = 1, g = 0.9333334, b = 0.4313726},
  insecureColor = {r = 0.9960785, g = 0.2980392, b = 0.3098039},
  offTankColor = {r = 0.7333333, g = 0.1960784, b = 1},
}

local AURAS = {
  showDebuffs = true,
  -- auras_per_row_amount = 4, aura size 28x18.
  maxDebuffs = 4,
  debuffIconWidth = 28,
  debuffIconHeight = 18,
  debuffFontSize = 11,
  debuffStackFontSize = 11,
  debuffXOffset = 1,
  debuffYOffset = 0,
  debuffBorderMode = "COLOR_CODED",
  debuffDurationAnchor = "BOTTOM",
  debuffStackAnchor = "TOPLEFT",

  showBuffs = true,
  buffFilterMode = "WHITELIST_DISPELLABLE",
  -- buffs_on_aura2=true and auras_per_row_amount2=2.
  maxBuffs = 2,
  buffIconWidth = 28,
  buffIconHeight = 18,
  buffFontSize = 11,
  buffStackFontSize = 11,
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
  -- Source: stacking_nameplates_enabled=true and auto-toggle stacking enabled.
  enabled = true,
  preset = "balanced",
  xSpaceRatio = 1.0,
  ySpaceRatio = 1.6,
}

local function CopyColor(value)
  if type(value) ~= "table" then return value end
  return {r = value.r, g = value.g, b = value.b, a = value.a}
end

local function ApplyFlatProfile(db)
  for key, value in pairs(NAOWH) do
    if type(value) == "table" then db[key] = CopyColor(value)
    else db[key] = value end
  end

  db.auras = db.auras or {}
  for key, value in pairs(AURAS) do db.auras[key] = value end
  db.auras.whitelist = db.auras.whitelist or {}
  db.auras.blacklist = db.auras.blacklist or {}

  db.stacking = db.stacking or {}
  for key, value in pairs(STACKING) do db.stacking[key] = value end
end

local function SafeSetCVar(name, value)
  if type(C_CVar) == "table" and type(C_CVar.Set) == "function" then
    local ok = pcall(C_CVar.Set, name, tostring(value))
    if ok then return true end
  end
  if type(SetCVar) == "function" then return pcall(SetCVar, name, tostring(value)) end
  return false
end

local function ApplyNaowhCVars()
  -- Only direct 3.3.5/TurboPlates equivalents are copied. No Plater scripts,
  -- hooks, mods or unsupported CVars are recreated.
  SafeSetCVar("nameplateMotion", 1)
  SafeSetCVar("nameplateOverlapH", 1.0)
  SafeSetCVar("nameplateOverlapV", 1.6)
  SafeSetCVar("nameplateMaxDistance", 45)
  SafeSetCVar("nameplateSelectedScale", 1.15)
end

local function RecordInstall(self, resolution, mobOK)
  local db = self.EnsureDB and self:EnsureDB() or nil
  if not db then return end
  db.integrations = db.integrations or {}
  db.integrations.turboNaowhBeta20 = {
    enabled = true,
    resolution = resolution,
    nativeSettingsOnly = true,
    platerScriptsImported = false,
    legacyRuntimeDisabled = true,
    decodedPlaterSettings = 383,
    mobSpells = mobOK == true,
    version = self.version,
  }
end

function RUI:InstallTurboPlatesProfile(resolution)
  resolution = tostring(resolution or "1440p"):lower()
  if resolution ~= "1440p" and resolution ~= "1080p" then
    return false, "TurboPlates profile must be 1440p or 1080p."
  end

  if type(self.DisableElvUINamePlates) == "function" then self:DisableElvUINamePlates() end
  if type(self.EnsureAddOnLoaded) == "function" then self:EnsureAddOnLoaded("TurboPlates") end
  if type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded." end

  ApplyFlatProfile(TurboPlatesDB)
  ApplyNaowhCVars()

  -- Preserve RetreatUI's CoA NPC spell whitelist, but do not import or recreate
  -- any Plater mod/script runtime.
  local mobOK = false
  if type(MobSpellsDB) == "table" and type(self.ApplyMobSpellsToTurboPlates) == "function" then
    mobOK = select(1, self:ApplyMobSpellsToTurboPlates()) == true
    -- ApplyMobSpellsToTurboPlates owns spell lists; restore the Naowh visual
    -- values afterwards so spell curation cannot change profile geometry.
    ApplyFlatProfile(TurboPlatesDB)
  end

  RecordInstall(self, resolution, mobOK)

  return true, mobOK
    and "Naowh TurboPlates layout applied; CoA NPC spell whitelist retained. Reload UI to finish."
    or "Naowh TurboPlates layout applied. Reload UI to finish."
end

-- beta.19 exposed ApplyTurboPlatesRuntime() as a broad repair/runtime entry point.
-- Leaving that function alive would re-enable the old mana-coloring scanner,
-- old aura geometry and old stacking values whenever /rui repair is used.
-- In beta.20 the Naowh native profile is the sole TurboPlates owner, so every
-- legacy caller is deliberately routed through the same static profile path.
function RUI:ApplyTurboPlatesRuntime(resolution)
  local db = self.EnsureDB and self:EnsureDB() or nil
  local installed = db and db.integrations and db.integrations.turboNaowhBeta20
  local selected = tostring(resolution or (installed and installed.resolution) or "1440p"):lower()
  if selected ~= "1080p" then selected = "1440p" end
  return self:InstallTurboPlatesProfile(selected)
end

RUI._naowhTurboPlatesBeta20Loaded = true
RUI._naowhTurboPlatesBeta20Revision = 20
