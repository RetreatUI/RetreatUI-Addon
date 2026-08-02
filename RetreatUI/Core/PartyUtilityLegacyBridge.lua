local RUI = RetreatUI
if not RUI or type(RUI.InitializePartyUtilityTracker) ~= "function" then return end

-- Safe Ascension legacy combat-log bridge for Party Utility V4.
--
-- CoA can expose CombatLogGetCurrentEventInfo while still passing the useful
-- 3.3.5 payload directly to COMBAT_LOG_EVENT_UNFILTERED. V4 preferred the API
-- whenever it existed, so remote party casts disappeared when that API returned
-- an empty payload. This bridge replaces only V4's combat-log event path:
--
--   * direct legacy event arguments are preferred;
--   * CombatLogGetCurrentEventInfo is only a read-only fallback;
--   * no tooltip scanner is created;
--   * no global function is replaced or modified;
--   * resolved casts are fed into V4 through its existing addon-message format.
--
-- The catalogue is name-first, following the same robust principle used by
-- CoACooldownManager: event IDs may change, while the displayed spell name is
-- usually stable and can be mapped to the runtime ID from the combat log.

local originalInitialize = RUI.InitializePartyUtilityTracker
local PREFIX = "RUIUTIL4"
local installed = false
local catalogDirty = true
local byID = {}
local byName = {}
local originalDriverOnEvent
local driver

local debugState = {
  received = 0,
  relevant = 0,
  directPayload = 0,
  apiPayload = 0,
  injected = 0,
  lastEvent = nil,
  lastSpellID = nil,
  lastSpellName = nil,
  lastSource = nil,
  lastPayloadSource = nil,
}

local ARCANE_TORRENT_IDS = {
  [50613] = true,
  [28730] = true,
  [25046] = true,
  [80483] = true,
  [69179] = true,
  [129597] = true,
}

-- Verified or user-supplied CoA interrupt records. Unknown cooldowns use V4's
-- conservative 15-second fallback until a verified value is supplied.
local COA_OVERRIDES = {
  {name = "Heartchill", id = 801739, cooldown = 30, kind = "direct", category = "interrupt"},
  {name = "Spellburn", id = 800808, cooldown = 15, kind = "direct", category = "interrupt", provisional = true},
  {name = "Shield of Denial", id = 704159, cooldown = 15, kind = "direct", category = "interrupt", provisional = true},
  {name = "Chainwhip", cooldown = 20, kind = "direct", category = "interrupt"},
  {name = "Arcane Torrent", id = 50613, cooldown = 120, kind = "torrent", category = "interrupt"},
}

local DIRECT_ALLOW_NAMES = {
  ["heartchill"] = true,
  ["spellburn"] = true,
  ["shield of denial"] = true,
  ["chainwhip"] = true,
  ["mind freeze"] = true,
  ["counterspell"] = true,
  ["kick"] = true,
  ["wind shear"] = true,
  ["pummel"] = true,
}

local DIRECT_DENY_PATTERNS = {
  "silence", "silencing", "stun", "fear", "horror", "incapacitat",
  "knock", "repulsion", "grip", "taunt", "disorient", "root", "sleep",
}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function ShortName(value)
  value = tostring(value or "")
  return value:match("^[^-]+") or value
end

local function Escape(value)
  return tostring(value or ""):gsub("[|~,;]", " ")
end

local function IsArcaneTorrent(name, spellID)
  return ARCANE_TORRENT_IDS[tonumber(spellID)] == true or Normalize(name) == "arcane torrent"
end

local function UtilityCategory(record)
  if type(record) ~= "table" then return nil end
  local category = Normalize(record.category)
  local cooldownCategory = Normalize(record.cooldownCategory)
  if record.combatRes == true then return "combatres" end
  if record.dispel == true or category == "dispel" then return "dispel" end
  if record.external == true then return "external" end
  if record.immunity == true then return "immunity" end
  if category == "taunt" then return "taunt" end
  if record.partyCooldown == true and cooldownCategory == "defensive" then return "defensive" end
  return nil
end

local function ExplicitDirect(record)
  if type(record) ~= "table" then return false end
  local name = Normalize(record.name)
  if IsArcaneTorrent(record.name, record.id) then return false end
  if record.directInterrupt == false then return false end
  if record.directInterrupt == true or record.primaryInterrupt == true then return true end
  if DIRECT_ALLOW_NAMES[name] then return true end
  if Normalize(record.category) ~= "interrupt" then return false end
  for _, pattern in ipairs(DIRECT_DENY_PATTERNS) do
    if string.find(name, pattern, 1, true) then return false end
  end
  -- Data Collector's broad "interrupt" category also contains silences, fears
  -- and disruption abilities. Do not guess from that category alone. Unknown
  -- real kicks are learned only after an actual SPELL_INTERRUPT event.
  return false
end

local function AddCapability(capability)
  if type(capability) ~= "table" then return end
  local nameKey = Normalize(capability.name)
  if nameKey == "" then return end

  capability.name = tostring(capability.name)
  capability.cooldown = math.max(0, tonumber(capability.cooldown) or 0)
  capability.kind = capability.kind or "utility"
  capability.category = capability.category or "utility"
  byName[nameKey] = capability

  local spellID = tonumber(capability.id)
  if spellID and spellID > 0 then
    capability.id = spellID
    byID[spellID] = capability
  end

  for _, alias in ipairs(capability.aliases or {}) do
    local key = Normalize(alias)
    if key ~= "" then byName[key] = capability end
  end
  for _, knownID in ipairs(capability.knownRankIDs or {}) do
    knownID = tonumber(knownID)
    if knownID and knownID > 0 then byID[knownID] = capability end
  end
  for _, knownID in ipairs(capability.waSpellIDs or {}) do
    knownID = tonumber(knownID)
    if knownID and knownID > 0 then byID[knownID] = capability end
  end
end

local function BuildCatalog()
  byID, byName = {}, {}

  for _, override in ipairs(COA_OVERRIDES) do
    local copy = {}
    for key, value in pairs(override) do copy[key] = value end
    AddCapability(copy)
  end

  for className, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      local kind, category
      if IsArcaneTorrent(record.name, record.id) then
        kind, category = "torrent", "interrupt"
      elseif ExplicitDirect(record) then
        kind, category = "direct", "interrupt"
      else
        category = UtilityCategory(record)
        if category then kind = "utility" end
      end

      if kind then
        AddCapability({
          id = tonumber(record.id),
          name = record.name,
          aliases = record.aliases,
          knownRankIDs = record.knownRankIDs,
          waSpellIDs = record.waSpellIDs,
          cooldown = tonumber(record.cooldownHint) or 0,
          kind = kind,
          category = category,
          className = className,
        })
      end
    end
  end

  -- Preserve every known Arcane Torrent rank/variant.
  local torrent = byName["arcane torrent"] or {
    name = "Arcane Torrent", cooldown = 120, kind = "torrent", category = "interrupt",
  }
  for spellID in pairs(ARCANE_TORRENT_IDS) do byID[spellID] = torrent end

  catalogDirty = false
end

local function ValidPayload(values)
  if type(values) ~= "table" then return false end
  local eventType = values[2]
  return type(eventType) == "string"
    and (string.find(eventType, "^SPELL_") ~= nil or string.find(eventType, "^RANGE_") ~= nil)
end

local function ReadPayload(...)
  local direct = {...}
  if ValidPayload(direct) then
    debugState.directPayload = debugState.directPayload + 1
    return direct, "legacy event"
  end

  if type(CombatLogGetCurrentEventInfo) == "function" then
    local ok, values = pcall(function() return {CombatLogGetCurrentEventInfo()} end)
    if ok and ValidPayload(values) then
      debugState.apiPayload = debugState.apiPayload + 1
      return values, "CombatLogGetCurrentEventInfo"
    end
  end
  return nil, "none"
end

local function ParsePayload(values)
  if not ValidPayload(values) then return nil end
  local modern = type(values[3]) == "boolean"
  if modern then
    return {
      eventType = values[2],
      sourceGUID = values[4],
      sourceName = values[5],
      spellID = tonumber(values[12]),
      spellName = values[13],
    }
  end
  return {
    eventType = values[2],
    sourceGUID = values[3],
    sourceName = values[4],
    spellID = tonumber(values[9]),
    spellName = values[10],
  }
end

local function UnitFullName(unit)
  if type(UnitName) ~= "function" then return nil end
  local name, realm = UnitName(unit)
  if not name then return nil end
  if realm and realm ~= "" then return tostring(name) .. "-" .. tostring(realm) end
  return tostring(name)
end

local function PartySender(sourceGUID, sourceName)
  local wantedName = Normalize(sourceName)
  local wantedShort = Normalize(ShortName(sourceName))
  local partyCount = type(GetNumPartyMembers) == "function" and (tonumber(GetNumPartyMembers()) or 0) or 0

  for index = 1, math.min(4, partyCount) do
    local unit = "party" .. tostring(index)
    local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
    local full = UnitFullName(unit)
    local fullKey = Normalize(full)
    local shortKey = Normalize(ShortName(full))
    if (sourceGUID and guid and sourceGUID == guid)
      or (wantedName ~= "" and (wantedName == fullKey or wantedName == shortKey))
      or (wantedShort ~= "" and wantedShort == shortKey) then
      return full or sourceName
    end
  end
  return nil
end

local function RuntimeCapability(parsed)
  if catalogDirty then BuildCatalog() end

  local capability = parsed.spellID and byID[parsed.spellID] or nil
  if not capability then capability = byName[Normalize(parsed.spellName)] end

  if not capability and parsed.spellID and type(GetSpellInfo) == "function" then
    local resolvedName = GetSpellInfo(parsed.spellID)
    capability = byName[Normalize(resolvedName)]
    if capability and (not parsed.spellName or parsed.spellName == "") then parsed.spellName = resolvedName end
  end

  -- SPELL_INTERRUPT proves that the combat-log spell itself interrupted a cast.
  -- Unknown interrupts are learned safely from that event without a tooltip scan.
  if not capability and parsed.eventType == "SPELL_INTERRUPT" and parsed.spellID then
    capability = {
      id = parsed.spellID,
      name = parsed.spellName or (GetSpellInfo and GetSpellInfo(parsed.spellID)) or tostring(parsed.spellID),
      cooldown = 15,
      kind = "direct",
      category = "interrupt",
      runtimeDiscovered = true,
    }
    AddCapability(capability)
  end

  if not capability then return nil end

  -- Bind an ID-changing event to the stable name entry for the remainder of the
  -- session. The original catalogue table is not mutated outside this bridge.
  if parsed.spellID and parsed.spellID > 0 and not byID[parsed.spellID] then
    byID[parsed.spellID] = capability
  end

  local runtime = {}
  for key, value in pairs(capability) do runtime[key] = value end
  runtime.id = parsed.spellID or runtime.id
  runtime.name = parsed.spellName or runtime.name
  if not runtime.id or runtime.id <= 0 then return nil end
  return runtime
end

local function InjectMessage(sender, message)
  if not originalDriverOnEvent or not driver then return false end
  originalDriverOnEvent(driver, "CHAT_MSG_ADDON", PREFIX, message, "PARTY", sender)
  debugState.injected = debugState.injected + 1
  return true
end

local function InjectCast(sender, capability)
  local cooldown = tonumber(capability.cooldown) or 0
  if cooldown <= 1.5 and capability.kind == "direct" then cooldown = 15 end
  if cooldown <= 1.5 then return false end

  InjectMessage(sender, table.concat({
    "L",
    capability.kind or "utility",
    capability.category or "utility",
    tostring(capability.id),
    string.format("%.1f", cooldown),
    Escape(capability.name),
  }, "|"))
  InjectMessage(sender, "E|1")
  InjectMessage(sender, table.concat({
    "C",
    tostring(capability.id),
    string.format("%.1f", cooldown),
    string.format("%.1f", cooldown),
  }, "|"))
  return true
end

local function HandleSafeCombatLog(...)
  debugState.received = debugState.received + 1
  local values, payloadSource = ReadPayload(...)
  local parsed = ParsePayload(values)
  if not parsed then return false end
  if parsed.eventType ~= "SPELL_CAST_SUCCESS" and parsed.eventType ~= "SPELL_INTERRUPT" then return false end

  local sender = PartySender(parsed.sourceGUID, parsed.sourceName)
  if not sender then return false end

  local capability = RuntimeCapability(parsed)
  if not capability then return false end

  debugState.relevant = debugState.relevant + 1
  debugState.lastEvent = parsed.eventType
  debugState.lastSpellID = capability.id
  debugState.lastSpellName = capability.name
  debugState.lastSource = sender
  debugState.lastPayloadSource = payloadSource

  return InjectCast(sender, capability)
end

local function InstallBridge()
  driver = _G.RetreatUIPartyUtilityDriverV4
  if not driver or driver.__ruiSafeLegacyBridge then return driver ~= nil end
  if type(driver.GetScript) ~= "function" or type(driver.SetScript) ~= "function" then return false end

  originalDriverOnEvent = driver:GetScript("OnEvent")
  if type(originalDriverOnEvent) ~= "function" then return false end

  driver:SetScript("OnEvent", function(frame, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      -- Do not call V4's old combat-log path: it prefers the empty API payload
      -- and redraws the complete tracker for every unrelated combat-log event.
      HandleSafeCombatLog(...)
      return
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
      or event == "ACTIVE_TALENT_GROUP_CHANGED"
      or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
      catalogDirty = true
    end
    return originalDriverOnEvent(frame, event, ...)
  end)

  driver.__ruiSafeLegacyBridge = true
  installed = true
  BuildCatalog()
  return true
end

function RUI:InitializePartyUtilityTracker(...)
  local results = {originalInitialize(self, ...)}
  InstallBridge()
  return unpack(results)
end

function RUI:RefreshPartyUtilityLegacyBridge()
  catalogDirty = true
  BuildCatalog()
  InstallBridge()
  return true
end

function RUI:GetPartyUtilityLegacyBridgeStatus()
  return installed,
    debugState.received,
    debugState.relevant,
    debugState.injected,
    debugState.directPayload,
    debugState.apiPayload,
    debugState.lastEvent,
    debugState.lastSpellID,
    debugState.lastSpellName,
    debugState.lastSource,
    debugState.lastPayloadSource
end

SLASH_RUIUTILITYDEBUG1 = "/ruiutilitydebug"
SlashCmdList.RUIUTILITYDEBUG = function()
  local status = {
    RUI:GetPartyUtilityLegacyBridgeStatus()
  }
  RUI:Print(string.format(
    "Utility bridge: %s | events=%d relevant=%d injected=%d | legacy=%d api=%d",
    status[1] and "ACTIVE" or "INACTIVE",
    tonumber(status[2]) or 0,
    tonumber(status[3]) or 0,
    tonumber(status[4]) or 0,
    tonumber(status[5]) or 0,
    tonumber(status[6]) or 0
  ))
  if status[7] then
    RUI:Print(string.format(
      "Last: %s — %s (%s) by %s via %s",
      tostring(status[7]),
      tostring(status[9] or "Unknown"),
      tostring(status[8] or "name"),
      tostring(status[10] or "Unknown"),
      tostring(status[11] or "unknown payload")
    ))
  end
end

RUI._partyUtilitySafeLegacyBridgeLoaded = true
