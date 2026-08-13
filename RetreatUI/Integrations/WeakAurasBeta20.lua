local RUI = RetreatUI
if not RUI then return end

local CLEANUP_REVISION = 32

local CLASS_NAMES = {
  "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
  "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
  "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
  "Venomancer", "Witch Doctor", "Witch Hunter",
}

local function PayloadRegistry()
  local registry = RUI.Beta20WeakAuras
  if type(registry) ~= "table" then
    registry = { classes = {} }
    RUI.Beta20WeakAuras = registry
  end
  registry.classes = registry.classes or {}
  return registry
end

local function AddOwnedRoot(roots, id)
  if type(id) == "string" and id ~= "" then roots[id] = true end
end

local function BuildOwnedRoots()
  local roots = {}
  AddOwnedRoot(roots, "RetreatUI - General")
  AddOwnedRoot(roots, "Core & Essentials")
  AddOwnedRoot(roots, "Anchors")
  AddOwnedRoot(roots, "UI Elements")
  AddOwnedRoot(roots, "Aura bar (Player buffs)")
  AddOwnedRoot(roots, "Class Power Bar")
  AddOwnedRoot(roots, "Trinket 1")
  AddOwnedRoot(roots, "Trinket 2")

  for _, className in ipairs(CLASS_NAMES) do
    AddOwnedRoot(roots, "RetreatUI - " .. className)
    AddOwnedRoot(roots, className .. " Class Pack")
    AddOwnedRoot(roots, "Aura Bar - " .. className)
    AddOwnedRoot(roots, "Main - " .. className)
    AddOwnedRoot(roots, "Resources - " .. className)
    AddOwnedRoot(roots, "Bars - " .. className)
    AddOwnedRoot(roots, "Dynamic Bars - " .. className)
    AddOwnedRoot(roots, "Aux Bar - " .. className)
    AddOwnedRoot(roots, "Main Row 1 - " .. className)
    AddOwnedRoot(roots, "Main Row 2 - " .. className)
    AddOwnedRoot(roots, "Main Row 3 - " .. className)
    AddOwnedRoot(roots, className .. " - Primary Power")
  end
  return roots
end

local OWNED_ROOTS = BuildOwnedRoots()

-- Recovery migration for broken beta.20 test imports. Only RetreatUI-owned
-- display records are touched. Direct saved-data removal is intentional here:
-- calling WeakAuras.Delete can evaluate the invalid load conditions we need to
-- remove and can therefore recreate the login error before cleanup completes.
local function PurgeOwnedSavedDisplays()
  if type(WeakAurasSaved) ~= "table" or type(WeakAurasSaved.displays) ~= "table" then
    return 0
  end

  local displays = WeakAurasSaved.displays
  local remove = {}
  for id in pairs(OWNED_ROOTS) do
    if displays[id] ~= nil then remove[id] = true end
  end

  local changed = true
  while changed do
    changed = false
    for id, data in pairs(displays) do
      if not remove[id] and type(data) == "table" and type(data.parent) == "string" and remove[data.parent] then
        remove[id] = true
        changed = true
      end
    end
  end

  local count = 0
  for id in pairs(remove) do
    if displays[id] ~= nil then
      displays[id] = nil
      count = count + 1
    end
  end
  return count
end

local function CleanupState()
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  RetreatUIDB.integrations.weakAuras = RetreatUIDB.integrations.weakAuras or {}
  return RetreatUIDB.integrations.weakAuras
end

local function RunStartupRecovery()
  local state = CleanupState()
  if tonumber(state.beta20CleanupRevision) >= CLEANUP_REVISION then return 0 end
  local removed = PurgeOwnedSavedDisplays()
  state.beta20CleanupRevision = CLEANUP_REVISION
  state.beta20CleanupRemoved = removed
  return removed
end

RUI._beta20WeakAuraCleanupRemoved = RunStartupRecovery()

local function WeakAurasImportAvailable()
  return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
end

local function After(delay, callback)
  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(delay, callback)
    return
  end

  local frame = CreateFrame("Frame")
  local elapsed = 0
  frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + (dt or 0)
    if elapsed >= delay then
      self:SetScript("OnUpdate", nil)
      callback()
    end
  end)
end

local function PrepareWeakAurasOptions()
  if not WeakAurasImportAvailable() then
    return false, "WeakAuras is unavailable."
  end
  if InCombatLockdown and InCombatLockdown() then
    return false, "Leave combat before importing WeakAuras."
  end

  if IsAddOnLoaded and not IsAddOnLoaded("WeakAurasOptions") then
    if type(LoadAddOn) ~= "function" then
      return false, "WeakAurasOptions cannot be loaded by this client."
    end
    local loaded, reason = LoadAddOn("WeakAurasOptions")
    if not loaded and not (IsAddOnLoaded and IsAddOnLoaded("WeakAurasOptions")) then
      return false, "WeakAurasOptions could not be loaded: " .. tostring(reason or "unknown reason")
    end
  end

  -- WeakAuras 5.21.2 wires Transmission.lua's update callback during the
  -- first ShowOptions frame construction. Loading WeakAurasOptions alone (or
  -- merely checking IsOptionsOpen) is not sufficient.
  if type(WeakAuras.ShowOptions) ~= "function" then
    return false, "WeakAuras 5.21.2 options API is unavailable."
  end
  local ok, err = pcall(WeakAuras.ShowOptions)
  if not ok then
    return false, "WeakAuras options could not be initialized: " .. tostring(err)
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
  label = tostring(label or "WeakAura")
  if type(payload) ~= "string" or payload == "" then
    return false, label .. " payload is missing."
  end
  if payload:sub(1, 6) ~= "!WA:2!" then
    return false, label .. " payload is not a WeakAuras 2 export."
  end

  local ready, reason = PrepareWeakAurasOptions()
  if not ready then return false, reason end

  -- Give the options frame two tenths of a second to finish its first layout
  -- pass before Transmission.lua enters its import/update phase.
  After(0.20, function()
    local called, result, detail = pcall(WeakAuras.Import, payload)
    if not called then
      SetImportResult(false, tostring(result))
      return
    end
    if result == false or detail ~= nil then
      SetImportResult(false, tostring(detail or "WeakAuras rejected the import."))
      return
    end
    SetImportResult(true, label .. " import opened successfully.")
  end)

  return true, label .. " import is opening."
end

function RUI:ValidateCoAWeakAurasImportAPI()
  if not WeakAurasImportAvailable() then
    return false, "WeakAuras.Import is unavailable in the installed WeakAuras version."
  end
  local payloads = PayloadRegistry()
  if type(payloads.general) ~= "string" or payloads.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  return true, "WeakAuras 5.21.2 import path and General payload are available."
end

function RUI:InstallGeneralWeakAuras()
  PurgeOwnedSavedDisplays()
  local state = CleanupState()
  state.beta20CleanupRevision = CLEANUP_REVISION
  local payloads = PayloadRegistry()
  return ImportPayload(payloads.general, "General WeakAuras")
end

function RUI:InstallClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local payloads = PayloadRegistry()
  local payload = payloads.classes and payloads.classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end

  PurgeOwnedSavedDisplays()
  local ok, message = ImportPayload(payload, tostring(className) .. " WeakAura")
  if ok and type(self.MarkClassInstallCompleted) == "function" then
    self:MarkClassInstallCompleted(className)
  end
  return ok, message
end

RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = 32
