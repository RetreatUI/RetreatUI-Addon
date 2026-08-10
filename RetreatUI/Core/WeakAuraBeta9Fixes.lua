local RUI = RetreatUI
if not RUI then return end

-- beta.9: global form/state lane + Necromancer Life Force cleanup.
-- The form/state lane is screen-anchored from the shared HUD geometry so it can
-- never collide with ElvUI player-frame trinkets. Necromancer Life Force is a
-- mirrored Ascension class resource, not a generic icon counter.

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

-- Global stance/form placement derived from the immutable HUD geometry.
-- Resource top edge: -144. 38px icon centered at -121 => bottom -140: 4px gap.
-- X=-188 keeps it 4px left of a 330px secondary-resource bar (left edge -165).
local STATE_X, STATE_Y = -188, -121

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
  state.align = "RIGHT"
end

local LIFE_FORCE_ICON = "Interface\\Icons\\Spell_Shadow_AnimateDead"
local lifeForceObservedMax = 3

local function EnsureNecromancerNativeResource(self, className)
  if className ~= "Necromancer" then return end
  local database = self:GetClassSpellDatabase(className)
  if type(database) ~= "table" then return end
  database.nativeResource = database.nativeResource or {
    key = "lifeForce",
    title = "LIFE FORCE",
    keywords = {"life force", "lifeforce"},
    auraNames = {"Life Force"},
    auraIDs = {805011},
    mode = "segments",
    icon = LIFE_FORCE_ICON,
  }
end

local function RemoveNecromancerLegacyLifeForceIcon(packageData, className)
  if className ~= "Necromancer" then return end
  local resourceID = packageData.classGroups and packageData.classGroups.resource
  if not resourceID then return end
  local legacyID = resourceID .. " — Life Force"
  local removed = {[legacyID] = true}
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

local previousNativeResourceState = RUI.GetWeakAuraNativeResourceState
if type(previousNativeResourceState) == "function" then
  function RUI:GetWeakAuraNativeResourceState(className, forceDiscovery)
    className = CurrentClass(self, className)
    local snapshot = previousNativeResourceState(self, className, forceDiscovery)
    if snapshot or className ~= "Necromancer" then return snapshot end

    -- Same fallback used by the old native Necromancer HUD: Life Force aura 805011.
    if type(UnitBuff) ~= "function" then return nil end
    for index = 1, 40 do
      local values = {UnitBuff("player", index)}
      local name = values[1]
      if not name then break end
      local spellID = tonumber(values[11])
      if spellID == 805011 or Normalize(name) == "life force" then
        local current = math.max(0, tonumber(values[4]) or 0)
        lifeForceObservedMax = math.max(lifeForceObservedMax, current)
        self.weakAuraResourceReady = true
        return {
          show = true,
          key = "native",
          name = "LIFE FORCE",
          icon = values[3] or LIFE_FORCE_ICON,
          current = current,
          maximum = math.max(1, lifeForceObservedMax),
          mode = "segments",
          progressType = "static",
          value = current,
          total = math.max(1, lifeForceObservedMax),
        }
      end
    end
    return nil
  end
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    className = CurrentClass(self, className)
    EnsureNecromancerNativeResource(self, className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    ApplyGlobalStateLane(packageData)
    RemoveNecromancerLegacyLifeForceIcon(packageData, className)
    packageData.beta9Cleanup = {
      globalStateLane = {
        frame = "SCREEN", x = STATE_X, y = STATE_Y, iconSize = 38,
        primaryResourceY = -152, primaryResourceHeight = 16, gap = 4,
      },
      necromancerLifeForce = className == "Necromancer",
    }
    return packageData, buildError
  end
end

-- Delete the beta.8 generic Life Force counter before reinstall so its old
-- question-mark leaf cannot survive as an orphan in WeakAuras.
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
    className = CurrentClass(self, className)
    if className == "Necromancer" then
      DeleteWeakAuraTree("RetreatUI - Necromancer — Resource — Life Force")
    end
    return previousInstallWeakAuraHUD(self, className, force)
  end
end

RUI._weakAuraBeta9FixesLoaded = true
RUI._weakAuraBeta9FixesRevision = 1
