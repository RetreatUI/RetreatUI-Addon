local RUI = RetreatUI
if not RUI then return end

local PROFILE_SCHEMA = 3
local ALLOWED_TEMPLATES = {
  cooldown=true, charges=true, buff=true, buff_stacks=true, proc=true, proc_stacks=true,
  debuff=true, cooldown_aura=true, resource=true, summon=true,
}
local ALLOWED_UNITS = {player=true, target=true, focus=true, pet=true}
local ALLOWED_TRACKING_TYPES = {
  cooldown=true, buff=true, proc=true, debuff=true, stacks=true,
  charges=true, resource=true, summon=true,
}
local ALLOWED_DISPLAYS = {icon=true, bar=true}
local ALLOWED_GLOWS = {off=true, ready=true, active=true}
local ALLOWED_GROUPS = {main=true, procs=true, defensives=true, utility=true, resources=true, target=true}
local ALLOWED_GROWTH = {RIGHT=true, LEFT=true, UP=true, DOWN=true}
local ALLOWED_DESTINATIONS = {hud=true, targetFrame=true, nameplates=true}
local BOOLEAN_SETTINGS = {
  showCooldownText=true, showDuration=true, showStacks=true, learnedOnly=true, combatOnly=true,
}

local function CopyValue(value, depth)
  depth = (depth or 0) + 1
  if depth > 12 then return nil end
  local kind = type(value)
  if kind == "string" or kind == "number" or kind == "boolean" then return value end
  if kind ~= "table" then return nil end
  local result = {}
  for key, child in pairs(value) do
    local keyType = type(key)
    if keyType == "string" or keyType == "number" then
      local copied = CopyValue(child, depth)
      if copied ~= nil then result[key] = copied end
    end
  end
  return result
end

local function ValidateTrackingTypes(entry)
  if entry.trackingType ~= nil and (type(entry.trackingType) ~= "string" or not ALLOWED_TRACKING_TYPES[entry.trackingType]) then
    return false, "unsupported legacy tracking type"
  end
  if entry.trackingTypes == nil then return true end
  if type(entry.trackingTypes) ~= "table" then return false, "tracking types are not a table" end
  if #entry.trackingTypes < 1 or #entry.trackingTypes > 8 then return false, "invalid tracking type count" end
  local seen = {}
  for _, value in ipairs(entry.trackingTypes) do
    if type(value) ~= "string" or not ALLOWED_TRACKING_TYPES[value] then return false, "unsupported tracking type" end
    if seen[value] then return false, "duplicate tracking type" end
    seen[value] = true
  end
  return true
end

local function ValidateDestinations(entry)
  if entry.destinations == nil then return true end
  if type(entry.destinations) ~= "table" then return false, "tracker destinations are not a table" end
  if #entry.destinations < 1 or #entry.destinations > 3 then return false, "invalid tracker destination count" end
  local seen = {}
  for _, value in ipairs(entry.destinations) do
    if type(value) ~= "string" or not ALLOWED_DESTINATIONS[value] then return false, "unsupported tracker destination" end
    if seen[value] then return false, "duplicate tracker destination" end
    seen[value] = true
  end
  return true
end

local function ValidateSettings(settings)
  if settings == nil then return true end
  if type(settings) ~= "table" then return false, "tracker settings are not a table" end
  for key, value in pairs(settings) do
    if key == "display" then
      if type(value) ~= "string" or not ALLOWED_DISPLAYS[value] then return false, "unsupported display mode" end
    elseif key == "iconSize" then
      if type(value) ~= "number" or value < 20 or value > 80 then return false, "invalid icon size" end
    elseif key == "glow" then
      if type(value) ~= "string" or not ALLOWED_GLOWS[value] then return false, "unsupported glow mode" end
    elseif BOOLEAN_SETTINGS[key] then
      if type(value) ~= "boolean" then return false, "invalid boolean tracker setting" end
    else
      return false, "unsupported tracker setting: " .. tostring(key)
    end
  end
  return true
end

local function ValidateTracker(entry, className)
  if type(entry) ~= "table" then return false, "tracker entry is not a table" end
  if type(entry.key) ~= "string" or entry.key == "" then return false, "tracker key is missing" end
  if type(entry.name) ~= "string" or entry.name == "" then return false, "tracker name is missing" end
  if entry.className ~= nil and entry.className ~= className then return false, "tracker class does not match profile class" end
  if entry.spellID ~= nil and (type(entry.spellID) ~= "number" or entry.spellID <= 0) then return false, "invalid spell ID" end
  if entry.auraID ~= nil and (type(entry.auraID) ~= "number" or entry.auraID <= 0) then return false, "invalid aura ID" end
  if entry.template ~= nil and not ALLOWED_TEMPLATES[entry.template] then return false, "unsupported tracker template" end
  if entry.unit ~= nil and not ALLOWED_UNITS[entry.unit] then return false, "unsupported tracker unit" end
  if entry.group ~= nil and (type(entry.group) ~= "string" or not ALLOWED_GROUPS[entry.group]) then return false, "unsupported tracker group" end
  local typesOK, typesReason = ValidateTrackingTypes(entry)
  if not typesOK then return false, typesReason end
  local destinationsOK, destinationsReason = ValidateDestinations(entry)
  if not destinationsOK then return false, destinationsReason end
  local settingsOK, settingsReason = ValidateSettings(entry.settings)
  if not settingsOK then return false, settingsReason end
  return true
end

local function ValidateGroupLayouts(groups)
  if groups == nil then return true end
  if type(groups) ~= "table" then return false, "tracker group layouts are not a table" end
  for key, entry in pairs(groups) do
    if not ALLOWED_GROUPS[key] then return false, "unsupported tracker layout group" end
    if type(entry) ~= "table" then return false, "tracker layout entry is not a table" end
    if type(entry.x) ~= "number" or type(entry.y) ~= "number" then return false, "tracker layout position is invalid" end
    if type(entry.scale) ~= "number" or entry.scale < 0.5 or entry.scale > 2 then return false, "tracker layout scale is invalid" end
    if type(entry.spacing) ~= "number" or entry.spacing < 0 or entry.spacing > 24 then return false, "tracker layout spacing is invalid" end
    if type(entry.growth) ~= "string" or not ALLOWED_GROWTH[entry.growth] then return false, "tracker layout growth is invalid" end
  end
  return true
end

function RUI:GetTrackerProfileData(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return nil end
  local selected = self.GetSelectedTrackers and self:GetSelectedTrackers(className) or {}
  local layoutData = self.GetTrackerGroupLayoutProfileData and self:GetTrackerGroupLayoutProfileData(className) or nil
  return {
    schema = PROFILE_SCHEMA,
    className = className,
    trackers = CopyValue(selected) or {},
    groupLayouts = layoutData and CopyValue(layoutData.groups) or nil,
  }
end

function RUI:ValidateTrackerProfileData(data)
  if type(data) ~= "table" then return false, "tracker profile is not a table" end
  local schema = tonumber(data.schema)
  if schema ~= 1 and schema ~= 2 and schema ~= PROFILE_SCHEMA then return false, "unsupported tracker profile schema" end
  if type(data.className) ~= "string" or data.className == "" then return false, "tracker profile class is missing" end
  if type(data.trackers) ~= "table" then return false, "tracker list is missing" end
  if #data.trackers > 250 then return false, "tracker profile contains too many entries" end
  local seen = {}
  for _, entry in ipairs(data.trackers) do
    local ok, reason = ValidateTracker(entry, data.className)
    if not ok then return false, reason end
    if seen[entry.key] then return false, "tracker profile contains duplicate keys" end
    seen[entry.key] = true
  end
  local groupsOK, groupsReason = ValidateGroupLayouts(data.groupLayouts)
  if not groupsOK then return false, groupsReason end
  return true
end

function RUI:ApplyTrackerProfileData(data, options)
  local valid, reason = self:ValidateTrackerProfileData(data)
  if not valid then return false, reason end
  options = type(options) == "table" and options or {}
  local currentClass = self.GetDetectedClass and self:GetDetectedClass() or nil
  if not options.allowOtherClass and currentClass and data.className ~= currentClass then
    return false, "tracker profile belongs to " .. tostring(data.className) .. ", current class is " .. tostring(currentClass)
  end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.trackerBuilder = RetreatUIDB.trackerBuilder or {}
  RetreatUIDB.trackerBuilder.selected = RetreatUIDB.trackerBuilder.selected or {}
  local target = {}
  for _, entry in ipairs(data.trackers) do
    local copy = CopyValue(entry)
    copy.className = data.className
    target[copy.key] = copy
  end
  RetreatUIDB.trackerBuilder.selected[data.className] = target

  if type(data.groupLayouts) == "table" then
    RetreatUIDB.trackerBuilder.groupLayouts = RetreatUIDB.trackerBuilder.groupLayouts or {}
    RetreatUIDB.trackerBuilder.groupLayouts[data.className] = CopyValue(data.groupLayouts) or {}
  end

  if self.trackerBuilderFrame and self.trackerBuilderFrame:IsShown() and self.RefreshTrackerBuilder then
    pcall(self.RefreshTrackerBuilder, self)
  end
  return true, #data.trackers
end

RUI.trackerProfileSchema = PROFILE_SCHEMA
