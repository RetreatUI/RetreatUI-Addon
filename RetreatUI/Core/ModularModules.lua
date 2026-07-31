local RUI = RetreatUI
if not RUI then return end

-- Modular installer registry. Every visible component is optional and owns its
-- own dependency check. Missing addons skip only the affected component.

RUI.moduleOrder = {
  "unitframes",
  "classHUD",
  "partyTrackers",
  "trinketHUD",
  "buffManager",
  "nameplates",
  "npcTracking",
  "details",
  "dbm",
  "gameSettings",
  "cleanup",
}
RUI.installerDependencies = {}

local function DB()
  local db = RUI:EnsureDB()
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  return db
end

local function AddOnAvailable(...)
  for index=1,select("#",...) do
    local name=select(index,...)
    if name and RUI.IsAddOnAvailable and RUI:IsAddOnAvailable(name) then return true end
    if name and GetAddOnInfo and GetAddOnInfo(name) ~= nil then return true end
  end
  return false
end

local function MigrateSelections()
  local selections = DB().installer.moduleSelections
  local mapping = {
    unitframes="elvui",
    nameplates="turboplates",
    npcTracking="mobspells",
    gameSettings="cvars",
  }
  for newKey,oldKey in pairs(mapping) do
    if selections[newKey] == nil and selections[oldKey] ~= nil then selections[newKey]=selections[oldKey] end
  end
end
MigrateSelections()

local function ClassHUDReady()
  if not AddOnAvailable("RetreatUI_Classes") then return false, "RetreatUI Classes is not installed" end
  if type(RUI.ScanSpellbook)=="function" then pcall(RUI.ScanSpellbook,RUI) end
  local className=type(RUI.GetDetectedClass)=="function" and RUI:GetDetectedClass() or nil
  local definition=className and RUI.classRegistry and RUI.classRegistry[className]
  local database=className and RUI.spellDatabase and RUI.spellDatabase[className]
  local module=className and RUI.classModules and RUI.classModules[className]
  if not className or not definition or definition.ready~=true or not database or not module or type(module.activate)~="function" then
    return false, "No supported class HUD is available for this character"
  end
  return true
end

local function Register(key, definition)
  definition.required=false
  definition.selectable=true
  definition.defaultEnabled=definition.defaultEnabled~=false
  RUI:RegisterInstallerModule(key,definition)
end

Register("unitframes",{
  label="Unitframes & Layout",
  description="ElvUI player, target, party, raid, castbars and frame positions.",
  icon="Interface\\Icons\\INV_Misc_Note_05",
  dependencies={"ElvUI"},
  available=function() return AddOnAvailable("ElvUI") end,
  missing="Requires the official Ascension ElvUI",
  install=function(self) return self:InstallElvUIProfile() end,
  disable=function() return true,"ElvUI profile changes are no longer managed by RetreatUI" end,
  validate=function(self)
    if type(ElvDB)~="table" or type(ElvDB.profiles)~="table" or type(ElvDB.profiles.RetreatUI)~="table" then
      return false,"The RetreatUI ElvUI profile is missing"
    end
    return true
  end,
})

Register("classHUD",{
  label="Class HUD",
  description="Abilities, class resources, procs and target debuffs.",
  icon=function(self) return self:GetTheme().installer.icon end,
  dependencies={"RetreatUI_Classes"},
  available=function() return ClassHUDReady() end,
  missing="Requires RetreatUI Classes and a supported class",
  install=function(self)
    local db=self:EnsureDB(); db.features.classHUD=true
    local ok,mode=self:ActivateClassHUD(true)
    if not ok or mode~="complete" then return false,"Class HUD could not be activated ("..tostring(mode or "unknown")..")" end
    return true,tostring(self:GetDetectedClass()).." HUD activated"
  end,
  disable=function(self)
    local db=self:EnsureDB(); db.features.classHUD=false
    if self.activeModule and type(self.activeModule.deactivate)=="function" then pcall(self.activeModule.deactivate,self.activeModule)
    elseif type(self.DeactivateAllHUD)=="function" then pcall(self.DeactivateAllHUD,self) end
    return true,"Class HUD disabled"
  end,
  validate=function(self)
    return self.activeModule~=nil,"The class HUD did not initialize"
  end,
})

Register("partyTrackers",{
  label="Party Trackers",
  description="Interrupts, combat res, dispels, externals and group defensives.",
  icon="Interface\\Icons\\Spell_Frost_IceShock",
  install=function(self)
    local db=self:EnsureDB()
    db.features.partyUtility=true; db.features.partyInterrupts=true
    db.partyUtility=db.partyUtility or {}; db.partyUtility.enabled=true
    db.partyInterrupts=db.partyInterrupts or {}; db.partyInterrupts.enabled=true
    if type(self.InitializePartyUtilityTracker)=="function" then self:InitializePartyUtilityTracker() end
    if type(self.RefreshPartyUtility)=="function" then self:RefreshPartyUtility() end
    return true,"Party cooldown and interrupt trackers enabled"
  end,
  disable=function(self)
    local db=self:EnsureDB()
    db.features.partyUtility=false; db.features.partyInterrupts=false
    db.partyUtility=db.partyUtility or {}; db.partyUtility.enabled=false
    db.partyInterrupts=db.partyInterrupts or {}; db.partyInterrupts.enabled=false
    if type(self.RefreshPartyUtility)=="function" then pcall(self.RefreshPartyUtility,self) end
    local frame=_G.RetreatUIPartyInterruptTracker; if frame then frame:Hide() end
    return true,"Party trackers disabled"
  end,
  validate=function(self)
    return self._partyUtilityV4Loaded==true,"Party Utility v4 did not load"
  end,
})

Register("trinketHUD",{
  label="Trinket HUD",
  description="Equipped trinket cooldowns and active proc durations.",
  icon="Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
  install=function(self)
    local db=self:EnsureDB(); db.features.trinketTracker=true
    db.trinketTracker=db.trinketTracker or {}; db.trinketTracker.enabled=true
    if type(self.InitializeTrinketTracker)=="function" then self:InitializeTrinketTracker() end
    if type(self.RefreshTrinketTracker)=="function" then self:RefreshTrinketTracker(true) end
    return true,"Trinket HUD enabled"
  end,
  disable=function(self)
    local db=self:EnsureDB(); db.features.trinketTracker=false
    db.trinketTracker=db.trinketTracker or {}; db.trinketTracker.enabled=false
    if type(self.RefreshTrinketTracker)=="function" then pcall(self.RefreshTrinketTracker,self,true) end
    local frame=_G.RetreatUITrinketTracker; if frame then frame:Hide() end
    return true,"Trinket HUD disabled"
  end,
})

Register("buffManager",{
  label="Buff Manager",
  description="Compact buff assignments, Smart Buff and keybinds.",
  icon="Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
  install=function(self)
    local db=self:EnsureDB(); db.features.buffManager2=true; db.features.buffManagerKeybinds=true
    db.buffManager=db.buffManager or {}; db.buffManager.barShown=true
    local frame=_G.RetreatUIBuffBar; if frame then frame:Show() end
    return true,"Buff Manager enabled"
  end,
  disable=function(self)
    local db=self:EnsureDB(); db.features.buffManager2=false; db.features.buffManagerKeybinds=false
    db.buffManager=db.buffManager or {}; db.buffManager.barShown=false
    for _,name in ipairs({"RetreatUIBuffBar","RetreatUIBuffAssignmentManager","RetreatUIBuffKeybindManager"}) do
      local frame=_G[name]; if frame then frame:Hide() end
    end
    return true,"Buff Manager disabled"
  end,
})

Register("nameplates",{
  label="Nameplates",
  description="RetreatUI TurboPlates profile without NPC spell tracking.",
  icon="Interface\\Icons\\Ability_Warrior_BattleShout",
  dependencies={"TurboPlates"},
  available=function() return AddOnAvailable("TurboPlates") end,
  missing="Requires TurboPlates v1.4.5",
  install=function(self) return self:InstallTurboPlatesProfile() end,
  disable=function() return true,"TurboPlates profile changes are no longer managed by RetreatUI" end,
  validate=function(self)
    local db=self:EnsureDB(); local runtime=db.integrations and db.integrations.turboRuntime
    return type(TurboPlatesDB)=="table" and runtime~=nil,"TurboPlates settings were not applied"
  end,
})

Register("npcTracking",{
  label="NPC Ability Tracking",
  description="Enemy ability names and cooldowns on TurboPlates.",
  icon="Interface\\Icons\\Spell_Arcane_Arcane01",
  dependencies={"TurboPlates","MobSpells"},
  available=function() return AddOnAvailable("TurboPlates") and AddOnAvailable("MobSpells") end,
  missing="Requires TurboPlates and MobSpells v1.3",
  install=function(self)
    local loaded=self:EnsureAddOnLoaded("MobSpells")
    if not loaded or type(MobSpellsDB)~="table" then return false,"MobSpells could not be loaded" end
    local applied,message=self:ApplyMobSpellsToTurboPlates(); if not applied then return false,message end
    local initialized,initMessage=self:InitializeNPCSpellCooldowns(); if not initialized then return false,initMessage end
    local db=self:EnsureDB(); db.features.npcAbilityTracking=true
    return true,"NPC ability and cooldown tracking enabled"
  end,
  disable=function(self)
    local db=self:EnsureDB(); db.features.npcAbilityTracking=false
    if db.integrations then
      if db.integrations.mobSpells then db.integrations.mobSpells.enabled=false end
      if db.integrations.npcSpellCooldowns then db.integrations.npcSpellCooldowns.enabled=false end
    end
    return true,"NPC ability tracking disabled"
  end,
})

Register("details",{
  label="Details! Profile",
  description="RetreatUI meter layout, fonts and positioning.",
  icon="Interface\\Icons\\INV_Misc_Book_09",
  dependencies={"Details!"},
  available=function() return AddOnAvailable("Details") end,
  missing="Requires Details!",
  install=function(self) return self:InstallDetailsProfile() end,
  disable=function() return true,"Details profile changes are no longer managed by RetreatUI" end,
  validate=function(self) return self:ValidateDetailsProfile() end,
})

Register("dbm",{
  label="DBM Theme",
  description="RetreatUI styling for Deadly Boss Mods.",
  icon="Interface\\Icons\\Ability_Warrior_RallyingCry",
  defaultEnabled=false,
  dependencies={"DBM"},
  available=function() return AddOnAvailable("DBM-Core","DBM") end,
  missing="DBM is not installed",
  install=function(self) return self:ApplyDBMTheme() end,
  disable=function() return true,"DBM theme changes are no longer managed by RetreatUI" end,
})

Register("gameSettings",{
  label="Game Settings",
  description="CVars and RetreatUI combat-text preferences.",
  icon="Interface\\Icons\\INV_Misc_Gear_01",
  install=function(self)
    local ok,message=self:ApplyCVars()
    if ok==false then return false,message end
    if type(self.ApplyCombatTextStyle)=="function" then pcall(self.ApplyCombatTextStyle,self) end
    return true,"Game settings applied"
  end,
  disable=function() return true,"Game settings will no longer be changed by RetreatUI" end,
})

Register("cleanup",{
  label="Ascension Cleanup",
  description="Hide duplicate Ascension frames and overlapping UI elements.",
  icon="Interface\\Icons\\INV_Misc_Broom_01",
  install=function(self) return self:HideDuplicateFrames() end,
  disable=function(self)
    local db=self:EnsureDB(); db.features.ascensionCleanup=false
    return true,"Ascension cleanup disabled for future refreshes"
  end,
  validate=function(self)
    local db=self:EnsureDB(); local cleanup=db.integrations and db.integrations.frameCleanup
    return cleanup~=nil,"Frame cleanup did not complete"
  end,
})

function RUI:GetInstallerModuleAvailability(key)
  local definition=self.moduleInstallers and self.moduleInstallers[key]
  if not definition then return false,"Module not registered" end
  if not definition.available then return true end
  local ok,available,reason=pcall(definition.available,self)
  if not ok then return false,tostring(available) end
  return available==true, reason or definition.missing
end

function RUI:GetInstallerReadiness()
  return true,{}
end

function RUI:InstallModule(key)
  local definition=self.moduleInstallers and self.moduleInstallers[key]
  if not definition then return self:SetModuleStatus(key,"error","Module not registered") end
  local enabled=self:IsInstallerModuleEnabled(key)
  if not enabled then
    if type(definition.disable)=="function" then
      local ok,value,message=pcall(definition.disable,self)
      if not ok or value==false then return self:SetModuleStatus(key,"error",message or value or "Could not disable module") end
    end
    return self:SetModuleStatus(key,"skipped","Disabled by user")
  end
  local available,reason=self:GetInstallerModuleAvailability(key)
  if not available then return self:SetModuleStatus(key,"skipped",reason or definition.missing or "Dependency missing") end
  local ok,value,message=pcall(definition.install,self)
  if not ok then return self:SetModuleStatus(key,"error",value) end
  if value==false then return self:SetModuleStatus(key,"error",message or "Installation failed") end
  if definition.validate then
    local valid,validationMessage=definition.validate(self)
    if not valid then return self:SetModuleStatus(key,"error",validationMessage or "Validation failed") end
  end
  return self:SetModuleStatus(key,"success",message or definition.success or "Installed")
end

function RUI:ValidateInstallation()
  local problems={}
  for _,key in ipairs(self.moduleOrder or {}) do
    local definition=self.moduleInstallers[key]
    if definition and self:IsInstallerModuleEnabled(key) then
      local available=self:GetInstallerModuleAvailability(key)
      local record=self:GetModuleStatus(key)
      if available and (not record or record.version~=self.version or record.state~="success") then
        problems[#problems+1]=definition.label.." has not been installed for this version"
      elseif record and record.version==self.version and record.state=="error" then
        problems[#problems+1]=definition.label..": "..tostring(record.message or "failed")
      end
    end
  end
  return #problems==0,problems
end

function RUI:GetOptionalIntegrationWarnings()
  local warnings={}
  for _,key in ipairs(self.moduleOrder or {}) do
    local definition=self.moduleInstallers[key]
    if definition and self:IsInstallerModuleEnabled(key) then
      local available,reason=self:GetInstallerModuleAvailability(key)
      local record=self:GetModuleStatus(key)
      if not available then warnings[#warnings+1]=definition.label..": "..tostring(reason or definition.missing or "dependency missing")
      elseif record and record.version==self.version and record.state=="skipped" then warnings[#warnings+1]=definition.label..": "..tostring(record.message or "skipped") end
    end
  end
  return warnings
end

function RUI:InstallAllModules(progressCallback)
  if InCombatLockdown and InCombatLockdown() then return false,{"Leave combat before running the installer."} end
  local db=self:EnsureDB(); db.installer.lastAttemptVersion=self.version; db.installer.lastAttemptOK=false
  local errors={}
  for _,key in ipairs(self.moduleOrder or {}) do
    local definition=self.moduleInstallers[key]
    if progressCallback then progressCallback(key,self:IsInstallerModuleEnabled(key) and "running" or "skipped",definition) end
    local record=self:InstallModule(key)
    if progressCallback then progressCallback(key,record.state,definition,record) end
    if record.state=="error" then errors[#errors+1]=definition.label..": "..tostring(record.message or "failed") end
  end
  if type(self.SyncThemeFonts)=="function" then pcall(self.SyncThemeFonts,self) end
  db.installer.lastAttemptOK=#errors==0
  return #errors==0,errors
end

function RUI:ApplyInstallerPreset(preset)
  local selections=DB().installer.moduleSelections
  local selected={}
  if preset=="full" then
    for _,key in ipairs(self.moduleOrder) do selected[key]=true end
    selected.dbm=AddOnAvailable("DBM-Core","DBM")
    if not ClassHUDReady() then selected.classHUD=false end
  elseif preset=="hud" then
    selected={classHUD=true,partyTrackers=true,trinketHUD=true,buffManager=true}
    if not ClassHUDReady() then selected.classHUD=false end
  elseif preset=="layout" then
    selected={unitframes=true,nameplates=true,npcTracking=true,details=true,dbm=AddOnAvailable("DBM-Core","DBM"),gameSettings=true,cleanup=true}
  elseif preset=="clear" then
    selected={}
  else
    return false
  end
  for _,key in ipairs(self.moduleOrder) do selections[key]=selected[key]==true end
  return true
end

RUI._modularModulesLoaded=true
