local RUI = RetreatUI
if not RUI or not RUI._retreatCDLoaded then return end

-- RetreatCD discovery v2.
-- Uses only verified combat-log payloads for discovery. The Ascension
-- UNIT_SPELLCAST_SUCCEEDED payload is intentionally ignored because rank/action
-- values can masquerade as spell IDs and create false candidates/matches.

local oldSlash = SlashCmdList and SlashCmdList.RUICD
if type(oldSlash) ~= "function" then return end

local DEDUPE_WINDOW = 0.40
local LONG_GAP_SECONDS = 15
local MAX_ROWS = 15

local knownByID = {}
local knownByName = {}
local candidates = {}
local matched = {}
local recentCandidates = {}
local recentMatched = {}
local initialized = false

local STRONG_PATTERNS = {
  "interrupt", "counterspell", "spell lock", "pummel", "kick",
  "heartchill", "spellburn", "chainwhip", "shield of denial",
  "arcane torrent", "combat res", "rebirth", "resurrection",
}

local WEAK_PATTERNS = {
  "shield", "barrier", "ward", "protection", "sacrifice",
  "suppression", "immune", "immunity", "fortitude", "deflection",
  "dispel", "cleanse", "purge", "remove curse", "freedom",
  "taunt", "challenge", "grip", "rescue",
}

local FALLBACK_KNOWN = {
  {"Heartchill", 801739},
  {"Spellburn", 800808},
  {"Shield of Denial", 704159},
  {"Chainwhip"},
  {"Arcane Torrent", 50613},
  {"Pummel", 6552},
  {"Kick", 1766},
  {"Mind Freeze", 47528},
  {"Wind Shear", 57994},
  {"Counterspell", 2139},
  {"Spell Lock", 19647},
  {"Spell Lock", 19244},
  {"Shield Bash", 72},
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

local function AddKnown(name, spellID)
  local canonical = tostring(name or "")
  local key = Normalize(canonical)
  if key ~= "" then knownByName[key] = canonical end
  spellID = tonumber(spellID)
  if spellID and spellID > 0 then knownByID[spellID] = canonical end
end

local function IsTrackedRecord(record)
  if type(record) ~= "table" then return false end
  local category = Normalize(record.category)
  local cooldownCategory = Normalize(record.cooldownCategory)
  return record.directInterrupt == true
    or record.primaryInterrupt == true
    or record.combatRes == true
    or record.dispel == true
    or record.external == true
    or record.immunity == true
    or category == "interrupt"
    or category == "dispel"
    or category == "taunt"
    or (record.partyCooldown == true and cooldownCategory == "defensive")
end

local function BuildKnownCatalog()
  Wipe(knownByID)
  Wipe(knownByName)

  for _, entry in ipairs(FALLBACK_KNOWN) do AddKnown(entry[1], entry[2]) end

  for _, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      if IsTrackedRecord(record) then
        AddKnown(record.name, record.id)
        for _, alias in ipairs(record.aliases or {}) do AddKnown(alias) end
        for _, spellID in ipairs(record.knownRankIDs or {}) do AddKnown(record.name, spellID) end
        for _, spellID in ipairs(record.waSpellIDs or {}) do AddKnown(record.name, spellID) end
      end
    end
  end
end

local function ValidCombatPayload(values)
  return type(values) == "table"
    and type(values[2]) == "string"
    and values[2]:find("^SPELL_") ~= nil
end

local function ReadCombatPayload(...)
  local direct = {...}
  if ValidCombatPayload(direct) then return direct, "legacy" end
  if type(CombatLogGetCurrentEventInfo) == "function" then
    local ok, values = pcall(function() return {CombatLogGetCurrentEventInfo()} end)
    if ok and ValidCombatPayload(values) then return values, "api" end
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

local function CanonicalKnown(spellID, spellName)
  spellID = tonumber(spellID)
  if spellID and knownByID[spellID] then return knownByID[spellID] end
  local nameKey = Normalize(spellName)
  if nameKey ~= "" and knownByName[nameKey] then return knownByName[nameKey] end
  if spellID and type(GetSpellInfo) == "function" then
    local resolvedName = GetSpellInfo(spellID)
    if knownByName[Normalize(resolvedName)] then return knownByName[Normalize(resolvedName)] end
  end
  return nil
end

local function ContainsPattern(name, patterns)
  local normalized = Normalize(name)
  for _, pattern in ipairs(patterns) do
    if normalized:find(pattern, 1, true) then return true end
  end
  return false
end

local function InvalidDiscoveryName(name)
  local normalized = Normalize(name)
  if normalized == "" or normalized == "unknown" then return true end
  if normalized:match("^rank%s+%d+$") then return true end
  if normalized:find("(nyi)", 1, true) then return true end
  if normalized == "automation mechanic immunity" then return true end
  return false
end

local function Dedupe(store, owner, identity)
  local key = tostring(owner) .. "|" .. tostring(identity)
  local now = Now()
  local previous = store[key]
  store[key] = now
  return previous and now - previous <= DEDUPE_WINDOW
end

local function RecordMatched(ownerUnit, isPet, parsed, canonical)
  local owner = FullUnitName(ownerUnit) or ownerUnit
  local identity = Normalize(canonical) .. "|" .. tostring(parsed.spellID or 0)
  if Dedupe(recentMatched, owner, identity) then return end

  local key = identity .. "|" .. tostring(owner)
  local item = matched[key] or {
    name = canonical,
    id = parsed.spellID,
    count = 0,
    owner = owner,
  }
  item.count = item.count + 1
  item.event = parsed.eventType
  item.pet = isPet == true
  matched[key] = item
end

local function RecordCandidate(ownerUnit, isPet, parsed, payload)
  local spellName = parsed.spellName
    or (parsed.spellID and type(GetSpellInfo) == "function" and GetSpellInfo(parsed.spellID))
  if InvalidDiscoveryName(spellName) then return end

  local owner = FullUnitName(ownerUnit) or ownerUnit
  local identity = tostring(tonumber(parsed.spellID) or Normalize(spellName))
  if Dedupe(recentCandidates, owner, identity) then return end

  local now = Now()
  local key = Normalize(spellName) .. "|" .. tostring(tonumber(parsed.spellID) or 0)
  local item = candidates[key]
  if not item then
    item = {
      name = spellName,
      id = tonumber(parsed.spellID),
      count = 0,
      firstSeen = now,
      lastSeen = nil,
      minGap = nil,
      strong = ContainsPattern(spellName, STRONG_PATTERNS),
      weak = ContainsPattern(spellName, WEAK_PATTERNS),
      interruptEvent = false,
    }
    candidates[key] = item
  end

  if item.lastSeen then
    local gap = now - item.lastSeen
    if gap > DEDUPE_WINDOW and (not item.minGap or gap < item.minGap) then item.minGap = gap end
  end
  item.lastSeen = now
  item.count = item.count + 1
  item.owner = owner
  item.event = parsed.eventType
  item.payload = payload
  item.pet = isPet == true
  if parsed.eventType == "SPELL_INTERRUPT" then item.interruptEvent = true end
end

local function PlausibleCoAID(item)
  return tonumber(item.id) and tonumber(item.id) >= 1000
end

local function IsCandidate(item)
  if item.interruptEvent or item.strong then return true end
  if item.weak and PlausibleCoAID(item) then
    return item.count == 1 or (item.minGap and item.minGap >= 8)
  end
  return PlausibleCoAID(item)
    and item.count >= 2
    and item.minGap
    and item.minGap >= LONG_GAP_SECONDS
end

local function CandidateScore(item)
  if item.interruptEvent then return 100000 + (item.count or 0) end
  if item.strong then return 75000 + (item.minGap or 0) end
  if item.weak then return 50000 + (item.minGap or 0) end
  return 1000 + (item.minGap or 0)
end

local function PrintCandidates()
  local rows = {}
  for _, item in pairs(candidates) do
    if IsCandidate(item) then rows[#rows + 1] = item end
  end
  table.sort(rows, function(a, b)
    local aScore, bScore = CandidateScore(a), CandidateScore(b)
    if aScore ~= bScore then return aScore > bScore end
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    return tostring(a.name) < tostring(b.name)
  end)

  RUI:Print("RetreatCD utility candidates (combat log, top 15):")
  for index = 1, math.min(MAX_ROWS, #rows) do
    local item = rows[index]
    local gap = item.minGap and string.format("%.1fs min gap", item.minGap) or "one observation"
    local reason = item.interruptEvent and "confirmed interrupt event"
      or (item.strong and "strong utility name"
      or (item.weak and "possible utility name" or "long observed interval"))
    RUI:Print(string.format(
      "%d. %s (%s) x%d — %s / %s / %s%s",
      index, tostring(item.name), tostring(item.id or "no id"),
      tonumber(item.count) or 0, tostring(item.owner or "Unknown"),
      gap, reason, item.pet and " / pet" or ""
    ))
  end
  if #rows == 0 then
    RUI:Print("No likely utility candidates recorded. /ruicd raw still shows every unmatched combat-log cast.")
  end
end

local function PrintMatched()
  local rows = {}
  for _, item in pairs(matched) do rows[#rows + 1] = item end
  table.sort(rows, function(a, b)
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    if tostring(a.name) ~= tostring(b.name) then return tostring(a.name) < tostring(b.name) end
    return tostring(a.owner) < tostring(b.owner)
  end)

  RUI:Print("RetreatCD matched party abilities (top 15):")
  for index = 1, math.min(MAX_ROWS, #rows) do
    local item = rows[index]
    RUI:Print(string.format(
      "%d. %s (%s) x%d — %s / %s%s",
      index, tostring(item.name), tostring(item.id or "name match"),
      tonumber(item.count) or 0, tostring(item.owner or "Unknown"),
      tostring(item.event or "event"), item.pet and " / pet" or ""
    ))
  end
  if #rows == 0 then RUI:Print("No known party cooldowns matched this session.") end
end

local frame = CreateFrame("Frame", "RetreatCDDiscoveryDriverV2")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE"
    or event == "PARTY_MEMBERS_CHANGED" or event == "SPELLS_CHANGED" then
    BuildKnownCatalog()
    initialized = true
    return
  end

  if not initialized then BuildKnownCatalog(); initialized = true end

  local values, payload = ReadCombatPayload(...)
  local parsed = ParseCombatPayload(values)
  if not parsed then return end
  if parsed.eventType ~= "SPELL_CAST_SUCCESS" and parsed.eventType ~= "SPELL_INTERRUPT" then return end

  local ownerUnit, isPet = PartyOwnerBySource(parsed.sourceGUID, parsed.sourceName)
  if not ownerUnit then return end

  local canonical = CanonicalKnown(parsed.spellID, parsed.spellName)
  if canonical then
    RecordMatched(ownerUnit, isPet, parsed, canonical)
  else
    RecordCandidate(ownerUnit, isPet, parsed, payload)
  end
end)

SlashCmdList.RUICD = function(message)
  local command = Normalize(tostring(message or ""):match("^(%S*)") or "")
  if command == "unknown" or command == "unmatched" or command == "candidates" then
    PrintCandidates()
  elseif command == "matched" or command == "matches" then
    PrintMatched()
  elseif command == "raw" then
    oldSlash("unknown")
  elseif command == "clear" then
    Wipe(candidates)
    Wipe(matched)
    Wipe(recentCandidates)
    Wipe(recentMatched)
    oldSlash("clear")
  else
    oldSlash(message)
    if command == "" or command == "status" then
      RUI:Print("Extra diagnostics: /ruicd matched | unknown | raw")
    end
  end
end

function RUI:GetRetreatCDDiscoveryStatus()
  local total, likely, matchedCount = 0, 0, 0
  for _, item in pairs(candidates) do
    total = total + 1
    if IsCandidate(item) then likely = likely + 1 end
  end
  for _ in pairs(matched) do matchedCount = matchedCount + 1 end
  return total, likely, matchedCount
end

RUI._retreatCDDiscoveryV2Loaded = true
