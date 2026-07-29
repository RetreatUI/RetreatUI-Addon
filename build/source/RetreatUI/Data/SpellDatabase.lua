local RUI = RetreatUI

RUI.spellDatabase = RUI.spellDatabase or {}
RUI.spellDatabaseVersion = 1


local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value):gsub("^%s+", ""):gsub("%s+$", "")
end


function RUI:RegisterClassSpellDatabase(className, database)
  if type(className) ~= "string" or type(database) ~= "table" then return false end
  database.className = className
  database.version = tonumber(database.version) or 1
  database.spells = database.spells or {}
  database.resources = database.resources or {}
  self.spellDatabase[className] = database
  return true
end

function RUI:GetClassSpellDatabase(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  return self.spellDatabase[className]
end

function RUI:GetClassSpellRecords(className)
  local database = self:GetClassSpellDatabase(className)
  return database and database.spells or {}
end

function RUI:GetClassResourceRecords(className)
  local database = self:GetClassSpellDatabase(className)
  return database and database.resources or {}
end

-- Character Advancement awareness. Spellbook names remain the primary runtime
-- reference for ranks and replacement spell IDs, but the active CA slot is the
-- authoritative answer to whether a talent/spec node is currently selected.
-- This prevents spells from a previous specialization remaining on the HUD
-- while Ascension is still rebuilding the spellbook.
function RUI:GetActiveAdvancementSlot()
  local specialization = _G.SpecializationUtil
  if specialization and type(specialization.GetActiveSpecialization) == "function" then
    local ok, slot = pcall(specialization.GetActiveSpecialization)
    if ok and tonumber(slot) then return tonumber(slot) end
  end

  local advancement = _G.C_CharacterAdvancement
  if advancement and type(advancement.GetInspectInfo) == "function" then
    local ok, slot = pcall(advancement.GetInspectInfo, "player")
    if ok and tonumber(slot) then return tonumber(slot) end
  end

  if type(GetActiveTalentGroup) == "function" then
    local ok, slot = pcall(GetActiveTalentGroup)
    if ok and tonumber(slot) then return tonumber(slot) end
  end
  return 1
end

function RUI:IsAdvancementEntryLearned(entryID)
  entryID = tonumber(entryID)
  local advancement = _G.C_CharacterAdvancement
  if not entryID or type(advancement) ~= "table" then return nil end
  local slot = self:GetActiveAdvancementSlot()

  local rankKnown
  if type(advancement.UnitTalentRankByID) == "function" then
    local ok, rank = pcall(advancement.UnitTalentRankByID, "player", entryID, slot)
    if ok and type(rank) == "number" then
      if rank > 0 then return true end
      rankKnown = false
    end
  end

  -- Ability nodes are not reported as talents on every Ascension build, so a
  -- zero talent rank still gets a second authoritative check through UnitKnownID.
  if type(advancement.UnitKnownID) == "function" then
    local ok, known = pcall(advancement.UnitKnownID, "player", entryID, slot)
    if ok and type(known) == "boolean" then return known end
  end
  return rankKnown
end

function RUI:IsSpellRecordLearned(record)
  if type(record) ~= "table" then return false end

  local advancementID = record.collectorEntryID or record.entryID or record.talentID
  if advancementID and self.IsAdvancementEntryLearned then
    local known = self:IsAdvancementEntryLearned(advancementID)
    if known ~= nil then
      if known then return true end
      -- A definite false from the active Character Advancement slot must win
      -- over stale spellbook entries from the previously active spec.
      return false
    end
  end

  -- Prefer the actual spellbook entry. Ascension talent IDs can sometimes
  -- point at a passive/advancement record rather than the castable spell.
  if record.name and self.IsSpellLearned and self:IsSpellLearned(record.name) then return true end
  for _, alias in ipairs(record.aliases or {}) do
    if self.IsSpellLearned and self:IsSpellLearned(alias) then return true end
  end
  if record.id and self.IsSpellIDLearned and self:IsSpellIDLearned(record.id) then return true end
  return false
end

function RUI:GetSpellRecordBookIndex(record)
  if type(record) ~= "table" then return nil end
  if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end

  if record.name and self.GetSpellBookIndex then
    local index = self:GetSpellBookIndex(record.name)
    if index then return index end
  end
  for _, alias in ipairs(record.aliases or {}) do
    if self.GetSpellBookIndex then
      local index = self:GetSpellBookIndex(alias)
      if index then return index end
    end
  end
  if record.id and self.GetSpellBookIndexByID then
    return self:GetSpellBookIndexByID(record.id)
  end
  return nil
end

function RUI:GetSpellRecordRuntimeID(record)
  if type(record) ~= "table" then return nil end
  if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end

  local function ByName(name)
    if not name or not self.spellbook or not self.spellbook.ids then return nil end
    return self.spellbook.ids[Normalize(name)]
  end

  local spellID = ByName(record.name)
  if spellID then return spellID end
  for _, alias in ipairs(record.aliases or {}) do
    spellID = ByName(alias)
    if spellID then return spellID end
  end
  return tonumber(record.id)
end



-- Talent-aware visibility helpers. These rules are deliberately data-driven so
-- class modules can describe replacements and passive conversions without
-- adding one-off conditionals to their HUD files.
local function AnyConditionLearned(self, values)
  if values == nil then return false end
  if type(values) ~= "table" then values = {values} end
  for _, value in ipairs(values) do
    if type(value) == "number" and self.IsSpellIDLearned and self:IsSpellIDLearned(value) then return true end
    if type(value) == "string" and self.IsSpellLearned and self:IsSpellLearned(value) then return true end
    if type(value) == "table" then
      if value.id and self.IsSpellIDLearned and self:IsSpellIDLearned(value.id) then return true end
      if value.name and self.IsSpellLearned and self:IsSpellLearned(value.name) then return true end
    end
  end
  return false
end

function RUI:IsSpellRecordPassive(record)
  if type(record) ~= "table" then return false end
  local spellID = self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record) or tonumber(record.id)
  if spellID and IsPassiveSpell then
    local ok, passive = pcall(IsPassiveSpell, spellID)
    if ok and passive then return true end
  end
  return record.passive == true
end

function RUI:IsSpellRecordCastable(record)
  if type(record) ~= "table" then return false end
  if self:IsSpellRecordPassive(record) then return false end
  if AnyConditionLearned(self, record.becomesPassiveWhen) then return false end
  return self:IsSpellRecordLearned(record)
end

function RUI:ShouldShowSpellRecord(record)
  if type(record) ~= "table" or record.disabled == true then return false end
  if record.hideIfSpellIDLearned and self.IsSpellIDLearned and self:IsSpellIDLearned(record.hideIfSpellIDLearned) then return false end
  if record.hideIfSpellLearned and self.IsSpellLearned and self:IsSpellLearned(record.hideIfSpellLearned) then return false end
  if AnyConditionLearned(self, record.hideWhen) then return false end
  if record.requiresSpellID and self.IsSpellIDLearned and not self:IsSpellIDLearned(record.requiresSpellID) then return false end
  if record.requiresSpell and self.IsSpellLearned and not self:IsSpellLearned(record.requiresSpell) then return false end
  if record.requiresAny and not AnyConditionLearned(self, record.requiresAny) then return false end
  if record.requiresAll then
    local values = type(record.requiresAll) == "table" and record.requiresAll or {record.requiresAll}
    for _, value in ipairs(values) do if not AnyConditionLearned(self, {value}) then return false end end
  end
  if record.hudRow and record.allowPassiveOnHUD ~= true and self:IsSpellRecordPassive(record) then return false end
  if record.hudRow and AnyConditionLearned(self, record.becomesPassiveWhen) then return false end
  return true
end

function RUI:GetSpellRecordTexture(record)
  if type(record) ~= "table" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  local texture

  -- Use the learned spellbook entry first. This keeps the HUD icon tied to
  -- the castable spell even when an Ascension talent ID resolves to another
  -- internal effect with a different icon.
  local bookIndex = self.GetSpellRecordBookIndex and self:GetSpellRecordBookIndex(record)
  if bookIndex and GetSpellBookItemTexture then
    local ok, result = pcall(GetSpellBookItemTexture, bookIndex, BOOKTYPE_SPELL or "spell")
    if ok then texture = result end
  end

  local _, _, infoTexture
  if not texture and record.name and GetSpellInfo then
    _, _, infoTexture = GetSpellInfo(record.name)
    texture = infoTexture
  end
  if not texture then
    for _, alias in ipairs(record.aliases or {}) do
      _, _, infoTexture = GetSpellInfo(alias)
      if infoTexture then texture = infoTexture break end
    end
  end
  if not texture and record.id and GetSpellInfo then
    _, _, texture = GetSpellInfo(record.id)
  end
  return texture or record.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end


-- HUD curation --------------------------------------------------------------
-- RetreatUI is a cooldown HUD, not a second action bar. A spell only belongs
-- on a visible HUD row when it has a meaningful cooldown/recharge, charges, or
-- an explicit class override (for example a proc-priority spell such as
-- Lichfrost). Passive talents, fillers and ordinary no-cooldown rotation
-- buttons remain available to proc/debuff logic but are never rendered.
local HUD_COOLDOWN_THRESHOLD = 1.5
local cooldownHintCache = {}
local cooldownTooltip

local CORE_CATEGORIES = {
  rotation=true, offensive=true, summon=true, resource=true,
}
local UTILITY_CATEGORIES = {
  interrupt=true, taunt=true, control=true, mobility=true,
  defensive=true, utility=true, stance=true, form=true, ally=true, racial=true,
}

local function TooltipTextForRecord(self, record)
  if not CreateFrame then return "" end
  if not cooldownTooltip then
    cooldownTooltip = CreateFrame("GameTooltip", "RetreatUIHudCooldownScanner", UIParent, "GameTooltipTemplate")
  end
  if not cooldownTooltip then return "" end

  cooldownTooltip:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
  cooldownTooltip:ClearLines()

  local shown = false
  local bookIndex = self.GetSpellRecordBookIndex and self:GetSpellRecordBookIndex(record)
  if bookIndex and cooldownTooltip.SetSpellBookItem then
    shown = pcall(cooldownTooltip.SetSpellBookItem, cooldownTooltip, bookIndex, BOOKTYPE_SPELL or "spell")
  end
  if not shown and cooldownTooltip.SetHyperlink then
    local runtimeID = self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record)
    if runtimeID then
      shown = pcall(cooldownTooltip.SetHyperlink, cooldownTooltip, "spell:" .. tostring(runtimeID))
    end
  end
  if not shown then return "" end

  local parts = {}
  for index = 1, cooldownTooltip:NumLines() do
    for _, side in ipairs({"TextLeft", "TextRight"}) do
      local fontString = _G["RetreatUIHudCooldownScanner" .. side .. index]
      local text = fontString and fontString:GetText()
      if text and text ~= "" then parts[#parts + 1] = text end
    end
  end
  return string.lower(table.concat(parts, "\n"))
end

local function ParseCooldownHint(text)
  if type(text) ~= "string" or text == "" then return 0 end
  local value = text:match("([%d%.]+)%s*hour%s+cooldown") or text:match("([%d%.]+)%s*hr%s+cooldown")
  if value then return (tonumber(value) or 0) * 3600 end
  value = text:match("([%d%.]+)%s*min%s+cooldown")
  if value then return (tonumber(value) or 0) * 60 end
  value = text:match("([%d%.]+)%s*sec%s+cooldown")
  if value then return tonumber(value) or 0 end
  value = text:match("([%d%.]+)%s*min%s+recharge")
  if value then return (tonumber(value) or 0) * 60 end
  value = text:match("([%d%.]+)%s*sec%s+recharge")
  if value then return tonumber(value) or 0 end
  return 0
end


local SortedRecords

-- Live class-spell safety net -------------------------------------------------
-- The Character Advancement tree does not contain every base class spell.
-- Ascension exposes those separately in the spellbook with the line
-- "This spell belongs to <Class>". Merge those learned cooldowns/charge spells
-- at runtime so a class can never lose core tools such as Felsworn Chaos Rush
-- merely because they are absent from GetEntriesByClass.
local liveClassSpellCache = {}

local function ContainsAny(text, values)
  for _, value in ipairs(values) do
    if string.find(text, value, 1, true) then return true end
  end
  return false
end

local function LiveClassSpellCategory(name, text)
  local normalizedName = Normalize(name)
  if normalizedName == "chaos rush" then return "rotation", "core", true end

  if ContainsAny(text, {"interrupt", "preventing any spell in that school"}) then
    return "interrupt", "utility"
  end
  if ContainsAny(text, {"forces the target to attack you", " taunt"}) then
    return "taunt", "utility"
  end
  if ContainsAny(normalizedName, {"rush", "dash", "escape", "slither", "rocket boots", "charge", "leap", "blink", "teleport", "cavalry"})
    or ContainsAny(text, {"increase your movement speed", "increasing movement speed", "launching you forward", "jump backwards", "teleport forward"})
  then
    return "mobility", "utility"
  end
  if ContainsAny(text, {"stun", "root", "fear", "silence", "knock back", "knocking back", "transform enemies", "slowing their movement", "incapacitat", "horrif"}) then
    return "control", "utility"
  end
  if ContainsAny(text, {"damage taken", "immune to", "immunity", "absorbing", "absorbs", "deflect", "cannot die", "heals you", "healing you", "maximum health", "dodge chance", "parry chance", "block chance", " shield", " ward"}) then
    return "defensive", "utility"
  end
  if ContainsAny(text, {"friendly target", "an ally", "all allies", "party and raid", "dispel", "cleanse", "remove all curse", "transfers 50%"})
    and not ContainsAny(text, {"deal ", "damage"})
  then
    return "utility", "utility"
  end
  return "offensive", "core"
end

local function LiveClassSpellOrder(category, cooldown)
  cooldown = tonumber(cooldown) or 0
  if category == "interrupt" then return 10 + math.min(cooldown, 120) end
  if category == "taunt" then return 40 + math.min(cooldown, 120) end
  if category == "mobility" then return 80 + math.min(cooldown, 120) end
  if category == "control" then return 140 + math.min(cooldown, 120) end
  if category == "defensive" then return 200 + math.min(cooldown, 120) end
  if category == "utility" then return 260 + math.min(cooldown, 120) end
  return 100 + math.min(cooldown, 300)
end

function RUI:GetLiveClassCooldownDefinitions(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if not className or not self.ScanSpellbook then return {} end
  if not self.spellbook then self:ScanSpellbook() end
  local signature = self.spellbook and self.spellbook.signature or ""
  local cacheKey = tostring(className) .. "|" .. tostring(signature)
  if liveClassSpellCache[cacheKey] then return liveClassSpellCache[cacheKey] end

  local result, seen = {}, {}
  local classNeedle = Normalize(className)
  for lowerName, index in pairs((self.spellbook and self.spellbook.indices) or {}) do
    local spellID = self.spellbook.ids and self.spellbook.ids[lowerName]
    local actualName = spellID and GetSpellInfo and GetSpellInfo(spellID) or nil
    actualName = actualName or lowerName
    local record = {name=actualName, id=spellID}
    local text = TooltipTextForRecord(self, record)
    local belongs = string.find(text, "this spell belongs to", 1, true)
      and string.find(text, classNeedle, 1, true)
    if belongs then
      local cooldown = ParseCooldownHint(text)
      local hasCharges = text:match("%d+%s+charges?") ~= nil
      if hasCharges or cooldown > HUD_COOLDOWN_THRESHOLD then
        local category, row, forceMain = LiveClassSpellCategory(actualName, text)
        local key = Normalize(actualName)
        if key ~= "" and not seen[key] then
          seen[key] = true
          local dynamic = {
            name=actualName, id=spellID, category=category, hudRow=row,
            order=LiveClassSpellOrder(category, cooldown), trackCooldown=true,
            trackCharges=hasCharges or nil, cooldownHint=cooldown,
            forceMain=forceMain or nil, liveClassSpell=true,
            fallbackIcon=spellID and select(3, GetSpellInfo(spellID)) or nil,
          }
          if key == "chaos rush" then dynamic.aliases = {"Fel Torpedo"} end
          if text:match("for%s+%d+[%d%.]*%s+sec")
            and ContainsAny(text, {"your ", "you ", "become ", "enter your ", "transform into ", "drink a "})
          then
            dynamic.buff = actualName
            dynamic.trackDuration = true
          end
          result[#result + 1] = dynamic
        end
      end
    end
  end
  liveClassSpellCache[cacheKey] = SortedRecords(result)
  return liveClassSpellCache[cacheKey]
end

function RUI:GetSpellRecordCooldownHint(record)
  if type(record) ~= "table" then return 0 end
  local explicit = tonumber(record.cooldownHint)
  if explicit then return explicit end

  local key = tostring(self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record)
    or record.id or record.name or record)
  if cooldownHintCache[key] ~= nil then return cooldownHintCache[key] end

  local hint = ParseCooldownHint(TooltipTextForRecord(self, record))
  cooldownHintCache[key] = hint
  return hint
end

function RUI:IsMeaningfulHUDCooldown(record)
  if type(record) ~= "table" then return false end
  if record.forceHUD == true or record.forceMain == true or record.forceUtility == true then return true end
  if record.trackCharges == true then return true end
  return (self:GetSpellRecordCooldownHint(record) or 0) > HUD_COOLDOWN_THRESHOLD
end

local function DesiredHUDRow(record)
  if record.forceMain == true then return "core" end
  if record.forceUtility == true then return "utility" end
  local category = Normalize(record.category)
  if CORE_CATEGORIES[category] then return "core" end
  if UTILITY_CATEGORIES[category] then return "utility" end
  return nil
end

SortedRecords = function(records)
  table.sort(records, function(left, right)
    local leftOrder = tonumber(left.order) or 9999
    local rightOrder = tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    local leftGroup = tostring(left.group or "")
    local rightGroup = tostring(right.group or "")
    if leftGroup ~= rightGroup then return leftGroup < rightGroup end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

function RUI:GetHUDSpellDefinitions(className, row)
  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    local desiredRow = DesiredHUDRow(record)
    local isClassState = record.showStateActivationOnHUD ~= true
      and type(self.IsClassStateName) == "function"
      and self:IsClassStateName(className, record.buff or record.name)
    if not isClassState
      and desiredRow == row
      and record.trackHUD ~= false
      and self:ShouldShowSpellRecord(record)
      and self:IsMeaningfulHUDCooldown(record)
    then
      local key = Normalize(record.name or tostring(record.id or ""))
      if key ~= "" and not seen[key] then
        result[#result + 1] = record
        seen[key] = true
      end
    end
  end

  -- Merge base class cooldowns discovered directly from the live spellbook.
  -- Curated database records always win when the same spell is already present.
  -- A class may opt out when it has an exact, tester-approved HUD profile;
  -- this prevents the safety net from turning the HUD back into a second action bar.
  local database = self:GetClassSpellDatabase(className)
  if not (database and database.disableLiveClassCooldowns == true) then
    for _, record in ipairs(self:GetLiveClassCooldownDefinitions(className) or {}) do
      -- The live spellbook safety net must never promote a stance/form/vow/etc.
      -- into Main Rotation merely because the activation spell has a cooldown.
      -- StateTracker owns these exact class-specific records.
      local isClassState = type(self.IsClassStateName) == "function"
        and self:IsClassStateName(className, record.name)
      if not isClassState and DesiredHUDRow(record) == row and self:ShouldShowSpellRecord(record) then
        local key = Normalize(record.name or tostring(record.id or ""))
        if key ~= "" and not seen[key] then
          result[#result + 1] = record
          seen[key] = true
        end
      end
    end
  end
  return SortedRecords(result)
end

function RUI:GetAuraTrackerDefinitions(className)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.auraTracker == true then result[#result + 1] = record end
  end
  return SortedRecords(result)
end

function RUI:GetTargetDebuffDefinitions(className)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.targetDebuff == true then result[#result + 1] = record end
  end
  return SortedRecords(result)
end

function RUI:GetPartyCooldownDefinitions(className, category)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.partyCooldown == true and (not category or record.cooldownCategory == category) then
      result[#result + 1] = record
    end
  end
  return SortedRecords(result)
end

