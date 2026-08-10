local RUI = RetreatUI
if not RUI then return end

-- CoA now follows the same WeakAuras presentation contract as RetreatUI TBC:
-- General remains one shared package, while the active class exposes separate
-- top-level Resource / Main / Utility / State / Target roots. Main and Utility
-- contain one WeakAura per curated ability instead of one cloned catch-all aura.
--
-- The native HUD remains the source of truth for curation. AdvancedHUD profiles
-- capture their exact coreOrder/utilityOrder, strict flags and row limits in
-- RetreatUI_Classes/WeakAuraHUDProfiles.lua. This layer only changes rendering.

local originalBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
local originalGetWeakAuraRowStates = RUI.GetWeakAuraRowStates
local originalGetWeakAuraClassStates = RUI.GetWeakAuraClassStates
local originalInstallWeakAuraHUD = RUI.InstallWeakAuraHUD
if type(originalBuildWeakAuraHUDPackage) ~= "function"
  or type(originalGetWeakAuraRowStates) ~= "function"
  or type(originalInstallWeakAuraHUD) ~= "function"
then
  return
end

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

local function AddRacials(self, definitions)
  local result, seen = {}, {}
  for _, record in ipairs(definitions or {}) do
    result[#result + 1] = record
    local key = Normalize(record.name)
    if key ~= "" then seen[key] = true end
  end
  if self.GetRacialSpellDefinitions then
    for _, racial in ipairs(self:GetRacialSpellDefinitions(false) or {}) do
      local key = Normalize(racial.name)
      if key ~= "" and not seen[key] then
        racial.category = "racial"
        racial.hudRow = "utility"
        racial.order = tonumber(racial.order) or 900
        result[#result + 1] = racial
        seen[key] = true
      end
    end
  end
  return result
end

local function BaseDefinitions(self, className, row)
  local definitions = self.GetHUDSpellDefinitions and self:GetHUDSpellDefinitions(className, row) or {}
  if row == "utility" then definitions = AddRacials(self, definitions) end
  return definitions
end

local function ProfileFor(self, className)
  if type(self.GetWeakAuraHUDProfile) == "function" then
    local profile = self:GetWeakAuraHUDProfile(className)
    if type(profile) == "table" then return profile end
  end
  local profiles = self.weakAuraHUDProfiles
  return type(profiles) == "table" and profiles[className] or nil
end

local function CurateDefinitions(self, className, row)
  className = CurrentClass(self, className)
  local definitions = BaseDefinitions(self, className, row)
  local profile = ProfileFor(self, className)
  if type(profile) ~= "table" then return definitions end

  local preferred = row == "core" and profile.coreOrder or profile.utilityOrder
  local strict = row == "core" and profile.strictCoreOrder == true or profile.strictUtilityOrder == true
  local maximum = tonumber(row == "core" and profile.maxCore or profile.maxUtility)

  local byName, used, result = {}, {}, {}
  for _, definition in ipairs(definitions) do
    local key = Normalize(definition.name)
    if key ~= "" and not byName[key] then byName[key] = definition end
  end

  if type(preferred) == "table" and #preferred > 0 then
    for _, wanted in ipairs(preferred) do
      local definition = byName[Normalize(wanted)]
      if definition and not used[definition] then
        result[#result + 1] = definition
        used[definition] = true
      end
    end
  end

  if not strict then
    for _, definition in ipairs(definitions) do
      if not used[definition] then result[#result + 1] = definition end
    end
  end

  if type(preferred) ~= "table" or #preferred == 0 then result = definitions end
  if maximum and maximum > 0 and #result > maximum then
    local clipped = {}
    for index = 1, maximum do clipped[index] = result[index] end
    result = clipped
  end
  return result
end

function RUI:GetCuratedWeakAuraDefinitions(className, row)
  return CurateDefinitions(self, className, row)
end

-- Preserve the original snapshot logic (cooldowns, charges, buffs, glows), but
-- apply exactly the same preferred ordering/strict limits the native HUD used.
function RUI:GetWeakAuraRowStates(className, row)
  className = CurrentClass(self, className)
  local states = originalGetWeakAuraRowStates(self, className, row) or {}
  local profile = ProfileFor(self, className)
  if type(profile) ~= "table" then return states end

  local curated = CurateDefinitions(self, className, row)
  local byName = {}
  for _, state in ipairs(states) do
    local key = Normalize(state.name)
    if key ~= "" and not byName[key] then byName[key] = state end
  end

  local result = {}
  for _, definition in ipairs(curated) do
    local state = byName[Normalize(definition.name)]
    if state then
      result[#result + 1] = state
      state.index = #result
      state.key = string.format("%03d:%s", state.index, tostring(state.spellID or Normalize(state.name)))
    end
  end
  return result
end

-- Individual ability WeakAuras share a very short-lived row snapshot cache so
-- a row of 10 icons does not rescan spellbook/auras 10 times in the same frame.
local rowCache = {}
local function CachedRowStates(self, className, row)
  local now = type(GetTime) == "function" and GetTime() or 0
  local key = tostring(className) .. "\031" .. tostring(row)
  local cached = rowCache[key]
  if cached and now - cached.time < 0.025 then return cached.states end
  local states = self:GetWeakAuraRowStates(className, row) or {}
  rowCache[key] = {time=now, states=states}
  return states
end

function RUI:GetWeakAuraAbilityState(className, row, abilityName)
  className = CurrentClass(self, className)
  if className ~= CurrentClass(self) then return nil end
  local wanted = Normalize(abilityName)
  for _, state in ipairs(CachedRowStates(self, className, row)) do
    if Normalize(state.name) == wanted then return state end
  end
  return nil
end

-- Reuse StateTracker's actual grouped collector. It selects at most one state
-- per class-state group and prioritises the client's active shapeshift state,
-- eliminating the aura+shapeshift duplicate that the first WA bridge produced.
local collectorParents, collectors = {}, {}
local function CollectorFor(self, className)
  if collectors[className] then return collectors[className] end
  if type(self.CreateClassStateTracker) ~= "function" or type(CreateFrame) ~= "function" then return nil end
  local parent = CreateFrame("Frame")
  parent:Hide()
  collectorParents[className] = parent
  local tracker = self:CreateClassStateTracker(parent, className, {})
  if type(tracker) == "table" and type(tracker.Collect) == "function" then
    collectors[className] = tracker
    return tracker
  end
  return nil
end

local function StateTexture(item)
  if item.icon then return item.icon end
  local member = item.member or {}
  if member.icon then return member.icon end
  if type(GetSpellInfo) == "function" then
    local reference = tonumber(member.id) or member.name or item.name
    local _, _, texture = GetSpellInfo(reference)
    if texture then return texture end
  end
  return member.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function StateLabel(item)
  local label = item.member and item.member.label or item.name or "STATE"
  return string.upper(tostring(label or "STATE"))
end

local function BloodmageFallback(self)
  local cursed = false
  if self.IsSpellIDLearned then
    local ok, known = pcall(self.IsSpellIDLearned, self, 800157)
    cursed = ok and known == true
  end
  local name = cursed and "Cursed Form" or "Mortal Form"
  local icon = cursed and "Interface\\Icons\\Ability_Racial_Cannibalize" or "Interface\\Icons\\Spell_Shadow_LifeDrain"
  return {name=name, fullName=name, icon=icon, source="fallback"}
end

function RUI:GetWeakAuraClassStates(className)
  className = CurrentClass(self, className)
  if className ~= CurrentClass(self) then return {} end
  local tracker = CollectorFor(self, className)
  if not tracker then return originalGetWeakAuraClassStates and originalGetWeakAuraClassStates(self, className) or {} end

  local active = tracker:Collect() or {}
  if className == "Bloodmage" and #active == 0 then active = {BloodmageFallback(self)} end
  local result = {}
  for index, item in ipairs(active) do
    local duration = tonumber(item.duration) or 0
    local expirationTime = tonumber(item.expires) or 0
    local timed = duration > 0 and expirationTime > 0
    local groupKey = item.group and item.group.key or "STATE"
    result[#result + 1] = {
      show = true,
      key = string.format("%03d:%s", index, Normalize(groupKey)),
      index = index,
      name = StateLabel(item),
      fullName = item.name,
      icon = StateTexture(item),
      spellID = item.spellID,
      stacks = tonumber(item.count) and tonumber(item.count) > 1 and tonumber(item.count) or nil,
      progressType = timed and "timed" or "static",
      duration = timed and duration or nil,
      expirationTime = timed and expirationTime or nil,
      value = timed and nil or 1,
      total = timed and nil or 1,
      autoHide = false,
    }
  end
  return result
end

local function CopySnapshotCode(className, row, abilityName)
  return string.format([[
function(allstates, event, unit)
  if unit and unit ~= "player" and unit ~= "target" then return false end
  local state = allstates[""] or {}
  allstates[""] = state
  local snapshot = RetreatUI and RetreatUI.GetWeakAuraAbilityState and RetreatUI:GetWeakAuraAbilityState(%q, %q, %q) or nil
  if type(snapshot) ~= "table" or snapshot.show == false then
    if state.show then state.show = false; state.changed = true; return true end
    return false
  end
  for key in pairs(state) do
    if key ~= "changed" then state[key] = nil end
  end
  for key, value in pairs(snapshot) do state[key] = value end
  state.show = true
  state.changed = true
  return true
end
]], className, row, abilityName)
end

local function RemoveByID(list, id)
  local result = {}
  for _, item in ipairs(list or {}) do
    if type(item) ~= "table" or item.id ~= id then result[#result + 1] = item end
  end
  return result
end

local function FindByID(list, id)
  for _, item in ipairs(list or {}) do
    if type(item) == "table" and item.id == id then return item end
  end
end

local function ReplaceAbilityClone(self, packageData, className, groupID, row)
  local templateID = groupID .. " — Abilities"
  local template = FindByID(packageData.displays, templateID)
  local group = FindByID(packageData.groups, groupID) or FindByID(packageData.roots, groupID)
  if not template or not group then return false, "Missing WeakAura " .. row .. " template" end

  packageData.displays = RemoveByID(packageData.displays, templateID)
  group.controlledChildren = {}
  for _, definition in ipairs(CurateDefinitions(self, className, row)) do
    local abilityName = tostring(definition.name or definition.id or "Ability")
    local id = groupID .. " — " .. abilityName
    local display = self:DeepCopy(template)
    display.id = id
    display.uid = nil
    display.parent = groupID
    display.retreatUIAbilityName = abilityName
    display.retreatUIAbilityRow = row
    if self.GetSpellRecordTexture then display.displayIcon = self:GetSpellRecordTexture(definition) end
    local triggerSet = display.triggers and display.triggers[1]
    local trigger = triggerSet and triggerSet.trigger
    if not trigger then return false, "Missing custom trigger for " .. id end
    trigger.custom = CopySnapshotCode(className, row, abilityName)
    group.controlledChildren[#group.controlledChildren + 1] = id
    packageData.displays[#packageData.displays + 1] = display
  end
  return true
end

local function PromoteClassGroups(packageData, className)
  local oldRootID = "RetreatUI - " .. tostring(className)
  packageData.groups = RemoveByID(packageData.groups, oldRootID)
  packageData.roots = RemoveByID(packageData.roots, oldRootID)

  local roots = {}
  for _, key in ipairs({"resource", "main", "utility", "state", "target"}) do
    local id = packageData.classGroups and packageData.classGroups[key]
    local group = id and (FindByID(packageData.groups, id) or FindByID(packageData.roots, id))
    if group then
      group.parent = nil
      roots[#roots + 1] = id
    end
  end
  packageData.classRoots = roots
  -- Keep the old validator compatible while the public package model now has
  -- five actual class roots rather than an outer wrapper.
  packageData.classRoot = packageData.classGroups and packageData.classGroups.main or nil
end

function RUI:BuildWeakAuraHUDPackage(...)
  local packageData, buildError = originalBuildWeakAuraHUDPackage(self, ...)
  if type(packageData) ~= "table" then return packageData, buildError end
  local className = CurrentClass(self, packageData.className)

  local ok, err = ReplaceAbilityClone(self, packageData, className, packageData.classGroups.main, "core")
  if not ok then return nil, err end
  ok, err = ReplaceAbilityClone(self, packageData, className, packageData.classGroups.utility, "utility")
  if not ok then return nil, err end
  PromoteClassGroups(packageData, className)

  packageData.tbcParity = {
    enabled = true,
    separateClassRoots = true,
    individualAbilities = true,
    nativeCuration = true,
  }
  return packageData, buildError
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

local function DeleteChildren(id)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then return end
  local data = WeakAuras.GetData(id)
  if type(data) ~= "table" then return end
  local children = {}
  for _, childID in ipairs(data.controlledChildren or {}) do children[#children + 1] = childID end
  for _, childID in ipairs(children) do DeleteWeakAuraTree(childID) end
end

local function DetachLegacyOuterRoot(className)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" or type(WeakAuras.Delete) ~= "function" then return end
  local id = "RetreatUI - " .. tostring(className)
  local data = WeakAuras.GetData(id)
  if data then pcall(WeakAuras.Delete, data) end -- WeakAuras safely unparents children.
end

local function CleanupClassPackages(self, currentClass)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then return end
  currentClass = CurrentClass(self, currentClass)

  for className in pairs(self.classRegistry or {}) do
    className = CurrentClass(self, className)
    local outer = "RetreatUI - " .. tostring(className)
    if className ~= currentClass then
      -- beta.3-beta.6 outer package (recursive) and beta.7+ separate roots.
      if WeakAuras.GetData(outer) then DeleteWeakAuraTree(outer) end
      for _, suffix in ipairs({"Resource", "Main", "Utility", "State", "Target"}) do
        DeleteWeakAuraTree(outer .. " — " .. suffix)
      end
      local db = self:EnsureDB()
      if db.integrations and db.integrations.coaWeakAuraHUD then
        db.integrations.coaWeakAuraHUD[className] = nil
      end
    end
  end

  -- Upgrade the active beta.3-beta.6 package in place: remove only the obsolete
  -- outer wrapper, then replace Main/Utility children with individual abilities.
  DetachLegacyOuterRoot(currentClass)
  DeleteChildren("RetreatUI - " .. tostring(currentClass) .. " — Main")
  DeleteChildren("RetreatUI - " .. tostring(currentClass) .. " — Utility")
end

function RUI:InstallWeakAuraHUD(className, force)
  className = CurrentClass(self, className)
  CleanupClassPackages(self, className)
  local ok, message = originalInstallWeakAuraHUD(self, className, force)
  if ok and WeakAuras and type(WeakAuras.ScanForLoads) == "function" then pcall(WeakAuras.ScanForLoads) end
  return ok, message
end

RUI._weakAuraTBCParityLoaded = true
RUI._weakAuraTBCParityRevision = 1
