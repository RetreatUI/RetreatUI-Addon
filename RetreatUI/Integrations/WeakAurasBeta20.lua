local RUI = RetreatUI
if not RUI then return end

-- beta.20 imports finished WeakAuras export strings only.
-- No runtime aura generation, RetreatUI custom-grow framework or synthetic WA
-- event engine lives here.
local function PayloadRegistry()
  local registry = RUI.Beta20WeakAuras or RUI.NaowhCoAWeakAuras
  if type(registry) ~= "table" then
    registry = {classes = {}}
  end
  registry.classes = registry.classes or {}
  RUI.Beta20WeakAuras = registry
  RUI.NaowhCoAWeakAuras = registry -- branch-upgrade compatibility alias
  return registry
end

local function WeakAurasReady()
  return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
end

local function ImportPayload(payload, label)
  if not WeakAurasReady() then
    return false, "WeakAuras.Import is unavailable in the installed CoA WeakAuras build."
  end
  if type(payload) ~= "string" or payload == "" then
    return false, tostring(label or "WeakAura") .. " payload is missing."
  end
  if payload:sub(1, 6) ~= "!WA:2!" then
    return false, tostring(label or "WeakAura") .. " payload is not a WeakAuras 2 export."
  end

  local ok, result = pcall(WeakAuras.Import, payload)
  if not ok then return false, tostring(result) end
  if result == false then return false, tostring(label or "WeakAura") .. " import was rejected." end
  return true, tostring(label or "WeakAura") .. " import opened successfully."
end

function RUI:ValidateCoAWeakAurasImportAPI()
  if not WeakAurasReady() then
    return false, "WeakAuras.Import is unavailable in the installed CoA WeakAuras version."
  end
  local payloads = PayloadRegistry()
  if type(payloads.general) ~= "string" or payloads.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  return true, "WeakAuras.Import and the beta.20 General payload are available."
end

function RUI:InstallGeneralWeakAuras()
  local payloads = PayloadRegistry()
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

  local ok, message = ImportPayload(payload, tostring(className) .. " WeakAura")
  if ok and type(self.MarkClassInstallCompleted) == "function" then
    self:MarkClassInstallCompleted(className)
  end
  return ok, message
end

RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = 22
