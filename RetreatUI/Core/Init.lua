local ADDON_NAME = ...

RetreatUI = RetreatUI or {}
local RUI = RetreatUI

RUI.name = RUI.name or "RetreatUI"
RUI.author = "Retreat"
RUI.schema = 3
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
  db.version = db.version or {}
  db.moduleStatus = db.moduleStatus or {}
  db.class = db.class or {}
  db.integrations = db.integrations or {}
  db.hiddenFrames = db.hiddenFrames or {}
  db.spellDiscovery = db.spellDiscovery or {}

  if previousSchema < 3 then RemoveRetiredData(db) end
  db.schema = self.schema
  return db
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
