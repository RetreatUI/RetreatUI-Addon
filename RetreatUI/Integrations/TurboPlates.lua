local RUI = RetreatUI
if not RUI then return end

local function EnsureTurboTables()
  if type(TurboPlatesDB) ~= "table" then return nil end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.blacklist = TurboPlatesDB.auras.blacklist or {}
  TurboPlatesDB.highlightSpells = TurboPlatesDB.highlightSpells or {}
  TurboPlatesDB.stacking = TurboPlatesDB.stacking or {}
  return TurboPlatesDB
end

-- Keep NPC spell data as data. TurboPlates itself owns rendering, update
-- cadence, nameplate lifecycle and cast/aura refreshes.
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

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.mobSpells = ruiDB.integrations.mobSpells or {}
  ruiDB.integrations.mobSpells.enabled = true
  ruiDB.integrations.mobSpells.whitelistEntries = spellCount
  ruiDB.integrations.mobSpells.highlightEntries = namedCount
  ruiDB.integrations.mobSpells.version = self.version

  return true, "MobSpells NPC abilities added to TurboPlates"
end

-- The previous integration ran a permanent 0.15-second frame scan to recolor
-- mana NPC plates, recursively walked arbitrary plate children and scheduled
-- additional delayed full scans on power/nameplate events. That runtime is
-- intentionally retired. Plate appearance is now profile-driven only.
function RUI:InitializeTurboManaColoring()
  local oldFrame = _G.RetreatUITurboManaColoring
  if oldFrame then
    if oldFrame.UnregisterAllEvents then pcall(oldFrame.UnregisterAllEvents, oldFrame) end
    if oldFrame.SetScript then
      pcall(oldFrame.SetScript, oldFrame, "OnEvent", nil)
      pcall(oldFrame.SetScript, oldFrame, "OnUpdate", nil)
    end
    if oldFrame.Hide then pcall(oldFrame.Hide, oldFrame) end
  end
  return true
end

-- Kept as a compatibility entry point for installer/runtime callers. Exact
-- stacking/spacing values are supplied by the profile mapping layer; this
-- function no longer invents an independent preset or continuously corrects it.
function RUI:ApplyTurboPlatesStacking()
  local db = EnsureTurboTables()
  if not db then return false, "TurboPlates is not loaded" end
  return true, "TurboPlates stacking is profile-driven"
end

function RUI:ApplyTurboPlatesRuntime()
  if type(self.DisableElvUINamePlates) == "function" then self:DisableElvUINamePlates() end
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end

  local db = EnsureTurboTables()
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true

  -- Do not overwrite dimensions, fonts, colors, aura layout, stacking or
  -- threat styling here. Those values belong to the profile mapping and have
  -- one source of truth instead of a second post-import repair layer.
  self:InitializeTurboManaColoring()

  local mobOK = false
  if type(MobSpellsDB) == "table" then
    mobOK = select(1, self:ApplyMobSpellsToTurboPlates()) == true
  end

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.turboRuntime = {
    enabled = true,
    mobSpells = mobOK,
    profileDriven = true,
    legacyManaScanner = false,
    recursivePlateDiscovery = false,
    periodicPlatePolling = false,
    version = self.version,
  }

  return true, mobOK
    and "TurboPlates runtime applied with native plate updates and MobSpells data"
    or "TurboPlates runtime applied with native plate updates; MobSpells was not loaded"
end

function RUI:InstallTurboPlatesProfile()
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  return self:ApplyTurboPlatesRuntime()
end
