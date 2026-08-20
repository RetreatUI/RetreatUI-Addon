local RUI = RetreatUI
if not RUI then return end

RUI.auditSpellCatalogVersion = 4
RUI.auditSpellCatalogRaw = RUI.auditSpellCatalogRaw or {}
RUI.auditSpellCatalogCompact = RUI.auditSpellCatalogCompact or {}
RUI.auditSpellCatalogCache = RUI.auditSpellCatalogCache or {}
RUI.auditSpellCatalogByID = RUI.auditSpellCatalogByID or {}

local CATEGORY_CODES = {U="Utility", O="Offensive", D="Defensive", I="Interrupts", X="Uncategorized"}
local EFFECT_KIND_CODES = {A="aura", B="buff", D="debuff"}

local function Unescape(value)
  if type(value) ~= "string" then return "" end
  return value:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\\\", "\\")
end

local function Split(line, delimiter)
  local fields, start = {}, 1
  while true do
    local pos = string.find(line, delimiter, start, true)
    if not pos then fields[#fields + 1] = string.sub(line, start); break end
    fields[#fields + 1] = string.sub(line, start, pos - 1)
    start = pos + #delimiter
  end
  return fields
end

local function FlagSet(flags)
  local result = {}
  for index = 1, #(flags or "") do result[string.sub(flags, index, index)] = true end
  return result
end

local function SpellName(id)
  if type(GetSpellInfo) == "function" then
    local name = GetSpellInfo(id)
    if type(name) == "string" and name ~= "" then return name end
  end
  return "Spell " .. tostring(id)
end

local function ParseRelated(value)
  local result = {}
  if type(value) ~= "string" or value == "" then return result end
  for token in string.gmatch(value, "[^,]+") do local id = tonumber(token); if id then result[#result + 1] = id end end
  return result
end

local function ParseRelations(value)
  local relations, ids = {}, {}
  if type(value) ~= "string" or value == "" then return relations, ids end
  for token in string.gmatch(value, "[^,]+") do
    local f = Split(token, ":")
    local id = tonumber(f[1])
    if id then
      ids[#ids + 1] = id
      relations[#relations + 1] = {
        spellID=id,
        relation=f[2] or "X",
        confidence=f[3] == "H" and "high" or (f[3] == "M" and "medium" or "review"),
        sourceSpellID=tonumber(f[4]),
      }
    end
  end
  return relations, ids
end

local function ParseSparseExtras(value)
  local result = {spellEffectRelations={}, relatedSpellIDs={}}
  if type(value) ~= "string" or value == "" then return result end
  for token in string.gmatch(value, "[^;]+") do
    local prefix, body = string.sub(token, 1, 1), string.sub(token, 2)
    if prefix == "c" then result.cooldownHint = tonumber(body)
    elseif prefix == "d" then result.durationHint = tonumber(body)
    elseif prefix == "h" then result.chargesHint = tonumber(body)
    elseif prefix == "r" then result.rechargeHint = tonumber(body)
    elseif prefix == "s" then result.maxStacks = tonumber(body)
    elseif prefix == "e" then
      local id, kind = string.match(body, "^(%d+)([ABD])$")
      id = tonumber(id)
      if id then
        result.effectID=id; result.auraID=id; result.effectKind=EFFECT_KIND_CODES[kind] or "aura"; result.effectConfidence="high"
      end
    elseif prefix == "l" then
      result.spellEffectRelations, result.relatedSpellIDs = ParseRelations(body)
    end
  end
  return result
end

local function BlockedAutomaticEffect(record)
  local effectID = tonumber(record and record.effectID)
  if not effectID then return false end
  for _, relation in ipairs(record.spellEffectRelations or {}) do
    if tonumber(relation.spellID) == effectID then
      local kind = relation.relation
      if kind == "T" or kind == "E" or kind == "S" then return true end
    end
  end
  return false
end

local function ApplyEffectSafety(record)
  if BlockedAutomaticEffect(record) then
    record.effectID=nil; record.auraID=nil; record.effectKind=nil; record.effectConfidence=nil
  end
  return record
end

function RUI:RegisterRawAuditSpellCatalog(className, raw)
  if type(className) ~= "string" or className == "" or type(raw) ~= "string" then return false end
  self.auditSpellCatalogRaw[className]=raw; self.auditSpellCatalogCache[className]=nil; self.auditSpellCatalogByID[className]=nil
  return true
end

function RUI:RegisterCompactAuditSpellCatalog(className, specs, raw)
  if type(className) ~= "string" or className == "" or type(specs) ~= "table" or type(raw) ~= "string" then return false end
  self.auditSpellCatalogCompact[className]={specs=specs,chunks={raw}}; self.auditSpellCatalogCache[className]=nil; self.auditSpellCatalogByID[className]=nil
  return true
end

function RUI:RegisterCompactAuditSpellCatalogChunk(className, specs, raw)
  if type(className) ~= "string" or className == "" or type(specs) ~= "table" or type(raw) ~= "string" then return false end
  local container=self.auditSpellCatalogCompact[className]
  if type(container) ~= "table" then container={specs=specs,chunks={}}; self.auditSpellCatalogCompact[className]=container end
  if type(container.specs) ~= "table" or #container.specs == 0 then container.specs=specs end
  container.chunks=container.chunks or {}; container.chunks[#container.chunks + 1]=raw
  self.auditSpellCatalogCache[className]=nil; self.auditSpellCatalogByID[className]=nil
  return true
end

local function ParseLegacy(raw)
  local result={}
  for line in string.gmatch(raw, "[^\r\n]+") do
    local f=Split(line,"\t"); local id=tonumber(f[1])
    if id and f[3] and f[3] ~= "" then
      local flags=FlagSet(f[5])
      result[#result+1]={
        id=id,specialization=Unescape(f[2]),sourceTab=Unescape(f[2]),name=Unescape(f[3]),category=Unescape(f[4]),
        auditCatalog=true,auditFlags=f[5] or "",cooldownHint=tonumber(f[6]),durationHint=tonumber(f[7]),chargesHint=tonumber(f[8]),
        rechargeHint=tonumber(f[9]),maxStacks=tonumber(f[10]),relatedSpellIDs=ParseRelated(f[11]),
        trackCooldown=flags.C or flags.H or nil,trackCharges=flags.H or nil,interrupt=flags.I or nil,passive=flags.P or nil,advanced=flags.A or nil,
      }
    end
  end
  return result
end

local function ParseCompact(container)
  local result={}; local specs=container.specs or {}; local chunks=container.chunks or (container.raw and {container.raw}) or {}
  for _,raw in ipairs(chunks) do
    for line in string.gmatch(raw or "", "[^\r\n]+") do
      local f=Split(line,"|"); local id=tonumber(f[1])
      if id then
        local flags=FlagSet(f[4]); local specialization=specs[tonumber(f[2]) or 0] or "Class-wide / Shared"
        local record={
          id=id,specialization=specialization,sourceTab=specialization,name=SpellName(id),category=CATEGORY_CODES[f[3]] or "Uncategorized",
          auditCatalog=true,auditFlags=f[4] or "",trackCooldown=flags.C or flags.H or nil,trackCharges=flags.H or nil,
          interrupt=flags.I or nil,passive=flags.P or nil,advanced=flags.A or nil,
        }
        if f[5] and string.find(f[5], "[cdrhsel]", 1) then
          local extras=ParseSparseExtras(f[5]); for key,value in pairs(extras) do record[key]=value end
          ApplyEffectSafety(record)
        else
          record.cooldownHint=tonumber(f[5]); record.durationHint=tonumber(f[6]); record.chargesHint=tonumber(f[7])
          record.rechargeHint=tonumber(f[8]); record.maxStacks=tonumber(f[9]); record.relatedSpellIDs=ParseRelated(f[10])
        end
        result[#result+1]=record
      end
    end
  end
  return result
end

function RUI:GetAuditSpellCatalog(className)
  className=className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return {} end
  if self.auditSpellCatalogCache[className] then return self.auditSpellCatalogCache[className] end
  local compact=self.auditSpellCatalogCompact[className]; local result
  if type(compact) == "table" then result=ParseCompact(compact)
  else local raw=self.auditSpellCatalogRaw[className]; result=type(raw)=="string" and raw~="" and ParseLegacy(raw) or {} end
  local byID={}; for _,record in ipairs(result) do if tonumber(record.id) and byID[tonumber(record.id)] == nil then byID[tonumber(record.id)]=record end end
  self.auditSpellCatalogByID[className]=byID; self.auditSpellCatalogCache[className]=result
  return result
end

function RUI:GetAuditSpellRecordByID(className, spellID)
  className=className or (self.GetDetectedClass and self:GetDetectedClass()); spellID=tonumber(spellID)
  if not className or not spellID then return nil end
  if not self.auditSpellCatalogByID[className] then self:GetAuditSpellCatalog(className) end
  return self.auditSpellCatalogByID[className] and self.auditSpellCatalogByID[className][spellID] or nil
end
