local RUI = RetreatUI
if not RUI then return end

RUI.auditSpellCatalogVersion = 2
RUI.auditSpellCatalogRaw = RUI.auditSpellCatalogRaw or {}
RUI.auditSpellCatalogCompact = RUI.auditSpellCatalogCompact or {}
RUI.auditSpellCatalogCache = RUI.auditSpellCatalogCache or {}

local CATEGORY_CODES = {U="Utility", O="Offensive", D="Defensive", I="Interrupts", X="Uncategorized"}

local function Unescape(value)
  if type(value) ~= "string" then return "" end
  return value:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\\\", "\\")
end

local function Split(line, delimiter)
  local fields, start = {}, 1
  while true do
    local pos = string.find(line, delimiter, start, true)
    if not pos then
      fields[#fields + 1] = string.sub(line, start)
      break
    end
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

local function ParseRelated(value)
  local result = {}
  if type(value) ~= "string" or value == "" then return result end
  for token in string.gmatch(value, "[^,]+") do
    local id = tonumber(token)
    if id then result[#result + 1] = id end
  end
  return result
end

local function SpellName(id)
  if type(GetSpellInfo) == "function" then
    local name = GetSpellInfo(id)
    if type(name) == "string" and name ~= "" then return name end
  end
  return "Spell " .. tostring(id)
end

function RUI:RegisterRawAuditSpellCatalog(className, raw)
  if type(className) ~= "string" or className == "" or type(raw) ~= "string" then return false end
  self.auditSpellCatalogRaw[className] = raw
  self.auditSpellCatalogCache[className] = nil
  return true
end

function RUI:RegisterCompactAuditSpellCatalog(className, specs, raw)
  if type(className) ~= "string" or className == "" or type(specs) ~= "table" or type(raw) ~= "string" then return false end
  self.auditSpellCatalogCompact[className] = {specs=specs, raw=raw}
  self.auditSpellCatalogCache[className] = nil
  return true
end

local function ParseLegacy(raw)
  local result = {}
  for line in string.gmatch(raw, "[^\r\n]+") do
    local f = Split(line, "\t")
    local id = tonumber(f[1])
    if id and f[3] and f[3] ~= "" then
      local flags = FlagSet(f[5])
      result[#result + 1] = {
        id=id, specialization=Unescape(f[2]), sourceTab=Unescape(f[2]), name=Unescape(f[3]), category=Unescape(f[4]),
        auditCatalog=true, auditFlags=f[5] or "", cooldownHint=tonumber(f[6]), durationHint=tonumber(f[7]),
        chargesHint=tonumber(f[8]), rechargeHint=tonumber(f[9]), maxStacks=tonumber(f[10]), relatedSpellIDs=ParseRelated(f[11]),
        trackCooldown=flags.C or flags.H or nil, trackCharges=flags.H or nil, interrupt=flags.I or nil,
        passive=flags.P or nil, advanced=flags.A or nil,
      }
    end
  end
  return result
end

local function ParseCompact(container)
  local result = {}
  local specs = container.specs or {}
  for line in string.gmatch(container.raw or "", "[^\r\n]+") do
    local f = Split(line, "|")
    local id = tonumber(f[1])
    if id then
      local flags = FlagSet(f[4])
      local specialization = specs[tonumber(f[2]) or 0] or "Class-wide / Shared"
      result[#result + 1] = {
        id=id, specialization=specialization, sourceTab=specialization, name=SpellName(id), category=CATEGORY_CODES[f[3]] or "Uncategorized",
        auditCatalog=true, auditFlags=f[4] or "", cooldownHint=tonumber(f[5]), durationHint=tonumber(f[6]),
        chargesHint=tonumber(f[7]), rechargeHint=tonumber(f[8]), maxStacks=tonumber(f[9]), relatedSpellIDs=ParseRelated(f[10]),
        trackCooldown=flags.C or flags.H or nil, trackCharges=flags.H or nil, interrupt=flags.I or nil,
        passive=flags.P or nil, advanced=flags.A or nil,
      }
    end
  end
  return result
end

function RUI:GetAuditSpellCatalog(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return {} end
  if self.auditSpellCatalogCache[className] then return self.auditSpellCatalogCache[className] end

  local result
  local compact = self.auditSpellCatalogCompact[className]
  if type(compact) == "table" and type(compact.raw) == "string" and compact.raw ~= "" then
    result = ParseCompact(compact)
  else
    local raw = self.auditSpellCatalogRaw[className]
    result = type(raw) == "string" and raw ~= "" and ParseLegacy(raw) or {}
  end

  self.auditSpellCatalogCache[className] = result
  return result
end
