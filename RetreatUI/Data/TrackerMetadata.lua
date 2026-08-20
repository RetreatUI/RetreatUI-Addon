local RUI = RetreatUI
if not RUI then return end

RUI.trackerMetadataVersion = 3
RUI.trackerMetadata = RUI.trackerMetadata or {}

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function RecordKey(record)
  if type(record) ~= "table" then return nil end
  if tonumber(record.id) then return "id:" .. tostring(tonumber(record.id)) end
  if type(record.name) == "string" and record.name ~= "" then return "name:" .. Normalize(record.name) end
  return nil
end

function RUI:RegisterTrackerMetadata(className, key, metadata)
  if type(className) ~= "string" or className == "" then return false end
  if type(key) == "number" then key = "id:" .. tostring(key) end
  if type(key) ~= "string" or key == "" or type(metadata) ~= "table" then return false end
  self.trackerMetadata[className] = self.trackerMetadata[className] or {}
  self.trackerMetadata[className][key] = metadata
  return true
end

function RUI:GetExplicitTrackerMetadata(className, record)
  local classTable = className and self.trackerMetadata[className]
  if type(classTable) ~= "table" then return nil end
  local key = RecordKey(record)
  if key and type(classTable[key]) == "table" then return classTable[key] end
  if type(record) == "table" and type(record.name) == "string" then
    local nameKey = "name:" .. Normalize(record.name)
    if type(classTable[nameKey]) == "table" then return classTable[nameKey] end
  end
  return nil
end

-- Curated class records sometimes intentionally omit an ID. Resolve those from
-- the generated Professional Audit only when the spell name is unique inside
-- the same CoA class. Ambiguous names are never auto-linked.
local AUDIT_NAME_CACHE = {}
local function AuditForRecord(self, className, record)
  local id = tonumber(record and record.id)
  if id and self.GetAuditSpellRecordByID then
    local direct = self:GetAuditSpellRecordByID(className, id)
    if direct then return direct end
  end
  if type(className) ~= "string" or type(record) ~= "table" or not self.GetAuditSpellCatalog then return nil end
  local wanted = Normalize(record.name)
  if wanted == "" then return nil end

  local classCache = AUDIT_NAME_CACHE[className]
  if classCache == nil then
    classCache = {}
    local duplicates = {}
    for _, candidate in ipairs(self:GetAuditSpellCatalog(className) or {}) do
      local key = Normalize(candidate and candidate.name)
      if key ~= "" then
        if classCache[key] ~= nil then duplicates[key] = true else classCache[key] = candidate end
      end
    end
    for key in pairs(duplicates) do classCache[key] = false end
    AUDIT_NAME_CACHE[className] = classCache
  end

  local candidate = classCache[wanted]
  return type(candidate) == "table" and candidate or nil
end

local CATEGORY_TYPE = {
  buff = "buff", proc = "proc", debuff = "debuff", resource = "resource", summon = "summon",
  interrupt = "cooldown", interrupts = "cooldown", taunt = "cooldown", control = "cooldown",
  mobility = "cooldown", defensive = "cooldown", offensive = "cooldown", rotation = "cooldown",
  utility = "cooldown", stance = "buff", form = "buff",
}
local HIDDEN_CATEGORIES = {visual=true, hidden=true, internal=true, trigger=true}

local function AddType(list, seen, value)
  if type(value) ~= "string" or value == "" or seen[value] then return end
  seen[value] = true
  list[#list + 1] = value
end

function RUI:InferTrackerMetadata(record, className)
  if type(record) ~= "table" then return nil end
  className = className or (self.GetDetectedClass and self:GetDetectedClass())

  local explicit = self:GetExplicitTrackerMetadata(className, record) or {}
  local audit = AuditForRecord(self, className, record)
  local category = Normalize(explicit.category or record.category)
  local types, seen = {}, {}

  if type(explicit.trackingType) == "string" then AddType(types, seen, explicit.trackingType) end
  if type(explicit.trackingTypes) == "table" then for _, value in ipairs(explicit.trackingTypes) do AddType(types, seen, value) end end

  if record.trackCooldown == true or tonumber(record.cooldownHint) or record.trackCharges == true or record.interrupt == true then AddType(types, seen, "cooldown") end
  if record.trackCharges == true or tonumber(record.chargesHint) then AddType(types, seen, "charges") end
  if record.auraTracker == true or record.buff or category == "buff" or category == "proc" then AddType(types, seen, category == "proc" and "proc" or "buff") end
  if record.targetDebuff == true or category == "debuff" then AddType(types, seen, "debuff") end
  if tonumber(record.maxStacks) and tonumber(record.maxStacks) > 1 then AddType(types, seen, "stacks") end
  if category == "resource" then AddType(types, seen, "resource") end
  if category == "summon" then AddType(types, seen, "summon") end

  local effectID = tonumber(explicit.effectID or record.effectID or (audit and audit.effectID))
  local auraID = tonumber(explicit.auraID or record.auraID or (audit and audit.auraID) or effectID)
  local effectKind = explicit.effectKind or record.effectKind or (audit and audit.effectKind)
  local effectConfidence = explicit.effectConfidence or record.effectConfidence or (audit and audit.effectConfidence)

  -- Only the generator's high-confidence applied effects automatically become aura tracking.
  -- Triggered casts, transforms, teaches and summons remain relation metadata only.
  if auraID and effectConfidence == "high" then
    if effectKind == "debuff" then AddType(types, seen, "debuff")
    elseif effectKind == "buff" then AddType(types, seen, "buff") end
  end

  if #types == 0 and record.auditCatalog ~= true and CATEGORY_TYPE[category] then AddType(types, seen, CATEGORY_TYPE[category]) end

  local trackable = explicit.trackable
  if trackable == nil then trackable = #types > 0 and record.disabled ~= true and HIDDEN_CATEGORIES[category] ~= true and record.internal ~= true and record.visualOnly ~= true end

  local advanced = explicit.advanced
  if advanced == nil then
    advanced = record.review == true or record.advanced == true or record.internal == true or record.visualOnly == true
      or HIDDEN_CATEGORIES[category] == true or (record.auditCatalog == true and record.passive == true)
  end

  local recommended = explicit.recommended
  if recommended == nil then
    if record.auditCatalog == true then
      local cooldown = tonumber(record.cooldownHint) or 0
      local stacks = tonumber(record.maxStacks) or 0
      recommended = trackable == true and advanced ~= true and (
        record.interrupt == true or record.trackCharges == true or tonumber(record.chargesHint) ~= nil or stacks > 1
        or effectConfidence == "high" or category == "proc" or category == "resource" or category == "interrupt" or category == "interrupts" or cooldown >= 30
      )
    else
      recommended = trackable == true and advanced ~= true and (
        record.hudRow ~= nil or record.auraTracker == true or record.targetDebuff == true or record.trackCharges == true
        or record.interrupt == true or effectConfidence == "high" or category == "interrupt" or category == "interrupts" or category == "proc" or category == "resource"
      )
    end
  end

  local defaultUnit = explicit.defaultUnit
  if not defaultUnit then defaultUnit = (seen.debuff or record.targetDebuff == true or category == "debuff") and "target" or "player" end

  local template = explicit.template
  if not template then
    if seen.resource then template = "resource"
    elseif seen.debuff then template = "debuff"
    elseif seen.proc and seen.stacks then template = "proc_stacks"
    elseif seen.proc then template = "proc"
    elseif seen.buff and seen.stacks then template = "buff_stacks"
    elseif seen.buff and seen.cooldown then template = "cooldown_aura"
    elseif seen.buff then template = "buff"
    elseif seen.charges then template = "charges"
    elseif seen.summon then template = "summon"
    else template = "cooldown" end
  end

  return {
    schema = self.trackerMetadataVersion,
    className = className,
    spellID = tonumber(explicit.spellID or record.id or (audit and audit.id)),
    cooldownID = tonumber(explicit.cooldownID or explicit.runtimeID or record.runtimeID),
    effectID = effectID,
    auraID = auraID,
    effectKind = effectKind,
    effectConfidence = effectConfidence,
    name = explicit.name or record.name,
    auraName = explicit.auraName or record.buff or (audit and audit.effectName),
    category = explicit.category or record.category,
    specialization = explicit.specialization or record.sourceTab or record.specialization or (audit and audit.specialization),
    trackingTypes = types,
    template = template,
    defaultUnit = defaultUnit,
    trackable = trackable == true,
    recommended = recommended == true,
    advanced = advanced == true,
    maxStacks = tonumber(explicit.maxStacks or record.maxStacks or (audit and audit.maxStacks)),
    cooldownHint = tonumber(explicit.cooldownHint or record.cooldownHint or (audit and audit.cooldownHint)),
    durationHint = tonumber(explicit.durationHint or record.durationHint or (audit and audit.durationHint)),
    relatedSpellIDs = explicit.relatedSpellIDs or record.relatedSpellIDs or (audit and audit.relatedSpellIDs),
    spellEffectRelations = explicit.spellEffectRelations or record.spellEffectRelations or (audit and audit.spellEffectRelations),
    source = explicit.source or record.source or (audit and "Professional Audit schema v4"),
  }
end
