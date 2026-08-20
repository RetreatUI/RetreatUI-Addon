local RUI = RetreatUI
if not RUI then return end

RUI.hudWorkspaceSchema = 1

local ORIENTATIONS = {HORIZONTAL=true, VERTICAL=true}
local ROLE_ORDER = {"main", "proc", "utility", "defensive", "target"}
local ROLE_DEFINITIONS = {
  main = {label="Main Ability", short="MAIN", defaultBarKind="main"},
  proc = {label="Buff / Proc", short="PROC", defaultBarKind="proc"},
  utility = {label="Utility", short="UTILITY", defaultBarKind="utility"},
  defensive = {label="Defensive", short="DEFENSIVE", defaultBarKind="defensive"},
  target = {label="Target Debuff", short="TARGET", defaultBarKind="target"},
}

local function Trim(value)
  value = tostring(value or "")
  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
  return result
end

local function DetectedClass(self, className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then className = "Unknown" end
  return className
end

local function EnsureRoot()
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.hudWorkspace = RetreatUIDB.hudWorkspace or {}
  local root = RetreatUIDB.hudWorkspace
  root.schema = RUI.hudWorkspaceSchema
  root.classes = root.classes or {}
  return root
end

local function DefaultPosition(kind, ordinal)
  ordinal = tonumber(ordinal) or 1
  if kind == "main" then return 0, -183 - ((ordinal - 1) * 48) end
  if kind == "utility" then return 0, -235 - ((ordinal - 1) * 42) end
  if kind == "proc" then return 0, -92 - ((ordinal - 1) * 38) end
  if kind == "defensive" then return 225, -183 - ((ordinal - 1) * 42) end
  if kind == "target" then return 310, -59 - ((ordinal - 1) * 38) end
  return 0, -183 - ((ordinal - 1) * 42)
end

local function KindLabel(kind)
  if kind == "main" then return "Main Rotation" end
  if kind == "utility" then return "Utility Bar" end
  if kind == "proc" then return "Proc Bar" end
  if kind == "defensive" then return "Defensive Bar" end
  if kind == "target" then return "Target Bar" end
  return "Custom Bar"
end

local function CountKind(state, kind)
  local count = 0
  for _, id in ipairs(state.order or {}) do
    local bar = state.bars and state.bars[id]
    if bar and bar.kind == kind then count = count + 1 end
  end
  return count
end

local function NewBar(state, className, kind, name, orientation)
  kind = ROLE_DEFINITIONS[kind] and kind or (kind == "custom" and "custom" or "custom")
  local ordinal = CountKind(state, kind) + 1
  local id = "bar" .. tostring(state.nextID or 1)
  state.nextID = (state.nextID or 1) + 1
  local x, y = DefaultPosition(kind, ordinal)
  local cleanName = Trim(name)
  if cleanName == "" then cleanName = KindLabel(kind) .. " " .. tostring(ordinal) end
  local bar = {
    id = id,
    className = className,
    kind = kind,
    name = cleanName,
    orientation = ORIENTATIONS[orientation] and orientation or "HORIZONTAL",
    x = x,
    y = y,
    scale = 1,
    spacing = kind == "main" and 2 or 4,
    iconSize = kind == "main" and 38 or 34,
    waID = "RetreatUI - " .. tostring(className) .. " - " .. cleanName,
    createdAt = time and time() or 0,
    dirty = true,
  }
  state.bars[id] = bar
  state.order[#state.order + 1] = id
  return bar
end

local function EnsureClass(self, className)
  className = DetectedClass(self, className)
  local root = EnsureRoot()
  local state = root.classes[className]
  if type(state) ~= "table" then
    state = {schema=RUI.hudWorkspaceSchema, nextID=1, bars={}, order={}}
    root.classes[className] = state
  end
  state.schema = RUI.hudWorkspaceSchema
  state.nextID = tonumber(state.nextID) or 1
  state.bars = state.bars or {}
  state.order = state.order or {}

  local compact = {}
  local seen = {}
  for _, id in ipairs(state.order) do
    if type(id) == "string" and state.bars[id] and not seen[id] then
      compact[#compact + 1] = id
      seen[id] = true
    end
  end
  for id in pairs(state.bars) do
    if not seen[id] then compact[#compact + 1] = id; seen[id] = true end
  end
  state.order = compact

  if #state.order == 0 then
    NewBar(state, className, "main", "Main Rotation 1", "HORIZONTAL")
    NewBar(state, className, "utility", "Utility Bar 1", "HORIZONTAL")
  end
  return state, className
end

function RUI:GetHUDRoleDefinitions()
  local result = {}
  for _, key in ipairs(ROLE_ORDER) do
    local definition = Copy(ROLE_DEFINITIONS[key])
    definition.key = key
    result[#result + 1] = definition
  end
  return result
end

function RUI:GetHUDBars(className)
  local state = EnsureClass(self, className)
  local result = {}
  for _, id in ipairs(state.order) do
    local bar = state.bars[id]
    if bar then result[#result + 1] = bar end
  end
  return result
end

function RUI:GetHUDBar(className, barID)
  local state = EnsureClass(self, className)
  return type(barID) == "string" and state.bars[barID] or nil
end

function RUI:CreateHUDBar(kind, name, orientation, className)
  local state, resolved = EnsureClass(self, className)
  return NewBar(state, resolved, kind, name, orientation)
end

function RUI:UpdateHUDBar(barID, values, className)
  local bar = self:GetHUDBar(className, barID)
  if not bar or type(values) ~= "table" then return false, "HUD bar not found" end
  if values.name ~= nil then
    local name = Trim(values.name)
    if name ~= "" then bar.name = name end
  end
  if ORIENTATIONS[values.orientation] then bar.orientation = values.orientation end
  if tonumber(values.x) then bar.x = math.floor(tonumber(values.x) + 0.5) end
  if tonumber(values.y) then bar.y = math.floor(tonumber(values.y) + 0.5) end
  if tonumber(values.scale) then bar.scale = math.max(0.5, math.min(2, tonumber(values.scale))) end
  if tonumber(values.spacing) then bar.spacing = math.max(0, math.min(24, math.floor(tonumber(values.spacing) + 0.5))) end
  if tonumber(values.iconSize) then bar.iconSize = math.max(20, math.min(80, math.floor(tonumber(values.iconSize) + 0.5))) end
  bar.dirty = true
  return true, bar
end

function RUI:DeleteHUDBar(barID, className)
  local state, resolved = EnsureClass(self, className)
  local bar = type(barID) == "string" and state.bars[barID]
  if not bar then return false, "HUD bar not found" end
  if #state.order <= 1 then return false, "At least one HUD bar must remain" end

  local replacement
  for _, id in ipairs(state.order) do if id ~= barID and state.bars[id] then replacement = id; break end end
  for _, tracker in ipairs(self.GetSelectedTrackers and self:GetSelectedTrackers(resolved) or {}) do
    if tracker.hudBarID == barID then tracker.hudBarID = replacement end
  end
  state.bars[barID] = nil
  for index=#state.order,1,-1 do if state.order[index] == barID then table.remove(state.order, index) end end
  return true, replacement
end

local function HasType(item, wanted)
  for _, value in ipairs((item and item.trackingTypes) or {}) do if value == wanted then return true end end
  return false
end

local function RoleConfig(item, roleKey)
  if roleKey == "proc" then
    local types = {"proc"}
    if tonumber(item and item.maxStacks) and tonumber(item.maxStacks) > 1 then types[#types + 1] = "stacks" end
    return {trackingTypes=types, unit="player", showDuration=true, showStacks=#types > 1, glow="active"}
  end
  if roleKey == "target" then
    return {trackingTypes={"debuff"}, unit="target", showDuration=true, showStacks=tonumber(item and item.maxStacks) and tonumber(item.maxStacks) > 1 or false, glow="off"}
  end

  local types = {"cooldown"}
  if HasType(item, "charges") then types[#types + 1] = "charges" end
  return {
    trackingTypes=types,
    unit="player",
    showCooldownText=true,
    showDuration=false,
    showStacks=HasType(item, "charges"),
    glow=roleKey == "main" and "ready" or "off",
  }
end

function RUI:SaveHUDWorkspaceTracker(item, roleKey, barID, options)
  if type(item) ~= "table" then return false, "Select a spell first" end
  local definition = ROLE_DEFINITIONS[roleKey]
  if not definition then return false, "Choose what this spell should track" end
  local bar = self:GetHUDBar(item.className, barID)
  if not bar then return false, "Choose a HUD bar" end

  local config = RoleConfig(item, roleKey)
  options = type(options) == "table" and options or {}
  config.display = "icon"
  config.iconSize = tonumber(options.iconSize) or tonumber(bar.iconSize) or 36
  config.destinations = {"hud"}
  if options.glow then config.glow = options.glow end

  local ok, saved = self:SaveTrackerSelection(item, config)
  if not ok or type(saved) ~= "table" then return false, saved or "Tracker could not be saved" end
  saved.hudRole = roleKey
  saved.hudBarID = bar.id
  saved.group = nil
  saved.destinations = {"hud"}
  bar.dirty = true
  return true, saved
end

function RUI:RemoveHUDWorkspaceTracker(key, className)
  className = DetectedClass(self, className)
  local selected = self.GetTrackerSelection and self:GetTrackerSelection(className, key)
  local barID = selected and selected.hudBarID
  local removed = self.RemoveTrackerSelection and self:RemoveTrackerSelection(className, key)
  local bar = barID and self:GetHUDBar(className, barID)
  if bar then bar.dirty = true end
  return removed == true
end

function RUI:GetHUDTrackersForBar(barID, className)
  className = DetectedClass(self, className)
  local result = {}
  for _, tracker in ipairs(self.GetSelectedTrackers and self:GetSelectedTrackers(className) or {}) do
    if tracker.hudBarID == barID then result[#result + 1] = tracker end
  end
  table.sort(result, function(a,b)
    local ai = tonumber(a.hudOrder) or 9999
    local bi = tonumber(b.hudOrder) or 9999
    if ai ~= bi then return ai < bi end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return result
end

function RUI:GetHUDWorkspaceTrackerCount(barID, className)
  return #self:GetHUDTrackersForBar(barID, className)
end

function RUI:SearchHUDSpells(query, maxResults, className)
  query = Trim(query)
  if query == "" then return {} end
  className = DetectedClass(self, className)
  local catalog = self.GetTrackerCatalog and self:GetTrackerCatalog(className, {
    query=query,
    learnedOnly=false,
    recommendedOnly=false,
    includeAdvanced=true,
    includeUntrackable=true,
  }) or {}

  local numeric = tonumber(query)
  table.sort(catalog, function(a,b)
    local aExactID = numeric and tonumber(a.spellID) == numeric or false
    local bExactID = numeric and tonumber(b.spellID) == numeric or false
    if aExactID ~= bExactID then return aExactID end
    local aExactName = string.lower(tostring(a.name or "")) == string.lower(query)
    local bExactName = string.lower(tostring(b.name or "")) == string.lower(query)
    if aExactName ~= bExactName then return aExactName end
    if a.learned ~= b.learned then return a.learned == true end
    return tostring(a.name or "") < tostring(b.name or "")
  end)

  maxResults = math.max(1, math.min(20, tonumber(maxResults) or 8))
  local result = {}
  for index=1, math.min(#catalog, maxResults) do result[#result + 1] = catalog[index] end
  return result
end

function RUI:GetHUDWorkspaceState(className)
  local state, resolved = EnsureClass(self, className)
  return state, resolved
end

RUI._hudWorkspaceLoaded = true
