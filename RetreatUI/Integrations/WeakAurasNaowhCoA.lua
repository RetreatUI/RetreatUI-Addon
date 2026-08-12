local RUI = RetreatUI
if not RUI then return end

-- beta.20 WeakAura import adapter.
-- The payloads are finished WeakAuras exports. This file deliberately does not
-- generate aura tables or add custom runtime events; it only imports the same
-- kind of export string the WeakAuras UI accepts.
RUI.NaowhCoAWeakAuras = RUI.NaowhCoAWeakAuras or {classes = {}}

local function WeakAurasReady()
  return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
end

local function ImportPayload(payload, label)
  if not WeakAurasReady() then
    return false, "This CoA WeakAuras build does not expose WeakAuras.Import."
  end
  if type(payload) ~= "string" or payload == "" then
    return false, tostring(label or "WeakAura") .. " payload is missing."
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
  return true, "WeakAuras.Import is available."
end

function RUI:InstallNaowhGeneralWeakAuras()
  local payloads = self.NaowhCoAWeakAuras or {}
  return ImportPayload(payloads.general, "General WeakAuras")
end

function RUI:InstallNaowhClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local payloads = self.NaowhCoAWeakAuras or {}
  local classes = payloads.classes or {}
  local payload = classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end
  return ImportPayload(payload, tostring(className) .. " WeakAura")
end

RUI._naowhCoAWeakAuraImportLoaded = true
RUI._naowhCoAWeakAuraImportRevision = 20
