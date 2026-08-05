local RUI = RetreatUI
if not RUI then return end

-- RetreatUI HUD policy -------------------------------------------------------
-- Main Rotation is allowed to contain short learned cooldowns, including
-- 2-5 second filler buttons. Offensive and Defensive rows are deliberately
-- stricter: a spell must be explicitly curated as a major cooldown.
local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local CORE_CATEGORIES = {
  rotation=true,
  resource=true,
}

local UTILITY_CATEGORIES = {
  interrupt=true,
  taunt=true,
  control=true,
  mobility=true,
  defensive=true,
  utility=true,
  stance=true,
  form=true,
  ally=true,
  racial=true,
}

-- Manual corrections for abilities whose raw category does not describe the
-- actual combat decision. These are intentional HUD placements, not an
-- automatic import of every spell in the catalogue.
local CURATED_ROWS = {
  ["Bloodmage"]={
    ["blood bond"]="defensive",
    ["blood veil"]="defensive",
    ["transfusion"]="defensive",
    ["fleshcraft"]="defensive",
  },
  ["Chronomancer"]={
    ["fortify timeline"]="defensive",
    ["displacement"]="utility",
    ["continuum restoration"]="defensive",
  },
  ["Cultist"]={
    ["voidborne"]="defensive",
  },
  ["Pyromancer"]={
    ["volcanic shell"]="defensive",
  },
  ["Ranger"]={
    ["briar veil"]="defensive",
    ["natural disguise"]="defensive",
    ["adrenaline rush"]="defensive",
  },
  ["Reaper"]={
    ["bolstered form"]="defensive",
    ["spectral warden"]="defensive",
    ["shadow's embrace"]="defensive",
  },
  ["Runemaster"]={
    ["guarding rune"]="defensive",
    ["warding rune"]="defensive",
    ["echo rune"]="utility",
    ["phase out"]="utility",
    ["speed rune"]="utility",
  },
  ["Starcaller"]={
    ["halt"]="utility",
    ["reverse magic"]="utility",
  },
  ["Sun Cleric"]={
    ["scroll of hope"]="defensive",
    ["sunwell"]="defensive",
    ["circle of valor"]="defensive",
  },
  ["Templar"]={
    ["temple guardian"]="defensive",
    ["libram of tenacity"]="defensive",
  },
  ["Tinker"]={
    ["auto resuscitation device"]="defensive",
    ["med pack"]="defensive",
  },
  ["Witch Doctor"]={
    ["base: crystal water"]="defensive",
  },
  ["Witch Hunter"]={
    ["daring escape"]="utility",
  },
}

local function CooldownHint(record)
  if RUI.GetSpellRecordCooldownHint then
    return tonumber(RUI:GetSpellRecordCooldownHint(record)) or 0
  end
  return tonumber(record and record.cooldownHint) or 0
end

local function ExplicitRow(className, record)
  if type(record) ~= "table" then return nil end

  local classRows = CURATED_ROWS[className]
  local row = classRows and classRows[Normalize(record.name)]
  if row then return row end

  -- Spreadsheet/class-data curation is authoritative only when the record is
  -- explicitly marked as a party/major cooldown. Merely having a long cooldown
  -- or an Offensive/Defensive category is not enough.
  local category = Normalize(record.cooldownCategory)
  if record.partyCooldown == true and (category == "offensive" or category == "defensive") then
    return category
  end

  row = Normalize(record.cooldownRow)
  if record.forceCooldownRow == true
    and (row == "offensive" or row == "defensive" or row == "core" or row == "utility")
  then
    return row
  end
  return nil
end

local function IsVisible(className, record)
  if type(record) ~= "table" or record.disabled == true or record.trackCooldown == false then
    return false
  end

  local explicit = ExplicitRow(className, record)
  if record.trackHUD == false and not explicit then return false end

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

local function MainRow(className, record)
  local explicit = ExplicitRow(className, record)
  if explicit == "offensive" or explicit == "defensive" then return nil end
  if explicit == "core" or explicit == "utility" then return explicit end

  if record.forceMain == true then return "core" end
  if record.forceUtility == true then return "utility" end

  local category = Normalize(record.category)
  if CORE_CATEGORIES[category] then return "core" end

  -- Some class databases label short rotational attacks as Offensive rather
  -- than Rotation. Keep those learned filler/cycle buttons on Main Rotation,
  -- but do not promote long uncurated cooldowns into the HUD.
  if category == "offensive" or category == "summon" then
    local cooldown = CooldownHint(record)
    if record.partyCooldown ~= true and cooldown > 1.5 and cooldown <= 30 then
      return "core"
    end
    return nil
  end

  if UTILITY_CATEGORIES[category] then return "utility" end

  local configured = Normalize(record.hudRow)
  if configured == "core" and CooldownHint(record) > 1.5 and CooldownHint(record) <= 30 then
    return "core"
  end
  if configured == "utility" then return "utility" end
  return nil
end

local function SortRecords(records)
  table.sort(records, function(left, right)
    local leftOrder = tonumber(left.cooldownRowOrder) or tonumber(left.order) or 9999
    local rightOrder = tonumber(right.cooldownRowOrder) or tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    local leftCooldown = CooldownHint(left)
    local rightCooldown = CooldownHint(right)
    if leftCooldown ~= rightCooldown then return leftCooldown < rightCooldown end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

local function AddRecord(result, seen, className, record, row, dedicated)
  if not IsVisible(className, record) then return end

  local desired = dedicated and ExplicitRow(className, record) or MainRow(className, record)
  if desired ~= row then return end

  local key = Normalize(record.name or tostring(record.id or ""))
  if key == "" or seen[key] then return end
  seen[key] = true
  result[#result + 1] = record
end

function RUI:GetClassCooldownRowDefinitions(className, row)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if row ~= "offensive" and row ~= "defensive" then return {} end

  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    AddRecord(result, seen, className, record, row, true)
  end

  -- Live spellbook discovery is not used as a blanket source for major
  -- cooldown rows. Exact class records and explicit curation must exist first.
  return SortRecords(result)
end

function RUI:GetHUDSpellDefinitions(className, row)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if row == "offensive" or row == "defensive" then
    return self:GetClassCooldownRowDefinitions(className, row)
  end
  if row ~= "core" and row ~= "utility" then return {} end

  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    AddRecord(result, seen, className, record, row, false)
  end

  -- Keep the live safety net only for records that explicitly declare their
  -- placement, such as Felsworn Chaos Rush. Generic discovered cooldowns are
  -- excluded so the HUD cannot silently become a second action bar.
  if self.GetLiveClassCooldownDefinitions then
    for _, record in ipairs(self:GetLiveClassCooldownDefinitions(className) or {}) do
      if record.forceMain == true or record.forceUtility == true then
        AddRecord(result, seen, className, record, row, false)
      end
    end
  end

  return SortRecords(result)
end

RUI._strictCooldownHUDPolicyInstalled = true
