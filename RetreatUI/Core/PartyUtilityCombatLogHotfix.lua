local RUI = RetreatUI
if not RUI or type(RUI.InitializePartyUtilityTracker) ~= "function" then return end

-- Ascension exposes CombatLogGetCurrentEventInfo on some client builds while
-- still delivering the actual 3.3.5 combat-log payload directly to the event.
-- PartyUtilityV4 preferred the function whenever it existed; when that function
-- returned an empty or incomplete payload, both interrupt and utility casts were
-- silently discarded. This compatibility layer selects the valid payload,
-- normalises it to the legacy layout expected by V4 and resolves rank-changing
-- custom spells by name/alias before the original tracker handles the event.

local originalInitialize = RUI.InitializePartyUtilityTracker
local unpack = unpack or table.unpack
local relevantByID = {}
local relevantByName = {}
local indexBuilt = false
local debugState = {
  received = 0,
  directPayload = 0,
  apiPayload = 0,
  canonicalized = 0,
  forwarded = 0,
  lastEvent = nil,
  lastSpellID = nil,
  lastSpellName = nil,
  lastSource = nil,
}

local ARCANE_TORRENT_IDS = {50613, 28730, 25046, 80483, 69179, 129597}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function RelevantRecord(record)
  if type(record) ~= "table" then return false end
  local category = Normalize(record.category)
  local cooldownCategory = Normalize(record.cooldownCategory)
  return category == "interrupt"
    or category == "taunt"
    or category == "dispel"
    or record.combatRes == true
    or record.dispel == true
    or record.external == true
    or record.immunity == true
    or (record.partyCooldown == true and cooldownCategory == "defensive")
end

local function AddRelevantID(spellID, canonicalID)
  spellID, canonicalID = tonumber(spellID), tonumber(canonicalID)
  if spellID and spellID > 0 and canonicalID and canonicalID > 0 then
    relevantByID[spellID] = canonicalID
  end
end

local function AddRelevantName(name, canonicalID)
  local key = Normalize(name)
  canonicalID = tonumber(canonicalID)
  if key ~= "" and canonicalID and canonicalID > 0 then relevantByName[key] = canonicalID end
end

local function BuildRelevantIndex()
  relevantByID, relevantByName = {}, {}
  for _, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      if RelevantRecord(record) then
        local canonicalID = tonumber(record.id)
        if canonicalID and canonicalID > 0 then
          AddRelevantID(canonicalID, canonicalID)
          AddRelevantName(record.name, canonicalID)
          for _, alias in ipairs(record.aliases or {}) do AddRelevantName(alias, canonicalID) end
          for _, spellID in ipairs(record.waSpellIDs or {}) do AddRelevantID(spellID, canonicalID) end
          for _, spellID in ipairs(record.knownRankIDs or {}) do AddRelevantID(spellID, canonicalID) end
        end
      end
    end
  end

  for _, spellID in ipairs(ARCANE_TORRENT_IDS) do AddRelevantID(spellID, spellID) end
  AddRelevantName("Arcane Torrent", ARCANE_TORRENT_IDS[1])
  indexBuilt = true
end

local function ValidPayload(values)
  if type(values) ~= "table" then return false end
  local eventType = values[2]
  if type(eventType) ~= "string" or eventType == "" then return false end
  return eventType:find("^SPELL_") ~= nil or eventType:find("^RANGE_") ~= nil
end

local function ReadCombatPayload(...)
  local direct = {...}
  if ValidPayload(direct) then
    debugState.directPayload = debugState.directPayload + 1
    return direct
  end

  if type(CombatLogGetCurrentEventInfo) == "function" then
    local ok, values = pcall(function() return {CombatLogGetCurrentEventInfo()} end)
    if ok and ValidPayload(values) then
      debugState.apiPayload = debugState.apiPayload + 1
      return values
    end
  end
  return nil
end

local function ParsePayload(values)
  if not ValidPayload(values) then return nil end
  local modern = type(values[3]) == "boolean"
  if modern then
    return {
      timestamp = values[1],
      eventType = values[2],
      sourceGUID = values[4],
      sourceName = values[5],
      sourceFlags = values[6],
      destGUID = values[8],
      destName = values[9],
      destFlags = values[10],
      spellID = tonumber(values[12]),
      spellName = values[13],
      spellSchool = values[14],
    }
  end
  return {
    timestamp = values[1],
    eventType = values[2],
    sourceGUID = values[3],
    sourceName = values[4],
    sourceFlags = values[5],
    destGUID = values[6],
    destName = values[7],
    destFlags = values[8],
    spellID = tonumber(values[9]),
    spellName = values[10],
    spellSchool = values[11],
  }
end

local function ResolveCanonicalSpellID(spellID, spellName)
  if not indexBuilt then BuildRelevantIndex() end
  spellID = tonumber(spellID)
  local canonical = spellID and relevantByID[spellID] or nil
  if not canonical then canonical = relevantByName[Normalize(spellName)] end
  if canonical then return canonical end

  -- GetSpellInfo normalises rank-specific Ascension IDs to their displayed
  -- spell name. Use it when the combat log supplied only an unknown rank ID.
  if spellID and type(GetSpellInfo) == "function" then
    local resolvedName = GetSpellInfo(spellID)
    canonical = relevantByName[Normalize(resolvedName)]
    if canonical then return canonical end
  end
  return spellID
end

local function ShouldForward(parsed, canonicalID)
  local eventType = parsed and parsed.eventType
  if eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_INTERRUPT" then return true end

  -- A few Ascension utility spells expose only their aura application in the
  -- combat log. Forward those as a successful use only when the spell resolves
  -- to a known interrupt/party-utility record, avoiding unrelated aura spam.
  if (eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH")
    and canonicalID and (relevantByID[canonicalID] or relevantByName[Normalize(parsed.spellName)]) then
    return true
  end
  return false
end

local function LegacyPayload(parsed, canonicalID)
  local eventType = parsed.eventType
  if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
    eventType = "SPELL_CAST_SUCCESS"
  end
  return {
    parsed.timestamp or 0,
    eventType,
    parsed.sourceGUID,
    parsed.sourceName,
    parsed.sourceFlags or 0,
    parsed.destGUID,
    parsed.destName,
    parsed.destFlags or 0,
    canonicalID or parsed.spellID,
    parsed.spellName,
    parsed.spellSchool or 0,
  }
end

local function ForwardCombatLog(originalOnEvent, frame, event, ...)
  debugState.received = debugState.received + 1
  local values = ReadCombatPayload(...)
  local parsed = ParsePayload(values)
  if not parsed then return originalOnEvent(frame, event, ...) end

  local canonicalID = ResolveCanonicalSpellID(parsed.spellID, parsed.spellName)
  if canonicalID and parsed.spellID and canonicalID ~= parsed.spellID then
    debugState.canonicalized = debugState.canonicalized + 1
  end

  debugState.lastEvent = parsed.eventType
  debugState.lastSpellID = canonicalID or parsed.spellID
  debugState.lastSpellName = parsed.spellName
  debugState.lastSource = parsed.sourceName

  if not ShouldForward(parsed, canonicalID) then
    return originalOnEvent(frame, event, ...)
  end

  local payload = LegacyPayload(parsed, canonicalID)
  local savedGetter = _G.CombatLogGetCurrentEventInfo
  _G.CombatLogGetCurrentEventInfo = nil
  local results = {pcall(originalOnEvent, frame, event, unpack(payload))}
  _G.CombatLogGetCurrentEventInfo = savedGetter

  local ok = table.remove(results, 1)
  if not ok then error(results[1]) end
  debugState.forwarded = debugState.forwarded + 1
  return unpack(results)
end

local function InstallDriverPatch()
  local driver = _G.RetreatUIPartyUtilityDriverV4
  if not driver or driver.__ruiCombatLogPayloadHotfix then return false end
  if type(driver.GetScript) ~= "function" or type(driver.SetScript) ~= "function" then return false end

  local originalOnEvent = driver:GetScript("OnEvent")
  if type(originalOnEvent) ~= "function" then return false end

  driver:SetScript("OnEvent", function(frame, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      return ForwardCombatLog(originalOnEvent, frame, event, ...)
    end
    return originalOnEvent(frame, event, ...)
  end)
  driver.__ruiCombatLogPayloadHotfix = true
  return true
end

function RUI:InitializePartyUtilityTracker(...)
  local results = {originalInitialize(self, ...)}
  InstallDriverPatch()
  return unpack(results)
end

function RUI:RefreshPartyUtilityCombatLogIndex()
  BuildRelevantIndex()
  InstallDriverPatch()
  return true
end

function RUI:GetPartyUtilityCombatLogStatus()
  return debugState.received, debugState.forwarded, debugState.canonicalized,
    debugState.lastEvent, debugState.lastSpellID, debugState.lastSpellName, debugState.lastSource
end

RUI._partyUtilityCombatLogHotfixLoaded = true
