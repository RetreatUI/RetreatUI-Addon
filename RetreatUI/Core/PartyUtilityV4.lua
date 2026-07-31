local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

-- Party Utility v4
-- One compact interrupt row per group member, direct interrupts only, with
-- Blood Elf Arcane Torrent always retained as a second independent icon.
-- Remote cooldowns are learned from addon sync when available and from the
-- combat log for every party member, so the tracker no longer depends on
-- UNIT_SPELLCAST_SUCCEEDED firing for other players.

local W = RUI.HUDWidgets
local PREFIX = "RUIUTIL4"
local UPDATE_INTERVAL = 0.20
local BROADCAST_DELAY = 0.75
local INTERRUPT_WIDTH = 210
local HEADER_HEIGHT = 20
local ROW_HEIGHT = 25
local ROW_GAP = 1
local ICON_SIZE = 20
local UTILITY_ICON_SIZE = 23
local UTILITY_SPACING = 2
local MAX_UTILITY_ICONS = 6
local ARCANE_TORRENT_DEFAULT_ID = 50613
local ARCANE_TORRENT_IDS = {50613, 28730, 25046, 80483, 69179, 129597}
local ARCANE_TORRENT_TEXTURE = "Interface\\Icons\\Spell_Shadow_Teleport"
local UNIT_ORDER = {"player", "party1", "party2", "party3", "party4"}

local CATEGORY_COLORS = {
  combatres = {0.34, 0.95, 0.38},
  dispel = {0.20, 0.72, 1.00},
  external = {0.92, 0.50, 1.00},
  defensive = {1.00, 0.42, 0.12},
  immunity = {0.95, 0.95, 0.95},
  taunt = {1.00, 0.18, 0.18},
  interrupt = {1.00, 0.82, 0.12},
  torrent = {0.72, 0.40, 1.00},
}

local DIRECT_DENY_PATTERNS = {
  "silence", "silencing", "stun", "fear", "horror", "incapacitat",
  "knock", "repulsion", "grip", "taunt", "disorient", "root", "sleep",
  "torrent",
}

local initialized = false
local driver
local elapsed = 0
local previewMode = false
local interruptEditorPreview = false
local localCapabilities = {}
local localCooldownState = {}
local globalByID = {}
local globalByName = {}
local inferredDirectByClass = {}
local peers = {}
local remoteCooldowns = {}
local observedByGUID = {}
local interruptFrame
local utilityFrames = {}
local unitFrames = {}
local settingsFrame
local tooltipScanner

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function ShortName(value)
  value = tostring(value or "Unknown")
  return value:match("^[^-]+") or value
end

local function Escape(value)
  return tostring(value or ""):gsub("[|~,;]", " ")
end

local function Now()
  return GetTime and GetTime() or 0
end

local function PartyCount()
  if type(GetNumPartyMembers) == "function" then return math.max(0, tonumber(GetNumPartyMembers()) or 0) end
  if type(GetNumSubgroupMembers) == "function" then return math.max(0, tonumber(GetNumSubgroupMembers()) or 0) end
  return 0
end

local function IsInRaidSafe()
  return type(IsInRaid) == "function" and IsInRaid() == true
end

local function IsInPartySafe()
  if IsInRaidSafe() then return false end
  if type(IsInGroup) == "function" and IsInGroup() then return true end
  return PartyCount() > 0
end

local function PlayerFullName()
  if not UnitName then return "player" end
  local name, realm = UnitName("player")
  if realm and realm ~= "" then return tostring(name) .. "-" .. tostring(realm) end
  return tostring(name or "player")
end

local function UnitRaceKey(unit)
  if type(UnitRace) ~= "function" then return nil end
  local ok, localized, token = pcall(UnitRace, unit)
  if not ok then return nil end
  return Normalize(token or localized)
end

local function IsBloodElfUnit(unit)
  local key = UnitRaceKey(unit)
  return key == "bloodelf" or key == "blood elf"
end

local function UnitClassName(unit)
  if type(UnitClass) ~= "function" then return nil end
  local ok, localized, token = pcall(UnitClass, unit)
  if not ok then return nil end
  for _, value in ipairs({token, localized}) do
    local className = RUI.NormalizeClassName and RUI:NormalizeClassName(value) or value
    if className and RUI.spellDatabase and RUI.spellDatabase[className] then return className end
  end
  return nil
end

local function UnitRole(unit)
  if type(UnitGroupRolesAssigned) == "function" then
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if ok and role and role ~= "NONE" then return role end
  end
  return "NONE"
end

local function GroupMembers()
  local byUnit, byName, byGUID = {}, {}, {}
  local function Add(unit)
    if UnitExists and not UnitExists(unit) then return end
    local name, realm = UnitName and UnitName(unit)
    if not name then return end
    local full = realm and realm ~= "" and (name .. "-" .. realm) or name
    local member = {
      unit = unit,
      name = full,
      short = ShortName(full),
      guid = UnitGUID and UnitGUID(unit) or nil,
      className = UnitClassName(unit),
      role = UnitRole(unit),
      bloodElf = IsBloodElfUnit(unit),
    }
    byUnit[unit] = member
    byName[Normalize(full)] = member
    byName[Normalize(name)] = member
    if member.guid then byGUID[member.guid] = member end
  end
  Add("player")
  for index = 1, math.min(4, PartyCount()) do Add("party" .. index) end
  return byUnit, byName, byGUID
end

local function EnsureSettings()
  local db = RUI:EnsureDB()
  db.partyUtility = db.partyUtility or {}
  db.partyInterrupts = db.partyInterrupts or {}
  local utility = db.partyUtility
  local interrupts = db.partyInterrupts
  if utility.enabled == nil then utility.enabled = true end
  if utility.showReady == nil then utility.showReady = true end
  if utility.showSelf == nil then utility.showSelf = true end
  if utility.showSolo == nil then utility.showSolo = false end
  if interrupts.enabled == nil then interrupts.enabled = true end
  if interrupts.showSelf == nil then interrupts.showSelf = true end
  if interrupts.showSolo == nil then interrupts.showSolo = false end
  return utility, interrupts
end

local function HasRealTexture(texture)
  if type(texture) ~= "string" or texture == "" then return false end
  return not Normalize(texture):find("questionmark", 1, true)
end

local function SpellTexture(spellID, fallback)
  if GetSpellInfo and spellID then
    local _, _, texture = GetSpellInfo(spellID)
    if HasRealTexture(texture) then return texture end
  end
  return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function IsArcaneTorrentRecord(record)
  if type(record) ~= "table" then return false end
  local id = tonumber(record.id)
  for _, spellID in ipairs(ARCANE_TORRENT_IDS) do if id == spellID then return true end end
  return Normalize(record.name) == "arcane torrent"
end

local function TooltipText(record)
  if not CreateFrame or type(record) ~= "table" then return "" end
  if not tooltipScanner then
    tooltipScanner = CreateFrame("GameTooltip", "RetreatUIDirectInterruptScanner", UIParent, "GameTooltipTemplate")
  end
  if not tooltipScanner then return "" end
  tooltipScanner:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
  tooltipScanner:ClearLines()
  local shown = false
  local bookIndex = RUI.GetSpellRecordBookIndex and RUI:GetSpellRecordBookIndex(record)
  if bookIndex and tooltipScanner.SetSpellBookItem then
    shown = pcall(tooltipScanner.SetSpellBookItem, tooltipScanner, bookIndex, BOOKTYPE_SPELL or "spell")
  end
  if not shown and tooltipScanner.SetHyperlink then
    local spellID = RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(record) or tonumber(record.id)
    if spellID then shown = pcall(tooltipScanner.SetHyperlink, tooltipScanner, "spell:" .. tostring(spellID)) end
  end
  if not shown then return "" end
  local parts = {}
  for index = 1, tooltipScanner:NumLines() do
    for _, side in ipairs({"TextLeft", "TextRight"}) do
      local fs = _G["RetreatUIDirectInterruptScanner" .. side .. index]
      local text = fs and fs:GetText()
      if text and text ~= "" then parts[#parts + 1] = Normalize(text) end
    end
  end
  return table.concat(parts, "\n")
end

local function IsDirectInterruptRecord(record)
  if type(record) ~= "table" or Normalize(record.category) ~= "interrupt" then return false end
  if IsArcaneTorrentRecord(record) then return false end
  if record.directInterrupt == false then return false end
  if record.directInterrupt == true or record.primaryInterrupt == true then return true end
  local name = Normalize(record.name)
  for _, pattern in ipairs(DIRECT_DENY_PATTERNS) do
    if name:find(pattern, 1, true) then return false end
  end
  local tooltip = TooltipText(record)
  if tooltip ~= "" then
    if tooltip:find("interrupt", 1, true) or tooltip:find("preventing any spell in that school", 1, true) then return true end
    if tooltip:find("silence", 1, true) or tooltip:find("stun", 1, true) then return false end
  end
  return true
end

local function UtilityCategory(record)
  if type(record) ~= "table" then return nil end
  if record.combatRes == true then return "combatres" end
  if record.dispel == true or Normalize(record.category) == "dispel" then return "dispel" end
  if record.external == true then return "external" end
  if record.immunity == true then return "immunity" end
  if Normalize(record.category) == "taunt" then return "taunt" end
  if record.partyCooldown == true and Normalize(record.cooldownCategory) == "defensive" then return "defensive" end
  return nil
end

local function CapabilityFromRecord(record, className, learnedOnly)
  if type(record) ~= "table" then return nil end
  if learnedOnly then
    if RUI.ShouldShowSpellRecord and not RUI:ShouldShowSpellRecord(record) then return nil end
    if RUI.IsSpellRecordCastable and not RUI:IsSpellRecordCastable(record) then return nil end
  end
  local kind, category
  if IsArcaneTorrentRecord(record) then kind, category = "torrent", "interrupt"
  elseif IsDirectInterruptRecord(record) then kind, category = "direct", "interrupt"
  else
    category = UtilityCategory(record)
    if category then kind = "utility" end
  end
  if not kind then return nil end
  local spellID = RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(record) or tonumber(record.id)
  spellID = tonumber(spellID or record.id)
  if not spellID or spellID <= 0 then return nil end
  local texture = RUI.GetSpellRecordTexture and RUI:GetSpellRecordTexture(record) or SpellTexture(spellID)
  if not HasRealTexture(texture) then texture = SpellTexture(spellID) end
  return {
    id = spellID,
    name = tostring(record.name or (GetSpellInfo and GetSpellInfo(spellID)) or spellID),
    kind = kind,
    category = category,
    texture = texture,
    cooldownHint = math.max(0, tonumber(record.cooldownHint) or 0),
    order = tonumber(record.order) or 9999,
    primaryInterrupt = record.primaryInterrupt == true,
    className = className,
    definition = record,
  }
end

local function ArcaneTorrentCapability(spellID)
  spellID = tonumber(spellID) or ARCANE_TORRENT_DEFAULT_ID
  return {
    id = spellID,
    name = "Arcane Torrent",
    kind = "torrent",
    category = "interrupt",
    texture = SpellTexture(spellID, ARCANE_TORRENT_TEXTURE),
    cooldownHint = 120,
    order = 999,
    racial = true,
  }
end

local function BuildGlobalIndex()
  globalByID, globalByName, inferredDirectByClass = {}, {}, {}
  for className, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      local capability = CapabilityFromRecord(record, className, false)
      if capability then
        globalByID[capability.id] = capability
        globalByName[Normalize(capability.name)] = capability
        for _, alias in ipairs(record.aliases or {}) do globalByName[Normalize(alias)] = capability end
        if capability.kind == "direct" then
          inferredDirectByClass[className] = inferredDirectByClass[className] or {}
          inferredDirectByClass[className][#inferredDirectByClass[className] + 1] = capability
        end
      end
    end
  end
  for _, spellID in ipairs(ARCANE_TORRENT_IDS) do globalByID[spellID] = ArcaneTorrentCapability(spellID) end
  globalByName["arcane torrent"] = ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID)
end

local function BuildLocalCapabilities()
  localCapabilities = {}
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass()
  if className then
    local seen = {}
    for _, record in ipairs(RUI:GetClassSpellRecords(className) or {}) do
      local capability = CapabilityFromRecord(record, className, true)
      if capability and not seen[capability.id] then
        seen[capability.id] = true
        localCapabilities[#localCapabilities + 1] = capability
      end
    end
  end
  if IsBloodElfUnit("player") then
    local found
    for _, spellID in ipairs(ARCANE_TORRENT_IDS) do
      if RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(spellID) then found = spellID break end
      local name = GetSpellInfo and GetSpellInfo(spellID)
      if name and RUI.IsSpellLearned and RUI:IsSpellLearned(name) then found = spellID break end
    end
    localCapabilities[#localCapabilities + 1] = ArcaneTorrentCapability(found or ARCANE_TORRENT_DEFAULT_ID)
  end
  table.sort(localCapabilities, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    if a.order ~= b.order then return a.order < b.order end
    return tostring(a.name) < tostring(b.name)
  end)
  return localCapabilities
end

local function SelectPrimaryInterrupt(capabilities)
  local candidates = {}
  for _, capability in ipairs(capabilities or {}) do
    if capability.kind == "direct" then candidates[#candidates + 1] = capability end
  end
  table.sort(candidates, function(a, b)
    if a.primaryInterrupt ~= b.primaryInterrupt then return a.primaryInterrupt == true end
    local acd = a.cooldownHint > 0 and a.cooldownHint or 9999
    local bcd = b.cooldownHint > 0 and b.cooldownHint or 9999
    if acd ~= bcd then return acd < bcd end
    if a.order ~= b.order then return a.order < b.order end
    return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
  end)
  return candidates[1]
end

local function FindTorrent(capabilities)
  for _, capability in ipairs(capabilities or {}) do if capability.kind == "torrent" then return capability end end
  return nil
end

local function GetLocalCooldown(capability)
  if not capability then return 0, 0 end
  if W and W.ReadSpellCooldown and capability.definition then
    local start, duration, enabled = W:ReadSpellCooldown(capability.definition)
    start, duration, enabled = tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    local remaining = start > 0 and duration > 1.5 and math.max(0, start + duration - Now()) or 0
    return remaining, duration, enabled
  end
  if GetSpellCooldown then
    local start, duration, enabled = GetSpellCooldown(capability.id)
    start, duration, enabled = tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    return start > 0 and duration > 1.5 and math.max(0, start + duration - Now()) or 0, duration, enabled
  end
  return 0, 0, 0
end

local function Send(message, target)
  local channel = target and "WHISPER" or (IsInPartySafe() and "PARTY" or nil)
  if not channel then return false end
  if C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function" then
    return pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel, target)
  end
  if type(SendAddonMessage) == "function" then
    return pcall(SendAddonMessage, PREFIX, message, channel, target)
  end
  return false
end

local function SendCapabilities(target)
  BuildLocalCapabilities()
  Send("H|" .. Escape(RUI.version) .. "|" .. Escape(RUI.GetDetectedClass and RUI:GetDetectedClass() or "Unknown"), target)
  for _, capability in ipairs(localCapabilities) do
    Send(table.concat({"L", capability.kind, capability.category or "", capability.id, capability.cooldownHint, Escape(capability.name)}, "|"), target)
  end
  Send("E|1", target)
end

local function Peer(sender)
  sender = tostring(sender or "Unknown")
  peers[sender] = peers[sender] or {capabilities={}, exact=false, lastSeen=0}
  peers[sender].lastSeen = Now()
  return peers[sender]
end

local function FindPeer(member)
  if not member then return nil end
  for name, peer in pairs(peers) do
    if Normalize(name) == Normalize(member.name) or Normalize(ShortName(name)) == Normalize(member.short) then return peer end
  end
  return nil
end

local function ParseCapability(sender, kind, category, spellID, cooldownHint, name)
  spellID = tonumber(spellID)
  if not spellID then return end
  local peer = Peer(sender)
  local known = globalByID[spellID] or globalByName[Normalize(name)]
  peer.capabilities[spellID] = {
    id = spellID,
    name = known and known.name or name,
    kind = kind,
    category = category,
    texture = known and known.texture or SpellTexture(spellID),
    cooldownHint = tonumber(cooldownHint) or (known and known.cooldownHint) or 0,
    order = known and known.order or 9999,
    primaryInterrupt = known and known.primaryInterrupt or false,
    definition = known and known.definition or nil,
  }
end

local function ParseCooldown(sender, spellID, remaining, duration)
  spellID, remaining, duration = tonumber(spellID), tonumber(remaining) or 0, tonumber(duration) or 0
  if not spellID then return end
  local peer = Peer(sender)
  local capability = peer.capabilities[spellID]
  if not capability then
    local known = globalByID[spellID]
    if not known then return end
    capability = {
      id=known.id, name=known.name, kind=known.kind, category=known.category,
      texture=known.texture, cooldownHint=known.cooldownHint, order=known.order,
      primaryInterrupt=known.primaryInterrupt, definition=known.definition,
    }
    peer.capabilities[spellID] = capability
  end
  capability.duration = duration
  capability.expires = remaining > 0.05 and (Now() + remaining) or nil
end

local function HandleAddonMessage(prefix, message, channel, sender)
  if prefix ~= PREFIX or not sender or Normalize(sender) == Normalize(PlayerFullName()) then return end
  local parts = {}
  for value in tostring(message or ""):gmatch("([^|]+)") do parts[#parts + 1] = value end
  local kind = parts[1]
  if kind == "Q" then SendCapabilities(sender); return end
  if kind == "H" then
    local peer = Peer(sender)
    peer.version, peer.className = parts[2], parts[3]
    peer.capabilities = {}
    peer.exact = false
    return
  end
  if kind == "L" then ParseCapability(sender, parts[2], parts[3], parts[4], parts[5], parts[6]); return end
  if kind == "E" then Peer(sender).exact = true; return end
  if kind == "C" then ParseCooldown(sender, parts[2], parts[3], parts[4]); return end
end

local function CapabilityCopy(capability)
  local copy = {}
  for key, value in pairs(capability or {}) do copy[key] = value end
  return copy
end

local function MemberCapabilities(member)
  if not member then return {} end
  if member.unit == "player" then return localCapabilities end
  local result, seen = {}, {}
  local peer = FindPeer(member)
  if peer then
    for _, capability in pairs(peer.capabilities or {}) do
      local copy = CapabilityCopy(capability)
      result[#result + 1] = copy
      seen[copy.id] = true
    end
  end
  local observed = member.guid and observedByGUID[member.guid] or nil
  for _, capability in pairs(observed or {}) do
    if not seen[capability.id] then result[#result + 1] = CapabilityCopy(capability); seen[capability.id] = true end
  end
  if not SelectPrimaryInterrupt(result) then
    for _, capability in ipairs(inferredDirectByClass[member.className] or {}) do
      if not seen[capability.id] then result[#result + 1] = CapabilityCopy(capability); seen[capability.id] = true end
    end
  end
  if member.bloodElf and not FindTorrent(result) then result[#result + 1] = ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID) end
  return result
end

local function RemoteState(member, capability)
  local guid = member and member.guid
  local state = guid and remoteCooldowns[guid] and remoteCooldowns[guid][capability.id]
  if state then return math.max(0, (state.expires or 0) - Now()), state.duration or capability.cooldownHint or 0 end
  local peer = FindPeer(member)
  local peerCapability = peer and peer.capabilities and peer.capabilities[capability.id]
  if peerCapability and peerCapability.expires then
    return math.max(0, peerCapability.expires - Now()), peerCapability.duration or peerCapability.cooldownHint or 0
  end
  return 0, capability.cooldownHint or 0
end

local function CapabilityRemaining(member, capability)
  if member and member.unit == "player" then return GetLocalCooldown(capability) end
  return RemoteState(member, capability)
end

local function RecordRemoteUse(member, capability, duration, forceDirect)
  if not member or not member.guid or not capability then return end
  duration = tonumber(duration) or tonumber(capability.cooldownHint) or 0
  if duration <= 1.5 and (capability.kind == "direct" or forceDirect) then duration = 15 end
  observedByGUID[member.guid] = observedByGUID[member.guid] or {}
  local observed = CapabilityCopy(capability)
  if forceDirect then observed.kind, observed.category = "direct", "interrupt" end
  observedByGUID[member.guid][observed.id] = observed
  if duration > 1.5 then
    remoteCooldowns[member.guid] = remoteCooldowns[member.guid] or {}
    remoteCooldowns[member.guid][observed.id] = {expires=Now()+duration, duration=duration}
  end
end

local function ExtractSpellID(values)
  for index = 9, #values do
    local candidate = tonumber(values[index])
    if candidate and globalByID[candidate] then return candidate end
  end
  local modern = tonumber(values[12])
  local legacy = tonumber(values[9])
  if modern and modern > 0 then return modern end
  if legacy and legacy > 0 then return legacy end
  return nil
end

local function HandleCombatLog(...)
  local values
  if CombatLogGetCurrentEventInfo then values = {CombatLogGetCurrentEventInfo()} else values = {...} end
  local eventType = values[2]
  if eventType ~= "SPELL_CAST_SUCCESS" and eventType ~= "SPELL_INTERRUPT" then return end
  local sourceGUID, sourceName
  if type(values[3]) == "boolean" then sourceGUID, sourceName = values[4], values[5]
  else sourceGUID, sourceName = values[3], values[4] end
  local _, byName, byGUID = GroupMembers()
  local member = sourceGUID and byGUID[sourceGUID] or nil
  member = member or (sourceName and (byName[Normalize(sourceName)] or byName[Normalize(ShortName(sourceName))]))
  if not member or member.unit == "player" then return end
  local spellID = ExtractSpellID(values)
  if not spellID then return end
  local capability = globalByID[spellID]
  if not capability and eventType == "SPELL_INTERRUPT" then
    local name = GetSpellInfo and GetSpellInfo(spellID) or tostring(spellID)
    capability = {
      id=spellID, name=name, kind="direct", category="interrupt",
      texture=SpellTexture(spellID), cooldownHint=15, order=9999,
    }
    globalByID[spellID] = capability
  end
  if not capability then return end
  RecordRemoteUse(member, capability, capability.cooldownHint, eventType == "SPELL_INTERRUPT")
end

local function HandleUnitSpellcast(unit, ...)
  if type(unit) ~= "string" or not unit:match("^party[1-4]$") then return end
  local values = {...}
  local spellID
  for index = #values, 1, -1 do
    local candidate = tonumber(values[index])
    if candidate and candidate > 0 then spellID = candidate break end
  end
  local spellName
  for _, value in ipairs(values) do if type(value) == "string" and not value:find("^Cast%-") then spellName = value end end
  local capability = (spellID and globalByID[spellID]) or globalByName[Normalize(spellName)]
  if not capability then return end
  local byUnit = GroupMembers()
  local member = byUnit[unit]
  if member then RecordRemoteUse(member, capability, capability.cooldownHint, false) end
end

local function ReadFrameUnit(frame)
  if not frame then return nil end
  local unit = rawget(frame, "unit") or rawget(frame, "displayedUnit") or rawget(frame, "unitToken")
  if not unit and type(frame.GetAttribute) == "function" then
    local ok, value = pcall(frame.GetAttribute, frame, "unit")
    if ok then unit = value end
  end
  unit = tostring(unit or "")
  if unit == "player" or unit:match("^party[1-4]$") then return unit end
  return nil
end

local function ConsiderFrame(map, frame, forcedUnit)
  if not frame then return end
  local unit = forcedUnit or ReadFrameUnit(frame)
  if unit and not map[unit] then map[unit] = frame end
end

local function CollectChildren(map, frame, depth, seen)
  if not frame or depth < 0 or seen[frame] then return end
  seen[frame] = true
  ConsiderFrame(map, frame)
  if depth == 0 or type(frame.GetChildren) ~= "function" then return end
  for _, child in ipairs({frame:GetChildren()}) do CollectChildren(map, child, depth-1, seen) end
end

local function ResolveUnitFrames()
  local map, seen = {}, {}
  for _, root in ipairs({_G.ElvUF_Party, _G.ElvUF_PartyGroup1, _G.CompactPartyFrame, _G.PartyFrame}) do
    CollectChildren(map, root, 3, seen)
  end
  for index=1,5 do
    ConsiderFrame(map, _G["ElvUF_PartyGroup1UnitButton"..index])
    ConsiderFrame(map, _G["ElvUF_PartyUnitButton"..index])
    ConsiderFrame(map, _G["CompactPartyFrameMember"..index])
  end
  for index=1,4 do ConsiderFrame(map, _G["PartyMemberFrame"..index], "party"..index) end
  ConsiderFrame(map, _G.ElvUF_Player, "player")
  ConsiderFrame(map, _G.PlayerFrame, "player")
  unitFrames = map
  return map
end

local function CreateUtilityFrame(unit)
  if utilityFrames[unit] then return utilityFrames[unit] end
  local frame = CreateFrame("Frame", "RetreatUIPartyUtilityV4_" .. unit, UIParent)
  frame:SetSize(1, UTILITY_ICON_SIZE)
  frame:SetFrameStrata("MEDIUM")
  frame.icons = {}
  frame:Hide()
  utilityFrames[unit] = frame
  return frame
end

local function AnchorUtilityFrame(unit)
  local frame = CreateUtilityFrame(unit)
  local target = unitFrames[unit]
  frame.target = target
  frame:ClearAllPoints()
  if not target then frame:Hide(); return false end
  frame:SetPoint("RIGHT", target, "LEFT", -4, 0)
  return true
end

local function CreateTrackedIcon(parent, size)
  local icon = W:CreateIcon(parent, size)
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", function(self)
    local capability = self.capability
    if not capability or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local shown = false
    if capability.id and GameTooltip.SetSpellByID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, capability.id) end
    if not shown then GameTooltip:SetText(tostring(capability.name or "Ability"), 1,1,1) end
    if self.ownerName then GameTooltip:AddLine("Player: " .. tostring(self.ownerName), .72,.82,1,true) end
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return icon
end

local function UtilityEntries(member)
  local utilitySettings = EnsureSettings()
  local entries = {}
  if member.unit == "player" then
    if not utilitySettings.showSelf then return entries end
    for _, capability in ipairs(localCapabilities) do
      if capability.kind == "utility" then
        local remaining, duration = CapabilityRemaining(member, capability)
        if utilitySettings.showReady or remaining > 0.05 then
          entries[#entries+1] = {capability=capability, remaining=remaining, duration=duration}
        end
      end
    end
  else
    for _, capability in ipairs(MemberCapabilities(member)) do
      if capability.kind == "utility" then
        local remaining, duration = CapabilityRemaining(member, capability)
        local peer = FindPeer(member)
        local exact = peer and peer.exact
        local observed = member.guid and observedByGUID[member.guid] and observedByGUID[member.guid][capability.id]
        if remaining > 0.05 or (utilitySettings.showReady and (exact or observed)) then
          entries[#entries+1] = {capability=capability, remaining=remaining, duration=duration}
        end
      end
    end
  end
  table.sort(entries, function(a,b)
    if (a.remaining > .05) ~= (b.remaining > .05) then return a.remaining > .05 end
    return tostring(a.capability.name) < tostring(b.capability.name)
  end)
  while #entries > MAX_UTILITY_ICONS do table.remove(entries) end
  return entries
end

local function RenderUtility()
  local utilitySettings = EnsureSettings()
  if not utilitySettings.enabled or IsInRaidSafe() or (not IsInPartySafe() and not utilitySettings.showSolo and not previewMode) then
    for _, frame in pairs(utilityFrames) do frame:Hide() end
    return
  end
  if not next(unitFrames) then ResolveUnitFrames() end
  local byUnit = GroupMembers()
  for _, unit in ipairs(UNIT_ORDER) do
    local member = byUnit[unit]
    local frame = CreateUtilityFrame(unit)
    local entries = member and UtilityEntries(member) or {}
    if previewMode and member then
      entries = {{capability={id=0,name="Group Defensive",category="defensive",texture="Interface\\Icons\\Spell_Holy_DevotionAura"},remaining=unit=="party1" and 22 or 0,duration=60}}
    end
    if not member or not unitFrames[unit] or #entries == 0 then frame:Hide()
    else
      AnchorUtilityFrame(unit)
      local total = #entries * UTILITY_ICON_SIZE + math.max(0,#entries-1)*UTILITY_SPACING
      frame:SetSize(total, UTILITY_ICON_SIZE)
      for index, item in ipairs(entries) do
        local icon = frame.icons[index] or CreateTrackedIcon(frame, UTILITY_ICON_SIZE)
        frame.icons[index] = icon
        icon.capability = item.capability
        icon.ownerName = member.short
        icon.texture:SetTexture(item.capability.texture)
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", frame, "RIGHT", -((index-1)*(UTILITY_ICON_SIZE+UTILITY_SPACING)), 0)
        W:SetBorder(icon, CATEGORY_COLORS[item.capability.category] or {1,1,1}, 1)
        W:SetIconInactive(icon, item.remaining > .05)
        W:SetCooldownDisplay(icon, item.remaining, item.remaining > .05)
        icon:Show()
      end
      for index=#entries+1,#frame.icons do frame.icons[index]:Hide() end
      frame:Show()
    end
  end
end

local function ClassColor(unit, previewIndex)
  if previewIndex then
    local colors={{.82,.38,.08},{.18,.56,.72},{.42,.22,.66},{.16,.62,.30},{.58,.30,.18}}
    return unpack(colors[previewIndex] or colors[1])
  end
  if UnitClass then
    local _, token = UnitClass(unit)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and token and colors[token]
    if color then return color.r or .25, color.g or .45, color.b or .62 end
  end
  return .20,.42,.55
end

local function CreateInterruptFrame()
  if interruptFrame then return interruptFrame end
  local frame = CreateFrame("Frame", "RetreatUIPartyInterruptTracker", UIParent)
  frame:SetSize(INTERRUPT_WIDTH, HEADER_HEIGHT+2)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame.rows = {}
  RUI:SkinFrame(frame, {.015,.02,.028,.96}, {.18,.22,.28,1})
  frame.header = CreateFrame("Frame", nil, frame)
  frame.header:SetPoint("TOPLEFT",1,-1)
  frame.header:SetPoint("TOPRIGHT",-1,-1)
  frame.header:SetHeight(HEADER_HEIGHT)
  RUI:SkinFrame(frame.header, {.015,.04,.065,.98}, {.015,.04,.065,0})
  frame.header.text = frame.header:CreateFontString(nil,"OVERLAY")
  frame.header.text:SetPoint("CENTER")
  RUI:ApplyFont(frame.header.text,11,"OUTLINE")
  frame.header.text:SetTextColor(.05,.95,1,1)
  frame.header.text:SetText("INTERRUPTS")
  frame:Hide()
  interruptFrame = frame
  return frame
end

local function InterruptRow(index)
  local tracker = CreateInterruptFrame()
  if tracker.rows[index] then return tracker.rows[index] end
  local row = CreateFrame("Frame", nil, tracker)
  row:SetHeight(ROW_HEIGHT)
  RUI:SkinFrame(row, {.12,.20,.26,.94}, {.02,.02,.03,1})
  row.nameText = row:CreateFontString(nil,"OVERLAY")
  row.nameText:SetPoint("LEFT",7,0)
  row.nameText:SetWidth(104)
  row.nameText:SetJustifyH("LEFT")
  RUI:ApplyFont(row.nameText,10,"OUTLINE")
  row.statusText = row:CreateFontString(nil,"OVERLAY")
  row.statusText:SetPoint("RIGHT",-51,0)
  row.statusText:SetWidth(44)
  row.statusText:SetJustifyH("RIGHT")
  RUI:ApplyFont(row.statusText,9,"OUTLINE")
  row.icons = {}
  for slot=1,2 do
    local icon = CreateTrackedIcon(row, ICON_SIZE)
    icon:SetPoint("RIGHT", row, "RIGHT", -4-((slot-1)*(ICON_SIZE+3)), 0)
    row.icons[slot] = icon
  end
  tracker.rows[index] = row
  return row
end

local function PartyAnchor()
  if not next(unitFrames) then ResolveUnitFrames() end
  for _, frame in ipairs({_G.ElvUF_Party, _G.ElvUF_PartyGroup1, _G.CompactPartyFrame, _G.PartyFrame}) do
    if frame and frame.GetWidth and frame:GetWidth() and frame:GetWidth() > 1 then return frame end
  end
  return unitFrames.party1
end

function RUI:ApplyPartyInterruptLayout()
  local frame = CreateInterruptFrame()
  local layout = self.layout and self.layout.partyInterrupts or {}
  local scale = self.GetHUDScale and self:GetHUDScale("partyInterrupts") or tonumber(layout.scale) or 1
  frame:SetScale(scale)
  frame:ClearAllPoints()
  if layout.autoAnchor == false then
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(layout.x) or 0, tonumber(layout.y) or -278)
  else
    local anchor = PartyAnchor()
    if anchor then frame:SetPoint("TOP", anchor, "BOTTOM", 0, -5)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 0, -278) end
  end
  return true
end

local function InterruptEntries(member)
  local capabilities = MemberCapabilities(member)
  local entries = {}
  local primary = SelectPrimaryInterrupt(capabilities)
  local torrent = member.bloodElf and (FindTorrent(capabilities) or ArcaneTorrentCapability()) or nil
  if primary then entries[#entries+1] = primary end
  if torrent and (not primary or torrent.id ~= primary.id) then entries[#entries+1] = torrent end
  return entries
end

local function PreviewMember(unit, index)
  return {unit=unit,name=({"YOU","TANK","HEALER","DPS","DPS"})[index],short=({"YOU","TANK","HEALER","DPS","DPS"})[index],bloodElf=index==3,guid="preview"..index}
end

local function RenderInterrupts()
  local _, interruptSettings = EnsureSettings()
  local frame = CreateInterruptFrame()
  local showingPreview = previewMode or interruptEditorPreview
  if not interruptSettings.enabled or IsInRaidSafe() or (not IsInPartySafe() and not interruptSettings.showSolo and not showingPreview) then frame:Hide(); return end
  local byUnit = GroupMembers()
  local rows = {}
  for index, unit in ipairs(UNIT_ORDER) do
    local member = showingPreview and PreviewMember(unit,index) or byUnit[unit]
    if member and (unit ~= "player" or interruptSettings.showSelf) then
      local entries
      if showingPreview then
        entries = {{id=1766,name="Kick",kind="direct",category="interrupt",texture=SpellTexture(1766,"Interface\\Icons\\Ability_Kick"),cooldownHint=10}}
        if member.bloodElf then entries[#entries+1] = ArcaneTorrentCapability() end
      else entries = InterruptEntries(member) end
      rows[#rows+1] = {member=member, entries=entries, index=index}
    end
  end
  if #rows == 0 then frame:Hide(); return end
  local height = HEADER_HEIGHT + 2 + #rows*ROW_HEIGHT + math.max(0,#rows-1)*ROW_GAP
  local layout = RUI.layout and RUI.layout.partyInterrupts or {}
  frame:SetWidth(tonumber(layout.width) or INTERRUPT_WIDTH)
  frame:SetHeight(height)
  for rowIndex, item in ipairs(rows) do
    local row = InterruptRow(rowIndex)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -((rowIndex-1)*(ROW_HEIGHT+ROW_GAP)))
    row:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", 0, -((rowIndex-1)*(ROW_HEIGHT+ROW_GAP)))
    local r,g,b = ClassColor(item.member.unit, showingPreview and rowIndex or nil)
    if row.SetBackdropColor then row:SetBackdropColor(r*.72,g*.72,b*.72,.96) end
    row.nameText:SetText(item.member.short or item.member.name or item.member.unit)
    local shortest, allReady = nil, true
    for slot=1,2 do
      local icon = row.icons[slot]
      local capability = item.entries[slot]
      if capability then
        local remaining
        if showingPreview then
          remaining = (rowIndex==2 and slot==1) and 7.5 or ((rowIndex==3 and slot==2) and 42 or 0)
        else remaining = CapabilityRemaining(item.member, capability) end
        icon.capability = capability
        icon.ownerName = item.member.short
        icon.texture:SetTexture(capability.texture or SpellTexture(capability.id))
        W:SetBorder(icon, capability.kind=="torrent" and CATEGORY_COLORS.torrent or CATEGORY_COLORS.interrupt, 1)
        W:SetIconInactive(icon, remaining > .05)
        W:SetCooldownDisplay(icon, remaining, remaining > .05)
        icon:Show()
        if remaining > .05 then allReady=false; shortest = not shortest and remaining or math.min(shortest,remaining) end
      else icon:Hide() end
    end
    if #item.entries == 0 then
      row.statusText:SetText("—")
      row.statusText:SetTextColor(.62,.62,.68,1)
    elseif allReady then
      row.statusText:SetText("READY")
      row.statusText:SetTextColor(.18,1,.18,1)
    else
      row.statusText:SetText(W:FormatCooldown(shortest or 0))
      row.statusText:SetTextColor(1,.70,.12,1)
    end
    row:Show()
  end
  for index=#rows+1,#frame.rows do frame.rows[index]:Hide() end
  RUI:ApplyPartyInterruptLayout()
  frame:Show()
end

local function RenderAll()
  if not next(unitFrames) then ResolveUnitFrames() end
  RenderUtility()
  RenderInterrupts()
end

local function PollLocalCooldowns()
  if not IsInPartySafe() and not previewMode then return end
  for _, capability in ipairs(localCapabilities) do
    local remaining, duration = GetLocalCooldown(capability)
    local rounded = math.floor((remaining or 0)*10+.5)/10
    local previous = localCooldownState[capability.id]
    local active = rounded > .05
    if not previous or previous.active ~= active then
      localCooldownState[capability.id] = {active=active,remaining=rounded,duration=duration}
      Send("C|"..capability.id.."|"..string.format("%.1f",rounded).."|"..string.format("%.1f",duration or 0))
    end
  end
end

local function PurgeState()
  local _, byName, byGUID = GroupMembers()
  for name in pairs(peers) do
    if not byName[Normalize(name)] and not byName[Normalize(ShortName(name))] then peers[name]=nil end
  end
  for guid in pairs(remoteCooldowns) do if not byGUID[guid] then remoteCooldowns[guid]=nil end end
  for guid in pairs(observedByGUID) do if not byGUID[guid] then observedByGUID[guid]=nil end end
end

local function SmallButton(parent, label, width, callback)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width,24)
  RUI:SkinFrame(button,{.08,.08,.11,.98},{.30,.30,.38,1})
  button.text=button:CreateFontString(nil,"OVERLAY")
  button.text:SetPoint("CENTER")
  RUI:ApplyFont(button.text,9,"OUTLINE")
  button.text:SetText(label)
  button:SetScript("OnClick",callback)
  return button
end

function RUI:OpenPartyUtilitySettings()
  if not settingsFrame then
    local frame = CreateFrame("Frame", "RetreatUIPartyUtilitySettingsV4", UIParent)
    frame:SetSize(430,220)
    frame:SetPoint("CENTER",0,120)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    RUI:SkinFrame(frame,{.018,.018,.024,.98},{1,.35,.08,1})
    frame.title=frame:CreateFontString(nil,"OVERLAY"); frame.title:SetPoint("TOPLEFT",14,-13); RUI:ApplyFont(frame.title,14,"OUTLINE"); frame.title:SetText("RetreatUI Party Trackers")
    frame.body=frame:CreateFontString(nil,"OVERLAY"); frame.body:SetPoint("TOPLEFT",14,-44); frame.body:SetWidth(400); frame.body:SetJustifyH("LEFT"); RUI:ApplyFont(frame.body,9,"OUTLINE")
    frame.body:SetText("The interrupt tracker shows one row per player, one direct interrupt, and Arcane Torrent as an additional Blood Elf icon. Remote cooldowns use combat-log tracking and RetreatUI sync.")
    frame.utility=SmallButton(frame,"TOGGLE COOLDOWNS",150,function()
      local utility=EnsureSettings(); utility.enabled=not utility.enabled; RenderAll()
    end); frame.utility:SetPoint("TOPLEFT",14,-104)
    frame.interrupts=SmallButton(frame,"TOGGLE INTERRUPTS",150,function()
      local _,interrupts=EnsureSettings(); interrupts.enabled=not interrupts.enabled; RenderAll()
    end); frame.interrupts:SetPoint("LEFT",frame.utility,"RIGHT",8,0)
    frame.preview=SmallButton(frame,"TOGGLE PREVIEW",150,function() previewMode=not previewMode; RenderAll() end); frame.preview:SetPoint("TOPLEFT",14,-138)
    frame.resync=SmallButton(frame,"RESYNC GROUP",150,function() Send("Q|1"); SendCapabilities(); RenderAll() end); frame.resync:SetPoint("LEFT",frame.preview,"RIGHT",8,0)
    frame.close=SmallButton(frame,"CLOSE",90,function() frame:Hide() end); frame.close:SetPoint("BOTTOMRIGHT",-14,14)
    frame:Hide(); settingsFrame=frame
  end
  settingsFrame:Show()
  return true
end

function RUI:TogglePartyUtilityPreview(force)
  if force == nil then previewMode=not previewMode else previewMode=force==true end
  RenderAll()
  return previewMode
end

function RUI:SetPartyInterruptEditorPreview(enabled)
  interruptEditorPreview=enabled==true
  RenderInterrupts()
  return interruptEditorPreview
end

function RUI:GetPartyInterruptTrackerStatus()
  local shown=interruptFrame and interruptFrame:IsShown() or false
  local count=0
  if interruptFrame then for _,row in ipairs(interruptFrame.rows or {}) do if row:IsShown() then count=count+1 end end end
  return shown,count,interruptEditorPreview
end

function RUI:GetPartyUtilityStatus()
  local peerCount,attached=0,0
  for _ in pairs(peers) do peerCount=peerCount+1 end
  for _,unit in ipairs(UNIT_ORDER) do if unitFrames[unit] then attached=attached+1 end end
  return initialized,#localCapabilities,peerCount,previewMode,attached
end

function RUI:RefreshPartyUtility()
  BuildGlobalIndex(); BuildLocalCapabilities(); RenderAll(); return true
end

function RUI:InitializePartyUtilityTracker()
  if initialized then self:RefreshPartyUtility(); return true end
  initialized=true
  EnsureSettings()
  BuildGlobalIndex()
  BuildLocalCapabilities()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
  elseif RegisterAddonMessagePrefix then pcall(RegisterAddonMessagePrefix,PREFIX) end
  driver=CreateFrame("Frame","RetreatUIPartyUtilityDriverV4")
  for _,event in ipairs({
    "PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE",
    "SPELLS_CHANGED","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED","ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
    "CHAT_MSG_ADDON","UNIT_SPELLCAST_SUCCEEDED","COMBAT_LOG_EVENT_UNFILTERED","UI_SCALE_CHANGED",
  }) do pcall(driver.RegisterEvent,driver,event) end
  driver:SetScript("OnEvent",function(_,event,...)
    if event=="CHAT_MSG_ADDON" then HandleAddonMessage(...); RenderAll(); return end
    if event=="COMBAT_LOG_EVENT_UNFILTERED" then HandleCombatLog(...); RenderAll(); return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then HandleUnitSpellcast(...); RenderAll(); return end
    if event=="GROUP_ROSTER_UPDATE" or event=="PARTY_MEMBERS_CHANGED" or event=="RAID_ROSTER_UPDATE" then
      unitFrames = {}; PurgeState(); RenderAll(); RUI:After(BROADCAST_DELAY,function() Send("Q|1"); SendCapabilities(); RenderAll() end); return
    end
    if event=="SPELLS_CHANGED" or event=="PLAYER_TALENT_UPDATE" or event=="ACTIVE_TALENT_GROUP_CHANGED" or event=="ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
      RUI:After(.15,function() BuildGlobalIndex(); BuildLocalCapabilities(); SendCapabilities(); RenderAll() end); return
    end
    RenderAll(); RUI:After(BROADCAST_DELAY,function() Send("Q|1"); SendCapabilities(); RenderAll() end)
  end)
  driver:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=UPDATE_INTERVAL then elapsed=0; PollLocalCooldowns(); RenderAll() end
  end)
  for _,delay in ipairs({.10,.80,2.00}) do RUI:After(delay,function() RenderAll() end) end
  RUI:After(BROADCAST_DELAY,function() Send("Q|1"); SendCapabilities(); RenderAll() end)
  return true
end

RUI._partyUtilityV4Loaded = true
