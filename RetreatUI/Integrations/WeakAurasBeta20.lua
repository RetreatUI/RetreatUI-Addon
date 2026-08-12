local RUI = RetreatUI
if not RUI then return end

-- beta.20 ships ordinary static !WA:2! exports only.
-- RetreatUI does not generate WeakAuras or synthetic WeakAuras events at runtime.
local function PayloadRegistry()
  local registry = RUI.Beta20WeakAuras
  local legacy = RUI.NaowhCoAWeakAuras

  if type(registry) ~= "table" then
    registry = type(legacy) == "table" and legacy or {classes = {}}
  elseif type(legacy) == "table" and legacy ~= registry then
    if type(registry.general) ~= "string" and type(legacy.general) == "string" then
      registry.general = legacy.general
    end
    registry.classes = registry.classes or {}
    for className, payload in pairs(legacy.classes or {}) do
      if registry.classes[className] == nil then
        registry.classes[className] = payload
      end
    end
  end

  registry.classes = registry.classes or {}
  RUI.Beta20WeakAuras = registry
  -- Remove the old beta.20 alias after recovering any payloads from it.
  RUI.NaowhCoAWeakAuras = nil
  return registry
end

local function WeakAurasReady()
  return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
end

local function GetWeakAuraData(id)
  if type(id) ~= "string" or id == "" then return nil end
  if type(WeakAuras) ~= "table" or type(WeakAuras.GetData) ~= "function" then return nil end
  local ok, data = pcall(WeakAuras.GetData, id)
  if ok and type(data) == "table" then return data end
  return nil
end

local function DeleteWeakAuraByID(id, expectedUID)
  local data = GetWeakAuraData(id)
  if not data then return false end
  if expectedUID and data.uid ~= expectedUID then return false end
  if type(WeakAuras.Delete) ~= "function" then return false end
  local ok = pcall(WeakAuras.Delete, data)
  return ok == true
end

-- These are deterministic UIDs from beta.20's build-time exporter. Generic
-- names are only removed when the UID proves RetreatUI created the display.
local GENERATED_ROOTS = {
  ["Core & Essentials"] = "R5db4bd2edd370c0",
  ["Bloodmage Class Pack"] = "R7ded19cbd25a7f6",
  ["Knight of Xoroth Class Pack"] = "R441c13c11a3f4fb",
}

local BRANDED_ROOTS = {
  "RetreatUI - General",
  "RetreatUI - Bloodmage",
  "RetreatUI - Knight of Xoroth",
}

local function CleanupKnownBrokenBeta20Imports()
  if type(WeakAuras) ~= "table" or type(WeakAuras.Delete) ~= "function" then return 0 end

  local removed = 0
  local owned = {}
  local displays = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays or nil

  for id, expectedUID in pairs(GENERATED_ROOTS) do
    local data = GetWeakAuraData(id)
    if data and data.uid == expectedUID then owned[id] = true end
  end
  for _, id in ipairs(BRANDED_ROOTS) do
    if GetWeakAuraData(id) then owned[id] = true end
  end

  -- Recover every child below one of our known beta.20 test roots, regardless
  -- of how deep the imported group hierarchy is.
  if type(displays) == "table" then
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
  end

  -- Delete children before their parents so partially imported groups cannot
  -- leave broken spell-known displays behind.
  local ids = {}
  for id in pairs(owned) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    local da, db = GetWeakAuraData(a), GetWeakAuraData(b)
    local function depth(data)
      local d, seen = 0, {}
      while type(data) == "table" and type(data.parent) == "string" and not seen[data.parent] do
        seen[data.parent] = true
        d = d + 1
        data = displays and displays[data.parent] or nil
      end
      return d
    end
    return depth(da) > depth(db)
  end)

  for _, id in ipairs(ids) do
    local expectedUID = GENERATED_ROOTS[id]
    if DeleteWeakAuraByID(id, expectedUID) then removed = removed + 1 end
  end

  return removed
end

local function EnsureWeakAurasOptionsLoaded()
  if not WeakAurasReady() then
    return false, "WeakAuras is unavailable."
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

  -- On Ascension the import UI is LoadOnDemand. Initialising the options frame
  -- first makes the normal WeakAuras.Import path register its update/import
  -- handler before Transmission.lua tries to use it.
  if type(WeakAuras.OpenOptions) == "function" then
    local ok, err = pcall(WeakAuras.OpenOptions)
    if not ok then return false, "WeakAuras Options failed to open: " .. tostring(err) end
  end

  return true
end

local function ReportAsyncImport(ok, message)
  RUI._beta20LastWeakAuraImportOK = ok == true
  RUI._beta20LastWeakAuraImportMessage = tostring(message or "")
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

  local ready, reason = EnsureWeakAurasOptionsLoaded()
  if not ready then return false, reason end

  local function doImport()
    local ok, result = pcall(WeakAuras.Import, payload)
    if not ok then
      ReportAsyncImport(false, result)
      return
    end
    if result == false then
      ReportAsyncImport(false, tostring(label or "WeakAura") .. " import was rejected.")
      return
    end
    ReportAsyncImport(true, tostring(label or "WeakAura") .. " import opened successfully.")
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, doImport)
  else
    doImport()
  end

  return true, tostring(label or "WeakAura") .. " import is opening in WeakAuras."
end

function RUI:ValidateCoAWeakAurasImportAPI()
  if not WeakAurasReady() then
    return false, "WeakAuras.Import is unavailable in the installed CoA WeakAuras version."
  end
  local payloads = PayloadRegistry()
  if type(payloads.general) ~= "string" or payloads.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  return true, "WeakAuras and the beta.20 General payload are available."
end

function RUI:InstallGeneralWeakAuras()
  local payloads = PayloadRegistry()
  CleanupKnownBrokenBeta20Imports()
  return ImportPayload(payloads.general, "General WeakAuras")
end

function RUI:InstallClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local payloads = PayloadRegistry()
  local classes = payloads.classes or {}
  local payload = classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end

  CleanupKnownBrokenBeta20Imports()
  local ok, message = ImportPayload(payload, tostring(className) .. " WeakAura")
  if ok and type(self.MarkClassInstallCompleted) == "function" then
    self:MarkClassInstallCompleted(className)
  end
  return ok, message
end

-- Remove broken beta.20 test imports as soon as RetreatUI loads. A stale aura
-- can still throw once earlier in the same login while WeakAuras itself starts;
-- after this cleanup and one reload it is gone from WeakAurasSaved.
local cleaned = CleanupKnownBrokenBeta20Imports()
RUI._beta20WeakAuraCleanupRemoved = cleaned
RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = 25
