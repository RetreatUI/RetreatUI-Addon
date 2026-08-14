local RUI = RetreatUI
if not RUI then return end

local CLEANUP_REVISION = 35

local CLASS_NAMES = {
  "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
  "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
  "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
  "Venomancer", "Witch Doctor", "Witch Hunter",
}

local function PayloadRegistry()
  local registry = RUI.Beta20WeakAuras
  if type(registry) ~= "table" then return nil end
  if type(registry.classes) ~= "table" then return nil end
  return registry
end

local function ValidateBaseRegistry()
  local registry = PayloadRegistry()
  if not registry then
    return false, "beta.20 WeakAuras registry is missing."
  end
  if type(registry.general) ~= "string" or registry.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  if registry.weakAurasVersion and tostring(registry.weakAurasVersion) ~= "5.21.2" then
    return false, "WeakAuras payloads were generated for the wrong WeakAuras version."
  end
  return true, registry
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

-- One-time recovery for beta.20 test imports. Previous builds could leave
-- RetreatUI-owned displays with unsafe Spell Known load conditions in
-- WeakAurasSaved. Remove only RetreatUI-owned roots and their descendants,
-- then require one reload before importing the corrected static payloads.
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
  local previousRevision = tonumber(state.beta20CleanupRevision) or 0

  if previousRevision >= CLEANUP_REVISION then
    state.beta20ReloadRequired = false
    return 0
  end

  local removed = PurgeOwnedSavedDisplays()
  state.beta20CleanupRevision = CLEANUP_REVISION
  state.beta20CleanupRemoved = removed
  state.beta20ReloadRequired = removed > 0
  return removed
end

RUI._beta20WeakAuraCleanupRemoved = RunStartupRecovery()

function RUI:Beta20WeakAurasNeedsRecoveryReload()
  local state = CleanupState()
  return state.beta20ReloadRequired == true
end

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

local function ConfirmImportWindow(label, elapsed)
  elapsed = tonumber(elapsed) or 0
  if type(WeakAuras) ~= "table" then
    SetImportResult(false, "WeakAuras unloaded while opening the import window.")
    return
  end

  if type(WeakAuras.IsOptionsOpen) ~= "function" then
    SetImportResult(true, label .. " import opened successfully.")
    return
  end

  local ok, isOpen = pcall(WeakAuras.IsOptionsOpen)
  if ok and isOpen == true then
    SetImportResult(true, label .. " import opened successfully.")
    return
  end

  if elapsed >= 2.0 then
    SetImportResult(false, "WeakAuras did not open its import window.")
    return
  end

  After(0.05, function()
    ConfirmImportWindow(label, elapsed + 0.05)
  end)
end

local function ImportPayload(payload, label)
  label = tostring(label or "WeakAura")
  if type(payload) ~= "string" or payload == "" then
    return false, label .. " payload is missing."
  end
  if payload:sub(1, 6) ~= "!WA:2!" then
    return false, label .. " payload is not a WeakAuras 2 export."
  end

  if RUI:Beta20WeakAurasNeedsRecoveryReload() then
    return false, "Old beta.20 WeakAuras were removed. Reload the UI once, then run this step again."
  end

  if InCombatLockdown and InCombatLockdown() then
    return false, "Leave combat before importing WeakAuras."
  end

  if not WeakAurasImportAvailable() then
    local loaded = RUI.EnsureAddOnLoaded and RUI:EnsureAddOnLoaded("WeakAuras")
    if not loaded or not WeakAurasImportAvailable() then
      return false, "WeakAuras.Import is unavailable in the installed WeakAuras build."
    end
  end

  -- WeakAuras.Import is the supported entry point. It decodes the payload,
  -- loads WeakAurasOptions itself and opens the import/update window. Do not
  -- manually LoadAddOn/OpenOptions or wait for a WeakAurasOptions global.
  local called, result, detail = pcall(WeakAuras.Import, payload)
  if not called then
    return false, "WeakAuras import error: " .. tostring(result)
  end
  if result == false or detail ~= nil then
    return false, tostring(detail or "WeakAuras rejected the import.")
  end

  After(0.05, function() ConfirmImportWindow(label, 0.05) end)
  return true, label .. " import is opening."
end

function RUI:ValidateCoAWeakAurasImportAPI()
  if not WeakAurasImportAvailable() then
    return false, "WeakAuras.Import is unavailable in the installed WeakAuras version."
  end
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end
  return true, "WeakAuras 5.21.2 native import path and General payload are available."
end

function RUI:InstallGeneralWeakAuras()
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end
  return ImportPayload(registryOrMessage.general, "General WeakAuras")
end

function RUI:InstallClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end

  local payload = registryOrMessage.classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end

  local ok, message = ImportPayload(payload, tostring(className) .. " WeakAura")
  if ok and type(self.MarkClassInstallCompleted) == "function" then
    self:MarkClassInstallCompleted(className)
  end
  return ok, message
end

RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = 35
