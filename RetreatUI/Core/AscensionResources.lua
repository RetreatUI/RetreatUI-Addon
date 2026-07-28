local RUI = RetreatUI
if not RUI then return end

-- Ascension's custom-resource implementation has changed names and internal
-- layouts several times. This bridge reads the live native widget instead of
-- hardcoding a single revision. A native source frame remains alive at alpha 0
-- after RetreatUI has a valid compact mirror, so its own update scripts continue
-- feeding current values, segments and state text.
local knownNames = {
  "CoAResourceSegmentBar",
  "CoAResourceSegmentBarContainer", "CoAResourceSegmentContainer",
  "CoAResourceBar", "CoAResourceFrame", "CoAResourceAnchor", "CoAResourceHolder",
  "CoAClassResourceBar", "CoAClassResourceFrame", "CoAClassBar",
  "AscensionResourceBar", "AscensionResourceFrame", "AscensionResourceAnchor",
  "AscensionClassResourceBar", "AscensionClassResourceFrame", "AscensionClassBar",
  "AscensionPowerBar", "AscensionPowerFrame",
  "ClasslessResourceBar", "ClasslessResourceFrame", "ClasslessPowerBar",
  "HeroArchitectResourceBar", "HeroArchitectResourceFrame",
  "ConquestResourceBar", "ConquestResourceFrame",
  "ClassResourceBar", "ClassResourceFrame", "ClassResourceContainer",
  "CharacterResourceBar", "CharacterResourceFrame",
}

for index = 1, 24 do
  knownNames[#knownNames + 1] = "CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate" .. index
  knownNames[#knownNames + 1] = string.format("CoAResourceSegmentBarPoolFrameCoAResourceSegmentTemplate%02d", index)
end

local mirrorSources = setmetatable({}, {__mode = "k"})
local discovered = {}
local lastDiscovery = 0

local function Lower(value)
  return string.lower(tostring(value or ""))
end

local function FrameName(frame)
  if not frame or type(frame.GetName) ~= "function" then return nil end
  local ok, name = pcall(frame.GetName, frame)
  return ok and name or nil
end

local function IsFrameLike(value)
  local kind = type(value)
  if kind ~= "table" and kind ~= "userdata" then return false end
  return value.GetObjectType ~= nil and value.GetChildren ~= nil
end

local function LooksLikeNativeResourceName(name)
  if type(name) ~= "string" or name == "" then return false end
  local lower = Lower(name)
  if string.find(lower, "retreatui", 1, true) then return false end
  local namespace = string.find(lower, "coa", 1, true)
    or string.find(lower, "ascension", 1, true)
    or string.find(lower, "classless", 1, true)
    or string.find(lower, "conquest", 1, true)
    or string.find(lower, "heroarchitect", 1, true)
  if not namespace then return false end
  return string.find(lower, "resource", 1, true)
    or string.find(lower, "powerbar", 1, true)
    or string.find(lower, "powerframe", 1, true)
    or string.find(lower, "segmentbar", 1, true)
    or string.find(lower, "segmenttemplate", 1, true)
    or string.find(lower, "classbar", 1, true)
end

local function Discover(force)
  local now = time and time() or 0
  if not force and now ~= 0 and lastDiscovery ~= 0 and now - lastDiscovery < 2 then return end
  lastDiscovery = now
  for _, name in ipairs(knownNames) do
    local frame = _G[name]
    if IsFrameLike(frame) then discovered[frame] = name end
  end
  for name, value in pairs(_G) do
    if LooksLikeNativeResourceName(name) and IsFrameLike(value) then
      discovered[value] = name
    end
  end
end

local function IsShown(frame)
  if not frame then return false end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and shown then return true end
  end
  if type(frame.IsVisible) == "function" then
    local ok, shown = pcall(frame.IsVisible, frame)
    if ok and shown then return true end
  end
  return false
end

local function AddUnique(list, set, value)
  if value == nil then return end
  local key = tostring(value)
  if key == "" or set[key] then return end
  set[key] = true
  list[#list + 1] = value
end

local function ReadTexture(region)
  if not region or type(region.GetTexture) ~= "function" then return nil end
  local ok, texture = pcall(region.GetTexture, region)
  if not ok or texture == nil or texture == "" then return nil end
  return texture
end

local function IsIconTexture(texture)
  if type(texture) == "number" then return true end
  if type(texture) ~= "string" then return false end
  local lower = Lower(texture)
  return string.find(lower, "interface\\icons\\", 1, true)
    or string.find(lower, "interface/icons/", 1, true)
end

local function Collect(frame, snapshot, depth, seen)
  if not frame or seen[frame] or depth > 8 then return end
  seen[frame] = true

  local name = FrameName(frame)
  local objectType
  if type(frame.GetObjectType) == "function" then
    local ok, value = pcall(frame.GetObjectType, frame)
    if ok then objectType = value end
  end

  if objectType == "StatusBar" and type(frame.GetMinMaxValues) == "function" and type(frame.GetValue) == "function" then
    local okRange, minimum, maximum = pcall(frame.GetMinMaxValues, frame)
    local okValue, current = pcall(frame.GetValue, frame)
    minimum = okRange and tonumber(minimum) or nil
    maximum = okRange and tonumber(maximum) or nil
    current = okValue and tonumber(current) or nil
    if minimum and maximum and current and maximum > minimum then
      local width, height = 0, 0
      if type(frame.GetWidth) == "function" then pcall(function() width = tonumber(frame:GetWidth()) or 0 end) end
      if type(frame.GetHeight) == "function" then pcall(function() height = tonumber(frame:GetHeight()) or 0 end) end
      snapshot.bars[#snapshot.bars + 1] = {
        frame = frame,
        current = current - minimum,
        maximum = maximum - minimum,
        area = math.max(1, width) * math.max(1, height),
      }
    end
  end

  if name and string.find(Lower(name), "segmenttemplate", 1, true) then
    local alpha = 1
    if type(frame.GetAlpha) == "function" then
      local ok, value = pcall(frame.GetAlpha, frame)
      if ok and tonumber(value) then alpha = tonumber(value) end
    end
    snapshot.segments[#snapshot.segments + 1] = {
      frame = frame,
      active = IsShown(frame) and alpha > 0.52,
      alpha = alpha,
    }
  end

  if type(frame.GetRegions) == "function" then
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
      if region then
        if type(region.GetText) == "function" then
          local ok, text = pcall(region.GetText, region)
          if ok and text and tostring(text) ~= "" then
            AddUnique(snapshot.texts, snapshot.textSet, tostring(text))
          end
        end
        local texture = ReadTexture(region)
        if texture then
          if IsIconTexture(texture) then
            AddUnique(snapshot.icons, snapshot.iconSet, texture)
          else
            AddUnique(snapshot.textures, snapshot.textureSet, texture)
          end
        end
      end
    end
  end

  if type(frame.GetChildren) == "function" then
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do Collect(child, snapshot, depth + 1, seen) end
  end
end

local function KeywordScore(snapshot, keywords)
  if type(keywords) ~= "table" or #keywords == 0 then return 0 end
  local haystack = Lower(snapshot.name)
  for _, text in ipairs(snapshot.texts) do haystack = haystack .. " " .. Lower(text) end
  local score = 0
  for _, keyword in ipairs(keywords) do
    local normalized = Lower(keyword)
    if normalized ~= "" and string.find(haystack, normalized, 1, true) then score = score + 100 end
  end
  return score
end

local function CleanLabel(snapshot, fallback)
  local className = type(RUI.GetDetectedClass) == "function" and Lower(RUI:GetDetectedClass()) or ""
  local classKey = className:gsub("[^%a%d]", "")
  local ignored = {
    ["resource"] = true, ["class resource"] = true, ["power"] = true,
  }
  for _, text in ipairs(snapshot.texts or {}) do
    local trimmed = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = Lower(trimmed)
    local lowerKey = lower:gsub("[^%a%d]", "")
    if trimmed ~= "" and lower ~= className and lowerKey ~= classKey and not ignored[lower]
      and not trimmed:match("^%d+%s*/%s*%d+$") and trimmed:match("%a") then
      return trimmed
    end
  end
  return fallback or "CLASS RESOURCE"
end

local function ParseTextValues(snapshot)
  for _, text in ipairs(snapshot.texts or {}) do
    local current, maximum = tostring(text):match("(%d+)%s*/%s*(%d+)")
    current, maximum = tonumber(current), tonumber(maximum)
    if current and maximum and maximum > 0 then return current, maximum end
  end
  return nil, nil
end

function RUI:MarkNativeResourceMirrorSource(frame)
  local function MarkChildren(current, depth, seen)
    if not current or seen[current] or depth > 8 then return end
    seen[current] = true
    mirrorSources[current] = true
    if type(current.GetChildren) == "function" then
      local children = {current:GetChildren()}
      for _, child in ipairs(children) do MarkChildren(child, depth + 1, seen) end
    end
  end

  MarkChildren(frame, 0, {})
  local current, depth = frame, 0
  while current and depth < 10 do
    mirrorSources[current] = true
    if current == UIParent or current == WorldFrame then break end
    current = type(current.GetParent) == "function" and current:GetParent() or nil
    depth = depth + 1
  end
end

function RUI:IsNativeResourceMirrorSource(frame)
  return frame ~= nil and mirrorSources[frame] == true
end

function RUI:RestoreNativeResourceMirrorSources()
  for frame in pairs(mirrorSources) do
    if frame then
      if type(frame.SetAlpha) == "function" then pcall(frame.SetAlpha, frame, 1) end
      if type(frame.EnableMouse) == "function" then pcall(frame.EnableMouse, frame, true) end
      if type(frame.Show) == "function" then pcall(frame.Show, frame) end
    end
  end
end

function RUI:ReadAscensionResourceSnapshot(keywords, fallbackLabel, forceDiscovery)
  Discover(forceDiscovery == true)
  local best, bestScore

  for frame, name in pairs(discovered) do
    if frame and IsFrameLike(frame) then
      local snapshot = {
        frame = frame,
        name = name or FrameName(frame) or "",
        texts = {}, textSet = {},
        icons = {}, iconSet = {},
        textures = {}, textureSet = {},
        bars = {}, segments = {},
      }
      Collect(frame, snapshot, 0, {})
      table.sort(snapshot.bars, function(left, right) return (left.area or 0) > (right.area or 0) end)

      local score = KeywordScore(snapshot, keywords)
      if IsShown(frame) then score = score + 20 end
      if #snapshot.bars > 0 then score = score + 12 end
      if #snapshot.segments > 0 then score = score + 10 end
      if #snapshot.texts > 0 then score = score + 4 end
      if #snapshot.icons > 0 then score = score + 2 end
      if string.find(Lower(snapshot.name), "segmenttemplate", 1, true) then score = score - 30 end

      local requiresKeyword = type(keywords) == "table" and #keywords > 0
      if (not requiresKeyword or score >= 100) and (not bestScore or score > bestScore) then
        best, bestScore = snapshot, score
      end
    end
  end

  if not best then return nil end
  best.label = CleanLabel(best, fallbackLabel)
  best.icon = best.icons[1]

  if best.bars[1] then
    best.current = math.max(0, tonumber(best.bars[1].current) or 0)
    best.maximum = math.max(1, tonumber(best.bars[1].maximum) or 1)
  elseif #best.segments > 0 then
    local active = 0
    for _, segment in ipairs(best.segments) do if segment.active then active = active + 1 end end
    best.current, best.maximum = active, #best.segments
  else
    best.current, best.maximum = ParseTextValues(best)
  end

  self:MarkNativeResourceMirrorSource(best.frame)
  return best
end

local POWER_TYPE_BY_TOKEN = {
  MANA = 0,
  RAGE = 1,
  FOCUS = 2,
  ENERGY = 3,
  RUNICPOWER = 6,
}

function RUI:GetPowerTypeForToken(token)
  token = string.upper(tostring(token or "")):gsub("[^A-Z]", "")
  return POWER_TYPE_BY_TOKEN[token]
end

function RUI:FindCustomPower(options)
  options = options or {}
  if not UnitPower or not UnitPowerMax then return nil end

  local excluded = {}
  if type(options.excludeTypes) == "table" then
    for _, value in ipairs(options.excludeTypes) do excluded[tonumber(value)] = true end
  end
  if options.excludeToken then
    local powerType = self:GetPowerTypeForToken(options.excludeToken)
    if powerType ~= nil then excluded[powerType] = true end
  end

  local minimumMax = tonumber(options.minimumMax) or 1
  local maximumMax = tonumber(options.maximumMax) or 1000
  local expectedMax = tonumber(options.expectedMax)
  local candidates = {}

  for powerType = 0, tonumber(options.scanMaximumType) or 30 do
    if not excluded[powerType] then
      local okMax, maximum = pcall(UnitPowerMax, "player", powerType)
      maximum = okMax and tonumber(maximum) or nil
      if maximum and maximum >= minimumMax and maximum <= maximumMax
        and (not expectedMax or maximum == expectedMax) then
        local okCurrent, current = pcall(UnitPower, "player", powerType)
        current = okCurrent and tonumber(current) or 0
        candidates[#candidates + 1] = {
          powerType = powerType,
          current = math.max(0, current or 0),
          maximum = maximum,
        }
      end
    end
  end

  table.sort(candidates, function(left, right)
    if expectedMax then return left.powerType < right.powerType end
    local leftScore = (left.maximum <= 20 and 100 or 0) + left.maximum
    local rightScore = (right.maximum <= 20 and 100 or 0) + right.maximum
    if leftScore == rightScore then return left.powerType < right.powerType end
    return leftScore > rightScore
  end)
  return candidates[1]
end

RUI._ascensionResourcesLoaded = true
