local RUI = RetreatUI
if not RUI then return end

-- RetreatUI HUD policy -------------------------------------------------------
-- Main Rotation is the single action/cooldown row. Every learned, castable and
-- meaningful offensive or defensive class ability belongs there, together
-- with rotational fillers and resource buttons that have a real cooldown.
-- Interrupts, taunts, mobility, control and other utility stay on Utility.
-- Persistent class states are removed afterwards by StateHUDGuard.
local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AuditedSpell(name, id, category, cooldown)
  return {
    name=name,
    id=id,
    category=category,
    hudRow="core",
    forceHUD=true,
    forceMain=true,
    trackHUD=true,
    trackCooldown=true,
    cooldownHint=cooldown,
    cooldownCategory=category,
    source="CooldownSpreadsheetAudit",
  }
end

-- High-confidence spreadsheet gaps. Ambiguous replacements and records with
-- missing tooltips remain excluded until they are verified in game.
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

local function OverlayAuditedSpells()
  if not RUI.GetClassSpellDatabase then return end
  for className, additions in pairs(EXTRA_DEFINITIONS) do
    local database = RUI:GetClassSpellDatabase(className)
    if database then
      database.spells = database.spells or {}
      local byName = {}
      for _, record in ipairs(database.spells) do
        byName[Normalize(record.name)] = record
      end
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

-- Manual semantic corrections. "core" means an offensive/defensive action;
-- "utility" means the spell is not part of the Main Rotation action row.
local CURATED_ROWS = {
  ["Bloodmage"]={
    ["blood bond"]="core",
    ["blood veil"]="core",
    ["transfusion"]="core",
    ["fleshcraft"]="core",
  },
  ["Chronomancer"]={
    ["fortify timeline"]="core",
    ["displacement"]="utility",
    ["continuum restoration"]="core",
  },
  ["Cultist"]={
    ["voidborne"]="core",
  },
  ["Pyromancer"]={
    ["volcanic shell"]="core",
  },
  ["Ranger"]={
    ["briar veil"]="core",
    ["natural disguise"]="core",
    ["adrenaline rush"]="core",
  },
  ["Reaper"]={
    ["spectral warden"]="core",
    ["shadow's embrace"]="core",
  },
  ["Runemaster"]={
    ["guarding rune"]="core",
    ["warding rune"]="core",
    ["echo rune"]="utility",
    ["phase out"]="utility",
    ["speed rune"]="utility",
  },
  ["Starcaller"]={
    ["halt"]="utility",
    ["reverse magic"]="utility",
  },
  ["Sun Cleric"]={
    ["scroll of hope"]="core",
    ["sunwell"]="core",
    ["circle of valor"]="core",
  },
  ["Templar"]={
    ["temple guardian"]="core",
    ["libram of tenacity"]="core",
  },
  ["Tinker"]={
    ["auto resuscitation device"]="core",
    ["med pack"]="core",
  },
  ["Witch Doctor"]={
    ["base: crystal water"]="core",
  },
  ["Witch Hunter"]={
    ["daring escape"]="utility",
  },
}

local CORE_CATEGORIES = {
  rotation=true,
  resource=true,
  offensive=true,
  defensive=true,
  summon=true,
}

local UTILITY_CATEGORIES = {
  interrupt=true,
  taunt=true,
  control=true,
  mobility=true,
  utility=true,
  ally=true,
  racial=true,
  dispel=true,
}

local function CooldownHint(record)
  if RUI.GetSpellRecordCooldownHint then
    return tonumber(RUI:GetSpellRecordCooldownHint(record)) or 0
  end
  return tonumber(record and record.cooldownHint) or 0
end

local function CuratedRow(className, record)
  local rows = CURATED_ROWS[className]
  return rows and rows[Normalize(record and record.name)] or nil
end

local function IsMajorCategory(record)
  local category = Normalize(record and record.category)
  local cooldownCategory = Normalize(record and record.cooldownCategory)
  return category == "offensive" or category == "defensive"
    or cooldownCategory == "offensive" or cooldownCategory == "defensive"
end

local function IsVisible(className, record)
  if type(record) ~= "table" or record.disabled == true or record.trackCooldown == false then
    return false
  end

  -- Audit/source-reference files are data-only unless explicitly approved.
  if record.auditRecord == true and record.hudApproved ~= true then return false end

  local curated = CuratedRow(className, record)
  local explicit = curated ~= nil or record.forceMain == true or record.forceUtility == true
    or record.forceHUD == true or IsMajorCategory(record)
  if record.trackHUD == false and not explicit then return false end

  if RUI.ShouldShowSpellRecord and not RUI:ShouldShowSpellRecord(record) then return false end
  if RUI.IsMeaningfulHUDCooldown and not RUI:IsMeaningfulHUDCooldown(record) then return false end
  if RUI.IsSpellRecordCastable then return RUI:IsSpellRecordCastable(record) end
  return RUI.IsSpellRecordLearned and RUI:IsSpellRecordLearned(record) or false
end

local function DesiredRow(className, record)
  local curated = CuratedRow(className, record)
  if curated then return curated end

  local category = Normalize(record and record.category)
  local cooldownCategory = Normalize(record and record.cooldownCategory)

  -- Offensive and defensive classification always wins over an old hudRow or
  -- forceUtility flag. The user wants every such learned cooldown on Main.
  if category == "offensive" or category == "defensive"
    or cooldownCategory == "offensive" or cooldownCategory == "defensive"
  then
    return "core"
  end

  if CORE_CATEGORIES[category] then return "core" end
  if record.forceMain == true then return "core" end
  if record.forceUtility == true then return "utility" end
  if UTILITY_CATEGORIES[category] then return "utility" end

  local configured = Normalize(record and record.hudRow)
  if configured == "core" or configured == "utility" then return configured end
  return nil
end

local function SortRecords(records)
  table.sort(records, function(left, right)
    local leftOrder = tonumber(left.cooldownRowOrder) or tonumber(left.order) or 9999
    local rightOrder = tonumber(right.cooldownRowOrder) or tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    local leftCooldown, rightCooldown = CooldownHint(left), CooldownHint(right)
    if leftCooldown ~= rightCooldown then return leftCooldown < rightCooldown end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

local function AddRecord(result, seen, className, record, row)
  if DesiredRow(className, record) ~= row or not IsVisible(className, record) then return end
  local key = Normalize(record.name or tostring(record.id or ""))
  if key == "" or seen[key] then return end
  seen[key] = true
  result[#result + 1] = record
end

function RUI:GetClassCooldownRowDefinitions()
  -- Dedicated Offensive/Defensive rows are retired in this layout. Their
  -- contents are merged into Main Rotation through GetHUDSpellDefinitions.
  return {}
end

function RUI:GetHUDSpellDefinitions(className, row)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if row == "offensive" or row == "defensive" then return {} end
  if row ~= "core" and row ~= "utility" then return {} end

  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    AddRecord(result, seen, className, record, row)
  end

  -- Live discovery remains a narrow safety net. Generic tooltip classification
  -- is not trusted to decide that an unknown spell belongs on the HUD.
  if self.GetLiveClassCooldownDefinitions then
    for _, record in ipairs(self:GetLiveClassCooldownDefinitions(className) or {}) do
      if record.forceMain == true or record.forceUtility == true then
        AddRecord(result, seen, className, record, row)
      end
    end
  end

  return SortRecords(result)
end

RUI._strictCooldownHUDPolicyInstalled = true
RUI._singleMainCooldownRow = true
