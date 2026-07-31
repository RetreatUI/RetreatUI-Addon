local ADDON_NAME = ...

RetreatUI = RetreatUI or {}
local RUI = RetreatUI

RUI.name = RUI.name or "RetreatUI"
RUI.author = "Retreat"
RUI.schema = 10
RUI.modules = RUI.modules or {}
RUI.classModules = RUI.classModules or {}
RUI.providers = RUI.providers or {}
RUI.activeClass = nil
RUI.activeModule = nil
RUI._scheduled = RUI._scheduled or {}

local scheduler = CreateFrame("Frame")
scheduler:Hide()
scheduler:SetScript("OnUpdate", function(self, elapsed)
  for index = #RUI._scheduled, 1, -1 do
    local item = RUI._scheduled[index]
    item.remaining = item.remaining - elapsed
    if item.remaining <= 0 then
      table.remove(RUI._scheduled, index)
      local ok, err = pcall(item.callback)
      if not ok then RUI:Print("Scheduled action failed: " .. tostring(err)) end
    end
  end
  if #RUI._scheduled == 0 then self:Hide() end
end)

function RUI:After(seconds, callback)
  if type(callback) ~= "function" then return false end
  table.insert(self._scheduled, {remaining = tonumber(seconds) or 0, callback = callback})
  scheduler:Show()
  return true
end

function RUI:Print(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5a1fRetreatUI:|r " .. tostring(message))
  end
end

function RUI:DeepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[self:DeepCopy(key, seen)] = self:DeepCopy(child, seen)
  end
  return copy
end

function RUI:ClearTable(tbl)
  if type(tbl) ~= "table" then return end
  for key in pairs(tbl) do tbl[key] = nil end
end

local function RemoveRetiredData(db)
  db.backups = nil
  db.weakAuras = nil
  if type(db.integrations) == "table" then
    db.integrations.turboOriginal = nil
    db.integrations.weakAuras = nil
    db.integrations.weakAuraHUD = nil
    db.integrations.weakAuraMigration = nil
  end
  if type(db.version) == "table" then
    db.version.latestDetected = nil
    db.version.latestSummary = nil
    db.version.notifiedRemoteVersion = nil
  end
end

function RUI:EnsureDB()
  RetreatUIDB = RetreatUIDB or {}
  local db = RetreatUIDB
  local previousSchema = tonumber(db.schema) or 0

  db.installer = db.installer or {}
  if db.installer.initialCompleted == nil and db.installer.completedVersion then
    db.installer.initialCompleted = true
  end
  db.installer.classes = db.installer.classes or {}
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  -- Older builds stored installer completion globally. That made every newly
  -- visited class look preinstalled and forced testers to use /rui reset before
  -- seeing the correct class installer. Schema 4 intentionally starts a clean
  -- per-class completion map while preserving profiles and all other settings.
  if previousSchema < 4 then
    db.installer.classes = {}
    db.installer.classStateMigrationVersion = self.version
  end
  db.version = db.version or {}
  db.moduleStatus = db.moduleStatus or {}
  db.class = db.class or {}
  db.integrations = db.integrations or {}
  db.hiddenFrames = db.hiddenFrames or {}
  db.spellDiscovery = db.spellDiscovery or {}
  db.features = db.features or {}
  if db.features.hudEditor == nil then db.features.hudEditor = true end
  if db.features.buildProfiles == nil then db.features.buildProfiles = true end
  if db.features.partyUtility == nil then db.features.partyUtility = true end
  if db.features.partyInterrupts == nil then db.features.partyInterrupts = true end
  db.features.dangerousAbilities = false
  if db.features.buffManager2 == nil then db.features.buffManager2 = true end
  if db.features.buffManagerKeybinds == nil then db.features.buffManagerKeybinds = true end
  if db.features.trinketTracker == nil then db.features.trinketTracker = true end

  db.trinketTracker = db.trinketTracker or {}
  if db.trinketTracker.enabled == nil then db.trinketTracker.enabled = true end
  db.trinketTracker.auraByItem = db.trinketTracker.auraByItem or {}

  db.partyUtility = db.partyUtility or {}
  if db.partyUtility.enabled == nil then db.partyUtility.enabled = true end
  db.partyUtility.categories = db.partyUtility.categories or {}
  for _, category in ipairs({"interrupt","combatres","dispel","external","defensive","immunity","taunt"}) do
    if db.partyUtility.categories[category] == nil then db.partyUtility.categories[category] = true end
  end
  db.partyUtility.categories.interrupt = false

  db.partyInterrupts = db.partyInterrupts or {}
  if db.partyInterrupts.enabled == nil then db.partyInterrupts.enabled = true end
  if db.partyInterrupts.showSelf == nil then db.partyInterrupts.showSelf = true end
  if db.partyInterrupts.showSolo == nil then db.partyInterrupts.showSolo = false end

  db.dangerousAbilities = nil


  if previousSchema < 3 then RemoveRetiredData(db) end
  db.schema = self.schema
  return db
end


function RUI:GetInstallerClassKey(className)
  className = className or (type(self.GetDetectedClass) == "function" and self:GetDetectedClass()) or "Unknown"
  if type(self.NormalizeClassName) == "function" then className = self:NormalizeClassName(className) or className end
  return tostring(className)
end

function RUI:GetClassInstallRecord(className, create)
  local db = self:EnsureDB()
  db.installer.classes = db.installer.classes or {}
  local key = self:GetInstallerClassKey(className)
  local record = db.installer.classes[key]
  if not record and create then
    record = {}
    db.installer.classes[key] = record
  end
  return record, key
end

function RUI:IsClassInstallCompleted(className)
  local record = self:GetClassInstallRecord(className, false)
  return record ~= nil and record.initialCompleted == true
end

function RUI:MarkClassInstallCompleted(className)
  local record, key = self:GetClassInstallRecord(className, true)
  record.initialCompleted = true
  record.completedVersion = self.version
  record.lastCompletedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or 0)
  local db = self:EnsureDB()
  db.installer.initialCompleted = true
  db.installer.completedVersion = self.version
  db.installer.lastCompletedClass = key
  db.version = db.version or {}
  db.version.lastPopupVersion = self.version
  db.version.lastSeenVersion = self.version
  return record
end

function RUI:ResetClassInstallation(className)
  local db = self:EnsureDB()
  local key = self:GetInstallerClassKey(className)
  if db.installer.classes then db.installer.classes[key] = nil end
  if db.moduleStatus then db.moduleStatus["classHUD:" .. key] = nil end
  return true
end

function RUI:IsAddOnAvailable(name)
  if IsAddOnLoaded and IsAddOnLoaded(name) then return true end
  if GetAddOnInfo then return GetAddOnInfo(name) ~= nil end
  return false
end

function RUI:EnsureAddOnLoaded(names)
  if type(names) == "string" then names = {names} end
  if type(names) ~= "table" then return false, "invalid" end
  local found = false
  for _, name in ipairs(names) do
    if IsAddOnLoaded and IsAddOnLoaded(name) then return true, name end
    if GetAddOnInfo and GetAddOnInfo(name) then
      found = true
      if LoadAddOn then
        pcall(LoadAddOn, name)
        if IsAddOnLoaded and IsAddOnLoaded(name) then return true, name end
      end
    end
  end
  return false, found and "could-not-load" or "missing"
end

RUI._coreLoaded = true
