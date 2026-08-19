local RUI = RetreatUI
if not RUI then return end

-- beta.20 revision 37 follows the same proven install path as RetreatUI-TBC:
-- decode the bundled transmission, add real display tables through WeakAuras.Add,
-- then verify every display through WeakAuras.GetData before reporting success.
-- No WeakAurasOptions import UI and no direct SavedVariables installation.
local CLEANUP_REVISION = 37
local INSTALL_REVISION = 37

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

local function IntegrationState()
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
  if id == "Aura Bar - " .. className or id == "Main - " .. className then return true end
  if id == "Resources - " .. className or id == "Bars - " .. className then return true end
  if id == "Dynamic Bars - " .. className or id == "Aux Bar - " .. className then return true end
  if id == "Main Row 1 - " .. className or id == "Main Row 2 - " .. className or id == "Main Row 3 - " .. className then return true end
  return false
end

local function IsAnyRetreatUIOwnedID(id)
  if type(id) ~= "string" then return false end
  if id:sub(1, 12) == "RetreatUI - " then return true end
  if GENERAL_IDS[id] then return true end
  for _, className in ipairs(CLASS_NAMES) do
    if IsClassOwnedID(id, className) then return true end
  end
  return false
end

local function BuildOwnedRemovalSet(displays, className, generalOnly)
  local remove = {}
  for id in pairs(displays or {}) do
    local owned
    if generalOnly then
      owned = GENERAL_IDS[id] == true or id == "RetreatUI - General"
    elseif className then
      owned = IsClassOwnedID(id, className)
    else
      owned = IsAnyRetreatUIOwnedID(id)
    end
    if owned then remove[id] = true end
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

local function EnsureWeakAurasLoaded()
  if type(_G.WeakAuras) == "table"
    and type(_G.WeakAuras.Add) == "function"
    and type(_G.WeakAuras.GetData) == "function" then
    return true
  end
  if RUI.EnsureAddOnLoaded then RUI:EnsureAddOnLoaded("WeakAuras") end
  return type(_G.WeakAuras) == "table"
    and type(_G.WeakAuras.Add) == "function"
    and type(_G.WeakAuras.GetData) == "function"
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
  if not EnsureWeakAurasLoaded() then return nil, "WeakAuras Add API is unavailable." end

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

local function PrepareDisplay(data)
  if type(data) ~= "table" then return false, "WeakAuras display is not a table." end
  if type(data.id) ~= "string" or data.id == "" then return false, "WeakAuras display has no ID." end
  if type(data.load) == "table" then StripSpellKnown(data.load) end

  -- The CoA fork can carry a different internal revision while retaining the
  -- 5.21.2 transmission format. Mark generated tables with the actual runtime
  -- revision before WeakAuras.Add owns them.
  if type(WeakAuras.InternalVersion) == "function" then
    local ok, runtimeVersion = pcall(WeakAuras.InternalVersion)
    if ok and type(runtimeVersion) == "number" then data.internalVersion = runtimeVersion end
  end
  return true
end

local function DisplayDepth(displays, id)
  local depth, seen, data = 0, {}, displays and displays[id]
  while type(data) == "table" and type(data.parent) == "string" and not seen[data.parent] and depth < 50 do
    seen[data.parent] = true
    depth = depth + 1
    data = displays[data.parent]
  end
  return depth
end

local function RemoveOwnedDisplays(className, isGeneral)
  local displays = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays or nil
  if type(displays) ~= "table" then return 0 end

  local remove = BuildOwnedRemovalSet(displays, className, isGeneral)
  local ids = {}
  for id in pairs(remove) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return DisplayDepth(displays, a) > DisplayDepth(displays, b) end)

  local removed = 0
  for _, id in ipairs(ids) do
    local data = WeakAuras.GetData(id) or displays[id]
    if type(data) == "table" and type(WeakAuras.Delete) == "function" then
      pcall(WeakAuras.Delete, data)
    end
    if displays[id] ~= nil then displays[id] = nil end
    if WeakAuras.GetData(id) == nil then removed = removed + 1 end
  end
  return removed
end

local function AddDisplay(data)
  local prepared, reason = PrepareDisplay(data)
  if not prepared then return false, reason end

  local existing = WeakAuras.GetData(data.id)
  if existing and existing.uid then data.uid = existing.uid end

  local ok, err = pcall(WeakAuras.Add, data)
  if not ok then return false, tostring(err) end
  if not WeakAuras.GetData(data.id) then
    return false, data.id .. " was not present after WeakAuras.Add"
  end
  return true
end

local function InstallTransmission(transmission, className, isGeneral)
  if not EnsureWeakAurasLoaded() then return false, "WeakAuras Add API is unavailable." end

  RemoveOwnedDisplays(className, isGeneral)

  local root = transmission.d
  local children = type(transmission.c) == "table" and transmission.c or {}
  local prepared, reason = PrepareDisplay(root)
  if not prepared then return false, reason end

  -- Seed the package root first, exactly as the proven TBC installer does.
  local seed = {}
  for key, value in pairs(root) do seed[key] = value end
  seed.controlledChildren = {}
  local ok, err = AddDisplay(seed)
  if not ok then return false, err end

  -- Add parents before their descendants when the transmission contains nested
  -- dynamic groups. This makes the direct Add path deterministic.
  local installed = {[root.id] = true}
  local pending = {}
  for index, child in ipairs(children) do pending[index] = child end
  local remaining = #pending

  while remaining > 0 do
    local progressed = false
    for index, child in ipairs(pending) do
      if child ~= false then
        local parent = type(child) == "table" and child.parent or nil
        if not parent or installed[parent] or WeakAuras.GetData(parent) then
          local childOK, childErr = AddDisplay(child)
          if not childOK then return false, childErr end
          installed[child.id] = true
          pending[index] = false
          remaining = remaining - 1
          progressed = true
        end
      end
    end
    if not progressed then
      -- Preserve transmission order as a last resort for unusual parent graphs.
      for index, child in ipairs(pending) do
        if child ~= false then
          local childOK, childErr = AddDisplay(child)
          if not childOK then return false, childErr end
          installed[child.id] = true
          pending[index] = false
          remaining = remaining - 1
        end
      end
    end
  end

  -- Restore the exported root with its final controlledChildren ordering.
  ok, err = AddDisplay(root)
  if not ok then return false, err end

  if type(WeakAuras.ScanForLoads) == "function" then pcall(WeakAuras.ScanForLoads) end

  if not WeakAuras.GetData(root.id) then return false, root.id .. " is missing after installation" end
  for _, child in ipairs(children) do
    if type(child) == "table" and type(child.id) == "string" and not WeakAuras.GetData(child.id) then
      return false, child.id .. " is missing after installation"
    end
  end

  local state = IntegrationState()
  state.beta20CleanupRevision = CLEANUP_REVISION
  state.beta20InstallRevision = INSTALL_REVISION
  state.beta20LastInstalledDisplays = 1 + #children
  state.beta20InstallReloadRequired = false
  return true, 1 + #children
end

local function InstallPayload(payload, label, className, isGeneral)
  label = tostring(label or "WeakAuras")
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before installing WeakAuras." end

  local transmission, reason = DecodeTransmission(payload)
  if not transmission then return false, reason end
  local ok, countOrReason = InstallTransmission(transmission, className, isGeneral)
  if not ok then return false, countOrReason end
  return true, string.format("%s installed and verified (%d displays).", label, countOrReason)
end

function RUI:Beta20WeakAurasNeedsRecoveryReload()
  return false
end

function RUI:ValidateCoAWeakAurasImportAPI()
  local valid, registryOrMessage = ValidateBaseRegistry()
  if not valid then return false, registryOrMessage end
  if not EnsureWeakAurasLoaded() then return false, "WeakAuras Add/GetData API is unavailable." end
  local deflate, serialize, reason = GetCodecLibraries()
  if not deflate or not serialize then return false, reason end
  return true, "WeakAuras 5.21.2 Add/GetData installer is ready."
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
