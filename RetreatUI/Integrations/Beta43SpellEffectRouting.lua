local RUI = RetreatUI
if not RUI or RUI._beta43SpellEffectRouting then return end

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local AUDIT_NAME_CACHE = {}
local function AuditFor(className, spellID, name)
  if tonumber(spellID) and type(RUI.GetAuditSpellRecordByID) == "function" then
    local direct = RUI:GetAuditSpellRecordByID(className, tonumber(spellID))
    if direct then return direct end
  end
  if type(className) ~= "string" or type(RUI.GetAuditSpellCatalog) ~= "function" then return nil end
  local wanted = Normalize(name)
  if wanted == "" then return nil end

  local classCache = AUDIT_NAME_CACHE[className]
  if classCache == nil then
    classCache = {}
    local duplicates = {}
    for _, candidate in ipairs(RUI:GetAuditSpellCatalog(className) or {}) do
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

local function Enrich(entry, className, item)
  if type(entry) ~= "table" then return entry end
  className = className or entry.className
  local suppliedSpellID = tonumber((item and item.spellID) or entry.spellID)
  local audit = AuditFor(className, suppliedSpellID, (item and item.name) or entry.name)
  local spellID = suppliedSpellID or tonumber(audit and audit.id)

  entry.spellID = spellID or entry.spellID
  entry.cooldownID = tonumber((item and item.cooldownID) or entry.cooldownID) or entry.spellID

  local confidence = (item and item.effectConfidence) or (audit and audit.effectConfidence)
  if confidence == "high" then
    entry.effectID = tonumber((item and item.effectID) or (audit and audit.effectID))
    entry.auraID = tonumber((item and item.auraID) or (audit and audit.auraID) or entry.effectID)
    entry.effectKind = (item and item.effectKind) or (audit and audit.effectKind)
    entry.effectConfidence = "high"
  end

  entry.spellEffectRelations = (item and item.spellEffectRelations) or (audit and audit.spellEffectRelations) or entry.spellEffectRelations
  entry.relatedSpellIDs = (item and item.relatedSpellIDs) or (audit and audit.relatedSpellIDs) or entry.relatedSpellIDs
  return entry
end

local BaseSaveTrackerSelection = RUI.SaveTrackerSelection
if type(BaseSaveTrackerSelection) == "function" then
  function RUI:SaveTrackerSelection(item, config)
    local ok, saved = BaseSaveTrackerSelection(self, item, config)
    if not ok then return ok, saved end
    return true, Enrich(saved, item and item.className, item)
  end
end

local function MigrateSelections()
  if type(RetreatUIDB) ~= "table" or type(RetreatUIDB.trackerBuilder) ~= "table" then return end
  local selected = RetreatUIDB.trackerBuilder.selected
  if type(selected) ~= "table" then return end

  for className, entries in pairs(selected) do
    if type(entries) == "table" then
      local moves = {}
      for oldKey, entry in pairs(entries) do
        if type(entry) == "table" then
          Enrich(entry, className, nil)
          local id = tonumber(entry.spellID)
          if id then
            local newKey = "spell:" .. tostring(id)
            entry.key = newKey
            if newKey ~= oldKey then moves[#moves + 1] = {oldKey=oldKey, newKey=newKey, entry=entry} end
          end
        end
      end
      for _, move in ipairs(moves) do
        if entries[move.newKey] == nil then entries[move.newKey] = move.entry end
        entries[move.oldKey] = nil
      end
    end
  end
end

MigrateSelections()
RUI._beta43SpellEffectRouting = true
RUI.beta43SpellEffectRoutingSchema = 2
