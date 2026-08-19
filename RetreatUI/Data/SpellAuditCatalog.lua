local RUI = RetreatUI
if not RUI then return end

RUI.auditSpellCatalogVersion = 1
RUI.auditSpellCatalogRaw = RUI.auditSpellCatalogRaw or {}
RUI.auditSpellCatalogCache = RUI.auditSpellCatalogCache or {}

local function Unescape(value)
  if type(value) ~= "string" then return "" end
  return value:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\\\", "\\")
end

local function SplitTabs(line)
  local fields, start = {}, 1
  while true do
    local pos = string.find(line, "\t", start, true)
    if not pos then
      fields[#fields + 1] = string.sub(line, start)
      break
    end
    fields[#fields + 1] = string.sub(line, start, pos - 1)
    start = pos + 1
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

function RUI:RegisterRawAuditSpellCatalog(className, raw)
  if type(className) ~= "string" or className == "" or type(raw) ~= "string" then return false end
  self.auditSpellCatalogRaw[className] = raw
  self.auditSpellCatalogCache[className] = nil
  return true
end

function RUI:GetAuditSpellCatalog(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return {} end
  if self.auditSpellCatalogCache[className] then return self.auditSpellCatalogCache[className] end

  local raw = self.auditSpellCatalogRaw[className]
  if type(raw) ~= "string" or raw == "" then return {} end

  local result = {}
  for line in string.gmatch(raw, "[^\r\n]+") do
    local f = SplitTabs(line)
    local id = tonumber(f[1])
    if id and f[3] and f[3] ~= "" then
      local flags = FlagSet(f[5])
      result[#result + 1] = {
        id = id,
        specialization = Unescape(f[2]),
        sourceTab = Unescape(f[2]),
        name = Unescape(f[3]),
        category = Unescape(f[4]),
        auditCatalog = true,
        auditFlags = f[5] or "",
        cooldownHint = tonumber(f[6]),
        durationHint = tonumber(f[7]),
        chargesHint = tonumber(f[8]),
        rechargeHint = tonumber(f[9]),
        maxStacks = tonumber(f[10]),
        relatedSpellIDs = ParseRelated(f[11]),
        trackCooldown = flags.C or flags.H or nil,
        trackCharges = flags.H or nil,
        interrupt = flags.I or nil,
        passive = flags.P or nil,
        advanced = flags.A or nil,
      }
    end
  end
  self.auditSpellCatalogCache[className] = result
  return result
end
