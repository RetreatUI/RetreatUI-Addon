local RUI = RetreatUI
if not RUI then return end

-- CoA HUD migration switch. Native class HUD modules stay loaded as data and
-- compatibility providers, but their visible CreateFrame renderers are no
-- longer activated. WeakAuras owns the complete central combat HUD.
RUI.weakAuraHUDMode = true

local nativeInitializeTrinketTracker = RUI.InitializeTrinketTracker
RUI._nativeInitializeTrinketTracker = RUI._nativeInitializeTrinketTracker or nativeInitializeTrinketTracker

local function WeakAurasAvailable(self, loadNow)
  if loadNow and type(self.EnsureAddOnLoaded) == "function" then
    self:EnsureAddOnLoaded("WeakAuras")
  end
  return WeakAuras and type(WeakAuras.Add) == "function" and type(WeakAuras.GetData) == "function"
end

local function HideNativeTrinketFrame()
  local tracker = _G.RetreatUITrinketTracker
  if tracker then
    if tracker.Hide then pcall(tracker.Hide, tracker) end
    if tracker.SetAlpha then pcall(tracker.SetAlpha, tracker, 0) end
    if tracker.EnableMouse then pcall(tracker.EnableMouse, tracker, false) end
  end
end

-- The General WeakAura package now owns trinkets. Keep the old engine source in
-- the addon for rollback/reference, but never start its visible runtime.
function RUI:InitializeTrinketTracker()
  HideNativeTrinketFrame()
  return true, "General WeakAuras own the trinket HUD"
end

local function PrepareModuleForWeakAuras(self, module)
  if type(module) ~= "table" then return end
  if module._nativeCustomResourcesComplete == nil then
    module._nativeCustomResourcesComplete = module.customResourcesComplete
  end
  module.customResourcesComplete = function()
    return self.weakAuraHUDMode == true and self.weakAuraResourceReady == true
  end
end

function RUI:ActivateClassHUD(force)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    return false, "unsupported"
  end
  local className = self.GetDetectedClass and self:GetDetectedClass() or nil
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  local module = className and self.GetClassModule and self:GetClassModule(className) or nil
  if not className or not module or module.ready == false then return false, "missing-module" end
  if not WeakAurasAvailable(self, true) then return false, "WeakAuras is required" end

  -- Ensure legacy native renderers cannot coexist with the WeakAura HUD.
  if type(self.DeactivatePrimaryPower) == "function" then pcall(self.DeactivatePrimaryPower, self) end
  if type(self.StopHUDVisibilityDriver) == "function" then pcall(self.StopHUDVisibilityDriver, self) end
  HideNativeTrinketFrame()
  PrepareModuleForWeakAuras(self, module)

  self.activeClass = className
  self.activeModule = module

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.coaWeakAuraHUD = db.integrations.coaWeakAuraHUD or {}
  local record = db.integrations.coaWeakAuraHUD[className]
  local installed = record and record.version == self.version
    and type(self.IsWeakAuraHUDInstalled) == "function"
    and self:IsWeakAuraHUDInstalled(className)

  if not installed then
    if type(self.InstallWeakAuraHUD) ~= "function" then return false, "WeakAura HUD package did not load" end
    local ok, message = self:InstallWeakAuraHUD(className, force)
    if not ok then return false, message or "WeakAura HUD installation failed" end
  else
    if type(self.PrimeWeakAuraResourceSource) == "function" then pcall(self.PrimeWeakAuraResourceSource, self, className) end
  end

  if type(self.ScheduleNativeClassResourceCleanup) == "function" then
    self:After(0.10, function() self:ScheduleNativeClassResourceCleanup(true) end)
  end
  return true, "complete"
end

-- No native central HUD was activated, so deactivation only clears compatibility
-- state and the legacy primary-power frame. WeakAura regions manage visibility
-- from their own triggers and current-class checks.
function RUI:DeactivateAllHUD()
  if type(self.DeactivatePrimaryPower) == "function" then pcall(self.DeactivatePrimaryPower, self) end
  if type(self.StopHUDVisibilityDriver) == "function" then pcall(self.StopHUDVisibilityDriver, self) end
  HideNativeTrinketFrame()
  self.activeClass = nil
  self.activeModule = nil
  self.weakAuraResourceReady = false
  return true
end

-- WeakAuras is now a required dependency of the Class HUD installer.
local hasDependency = false
for _, dependency in ipairs(RUI.installerDependencies or {}) do
  if dependency.key == "weakauras" then hasDependency = true; dependency.required = true; break end
end
if not hasDependency then
  RUI.installerDependencies[#RUI.installerDependencies + 1] = {
    key = "weakauras", label = "WeakAuras", names = {"WeakAuras"}, required = true,
  }
end

local classInstaller = RUI.moduleInstallers and RUI.moduleInstallers.classHUD
if classInstaller then
  classInstaller.label = "Class WeakAuras HUD"
  classInstaller.missing = "WeakAuras or the detected RetreatUI class data is not available"
  classInstaller.available = function(self)
    if type(self.ScanSpellbook) == "function" then pcall(self.ScanSpellbook, self) end
    local className = self.GetDetectedClass and self:GetDetectedClass() or nil
    local definition = className and self.classRegistry and self.classRegistry[className]
    local database = className and self.spellDatabase and self.spellDatabase[className]
    local module = className and self.classModules and self.classModules[className]
    return WeakAurasAvailable(self, false)
      and definition ~= nil and definition.ready == true
      and database ~= nil and module ~= nil and module.ready ~= false
  end
  classInstaller.install = function(self)
    if type(self.ScanSpellbook) == "function" then pcall(self.ScanSpellbook, self) end
    local className = self:GetDetectedClass()
    local ok, mode = self:ActivateClassHUD(true)
    if not ok or mode ~= "complete" then
      return false, tostring(className) .. " WeakAura HUD could not be installed (" .. tostring(mode or "unknown") .. ")"
    end
    return true, tostring(className) .. " HUD installed in WeakAuras"
  end
  classInstaller.validate = function(self)
    local className = self:GetDetectedClass()
    if type(self.ValidateWeakAuraHUD) ~= "function" then return false, "WeakAura HUD validation is unavailable" end
    return self:ValidateWeakAuraHUD(className)
  end
end

RUI._weakAuraHUDMigrationLoaded = true
RUI._weakAuraHUDMigrationRevision = 1
