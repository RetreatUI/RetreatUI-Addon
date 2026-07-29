local RUI = RetreatUI

RUI.moduleInstallers = {}
RUI.moduleOrder = {"elvui", "classHUD", "turboplates", "mobspells", "cvars", "fonts", "cleanup", "details", "dbm"}

RUI.installerDependencies = {
  {key="classes", label="RetreatUI Classes", names={"RetreatUI_Classes"}, required=true, matchCoreVersion=true, hidden=true},
  {key="elvui", label="ElvUI", names={"ElvUI"}, required=true},
  {key="turboplates", label="TurboPlates v1.4.5", names={"TurboPlates"}, required=true},
  {key="mobspells", label="MobSpells v1.3", names={"MobSpells"}, required=true},
  {key="details", label="Details!", names={"Details"}, required=true},
  {key="dbm", label="Deadly Boss Mods", names={"DBM-Core", "DBM"}, required=false},
}

function RUI:RegisterInstallerModule(key, definition)
  if type(key) ~= "string" or type(definition) ~= "table" then return false end
  definition.key = key
  definition.required = definition.required == true
  self.moduleInstallers[key] = definition
  return true
end

function RUI:IsInstallerModuleEnabled(key)
  local definition = self.moduleInstallers[key]
  if definition and definition.selectable == false then return true end
  local db = self:EnsureDB()
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  local selected = db.installer.moduleSelections[key]
  if selected == nil then
    selected = definition == nil or definition.defaultEnabled ~= false
    db.installer.moduleSelections[key] = selected
  end
  return selected ~= false
end

function RUI:SetInstallerModuleEnabled(key, enabled)
  local definition = self.moduleInstallers[key]
  if definition and definition.selectable == false then return true end
  local db = self:EnsureDB()
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  db.installer.moduleSelections[key] = enabled ~= false
  return db.installer.moduleSelections[key]
end

function RUI:GetModuleStatusKey(key)
  if key == "classHUD" then return key .. ":" .. tostring(self:GetDetectedClass()) end
  return key
end

function RUI:GetModuleStatus(key)
  local db = self:EnsureDB()
  return db.moduleStatus[self:GetModuleStatusKey(key)]
end

function RUI:SetModuleStatus(key, state, message)
  if type(state) == "boolean" then state = state and "success" or "error" end
  if state ~= "success" and state ~= "error" and state ~= "skipped" then state = "error" end
  local db = self:EnsureDB()
  local record = {
    state = state,
    ok = state == "success",
    skipped = state == "skipped",
    message = tostring(message or ""),
    version = self.version,
    className = key == "classHUD" and self:GetDetectedClass() or nil,
    time = date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or 0),
  }
  db.moduleStatus[self:GetModuleStatusKey(key)] = record
  return record
end

function RUI:GetDependencyStatus(dependency, loadNow)
  local names = dependency and dependency.names
  if type(names) ~= "table" then return false, "Invalid dependency" end
  for _, name in ipairs(names) do
    local loaded = IsAddOnLoaded and IsAddOnLoaded(name)
    local available = loaded or (GetAddOnInfo and GetAddOnInfo(name) ~= nil)
    if available then
      if dependency.matchCoreVersion and GetAddOnMetadata then
        local dependencyVersion = GetAddOnMetadata(name, "Version")
        if tostring(dependencyVersion or "") ~= tostring(self.version or "") then
          return false, "Version mismatch"
        end
      end
      if loaded then return true, "Loaded" end
      if loadNow then
        if not LoadAddOn then return false, "Could not load" end
        pcall(LoadAddOn, name)
        if IsAddOnLoaded and IsAddOnLoaded(name) then return true, "Loaded" end
        return false, "Could not load"
      end
      return true, "Available"
    end
  end
  return false, "Missing"
end

function RUI:GetInstallerReadiness(loadNow)
  local missing = {}
  for _, dependency in ipairs(self.installerDependencies or {}) do
    if dependency.required then
      local available = self:GetDependencyStatus(dependency, loadNow)
      if not available then missing[#missing + 1] = dependency.label end
    end
  end
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    local detected = type(self.GetDetectedClass) == "function" and self:GetDetectedClass() or "current character"
    missing[#missing + 1] = "Supported class module for " .. tostring(detected)
  end
  return #missing == 0, missing
end

function RUI:InstallModule(key)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    return self:SetModuleStatus(key, "error", self:GetUnsupportedMessage())
  end

  local definition = self.moduleInstallers[key]
  if not definition then return self:SetModuleStatus(key, "error", "Module not registered") end
  if not self:IsInstallerModuleEnabled(key) then
    return self:SetModuleStatus(key, "skipped", "Disabled by user")
  end

  if definition.available and not definition.available(self) then
    if definition.required then
      return self:SetModuleStatus(key, "error", definition.missing or "Required addon is missing")
    end
    return self:SetModuleStatus(key, "skipped", definition.missing or "Optional addon is not installed")
  end

  local ok, value, message = pcall(definition.install, self)
  if not ok then return self:SetModuleStatus(key, "error", value) end
  if value == false then return self:SetModuleStatus(key, "error", message or "Installation failed") end

  if definition.validate then
    local valid, validationMessage = definition.validate(self)
    if not valid then return self:SetModuleStatus(key, "error", validationMessage or "Validation failed") end
  end

  return self:SetModuleStatus(key, "success", message or definition.success or "Installed")
end

function RUI:ValidateInstallation()
  local ready, missing = self:GetInstallerReadiness(false)
  local problems = {}
  if not ready then
    for _, label in ipairs(missing) do problems[#problems + 1] = label .. " is missing" end
  end

  for _, key in ipairs(self.moduleOrder) do
    local definition = self.moduleInstallers[key]
    if definition and definition.required and self:IsInstallerModuleEnabled(key) then
      local record = self:GetModuleStatus(key)
      if not record or record.version ~= self.version or record.state ~= "success" then
        problems[#problems + 1] = definition.label .. " was not installed successfully"
      elseif definition.validate then
        local valid, message = definition.validate(self)
        if not valid then problems[#problems + 1] = message or (definition.label .. " failed validation") end
      end
    end
  end

  return #problems == 0, problems
end

function RUI:GetOptionalIntegrationWarnings()
  local warnings = {}
  for _, key in ipairs(self.moduleOrder) do
    local definition = self.moduleInstallers[key]
    if definition and not definition.required then
      local record = self:GetModuleStatus(key)
      if record and record.version == self.version and record.state == "error" then
        warnings[#warnings + 1] = definition.label .. ": " .. tostring(record.message or "failed")
      end
    end
  end
  return warnings
end

function RUI:InstallAllModules(progressCallback)
  if InCombatLockdown and InCombatLockdown() then
    return false, {"Leave combat before running the installer."}
  end

  local ready, missing = self:GetInstallerReadiness(true)
  if not ready then
    local problems = {}
    for _, label in ipairs(missing) do problems[#problems + 1] = label .. " is missing" end
    return false, problems
  end

  local db = self:EnsureDB()
  db.installer.lastAttemptVersion = self.version
  db.installer.lastAttemptOK = false

  for _, key in ipairs(self.moduleOrder) do
    local definition = self.moduleInstallers[key]
    if self:IsInstallerModuleEnabled(key) then
      if progressCallback then progressCallback(key, "running", definition) end
    else
      if progressCallback then progressCallback(key, "skipped", definition) end
    end
    local record = self:InstallModule(key)
    if progressCallback then progressCallback(key, record.state, definition, record) end
  end

  local valid, problems = self:ValidateInstallation()
  db.installer.lastAttemptOK = valid
  return valid, problems
end

RUI:RegisterInstallerModule("elvui", {
  label="ElvUI Profile",
  icon="Interface\\Icons\\INV_Misc_Note_05",
  required=true,
  available=function(self) return self:IsAddOnAvailable("ElvUI") end,
  missing="ElvUI is not installed",
  install=function(self) return self:InstallElvUIProfile() end,
  validate=function(self)
    if type(ElvDB) ~= "table" or type(ElvDB.profiles) ~= "table" or type(ElvDB.profiles.RetreatUI) ~= "table" then
      return false, "The RetreatUI ElvUI profile is missing"
    end
    if type(self.AreElvUINamePlatesDisabled) == "function" and not self:AreElvUINamePlatesDisabled() then
      return false, "ElvUI NamePlates could not be disabled for TurboPlates"
    end
    return true
  end,
})

RUI:RegisterInstallerModule("classHUD", {
  label="Class HUD",
  selectable=false,
  icon=function(self) return self:GetTheme().installer.icon end,
  required=true,
  available=function(self)
    -- The HUD is an internal RetreatUI module, not an external addon. Check the
    -- complete class registration chain directly so a valid Bloodmage module is
    -- never reported as UNAVAILABLE merely because an optional API is missing.
    if type(self.ScanSpellbook) == "function" then pcall(self.ScanSpellbook, self) end
    local className = type(self.GetDetectedClass) == "function" and self:GetDetectedClass() or nil
    local definition = className and self.classRegistry and self.classRegistry[className]
    local database = className and self.spellDatabase and self.spellDatabase[className]
    local module = className and self.classModules and self.classModules[className]
    return definition ~= nil
      and definition.ready == true
      and database ~= nil
      and module ~= nil
      and module.ready ~= false
      and type(module.activate) == "function"
  end,
  missing="The detected RetreatUI class HUD module did not finish loading",
  install=function(self)
    if type(self.ScanSpellbook) == "function" then pcall(self.ScanSpellbook, self) end
    local className = self:GetDetectedClass()
    local module = self.GetClassModule and self:GetClassModule(className) or (self.classModules and self.classModules[className])
    if not module or type(module.activate) ~= "function" then
      return false, tostring(className) .. " HUD module is not registered"
    end
    local ok, mode = self:ActivateClassHUD(true)
    if not ok or mode ~= "complete" then
      return false, tostring(className) .. " HUD could not be activated (" .. tostring(mode or "unknown") .. ")"
    end
    return true, tostring(className) .. " HUD activated"
  end,
  validate=function(self)
    local module = self.activeModule
    if not module then return false, "The class HUD did not initialize" end
    if module.frameName and not _G[module.frameName] then
      return false, tostring(self.activeClass or "Class") .. " HUD frame is missing"
    end
    return true
  end,
})

RUI:RegisterInstallerModule("turboplates", {
  label="TurboPlates Profile",
  icon="Interface\\Icons\\Ability_Warrior_BattleShout",
  required=true,
  available=function(self) return self:IsAddOnAvailable("TurboPlates") end,
  missing="TurboPlates is not installed",
  install=function(self) return self:InstallTurboPlatesProfile() end,
  validate=function(self)
    local db = self:EnsureDB()
    local runtime = db.integrations and db.integrations.turboRuntime
    return type(TurboPlatesDB) == "table" and runtime and runtime.version == self.version,
      "TurboPlates settings were not applied"
  end,
})

RUI:RegisterInstallerModule("mobspells", {
  label="NPC Ability Tracking",
  icon="Interface\\Icons\\Spell_Arcane_Arcane01",
  required=true,
  available=function(self) return self:IsAddOnAvailable("MobSpells") end,
  missing="MobSpells v1.3 is not installed",
  install=function(self)
    local loaded = self:EnsureAddOnLoaded("MobSpells")
    if not loaded or type(MobSpellsDB) ~= "table" then return false, "MobSpells could not be loaded" end
    local applied, applyMessage = self:ApplyMobSpellsToTurboPlates()
    if not applied then return false, applyMessage end
    local initialized, initMessage = self:InitializeNPCSpellCooldowns()
    if not initialized then return false, initMessage end
    return true, "MobSpells ability and cooldown tracking enabled"
  end,
  validate=function(self)
    local db = self:EnsureDB()
    local a = db.integrations and db.integrations.mobSpells
    local b = db.integrations and db.integrations.npcSpellCooldowns
    return type(MobSpellsDB) == "table" and a and a.version == self.version and b and b.version == self.version,
      "NPC ability tracking was not initialized"
  end,
})

RUI:RegisterInstallerModule("cvars", {
  label="Game Settings",
  icon="Interface\\Icons\\INV_Misc_Gear_01",
  required=true,
  install=function(self) return self:ApplyCVars() end,
})

RUI:RegisterInstallerModule("fonts", {
  label="Fonts & Theme",
  icon="Interface\\Icons\\INV_Inscription_Tradeskill01",
  required=true,
  install=function(self) return self:SyncThemeFonts() end,
})

RUI:RegisterInstallerModule("cleanup", {
  label="Ascension Frame Cleanup",
  icon="Interface\\Icons\\INV_Misc_Broom_01",
  required=true,
  install=function(self) return self:HideDuplicateFrames() end,
  validate=function(self)
    local db = self:EnsureDB()
    local cleanup = db.integrations and db.integrations.frameCleanup
    return cleanup and cleanup.version == self.version, "Frame cleanup did not complete"
  end,
})

RUI:RegisterInstallerModule("details", {
  label="Details! Profile",
  icon="Interface\\Icons\\INV_Misc_Book_09",
  required=true,
  available=function(self) return self:IsAddOnAvailable("Details") end,
  missing="Details! is required and is not installed",
  install=function(self) return self:InstallDetailsProfile() end,
  validate=function(self) return self:ValidateDetailsProfile() end,
})

RUI:RegisterInstallerModule("dbm", {
  label="DBM Theme",
  icon="Interface\\Icons\\Ability_Warrior_RallyingCry",
  required=false,
  available=function(self) return self:IsAddOnAvailable("DBM-Core") or self:IsAddOnAvailable("DBM") end,
  missing="DBM is not installed; integration skipped",
  install=function(self) return self:ApplyDBMTheme() end,
})
