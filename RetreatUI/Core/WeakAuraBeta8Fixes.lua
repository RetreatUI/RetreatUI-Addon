local RUI = RetreatUI
if not RUI then return end

-- beta.8 hardening for the CoA -> WeakAuras renderer migration.
-- Keep the class databases / old HUD curation authoritative, but stop using
-- tooltip scraping inside live WA triggers and only generate resource displays
-- that can actually be active for the current class.

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function CurrentClass(self, className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  return className
end

local CORE_CATEGORIES = {rotation=true, offensive=true, summon=true, resource=true}
local UTILITY_CATEGORIES = {
  interrupt=true, taunt=true, control=true, mobility=true, defensive=true,
  utility=true, stance=true, form=true, ally=true, racial=true,
}

local function DesiredRow(record)
  if type(record) ~= "table" then return nil end
  if record.forceMain == true then return "core" end
  if record.forceUtility == true then return "utility" end
  local explicit = Normalize(record.hudRow)
  if explicit == "core" or explicit == "main" then return "core" end
  if explicit == "utility" then return "utility" end
  local category = Normalize(record.category)
  if CORE_CATEGORIES[category] then return "core" end
  if UTILITY_CATEGORIES[category] then return "utility" end
  return nil
end

local function TrackableWithoutTooltip(record)
  if type(record) ~= "table" or record.trackHUD == false then return false end
  if record.forceHUD == true or record.forceMain == true or record.forceUtility == true then return true end
  if record.trackCharges == true or record.trackCooldown == true or record.trackDuration == true then return true end
  return (tonumber(record.cooldownHint) or 0) > 1.5
end

local function Sorted(records)
  table.sort(records, function(a, b)
    local ao, bo = tonumber(a.order) or 9999, tonumber(b.order) or 9999
    if ao ~= bo then return ao < bo end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return records
end

-- Do not scrape GameTooltip from a WA trigger. Ascension's GameTooltipMods can
-- expose a nil line while SetSpellBookItem/SetHyperlink is still building the
-- tooltip, which is exactly the GameTooltipMods.lua:109 crash reported live.
-- Curated CoA data already contains the cooldown/row intent we need here.
function RUI:GetHUDSpellDefinitions(className, row)
  className = CurrentClass(self, className)
  local result, seen = {}, {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    local isClassState = record.showStateActivationOnHUD ~= true
      and type(self.IsClassStateName) == "function"
      and self:IsClassStateName(className, record.buff or record.name)
    if not isClassState
      and DesiredRow(record) == row
      and TrackableWithoutTooltip(record)
      and (not self.ShouldShowSpellRecord or self:ShouldShowSpellRecord(record))
    then
      local key = Normalize(record.name or tostring(record.id or ""))
      if key ~= "" and not seen[key] then
        seen[key] = true
        result[#result + 1] = record
      end
    end
  end
  return Sorted(result)
end

-- Bloodmage used a custom native HUD instead of RegisterAdvancedClassHUD, so it
-- did not automatically contribute a TBC-style curation profile in beta.7.
-- Freeze the same compact rows here instead of falling back to every database
-- cooldown that happens to be learned.
RUI.weakAuraHUDProfiles = RUI.weakAuraHUDProfiles or {}
RUI.weakAuraHUDProfiles.Bloodmage = RUI.weakAuraHUDProfiles.Bloodmage or {
  coreOrder = {
    "Rotclaw", "Animated Blood", "Night Hunter's Howl", "Monstrous Howl",
    "Eternal Resolve", "Blood Tap", "Blood Curse",
  },
  strictCoreOrder = true,
  maxCore = 7,
  utilityOrder = {
    "Lunge", "Bare Fangs", "Blood Howl", "Blood Pact", "Liquify",
    "Apotheosis", "Hemostasis", "Blood Veil", "Transfusion", "Shadow Howl",
    "Fleshcraft", "Scarlet Delirium", "Blood Feast",
  },
  strictUtilityOrder = true,
  maxUtility = 13,
  maxProcs = 8,
}

local function FindSpellRecord(self, className, wantedName)
  local wanted = Normalize(wantedName)
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    if Normalize(record.name) == wanted then return record end
  end
end

local function BloodBondTarget()
  if type(UnitBuff) ~= "function" then return nil end
  local units = {"player", "party1", "party2", "party3", "party4"}
  if type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0 then
    units = {}
    for index = 1, math.min(40, GetNumRaidMembers() or 0) do units[#units + 1] = "raid" .. index end
  end
  for _, unit in ipairs(units) do
    if not UnitExists or UnitExists(unit) then
      for index = 1, 40 do
        local name, _, icon, count, _, duration, expires, caster, _, _, spellID = UnitBuff(unit, index)
        if not name then break end
        if Normalize(name) == "blood bond" and (caster == "player" or caster == nil) then
          return unit, {
            name=name, icon=icon, count=tonumber(count) or 0, duration=tonumber(duration) or 0,
            expires=tonumber(expires) or 0, caster=caster, spellID=tonumber(spellID),
          }
        end
      end
    end
  end
end

local originalExplicitResourceState = RUI.GetWeakAuraExplicitResourceState
if type(originalExplicitResourceState) == "function" then
  function RUI:GetWeakAuraExplicitResourceState(className, key)
    className = CurrentClass(self, className)
    if className == "Bloodmage" and Normalize(key) == "bloodbond" then
      local record = FindSpellRecord(self, className, "Blood Bond")
      if record and self.IsSpellRecordLearned then
        local ok, learned = pcall(self.IsSpellRecordLearned, self, record)
        if ok and learned == false then return nil end
      end
      local unit, aura = BloodBondTarget()
      local icon
      if record and self.GetSpellRecordTexture then icon = self:GetSpellRecordTexture(record) end
      if not icon and aura then icon = aura.icon end
      if not icon and type(GetSpellInfo) == "function" then
        local runtimeID = record and self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record)
        local _, _, texture = GetSpellInfo(runtimeID or "Blood Bond")
        icon = texture
      end
      -- Never put a question-mark placeholder into the middle HUD lane.
      if not icon then icon = "Interface\\Icons\\Spell_Shadow_LifeDrain" end
      local displayName = "BLOOD BOND"
      if unit and UnitName then displayName = UnitName(unit) or displayName end
      return {
        show = true,
        key = "bloodBond",
        name = displayName,
        icon = icon,
        spellID = aura and aura.spellID or nil,
        stacks = nil,
        current = unit and 1 or 0,
        maximum = 1,
        progressType = "static",
        value = unit and 1 or 0,
        total = 1,
        recordType = "ally",
      }
    end
    return originalExplicitResourceState(self, className, key)
  end
end

local function FindByID(list, id)
  for _, item in ipairs(list or {}) do
    if type(item) == "table" and item.id == id then return item end
  end
end

local function FilterList(list, removed)
  local result = {}
  for _, item in ipairs(list or {}) do
    if type(item) ~= "table" or not removed[item.id] then result[#result + 1] = item end
  end
  return result
end

local POWER_TOKENS = {"MANA", "RAGE", "FOCUS", "ENERGY", "RUNICPOWER", "FURY"}
local function PrimaryToken(self)
  local token = self.GetPrimaryResourceToken and self:GetPrimaryResourceToken() or "MANA"
  token = string.upper(tostring(token or "MANA")):gsub("[^A-Z]", "")
  if token == "RUNIC" or token == "RUNICPOWER" then return "RUNICPOWER" end
  for _, value in ipairs(POWER_TOKENS) do if token == value then return value end end
  return "MANA"
end

local function NativeMode(config)
  if type(config) ~= "table" then return nil end
  local mode = Normalize(config.mode)
  if mode == "segments" or mode == "bar" then return mode end
  local allSmall, saw = true, false
  for _, maximum in pairs(config.maxByName or {}) do
    maximum = tonumber(maximum)
    if maximum then
      saw = true
      if maximum > 12 or maximum ~= math.floor(maximum) then allSmall = false end
    end
  end
  if saw and allSmall then return "segments" end
  return "bar"
end

local function PruneResourcePackage(self, packageData, className)
  local resourceID = packageData.classGroups and packageData.classGroups.resource
  if not resourceID then return end
  local removed = {}
  local wantedPrimary = PrimaryToken(self)

  for _, token in ipairs(POWER_TOKENS) do
    if token ~= wantedPrimary then removed[resourceID .. " — " .. token] = true end
  end

  local database = self:GetClassSpellDatabase(className) or {}
  local mode = NativeMode(database.nativeResource)
  local nativeBarID = resourceID .. " — Secondary Bar"
  local nativeSegmentsID = resourceID .. " — Secondary Segments"
  local nativeSegmentAuraID = nativeSegmentsID .. " — Segment"
  if not mode then
    removed[nativeBarID] = true
    removed[nativeSegmentsID] = true
    removed[nativeSegmentAuraID] = true
  elseif mode == "segments" then
    removed[nativeBarID] = true
  else
    removed[nativeSegmentsID] = true
    removed[nativeSegmentAuraID] = true
  end

  packageData.displays = FilterList(packageData.displays, removed)
  packageData.groups = FilterList(packageData.groups, removed)
  packageData.roots = FilterList(packageData.roots, removed)
  for _, collection in ipairs({packageData.groups, packageData.roots}) do
    for _, group in ipairs(collection or {}) do
      if type(group) == "table" and type(group.controlledChildren) == "table" then
        local children = {}
        for _, childID in ipairs(group.controlledChildren) do
          if not removed[childID] then children[#children + 1] = childID end
        end
        group.controlledChildren = children
      end
    end
  end
end

local function FixStatePlacement(packageData)
  local stateID = packageData.classGroups and packageData.classGroups.state
  local state = stateID and (FindByID(packageData.groups, stateID) or FindByID(packageData.roots, stateID))
  if not state then return end
  state.anchorFrameType = "SELECTFRAME"
  state.anchorFrameFrame = "ElvUF_Player"
  state.anchorPoint = "TOPRIGHT"
  state.selfPoint = "BOTTOMRIGHT"
  state.xOffset = -17
  state.yOffset = 1
  state.grow = "HORIZONTAL"
  state.align = "RIGHT"
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    className = CurrentClass(self, packageData.className or className)
    PruneResourcePackage(self, packageData, className)
    FixStatePlacement(packageData)
    packageData.beta8Cleanup = {
      tooltipFreeCuration = true,
      exactResources = true,
      stateAnchor = {frame="ElvUF_Player", selfPoint="BOTTOMRIGHT", anchorPoint="TOPRIGHT", x=-17, y=1},
    }
    return packageData, buildError
  end
end

local function DeleteWeakAuraTree(id)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" or type(WeakAuras.Delete) ~= "function" then return end
  local data = WeakAuras.GetData(id)
  if type(data) ~= "table" then return end
  local children = {}
  for _, childID in ipairs(data.controlledChildren or {}) do children[#children + 1] = childID end
  for _, childID in ipairs(children) do DeleteWeakAuraTree(childID) end
  data = WeakAuras.GetData(id)
  if data then pcall(WeakAuras.Delete, data) end
end

local function DeleteResourceChildren(className)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then return end
  local resourceID = "RetreatUI - " .. tostring(className) .. " — Resource"
  local data = WeakAuras.GetData(resourceID)
  if type(data) ~= "table" then return end
  local children = {}
  for _, childID in ipairs(data.controlledChildren or {}) do children[#children + 1] = childID end
  for _, childID in ipairs(children) do DeleteWeakAuraTree(childID) end
end

local previousInstallWeakAuraHUD = RUI.InstallWeakAuraHUD
if type(previousInstallWeakAuraHUD) == "function" then
  function RUI:InstallWeakAuraHUD(className, force)
    className = CurrentClass(self, className)
    DeleteResourceChildren(className)
    return previousInstallWeakAuraHUD(self, className, force)
  end
end

-- General WeakAuras own trinkets now; do not expose the retired native trinket
-- HUD as a separate installer component.
if type(RUI.moduleOrder) == "table" then
  for index = #RUI.moduleOrder, 1, -1 do
    if RUI.moduleOrder[index] == "trinketHUD" then table.remove(RUI.moduleOrder, index) end
  end
end
local classInstaller = RUI.moduleInstallers and RUI.moduleInstallers.classHUD
if classInstaller then
  classInstaller.label = "WeakAuras HUD"
  classInstaller.description = "General Trinkets/Buffs/Procs plus the active class Resource, Main, Utility, State and Target trackers."
end

RUI._weakAuraBeta8FixesLoaded = true
RUI._weakAuraBeta8FixesRevision = 1
