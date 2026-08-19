local RUI = RetreatUI
if not RUI then return end

RUI.trackerMetadataVersion = 1
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
  local category = Normalize(explicit.category or record.category)
  local types, seen = {}, {}

  if type(explicit.trackingType) == "string" then AddType(types, seen, explicit.trackingType) end
  if type(explicit.trackingTypes) == "table" then
    for _, value in ipairs(explicit.trackingTypes) do AddType(types, seen, value) end
  end

  if record.trackCooldown == true or tonumber(record.cooldownHint) or record.trackCharges == true or record.interrupt == true then
    AddType(types, seen, "cooldown")
  end
  if record.trackCharges == true or tonumber(record.chargesHint) then AddType(types, seen, "charges") end
  if record.auraTracker == true or record.buff or category == "buff" or category == "proc" then
    AddType(types, seen, category == "proc" and "proc" or "buff")
  end
  if record.targetDebuff == true or category == "debuff" then AddType(types, seen, "debuff") end
  if tonumber(record.maxStacks) and tonumber(record.maxStacks) > 1 then AddType(types, seen, "stacks") end
  if category == "resource" then AddType(types, seen, "resource") end
  if category == "summon" then AddType(types, seen, "summon") end

  -- Curated records may use category alone as an intentional default. Raw audit
  -- categories are broad and must not turn thousands of passives into cooldown trackers.
  if #types == 0 and record.auditCatalog ~= true and CATEGORY_TYPE[category] then
    AddType(types, seen, CATEGORY_TYPE[category])
  end

  -- A passive audit entry that explicitly references another spell is a useful
  -- proc/aura candidate, but it stays Advanced until it has a curated override.
  if record.auditCatalog == true and record.passive == true and type(record.relatedSpellIDs) == "table" and #record.relatedSpellIDs > 0 then
    AddType(types, seen, "proc")
    if tonumber(record.maxStacks) and tonumber(record.maxStacks) > 1 then AddType(types, seen, "stacks") end
  end

  local trackable = explicit.trackable
  if trackable == nil then
    trackable = #types > 0 and record.disabled ~= true and HIDDEN_CATEGORIES[category] ~= true and record.internal ~= true and record.visualOnly ~= true
  end

  local advanced = explicit.advanced
  if advanced == nil then
    advanced = record.review == true or record.advanced == true or record.internal == true or record.visualOnly == true
      or HIDDEN_CATEGORIES[category] == true or (record.auditCatalog == true and record.passive == true)
  end

  local recommended = explicit.recommended
  if recommended == nil then
    if record.auditCatalog == true then
      -- Raw audit categories such as Offensive/Defensive are intentionally not
      -- enough on their own. Recommended should be a small, high-signal list.
      local cooldown = tonumber(record.cooldownHint) or 0
      local stacks = tonumber(record.maxStacks) or 0
      local related = type(record.relatedSpellIDs) == "table" and #record.relatedSpellIDs > 0
      recommended = trackable == true and advanced ~= true and (
        record.interrupt == true or record.trackCharges == true or tonumber(record.chargesHint) ~= nil
        or stacks > 1 or category == "proc" or category == "resource" or category == "interrupt" or category == "interrupts"
        or cooldown >= 30 or (related and tonumber(record.durationHint) ~= nil)
      )
    else
      recommended = trackable == true and advanced ~= true and (
        record.hudRow ~= nil or record.auraTracker == true or record.targetDebuff == true or record.trackCharges == true
        or record.interrupt == true or category == "interrupt" or category == "interrupts"
        or category == "proc" or category == "resource"
      )
    end
  end

  local defaultUnit = explicit.defaultUnit
  if not defaultUnit then defaultUnit = (record.targetDebuff == true or category == "debuff") and "target" or "player" end

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
    spellID = tonumber(explicit.spellID or record.id),
    auraID = tonumber(explicit.auraID or record.auraID),
    name = explicit.name or record.name,
    auraName = explicit.auraName or record.buff,
    category = explicit.category or record.category,
    specialization = explicit.specialization or record.sourceTab or record.specialization,
    trackingTypes = types,
    template = template,
    defaultUnit = defaultUnit,
    trackable = trackable == true,
    recommended = recommended == true,
    advanced = advanced == true,
    maxStacks = tonumber(explicit.maxStacks or record.maxStacks),
    cooldownHint = tonumber(explicit.cooldownHint or record.cooldownHint),
    durationHint = tonumber(explicit.durationHint or record.durationHint),
    relatedSpellIDs = explicit.relatedSpellIDs or record.relatedSpellIDs,
    source = explicit.source or record.source,
  }
end
