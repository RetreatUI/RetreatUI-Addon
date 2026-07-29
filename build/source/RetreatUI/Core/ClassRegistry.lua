local RUI = RetreatUI

-- Core owns only the registration and detection engine. Actual class metadata,
-- spell catalogues and HUD modules live in RetreatUI_Classes.
local registry = RUI.classRegistry or {}
local aliases = RUI.classAliases or {}
RUI.classRegistry = registry
RUI.classAliases = aliases

local function NormalizeKey(value)
  if type(value) ~= "string" then return nil end
  return string.lower(value):gsub("[^%a%d]", "")
end

local function RegisterAlias(alias, className)
  local key = NormalizeKey(alias)
  if key and key ~= "" then aliases[key] = className end
end

function RUI:RegisterClassDefinition(className, definition)
  if type(className) ~= "string" or className == "" or type(definition) ~= "table" then return false end
  local current = registry[className] or {}
  for key, value in pairs(definition) do current[key] = value end
  current.name = className
  registry[className] = current

  RegisterAlias(className, className)
  for _, alias in ipairs(current.aliases or {}) do RegisterAlias(alias, className) end
  return true
end

function RUI:NormalizeClassName(name)
  if type(name) ~= "string" or name == "" then return nil end
  return aliases[NormalizeKey(name)] or name
end

local function SpellbookName(index)
  if GetSpellBookItemName then
    local name = GetSpellBookItemName(index, BOOKTYPE_SPELL or "spell")
    if name then return name end
  end
  if GetSpellName then
    local name = GetSpellName(index, BOOKTYPE_SPELL or "spell")
    if name then return name end
  end
  return nil
end

local function SpellbookUpperBound()
  local total = 0
  if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
    local ok, tabs = pcall(GetNumSpellTabs)
    if ok and type(tabs) == "number" then
      for tab = 1, tabs do
        local tabOK, _, _, offset, count = pcall(GetSpellTabInfo, tab)
        if tabOK and type(offset) == "number" and type(count) == "number" then
          total = math.max(total, offset + count)
        end
      end
    end
  end
  if total > 0 then return math.min(total + 10, 1000), true end
  return 1000, false
end

function RUI:ScanSpellbook()
  local previous = self.spellbook
  local spellbook = {names={}, ids={}, indices={}, idSet={}, idIndices={}}
  local signature = {}
  local upperBound, hasExactBound = SpellbookUpperBound()
  local lastFound = 0

  for index = 1, upperBound do
    local name = SpellbookName(index)
    if not name then
      if not hasExactBound and index > math.max(300, lastFound + 50) then break end
    else
      lastFound = index
      local normalized = string.lower(name)
      spellbook.names[normalized] = true
      spellbook.indices[normalized] = index
      local spellID
      if GetSpellBookItemInfo then
        local _, itemID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL or "spell")
        spellID = tonumber(itemID)
      end
      if not spellID and GetSpellLink then
        local link = GetSpellLink(index, BOOKTYPE_SPELL or "spell")
        spellID = link and tonumber(string.match(link, "spell:(%d+)"))
      end
      if not spellID and GetSpellLink then
        local ok, link = pcall(GetSpellLink, name)
        spellID = ok and link and tonumber(string.match(link, "spell:(%d+)")) or nil
      end
      if spellID then
        spellbook.ids[normalized] = spellID
        spellbook.idSet[spellID] = true
        spellbook.idIndices[spellID] = index
      end
      signature[#signature + 1] = normalized .. ":" .. tostring(spellID or 0)
    end
  end

  spellbook.signature = table.concat(signature, "|")
  self.spellbook = spellbook
  local changed = not previous or previous.signature ~= spellbook.signature
  return spellbook, changed
end

function RUI:IsSpellLearned(name)
  if not self.spellbook then self:ScanSpellbook() end
  return self.spellbook.names[string.lower(name or "")] == true
end

function RUI:IsSpellIDLearned(spellID)
  spellID = tonumber(spellID)
  if not spellID then return false end
  if not self.spellbook then self:ScanSpellbook() end
  if self.spellbook.idSet and self.spellbook.idSet[spellID] then return true end
  if IsSpellKnown then
    local ok, known = pcall(IsSpellKnown, spellID)
    if ok and known then return true end
  end
  return false
end

function RUI:GetSpellBookIndexByID(spellID)
  spellID = tonumber(spellID)
  if not spellID then return nil end
  if not self.spellbook then self:ScanSpellbook() end
  return self.spellbook.idIndices and self.spellbook.idIndices[spellID]
end

function RUI:GetSpellID(name)
  if not self.spellbook then self:ScanSpellbook() end
  return self.spellbook.ids[string.lower(name or "")]
end

function RUI:GetSpellBookIndex(name)
  if not self.spellbook then self:ScanSpellbook() end
  return self.spellbook.indices and self.spellbook.indices[string.lower(name or "")]
end

local function DetectionMatches(self, definition)
  local spells = definition and definition.detectionSpells
  if type(spells) ~= "table" or #spells == 0 then return false end
  local required = math.max(1, tonumber(definition.detectionThreshold) or 1)
  local matched = 0
  for _, spell in ipairs(spells) do
    local found = false
    if type(spell) == "number" then
      found = self:IsSpellIDLearned(spell)
    elseif type(spell) == "string" then
      found = self:IsSpellLearned(spell)
    elseif type(spell) == "table" then
      if spell.id then found = self:IsSpellIDLearned(spell.id) end
      if not found and spell.name then found = self:IsSpellLearned(spell.name) end
    end
    if found then
      matched = matched + 1
      if matched >= required then return true end
    end
  end
  return false
end

function RUI:DetectClassFromSpellTabs()
  if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function" then return nil end
  local ok, count = pcall(GetNumSpellTabs)
  if not ok or type(count) ~= "number" then return nil end
  for index = 1, count do
    local tabOK, name = pcall(GetSpellTabInfo, index)
    if tabOK and type(name) == "string" and name ~= "" then
      local className = aliases[NormalizeKey(name)]
      if className and registry[className] then return className end
    end
  end
  return nil
end

function RUI:DetectClassFromSpellbook()
  local candidates = {}
  for className, definition in pairs(registry) do
    if definition.ready == true and type(definition.detectionSpells) == "table" then
      candidates[#candidates + 1] = {name=className, definition=definition}
    end
  end
  table.sort(candidates, function(left, right)
    local a = tonumber(left.definition.detectionPriority) or 100
    local b = tonumber(right.definition.detectionPriority) or 100
    if a ~= b then return a < b end
    return left.name < right.name
  end)
  for _, candidate in ipairs(candidates) do
    if DetectionMatches(self, candidate.definition) then return candidate.name end
  end
  return nil
end

function RUI:GetDetectedClass()
  local localized, token
  if UnitClass then localized, token = UnitClass("player") end
  local unitClassCandidates = {}
  if localized and localized ~= "" then unitClassCandidates[#unitClassCandidates + 1] = localized end
  if token and token ~= "" then unitClassCandidates[#unitClassCandidates + 1] = token end
  for _, value in ipairs(unitClassCandidates) do
    local className = self:NormalizeClassName(value)
    if className and registry[className] then return className end
  end

  local tabDetected = self:DetectClassFromSpellTabs()
  if tabDetected then return tabDetected end

  local detected = self:DetectClassFromSpellbook()
  if detected then return detected end
  return self:NormalizeClassName(localized or token) or "Unknown CoA Class"
end

function RUI:GetClassInfo(className)
  className = self:NormalizeClassName(className or self:GetDetectedClass())
  local definition = registry[className]
  if definition then
    return setmetatable({
      name = definition.name or className,
      definition = definition,
      colors = {
        accent = definition.accent,
        accent2 = definition.accent2,
        background = definition.background,
      },
    }, {__index = definition})
  end
  local fallback = {
    name=className or "Unknown CoA Class",
    theme="Conquest",
    accent={1.00,0.32,0.06},
    accent2={0.32,0.60,1.00},
    background={0.025,0.018,0.018},
    roles="Unknown",
    ready=false,
  }
  return {
    name=fallback.name,
    definition=fallback,
    colors={accent=fallback.accent, accent2=fallback.accent2, background=fallback.background},
    theme=fallback.theme, roles=fallback.roles, ready=fallback.ready,
  }
end

function RUI:GetClassModule(className)
  className = self:NormalizeClassName(className or self:GetDetectedClass())
  return self.classModules and self.classModules[className]
end

function RUI:RegisterClassModule(className, module)
  if type(className) ~= "string" or type(module) ~= "table" then return false end
  className = self:NormalizeClassName(className) or className
  module.className = className
  self.classModules[className] = module
  return true
end

function RUI:GetSupportedClassNames()
  local result = {}
  for className, definition in pairs(registry) do
    if definition.ready == true and self.classModules[className] and self.spellDatabase and self.spellDatabase[className] then
      result[#result + 1] = className
    end
  end
  table.sort(result)
  return result
end

function RUI:IsClassPackageCompatible()
  if not self.classesLoaded then return false, "RetreatUI_Classes is not loaded" end
  if tostring(self.classesVersion or "") ~= tostring(self.version or "") then
    return false, "RetreatUI and RetreatUI_Classes must use the same version"
  end
  return true
end

function RUI:IsSupportedCharacter()
  local compatible = self:IsClassPackageCompatible()
  if not compatible then return false end
  local className = self:GetDetectedClass()
  local definition = registry[className]
  local module = self.classModules and self.classModules[className]
  local database = self.spellDatabase and self.spellDatabase[className]
  return definition ~= nil and definition.ready == true and module ~= nil and module.ready ~= false and database ~= nil
end

function RUI:GetUnsupportedMessage()
  local compatible, packageMessage = self:IsClassPackageCompatible()
  if not compatible then return packageMessage .. ". Enable both bundled addon folders and reload the UI." end
  local className = self:GetDetectedClass()
  local definition = registry[className]
  if definition then
    return "RetreatUI does not have a public " .. tostring(className) .. " module yet. No profiles, settings or HUD frames were loaded on this character."
  end
  return "RetreatUI could not identify a supported Conquest of Azeroth class on this character."
end

-- Compatibility helper retained for existing Knight-specific integrations.
function RUI:IsKnightOfXoroth()
  return self:GetDetectedClass() == "Knight of Xoroth"
end

RUI._classRegistryLoaded = true
