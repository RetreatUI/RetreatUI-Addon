local RUI = RetreatUI
if not RUI then return end

-- beta.11: stance/form/state leaf geometry is an invariant.
-- The Dynamic Group owns the screen placement. Every actual state icon itself
-- must stay exactly 38x38 with X=0 / Y=0 inside that group. No class is allowed
-- to carry a per-icon nudge.
local STATE_ICON_SIZE = 38
local STATE_CHILD_X, STATE_CHILD_Y = 0, 0

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

local function LockStateLeafGeometry(packageData)
  local stateID = packageData.classGroups and packageData.classGroups.state
  if not stateID then return false end
  local stateGroup = FindByID(packageData.groups, stateID) or FindByID(packageData.roots, stateID)
  if not stateGroup then return false end

  local children = {}
  for _, id in ipairs(stateGroup.controlledChildren or {}) do children[id] = true end
  local found = false
  for _, display in ipairs(packageData.displays or {}) do
    if type(display) == "table" and display.parent == stateID and children[display.id] then
      display.width = STATE_ICON_SIZE
      display.height = STATE_ICON_SIZE
      display.xOffset = STATE_CHILD_X
      display.yOffset = STATE_CHILD_Y
      display.selfPoint = "CENTER"
      display.anchorPoint = "CENTER"
      found = true
    end
  end
  return found
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    if not LockStateLeafGeometry(packageData) then
      return nil, "Class State WeakAura leaf could not be locked to 38x38 at X 0 / Y 0"
    end
    packageData.beta11StateGeometry = {
      width = STATE_ICON_SIZE,
      height = STATE_ICON_SIZE,
      x = STATE_CHILD_X,
      y = STATE_CHILD_Y,
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
    -- Rebuild State from scratch so stale/manual offsets from earlier betas
    -- cannot survive WeakAuras' update path.
    if className then DeleteWeakAuraTree("RetreatUI - " .. tostring(className) .. " — State") end
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
    local stateGroup = stateID and WeakAuras and WeakAuras.GetData and WeakAuras.GetData(stateID)
    if not stateGroup then return false, "Class State WeakAura group is missing" end
    for _, childID in ipairs(stateGroup.controlledChildren or {}) do
      local child = WeakAuras.GetData(childID)
      if not child
        or (tonumber(child.width) or 0) ~= STATE_ICON_SIZE
        or (tonumber(child.height) or 0) ~= STATE_ICON_SIZE
        or (tonumber(child.xOffset) or 0) ~= STATE_CHILD_X
        or (tonumber(child.yOffset) or 0) ~= STATE_CHILD_Y then
        return false, "State/Form icon must be 38x38 at X 0 / Y 0"
      end
    end
    return true, tostring(CurrentClass(self, className)) .. " WeakAura HUD verified"
  end
end

RUI._weakAuraBeta11FixesLoaded = true
RUI._weakAuraBeta11FixesRevision = 1
