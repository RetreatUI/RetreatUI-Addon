local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

local W = RUI.HUDWidgets

-- Dedicated learned-only cooldown rows. RetreatUI remains a combat HUD rather
-- than a second action bar: rotation stays in core; interrupts, taunts,
-- mobility and control stay in utility.
local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AuditedSpell(name, id, row, cooldown)
  return {
    name=name, id=id, category=row, hudRow=row == "offensive" and "core" or "utility",
    cooldownRow=row, forceCooldownRow=true, trackHUD=true, trackCooldown=true,
    cooldownHint=cooldown, cooldownCategory=row, source="CooldownSpreadsheetAudit",
  }
end

-- High-confidence gaps verified against the shared CoA spreadsheet. Ambiguous
-- replacement records and missing-tooltip entries are deliberately excluded.
local EXTRA_DEFINITIONS = {
  ["Bloodmage"]={AuditedSpell("Blood Bond", 504627, "defensive", 120)},
  ["Chronomancer"]={
    AuditedSpell("Timeline Guardian", 805845, "defensive", 60),
    AuditedSpell("Timeline Destroyer", 805846, "offensive", 60),
  },
  ["Cultist"]={
    AuditedSpell("Protection From Light", 804065, "defensive", 30),
    AuditedSpell("Wrath of The Black Empire", 500724, "offensive", 60),
  },
  ["Necromancer"]={AuditedSpell("Frigid Ward", 801735, "defensive", 30)},
  ["Pyromancer"]={
    AuditedSpell("Burning Spheres", 801487, "offensive", 120),
    AuditedSpell("Eruption", 800103, "offensive", 120),
    AuditedSpell("Flames of Al'ar", 500202, "offensive", 120),
  },
  ["Ranger"]={
    AuditedSpell("Power Shot", 500070, "offensive", 43),
    AuditedSpell("Horn of Endurance", 806359, "defensive", 60),
  },
  ["Reaper"]={AuditedSpell("Shadow's Embrace", 524709, "defensive", 90)},
  ["Runemaster"]={AuditedSpell("Augur's Shield", 804126, "defensive", 40)},
  ["Sun Cleric"]={AuditedSpell("Wuju Tiki Shield", 807655, "defensive", 120)},
}

-- Catalogue corrections where the raw category does not match the actual
-- combat decision. "core"/"utility" keep a spell in the legacy rows.
local ROW_OVERRIDES = {
  ["Bloodmage"]={
    ["blood bond"]="defensive", ["blood veil"]="defensive",
    ["transfusion"]="defensive", ["fleshcraft"]="defensive",
  },
  ["Chronomancer"]={
    ["fortify timeline"]="defensive", ["displacement"]="utility",
    ["continuum restoration"]="defensive",
  },
  ["Cultist"]={["voidborne"]="defensive"},
  ["Pyromancer"]={["volcanic shell"]="defensive"},
  ["Ranger"]={
    ["briar veil"]="defensive", ["natural disguise"]="defensive",
    ["adrenaline rush"]="defensive",
  },
  ["Reaper"]={
    ["bolstered form"]="defensive", ["spectral warden"]="defensive",
    ["shadow's embrace"]="defensive",
  },
  ["Runemaster"]={
    ["guarding rune"]="defensive", ["warding rune"]="defensive",
    ["echo rune"]="utility", ["phase out"]="utility", ["speed rune"]="utility",
  },
  ["Starcaller"]={["halt"]="utility", ["reverse magic"]="utility"},
  ["Sun Cleric"]={
    ["scroll of hope"]="defensive", ["sunwell"]="defensive",
    ["circle of valor"]="defensive",
  },
  ["Templar"]={
    ["temple guardian"]="defensive", ["libram of tenacity"]="defensive",
  },
  ["Tinker"]={
    ["auto resuscitation device"]="defensive", ["med pack"]="defensive",
  },
  ["Witch Doctor"]={["base: crystal water"]="defensive"},
  ["Witch Hunter"]={["daring escape"]="utility"},
}

local function OverlayAuditedSpells()
  for className, additions in pairs(EXTRA_DEFINITIONS) do
    local database = RUI:GetClassSpellDatabase(className)
    if database then
      database.spells = database.spells or {}
      local byName = {}
      for _, record in ipairs(database.spells) do byName[Normalize(record.name)] = record end
      for _, addition in ipairs(additions) do
        local key = Normalize(addition.name)
        local record = byName[key]
        if record then
          for field, value in pairs(addition) do
            if field ~= "name" then record[field] = value end
          end
        else
          database.spells[#database.spells + 1] = addition
          byName[key] = addition
        end
      end
    end
  end
end
OverlayAuditedSpells()

local function ExplicitRow(className, record)
  local overrides = ROW_OVERRIDES[className]
  local value = overrides and overrides[Normalize(record and record.name)]
  if value then return value end
  value = Normalize(record and record.cooldownRow)
  if value == "offensive" or value == "defensive" or value == "core" or value == "utility" then
    return value
  end
end

local function CooldownHint(record)
  if RUI.GetSpellRecordCooldownHint then return RUI:GetSpellRecordCooldownHint(record) or 0 end
  return tonumber(record and record.cooldownHint) or 0
end

local function DedicatedRow(className, record)
  if type(record) ~= "table" then return nil end
  local explicit = ExplicitRow(className, record)
  if explicit == "offensive" or explicit == "defensive" then return explicit end
  if explicit == "core" or explicit == "utility" then return nil end
  local cooldown = CooldownHint(record)
  local cooldownCategory = Normalize(record.cooldownCategory)
  if cooldownCategory == "offensive" and cooldown >= 30 then return "offensive" end
  if cooldownCategory == "defensive" and cooldown >= 20 then return "defensive" end
  if record.forceCooldownRow ~= true and (record.forceMain == true or record.forceUtility == true) then
    return nil
  end
  local category = Normalize(record.category)
  if category == "offensive" and cooldown >= 30 then return "offensive" end
  if category == "defensive" and cooldown >= 20 then return "defensive" end
end

local function RecordVisible(className, record)
  if type(record) ~= "table" or record.disabled == true or record.trackCooldown == false then return false end
  if record.trackHUD == false and record.forceCooldownRow ~= true then return false end
  if record.showStateActivationOnHUD ~= true and RUI.IsClassStateName
    and RUI:IsClassStateName(className, record.buff or record.name)
  then
    return false
  end
  if RUI.ShouldShowSpellRecord and not RUI:ShouldShowSpellRecord(record) then return false end
  if RUI.IsMeaningfulHUDCooldown and not RUI:IsMeaningfulHUDCooldown(record) then return false end
  if RUI.IsSpellRecordCastable then return RUI:IsSpellRecordCastable(record) end
  return RUI.IsSpellRecordLearned and RUI:IsSpellRecordLearned(record) or false
end

local function SortRecords(records)
  table.sort(records, function(left, right)
    local a = tonumber(left.cooldownRowOrder) or tonumber(left.order) or 9999
    local b = tonumber(right.cooldownRowOrder) or tonumber(right.order) or 9999
    if a ~= b then return a < b end
    a, b = CooldownHint(left), CooldownHint(right)
    if a ~= b then return a < b end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

function RUI:GetClassCooldownRowDefinitions(className, row)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if row ~= "offensive" and row ~= "defensive" then return {} end
  local result, seen = {}, {}
  local function Add(record)
    if DedicatedRow(className, record) ~= row or not RecordVisible(className, record) then return end
    local key = Normalize(record.name or tostring(record.id or ""))
    if key == "" or seen[key] then return end
    seen[key], result[#result + 1] = true, record
  end
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do Add(record) end
  local database = self:GetClassSpellDatabase(className)
  if not (database and database.disableLiveClassCooldowns == true) and self.GetLiveClassCooldownDefinitions then
    for _, record in ipairs(self:GetLiveClassCooldownDefinitions(className) or {}) do Add(record) end
  end
  return SortRecords(result)
end

-- Filter dedicated cooldowns from core/utility, then inject the few explicit
-- cross-row corrections without rewriting every custom class HUD.
if not RUI._cooldownRowsDefinitionFilterInstalled then
  local OriginalGetHUDSpellDefinitions = RUI.GetHUDSpellDefinitions
  function RUI:GetHUDSpellDefinitions(className, row)
    if row == "offensive" or row == "defensive" then
      return self:GetClassCooldownRowDefinitions(className, row)
    end
    local definitions = OriginalGetHUDSpellDefinitions(self, className, row) or {}
    if row ~= "core" and row ~= "utility" then return definitions end
    local result, seen = {}, {}
    local function Add(record)
      local key = Normalize(record and (record.name or tostring(record.id or "")))
      if key == "" or seen[key] then return end
      seen[key], result[#result + 1] = true, record
    end
    for _, record in ipairs(definitions) do
      local explicit = ExplicitRow(className, record)
      local wrongRow = (explicit == "core" or explicit == "utility") and explicit ~= row
      if not wrongRow and not DedicatedRow(className, record) then Add(record) end
    end
    for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
      if ExplicitRow(className, record) == row and not DedicatedRow(className, record)
        and RecordVisible(className, record)
      then
        Add(record)
      end
    end
    return SortRecords(result)
  end
  RUI._cooldownRowsDefinitionFilterInstalled = true
end

local manager = RUI.CooldownRows or {
  elapsed=0, ensureElapsed=0, lastClass=nil, needsBuild=true, pendingBuild=false,
}
RUI.CooldownRows = manager

local function CombatLocked()
  return InCombatLockdown and InCombatLockdown()
end
local function HUDActive()
  return RUI.activeClass ~= nil and RUI.activeModule ~= nil
end
local function CurrentClass()
  return RUI.activeClass or (RUI.GetDetectedClass and RUI:GetDetectedClass())
end

local function EnsureFrames()
  if manager.root then return end
  manager.root = CreateFrame("Frame", "RetreatUIClassCooldownRows", UIParent)
  manager.root:SetAllPoints(UIParent)
  manager.root:SetFrameStrata("MEDIUM")
  manager.root:Hide()
  manager.offensiveRow = CreateFrame("Frame", nil, manager.root)
  manager.offensiveRow:SetSize(640, 30)
  manager.defensiveRow = CreateFrame("Frame", nil, manager.root)
  manager.defensiveRow:SetSize(640, 30)
end

local function PositionRows()
  EnsureFrames()
  local utility = (RUI.layout and RUI.layout.utility) or {x=0, y=-224}
  local offensive = (RUI.layout and RUI.layout.offensiveCooldowns)
    or {x=tonumber(utility.x) or 0, y=(tonumber(utility.y) or -224) - 36}
  local defensive = (RUI.layout and RUI.layout.defensiveCooldowns)
    or {x=tonumber(utility.x) or 0, y=(tonumber(utility.y) or -224) - 70}
  manager.offensiveRow:ClearAllPoints()
  manager.offensiveRow:SetPoint("CENTER", UIParent, "CENTER", offensive.x or 0, offensive.y or -260)
  manager.defensiveRow:ClearAllPoints()
  manager.defensiveRow:SetPoint("CENTER", UIParent, "CENTER", defensive.x or 0, defensive.y or -294)
  if RUI.ApplyHUDFrameScale then
    RUI:ApplyHUDFrameScale(manager.offensiveRow, "utility")
    RUI:ApplyHUDFrameScale(manager.defensiveRow, "utility")
  end
end

local function Clamp(records, maximum)
  if #records <= maximum then return records end
  local result = {}
  for index = 1, maximum do result[index] = records[index] end
  return result
end
local function HideIcons(row)
  for _, icon in ipairs((row and row.icons) or {}) do icon:Hide() end
end

local function BuildRows()
  EnsureFrames()
  local className = CurrentClass()
  if not className or not HUDActive() then
    manager.root:Hide()
    HideIcons(manager.offensiveRow)
    HideIcons(manager.defensiveRow)
    manager.lastClass, manager.needsBuild = nil, true
    return false
  end
  if CombatLocked() then
    manager.pendingBuild, manager.needsBuild = true, true
    return false
  end
  PositionRows()
  local texture = function(record) return RUI:GetSpellRecordTexture(record) end
  W:BuildSpellRow(manager.offensiveRow,
    Clamp(RUI:GetClassCooldownRowDefinitions(className, "offensive"), 10),
    30, 1, function() return true end, texture)
  W:BuildSpellRow(manager.defensiveRow,
    Clamp(RUI:GetClassCooldownRowDefinitions(className, "defensive"), 10),
    30, 1, function() return true end, texture)
  manager.lastClass, manager.needsBuild, manager.pendingBuild = className, false, false
  manager.root:Show()
  return true
end

local function PlayerAuras()
  local state = {byName={}, byLower={}, byID={}}
  if not UnitBuff then return state end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local aura = {
      name=name, icon=values[3], count=tonumber(values[4]) or 0,
      duration=tonumber(values[6]) or 0, expires=tonumber(values[7]) or 0,
      spellID=tonumber(values[11]),
    }
    state.byName[name], state.byLower[Normalize(name)] = aura, aura
    if aura.spellID then state.byID[aura.spellID] = aura end
  end
  return state
end

local function UpdateRows()
  if not manager.root or not manager.root:IsShown() then return end
  if not HUDActive() then manager.root:Hide() return end
  local auras = PlayerAuras()
  local find = function(reference)
    if type(reference) == "number" then return auras.byID[reference] end
    return auras.byName[reference] or auras.byLower[Normalize(reference)]
  end
  W:UpdateSpellRow(manager.offensiveRow, find)
  W:UpdateSpellRow(manager.defensiveRow, find)
  local suppressed = RUI.IsHUDOverlaySuppressed and RUI:IsHUDOverlaySuppressed()
  manager.root:SetAlpha(suppressed and 0 or 1)
end

local function EnsureActive(force)
  EnsureFrames()
  if not HUDActive() then
    manager.root:Hide()
    manager.lastClass, manager.needsBuild = nil, true
    return
  end
  if CurrentClass() ~= manager.lastClass or force then manager.needsBuild = true end
  if manager.needsBuild and not CombatLocked() then BuildRows() end
  if not CombatLocked() then PositionRows() end
  UpdateRows()
end

function RUI:RefreshClassCooldownRows(force)
  EnsureActive(force ~= false)
  return manager.root and manager.root:IsShown() or false
end

EnsureFrames()
manager.events = manager.events or CreateFrame("Frame")
for _, event in ipairs({
  "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED",
  "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "SPELLS_CHANGED",
  "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_COOLDOWN",
  "UNIT_AURA", "PLAYER_REGEN_ENABLED",
}) do
  pcall(manager.events.RegisterEvent, manager.events, event)
end
manager.events:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" and unit and unit ~= "player" then return end
  if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP"
    or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
    or event == "ACTIVE_TALENT_GROUP_CHANGED"
  then
    manager.needsBuild = true
    if CombatLocked() then
      manager.pendingBuild = true
      return
    end
    if RUI.ScanSpellbook then pcall(RUI.ScanSpellbook, RUI) end
    if RUI.InvalidateAdvancementEntryCache then RUI:InvalidateAdvancementEntryCache() end
    EnsureActive(true)
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    EnsureActive(manager.pendingBuild or manager.needsBuild)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    manager.needsBuild = true
    EnsureActive(true)
    return
  end
  UpdateRows()
end)

manager.timer = manager.timer or CreateFrame("Frame")
manager.timer:SetScript("OnUpdate", function(_, delta)
  manager.elapsed, manager.ensureElapsed = manager.elapsed + delta, manager.ensureElapsed + delta
  if manager.elapsed >= 0.10 then
    manager.elapsed = 0
    UpdateRows()
  end
  if manager.ensureElapsed >= 0.50 then
    manager.ensureElapsed = 0
    EnsureActive(false)
  end
end)
manager.timer:Show()
