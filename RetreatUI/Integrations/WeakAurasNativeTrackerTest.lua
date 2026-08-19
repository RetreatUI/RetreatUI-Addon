local RUI = RetreatUI
if not RUI then return end

-- beta.29 proof-of-concept: generate one sparse, native WeakAuras display from
-- Tracker Builder data and hand it to Ascension WeakAuras 5.21.2 through its
-- own Import() flow. No WeakAuras.Add, no custom decoder, no custom trigger Lua.

local function HasType(entry, wanted)
  if type(entry) ~= "table" then return false end
  if entry.trackingType == wanted then return true end
  if type(entry.trackingTypes) == "table" then
    for _, value in ipairs(entry.trackingTypes) do
      if value == wanted then return true end
    end
  end
  return false
end

local function FirstCooldownTracker(self)
  if type(self.GetSelectedTrackers) ~= "function" then return nil end
  local className = self.GetDetectedClass and self:GetDetectedClass() or nil
  local selected = self:GetSelectedTrackers(className)
  for _, entry in ipairs(selected or {}) do
    if type(entry.spellID) == "number" and entry.spellID > 0 and HasType(entry, "cooldown") then
      return entry
    end
  end
  return nil
end

local function WeakAurasAPI(self)
  if not self.EnsureAddOnLoaded or not self:EnsureAddOnLoaded("WeakAuras") then
    return nil, "WeakAuras is not installed or could not be loaded"
  end
  local wa = _G.WeakAuras
  if type(wa) ~= "table" then return nil, "WeakAuras core object is unavailable" end

  local required = {
    "Import",
    "GetTriggerCategoryFor",
    "GenerateUniqueID",
    "InternalVersion",
  }
  for _, name in ipairs(required) do
    if type(wa[name]) ~= "function" then
      return nil, "Ascension WeakAuras is missing required native API: " .. name
    end
  end
  return wa
end

local function SafeAuraID(wa, name)
  local base = "RetreatUI Test - " .. tostring(name or "Cooldown")
  if type(wa.FindUnusedId) == "function" then
    local ok, value = pcall(wa.FindUnusedId, base)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return base .. " - " .. tostring(time and time() or math.floor(GetTime and GetTime() or 0))
end

function RUI:BuildNativeCooldownTrackerTest(entry)
  if type(entry) ~= "table" or type(entry.spellID) ~= "number" or entry.spellID <= 0 then
    return nil, "selected tracker has no valid Spell ID"
  end

  local wa, reason = WeakAurasAPI(self)
  if not wa then return nil, reason end

  local categoryOK, triggerCategory = pcall(wa.GetTriggerCategoryFor, "Cooldown Progress (Spell)")
  if not categoryOK or type(triggerCategory) ~= "string" or triggerCategory == "" then
    return nil, "WeakAuras did not expose the native Cooldown Progress (Spell) trigger category"
  end

  local uidOK, uid = pcall(wa.GenerateUniqueID)
  if not uidOK or type(uid) ~= "string" or uid == "" then
    return nil, "WeakAuras could not generate a native aura UID"
  end

  local versionOK, internalVersion = pcall(wa.InternalVersion)
  if not versionOK or type(internalVersion) ~= "number" then
    return nil, "WeakAuras internal version is unavailable"
  end

  local settings = type(entry.settings) == "table" and entry.settings or {}
  local size = tonumber(settings.iconSize) or 36
  size = math.max(20, math.min(80, math.floor(size + 0.5)))

  local aura = {
    id = SafeAuraID(wa, entry.name),
    uid = uid,
    internalVersion = internalVersion,
    regionType = "icon",
    width = size,
    height = size,
    xOffset = 0,
    yOffset = 0,
    anchorFrameType = "SCREEN",
    anchorPoint = "CENTER",
    selfPoint = "CENTER",
    triggers = {
      {
        trigger = {
          type = triggerCategory,
          event = "Cooldown Progress (Spell)",
          spellName = entry.spellID,
          use_exact_spellName = true,
          use_genericShowOn = true,
          genericShowOn = "showAlways",
          use_track = true,
          track = "auto",
        },
        untrigger = {},
      },
    },
  }

  if type(self.BuildWeakAurasNativeImportEnvelope) ~= "function" then
    return nil, "RetreatUI WeakAuras native envelope adapter is unavailable"
  end
  local envelope, envelopeReason = self:BuildWeakAurasNativeImportEnvelope(aura, {})
  if not envelope then return nil, envelopeReason end
  return envelope, nil, aura.id
end

function RUI:OpenNativeCooldownTrackerTest()
  if InCombatLockdown and InCombatLockdown() then
    return false, "leave combat before opening the WeakAuras import test"
  end

  local entry = FirstCooldownTracker(self)
  if not entry then
    return false, "select at least one Tracker Builder ability with Cooldown enabled first"
  end

  local envelope, reason, auraID = self:BuildNativeCooldownTrackerTest(entry)
  if not envelope then return false, reason end
  if type(self.OpenWeakAurasNativeImport) ~= "function" then
    return false, "RetreatUI native WeakAuras import adapter is unavailable"
  end

  local ok, message = self:OpenWeakAurasNativeImport(envelope)
  if not ok then return false, message end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.weakAurasNativeTest = {
    version = self.version,
    className = entry.className,
    trackerKey = entry.key,
    spellID = entry.spellID,
    auraID = auraID,
  }

  return true, "WeakAuras native import window opened for " .. tostring(entry.name) .. " (Spell ID " .. tostring(entry.spellID) .. ")"
end

RUI._weakAurasNativeTrackerTest = true
