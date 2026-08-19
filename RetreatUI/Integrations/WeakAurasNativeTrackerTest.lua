local RUI = RetreatUI
if not RUI then return end

-- Native Tracker Builder -> WeakAuras bridge for Ascension WeakAuras 5.21.2.
-- Uses only native WeakAuras trigger data and WeakAuras' own Import() flow.
-- No WeakAuras.Add, no custom decoder and no custom trigger Lua.
--
-- Live-verified paths retained:
--   Cooldown
--   Cooldown + active Buff duration
--   Buff / Proc
--   Charges
--
-- beta.34 mirrors Ascension WeakAuras' own Charge Tracking template behavior:
-- while at least one charge remains, show the native charge count without a
-- recharge swipe taking over the icon; at zero charges, show the cooldown swipe.

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

local function HasSupportedType(entry)
  return HasType(entry, "cooldown")
      or HasType(entry, "buff")
      or HasType(entry, "proc")
      or HasType(entry, "debuff")
      or HasType(entry, "stacks")
      or HasType(entry, "charges")
end

local function FirstSupportedTracker(self)
  if type(self.GetSelectedTrackers) ~= "function" then return nil end
  local className = self.GetDetectedClass and self:GetDetectedClass() or nil
  local selected = self:GetSelectedTrackers(className)
  for _, entry in ipairs(selected or {}) do
    if type(entry.spellID) == "number" and entry.spellID > 0 and HasSupportedType(entry) then
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

  local required = {"Import", "GetTriggerCategoryFor", "GenerateUniqueID", "InternalVersion"}
  for _, name in ipairs(required) do
    if type(wa[name]) ~= "function" then
      return nil, "Ascension WeakAuras is missing required native API: " .. name
    end
  end
  return wa
end

local function BuildCooldownTrigger(triggerCategory, entry)
  local trigger = {
    type = triggerCategory,
    event = "Cooldown Progress (Spell)",
    spellName = entry.spellID,
    use_exact_spellName = true,
    use_genericShowOn = true,
    genericShowOn = "showAlways",
  }

  -- The Ascension WeakAuras Charge Tracking template deliberately does not set
  -- use_track/track for showAlways charge abilities. Preserve the already
  -- verified cooldown behavior for non-charge trackers, but mirror the native
  -- charge template exactly when Charges is enabled.
  if not HasType(entry, "charges") then
    trigger.use_track = true
    trigger.track = "auto"
  end

  return {
    trigger = trigger,
    untrigger = {},
  }
end

local function AuraName(entry)
  if type(entry.auraName) == "string" and entry.auraName ~= "" then return entry.auraName end
  if type(entry.name) == "string" and entry.name ~= "" then return entry.name end
  return nil
end

local function BuildAuraTrigger(entry, harmful)
  local auraName = AuraName(entry)
  if not auraName then return nil end
  local unit = entry.unit or (harmful and "target" or "player")
  return {
    trigger = {
      unit = unit,
      type = "aura2",
      matchesShowOn = "showOnActive",
      debuffType = harmful and "HARMFUL" or "HELPFUL",
      ownOnly = true,
      unitExists = false,
      useName = true,
      auranames = { tostring(auraName) },
    },
    untrigger = {},
  }
end

local function BuildTriggers(triggerCategory, entry)
  local wantsCooldown = HasType(entry, "cooldown") or HasType(entry, "charges")
  local wantsDebuff = HasType(entry, "debuff")
  local wantsHelpfulAura = HasType(entry, "buff") or HasType(entry, "proc") or (HasType(entry, "stacks") and not wantsDebuff)

  if wantsDebuff and (HasType(entry, "buff") or HasType(entry, "proc")) then
    return nil, "one tracker cannot use Buff/Proc and Debuff at the same time; choose the aura type that belongs to this spell"
  end

  local triggers = {}
  if wantsDebuff then
    local trigger = BuildAuraTrigger(entry, true)
    if not trigger then return nil, "the debuff tracker has no usable aura name" end
    triggers[#triggers + 1] = trigger
  elseif wantsHelpfulAura then
    local trigger = BuildAuraTrigger(entry, false)
    if not trigger then return nil, "the buff/proc/stacks tracker has no usable aura name" end
    triggers[#triggers + 1] = trigger
  end

  if wantsCooldown then
    triggers[#triggers + 1] = BuildCooldownTrigger(triggerCategory, entry)
  end

  if #triggers == 0 then
    return nil, "this tracker has no native WeakAuras type enabled yet"
  end

  triggers.disjunctive = (#triggers > 1) and "any" or "all"
  triggers.activeTriggerMode = -10
  return triggers
end

local function BuildSubRegions(entry)
  local settings = type(entry.settings) == "table" and entry.settings or {}
  local wantsCount = settings.showStacks == true or HasType(entry, "stacks") or HasType(entry, "charges")
  if not wantsCount then return nil end

  return {
    { type = "subbackground" },
    { type = "subtext", text_text = "%s", text_visible = true },
  }
end

local function FindCooldownTriggerIndex(triggers)
  for index, entry in ipairs(triggers or {}) do
    if type(entry) == "table" and type(entry.trigger) == "table"
      and entry.trigger.event == "Cooldown Progress (Spell)" then
      return index
    end
  end
  return nil
end

local function BuildChargeConditions(entry, triggers)
  if not HasType(entry, "charges") then return nil end
  local triggerIndex = FindCooldownTriggerIndex(triggers)
  if not triggerIndex then return nil end

  -- Mirrors WeakAurasTemplates/TriggerTemplates.lua hasChargesGrey() for icons:
  -- the base icon has cooldownSwipe=false; only zero charges enables the swipe.
  return {
    {
      check = {
        trigger = triggerIndex,
        variable = "charges",
        op = "==",
        value = "0",
      },
      changes = {
        { property = "cooldownSwipe", value = true },
      },
    },
  }
end

local function ModeLabel(entry)
  local result = {}
  local order = {"cooldown", "buff", "proc", "debuff", "stacks", "charges"}
  for _, key in ipairs(order) do
    if HasType(entry, key) then result[#result + 1] = key end
  end
  return table.concat(result, "+")
end

function RUI:BuildNativeTrackerImport(entry)
  if type(entry) ~= "table" or type(entry.spellID) ~= "number" or entry.spellID <= 0 then
    return nil, "selected tracker has no valid Spell ID"
  end
  if not HasSupportedType(entry) then
    return nil, "this tracker only uses Resource/Summon types, which are not generated in beta.34"
  end

  local wa, reason = WeakAurasAPI(self)
  if not wa then return nil, reason end
  if type(self.ResolveManagedWeakAuraIdentity) ~= "function" then
    return nil, "RetreatUI managed WeakAuras identity layer is unavailable"
  end

  local categoryOK, triggerCategory = pcall(wa.GetTriggerCategoryFor, "Cooldown Progress (Spell)")
  if not categoryOK or type(triggerCategory) ~= "string" or triggerCategory == "" then
    return nil, "WeakAuras did not expose the native Cooldown Progress (Spell) trigger category"
  end

  local versionOK, internalVersion = pcall(wa.InternalVersion)
  if not versionOK or type(internalVersion) ~= "number" then
    return nil, "WeakAuras internal version is unavailable"
  end

  local auraID, uid, isUpdate, identityReason = self:ResolveManagedWeakAuraIdentity(entry, wa)
  if not auraID then return nil, identityReason or "managed WeakAura identity could not be resolved" end

  local triggers, triggerReason = BuildTriggers(triggerCategory, entry)
  if not triggers then return nil, triggerReason end

  local settings = type(entry.settings) == "table" and entry.settings or {}
  local size = tonumber(settings.iconSize) or 36
  size = math.max(20, math.min(80, math.floor(size + 0.5)))

  local aura = {
    id = auraID,
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
    triggers = triggers,
  }

  if HasType(entry, "charges") then
    aura.cooldownSwipe = false
    aura.cooldownEdge = true
    aura.conditions = BuildChargeConditions(entry, triggers)
  end

  local subRegions = BuildSubRegions(entry)
  if subRegions then aura.subRegions = subRegions end

  if type(self.BuildWeakAurasNativeImportEnvelope) ~= "function" then
    return nil, "RetreatUI WeakAuras native envelope adapter is unavailable"
  end
  local envelope, envelopeReason = self:BuildWeakAurasNativeImportEnvelope(aura, {})
  if not envelope then return nil, envelopeReason end
  return envelope, nil, aura.id, ModeLabel(entry), isUpdate, uid
end

function RUI:BuildNativeCooldownTrackerTest(entry)
  return self:BuildNativeTrackerImport(entry)
end

function RUI:OpenNativeCooldownTrackerTest()
  if InCombatLockdown and InCombatLockdown() then
    return false, "leave combat before opening the WeakAuras import test"
  end

  local entry = FirstSupportedTracker(self)
  if not entry then
    return false, "select at least one supported Tracker Builder ability first"
  end

  local envelope, reason, auraID, mode, isUpdate, uid = self:BuildNativeTrackerImport(entry)
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
    auraName = entry.auraName,
    auraID = auraID,
    uid = uid,
    mode = mode,
    update = isUpdate == true,
  }

  local action = isUpdate and "update" or "import"
  return true, "WeakAuras native " .. action .. " opened for " .. tostring(entry.name) .. " (" .. tostring(mode) .. ")"
end

RUI._weakAurasNativeTrackerTest = true
