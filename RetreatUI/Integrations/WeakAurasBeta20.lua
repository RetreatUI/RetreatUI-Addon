local RUI = RetreatUI
if not RUI then return end

-- beta.20 only installs prebuilt !WA:2! payloads. RetreatUI does not create
-- aura tables, triggers, grow logic or synthetic WeakAuras events at runtime.
local CLEANUP_REVISION = 31
local CLASS_NAMES = {
  "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
  "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
  "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
  "Venomancer", "Witch Doctor", "Witch Hunter",
}

local function PayloadRegistry()
  if type(RUI.Beta20WeakAuras) ~= "table" then
    RUI.Beta20WeakAuras = {classes = {}}
  end
  RUI.Beta20WeakAuras.classes = RUI.Beta20WeakAuras.classes or {}
  return RUI.Beta20WeakAuras
end

local function WeakAurasReady()
  return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
end

local function GetData(id)
  if type(id) ~= "string" or id == "" then return nil end
  if type(WeakAuras) ~= "table" or type(WeakAuras.GetData) ~= "function" then return nil end
  local ok, data = pcall(WeakAuras.GetData, id)
  if ok and type(data) == "table" then return data end
  return nil
end

local function IsGeneralRoot(id)
  return id == "RetreatUI - General" or id == "Core & Essentials"
end

local function IsClassRoot(id, className)
  if type(id) ~= "string" or type(className) ~= "string" then return false end
  return id == "RetreatUI - " .. className
    or id == className .. " Class Pack"
    or id == "Aura Bar - " .. className
    or id == "Main - " .. className
    or id == "Resources - " .. className
    or id == "Bars - " .. className
    or id == "Dynamic Bars - " .. className
    or id == "Aux Bar - " .. className
    or id == "Main Row 1 - " .. className
    or id == "Main Row 2 - " .. className
    or id == "Main Row 3 - " .. className
    or id == className .. " - Primary Power"
end

local function DeleteOwnedTree(seedPredicate)
  if type(WeakAuras) ~= "table" or type(WeakAuras.Delete) ~= "function" then return nil end
  local displays = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays or nil
  if type(displays) ~= "table" then return nil end

  local owned = {}
  for id, data in pairs(displays) do
    if type(data) == "table" and seedPredicate(id, data) then owned[id] = true end
  end

  local changed = true
  while changed do
    changed = false
    for id, data in pairs(displays) do
      if type(data) == "table" and type(data.parent) == "string" and owned[data.parent] and not owned[id] then
        owned[id] = true
        changed = true
      end
    end
  end

  local function Depth(id)
    local depth, seen = 0, {}
    local data = displays[id]
    while type(data) == "table" and type(data.parent) == "string" and not seen[data.parent] do
      seen[data.parent] = true
      depth = depth + 1
      data = displays[data.parent]
    end
    return depth
  end

  local ids = {}
  for id in pairs(owned) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return Depth(a) > Depth(b) end)

  local removed = 0
  for _, id in ipairs(ids) do
    local data = GetData(id)
    if data then
      local ok = pcall(WeakAuras.Delete, data)
      if ok then removed = removed + 1 end
    end
  end
  return removed
end

local function CleanupAllBeta20Displays()
  return DeleteOwnedTree(function(id)
    if IsGeneralRoot(id) then return true end
    for _, className in ipairs(CLASS_NAMES) do
      if IsClassRoot(id, className) then return true end
    end
    return false
  end)
end

local function CleanupClassDisplay(className)
  if type(className) ~= "string" or className == "" then return 0 end
  return DeleteOwnedTree(function(id) return IsClassRoot(id, className) end) or 0
end

local function CleanupState()
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  RetreatUIDB.integrations.weakAuras = RetreatUIDB.integrations.weakAuras or {}
  return RetreatUIDB.integrations.weakAuras
end

local function RunOneTimeStartupCleanup()
  local state = CleanupState()
  if tonumber(state.beta20CleanupRevision) == CLEANUP_REVISION then return 0 end

  local removed = CleanupAllBeta20Displays()
  -- nil means WeakAuras/SavedVariables were not available, so do not consume
  -- the migration gate. With WeakAuras enabled as an OptionalDep they are
  -- available before PLAYER_LOGIN, which is when this cleanup must run.
  if removed ~= nil then
    state.beta20CleanupRevision = CLEANUP_REVISION
    state.beta20CleanupRemoved = removed
    return removed
  end
  return 0
end

local function EnsureOptionsReady()
  if not WeakAurasReady() then
    return false, "WeakAuras is unavailable."
  end
  if InCombatLockdown and InCombatLockdown() then
    return false, "Leave combat before importing WeakAuras."
  end

  if IsAddOnLoaded and not IsAddOnLoaded("WeakAurasOptions") then
    if type(LoadAddOn) ~= "function" then
      return false, "WeakAuras Options cannot be loaded by this client."
    end
    local loaded, reason = LoadAddOn("WeakAurasOptions")
    if not loaded then
      return false, "WeakAuras Options failed to load: " .. tostring(reason or "unknown error")
    end
  end

  -- WeakAuras 5.21.2 routes encoded imports through its options-side update
  -- frame. Initialize the same options UI a manual /wa import uses before
  -- handing the static payload to WeakAuras.Import.
  if type(WeakAuras.OpenOptions) == "function" then
    local ok, err = pcall(WeakAuras.OpenOptions)
    if not ok then return false, "WeakAuras Options failed to initialize: " .. tostring(err) end
  elseif type(WeakAuras.ShowOptions) == "function" then
    local ok, err = pcall(WeakAuras.ShowOptions)
    if not ok then return false, "WeakAuras Options failed to initialize: " .. tostring(err) end
  end

  return true
end

local function SetImportResult(ok, message)
  RUI._beta20LastWeakAuraImportOK = ok == true
  RUI._beta20LastWeakAuraImportMessage = tostring(message or "")
  if RUI._beta20WeakAuraResultCallback then
    pcall(RUI._beta20WeakAuraResultCallback, ok == true, tostring(message or ""))
  end
  if ok ~= true and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4d3dRetreatUI WeakAuras:|r " .. tostring(message or "Import failed."))
  end
end

local function ImportPayload(payload, label)
  if type(payload) ~= "string" or payload == "" then
    return false, tostring(label or "WeakAura") .. " payload is missing."
  end
  if payload:sub(1, 6) ~= "!WA:2!" then
    return false, tostring(label or "WeakAura") .. " payload is not a WeakAuras 2 export."
  end

  local ready, reason = EnsureOptionsReady()
  if not ready then return false, reason end

  local function RunImport()
    local called, result, detail = pcall(WeakAuras.Import, payload)
    if not called then
      SetImportResult(false, tostring(result))
      return
    end

    -- WeakAuras.Import returns nil,nil on a normal successful hand-off to its
    -- import/update window. Explicit false or a second return value is an error.
    if result == false or detail ~= nil then
      SetImportResult(false, tostring(detail or "WeakAuras rejected the import."))
      return
    end
    SetImportResult(true, tostring(label or "WeakAura") .. " import opened successfully.")
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0.05, RunImport)
  else
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      RunImport()
    end)
  end

  return true, tostring(label or "WeakAura") .. " import is opening."
end

function RUI:ValidateCoAWeakAurasImportAPI()
  if not WeakAurasReady() then
    return false, "WeakAuras.Import is unavailable in the installed CoA WeakAuras version."
  end
  local payloads = PayloadRegistry()
  if type(payloads.general) ~= "string" or payloads.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  return true, "WeakAuras 5.21.2 import path and General payload are available."
end

function RUI:InstallGeneralWeakAuras()
  -- General is the first WA installer step, so it is safe to replace every
  -- earlier beta.20 test tree here and then install the shared anchor anew.
  CleanupAllBeta20Displays()
  local state = CleanupState()
  state.beta20CleanupRevision = CLEANUP_REVISION
  return ImportPayload(PayloadRegistry().general, "General WeakAuras")
end

function RUI:InstallClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local payload = PayloadRegistry().classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end

  -- Replace only this class. Never remove General here: its Class Power Bar is
  -- the anchor the class package intentionally uses.
  CleanupClassDisplay(className)
  local ok, message = ImportPayload(payload, tostring(className) .. " WeakAura")
  if ok and type(self.MarkClassInstallCompleted) == "function" then
    self:MarkClassInstallCompleted(className)
  end
  return ok, message
end

RUI._beta20WeakAuraCleanupRemoved = RunOneTimeStartupCleanup()
RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = 31
