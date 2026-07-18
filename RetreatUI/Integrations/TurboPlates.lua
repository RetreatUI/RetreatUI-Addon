local RUI = RetreatUI

local PLAYER_DEBUFFS = {
  "Curse of Xoroth", "Torn Flesh", "Ritual Fire", "Bulwark of Xoroth",
  "Pestilence of Famine", "Pestilence of War", "Pestilence of Conquest",
}

local function SafeSetCVar(name, value)
  if type(SetCVar) ~= "function" then return false end
  return pcall(SetCVar, name, tostring(value))
end

local function EnsureTurboTables()
  if type(TurboPlatesDB) ~= "table" then return nil end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.blacklist = TurboPlatesDB.auras.blacklist or {}
  TurboPlatesDB.highlightSpells = TurboPlatesDB.highlightSpells or {}
  TurboPlatesDB.stacking = TurboPlatesDB.stacking or {}
  return TurboPlatesDB
end

function RUI:ApplyMobSpellsToTurboPlates()
  local db = EnsureTurboTables()
  if not db then return false, "TurboPlates is not loaded" end
  if type(MobSpellsDB) ~= "table" then
    return false, "MobSpells is not loaded; NPC spell whitelisting is unavailable"
  end

  local spellCount, namedCount = 0, 0
  for _, records in pairs(MobSpellsDB) do
    if type(records) == "table" then
      for _, record in ipairs(records) do
        local spellID = type(record) == "table" and tonumber(record[1]) or nil
        if spellID and spellID > 0 then
          if not db.auras.whitelist[spellID] then
            db.auras.whitelist[spellID] = true
            spellCount = spellCount + 1
          end
          local spellName = GetSpellInfo and GetSpellInfo(spellID)
          if spellName and spellName ~= "" and not db.highlightSpells[spellName] then
            db.highlightSpells[spellName] = true
            namedCount = namedCount + 1
          end
        end
      end
    end
  end

  db.auras.showBuffs = true
  db.auras.buffFilterMode = "WHITELIST_DISPELLABLE"
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true
  db.highlightGlowEnabled = true
  db.highlightGlowColor = {r = 1, g = 0.25, b = 0.05}

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.mobSpells = ruiDB.integrations.mobSpells or {}
  ruiDB.integrations.mobSpells.enabled = true
  ruiDB.integrations.mobSpells.whitelistEntries = spellCount
  ruiDB.integrations.mobSpells.highlightEntries = namedCount
  ruiDB.integrations.mobSpells.version = self.version

  return true, "MobSpells NPC abilities added to TurboPlates aura and cast whitelists"
end

function RUI:ApplyTurboPlatesStacking()
  local db = EnsureTurboTables()
  if not db then return false, "TurboPlates is not loaded" end

  local stacking = db.stacking
  stacking.enabled = true
  stacking.preset = "snappy"
  stacking.springFrequencyRaise = 13
  stacking.springFrequencyLower = 11
  stacking.launchDamping = 0.9
  stacking.settleThreshold = 1
  stacking.xSpaceRatio = 1.05
  stacking.ySpaceRatio = 1.15
  stacking.originPosRatio = 0
  stacking.upperBorder = 60
  stacking.maxPlates = 60

  -- Fallback CVars for clients where TurboPlates' custom stacking starts late.
  SafeSetCVar("nameplateMotion", 1)
  SafeSetCVar("nameplateOverlapH", 0.8)
  SafeSetCVar("nameplateOverlapV", 1.15)

  return true, "TurboPlates nameplate stacking enabled with extra vertical spacing"
end

function RUI:ApplyTurboPlatesRuntime()
  if type(self.DisableElvUINamePlates) == "function" then self:DisableElvUINamePlates() end
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end

  local db = EnsureTurboTables()
  db.font = self.fontName
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true

  local auras = db.auras
  auras.showDebuffs = true
  auras.maxDebuffs = math.max(tonumber(auras.maxDebuffs) or 0, 8)
  auras.debuffIconWidth = 24
  auras.debuffIconHeight = 20
  auras.debuffFontSize = 12
  auras.debuffStackFontSize = 12
  auras.debuffXOffset = 0
  auras.debuffYOffset = 5
  auras.growDirection = "CENTER"
  auras.iconSpacing = 2
  auras.debuffSortMode = "LEAST_TIME"

  for _, spellName in ipairs(PLAYER_DEBUFFS) do
    local spellID = self:GetSpellID(spellName)
    if spellID then auras.whitelist[spellID] = true end
  end

  self:ApplyTurboPlatesStacking()
  local mobOK = false
  if type(MobSpellsDB) == "table" then
    mobOK = select(1, self:ApplyMobSpellsToTurboPlates()) == true
  end

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.turboRuntime = {
    enabled = true,
    mobSpells = mobOK,
    version = self.version,
  }

  return true, mobOK
    and "TurboPlates runtime, MobSpells whitelists and separated stacking applied"
    or "TurboPlates runtime and separated stacking applied; MobSpells was not loaded"
end

function RUI:InstallTurboPlatesProfile()
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  local ok, message = self:ApplyTurboPlatesRuntime()
  if not ok then return false, message end
  return true, message
end
