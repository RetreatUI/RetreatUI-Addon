local RUI = RetreatUI
if not RUI then return end

local W = RUI.HUDWidgets
local PREFIX = "RUIUTIL3"
local UPDATE_INTERVAL = 0.25
local BROADCAST_DELAY = 0.80
local ICON_SIZE = 24
local ICON_SPACING = 2
local MAX_PER_UNIT = 10

local INTERRUPT_TRACKER_WIDTH = 270
local INTERRUPT_HEADER_HEIGHT = 28
local INTERRUPT_ROW_HEIGHT = 34
local INTERRUPT_ROW_GAP = 1
local INTERRUPT_TRACKER_PADDING = 2
local INTERRUPT_PARTY_GAP = 8
local ARCANE_TORRENT_DEFAULT_ID = 50613
local ARCANE_TORRENT_IDS = {50613, 28730, 25046, 80483, 69179, 129597}
local ARCANE_TORRENT_TEXTURE = "Interface\\Icons\\Spell_Shadow_Teleport"

local UNIT_ORDER = {"player", "party1", "party2", "party3", "party4"}

local CATEGORY_ORDER = {
  interrupt = 10,
  combatres = 20,
  dispel = 30,
  external = 40,
  defensive = 50,
  immunity = 60,
  taunt = 70,
}

local CATEGORY_LABELS = {
  interrupt = "INTERRUPT",
  combatres = "COMBAT RES",
  dispel = "DISPEL",
  external = "EXTERNAL",
  defensive = "GROUP DEFENSIVE",
  immunity = "IMMUNITY",
  taunt = "TAUNT",
}

local CATEGORY_COLORS = {
  interrupt = {1.00, 0.82, 0.12},
  combatres = {0.34, 0.95, 0.38},
  dispel = {0.20, 0.72, 1.00},
  external = {0.92, 0.50, 1.00},
  defensive = {1.00, 0.42, 0.12},
  immunity = {0.95, 0.95, 0.95},
  taunt = {1.00, 0.18, 0.18},
}

local PREVIEW_TEXTURES = {
  interrupt = "Interface\\Icons\\Spell_Frost_IceShock",
  combatres = "Interface\\Icons\\Spell_Holy_Resurrection",
  dispel = "Interface\\Icons\\Spell_Holy_DispelMagic",
  external = "Interface\\Icons\\Spell_Holy_PowerWordShield",
  defensive = "Interface\\Icons\\Spell_Holy_DevotionAura",
  immunity = "Interface\\Icons\\Spell_Holy_DivineIntervention",
  taunt = "Interface\\Icons\\Ability_Warrior_Challange",
}

local localCapabilities = {}
local globalIndexByID = {}
local globalIndexByName = {}
local inferredCapabilitiesByClass = {}
local peers = {}
local localCooldownState = {}
local unitFrames = {}
local containers = {}
local driver
local settingsWindow
local interruptFrame
local previewMode = false
local interruptEditorPreview = false
local elapsed = 0
local anchorElapsed = 0
local rebuildPending = false
local initialized = false

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
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

local function ShortName(value)
  value = tostring(value or "Unknown")
  return value:match("^[^-]+") or value
end

local function Escape(value)
  value = tostring(value or "")
  return value:gsub("[|~,;]", " ")
end

local function GetSettings()
  local db = RUI:EnsureDB()
  db.partyUtility = db.partyUtility or {}
  local settings = db.partyUtility
  if settings.enabled == nil then settings.enabled = true end
  if settings.showReady == nil then settings.showReady = true end
  if settings.showSelf == nil then settings.showSelf = true end
  if settings.showSolo == nil then settings.showSolo = false end
  if settings.roleAware == nil then settings.roleAware = true end
  settings.categories = settings.categories or {}
  for category in pairs(CATEGORY_ORDER) do
    if settings.categories[category] == nil then settings.categories[category] = true end
  end
  -- Interrupts live in their own central tracker from beta.8 onward.
  settings.categories.interrupt = false
  return settings
end

local function GetInterruptSettings()
  local db = RUI:EnsureDB()
  db.partyInterrupts = db.partyInterrupts or {}
  local settings = db.partyInterrupts
  if settings.enabled == nil then settings.enabled = true end
  if settings.showSelf == nil then settings.showSelf = true end
  if settings.showSolo == nil then settings.showSolo = false end
  return settings
end

local function NameSuggests(name, patterns)
  name = Normalize(name)
  for _, pattern in ipairs(patterns) do
    if name:find(pattern, 1, true) then return true end
  end
  return false
end

local function ClassifyRecord(record)
  if type(record) ~= "table" then return nil end
  local explicit = Normalize(record.partyUtilityCategory or record.cooldownCategory)
  if CATEGORY_ORDER[explicit] then return explicit end

  local category = Normalize(record.category)
  if category == "interrupt" then return "interrupt" end
  if category == "taunt" then return "taunt" end
  local supportive = category == "utility" or category == "healing" or category == "ally" or category == "defensive"
  if record.combatRes == true or (supportive and NameSuggests(record.name, {"combat resurrection", "combat res", "rebirth", "reviv", "raise ally"})) then
    return "combatres"
  end
  if record.external == true or ((category == "ally" or category == "defensive") and NameSuggests(record.name, {"external", "guardian spirit", "pain suppression", "life cocoon"})) then
    return "external"
  end
  if record.immunity == true or (category == "defensive" and NameSuggests(record.name, {"immunity", "immune", "divine shield", "ice block"})) then
    return "immunity"
  end
  if record.dispel == true or (supportive and NameSuggests(record.name, {"dispel", "cleanse", "cleansing", "purge", "purify", "remove curse", "detox"})) then
    return "dispel"
  end
  if category == "defensive" and record.partyCooldown == true then return "defensive" end
  return nil
end

local function HasRealTexture(texture)
  if type(texture) ~= "string" or texture == "" then return false end
  return not Normalize(texture):find("questionmark", 1, true)
end

local function ArcaneTorrentTexture(spellID)
  if GetSpellInfo and spellID then
    local _, _, texture = GetSpellInfo(spellID)
    if HasRealTexture(texture) then return texture end
  end
  return ARCANE_TORRENT_TEXTURE
end

local function ArcaneTorrentCapability(spellID, definition, inferred)
  spellID = tonumber(spellID) or ARCANE_TORRENT_DEFAULT_ID
  definition = type(definition) == "table" and definition or {
    id = spellID,
    name = "Arcane Torrent",
    aliases = {"Arcane Torrent"},
    racial = true,
    raceKey = "BloodElf",
    trackCooldown = true,
  }
  return {
    id = spellID,
    name = "Arcane Torrent",
    category = "interrupt",
    texture = ArcaneTorrentTexture(spellID),
    cooldownHint = 120,
    className = "BloodElf",
    definition = definition,
    racial = true,
    inferred = inferred == true,
  }
end

local function PlayerArcaneTorrentCapability()
  if not IsBloodElfUnit("player") then return nil end
  if type(RUI.GetRacialSpellDefinitions) == "function" then
    local ok, racials = pcall(RUI.GetRacialSpellDefinitions, RUI, false)
    if ok then
      for _, racial in ipairs(racials or {}) do
        if Normalize(racial.name) == "arcane torrent" then
          return ArcaneTorrentCapability(racial.id or racial.spellID, racial, false)
        end
      end
    end
  end
  for _, spellID in ipairs(ARCANE_TORRENT_IDS) do
    if GetSpellInfo then
      local name = GetSpellInfo(spellID)
      if Normalize(name) == "arcane torrent" then
        return ArcaneTorrentCapability(spellID, {id=spellID, name="Arcane Torrent", aliases={"Arcane Torrent"}, racial=true}, false)
      end
    end
  end
  return ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID, nil, false)
end

local function CapabilityFromRecord(record, className, learnedOnly)
  local category = ClassifyRecord(record)
  if not category then return nil end
  if learnedOnly then
    local show = not RUI.ShouldShowSpellRecord or RUI:ShouldShowSpellRecord(record)
    local learned = RUI.IsSpellRecordCastable and RUI:IsSpellRecordCastable(record)
    if not show or not learned then return nil end
  end

  local spellID = RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(record) or tonumber(record.id)
  spellID = tonumber(spellID or record.id)
  if not spellID or spellID <= 0 then return nil end
  local texture = RUI.GetSpellRecordTexture and RUI:GetSpellRecordTexture(record)
  if not HasRealTexture(texture) then return nil end

  return {
    id = spellID,
    name = tostring(record.name or (GetSpellInfo and GetSpellInfo(spellID)) or spellID),
    category = category,
    texture = texture,
    cooldownHint = math.max(0, tonumber(record.cooldownHint) or 0),
    className = className,
    definition = record,
  }
end

local function BuildGlobalIndex()
  RUI:ClearTable(globalIndexByID)
  RUI:ClearTable(globalIndexByName)
  RUI:ClearTable(inferredCapabilitiesByClass)
  for className, database in pairs(RUI.spellDatabase or {}) do
    for _, record in ipairs(database.spells or {}) do
      local capability = CapabilityFromRecord(record, className, false)
      if capability then
        globalIndexByID[capability.id] = capability
        globalIndexByName[Normalize(capability.name)] = capability
        for _, alias in ipairs(record.aliases or {}) do globalIndexByName[Normalize(alias)] = capability end
      end
    end
  end

  local defaultTorrent
  for _, spellID in ipairs(ARCANE_TORRENT_IDS) do
    local capability = ArcaneTorrentCapability(spellID, nil, true)
    globalIndexByID[spellID] = capability
    if spellID == ARCANE_TORRENT_DEFAULT_ID then defaultTorrent = capability end
  end
  globalIndexByName["arcane torrent"] = defaultTorrent or ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID, nil, true)
end

local function BuildLocalCapabilities()
  localCapabilities = {}
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass()
  if not className then return localCapabilities end

  local seen = {}
  for _, record in ipairs(RUI:GetClassSpellRecords(className) or {}) do
    local capability = CapabilityFromRecord(record, className, true)
    if capability and not seen[capability.id] then
      seen[capability.id] = true
      localCapabilities[#localCapabilities + 1] = capability
    end
  end

  local racialInterrupt = PlayerArcaneTorrentCapability()
  if racialInterrupt and not seen[racialInterrupt.id] then
    seen[racialInterrupt.id] = true
    localCapabilities[#localCapabilities + 1] = racialInterrupt
  end

  table.sort(localCapabilities, function(left, right)
    local a, b = CATEGORY_ORDER[left.category] or 999, CATEGORY_ORDER[right.category] or 999
    if a ~= b then return a < b end
    return tostring(left.name) < tostring(right.name)
  end)
  return localCapabilities
end

local function PlayerFullName()
  if not UnitName then return "player" end
  local name, realm = UnitName("player")
  if realm and realm ~= "" then return tostring(name) .. "-" .. tostring(realm) end
  return tostring(name or "player")
end

local function IsInRaidSafe()
  return type(IsInRaid) == "function" and IsInRaid() == true
end

local function PartyCount()
  if type(GetNumPartyMembers) == "function" then return math.max(0, tonumber(GetNumPartyMembers()) or 0) end
  if type(GetNumSubgroupMembers) == "function" then return math.max(0, tonumber(GetNumSubgroupMembers()) or 0) end
  return 0
end

local function IsInPartySafe()
  if IsInRaidSafe() then return false end
  if type(IsInGroup) == "function" and IsInGroup() then return true end
  return PartyCount() > 0
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
  Send("H|" .. Escape(RUI.version) .. "|" .. Escape(RUI:GetDetectedClass() or "Unknown") .. "|" .. Escape(RUI.GetBuildFingerprint and RUI:GetBuildFingerprint() or "unknown"), target)
  if #localCapabilities == 0 then Send("L|1|1|", target); return end

  local chunkSize = 4
  local chunks = math.ceil(#localCapabilities / chunkSize)
  for chunk = 1, chunks do
    local values = {}
    local first = (chunk - 1) * chunkSize + 1
    local last = math.min(#localCapabilities, first + chunkSize - 1)
    for index = first, last do
      local entry = localCapabilities[index]
      values[#values + 1] = table.concat({entry.category, entry.id, entry.cooldownHint, Escape(entry.name)}, ",")
    end
    Send("L|" .. chunk .. "|" .. chunks .. "|" .. table.concat(values, "~"), target)
  end
end

local function UnitRole(unit)
  if type(UnitGroupRolesAssigned) == "function" then
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if ok and role and role ~= "NONE" then return role end
  end
  return "NONE"
end

local function UnitClassName(unit)
  if type(UnitClass) ~= "function" then return nil end
  local ok, localized, token = pcall(UnitClass, unit)
  if not ok then return nil end
  for _, value in ipairs({localized, token}) do
    local className = RUI.NormalizeClassName and RUI:NormalizeClassName(value) or value
    if className and RUI.spellDatabase and RUI.spellDatabase[className] then return className end
  end
  return nil
end

local function InferredCapabilities(className)
  if not className or not RUI.spellDatabase or not RUI.spellDatabase[className] then return {} end
  if inferredCapabilitiesByClass[className] then return inferredCapabilitiesByClass[className] end
  local capabilities, seen = {}, {}
  for _, record in ipairs(RUI:GetClassSpellRecords(className) or {}) do
    local capability = CapabilityFromRecord(record, className, false)
    if capability and not seen[capability.id] then
      seen[capability.id] = true
      capability.inferred = true
      capabilities[#capabilities + 1] = capability
    end
  end
  table.sort(capabilities, function(left, right)
    local a, b = CATEGORY_ORDER[left.category] or 999, CATEGORY_ORDER[right.category] or 999
    if a ~= b then return a < b end
    local leftOrder = tonumber(left.definition and left.definition.order) or 999
    local rightOrder = tonumber(right.definition and right.definition.order) or 999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    return tostring(left.name) < tostring(right.name)
  end)
  inferredCapabilitiesByClass[className] = capabilities
  return capabilities
end

local function GroupMembers()
  local byName, byUnit = {}, {}
  local function Add(unit)
    if not UnitExists or not UnitExists(unit) then return end
    local name, realm = UnitName(unit)
    if not name then return end
    local full = realm and realm ~= "" and (name .. "-" .. realm) or name
    local member = {name=full, short=ShortName(full), unit=unit, role=UnitRole(unit), guid=UnitGUID and UnitGUID(unit), className=UnitClassName(unit)}
    byUnit[unit] = member
    byName[Normalize(full)] = member
    byName[Normalize(name)] = member
  end
  Add("player")
  for index = 1, math.min(4, PartyCount()) do Add("party" .. index) end
  return byName, byUnit
end

local function GetLocalCooldown(capability)
  local start, duration, enabled = 0, 0, 0
  if W and type(W.ReadSpellCooldown) == "function" then
    start, duration, enabled = W:ReadSpellCooldown(capability.definition)
  end
  start, duration, enabled = tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
  local remaining = 0
  if start > 0 and duration > 1.5 then remaining = math.max(0, start + duration - GetTime()) end
  return remaining, duration, enabled
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

local function FrameScore(frame, unit)
  if not frame then return -1 end
  local name = type(frame.GetName) == "function" and tostring(frame:GetName() or "") or ""
  local score = 0
  if name:find("ElvUF_Party", 1, true) then score = score + 200 end
  if name:find("CompactParty", 1, true) then score = score + 120 end
  if name:find("PartyMemberFrame", 1, true) then score = score + 100 end
  if unit == "player" and name == "ElvUF_Player" then score = score + 70 end
  if unit == "player" and name == "PlayerFrame" then score = score + 30 end
  if type(frame.IsShown) == "function" and frame:IsShown() then score = score + 10 end
  if type(frame.GetWidth) == "function" and (tonumber(frame:GetWidth()) or 0) >= 60 then score = score + 5 end
  return score
end

local function ConsiderFrame(map, scores, frame, forcedUnit)
  if not frame then return end
  local unit = forcedUnit or ReadFrameUnit(frame)
  if not unit then return end
  local score = FrameScore(frame, unit)
  if score > (scores[unit] or -1) then
    map[unit], scores[unit] = frame, score
  end
end

local function CollectChildren(map, scores, frame, depth, seen)
  if not frame or depth < 0 or seen[frame] then return end
  seen[frame] = true
  ConsiderFrame(map, scores, frame)
  if depth == 0 or type(frame.GetChildren) ~= "function" then return end
  local children = {frame:GetChildren()}
  for _, child in ipairs(children) do CollectChildren(map, scores, child, depth - 1, seen) end
end

local function ResolveUnitFrames()
  local map, scores, seen = {}, {}, {}
  local roots = {
    _G.ElvUF_Party, _G.ElvUF_PartyGroup1, _G.ElvUF_PartyMover,
    _G.CompactPartyFrame, _G.PartyFrame,
  }
  for _, rootFrame in ipairs(roots) do CollectChildren(map, scores, rootFrame, 3, seen) end

  for index = 1, 5 do
    ConsiderFrame(map, scores, _G["ElvUF_PartyGroup1UnitButton" .. index])
    ConsiderFrame(map, scores, _G["ElvUF_PartyUnitButton" .. index])
    ConsiderFrame(map, scores, _G["CompactPartyFrameMember" .. index])
  end
  for index = 1, 4 do
    ConsiderFrame(map, scores, _G["PartyMemberFrame" .. index], "party" .. index)
  end

  -- Some ElvUI layouts include the player as the first party unit. Prefer that
  -- frame when it exists; otherwise attach self cooldowns to the normal player frame.
  ConsiderFrame(map, scores, _G.ElvUF_Player, "player")
  ConsiderFrame(map, scores, _G.PlayerFrame, "player")

  -- One fallback frame walk is allowed only when known party-frame names did not
  -- resolve the active units. This runs on roster/UI events, never every frame.
  local _, byUnit = GroupMembers()
  local missing = false
  for unit in pairs(byUnit) do if not map[unit] then missing = true break end end
  if missing and type(EnumerateFrames) == "function" then
    local frame, count = nil, 0
    repeat
      frame = EnumerateFrames(frame)
      count = count + 1
      if frame then ConsiderFrame(map, scores, frame) end
    until not frame or count >= 6000
  end

  unitFrames = map
  return map
end

local function CreateIcon(parent, size)
  local frame = W:CreateIcon(parent, tonumber(size) or ICON_SIZE)
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self)
    local entry = self.entry
    if not entry or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")

    if entry.missing then
      GameTooltip:SetText("No interrupt detected", 1, 1, 1)
      GameTooltip:AddLine("This group member has not shared or cast a known interrupt yet.", 0.78, 0.78, 0.84, true)
    else
      local spellID = tonumber(entry.id)
      local spellTooltipShown = false
      if spellID and spellID > 0 then
        if type(GameTooltip.SetSpellByID) == "function" then
          spellTooltipShown = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
        end
        if not spellTooltipShown and type(GameTooltip.SetHyperlink) == "function" then
          spellTooltipShown = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(spellID))
        end
      end

      if not spellTooltipShown then
        GameTooltip:SetText(tostring(entry.name), 1, 1, 1)
      end
    end

    if self.ownerName and self.ownerName ~= "" then
      GameTooltip:AddLine("Player: " .. tostring(self.ownerName), 0.72, 0.82, 1.00)
    end

    local remaining = tonumber(self.remaining) or 0
    if not entry.missing then
      if remaining > 0 then
        GameTooltip:AddLine("Cooldown remaining: " .. W:FormatCooldown(remaining), 1, 0.82, 0.12)
      elseif not entry.preview then
        GameTooltip:AddLine("Ready", 0.34, 0.95, 0.38)
      end
    end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return frame
end

local function CreateContainer(unit)
  if containers[unit] then return containers[unit] end
  local frame = CreateFrame("Frame", "RetreatUIPartyUtility_" .. unit, UIParent)
  frame:SetSize(1, ICON_SIZE)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame.unit = unit
  frame.icons = {}
  frame.entries = {}
  frame:Hide()
  containers[unit] = frame
  return frame
end

local function AnchorContainer(unit)
  local container = CreateContainer(unit)
  local target = unitFrames[unit]
  container.targetFrame = target
  container:ClearAllPoints()
  if not target then container:Hide(); return false end
  container:SetPoint("RIGHT", target, "LEFT", -4, 0)
  if type(target.GetFrameStrata) == "function" and type(container.SetFrameStrata) == "function" then
    local strata = target:GetFrameStrata()
    if strata then container:SetFrameStrata(strata) end
  end
  if type(target.GetFrameLevel) == "function" and type(container.SetFrameLevel) == "function" then
    container:SetFrameLevel((tonumber(target:GetFrameLevel()) or 1) + 8)
  end
  return true
end

local function RefreshAnchors()
  ResolveUnitFrames()
  for _, unit in ipairs(UNIT_ORDER) do AnchorContainer(unit) end
end

local function RoleAllows(category, role, settings)
  if not settings.roleAware then return true end
  if category == "taunt" and role ~= "NONE" and role ~= "TANK" then return false end
  return true
end

local function BuildPreviewEntries(unit)
  local entries = {}
  local categories = unit == "player" and {"defensive", "immunity"} or {"dispel", "external"}
  for index, category in ipairs(categories) do
    entries[#entries + 1] = {
      id = 0,
      name = CATEGORY_LABELS[category],
      category = category,
      texture = PREVIEW_TEXTURES[category],
      remaining = index == 2 and 24 or 0,
      duration = index == 2 and 60 or 0,
      preview = true,
    }
  end
  return entries
end

local function AddEntry(entriesByUnit, unit, entry)
  if not entriesByUnit[unit] then return end
  entriesByUnit[unit][#entriesByUnit[unit] + 1] = entry
end

local function FindPeerForMember(member)
  if not member then return nil end
  local peer = peers[member.name] or peers[member.short]
  if peer then return peer end
  for peerName, candidate in pairs(peers) do
    if Normalize(peerName) == Normalize(member.name) or Normalize(ShortName(peerName)) == Normalize(member.short) then
      return candidate
    end
  end
  return nil
end

local function CapabilityCopy(capability)
  return {
    id=capability.id, name=capability.name, category=capability.category, texture=capability.texture,
    cooldownHint=capability.cooldownHint, duration=capability.duration, expires=capability.expires,
    definition=capability.definition, inferred=capability.inferred, racial=capability.racial,
  }
end

local function HasArcaneTorrent(capabilities)
  for _, capability in ipairs(capabilities or {}) do
    if Normalize(capability.name) == "arcane torrent" then return true end
  end
  return false
end

local function MergedCapabilitiesForMember(member)
  local peer = FindPeerForMember(member)
  local merged, ordered = {}, {}
  local className = (peer and peer.className and RUI.NormalizeClassName and RUI:NormalizeClassName(peer.className)) or member.className

  if not (peer and peer.exactCapabilities) then
    for _, capability in ipairs(InferredCapabilities(className)) do
      local copy = CapabilityCopy(capability)
      copy.inferred = true
      merged[copy.id] = copy
      ordered[#ordered + 1] = copy
    end
  end

  for _, capability in pairs(peer and peer.capabilities or {}) do
    local existing = merged[capability.id]
    if existing then
      for key, value in pairs(capability) do existing[key] = value end
    else
      local copy = CapabilityCopy(capability)
      merged[copy.id] = copy
      ordered[#ordered + 1] = copy
    end
  end

  -- A Blood Elf always owns Arcane Torrent even when an older RetreatUI client
  -- did not include racials in its capability broadcast.
  if IsBloodElfUnit(member.unit) and not HasArcaneTorrent(ordered) then
    local racial = ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID, nil, true)
    merged[racial.id] = racial
    ordered[#ordered + 1] = racial
  end

  return peer, ordered
end

local function BuildEntriesByUnit()
  local settings = GetSettings()
  local entriesByUnit = {}
  for _, unit in ipairs(UNIT_ORDER) do entriesByUnit[unit] = {} end

  if previewMode then
    for _, unit in ipairs(UNIT_ORDER) do
      if unitFrames[unit] then entriesByUnit[unit] = BuildPreviewEntries(unit) end
    end
    return entriesByUnit
  end
  if not settings.enabled or IsInRaidSafe() then return entriesByUnit end
  if not IsInPartySafe() and not settings.showSolo then return entriesByUnit end

  local byName, byUnit = GroupMembers()
  local playerMember = byUnit.player or {name=PlayerFullName(), short=ShortName(PlayerFullName()), unit="player", role=UnitRole("player")}

  if settings.showSelf then
    for _, capability in ipairs(localCapabilities) do
      if capability.category ~= "interrupt" and settings.categories[capability.category] and RoleAllows(capability.category, playerMember.role, settings) then
        local remaining, duration = GetLocalCooldown(capability)
        if settings.showReady or remaining > 0 then
          AddEntry(entriesByUnit, "player", {
            id=capability.id, name=capability.name, category=capability.category, texture=capability.texture,
            remaining=remaining, duration=duration, localPlayer=true, capability=capability,
          })
        end
      end
    end
  end

  local playerName = Normalize(PlayerFullName())
  for unit, member in pairs(byUnit) do
    if unit ~= "player" then
      local _, ordered = MergedCapabilitiesForMember(member)

      for _, capability in ipairs(ordered) do
        if capability.category ~= "interrupt" and settings.categories[capability.category] and RoleAllows(capability.category, member.role, settings) then
          local remaining = capability.expires and math.max(0, capability.expires - GetTime()) or 0
          if settings.showReady or remaining > 0 then
            AddEntry(entriesByUnit, unit, {
              id=capability.id, name=capability.name, category=capability.category, texture=capability.texture,
              remaining=remaining, duration=capability.duration or capability.cooldownHint or 0,
              capability=capability, peerName=member.name, inferred=capability.inferred,
            })
          end
        end
      end
    end
  end

  for _, unit in ipairs(UNIT_ORDER) do
    local entries = entriesByUnit[unit]
    table.sort(entries, function(left, right)
      local a, b = CATEGORY_ORDER[left.category] or 999, CATEGORY_ORDER[right.category] or 999
      if a ~= b then return a < b end
      return tostring(left.name) < tostring(right.name)
    end)
    while #entries > MAX_PER_UNIT do table.remove(entries) end
  end
  return entriesByUnit
end

local function BuildInterruptPreviewEntries(unit)
  local entries = {
    {
      id = 1766,
      name = "Kick",
      category = "interrupt",
      texture = (GetSpellInfo and select(3, GetSpellInfo(1766))) or "Interface\\Icons\\Ability_Kick",
      remaining = unit == "party1" and 7.5 or 0,
      duration = 10,
      preview = true,
    },
  }
  if unit == "party2" then
    local torrent = ArcaneTorrentCapability(ARCANE_TORRENT_DEFAULT_ID, nil, true)
    torrent.remaining = 38
    torrent.duration = 120
    torrent.preview = true
    entries[#entries + 1] = torrent
  end
  return entries
end

local function BuildInterruptEntriesByUnit()
  local settings = GetInterruptSettings()
  local entriesByUnit = {}
  for _, unit in ipairs(UNIT_ORDER) do entriesByUnit[unit] = {} end

  local showingPreview = previewMode or interruptEditorPreview
  if showingPreview then
    for _, unit in ipairs(UNIT_ORDER) do entriesByUnit[unit] = BuildInterruptPreviewEntries(unit) end
    return entriesByUnit, nil, true
  end
  if not settings.enabled or IsInRaidSafe() then return entriesByUnit, nil, false end
  if not IsInPartySafe() and not settings.showSolo then return entriesByUnit, nil, false end

  local _, byUnit = GroupMembers()
  local playerMember = byUnit.player or {name=PlayerFullName(), short=ShortName(PlayerFullName()), unit="player", role=UnitRole("player")}

  if settings.showSelf then
    for _, capability in ipairs(localCapabilities) do
      if capability.category == "interrupt" then
        local remaining, duration = GetLocalCooldown(capability)
        AddEntry(entriesByUnit, "player", {
          id=capability.id, name=capability.name, category="interrupt", texture=capability.texture,
          remaining=remaining, duration=duration, localPlayer=true, capability=capability,
          racial=capability.racial or Normalize(capability.name) == "arcane torrent",
        })
      end
    end
  end

  for unit, member in pairs(byUnit) do
    if unit ~= "player" then
      local _, ordered = MergedCapabilitiesForMember(member)
      for _, capability in ipairs(ordered) do
        if capability.category == "interrupt" then
          local remaining = capability.expires and math.max(0, capability.expires - GetTime()) or 0
          AddEntry(entriesByUnit, unit, {
            id=capability.id, name=capability.name, category="interrupt", texture=capability.texture,
            remaining=remaining, duration=capability.duration or capability.cooldownHint or 0,
            capability=capability, peerName=member.name, inferred=capability.inferred,
            racial=capability.racial or Normalize(capability.name) == "arcane torrent",
          })
        end
      end
    end
  end

  for _, unit in ipairs(UNIT_ORDER) do
    if byUnit[unit] then
      local entries = entriesByUnit[unit]
      table.sort(entries, function(left, right)
        if (left.racial == true) ~= (right.racial == true) then return left.racial ~= true end
        return tostring(left.name) < tostring(right.name)
      end)
      if #entries == 0 then
        entries[1] = {
          id=0, name="No interrupt detected", category="interrupt",
          texture="Interface\\Icons\\Ability_Kick", missing=true,
        }
      end
    end
  end
  return entriesByUnit, byUnit, false
end

local function EntryRemaining(entry)
  if entry.preview then return tonumber(entry.remaining) or 0, tonumber(entry.duration) or 0 end
  if entry.localPlayer and entry.capability then return GetLocalCooldown(entry.capability) end
  local capability = entry.capability
  local remaining = capability and capability.expires and math.max(0, capability.expires - GetTime()) or 0
  return remaining, capability and (capability.duration or capability.cooldownHint) or entry.duration or 0
end

local function UpdateIcon(icon)
  local entry = icon and icon.entry
  if not entry then return end
  if entry.missing then
    icon.remaining = 0
    W:SetIconInactive(icon, true)
    icon:SetAlpha(0.24)
    W:SetCooldownDisplay(icon, 0, false)
    return
  end
  local remaining = EntryRemaining(entry)
  icon.remaining = remaining
  W:SetIconInactive(icon, remaining > 0.05)
  W:SetCooldownDisplay(icon, remaining, remaining > 0.05)
end

local function RenderUnit(unit, entries)
  local frame = CreateContainer(unit)
  frame.entries = entries
  local target = unitFrames[unit]
  if not target or #entries == 0 then frame:Hide(); return end
  if type(target.IsShown) == "function" and not target:IsShown() and not previewMode then frame:Hide(); return end

  local total = #entries * ICON_SIZE + (#entries - 1) * ICON_SPACING
  frame:SetSize(math.max(1, total), ICON_SIZE)
  for index, entry in ipairs(entries) do
    local icon = frame.icons[index]
    if not icon then icon = CreateIcon(frame); frame.icons[index] = icon end
    icon.entry = entry
    icon.texture:SetTexture(entry.texture)
    W:SetBorder(icon, CATEGORY_COLORS[entry.category] or {1,1,1}, 1)
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", frame, "RIGHT", -((index - 1) * (ICON_SIZE + ICON_SPACING)), 0)
    UpdateIcon(icon)
    icon:Show()
  end
  for index = #entries + 1, #frame.icons do frame.icons[index]:Hide() end
  frame:Show()
end

local function UnitOrderIndex(unit)
  for index, token in ipairs(UNIT_ORDER) do
    if token == unit then return index end
  end
  return 99
end

local function ClassColorForUnit(unit, previewIndex)
  if previewIndex then
    local preview = {
      {0.82, 0.38, 0.08}, {0.18, 0.56, 0.72}, {0.42, 0.22, 0.66},
      {0.16, 0.62, 0.30}, {0.58, 0.30, 0.18},
    }
    return unpack(preview[previewIndex] or preview[1])
  end
  if type(UnitClass) == "function" then
    local _, classToken = UnitClass(unit)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and classToken and colors[classToken]
    if color then return color.r or 0.25, color.g or 0.45, color.b or 0.62 end
  end
  return 0.20, 0.42, 0.55
end

local function PartyFrameBounds()
  if not next(unitFrames) then ResolveUnitFrames() end
  local left, right, bottom
  for index = 1, 4 do
    local frame = unitFrames["party" .. index]
    if frame and type(frame.GetLeft) == "function" then
      local frameLeft, frameRight, frameBottom = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
      if frameLeft and frameRight and frameBottom then
        left = left and math.min(left, frameLeft) or frameLeft
        right = right and math.max(right, frameRight) or frameRight
        bottom = bottom and math.min(bottom, frameBottom) or frameBottom
      end
    end
  end
  if left and right and bottom then return left, bottom, math.max(1, right - left) end

  for _, frame in ipairs({_G.ElvUF_Party, _G.ElvUF_PartyGroup1, _G.CompactPartyFrame, _G.PartyFrame}) do
    if frame and type(frame.GetLeft) == "function" then
      local frameLeft, frameRight, frameBottom = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
      if frameLeft and frameRight and frameBottom then
        return frameLeft, frameBottom, math.max(1, frameRight - frameLeft)
      end
    end
  end
  return nil
end


local function PartyAnchorFrame()
  if not next(unitFrames) then ResolveUnitFrames() end
  for _, frame in ipairs({_G.ElvUF_Party, _G.ElvUF_PartyGroup1, _G.CompactPartyFrame, _G.PartyFrame}) do
    if frame and type(frame.GetWidth) == "function" and type(frame.GetHeight) == "function" then
      local width, height = frame:GetWidth(), frame:GetHeight()
      if width and height and width > 1 and height > 1 then return frame end
    end
  end
  local first = unitFrames.party1
  if first and type(first.GetParent) == "function" then
    local parent = first:GetParent()
    if parent and parent ~= UIParent and type(parent.GetWidth) == "function" then
      local width = parent:GetWidth()
      if width and width > 1 then return parent end
    end
  end
  return nil
end

local function CreateInterruptTracker()
  if interruptFrame then return interruptFrame end
  local frame = CreateFrame("Frame", "RetreatUIPartyInterruptTracker", UIParent)
  frame:SetSize(INTERRUPT_TRACKER_WIDTH, INTERRUPT_HEADER_HEIGHT + INTERRUPT_TRACKER_PADDING * 2)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame.rows = {}
  frame.members = frame.rows
  RUI:SkinFrame(frame, {0.015, 0.02, 0.028, 0.96}, {0.18, 0.22, 0.28, 1})

  frame.header = CreateFrame("Frame", nil, frame)
  frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", INTERRUPT_TRACKER_PADDING, -INTERRUPT_TRACKER_PADDING)
  frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -INTERRUPT_TRACKER_PADDING, -INTERRUPT_TRACKER_PADDING)
  frame.header:SetHeight(INTERRUPT_HEADER_HEIGHT)
  RUI:SkinFrame(frame.header, {0.015, 0.04, 0.065, 0.98}, {0.015, 0.04, 0.065, 0})
  frame.header.text = frame.header:CreateFontString(nil, "OVERLAY")
  frame.header.text:SetPoint("CENTER", frame.header, "CENTER", 0, 0)
  RUI:ApplyFont(frame.header.text, 15, "OUTLINE")
  frame.header.text:SetTextColor(0.05, 0.95, 1.00, 1)
  frame.header.text:SetText("Interrupts")

  frame:Hide()
  interruptFrame = frame
  return frame
end

local function InterruptRowFrame(index)
  local tracker = CreateInterruptTracker()
  local row = tracker.rows[index]
  if row then return row end
  row = CreateFrame("Frame", nil, tracker)
  row:SetHeight(INTERRUPT_ROW_HEIGHT)
  RUI:SkinFrame(row, {0.18, 0.36, 0.46, 0.94}, {0.02, 0.02, 0.03, 1})

  row.icon = CreateIcon(row, INTERRUPT_ROW_HEIGHT - 4)
  row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

  row.nameText = row:CreateFontString(nil, "OVERLAY")
  row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 9, 0)
  row.nameText:SetPoint("RIGHT", row, "RIGHT", -82, 0)
  row.nameText:SetJustifyH("LEFT")
  RUI:ApplyFont(row.nameText, 12, "OUTLINE")
  row.nameText:SetTextColor(0.96, 0.96, 0.98, 1)

  row.statusText = row:CreateFontString(nil, "OVERLAY")
  row.statusText:SetPoint("RIGHT", row, "RIGHT", -9, 0)
  row.statusText:SetWidth(68)
  row.statusText:SetJustifyH("RIGHT")
  RUI:ApplyFont(row.statusText, 12, "OUTLINE")

  tracker.rows[index] = row
  return row
end

function RUI:ApplyPartyInterruptLayout()
  local frame = CreateInterruptTracker()
  frame:SetScale(1)
  frame:ClearAllPoints()

  local anchor = PartyAnchorFrame()
  if anchor then
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -INTERRUPT_PARTY_GAP)
    frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -INTERRUPT_PARTY_GAP)
  else
    local left, bottom, width = PartyFrameBounds()
    if left and bottom and width then
      frame:SetWidth(width)
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom - INTERRUPT_PARTY_GAP)
    else
      frame:SetWidth(INTERRUPT_TRACKER_WIDTH)
      frame:SetPoint("TOP", UIParent, "CENTER", 0, -120)
    end
  end
  if self.layout then self.layout.partyInterrupts = {autoAnchor=true} end
  return true
end

function RUI:GetPartyInterruptDefaultPosition()
  local frame = CreateInterruptTracker()
  self:ApplyPartyInterruptLayout()
  local x, y = frame:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if x and y and parentX and parentY then return x - parentX, y - parentY end
  return 0, -278
end

local function PreviewMemberName(unit)
  local names = {player="YOU", party1="KINDERLINE", party2="PAMELAA", party3="HEALER", party4="DPS"}
  return names[unit] or string.upper(unit)
end

local function FlattenInterruptEntries(entriesByUnit, byUnit, showingPreview)
  local flattened = {}
  for _, unit in ipairs(UNIT_ORDER) do
    local member = byUnit and byUnit[unit]
    local ownerName = showingPreview and PreviewMemberName(unit) or tostring(member and member.short or unit)
    for _, entry in ipairs(entriesByUnit[unit] or {}) do
      local remaining, duration = EntryRemaining(entry)
      flattened[#flattened + 1] = {
        unit = unit,
        ownerName = ownerName,
        entry = entry,
        remaining = remaining,
        duration = duration,
        unitOrder = UnitOrderIndex(unit),
      }
    end
  end

  table.sort(flattened, function(left, right)
    local leftMissing, rightMissing = left.entry.missing == true, right.entry.missing == true
    if leftMissing ~= rightMissing then return not leftMissing end

    local leftReady, rightReady = left.remaining <= 0.05, right.remaining <= 0.05
    if leftReady ~= rightReady then return leftReady end
    if not leftReady and math.abs(left.remaining - right.remaining) > 0.05 then
      return left.remaining < right.remaining
    end
    if left.unitOrder ~= right.unitOrder then return left.unitOrder < right.unitOrder end
    return tostring(left.entry.name) < tostring(right.entry.name)
  end)
  return flattened
end

local function UpdateInterruptRow(row, item, index, width, showingPreview)
  local entry = item.entry
  local remaining = EntryRemaining(entry)
  item.remaining = remaining
  row.item = item
  row:SetWidth(width)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", interruptFrame.header, "BOTTOMLEFT", 0, -((index - 1) * (INTERRUPT_ROW_HEIGHT + INTERRUPT_ROW_GAP)))
  row:SetPoint("TOPRIGHT", interruptFrame.header, "BOTTOMRIGHT", 0, -((index - 1) * (INTERRUPT_ROW_HEIGHT + INTERRUPT_ROW_GAP)))

  local r, g, b = ClassColorForUnit(item.unit, showingPreview and index or nil)
  if entry.missing then r, g, b = 0.20, 0.20, 0.24 end
  if row.SetBackdropColor then row:SetBackdropColor(r * 0.72, g * 0.72, b * 0.72, 0.96) end

  row.icon.entry = entry
  row.icon.ownerName = item.ownerName
  row.icon.texture:SetTexture(entry.texture or "Interface\\Icons\\Ability_Kick")
  if entry.missing then
    W:SetBorder(row.icon, {0.34, 0.34, 0.40}, 1)
  elseif entry.racial then
    W:SetBorder(row.icon, {0.72, 0.40, 1.00}, 1)
  else
    W:SetBorder(row.icon, CATEGORY_COLORS.interrupt, 1)
  end
  UpdateIcon(row.icon)

  row.nameText:SetText(item.ownerName)
  if entry.missing then
    row.statusText:SetText("UNKNOWN")
    row.statusText:SetTextColor(0.68, 0.68, 0.72, 1)
  elseif remaining <= 0.05 then
    row.statusText:SetText("READY")
    row.statusText:SetTextColor(0.18, 1.00, 0.18, 1)
  else
    row.statusText:SetText(W:FormatCooldown(remaining))
    if remaining <= 5 then row.statusText:SetTextColor(1.00, 0.88, 0.16, 1)
    else row.statusText:SetTextColor(1.00, 0.48, 0.12, 1) end
  end
  row:Show()
end

local function RenderInterruptTracker()
  local frame = CreateInterruptTracker()
  local entriesByUnit, byUnit, showingPreview = BuildInterruptEntriesByUnit()
  local entries = FlattenInterruptEntries(entriesByUnit, byUnit, showingPreview)
  if #entries == 0 then frame:Hide(); return end

  local _, _, partyWidth = PartyFrameBounds()
  local width = partyWidth or INTERRUPT_TRACKER_WIDTH
  local height = INTERRUPT_TRACKER_PADDING * 2 + INTERRUPT_HEADER_HEIGHT
    + #entries * INTERRUPT_ROW_HEIGHT + math.max(0, #entries - 1) * INTERRUPT_ROW_GAP
  frame:SetHeight(height)
  if not PartyAnchorFrame() then frame:SetWidth(width) end

  for index, item in ipairs(entries) do
    UpdateInterruptRow(InterruptRowFrame(index), item, index, math.max(1, width - INTERRUPT_TRACKER_PADDING * 2), showingPreview)
  end
  for index = #entries + 1, #frame.rows do frame.rows[index]:Hide() end

  RUI:ApplyPartyInterruptLayout()
  frame:Show()
end

local function RenderAll()
  if not next(unitFrames) then RefreshAnchors() end
  local entriesByUnit = BuildEntriesByUnit()
  for _, unit in ipairs(UNIT_ORDER) do RenderUnit(unit, entriesByUnit[unit] or {}) end
  RenderInterruptTracker()
end

local function UpdateVisibleCooldowns()
  for _, unit in ipairs(UNIT_ORDER) do
    local frame = containers[unit]
    if frame and frame:IsShown() then
      local target = frame.targetFrame
      if not target or (type(target.IsShown) == "function" and not target:IsShown() and not previewMode) then
        frame:Hide()
      else
        for _, icon in ipairs(frame.icons or {}) do if icon:IsShown() then UpdateIcon(icon) end end
      end
    end
  end
  if interruptFrame and interruptFrame:IsShown() then
    -- Re-rendering keeps READY interrupts at the top and moves active cooldowns
    -- upward as their remaining time becomes the next available interrupt.
    RenderInterruptTracker()
  end
end

local function ScheduleRebuild()
  if rebuildPending then return end
  rebuildPending = true
  RUI:After(0.20, function()
    rebuildPending = false
    BuildGlobalIndex()
    BuildLocalCapabilities()
    SendCapabilities()
    RefreshAnchors()
    RenderAll()
  end)
end

local function Peer(sender)
  sender = tostring(sender or "Unknown")
  peers[sender] = peers[sender] or {capabilities={}, chunks={}, lastSeen=0}
  peers[sender].lastSeen = GetTime and GetTime() or 0
  return peers[sender]
end

local function ResolvePeerTexture(spellID, spellName)
  local known = globalIndexByID[tonumber(spellID)] or globalIndexByName[Normalize(spellName)]
  return known and known.texture, known
end

local function ParseList(sender, chunk, total, payload)
  chunk, total = tonumber(chunk) or 1, tonumber(total) or 1
  local peer = Peer(sender)
  peer.chunks[chunk] = payload or ""
  peer.totalChunks = total
  for index = 1, total do if peer.chunks[index] == nil then return end end

  peer.capabilities = {}
  peer.exactCapabilities = true
  for index = 1, total do
    for packed in tostring(peer.chunks[index] or ""):gmatch("[^~]+") do
      local category, spellID, cooldownHint, spellName = packed:match("^([^,]+),([^,]+),([^,]+),(.+)$")
      spellID = tonumber(spellID)
      if CATEGORY_ORDER[category] and spellID then
        local texture, known = ResolvePeerTexture(spellID, spellName)
        if texture then
          peer.capabilities[spellID] = {
            id=spellID, name=known and known.name or spellName, category=category, texture=texture,
            cooldownHint=tonumber(cooldownHint) or (known and known.cooldownHint) or 0,
          }
        end
      end
    end
  end
  peer.chunks = {}
  RenderAll()
end

local function ParseCooldown(sender, spellID, remaining, duration)
  spellID, remaining, duration = tonumber(spellID), tonumber(remaining) or 0, tonumber(duration) or 0
  if not spellID then return end
  local peer = Peer(sender)
  local capability = peer.capabilities[spellID]
  if not capability then
    local known = globalIndexByID[spellID]
    if not known then return end
    peer.capabilities[spellID] = {
      id=spellID, name=known.name, category=known.category, texture=known.texture, cooldownHint=known.cooldownHint,
    }
    capability = peer.capabilities[spellID]
  end
  capability.duration = duration
  capability.expires = remaining > 0 and (GetTime() + remaining) or nil
  RenderAll()
end

local function HandleAddonMessage(prefix, message, channel, sender)
  if prefix ~= PREFIX or not sender or Normalize(sender) == Normalize(PlayerFullName()) then return end
  local kind, a, b, payload = tostring(message or ""):match("^([^|]+)|?([^|]*)|?([^|]*)|?(.*)$")
  if kind == "Q" then SendCapabilities(sender); return end
  if kind == "H" then
    local peer = Peer(sender)
    peer.version, peer.className, peer.build = a, b, payload
    return
  end
  if kind == "L" then ParseList(sender, a, b, payload); return end
  if kind == "C" then ParseCooldown(sender, a, b, payload); return end
end

local function ExtractSpellID(...)
  local values = {...}
  for index = #values, 1, -1 do
    local value = tonumber(values[index])
    if value and value > 0 then return value end
  end
  return nil
end

local function HandleUnitSpellcast(unit, ...)
  if type(unit) ~= "string" or not unit:match("^party[1-4]$") then return end
  local spellID = ExtractSpellID(...)
  local spellName
  for _, value in ipairs({...}) do if type(value) == "string" and not value:find("^Cast%-") then spellName = value end end
  if spellID and GetSpellInfo then spellName = GetSpellInfo(spellID) or spellName end
  local known = globalIndexByID[spellID] or globalIndexByName[Normalize(spellName)]
  if not known then return end

  local _, byUnit = GroupMembers()
  local member = byUnit[unit]
  if not member then return end
  local peer = Peer(member.name)
  local capability = peer.capabilities[known.id]
  if not capability then
    capability = {id=known.id, name=known.name, category=known.category, texture=known.texture, cooldownHint=known.cooldownHint, inferred=true}
    peer.capabilities[known.id] = capability
  end
  local duration = tonumber(known.cooldownHint) or 0
  capability.duration = duration
  capability.expires = duration > 1.5 and (GetTime() + duration) or nil
  RenderAll()
end

local function PollLocalCooldowns()
  if not IsInPartySafe() and not previewMode then return end
  for _, capability in ipairs(localCapabilities) do
    local remaining, duration = GetLocalCooldown(capability)
    local active = remaining > 0.05
    local previous = localCooldownState[capability.id]
    if not previous or previous.active ~= active then
      localCooldownState[capability.id] = {active=active, duration=duration}
      Send("C|" .. capability.id .. "|" .. string.format("%.1f", remaining) .. "|" .. string.format("%.1f", duration))
      if GetSettings().showReady == false then RenderAll() end
    end
  end
end

local function PurgePeers()
  local byName = GroupMembers()
  for name in pairs(peers) do
    if not byName[Normalize(name)] and not byName[Normalize(ShortName(name))] then peers[name] = nil end
  end
end

local function CheckButton(parent, label, category, x, y)
  local button = CreateFrame("CheckButton", nil, parent)
  button:SetSize(20, 20)
  button:SetPoint("TOPLEFT", x, y)
  button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
  button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  button.label = button:CreateFontString(nil, "OVERLAY")
  button.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
  RUI:ApplyFont(button.label, 10, "OUTLINE")
  button.label:SetText(label)
  button.category = category
  button:SetScript("OnClick", function(self)
    GetSettings().categories[self.category] = self:GetChecked() == true
    RenderAll()
  end)
  return button
end

local function SmallButton(parent, label, width, callback)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, 24)
  RUI:SkinFrame(button, {0.08,0.08,0.11,0.98}, {0.30,0.30,0.38,1})
  button.text = button:CreateFontString(nil, "OVERLAY")
  button.text:SetPoint("CENTER")
  RUI:ApplyFont(button.text, 10, "OUTLINE")
  button.text:SetText(label)
  button:SetScript("OnClick", callback)
  return button
end

local function BuildSettingsWindow()
  if settingsWindow then return settingsWindow end
  settingsWindow = CreateFrame("Frame", "RetreatUIPartyUtilitySettings", UIParent)
  settingsWindow:SetSize(430, 260)
  settingsWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  settingsWindow:SetFrameStrata("DIALOG")
  settingsWindow:SetMovable(true)
  settingsWindow:EnableMouse(true)
  settingsWindow:RegisterForDrag("LeftButton")
  settingsWindow:SetScript("OnDragStart", function(self) if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end end)
  settingsWindow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  RUI:SkinFrame(settingsWindow, {0.018,0.018,0.024,0.98}, {1.00,0.35,0.08,1})

  settingsWindow.title = settingsWindow:CreateFontString(nil, "OVERLAY")
  settingsWindow.title:SetPoint("TOPLEFT", 14, -12)
  RUI:ApplyFont(settingsWindow.title, 14, "OUTLINE")
  settingsWindow.title:SetText("RetreatUI Party Utility")

  settingsWindow.subtitle = settingsWindow:CreateFontString(nil, "OVERLAY")
  settingsWindow.subtitle:SetPoint("TOPLEFT", settingsWindow.title, "BOTTOMLEFT", 0, -6)
  settingsWindow.subtitle:SetWidth(400)
  settingsWindow.subtitle:SetJustifyH("LEFT")
  RUI:ApplyFont(settingsWindow.subtitle, 9, "OUTLINE")
  settingsWindow.subtitle:SetTextColor(0.78,0.78,0.84,1)
  settingsWindow.subtitle:SetText("Non-interrupt utility stays beside each party frame. Interrupts now use a separate central tracker for the whole party, including Blood Elf Arcane Torrent. Move and scale it through /rui hud.")

  settingsWindow.checks = {}
  local ordered = {"combatres","dispel","external","defensive","immunity","taunt"}
  for index, category in ipairs(ordered) do
    local column = index > 4 and 2 or 1
    local row = column == 1 and index or index - 4
    local x = column == 1 and 18 or 225
    local y = -82 - (row - 1) * 30
    settingsWindow.checks[category] = CheckButton(settingsWindow, CATEGORY_LABELS[category], category, x, y)
  end

  settingsWindow.preview = SmallButton(settingsWindow, "Toggle Preview", 110, function()
    previewMode = not previewMode
    RefreshAnchors()
    RenderAll()
  end)
  settingsWindow.preview:SetPoint("BOTTOMLEFT", 14, 14)
  settingsWindow.resync = SmallButton(settingsWindow, "Resync Group", 110, function()
    Send("Q|" .. Escape(RUI.version))
    SendCapabilities()
    RUI:Print("Party Utility group sync requested.")
  end)
  settingsWindow.resync:SetPoint("LEFT", settingsWindow.preview, "RIGHT", 7, 0)
  settingsWindow.close = SmallButton(settingsWindow, "Close", 82, function() settingsWindow:Hide() end)
  settingsWindow.close:SetPoint("BOTTOMRIGHT", -14, 14)
  settingsWindow:Hide()
  return settingsWindow
end

function RUI:OpenPartyUtilitySettings()
  local window = BuildSettingsWindow()
  local settings = GetSettings()
  for category, check in pairs(window.checks or {}) do check:SetChecked(settings.categories[category] == true) end
  window:Show()
  return true
end

function RUI:TogglePartyUtilityPreview(force)
  if force == nil then previewMode = not previewMode else previewMode = force == true end
  RefreshAnchors()
  RenderAll()
  return previewMode
end

function RUI:SetPartyInterruptEditorPreview(enabled)
  interruptEditorPreview = enabled == true
  RenderInterruptTracker()
  return interruptEditorPreview
end

function RUI:GetPartyInterruptTrackerStatus()
  local shown = interruptFrame and interruptFrame:IsShown() or false
  local count = 0
  if interruptFrame then
    for _, row in ipairs(interruptFrame.rows or {}) do if row:IsShown() then count = count + 1 end end
  end
  return shown, count, interruptEditorPreview
end

function RUI:GetPartyUtilityStatus()
  local capabilityCount, peerCount, attachedCount = #localCapabilities, 0, 0
  for _ in pairs(peers) do peerCount = peerCount + 1 end
  for _, unit in ipairs(UNIT_ORDER) do if unitFrames[unit] then attachedCount = attachedCount + 1 end end
  return initialized, capabilityCount, peerCount, previewMode, attachedCount
end

function RUI:RefreshPartyUtility()
  RefreshAnchors()
  self:ApplyPartyInterruptLayout()
  ScheduleRebuild()
  return true
end

function RUI:InitializePartyUtilityTracker()
  if initialized then RefreshAnchors(); ScheduleRebuild(); return true end
  initialized = true
  GetSettings()
  BuildGlobalIndex()
  BuildLocalCapabilities()
  RefreshAnchors()

  if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  elseif type(RegisterAddonMessagePrefix) == "function" then
    pcall(RegisterAddonMessagePrefix, PREFIX)
  end

  driver = CreateFrame("Frame", "RetreatUIPartyUtilityDriver")
  for _, eventName in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "CHAT_MSG_ADDON", "UNIT_SPELLCAST_SUCCEEDED", "UI_SCALE_CHANGED",
  }) do pcall(driver.RegisterEvent, driver, eventName) end

  driver:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then HandleAddonMessage(...); return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then HandleUnitSpellcast(...); return end
    if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
      PurgePeers()
      RefreshAnchors()
      RenderAll()
      RUI:After(BROADCAST_DELAY, function() Send("Q|" .. Escape(RUI.version)); SendCapabilities(); RenderAll() end)
      return
    end
    if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
      ScheduleRebuild()
      return
    end
    RefreshAnchors()
    RenderAll()
    RUI:After(BROADCAST_DELAY, function() Send("Q|" .. Escape(RUI.version)); SendCapabilities(); RenderAll() end)
  end)

  driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    anchorElapsed = anchorElapsed + delta
    if elapsed >= UPDATE_INTERVAL then
      elapsed = 0
      PollLocalCooldowns()
      UpdateVisibleCooldowns()
    end
    if anchorElapsed >= 1.50 then
      anchorElapsed = 0
      -- Only re-anchor already resolved frames here. Full frame discovery is event-driven.
      for _, unit in ipairs(UNIT_ORDER) do
        local frame = containers[unit]
        if frame and frame.targetFrame ~= unitFrames[unit] then AnchorContainer(unit) end
      end
    end
  end)

  for _, delay in ipairs({0.10, 0.80, 2.00}) do
    RUI:After(delay, function() RefreshAnchors(); RenderAll() end)
  end
  RUI:After(BROADCAST_DELAY, function() Send("Q|" .. Escape(RUI.version)); SendCapabilities(); RenderAll() end)
  return true
end

RUI._partyUtilityLoaded = true
