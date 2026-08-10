local RUI = RetreatUI
if not RUI then return end

-- RetreatUI's CoA combat HUD is rendered by WeakAuras. This file remains the
-- authoritative runtime/data bridge: class databases decide *what* is tracked,
-- while WeakAuras owns the visible regions.
RUI.weakAuraHUDMode = true
RUI.weakAuraResourceReady = false

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function Now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function CurrentClass(self, className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  return className
end

local function ClassMatches(self, className)
  return CurrentClass(self, className) == CurrentClass(self)
end

local function OwnCaster(caster)
  if caster == nil or caster == "" then return nil end
  if caster == "player" or caster == "pet" or caster == "vehicle" then return true end
  local playerName = UnitName and UnitName("player")
  if playerName and caster == playerName then return true end
  return false
end

local function ReadAuras(unit, harmful)
  local getter = harmful and UnitDebuff or UnitBuff
  local state = { list = {}, byID = {}, byName = {} }
  if type(getter) ~= "function" then return state end
  if unit ~= "player" and UnitExists and not UnitExists(unit) then return state end

  for index = 1, 40 do
    local values = { getter(unit, index) }
    local name = values[1]
    if not name then break end
    local aura = {
      name = name,
      icon = values[3],
      count = tonumber(values[4]) or 0,
      duration = tonumber(values[6]) or 0,
      expires = tonumber(values[7]) or 0,
      caster = values[8],
      spellID = tonumber(values[11]),
      index = index,
      raw = values,
    }
    state.list[#state.list + 1] = aura
    state.byName[Normalize(name)] = aura
    if aura.spellID then state.byID[aura.spellID] = aura end
  end
  return state
end

local function AddReferenceName(set, value)
  local key = Normalize(value)
  if key ~= "" then set[key] = true end
end

local function RecordReferences(record)
  local names, ids = {}, {}
  if type(record) ~= "table" then return names, ids end
  AddReferenceName(names, record.name)
  AddReferenceName(names, record.buff)
  AddReferenceName(names, record.debuff)
  for _, alias in ipairs(record.aliases or {}) do AddReferenceName(names, alias) end
  for _, value in ipairs({ record.id, record.auraID, record.spellID }) do
    value = tonumber(value)
    if value then ids[value] = true end
  end
  return names, ids
end

local function FindAuraForRecord(auraState, record, allowAnyCaster)
  if type(auraState) ~= "table" or type(record) ~= "table" then return nil end
  local names, ids = RecordReferences(record)
  for _, aura in ipairs(auraState.list or {}) do
    local matched = (aura.spellID and ids[aura.spellID]) or names[Normalize(aura.name)]
    if matched then
      local own = OwnCaster(aura.caster)
      if allowAnyCaster or own ~= false then return aura end
    end
  end
  return nil
end

local function SpellTexture(self, record, fallbackName, fallbackID)
  if type(record) == "table" and self.GetSpellRecordTexture then
    local texture = self:GetSpellRecordTexture(record)
    if texture then return texture end
  end
  if type(GetSpellInfo) == "function" then
    local _, _, texture
    if fallbackName and fallbackName ~= "" then
      _, _, texture = GetSpellInfo(fallbackName)
      if texture then return texture end
    end
    if tonumber(fallbackID) then
      _, _, texture = GetSpellInfo(tonumber(fallbackID))
      if texture then return texture end
    end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ReadCooldown(self, record)
  if type(GetSpellCooldown) ~= "function" or type(record) ~= "table" then return 0, 0, 0 end
  local candidates, seen = {}, {}
  local function Add(value, book)
    if value == nil then return end
    local key = tostring(value) .. (book and ":book" or "")
    if seen[key] then return end
    seen[key] = true
    candidates[#candidates + 1] = { value = value, book = book }
  end

  local bookIndex = self.GetSpellRecordBookIndex and self:GetSpellRecordBookIndex(record)
  if bookIndex then Add(bookIndex, true) end
  if self.GetSpellRecordRuntimeID then Add(self:GetSpellRecordRuntimeID(record), false) end
  Add(record.name, false)
  Add(record.id, false)
  for _, alias in ipairs(record.aliases or {}) do Add(alias, false) end

  for _, candidate in ipairs(candidates) do
    local ok, start, duration, enabled
    if candidate.book then
      ok, start, duration, enabled = pcall(GetSpellCooldown, candidate.value, BOOKTYPE_SPELL or "spell")
    else
      ok, start, duration, enabled = pcall(GetSpellCooldown, candidate.value)
    end
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end
  return 0, 0, 0
end

local function ReadCharges(self, record)
  if type(GetSpellCharges) ~= "function" or type(record) ~= "table" then return nil end
  local candidates, seen = {}, {}
  local function Add(value)
    if value == nil then return end
    local key = tostring(value)
    if key == "" or seen[key] then return end
    seen[key] = true
    candidates[#candidates + 1] = value
  end
  if self.GetSpellRecordRuntimeID then Add(self:GetSpellRecordRuntimeID(record)) end
  Add(record.id)
  Add(record.name)
  for _, alias in ipairs(record.aliases or {}) do Add(alias) end

  for _, candidate in ipairs(candidates) do
    local ok, current, maximum, start, duration = pcall(GetSpellCharges, candidate)
    current, maximum = tonumber(current), tonumber(maximum)
    if ok and current and maximum and maximum > 0 then
      return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
    end
  end
  return nil
end

local function FormatAmount(value)
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 1000 then return string.format("%.1fk", value / 1000) end
  return tostring(math.floor(value + 0.5))
end

local function AuraAbsorb(aura)
  if not aura then return nil end
  if type(UnitGetTotalAbsorbs) == "function" then
    local ok, value = pcall(UnitGetTotalAbsorbs, "player")
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
  end
  for index = 12, #(aura.raw or {}) do
    local value = aura.raw[index]
    if type(value) == "number" and value > 1 and value < 1000000000 then return value end
  end
  return nil
end

local function SpellUsable(self, record)
  if type(IsUsableSpell) ~= "function" or type(record) ~= "table" then return false end
  local candidates = {}
  if self.GetSpellRecordRuntimeID then candidates[#candidates + 1] = self:GetSpellRecordRuntimeID(record) end
  candidates[#candidates + 1] = record.id
  candidates[#candidates + 1] = record.name
  for _, alias in ipairs(record.aliases or {}) do candidates[#candidates + 1] = alias end
  for _, candidate in ipairs(candidates) do
    if candidate ~= nil then
      local ok, usable = pcall(IsUsableSpell, candidate)
      if ok and usable then return true end
    end
  end
  return false
end

local function GlowAura(record, playerAuras)
  local wanted = record and (record.glowWhenAura or record.glowWhenAuraID)
  if wanted == nil then return nil end
  if type(wanted) ~= "table" then wanted = { wanted } end
  for _, value in ipairs(wanted) do
    if type(value) == "number" then
      local aura = playerAuras.byID and playerAuras.byID[value]
      if aura then return aura end
    else
      local aura = playerAuras.byName and playerAuras.byName[Normalize(value)]
      if aura then return aura end
    end
  end
  return nil
end

local function SpellSnapshot(self, className, record, playerAuras)
  if type(record) ~= "table" then return nil end
  if self.ShouldShowSpellRecord and not self:ShouldShowSpellRecord(record) then return nil end
  if self.IsSpellRecordCastable and not self:IsSpellRecordCastable(record) then return nil end

  local runtimeID = self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record) or tonumber(record.id)
  local name = record.name or (runtimeID and GetSpellInfo and GetSpellInfo(runtimeID)) or "Ability"
  local snapshot = {
    show = true,
    key = tostring(runtimeID or Normalize(name)),
    name = name,
    icon = SpellTexture(self, record, name, runtimeID),
    spellID = runtimeID or tonumber(record.id),
    progressType = "static",
    value = 1,
    total = 1,
    stacks = nil,
    glow = false,
  }

  local activeBuff
  if record.buff or record.trackDuration or record.trackAbsorb then
    activeBuff = FindAuraForRecord(playerAuras, record, true)
  end

  if record.trackCharges then
    local current, maximum, start, duration = ReadCharges(self, record)
    if current and maximum then
      snapshot.stacks = current
      if current < maximum and duration and duration > 0 and start and start > 0 then
        snapshot.progressType = "timed"
        snapshot.duration = duration
        snapshot.expirationTime = start + duration
        snapshot.autoHide = false
      end
    end
  end

  if snapshot.progressType ~= "timed" then
    local start, duration, enabled = ReadCooldown(self, record)
    local remaining = duration > 0 and math.max(0, start + duration - Now()) or 0
    if enabled ~= 0 and duration > 1.5 and remaining > 0.05 then
      snapshot.progressType = "timed"
      snapshot.duration = duration
      snapshot.expirationTime = start + duration
      snapshot.autoHide = false
    end
  end

  if record.trackDuration and activeBuff and activeBuff.duration > 0 and activeBuff.expires > Now() then
    snapshot.progressType = "timed"
    snapshot.duration = activeBuff.duration
    snapshot.expirationTime = activeBuff.expires
    snapshot.autoHide = false
    if activeBuff.count and activeBuff.count > 1 then snapshot.stacks = activeBuff.count end
  end

  if record.trackAbsorb and activeBuff then
    snapshot.stacks = FormatAmount(AuraAbsorb(activeBuff)) or snapshot.stacks
  end

  if GlowAura(record, playerAuras) then snapshot.glow = true end
  if record.glowWhenUsable == true and SpellUsable(self, record) then snapshot.glow = true end
  return snapshot
end

function RUI:GetWeakAuraRowStates(className, row)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return {} end
  local definitions = {}
  for _, record in ipairs(self:GetHUDSpellDefinitions(className, row) or {}) do definitions[#definitions + 1] = record end

  if row == "utility" and self.GetRacialSpellDefinitions then
    local seen = {}
    for _, record in ipairs(definitions) do seen[Normalize(record.name)] = true end
    for _, racial in ipairs(self:GetRacialSpellDefinitions(false) or {}) do
      local key = Normalize(racial.name)
      if key ~= "" and not seen[key] then
        racial.category = "racial"
        racial.hudRow = "utility"
        racial.order = tonumber(racial.order) or 900
        definitions[#definitions + 1] = racial
        seen[key] = true
      end
    end
    table.sort(definitions, function(a, b)
      local ao, bo = tonumber(a.order) or 9999, tonumber(b.order) or 9999
      if ao ~= bo then return ao < bo end
      return tostring(a.name or "") < tostring(b.name or "")
    end)
  end

  local playerAuras = ReadAuras("player", false)
  local result = {}
  for _, record in ipairs(definitions) do
    local snapshot = SpellSnapshot(self, className, record, playerAuras)
    if snapshot then
      snapshot.index = #result + 1
      snapshot.key = string.format("%03d:%s", snapshot.index, snapshot.key or Normalize(snapshot.name))
      result[#result + 1] = snapshot
    end
  end
  return result
end

local function NativeResourceExclusions(self, className)
  local database = self:GetClassSpellDatabase(className) or {}
  local config = database.nativeResource or {}
  local names, ids = {}, {}
  for _, value in ipairs(config.auraNames or {}) do AddReferenceName(names, value) end
  AddReferenceName(names, config.title)
  for _, value in ipairs(config.auraIDs or config.spellIDs or {}) do
    value = tonumber(value)
    if value then ids[value] = true end
  end
  if tonumber(config.spellID) then ids[tonumber(config.spellID)] = true end
  return names, ids
end

function RUI:GetWeakAuraProcStates(className)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return {} end
  local playerAuras = ReadAuras("player", false)
  local byName, byID = {}, {}
  local resourceNames, resourceIDs = NativeResourceExclusions(self, className)

  for _, definition in ipairs(self:GetAuraTrackerDefinitions(className) or {}) do
    local isState = self.IsClassStateAuraDefinition and self:IsClassStateAuraDefinition(className, definition)
    local names, ids = RecordReferences(definition)
    local resource = false
    for name in pairs(names) do if resourceNames[name] then resource = true end end
    for id in pairs(ids) do if resourceIDs[id] then resource = true end end
    if not isState and not resource then
      for name in pairs(names) do byName[name] = definition end
      for id in pairs(ids) do byID[id] = definition end
    end
  end

  local result, seen = {}, {}
  for _, aura in ipairs(playerAuras.list) do
    local nameKey = Normalize(aura.name)
    local definition = (aura.spellID and byID[aura.spellID]) or byName[nameKey]
    local isState = self.IsClassStateName and self:IsClassStateName(className, aura.name)
    local isResource = resourceNames[nameKey] or (aura.spellID and resourceIDs[aura.spellID])
    local own = OwnCaster(aura.caster)
    local genericProc = own ~= false and aura.duration > 0 and aura.duration <= 60
    if not isState and not isResource and (definition or genericProc) then
      local unique = aura.spellID and ("id:" .. tostring(aura.spellID)) or ("name:" .. nameKey)
      if not seen[unique] then
        seen[unique] = true
        result[#result + 1] = {
          show = true,
          key = unique,
          name = aura.name,
          icon = aura.icon or SpellTexture(self, definition, aura.name, aura.spellID),
          spellID = aura.spellID,
          stacks = aura.count and aura.count > 1 and aura.count or nil,
          duration = aura.duration > 0 and aura.duration or nil,
          expirationTime = aura.expires > 0 and aura.expires or nil,
          progressType = aura.duration > 0 and aura.expires > 0 and "timed" or "static",
          value = aura.duration > 0 and nil or 1,
          total = aura.duration > 0 and nil or 1,
          autoHide = false,
          order = definition and tonumber(definition.order) or 2000,
        }
      end
    end
  end

  table.sort(result, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  for index, state in ipairs(result) do
    state.index = index
    state.key = string.format("%03d:%s", index, state.key)
  end
  return result
end

local function BuildTargetLookup(self, className)
  local byName, byID, curated = {}, {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    local names, ids = RecordReferences(record)
    for name in pairs(names) do byName[name] = byName[name] or record end
    for id in pairs(ids) do byID[id] = byID[id] or record end
    if record.targetDebuff == true then curated[record] = true end
  end
  return byName, byID, curated
end

function RUI:GetWeakAuraTargetStates(className)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return {} end
  if UnitExists and not UnitExists("target") then return {} end
  local targetAuras = ReadAuras("target", true)
  local byName, byID, curated = BuildTargetLookup(self, className)
  local result, seen = {}, {}

  for _, aura in ipairs(targetAuras.list) do
    local definition = (aura.spellID and byID[aura.spellID]) or byName[Normalize(aura.name)]
    local own = OwnCaster(aura.caster)
    local accepted = own == true or (aura.caster == nil and definition ~= nil)
    if accepted then
      local unique = aura.spellID and ("id:" .. tostring(aura.spellID)) or ("name:" .. Normalize(aura.name))
      if not seen[unique] then
        seen[unique] = true
        result[#result + 1] = {
          show = true,
          key = unique,
          name = aura.name,
          icon = aura.icon or SpellTexture(self, definition, aura.name, aura.spellID),
          spellID = aura.spellID,
          stacks = aura.count and aura.count > 1 and aura.count or nil,
          duration = aura.duration > 0 and aura.duration or nil,
          expirationTime = aura.expires > 0 and aura.expires or nil,
          progressType = aura.duration > 0 and aura.expires > 0 and "timed" or "static",
          value = aura.duration > 0 and nil or 1,
          total = aura.duration > 0 and nil or 1,
          autoHide = false,
          order = definition and tonumber(definition.order) or 900,
          curated = definition and curated[definition] or false,
        }
      end
    end
  end

  table.sort(result, function(a, b)
    if a.curated ~= b.curated then return a.curated end
    if a.order ~= b.order then return a.order < b.order end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  for index, state in ipairs(result) do
    state.index = index
    state.key = string.format("%03d:%s", index, state.key)
  end
  return result
end

local function ShortStateLabel(name)
  local label = tostring(name or "STATE")
  for _, pattern in ipairs({
    "^[Vv][Oo][Ww]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+",
    "^[Vv][Oo][Ww]%s+[Oo][Ff]%s+",
    "^[Aa][Ss][Pp][Ee][Cc][Tt]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+",
    "^[Aa][Ss][Pp][Ee][Cc][Tt]%s+[Oo][Ff]%s+",
    "^[Pp][Rr][Ee][Ss][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+",
    "^[Pp][Rr][Ee][Ss][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+",
    "^[Pp][Ee][Ss][Tt][Ii][Ll][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+",
    "^[Oo][Aa][Tt][Hh]%s*:%s*",
    "^[Oo][Aa][Tt][Hh]%s+[Oo][Ff]%s+",
    "^[Ff][Oo][Rr][Mm]%s*:%s*",
    "^[Mm][Oo][Dd][Ee]%s*:%s*",
    "^[Aa][Uu][Gg][Mm][Ee][Nn][Tt][Aa][Tt][Ii][Oo][Nn]%s*:%s*",
    "^[Aa][Tt][Tt][Uu][Nn][Ee][Mm][Ee][Nn][Tt]%s*:%s*",
  }) do label = label:gsub(pattern, "") end
  return string.upper(label)
end

function RUI:GetWeakAuraClassStates(className)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return {} end
  local result, seen = {}, {}
  local playerAuras = ReadAuras("player", false)

  if self.IsClassStateName then
    for _, aura in ipairs(playerAuras.list) do
      if self:IsClassStateName(className, aura.name) then
        local unique = aura.spellID and ("id:" .. tostring(aura.spellID)) or ("name:" .. Normalize(aura.name))
        if not seen[unique] then
          seen[unique] = true
          result[#result + 1] = {
            show = true, key = unique, name = ShortStateLabel(aura.name), fullName = aura.name,
            icon = aura.icon, spellID = aura.spellID,
            stacks = aura.count and aura.count > 1 and aura.count or nil,
            duration = aura.duration > 0 and aura.duration or nil,
            expirationTime = aura.expires > 0 and aura.expires or nil,
            progressType = aura.duration > 0 and aura.expires > 0 and "timed" or "static",
            value = aura.duration > 0 and nil or 1, total = aura.duration > 0 and nil or 1,
            autoHide = false,
          }
        end
      end
    end
  end

  if type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function" then
    local ok, count = pcall(GetNumShapeshiftForms)
    count = ok and tonumber(count) or 0
    local current = type(GetShapeshiftForm) == "function" and tonumber(GetShapeshiftForm()) or 0
    for index = 1, count do
      local success, texture, name, active = pcall(GetShapeshiftFormInfo, index)
      if success and name and (active == true or active == 1 or index == current)
        and self.IsClassStateName and self:IsClassStateName(className, name) then
        local unique = "form:" .. Normalize(name)
        if not seen[unique] then
          seen[unique] = true
          result[#result + 1] = {
            show = true, key = unique, name = ShortStateLabel(name), fullName = name,
            icon = texture, progressType = "static", value = 1, total = 1,
          }
        end
      end
    end
  end

  table.sort(result, function(a, b) return tostring(a.fullName or a.name) < tostring(b.fullName or b.name) end)
  for index, state in ipairs(result) do state.index = index; state.key = string.format("%03d:%s", index, state.key) end
  return result
end

function RUI:GetWeakAuraPrimaryPowerState(className, wantedToken)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return nil end
  local token = self.GetPrimaryResourceToken and self:GetPrimaryResourceToken() or nil
  token = string.upper(tostring(token or "MANA")):gsub("[^A-Z]", "")
  wantedToken = string.upper(tostring(wantedToken or token)):gsub("[^A-Z]", "")
  if token ~= wantedToken then return nil end

  local powerType = self.GetPowerTypeForToken and self:GetPowerTypeForToken(token) or nil
  if powerType == nil and UnitPowerType then
    local ok, value = pcall(UnitPowerType, "player")
    if ok then powerType = tonumber(value) end
  end
  powerType = tonumber(powerType) or 0

  local current, maximum
  if UnitPower and UnitPowerMax then
    local ok1, value1 = pcall(UnitPower, "player", powerType)
    local ok2, value2 = pcall(UnitPowerMax, "player", powerType)
    if ok1 then current = tonumber(value1) end
    if ok2 then maximum = tonumber(value2) end
  end
  if not maximum or maximum <= 0 then
    if UnitMana then local ok, value = pcall(UnitMana, "player"); if ok then current = tonumber(value) end end
    if UnitManaMax then local ok, value = pcall(UnitManaMax, "player"); if ok then maximum = tonumber(value) end end
  end
  current = math.max(0, tonumber(current) or 0)
  maximum = math.max(1, tonumber(maximum) or 100)
  if current > maximum then current = maximum end
  return {
    show = true, key = token, name = token,
    progressType = "static", value = current, total = maximum,
    current = current, maximum = maximum,
  }
end

local resourceReadyClass
local function MarkResourceReady(self, className)
  self.weakAuraResourceReady = true
  resourceReadyClass = className
  if type(self.ScheduleNativeClassResourceCleanup) == "function" then
    self:After(0.05, function() self:ScheduleNativeClassResourceCleanup(false) end)
  end
end

local function NativeResourceMode(config, maximum)
  local mode = Normalize(config and config.mode)
  if mode == "segments" then return "segments" end
  if mode == "bar" then return "bar" end
  if maximum and maximum <= 12 and maximum == math.floor(maximum) then return "segments" end
  return "bar"
end

function RUI:GetWeakAuraNativeResourceState(className, forceDiscovery)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return nil end
  local database = self:GetClassSpellDatabase(className) or {}
  local config = database.nativeResource
  if type(config) ~= "table" then
    if resourceReadyClass ~= className then MarkResourceReady(self, className) end
    return nil
  end

  local snapshot = self.ReadAscensionResourceSnapshot
    and self:ReadAscensionResourceSnapshot(config.keywords, config.title, forceDiscovery == true)
    or nil
  if not snapshot then return nil end
  MarkResourceReady(self, className)
  local current = math.max(0, tonumber(snapshot.current) or 0)
  local maximum = math.max(1, tonumber(snapshot.maximum) or 1)
  return {
    show = true,
    key = "native",
    name = snapshot.label or config.title or "CLASS RESOURCE",
    icon = snapshot.icon or config.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
    current = current,
    maximum = maximum,
    mode = NativeResourceMode(config, maximum),
    progressType = "static",
    value = current,
    total = maximum,
  }
end

function RUI:GetWeakAuraNativeResourceSegments(className)
  local snapshot = self:GetWeakAuraNativeResourceState(className, false)
  if not snapshot or snapshot.mode ~= "segments" then return {} end
  local result = {}
  local maximum = math.min(12, math.max(0, math.floor(snapshot.maximum + 0.5)))
  local current = math.max(0, math.floor(snapshot.current + 0.5))
  for index = 1, maximum do
    result[#result + 1] = {
      show = true,
      key = string.format("%02d", index),
      name = snapshot.name,
      icon = snapshot.icon,
      progressType = "static",
      value = index <= current and 1 or 0,
      total = 1,
      index = index,
    }
  end
  return result
end

local impExpires = {}
local impDriver

local function SweepImps()
  local now = Now()
  local count = 0
  for guid, expires in pairs(impExpires) do
    if expires <= now then impExpires[guid] = nil else count = count + 1 end
  end
  return count
end

local function EnsureImpDriver()
  if impDriver or not CreateFrame then return end
  impDriver = CreateFrame("Frame", "RetreatUIWeakAuraImpRuntime")
  impDriver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  impDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
  impDriver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then SweepImps(); return end
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if subevent == "SPELL_SUMMON" and sourceGUID == UnitGUID("player") then
      local destination = Normalize(destName)
      local spell = Normalize(spellName)
      if destination:find("hellfire imp", 1, true) or spell:find("hellfire imp", 1, true) or spell:find("impcaller", 1, true) then
        impExpires[destGUID or (tostring(spellID) .. ":" .. tostring(Now()))] = Now() + 60
      end
    elseif (subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "SPELL_INSTAKILL") and destGUID then
      impExpires[destGUID] = nil
    end
  end)
end
EnsureImpDriver()

local function ExplicitResourceRecord(self, className, key)
  key = Normalize(key)
  for _, record in ipairs(self:GetClassResourceRecords(className) or {}) do
    if Normalize(record.key) == key or Normalize(record.name) == key then return record end
  end
  return nil
end

function RUI:GetWeakAuraExplicitResourceState(className, key)
  className = CurrentClass(self, className)
  if not ClassMatches(self, className) then return nil end
  local record = ExplicitResourceRecord(self, className, key)
  if not record or record.type == "primary" then return nil end
  local current, maximum = 0, tonumber(record.max) or tonumber(record.maximum)

  if record.type == "summon" and (Normalize(record.name):find("hellfire imp", 1, true) or Normalize(record.key):find("hellfireimp", 1, true)) then
    current = SweepImps()
  else
    local auras = ReadAuras("player", false)
    local wanted = Normalize(record.name)
    for _, aura in ipairs(auras.list) do
      local lower = Normalize(aura.name)
      if lower == wanted or lower:find(wanted, 1, true) then
        current = current + ((aura.count and aura.count > 0) and aura.count or 1)
      end
    end
  end

  if maximum and current > maximum then current = maximum end
  return {
    show = true,
    key = tostring(record.key or record.name),
    name = record.name or record.key or "Resource",
    icon = SpellTexture(self, nil, record.name, record.id),
    current = current,
    maximum = maximum,
    stacks = current,
    progressType = "static",
    value = maximum and current or 1,
    total = maximum or 1,
    recordType = record.type,
  }
end

function RUI:GetWeakAuraExplicitResourceSegments(className, key)
  local snapshot = self:GetWeakAuraExplicitResourceState(className, key)
  if not snapshot or not snapshot.maximum or snapshot.maximum > 12 then return {} end
  local result = {}
  for index = 1, snapshot.maximum do
    result[#result + 1] = {
      show = true, key = string.format("%02d", index), name = snapshot.name, icon = snapshot.icon,
      progressType = "static", value = index <= snapshot.current and 1 or 0, total = 1, index = index,
    }
  end
  return result
end

function RUI:PrimeWeakAuraResourceSource(className)
  className = CurrentClass(self, className)
  self.weakAuraResourceReady = false
  resourceReadyClass = nil
  local database = self:GetClassSpellDatabase(className) or {}
  if type(database.nativeResource) ~= "table" then
    MarkResourceReady(self, className)
    return true
  end
  local snapshot = self:GetWeakAuraNativeResourceState(className, true)
  return snapshot ~= nil
end

function RUI:GetWeakAuraTrinketState(slot)
  slot = tonumber(slot)
  if slot ~= 13 and slot ~= 14 then return nil end
  local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
  if not texture then return nil end
  local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
  local name = itemID and GetItemInfo and GetItemInfo(itemID) or nil
  local start, duration, enabled = 0, 0, 0
  if GetInventoryItemCooldown then
    local ok, a, b, c = pcall(GetInventoryItemCooldown, "player", slot)
    if ok then start, duration, enabled = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0 end
  end
  local state = {
    show = true, key = tostring(slot), name = name or ("Trinket " .. tostring(slot)), icon = texture,
    itemID = itemID, progressType = "static", value = 1, total = 1,
  }
  if enabled ~= 0 and duration > 1.5 and start > 0 and start + duration > Now() then
    state.progressType = "timed"
    state.duration = duration
    state.expirationTime = start + duration
    state.autoHide = false
  end
  return state
end

RUI._weakAuraHUDRuntimeLoaded = true
RUI._weakAuraHUDRuntimeRevision = 1
