local RUI = RetreatUI
if not RUI or not RUI._retreatCDLoaded then return end

-- RetreatCD discovery filter.
--
-- RetreatCD deliberately sees every successful party cast so a missing CoA
-- ability can be discovered without scanning tooltips or Character Advancement.
-- A raw list is useful for development, but normal rotational abilities quickly
-- drown out the cooldowns we actually care about. This module keeps the raw
-- command available while presenting a filtered candidate list by default.

local oldSlash = SlashCmdList and SlashCmdList.RUICD
if type(oldSlash) ~= "function" then return end

local DEDUPE_WINDOW = 0.40
local LONG_GAP_SECONDS = 10
local MAX_ROWS = 15

local knownByID = {}
local knownByName = {}
local candidates = {}
local recent = {}
local initialized = false

-- Confirmed high-frequency/non-party-cooldown spells observed during the first
-- live beta.15 test. They remain visible through /ruicd raw.
local OBSERVED_ROTATION_NOISE = {
  ["blade of the empire"] = true,
  ["burning slap"] = true,
  ["ballad of the dragonslayer"] = true,
  ["sanity tap"] = true,
  ["ballad of the conqueror"] = true,
  ["seeking flame"] = true,
  ["infernal strike"] = true,
  ["meatsaw"] = true,
  ["skulltaker"] = true,
  ["ram"] = true,
  ["bane of chaos"] = true,
  ["burst"] = true,
  ["flames of xoroth"] = true,
  ["annihilation"] = true,
  ["inner demon"] = true,
}

local CANDIDATE_PATTERNS = {
  "interrupt", "counterspell", "spell lock", "pummel", "kick", "silence",
  "shield", "barrier", "ward", "protection", "sacrifice", "suppression",
  "immune", "immunity", "fortitude", "guardian", "deflection",
  "dispel", "cleanse", "purge", "remove curse", "freedom",
  "resurrect", "resurrection", "rebirth", "revive", "combat res",
  "taunt", "challenge", "grip", "torrent", "rescue",
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
  local key = Normalize(name)
  if key ~= "" then knownByName[key] = true end
  spellID = tonumber(spellID)
  if spellID and spellID > 0 then knownByID[spellID] = true end
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

local function PartyOwnerByUnit(unit)
  if type(unit) ~= "string" then return nil end
  if unit:match("^party[1-4]$") then return unit, false end
  local owner = unit:match("^(party[1-4])pet$")
  if owner then return owner, true end
  return nil
end

local function ExtractUnitSpell(...)
  local values = {...}
  local spellID
  local spellName
  for index = #values, 1, -1 do
    local candidate = tonumber(values[index])
    if candidate and candidate > 0 then spellID = candidate break end
  end
  for _, value in ipairs(values) do
    if type(value) == "string" and not value:find("^Cast%-") then spellName = value end
  end
  if (not spellName or spellName == "") and spellID and type(GetSpellInfo) == "function" then
    spellName = GetSpellInfo(spellID)
  end
  return spellID, spellName
end

local function IsKnown(spellID, spellName)
  spellID = tonumber(spellID)
  if spellID and knownByID[spellID] then return true end
  local nameKey = Normalize(spellName)
  if nameKey ~= "" and knownByName[nameKey] then return true end
  if spellID and type(GetSpellInfo) == "function" then
    local resolvedName = GetSpellInfo(spellID)
    if knownByName[Normalize(resolvedName)] then return true end
  end
  return false
end

local function CandidateKeyword(name)
  local normalized = Normalize(name)
  for _, pattern in ipairs(CANDIDATE_PATTERNS) do
    if normalized:find(pattern, 1, true) then return true end
  end
  return false
end

local function Record(ownerUnit, isPet, eventType, spellID, spellName, payload)
  spellName = spellName or (spellID and type(GetSpellInfo) == "function" and GetSpellInfo(spellID))
  local normalized = Normalize(spellName)
  if normalized == "" or OBSERVED_ROTATION_NOISE[normalized] then return end
  if IsKnown(spellID, spellName) then return end

  local owner = FullUnitName(ownerUnit) or ownerUnit
  local identity = tostring(tonumber(spellID) or normalized)
  local dedupeKey = tostring(owner) .. "|" .. identity
  local now = Now()
  local lastRecent = recent[dedupeKey]
  recent[dedupeKey] = now
  if lastRecent and now - lastRecent <= DEDUPE_WINDOW then return end

  local key = normalized .. "|" .. tostring(tonumber(spellID) or 0)
  local item = candidates[key]
  if not item then
    item = {
      name = spellName or "Unknown",
      id = tonumber(spellID),
      count = 0,
      firstSeen = now,
      lastSeen = nil,
      minGap = nil,
      interruptEvent = false,
      keyword = CandidateKeyword(spellName),
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
  item.event = eventType
  item.payload = payload
  item.pet = isPet == true
  if eventType == "SPELL_INTERRUPT" then item.interruptEvent = true end
end

local function IsCandidate(item)
  if item.interruptEvent or item.keyword then return true end
  return item.minGap and item.minGap >= LONG_GAP_SECONDS
end

local function Score(item)
  if item.interruptEvent then return 100000 + (item.count or 0) end
  if item.keyword then return 50000 + (item.minGap or 0) end
  return 1000 + (item.minGap or 0)
end

local function PrintCandidates()
  local rows = {}
  for _, item in pairs(candidates) do
    if IsCandidate(item) then rows[#rows + 1] = item end
  end
  table.sort(rows, function(a, b)
    local aScore, bScore = Score(a), Score(b)
    if aScore ~= bScore then return aScore > bScore end
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    return tostring(a.name) < tostring(b.name)
  end)

  RUI:Print("RetreatCD utility candidates (top 15):")
  for index = 1, math.min(MAX_ROWS, #rows) do
    local item = rows[index]
    local gap = item.minGap and string.format("%.1fs min gap", item.minGap) or "one observation"
    local reason = item.interruptEvent and "confirmed interrupt event"
      or (item.keyword and "utility-like name" or "long observed interval")
    RUI:Print(string.format(
      "%d. %s (%s) x%d — %s / %s / %s%s",
      index, tostring(item.name), tostring(item.id or "no id"),
      tonumber(item.count) or 0, tostring(item.owner or "Unknown"),
      gap, reason, item.pet and " / pet" or ""
    ))
  end
  if #rows == 0 then
    RUI:Print("No likely utility candidates yet. Use the group's real interrupts/defensives, or run /ruicd raw for every unmatched cast.")
  end
end

local frame = CreateFrame("Frame", "RetreatCDDiscoveryDriver")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE"
    or event == "PARTY_MEMBERS_CHANGED" or event == "SPELLS_CHANGED" then
    BuildKnownCatalog()
    initialized = true
    return
  end

  if not initialized then BuildKnownCatalog(); initialized = true end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local values, payload = ReadCombatPayload(...)
    local parsed = ParseCombatPayload(values)
    if not parsed then return end
    if parsed.eventType ~= "SPELL_CAST_SUCCESS" and parsed.eventType ~= "SPELL_INTERRUPT" then return end
    local ownerUnit, isPet = PartyOwnerBySource(parsed.sourceGUID, parsed.sourceName)
    if ownerUnit then
      Record(ownerUnit, isPet, parsed.eventType, parsed.spellID, parsed.spellName, payload)
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit = ...
    local ownerUnit, isPet = PartyOwnerByUnit(unit)
    if not ownerUnit then return end
    local spellID, spellName = ExtractUnitSpell(select(2, ...))
    Record(ownerUnit, isPet, event, spellID, spellName, "unit")
  end
end)

SlashCmdList.RUICD = function(message)
  local command = Normalize(tostring(message or ""):match("^(%S*)") or "")
  if command == "unknown" or command == "unmatched" or command == "candidates" then
    PrintCandidates()
  elseif command == "raw" then
    oldSlash("unknown")
  elseif command == "clear" then
    Wipe(candidates)
    Wipe(recent)
    oldSlash("clear")
  else
    oldSlash(message)
  end
end

function RUI:GetRetreatCDDiscoveryStatus()
  local total, likely = 0, 0
  for _, item in pairs(candidates) do
    total = total + 1
    if IsCandidate(item) then likely = likely + 1 end
  end
  return total, likely
end

RUI._retreatCDDiscoveryLoaded = true
