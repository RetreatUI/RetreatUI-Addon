local RUI = RetreatUI
if not RUI then return end

-- beta.20 revision 36 deliberately does not use WeakAuras.Import().
-- The CoA 5.21.2 build can expose WeakAuras.Import while its options-side
-- Private.OpenUpdate callback is absent. RetreatUI therefore decodes its own
-- already-generated !WA:2! transmissions and installs only the contained
-- display tables into WeakAurasSaved. WeakAuras consumes those normal display
-- tables on the final installer reload.
local CLEANUP_REVISION = 36
local INSTALL_REVISION = 36

local CLASS_NAMES = {
  "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
  "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
  "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
  "Venomancer", "Witch Doctor", "Witch Hunter",
}

local GENERAL_IDS = {
  ["RetreatUI - General"] = true,
  ["Core & Essentials"] = true,
  ["Anchors"] = true,
  ["UI Elements"] = true,
  ["Aura bar (Player buffs)"] = true,
  ["Class Power Bar"] = true,
  ["Trinket 1"] = true,
  ["Trinket 2"] = true,
}

local function PayloadRegistry()
  local registry = RUI.Beta20WeakAuras
  if type(registry) ~= "table" or type(registry.classes) ~= "table" then return nil end
  return registry
end

local function ValidateBaseRegistry()
  local registry = PayloadRegistry()
  if not registry then return false, "beta.20 WeakAuras registry is missing." end
  if type(registry.general) ~= "string" or registry.general:sub(1, 6) ~= "!WA:2!" then
    return false, "General WeakAuras payload is not registered."
  end
  if registry.weakAurasVersion and tostring(registry.weakAurasVersion) ~= "5.21.2" then
    return false, "WeakAuras payloads were generated for the wrong WeakAuras version."
  end
  return true, registry
end

local function CleanupState()
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  RetreatUIDB.integrations.weakAuras = RetreatUIDB.integrations.weakAuras or {}
  return RetreatUIDB.integrations.weakAuras
end

local function IsClassOwnedID(id, className)
  if type(id) ~= "string" or type(className) ~= "string" then return false end
  if id == "RetreatUI - " .. className or id == className .. " Class Pack" then return true end
  if id:sub(1, #className + 3) == className .. " - " then return true end
  if id:find(" - " .. className, 1, true) then return true end
  if id:find(" - " .. className .. " Aux", 1, true) then return true end
  if id:find("(Active) - " .. className, 1, true) then return true end
  if id == "Aura Bar - " .. className or id == "Main - " .. className then return true end
  if id == "Resources - " .. className or id == "Bars - " .. className then return true end
  if id == "Dynamic Bars - " .. className or id == "Aux Bar - " .. className then return true end
  if id == "Main Row 1 - " .. className or id == "Main Row 2 - " .. className or id == "Main Row 3 - " .. className then return true end
  return false
end

local function IsAnyRetreatUIOwnedID(id)
  if GENERAL_IDS[id] then return true end
  for _, className in ipairs(CLASS_NAMES) do
    if IsClassOwnedID(id, className) then return true end
  end
  return false
end

local function IsUnsafeSpellKnownLoad(data)
  if type(data) ~= "table" or type(data.load) ~= "table" then return false end
  local function Scan(value)
    if type(value) ~= "table" then return false end
    for key, child in pairs(value) do
      local normalized = tostring(key):lower():gsub("[_%-%s]", "")
      if normalized:find("spellknown", 1, true) then return true end
      if type(child) == "table" and Scan(child) then return true end
    end
    return false
  end
  return Scan(data.load)
end

local function BuildOwnedRemovalSet(displays, className, generalOnly, unsafeOnly)
  local remove = {}
  for id, data in pairs(displays or {}) do
    local owned
    if generalOnly then
      owned = GENERAL_IDS[id] == true
    elseif className then
      owned = IsClassOwnedID(id, className)
    else
      owned = IsAnyRetreatUIOwnedID(id)
    end
    if owned and (not unsafeOnly or IsUnsafeSpellKnownLoad(data)) then remove[id] = true end
  end

  local changed = true
  while changed do
    changed = false
    for id, data in pairs(displays or {}) do
      if not remove[id] and type(data) == "table" and type(data.parent) == "string" and remove[data.parent] then
        remove[id] = true
        changed = true
      end
    end
  end
  return remove
end

local function RemoveDisplays(displays, remove)
  local count = 0
  for id in pairs(remove or {}) do
    if displays[id] ~= nil then
      displays[id] = nil
      count = count + 1
    end
  end
  return count
end

local function PurgeOldBeta20Displays()
  if type(WeakAurasSaved) ~= "table" or type(WeakAurasSaved.displays) ~= "table" then return 0 end
  return RemoveDisplays(WeakAurasSaved.displays, BuildOwnedRemovalSet(WeakAurasSaved.displays))
end

local function RunStartupRecovery()
  local state = CleanupState()
  local previousRevision = tonumber(state.beta20CleanupRevision) or 0
  if previousRevision >= CLEANUP_REVISION then
    state.beta20RecoveryReloadRequired = false
    return 0
  end

  local removed = PurgeOldBeta20Displays()
  state.beta20CleanupRevision = CLEANUP_REVISION
  state.beta20CleanupRemoved = removed
  state.beta20RecoveryReloadRequired = removed > 0
  return removed
end

RUI._beta20WeakAuraCleanupRemoved = RunStartupRecovery()

function RUI:Beta20WeakAurasNeedsRecoveryReload()
  return CleanupState().beta20RecoveryReloadRequired == true
end

local function EnsureWeakAurasLoaded()
  if type(WeakAurasSaved) == "table" then return true end
  if RUI.EnsureAddOnLoaded then RUI:EnsureAddOnLoaded("WeakAuras") end
  return type(WeakAurasSaved) == "table"
end

local function GetCodecLibraries()
  local libStub = _G.LibStub
  if type(libStub) ~= "table" and type(libStub) ~= "function" then
    return nil, nil, "LibStub is unavailable."
  end

  local deflate = LibStub("LibDeflate", true)
  local serialize = LibStub("LibSerialize", true)
  if type(deflate) ~= "table" or type(deflate.DecodeForPrint) ~= "function" or type(deflate.DecompressDeflate) ~= "function" then
    return nil, nil, "WeakAuras LibDeflate codec is unavailable."
  end
  if type(serialize) ~= "table" or type(serialize.Deserialize) ~= "function" then
    return nil, nil, "WeakAuras LibSerialize codec is unavailable."
  end
  return deflate, serialize
end

local function DecodeTransmission(payload)
  if type(payload) ~= "string" or payload:sub(1, 6) ~= "!WA:2!" then
    return nil, "Payload is not a WeakAuras 2 transmission."
  end
  if not EnsureWeakAurasLoaded() then return nil, "WeakAuras could not be loaded." end

  local deflate, serialize, reason = GetCodecLibraries()
  if not deflate then return nil, reason end

  local okDecode, compressed = pcall(deflate.DecodeForPrint, deflate, payload:sub(7))
  if not okDecode or type(compressed) ~= "string" then return nil, "WeakAuras payload print-decoding failed." end

  local okInflate, serialized = pcall(deflate.DecompressDeflate, deflate, compressed)
  if not okInflate or type(serialized) ~= "string" then return nil, "WeakAuras payload decompression failed." end

  local okDeserialize, success, transmission = pcall(serialize.Deserialize, serialize, serialized)
  if not okDeserialize then return nil, "WeakAuras payload deserialization failed: " .. tostring(success) end
  if success ~= true or type(transmission) ~= "table" then return nil, "WeakAuras payload deserialization was rejected." end
  if transmission.m ~= "d" or type(transmission.d) ~= "table" then return nil, "WeakAuras transmission does not contain display data." end
  return transmission
end

local function SanitizeDisplay(data)
  if type(data) ~= "table" then return end
  data.load = type(data.load) == "table" and data.load or {spec = {multi = {}}, use_never = false}
  local function StripSpellKnown(value)
    if type(value) ~= "table" then return end
    local delete = {}
    for key, child in pairs(value) do
      local normalized = tostring(key):lower():gsub("[_%-%s]", "")
      if normalized:find("spellknown", 1, true) then
        delete[#delete + 1] = key
      elseif type(child) == "table" then
        StripSpellKnown(child)
      end
    end
    for _, key in ipairs(delete) do value[key] = nil end
  end
  StripSpellKnown(data.load)
end

local function SaveTransmission(transmission, className, isGeneral)
  if not EnsureWeakAurasLoaded() then return false, "WeakAuras could not be loaded." end
  WeakAurasSaved.displays = type(WeakAurasSaved.displays) == "table" and WeakAurasSaved.displays or {}
  local displays = WeakAurasSaved.displays

  local remove = isGeneral
    and BuildOwnedRemovalSet(displays, nil, true, false)
    or BuildOwnedRemovalSet(displays, className, false, false)
  RemoveDisplays(displays, remove)

  local root = transmission.d
  local children = type(transmission.c) == "table" and transmission.c or {}
  SanitizeDisplay(root)
  if type(root.id) ~= "string" or root.id == "" then return false, "WeakAuras package root has no ID." end
  displays[root.id] = root

  local saved = 1
  for _, child in ipairs(children) do
    if type(child) == "table" and type(child.id) == "string" and child.id ~= "" then
      SanitizeDisplay(child)
      displays[child.id] = child
      saved = saved + 1
    end
  end

  local state = CleanupState()
  state.beta20InstallRevision = INSTALL_REVISION
  state.beta20InstallReloadRequired = true
  state.beta20LastSavedDisplays = saved
  return true, saved
end

local function InstallPayload(payload, label, className, isGeneral)
  label = tostring(label or "WeakAuras")
  if RUI:Beta20WeakAurasNeedsRecoveryReload() then
    return false, "Old RetreatUI WeakAuras were removed. Reload once, reopen the installer, then continue."
  end
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before installing WeakAuras." end

  local transmission, reason = DecodeTransmission(payload)
  if not transmission then return false, reason end
  local ok, savedOrReason = SaveTransmission(transmission, className, isGeneral)
  if not ok then return false, savedOrReason end
  return true, string.format("%s installed (%d displays). Continue; the final Reload activates it.", label, savedOrReason)
end

function RUI:ValidateCoAWeakAurasImportAPI()
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end
  if not EnsureWeakAurasLoaded() then return false, "WeakAuras could not be loaded." end
  local deflate, serialize, reason = GetCodecLibraries()
  if not deflate or not serialize then return false, reason end
  return true, "WeakAuras 5.21.2 direct display installer is ready."
end

function RUI:InstallGeneralWeakAuras()
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end
  return InstallPayload(registryOrMessage.general, "General WeakAuras", nil, true)
end

function RUI:InstallClassWeakAuras(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end

  local payload = registryOrMessage.classes[className]
  if type(payload) ~= "string" or payload == "" then
    return false, "No beta.20 WeakAura payload is registered for " .. tostring(className or "this CoA class") .. "."
  end

  local ok, message = InstallPayload(payload, tostring(className) .. " WeakAuras", className, false)
  if ok and type(self.MarkClassInstallCompleted) == "function" then self:MarkClassInstallCompleted(className) end
  return ok, message
end

RUI._beta20WeakAuraImportLoaded = true
RUI._beta20WeakAuraImportRevision = INSTALL_REVISION
