local RUI = RetreatUI
if not RUI or RUI._beta43SpellEffectRouting then return end

local function AuditFor(className, spellID)
  if type(RUI.GetAuditSpellRecordByID) ~= "function" then return nil end
  return RUI:GetAuditSpellRecordByID(className, tonumber(spellID))
end

local function Enrich(entry, className, item)
  if type(entry) ~= "table" then return entry end
  className = className or entry.className
  local spellID = tonumber((item and item.spellID) or entry.spellID)
  local audit = AuditFor(className, spellID)

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
      for _, entry in pairs(entries) do Enrich(entry, className, nil) end
    end
  end
end

MigrateSelections()
RUI._beta43SpellEffectRouting = true
RUI.beta43SpellEffectRoutingSchema = 1
