local RUI = RetreatUI
if not RUI then return end

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function Contains(haystack, needle)
  if needle == "" then return true end
  return Normalize(haystack):find(needle, 1, true) ~= nil
end

local function CooldownRuntimeID(self, record, metadata)
  if tonumber(metadata and metadata.cooldownID) then return tonumber(metadata.cooldownID) end
  if self.GetSpellRecordRuntimeID then
    local ok, value = pcall(self.GetSpellRecordRuntimeID, self, record)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return tonumber(record and record.id)
end

local function Learned(self, record)
  if not self.IsSpellRecordLearned then return false end
  local ok, value = pcall(self.IsSpellRecordLearned, self, record)
  return ok and value == true
end

local function Texture(self, record)
  if not self.GetSpellRecordTexture then return record and record.fallbackIcon end
  local ok, value = pcall(self.GetSpellRecordTexture, self, record)
  if ok then return value end
  return record and record.fallbackIcon
end

local function MatchesTypes(metadata, requested)
  if type(requested) ~= "string" or requested == "" or requested == "all" then return true end
  for _, value in ipairs(metadata.trackingTypes or {}) do if value == requested then return true end end
  return false
end

local function CatalogItem(self, className, record)
  local metadata = self.InferTrackerMetadata and self:InferTrackerMetadata(record, className)
  if not metadata then return nil end

  -- spellID is always the source/ability identity. cooldownID may be an Ascension
  -- replacement/runtime spell. auraID/effectID is the applied runtime state.
  local spellID = tonumber(metadata.spellID or record.id)
  local cooldownID = CooldownRuntimeID(self, record, metadata)
  return {
    key = spellID and ("spell:" .. tostring(spellID)) or ("name:" .. Normalize(record.name)),
    className = className,
    specialization = metadata.specialization,
    name = metadata.name or record.name,
    spellID = spellID,
    cooldownID = cooldownID,
    effectID = metadata.effectID,
    auraID = metadata.auraID,
    effectKind = metadata.effectKind,
    effectConfidence = metadata.effectConfidence,
    auraName = metadata.auraName,
    icon = Texture(self, record),
    category = metadata.category,
    trackingTypes = metadata.trackingTypes,
    template = metadata.template,
    defaultUnit = metadata.defaultUnit,
    trackable = metadata.trackable,
    recommended = metadata.recommended,
    advanced = metadata.advanced,
    learned = Learned(self, record),
    maxStacks = metadata.maxStacks,
    cooldownHint = metadata.cooldownHint,
    source = metadata.source,
    auditCatalog = record.auditCatalog == true,
    relatedSpellIDs = metadata.relatedSpellIDs or record.relatedSpellIDs,
    spellEffectRelations = metadata.spellEffectRelations or record.spellEffectRelations,
    record = record,
  }
end

local function AddIfVisible(self, result, seen, className, record, filters)
  local item = CatalogItem(self, className, record)
  if not item or not item.key or seen[item.key] then return end

  local specOK = filters.specialization == "" or filters.specialization == "all" or Normalize(item.specialization) == filters.specialization
  local queryOK = filters.query == "" or Contains(item.name, filters.query) or Contains(item.category, filters.query)
    or tostring(item.spellID or ""):find(filters.query, 1, true) or tostring(item.auraID or ""):find(filters.query, 1, true)
  local learnedOK = not filters.learnedOnly or item.learned
  local recommendedOK = not filters.recommendedOnly or item.recommended
  local advancedOK = filters.includeAdvanced or not item.advanced
  local trackableOK = filters.includeUntrackable or item.trackable
  local typeOK = MatchesTypes(item, filters.trackingType)

  if specOK and queryOK and learnedOK and recommendedOK and advancedOK and trackableOK and typeOK then
    result[#result + 1] = item
    seen[item.key] = true
  end
end

function RUI:GetTrackerCatalog(className, options)
  options = type(options) == "table" and options or {}
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return {} end

  local filters = {
    query = Normalize(options.query), specialization = Normalize(options.specialization), trackingType = Normalize(options.trackingType),
    learnedOnly = options.learnedOnly ~= false, recommendedOnly = options.recommendedOnly == true,
    includeAdvanced = options.includeAdvanced == true, includeUntrackable = options.includeUntrackable == true,
  }

  local result, seen = {}, {}
  -- Curated layout/class records win presentation, but InferTrackerMetadata enriches
  -- them from the generated audit by source spellID before they are added here.
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do AddIfVisible(self, result, seen, className, record, filters) end
  if self.GetAuditSpellCatalog then
    for _, record in ipairs(self:GetAuditSpellCatalog(className) or {}) do AddIfVisible(self, result, seen, className, record, filters) end
  end

  table.sort(result, function(a, b)
    if a.recommended ~= b.recommended then return a.recommended == true end
    if a.learned ~= b.learned then return a.learned == true end
    local leftSpec, rightSpec = tostring(a.specialization or ""), tostring(b.specialization or "")
    if leftSpec ~= rightSpec then return leftSpec < rightSpec end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return result
end

function RUI:GetTrackerCatalogSpecializations(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local database = self.GetClassSpellDatabase and self:GetClassSpellDatabase(className)
  local result, seen = {}, {}
  local function Add(value)
    if type(value) == "string" and value ~= "" and not seen[value] then result[#result + 1] = value; seen[value] = true end
  end
  for _, value in ipairs((database and database.tabs) or {}) do Add(value) end
  if self.GetAuditSpellCatalog then for _, record in ipairs(self:GetAuditSpellCatalog(className) or {}) do Add(record.specialization or record.sourceTab) end end
  table.sort(result)
  return result
end

function RUI:GetTrackerCatalogSummary(className)
  local all = self:GetTrackerCatalog(className, {learnedOnly=false, includeAdvanced=true, includeUntrackable=true})
  local summary = {total=#all, trackable=0, learned=0, recommended=0, advanced=0, audit=0, effects=0}
  for _, item in ipairs(all) do
    if item.trackable then summary.trackable = summary.trackable + 1 end
    if item.learned then summary.learned = summary.learned + 1 end
    if item.recommended then summary.recommended = summary.recommended + 1 end
    if item.advanced then summary.advanced = summary.advanced + 1 end
    if item.auditCatalog then summary.audit = summary.audit + 1 end
    if item.effectConfidence == "high" and item.effectID then summary.effects = summary.effects + 1 end
  end
  return summary
end
