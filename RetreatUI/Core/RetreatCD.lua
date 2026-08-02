local RUI = RetreatUI
if not RUI or type(RUI.InitializePartyUtilityTracker) ~= "function" then return end

-- RetreatCD: safe party cooldown event engine for Project Ascension 3.3.5.
--
-- Clean-room implementation combining three proven ideas:
--   * party and party-pet UNIT_SPELLCAST_SUCCEEDED observation;
--   * legacy COMBAT_LOG_EVENT_UNFILTERED parsing with GUID ownership;
--   * name-first spell resolution so changed Ascension IDs can be rebound live.
--
-- Safety rules:
--   * never replace CombatLogGetCurrentEventInfo;
--   * never call CombatLogClearEntries;
--   * never scan spell tooltips or Character Advancement entries;
--   * never mutate RetreatUI's spell database;
--   * only forward matched party abilities into Party Utility V4's existing
--     addon-message state path.

local PREFIX = "RUIUTIL4"
local DEDUPE_WINDOW = 0.40
local DEFAULT_INTERRUPT_CD = 15
local originalInitialize = RUI.InitializePartyUtilityTracker

local installed = false
local driver
local originalOnEvent
local catalogDirty = true
local byID = {}
local byName = {}
local bySharedGroup = {}
local recent = {}
local activeByOwner = {}
local unknown = {}

local stats = {
  combatEvents = 0,
  unitEvents = 0,
  legacyPayloads = 0,
  apiPayloads = 0,
  partyEvents = 0,
  matched = 0,
  injected = 0,
  duplicates = 0,
  petEvents = 0,
  resets = 0,
  lastEvent = nil,
  lastSpellID = nil,
  lastSpellName = nil,
  lastOwner = nil,
  lastSource = nil,
  lastPayload = nil,
}

local ARCANE_TORRENT_IDS = {
  [25046] = true,
  [28730] = true,
  [50613] = true,
  [69179] = true,
  [80483] = true,
  [129597] = true,
}

-- Verified CoA entries and deliberately conservative provisional fallbacks.
-- Unknown cooldowns remain visibly provisional until verified in game.
local COA_FALLBACKS = {
  {name="Heartchill", id=801739, cooldown=30, kind="direct", category="interrupt"},
  {name="Spellburn", id=800808, cooldown=15, kind="direct", category="interrupt", provisional=true},
  {name="Shield of Denial", id=704159, cooldown=15, kind="direct", category="interrupt", provisional=true},
  {name="Chainwhip", cooldown=20, kind="direct", category="interrupt"},
  {name="Arcane Torrent", id=50613, cooldown=120, kind="torrent", category="interrupt"},
}

-- Normal 3.3.5 interrupt fallbacks found in both supplied addons. These are
-- fallback IDs only; a same-name CoA runtime ID takes over for the session.
local WOTLK_INTERRUPTS = {
  {name="Pummel", id=6552, cooldown=10},
  {name="Kick", id=1766, cooldown=10},
  {name="Mind Freeze", id=47528, cooldown=10},
  {name="Wind Shear", id=57994, cooldown=6},
  {name="Counterspell", id=2139, cooldown=24},
  {name="Spell Lock", id=19647, knownRankIDs={19244}, cooldown=24},
  {name="Shield Bash", id=72, cooldown=12},
}

local EXPLICIT_DIRECT = {
  ["heartchill"] = true,
  ["spellburn"] = true,
  ["shield of denial"] = true,
  ["chainwhip"] = true,
  ["pummel"] = true,
  ["kick"] = true,
  ["mind freeze"] = true,
  ["wind shear"] = true,
  ["counterspell"] = true,
  ["spell lock"] = true,
  ["shield bash"] = true,
}

local function Now()
  return type(GetTime) == "function" and GetTime() or 0
end

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

local function Copy(source)
  local result = {}
  for key, value in pairs(source or {}) do result[key] = value end
  return result
end

local function Wipe(target)
  if type(wipe) == "function" then return wipe(target) end
  for key in pairs(target or {}) do target[key] = nil end
  return target
end

local function FullUnitName(unit)
  if type(UnitName) ~= "function" then return nil end
  local name, realm = UnitName(unit)
  if not name then return nil end
  if realm and realm ~= "" then return tostring(name) .. "-" .. tostring(realm) end
  return tostring(name)
end

local function PartyCount()
  if type(GetNumPartyMembers) == "function" then
    return math.max(0, tonumber(GetNumPartyMembers()) or 0)
  end
  if type(GetNumSubgroupMembers) == "function" then
    return math.max(0, tonumber(GetNumSubgroupMembers()) or 0)
  end
  return 0
end

local function IsArcaneTorrent(name, spellID)
  return ARCANE_TORRENT_IDS[tonumber(spellID)] == true
    or Normalize(name) == "arcane torrent"
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

local function IsExplicitDirect(record)
  if type(record) ~= "table" then return false end
  if IsArcaneTorrent(record.name, record.id) then return false end
  if record.directInterrupt == false then return false end
  if record.directInterrupt == true or record.primaryInterrupt == true then return true end
  return EXPLICIT_DIRECT[Normalize(record.name)] == true
end

local function NormalizeTarget(value)
  if type(value) == "number" then return value end
  local numeric = tonumber(value)
  if numeric then return numeric end
  local text = Normalize(value)
  return text ~= "" and text or nil
end

local function NormalizeTargets(record)
  local result = {}
  local sources = {
    record and record.resets,
    record and record.cooldownResets,
    record and record.resetCooldowns,
  }
  for _, source in ipairs(sources) do
    if type(source) == "table" then
      for key, value in pairs(source) do
        local target = (type(value) == "string" or type(value) == "number") and value or key
        target = NormalizeTarget(target)
        if target then result[#result + 1] = target end
      end
    end
  end
  return result
end

local function AddCapability(capability)
  if type(capability) ~= "table" then return nil end
  local nameKey = Normalize(capability.name)
  if nameKey == "" then return nil end

  local existing = byName[nameKey]
  capability.name = tostring(capability.name)
  capability.key = nameKey
  capability.cooldown = math.max(0, tonumber(capability.cooldown) or 0)
  if capability.cooldown <= 1.5 and existing and tonumber(existing.cooldown) and existing.cooldown > 1.5 then
    capability.cooldown = existing.cooldown
  end
  if not tonumber(capability.id) and existing and tonumber(existing.id) then capability.id = existing.id end
  capability.kind = capability.kind or "utility"
  capability.category = capability.category or "defensive"
  capability.resets = capability.resets or {}
  byName[nameKey] = capability

  local spellID = tonumber(capability.id)
  if spellID and spellID > 0 then
    capability.id = spellID
    byID[spellID] = capability
  end

  for _, alias in ipairs(capability.aliases or {}) do
    local aliasKey = Normalize(alias)
    if aliasKey ~= "" then byName[aliasKey] = capability end
  end
  for _, knownID in ipairs(capability.knownRankIDs or {}) do
    knownID = tonumber(knownID)
    if knownID and knownID > 0 then byID[knownID] = capability end
  end
  for _, knownID in ipairs(capability.waSpellIDs or {}) do
    knownID = tonumber(knownID)
    if knownID and knownID > 0 then byID[knownID] = capability end
  end

  local group = Normalize(capability.sharedGroup)
  if group ~= "" then
    capability.sharedGroup = group
    bySharedGroup[group] = bySharedGroup[group] or {}
    bySharedGroup[group][nameKey] = capability
  end
  return capability
end

local function AddFallbacks()
  for _, entry in ipairs(COA_FALLBACKS) do AddCapability(Copy(entry)) end
  for _, entry in ipairs(WOTLK_INTERRUPTS) do
    local copy = Copy(entry)
    copy.kind = "direct"
    copy.category = "interrupt"
    AddCapability(copy)
  end

  local torrent = byName["arcane torrent"] or AddCapability({
    name="Arcane Torrent", id=50613, cooldown=120,
    kind="torrent", category="interrupt",
  })
  for spellID in pairs(ARCANE_TORRENT_IDS) do byID[spellID] = torrent end
end

local function BuildCatalog()
  byID, byName, bySharedGroup = {}, {}, {}
  AddFallbacks()

  for className, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      local kind, category
      if IsArcaneTorrent(record.name, record.id) then
        kind, category = "torrent", "interrupt"
      elseif IsExplicitDirect(record) then
        kind, category = "direct", "interrupt"
      else
        category = UtilityCategory(record)
        if category then kind = "utility" end
      end

      if kind then
        local sharedGroup = record.sharedCooldownGroup
          or record.sharedGroup
          or record.cooldownGroup
        AddCapability({
          id = tonumber(record.id),
          name = record.name,
          aliases = record.aliases,
          knownRankIDs = record.knownRankIDs,
          waSpellIDs = record.waSpellIDs,
          cooldown = tonumber(record.cooldownHint) or tonumber(record.cooldown) or 0,
          kind = kind,
          category = category,
          className = className,
          sharedGroup = sharedGroup,
          resets = NormalizeTargets(record),
          triggerAura = record.partyTrackOnAura == true,
          source = "RetreatUI database",
        })
      end
    end
  end

  catalogDirty = false
end

local function ValidCombatPayload(values)
  if type(values) ~= "table" then return false end
  local eventType = values[2]
  return type(eventType) == "string"
    and (eventType:find("^SPELL_") ~= nil or eventType:find("^RANGE_") ~= nil)
end

local function ReadCombatPayload(...)
  local direct = {...}
  if ValidCombatPayload(direct) then
    stats.legacyPayloads = stats.legacyPayloads + 1
    return direct, "legacy"
  end
  if type(CombatLogGetCurrentEventInfo) == "function" then
    local ok, values = pcall(function() return {CombatLogGetCurrentEventInfo()} end)
    if ok and ValidCombatPayload(values) then
      stats.apiPayloads = stats.apiPayloads + 1
      return values, "api"
    end
  end
  return nil, "none"
end

local function ParseCombatPayload(values)
  if not ValidCombatPayload(values) then return nil end
  if type(values[3]) == "boolean" then
    return {
      eventType = values[2],
      sourceGUID = values[4],
      sourceName = values[5],
      sourceFlags = values[6],
      spellID = tonumber(values[12]),
      spellName = values[13],
    }
  end
  return {
    eventType = values[2],
    sourceGUID = values[3],
    sourceName = values[4],
    sourceFlags = values[5],
    spellID = tonumber(values[9]),
    spellName = values[10],
  }
end

local function PartyOwnerByUnit(unit)
  if type(unit) ~= "string" then return nil end
  if unit:match("^party[1-4]$") then return unit, false end
  local owner = unit:match("^(party[1-4])pet$")
  if owner then return owner, true end
  return nil
end

local function PartyOwnerBySource(sourceGUID, sourceName)
  local wantedFull = Normalize(sourceName)
  local wantedShort = Normalize(ShortName(sourceName))
  for index = 1, math.min(4, PartyCount()) do
    local owner = "party" .. index
    local ownerGUID = type(UnitGUID) == "function" and UnitGUID(owner) or nil
    local petGUID = type(UnitGUID) == "function" and UnitGUID(owner .. "pet") or nil
    local full = FullUnitName(owner)
    local fullKey = Normalize(full)
    local shortKey = Normalize(ShortName(full))
    if sourceGUID and ownerGUID and sourceGUID == ownerGUID then return owner, false end
    if sourceGUID and petGUID and sourceGUID == petGUID then return owner, true end
    if wantedFull ~= "" and (wantedFull == fullKey or wantedFull == shortKey) then return owner, false end
    if wantedShort ~= "" and wantedShort == shortKey then return owner, false end
  end
  return nil
end

local function ExtractUnitSpell(unit, ...)
  local values = {...}
  local spellID
  local spellName
  for index = #values, 1, -1 do
    local candidate = tonumber(values[index])
    if candidate and candidate > 0 then spellID = candidate break end
  end
  for _, value in ipairs(values) do
    if type(value) == "string" and not value:find("^Cast%-") then
      if not spellName or byName[Normalize(value)] then spellName = value end
    end
  end
  if (not spellName or spellName == "") and spellID and type(GetSpellInfo) == "function" then
    spellName = GetSpellInfo(spellID)
  end
  return {
    eventType = "UNIT_SPELLCAST_SUCCEEDED",
    unit = unit,
    spellID = spellID,
    spellName = spellName,
  }
end

local function ResolveCapability(parsed, allowDiscovery)
  if catalogDirty then BuildCatalog() end
  local capability = parsed.spellID and byID[parsed.spellID] or nil
  if not capability then capability = byName[Normalize(parsed.spellName)] end

  if not capability and parsed.spellID and type(GetSpellInfo) == "function" then
    local resolvedName = GetSpellInfo(parsed.spellID)
    capability = byName[Normalize(resolvedName)]
    if capability and (not parsed.spellName or parsed.spellName == "") then
      parsed.spellName = resolvedName
    end
  end

  if not capability and allowDiscovery and parsed.spellID then
    capability = AddCapability({
      id = parsed.spellID,
      name = parsed.spellName
        or (type(GetSpellInfo) == "function" and GetSpellInfo(parsed.spellID))
        or tostring(parsed.spellID),
      cooldown = DEFAULT_INTERRUPT_CD,
      kind = "direct",
      category = "interrupt",
      source = "observed SPELL_INTERRUPT",
      runtimeDiscovered = true,
    })
  end
  if not capability then return nil end

  if parsed.spellID and parsed.spellID > 0 and not byID[parsed.spellID] then
    byID[parsed.spellID] = capability
  end

  local runtime = Copy(capability)
  runtime.id = parsed.spellID or runtime.id
  runtime.name = parsed.spellName or runtime.name
  if not runtime.id or runtime.id <= 0 then return nil end
  return runtime
end

local function InjectMessage(sender, message)
  if not driver or type(originalOnEvent) ~= "function" then return false end
  originalOnEvent(driver, "CHAT_MSG_ADDON", PREFIX, message, "PARTY", sender)
  stats.injected = stats.injected + 1
  return true
end

local function InjectCapability(sender, capability, remaining, duration)
  duration = math.max(0, tonumber(duration) or tonumber(capability.cooldown) or 0)
  remaining = math.max(0, tonumber(remaining) or duration)
  if duration <= 1.5 and capability.kind == "direct" then
    duration, remaining = DEFAULT_INTERRUPT_CD, DEFAULT_INTERRUPT_CD
  end
  if duration <= 1.5 then return false end

  InjectMessage(sender, table.concat({
    "L",
    capability.kind or "utility",
    capability.category or "defensive",
    tostring(capability.id),
    string.format("%.1f", duration),
    Escape(capability.name),
  }, "|"))
  InjectMessage(sender, "E|1")
  InjectMessage(sender, table.concat({
    "C",
    tostring(capability.id),
    string.format("%.1f", remaining),
    string.format("%.1f", duration),
  }, "|"))
  return true
end

local function OwnerKey(ownerUnit)
  local guid = type(UnitGUID) == "function" and UnitGUID(ownerUnit) or nil
  return guid or FullUnitName(ownerUnit) or ownerUnit
end

local function IsDuplicate(ownerKey, capability)
  local key = tostring(ownerKey) .. "|" .. tostring(capability.key or Normalize(capability.name))
  local now = Now()
  local previous = recent[key]
  recent[key] = now
  if previous and now - previous <= DEDUPE_WINDOW then
    stats.duplicates = stats.duplicates + 1
    return true
  end
  return false
end

local function RememberActive(ownerKey, capability, duration)
  activeByOwner[ownerKey] = activeByOwner[ownerKey] or {}
  activeByOwner[ownerKey][capability.key or Normalize(capability.name)] = {
    capability = Copy(capability),
    expires = Now() + duration,
    duration = duration,
  }
end

local function ClearActive(sender, ownerKey, entry)
  if not entry or not entry.capability or not entry.capability.id then return end
  InjectCapability(sender, entry.capability, 0, entry.duration or entry.capability.cooldown)
end

local function ApplyResets(sender, ownerKey, capability)
  if type(capability.resets) ~= "table" or #capability.resets == 0 then return end
  local active = activeByOwner[ownerKey]
  if not active then return end
  local now = Now()
  for key, entry in pairs(active) do
    if not entry.expires or entry.expires <= now then
      active[key] = nil
    else
      local matches = false
      for _, target in ipairs(capability.resets) do
        if type(target) == "number" and tonumber(entry.capability.id) == target then matches = true end
        if type(target) == "string" and Normalize(entry.capability.name) == target then matches = true end
      end
      if matches then
        ClearActive(sender, ownerKey, entry)
        active[key] = nil
        stats.resets = stats.resets + 1
      end
    end
  end
end

local function ApplySharedCooldown(sender, ownerKey, capability, duration)
  local group = Normalize(capability.sharedGroup)
  if group == "" then return end
  local active = activeByOwner[ownerKey]
  if not active then return end
  local now = Now()
  for key, entry in pairs(active) do
    if not entry.expires or entry.expires <= now then
      active[key] = nil
    elseif key ~= capability.key and Normalize(entry.capability.sharedGroup) == group then
      entry.expires = Now() + duration
      entry.duration = duration
      InjectCapability(sender, entry.capability, duration, duration)
    end
  end
end

local function RecordUnknown(parsed, ownerUnit, payload)
  local name = tostring(parsed.spellName or "Unknown")
  local key = Normalize(name) .. "|" .. tostring(parsed.spellID or 0)
  local item = unknown[key] or {name=name, id=parsed.spellID, count=0}
  item.count = item.count + 1
  item.owner = FullUnitName(ownerUnit) or ownerUnit
  item.event = parsed.eventType
  item.payload = payload
  unknown[key] = item
end

local function RecordPartyAbility(ownerUnit, isPet, parsed, payload)
  stats.partyEvents = stats.partyEvents + 1
  if isPet then stats.petEvents = stats.petEvents + 1 end

  local allowDiscovery = parsed.eventType == "SPELL_INTERRUPT"
  local capability = ResolveCapability(parsed, allowDiscovery)
  if not capability then
    RecordUnknown(parsed, ownerUnit, payload)
    return false
  end
  if parsed.eventType == "SPELL_AURA_APPLIED" and capability.triggerAura ~= true then return false end

  local ownerKey = OwnerKey(ownerUnit)
  if IsDuplicate(ownerKey, capability) then return false end
  local sender = FullUnitName(ownerUnit)
  if not sender then return false end

  local duration = tonumber(capability.cooldown) or 0
  if duration <= 1.5 and capability.kind == "direct" then duration = DEFAULT_INTERRUPT_CD end
  if duration <= 1.5 then return false end

  ApplyResets(sender, ownerKey, capability)
  ApplySharedCooldown(sender, ownerKey, capability, duration)
  RememberActive(ownerKey, capability, duration)
  InjectCapability(sender, capability, duration, duration)

  stats.matched = stats.matched + 1
  stats.lastEvent = parsed.eventType
  stats.lastSpellID = capability.id
  stats.lastSpellName = capability.name
  stats.lastOwner = sender
  stats.lastSource = isPet and "pet" or "player"
  stats.lastPayload = payload
  return true
end

local function HandleCombatLog(...)
  stats.combatEvents = stats.combatEvents + 1
  local values, payload = ReadCombatPayload(...)
  local parsed = ParseCombatPayload(values)
  if not parsed then return false end
  if parsed.eventType ~= "SPELL_CAST_SUCCESS"
    and parsed.eventType ~= "SPELL_INTERRUPT"
    and parsed.eventType ~= "SPELL_AURA_APPLIED" then return false end
  if parsed.eventType == "SPELL_AURA_APPLIED" then
    local auraCapability = ResolveCapability(parsed, false)
    if not auraCapability or auraCapability.triggerAura ~= true then return false end
  end

  local ownerUnit, isPet = PartyOwnerBySource(parsed.sourceGUID, parsed.sourceName)
  if not ownerUnit then return false end
  return RecordPartyAbility(ownerUnit, isPet, parsed, payload)
end

local function HandleUnitSpellcast(unit, ...)
  stats.unitEvents = stats.unitEvents + 1
  local ownerUnit, isPet = PartyOwnerByUnit(unit)
  if not ownerUnit then return false end
  local parsed = ExtractUnitSpell(unit, ...)
  return RecordPartyAbility(ownerUnit, isPet, parsed, "unit")
end

local function PurgeTransientState()
  local validOwners = {}
  for index = 1, math.min(4, PartyCount()) do
    local unit = "party" .. index
    validOwners[OwnerKey(unit)] = true
  end
  for ownerKey in pairs(activeByOwner) do
    if not validOwners[ownerKey] then activeByOwner[ownerKey] = nil end
  end
  Wipe(recent)
end

local function Install()
  driver = _G.RetreatUIPartyUtilityDriverV4
  if not driver then return false end
  if driver.__retreatCDEngine then installed = true return true end
  if type(driver.GetScript) ~= "function" or type(driver.SetScript) ~= "function" then return false end

  originalOnEvent = driver:GetScript("OnEvent")
  if type(originalOnEvent) ~= "function" then return false end

  driver:SetScript("OnEvent", function(frame, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      HandleCombatLog(...)
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      HandleUnitSpellcast(...)
      return
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
      PurgeTransientState()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
      or event == "ACTIVE_TALENT_GROUP_CHANGED"
      or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
      catalogDirty = true
    end
    return originalOnEvent(frame, event, ...)
  end)

  driver.__retreatCDEngine = true
  installed = true
  BuildCatalog()
  return true
end

function RUI:InitializePartyUtilityTracker(...)
  local results = {originalInitialize(self, ...)}
  Install()
  return unpack(results)
end

function RUI:RefreshRetreatCD()
  catalogDirty = true
  BuildCatalog()
  Install()
  return true
end

function RUI:GetRetreatCDStatus()
  return installed, stats
end

local function PrintStatus()
  RUI:Print(string.format(
    "RetreatCD: %s | combat=%d unit=%d party=%d matched=%d duplicate=%d pet=%d",
    installed and "ACTIVE" or "INACTIVE",
    stats.combatEvents, stats.unitEvents, stats.partyEvents,
    stats.matched, stats.duplicates, stats.petEvents
  ))
  RUI:Print(string.format(
    "Payloads: legacy=%d api=%d | messages=%d resets=%d | catalog=%d IDs / %d names",
    stats.legacyPayloads, stats.apiPayloads, stats.injected, stats.resets,
    (function() local count=0 for _ in pairs(byID) do count=count+1 end return count end)(),
    (function() local count=0 for _ in pairs(byName) do count=count+1 end return count end)()
  ))
  if stats.lastEvent then
    RUI:Print(string.format(
      "Last: %s — %s (%s) by %s [%s/%s]",
      tostring(stats.lastEvent), tostring(stats.lastSpellName or "Unknown"),
      tostring(stats.lastSpellID or "name"), tostring(stats.lastOwner or "Unknown"),
      tostring(stats.lastSource or "unknown"), tostring(stats.lastPayload or "unknown")
    ))
  end
end

local function PrintUnknowns()
  local rows = {}
  for _, item in pairs(unknown) do rows[#rows + 1] = item end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return tostring(a.name) < tostring(b.name)
  end)
  RUI:Print("RetreatCD unmatched party casts (top 15):")
  for index = 1, math.min(15, #rows) do
    local item = rows[index]
    RUI:Print(string.format(
      "%d. %s (%s) x%d — %s / %s",
      index, tostring(item.name), tostring(item.id or "no id"),
      tonumber(item.count) or 0, tostring(item.owner or "Unknown"),
      tostring(item.event or "event")
    ))
  end
  if #rows == 0 then RUI:Print("None recorded this session.") end
end

SLASH_RUICD1 = "/ruicd"
SlashCmdList.RUICD = function(message)
  local command, rest = tostring(message or ""):match("^(%S*)%s*(.-)$")
  command = Normalize(command)
  if command == "unknown" or command == "unmatched" then
    PrintUnknowns()
  elseif command == "refresh" then
    RUI:RefreshRetreatCD()
    RUI:Print("RetreatCD catalog refreshed.")
  elseif command == "clear" then
    Wipe(unknown)
    RUI:Print("RetreatCD unmatched-cast list cleared.")
  elseif command == "find" and rest ~= "" then
    local query = Normalize(rest)
    local found = 0
    for name, capability in pairs(byName) do
      if name:find(query, 1, true) then
        found = found + 1
        RUI:Print(string.format(
          "%s — id=%s cd=%ss kind=%s category=%s%s",
          capability.name, tostring(capability.id or "runtime"),
          tostring(capability.cooldown or 0), tostring(capability.kind),
          tostring(capability.category), capability.provisional and " (provisional)" or ""
        ))
      end
    end
    if found == 0 then RUI:Print("No RetreatCD ability matched: " .. rest) end
  else
    PrintStatus()
    RUI:Print("Commands: /ruicd status | unknown | clear | refresh | find <ability>")
  end
end

-- Keep the beta.14 diagnostic command useful for existing testers.
SLASH_RUIUTILITYDEBUG1 = "/ruiutilitydebug"
SlashCmdList.RUIUTILITYDEBUG = PrintStatus

RUI._retreatCDLoaded = true
