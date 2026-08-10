local RUI = RetreatUI
if not RUI then return end

-- beta.10: one global class-state lane centered directly above the primary
-- resource bar, plus race abilities owned by RetreatUI - General.
--
-- beta.9 used X=-188 to protect the widest secondary-resource footprint. That
-- put the state group outside the 360px center HUD lane and into the player-frame
-- area. The global rule is now deliberately simple: screen center X=0 / Y=-121.
-- The resource bar spans X=-180..180 and its top edge is Y=-144, so 38px state
-- icons centered at Y=-121 sit 4px above it and remain inside the center gap.

local GENERAL_ROOT = "RetreatUI - General"
local GENERAL_PROCS = GENERAL_ROOT .. " — Buffs & Procs"
local GENERAL_RACIALS = GENERAL_ROOT .. " — Racials"
local GENERAL_RACIAL_AURA = GENERAL_RACIALS .. " — Active Racials"
local STATE_X, STATE_Y = 0, -121
local RACIAL_X, RACIAL_Y = -83, 1
local RACIAL_EVENTS = "PLAYER_ENTERING_WORLD SPELLS_CHANGED PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED ACTIVE_TALENT_GROUP_CHANGED ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED ASCENSION_KNOWN_ENTRIES_UPDATED SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE UNIT_AURA"

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

local function FindByID(list, id)
  for _, item in ipairs(list or {}) do
    if type(item) == "table" and item.id == id then return item end
  end
end

local function HasChild(group, id)
  if type(group) ~= "table" then return false end
  for _, childID in ipairs(group.controlledChildren or {}) do
    if childID == id then return true end
  end
  return false
end

local function AddChild(group, id)
  if type(group) ~= "table" then return end
  group.controlledChildren = group.controlledChildren or {}
  if not HasChild(group, id) then group.controlledChildren[#group.controlledChildren + 1] = id end
end

local function RacialNameSet(self)
  local result = {}
  if type(self.GetRacialSpellDefinitions) == "function" then
    for _, racial in ipairs(self:GetRacialSpellDefinitions(false) or {}) do
      local key = Normalize(racial.name)
      if key ~= "" then result[key] = true end
    end
  end
  return result
end

local function ReadRacialAura(record)
  if type(UnitBuff) ~= "function" then return nil end
  local wantedName = Normalize(record and record.name)
  local wantedID = tonumber(record and (record.id or record.spellID))
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local spellID = tonumber(values[11])
    if (wantedID and spellID == wantedID) or (wantedName ~= "" and Normalize(name) == wantedName) then
      return {
        name = name,
        icon = values[3],
        count = tonumber(values[4]) or 0,
        duration = tonumber(values[6]) or 0,
        expires = tonumber(values[7]) or 0,
        spellID = spellID,
      }
    end
  end
end

local function RacialTexture(record)
  if type(GetSpellInfo) ~= "function" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  local reference = tonumber(record and (record.id or record.spellID)) or (record and record.name)
  local _, _, texture = GetSpellInfo(reference)
  return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function RacialCooldown(record)
  if type(GetSpellCooldown) ~= "function" then return 0, 0, 0 end
  local book = BOOKTYPE_SPELL or "spell"
  if record and record.bookIndex then
    local ok, start, duration, enabled = pcall(GetSpellCooldown, record.bookIndex, book)
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end
  for _, reference in ipairs({record and record.id, record and record.spellID, record and record.name}) do
    if reference ~= nil then
      local ok, start, duration, enabled = pcall(GetSpellCooldown, reference)
      if ok and start ~= nil and duration ~= nil then
        return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
      end
    end
  end
  return 0, 0, 0
end

local function RacialCharges(record)
  if type(GetSpellCharges) ~= "function" then return nil end
  for _, reference in ipairs({record and record.id, record and record.spellID, record and record.name}) do
    if reference ~= nil then
      local ok, current, maximum, start, duration = pcall(GetSpellCharges, reference)
      current, maximum = tonumber(current), tonumber(maximum)
      if ok and current and maximum and maximum > 0 then
        return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
      end
    end
  end
end

function RUI:GetWeakAuraRacialStates()
  local result = {}
  if type(self.GetRacialSpellDefinitions) ~= "function" then return result end
  local now = type(GetTime) == "function" and GetTime() or 0

  for _, record in ipairs(self:GetRacialSpellDefinitions(false) or {}) do
    local name = tostring(record.name or "Racial")
    local spellID = tonumber(record.id or record.spellID)
    local aura = ReadRacialAura(record)
    local state = {
      show = true,
      key = "racial:" .. tostring(spellID or Normalize(name)),
      name = name,
      icon = (aura and aura.icon) or RacialTexture(record),
      spellID = spellID,
      stacks = nil,
      -- WeakAuras 5.21.2 / Ascension icon safety: an otherwise-static icon is
      -- represented as a zero-duration timed state so Icon:PreShow never sees
      -- a duration with a nil expirationTime.
      progressType = "timed",
      duration = 0,
      expirationTime = 0,
      autoHide = false,
    }

    local current, maximum, chargeStart, chargeDuration = RacialCharges(record)
    if current and maximum then
      state.stacks = current
      if current < maximum and chargeDuration > 0 and chargeStart > 0 then
        state.duration = chargeDuration
        state.expirationTime = chargeStart + chargeDuration
      end
    end

    if state.duration == 0 then
      local start, duration, enabled = RacialCooldown(record)
      local remaining = duration > 0 and math.max(0, start + duration - now) or 0
      if enabled ~= 0 and duration > 1.5 and remaining > 0.05 then
        state.duration = duration
        state.expirationTime = start + duration
      end
    end

    if aura and aura.duration > 0 and aura.expires > now then
      state.duration = aura.duration
      state.expirationTime = aura.expires
      if aura.count and aura.count > 1 then state.stacks = aura.count end
    end

    state.index = #result + 1
    state.key = string.format("%03d:%s", state.index, state.key)
    result[#result + 1] = state
  end
  return result
end

local function ApplyGlobalStateLane(packageData)
  local stateID = packageData.classGroups and packageData.classGroups.state
  local state = stateID and (FindByID(packageData.groups, stateID) or FindByID(packageData.roots, stateID))
  if not state then return end
  state.anchorFrameType = "SCREEN"
  state.anchorFrameFrame = nil
  state.anchorPoint = "CENTER"
  state.selfPoint = "CENTER"
  state.xOffset = STATE_X
  state.yOffset = STATE_Y
  state.grow = "HORIZONTAL"
  state.align = "CENTER"
end

local function RemoveClassRacialDisplays(self, packageData)
  local names = RacialNameSet(self)
  local utilityID = packageData.classGroups and packageData.classGroups.utility
  local utility = utilityID and (FindByID(packageData.groups, utilityID) or FindByID(packageData.roots, utilityID))
  if not utility or not next(names) then return end

  local removedIDs = {}
  local kept = {}
  for _, display in ipairs(packageData.displays or {}) do
    local abilityName = type(display) == "table" and display.retreatUIAbilityName or nil
    if display.parent == utilityID and abilityName and names[Normalize(abilityName)] then
      removedIDs[display.id] = true
    else
      kept[#kept + 1] = display
    end
  end
  packageData.displays = kept

  local children = {}
  for _, childID in ipairs(utility.controlledChildren or {}) do
    if not removedIDs[childID] then children[#children + 1] = childID end
  end
  utility.controlledChildren = children
end

local function AddGeneralRacials(self, packageData)
  local general = FindByID(packageData.groups, GENERAL_ROOT) or FindByID(packageData.roots, GENERAL_ROOT)
  local procGroup = FindByID(packageData.groups, GENERAL_PROCS) or FindByID(packageData.roots, GENERAL_PROCS)
  local procDisplay = FindByID(packageData.displays, GENERAL_PROCS .. " — Active Buffs & Procs")
  if not general or not procGroup or not procDisplay then return false end

  local racialGroup = self:DeepCopy(procGroup)
  racialGroup.id = GENERAL_RACIALS
  racialGroup.uid = nil
  racialGroup.parent = GENERAL_ROOT
  racialGroup.controlledChildren = {GENERAL_RACIAL_AURA}
  racialGroup.anchorFrameType = "SELECTFRAME"
  racialGroup.anchorFrameFrame = "ElvUF_Player"
  racialGroup.anchorPoint = "TOPRIGHT"
  racialGroup.selfPoint = "BOTTOMRIGHT"
  racialGroup.xOffset = RACIAL_X
  racialGroup.yOffset = RACIAL_Y
  racialGroup.grow = "HORIZONTAL"
  racialGroup.align = "RIGHT"
  racialGroup.space = 3
  racialGroup.rowSpace = 3
  racialGroup.columnSpace = 3

  local racialDisplay = self:DeepCopy(procDisplay)
  racialDisplay.id = GENERAL_RACIAL_AURA
  racialDisplay.uid = nil
  racialDisplay.parent = GENERAL_RACIALS
  racialDisplay.displayIcon = 134400
  local triggerSet = racialDisplay.triggers and racialDisplay.triggers[1]
  local trigger = triggerSet and triggerSet.trigger
  if not trigger or type(trigger.custom) ~= "string" then return false end
  trigger.custom = trigger.custom:gsub("GetWeakAuraProcStates", "GetWeakAuraRacialStates")
  trigger.events = RACIAL_EVENTS

  AddChild(general, GENERAL_RACIALS)
  packageData.groups[#packageData.groups + 1] = racialGroup
  packageData.roots[#packageData.roots + 1] = racialGroup
  packageData.displays[#packageData.displays + 1] = racialDisplay
  packageData.expected = packageData.expected or {}
  packageData.expected.racials = GENERAL_RACIALS
  packageData.expected.racialX = RACIAL_X
  packageData.expected.racialY = RACIAL_Y
  return true
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    ApplyGlobalStateLane(packageData)
    RemoveClassRacialDisplays(self, packageData)
    if not AddGeneralRacials(self, packageData) then
      return nil, "General Racials WeakAura group could not be built"
    end
    packageData.beta10Cleanup = {
      globalStateLane = {frame="SCREEN", x=STATE_X, y=STATE_Y, iconSize=38, align="CENTER"},
      racialsInGeneral = true,
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

local previousInstallWeakAuraHUD = RUI.InstallWeakAuraHUD
if type(previousInstallWeakAuraHUD) == "function" then
  function RUI:InstallWeakAuraHUD(className, force)
    -- Clear any stale General racial child from another character/race before
    -- rebuilding the shared General package.
    DeleteWeakAuraTree(GENERAL_RACIALS)
    return previousInstallWeakAuraHUD(self, className, force)
  end
end

local previousValidateWeakAuraHUD = RUI.ValidateWeakAuraHUD
if type(previousValidateWeakAuraHUD) == "function" then
  function RUI:ValidateWeakAuraHUD(className, packageData)
    packageData = packageData or self:BuildWeakAuraHUDPackage(className)
    local ok, message = previousValidateWeakAuraHUD(self, className, packageData)
    if not ok then return false, message end

    local stateID = packageData and packageData.classGroups and packageData.classGroups.state
    local state = stateID and WeakAuras and WeakAuras.GetData and WeakAuras.GetData(stateID)
    if not state or state.anchorFrameType ~= "SCREEN"
      or state.anchorPoint ~= "CENTER" or state.selfPoint ~= "CENTER"
      or math.abs((tonumber(state.xOffset) or 999) - STATE_X) > 0.01
      or math.abs((tonumber(state.yOffset) or 999) - STATE_Y) > 0.01
      or state.align ~= "CENTER" then
      return false, "Class State WeakAura is not on the global center lane"
    end

    local racials = WeakAuras and WeakAuras.GetData and WeakAuras.GetData(GENERAL_RACIALS)
    if not racials or racials.parent ~= GENERAL_ROOT then
      return false, "General Racials WeakAura group is missing"
    end
    return true, tostring(CurrentClass(self, className)) .. " WeakAura HUD verified"
  end
end

RUI._weakAuraBeta10FixesLoaded = true
RUI._weakAuraBeta10FixesRevision = 1
