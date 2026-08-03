local RUI = RetreatUI
if not RUI then return end

-- RetreatUI HUD frames are anchored directly to UIParent so the full-screen
-- World Map does not automatically suppress them. Keep one shared registry and
-- hide the complete managed HUD while the map is visible.
local managed = setmetatable({}, {__mode="k"})
local hiddenForMap = setmetatable({}, {__mode="k"})
local restoreChecks = setmetatable({}, {__mode="k"})
local mapWasOpen = false
local elapsed = 0
local discoveryElapsed = 0

local function WorldMapIsOpen()
  local map = _G.WorldMapFrame
  return map and map.IsShown and map:IsShown() == true
end

local function SafeFrameName(frame)
  if not frame or type(frame.GetName) ~= "function" then return nil end
  local ok, name = pcall(frame.GetName, frame)
  return ok and type(name) == "string" and name or nil
end

local function IsFrame(value)
  if not value or type(value) == "string" then return false end
  if type(value.IsObjectType) == "function" then
    local ok, result = pcall(value.IsObjectType, value, "Frame")
    if ok and result then return true end
  end
  return type(value.Show) == "function" and type(value.Hide) == "function"
    and type(value.IsShown) == "function"
end

local function ShouldDiscoverName(name)
  if type(name) ~= "string" or string.sub(name, 1, 9) ~= "RetreatUI" then return false end
  local lower = string.lower(name)
  if string.find(lower, "installer", 1, true)
    or string.find(lower, "editor", 1, true)
    or string.find(lower, "changelog", 1, true)
    or string.find(lower, "popup", 1, true)
    or string.find(lower, "warning", 1, true)
    or string.find(lower, "dialog", 1, true) then
    return false
  end
  return string.find(lower, "hud", 1, true)
    or string.find(lower, "tracker", 1, true)
    or string.find(lower, "powerbar", 1, true)
    or string.find(lower, "buffmanager", 1, true)
    or string.find(lower, "totembar", 1, true)
end

local function Register(frame, restoreCheck)
  if not IsFrame(frame) then return false end
  managed[frame] = true
  if type(restoreCheck) == "function" then restoreChecks[frame] = restoreCheck end

  if not frame.__ruiMapVisibilityHooked and type(frame.HookScript) == "function" then
    frame.__ruiMapVisibilityHooked = true
    frame:HookScript("OnShow", function(shownFrame)
      if WorldMapIsOpen() then
        hiddenForMap[shownFrame] = true
        shownFrame:Hide()
      end
    end)
  end

  if WorldMapIsOpen() and frame:IsShown() then
    hiddenForMap[frame] = true
    frame:Hide()
  end
  return true
end

function RUI:RegisterHUDVisibilityFrame(frame, restoreCheck)
  return Register(frame, restoreCheck)
end

local function DiscoverManagedFrames()
  for _, module in pairs(RUI.classModules or {}) do
    local frameName = type(module) == "table" and module.frameName or nil
    if type(frameName) == "string" then Register(_G[frameName]) end
  end

  for name, value in pairs(_G) do
    if ShouldDiscoverName(name) and IsFrame(value) then Register(value) end
  end
end

local function HideForMap()
  DiscoverManagedFrames()
  for frame in pairs(managed) do
    if frame:IsShown() then
      hiddenForMap[frame] = true
      frame:Hide()
    end
  end
end

local function ClassRootStillActive(frame)
  local name = SafeFrameName(frame)
  if not name then return true end
  for _, module in pairs(RUI.classModules or {}) do
    if type(module) == "table" and module.frameName == name then
      return RUI.activeModule == module
    end
  end
  return true
end

local function RestoreAfterMap()
  for frame in pairs(hiddenForMap) do
    local check = restoreChecks[frame]
    local allowed = ClassRootStillActive(frame)
    if allowed and check then
      local ok, result = pcall(check)
      allowed = ok and result == true
    end
    if allowed and frame.Show then pcall(frame.Show, frame) end
    hiddenForMap[frame] = nil
  end
end

local watcher = CreateFrame("Frame", "RetreatUIMapVisibilityController")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, eventName, addonName)
  if eventName == "ADDON_LOADED" and addonName ~= "Blizzard_WorldMap" and addonName ~= "RetreatUI" then return end
  DiscoverManagedFrames()
  local open = WorldMapIsOpen()
  if open then HideForMap() end
  mapWasOpen = open
end)

watcher:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.10 then return end
  elapsed = 0

  local open = WorldMapIsOpen()
  if open ~= mapWasOpen then
    mapWasOpen = open
    discoveryElapsed = 0
    if open then HideForMap() else RestoreAfterMap() end
    return
  end

  if open then
    discoveryElapsed = discoveryElapsed + 0.10
    if discoveryElapsed >= 0.50 then
      discoveryElapsed = 0
      HideForMap()
    end
  end
end)

RUI._mapVisibilityLoaded = true
