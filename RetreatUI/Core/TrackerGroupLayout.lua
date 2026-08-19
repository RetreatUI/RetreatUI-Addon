local RUI = RetreatUI
if not RUI then return end

RUI.trackerGroupLayoutSchema = 1
RUI.trackerGroupDefinitions = {
  {key="main", label="MAIN", x=0, y=-80, growth="RIGHT"},
  {key="procs", label="PROCS / BUFFS", x=0, y=-128, growth="RIGHT"},
  {key="defensives", label="DEFENSIVES", x=0, y=-176, growth="RIGHT"},
  {key="utility", label="UTILITY", x=0, y=-224, growth="RIGHT"},
  {key="resources", label="RESOURCES", x=0, y=-272, growth="RIGHT"},
  {key="target", label="TARGET", x=0, y=70, growth="RIGHT"},
}

local GROUP_KEYS = {}
for _, definition in ipairs(RUI.trackerGroupDefinitions) do GROUP_KEYS[definition.key] = true end
local GROWTH = {RIGHT=true, LEFT=true, UP=true, DOWN=true}

local function EnsureStore(self, className)
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.trackerBuilder = RetreatUIDB.trackerBuilder or {}
  RetreatUIDB.trackerBuilder.groupLayouts = RetreatUIDB.trackerBuilder.groupLayouts or {}
  local all = RetreatUIDB.trackerBuilder.groupLayouts
  className = className or (self.GetDetectedClass and self:GetDetectedClass()) or "Unknown"
  all[className] = all[className] or {}
  return all[className], className
end

local function Definition(key)
  for _, value in ipairs(RUI.trackerGroupDefinitions) do if value.key == key then return value end end
  return nil
end

function RUI:GetTrackerGroupLayout(className, key)
  if not GROUP_KEYS[key] then return nil end
  local store = EnsureStore(self, className)
  local definition = Definition(key)
  local entry = store[key]
  if type(entry) ~= "table" then
    entry = {}
    store[key] = entry
  end
  if type(entry.x) ~= "number" then entry.x = definition.x end
  if type(entry.y) ~= "number" then entry.y = definition.y end
  if type(entry.scale) ~= "number" then entry.scale = 1 end
  if type(entry.spacing) ~= "number" then entry.spacing = 4 end
  if not GROWTH[entry.growth] then entry.growth = definition.growth end
  entry.scale = math.max(0.5, math.min(2, entry.scale))
  entry.spacing = math.max(0, math.min(24, math.floor(entry.spacing + 0.5)))
  return entry
end

function RUI:SetTrackerGroupLayout(className, key, values)
  if not GROUP_KEYS[key] or type(values) ~= "table" then return false end
  local entry = self:GetTrackerGroupLayout(className, key)
  if not entry then return false end
  if tonumber(values.x) then entry.x = math.floor(tonumber(values.x) + 0.5) end
  if tonumber(values.y) then entry.y = math.floor(tonumber(values.y) + 0.5) end
  if tonumber(values.scale) then entry.scale = math.max(0.5, math.min(2, tonumber(values.scale))) end
  if tonumber(values.spacing) then entry.spacing = math.max(0, math.min(24, math.floor(tonumber(values.spacing) + 0.5))) end
  if GROWTH[values.growth] then entry.growth = values.growth end
  return true
end

function RUI:ResetTrackerGroupLayout(className, key)
  if not GROUP_KEYS[key] then return false end
  local store = EnsureStore(self, className)
  store[key] = nil
  self:GetTrackerGroupLayout(className, key)
  return true
end

function RUI:GetTrackersByGroup(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local grouped = {}
  for key in pairs(GROUP_KEYS) do grouped[key] = {} end
  local selected = self.GetSelectedTrackers and self:GetSelectedTrackers(className) or {}
  for _, tracker in ipairs(selected) do
    local key = GROUP_KEYS[tracker.group] and tracker.group or "main"
    grouped[key][#grouped[key] + 1] = tracker
  end
  return grouped
end

function RUI:GetTrackerGroupLayoutProfileData(className)
  local store, resolved = EnsureStore(self, className)
  local groups = {}
  for key in pairs(GROUP_KEYS) do
    local entry = self:GetTrackerGroupLayout(resolved, key)
    groups[key] = {x=entry.x, y=entry.y, scale=entry.scale, spacing=entry.spacing, growth=entry.growth}
  end
  return {schema=self.trackerGroupLayoutSchema, className=resolved, groups=groups}
end
