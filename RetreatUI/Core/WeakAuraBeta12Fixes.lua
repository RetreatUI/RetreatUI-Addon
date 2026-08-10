local RUI = RetreatUI
if not RUI then return end

-- beta.12 live geometry + target ownership cleanup.
--
-- The State dynamic group has one exact global screen position. Individual
-- stance/form/state leaves remain 38x38 at X=0 / Y=0 from beta.11.
-- Target debuffs are no longer rendered by RetreatUI WeakAuras; ElvUI owns the
-- player's target debuff display instead.
local STATE_GROUP_X, STATE_GROUP_Y = -159, -3

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

local function RemoveID(list, id)
  local result = {}
  for _, item in ipairs(list or {}) do
    if type(item) ~= "table" or item.id ~= id then result[#result + 1] = item end
  end
  return result
end

local function RemoveChild(group, id)
  if type(group) ~= "table" then return end
  local children = {}
  for _, childID in ipairs(group.controlledChildren or {}) do
    if childID ~= id then children[#children + 1] = childID end
  end
  group.controlledChildren = children
end

local function ApplyStateGroupPosition(packageData)
  local stateID = packageData.classGroups and packageData.classGroups.state
  local state = stateID and (FindByID(packageData.groups, stateID) or FindByID(packageData.roots, stateID))
  if not state then return false end
  state.anchorFrameType = "SCREEN"
  state.anchorFrameFrame = nil
  state.anchorPoint = "CENTER"
  state.selfPoint = "CENTER"
  state.xOffset = STATE_GROUP_X
  state.yOffset = STATE_GROUP_Y
  state.grow = "HORIZONTAL"
  state.align = "CENTER"
  return true
end

local function RemoveTargetWeakAuras(packageData)
  local targetID = packageData.classGroups and packageData.classGroups.target
  if not targetID then return true end

  -- Remove all target-owned leaf displays first.
  local keptDisplays = {}
  for _, display in ipairs(packageData.displays or {}) do
    if type(display) ~= "table" or display.parent ~= targetID then
      keptDisplays[#keptDisplays + 1] = display
    end
  end
  packageData.displays = keptDisplays

  -- Remove the target group from every parent and from root/group collections.
  for _, group in ipairs(packageData.groups or {}) do RemoveChild(group, targetID) end
  for _, group in ipairs(packageData.roots or {}) do RemoveChild(group, targetID) end
  packageData.groups = RemoveID(packageData.groups, targetID)
  packageData.roots = RemoveID(packageData.roots, targetID)
  packageData.classGroups.target = nil
  if packageData.expected then
    packageData.expected.targetX = nil
    packageData.expected.targetY = nil
  end
  packageData.targetDebuffsOwner = "ElvUI"
  return true
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    if not ApplyStateGroupPosition(packageData) then
      return nil, "Class State WeakAura group could not be positioned at X -159 / Y -3"
    end
    RemoveTargetWeakAuras(packageData)
    packageData.beta12 = {
      stateGroup = {frame="SCREEN", x=STATE_GROUP_X, y=STATE_GROUP_Y},
      targetDebuffsOwner = "ElvUI",
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
    className = CurrentClass(self, className)
    if className then
      -- Remove the old HUD/WA target-debuff tree permanently before rebuilding.
      DeleteWeakAuraTree("RetreatUI - " .. tostring(className) .. " — Target")
    end
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
    if not state
      or state.anchorFrameType ~= "SCREEN"
      or state.anchorPoint ~= "CENTER"
      or state.selfPoint ~= "CENTER"
      or (tonumber(state.xOffset) or 0) ~= STATE_GROUP_X
      or (tonumber(state.yOffset) or 0) ~= STATE_GROUP_Y then
      return false, "State/Form group must be at X -159 / Y -3"
    end

    local current = CurrentClass(self, className)
    local oldTarget = current and WeakAuras and WeakAuras.GetData and WeakAuras.GetData("RetreatUI - " .. tostring(current) .. " — Target")
    if oldTarget then return false, "Legacy Target WeakAura group is still installed" end
    if packageData.classGroups and packageData.classGroups.target ~= nil then
      return false, "Target debuffs must be owned by ElvUI, not WeakAuras"
    end
    return true, tostring(current) .. " WeakAura HUD verified"
  end
end

RUI._weakAuraBeta12FixesLoaded = true
RUI._weakAuraBeta12FixesRevision = 1
