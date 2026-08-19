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

local function RuntimeID(self, record)
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
  for _, value in ipairs(metadata.trackingTypes or {}) do
    if value == requested then return true end
  end
  return false
end

local function CatalogItem(self, className, record)
  local metadata = self.InferTrackerMetadata and self:InferTrackerMetadata(record, className)
  if not metadata then return nil end
  local spellID = RuntimeID(self, record) or metadata.spellID
  return {
    key = spellID and ("spell:" .. tostring(spellID)) or ("name:" .. Normalize(record.name)),
    className = className,
    specialization = metadata.specialization,
    name = metadata.name or record.name,
    spellID = spellID,
    auraID = metadata.auraID,
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
    record = record,
  }
end

function RUI:GetTrackerCatalog(className, options)
  options = type(options) == "table" and options or {}
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return {} end

  local query = Normalize(options.query)
  local specialization = Normalize(options.specialization)
  local trackingType = Normalize(options.trackingType)
  local learnedOnly = options.learnedOnly ~= false
  local recommendedOnly = options.recommendedOnly == true
  local includeAdvanced = options.includeAdvanced == true
  local includeUntrackable = options.includeUntrackable == true

  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    local item = CatalogItem(self, className, record)
    if item and item.key and not seen[item.key] then
      local specOK = specialization == "" or specialization == "all" or Normalize(item.specialization) == specialization
      local queryOK = query == "" or Contains(item.name, query) or Contains(item.category, query) or tostring(item.spellID or ""):find(query, 1, true)
      local learnedOK = not learnedOnly or item.learned
      local recommendedOK = not recommendedOnly or item.recommended
      local advancedOK = includeAdvanced or not item.advanced
      local trackableOK = includeUntrackable or item.trackable
      local typeOK = MatchesTypes(item, trackingType)
      if specOK and queryOK and learnedOK and recommendedOK and advancedOK and trackableOK and typeOK then
        result[#result + 1] = item
        seen[item.key] = true
      end
    end
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
  for _, value in ipairs((database and database.tabs) or {}) do
    if type(value) == "string" and value ~= "" and not seen[value] then
      result[#result + 1] = value
      seen[value] = true
    end
  end
  return result
end

function RUI:GetTrackerCatalogSummary(className)
  local all = self:GetTrackerCatalog(className, {learnedOnly=false, includeAdvanced=true, includeUntrackable=true})
  local summary = {total=#all, trackable=0, learned=0, recommended=0, advanced=0}
  for _, item in ipairs(all) do
    if item.trackable then summary.trackable = summary.trackable + 1 end
    if item.learned then summary.learned = summary.learned + 1 end
    if item.recommended then summary.recommended = summary.recommended + 1 end
    if item.advanced then summary.advanced = summary.advanced + 1 end
  end
  return summary
end
