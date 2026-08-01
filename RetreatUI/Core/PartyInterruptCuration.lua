local RUI = RetreatUI
if not RUI or type(RUI.InitializePartyUtilityTracker) ~= "function" then return end

-- Party interrupt curation
--
-- The collected class catalogues use "interrupt" for a wider family of spell
-- disruption effects, including long cooldown silences, fears and area control.
-- The central party tracker is intentionally narrower: one ordinary, direct
-- school-lock interrupt per member, plus Arcane Torrent in its own slot.
--
-- This layer runs after all class databases have loaded but before PartyUtility
-- builds its indexes. It verifies records against their live tooltip, promotes
-- misplaced direct interrupts from control/utility, and rejects broad control
-- abilities that were previously accepted merely because their category said
-- "interrupt".

local originalInitialize = RUI.InitializePartyUtilityTracker
local unpack = unpack or table.unpack
local scanner
local curated = false
local revision = 1

local ARCANE_TORRENT_IDS = {
  [50613]=true, [28730]=true, [25046]=true,
  [80483]=true, [69179]=true, [129597]=true,
}

local DIRECT_PHRASES = {
  "interrupts spellcasting",
  "interrupt spellcasting",
  "interrupting spellcasting",
  "interrupts the target's spellcasting",
  "interrupt the target's spellcasting",
  "interrupts the enemy's spellcasting",
  "interrupt the enemy's spellcasting",
  "interrupts an enemy's spellcasting",
  "interrupt an enemy's spellcasting",
  "preventing any spell in that school",
  "prevents any spell in that school",
  "preventing spells from that school",
  "prevents spells from that school",
}

local AREA_PHRASES = {
  "all enemies", "nearby enemies", "enemies within", "targets within",
  "around you", "around the target", "in an area", "area of effect",
}

local CONTROL_PHRASES = {
  "silences", "silenced", "stuns", "stunned", "fears", "feared",
  "horrifies", "incapacitates", "disorients", "knocks back", "knockback",
}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function ContainsAny(text, phrases)
  text = Normalize(text)
  for _, phrase in ipairs(phrases or {}) do
    if string.find(text, phrase, 1, true) then return true end
  end
  return false
end

local function IsArcaneTorrent(record)
  if type(record) ~= "table" then return false end
  if ARCANE_TORRENT_IDS[tonumber(record.id)] then return true end
  return Normalize(record.name) == "arcane torrent"
end

local function EnsureScanner()
  if scanner or type(CreateFrame) ~= "function" then return scanner end
  scanner = CreateFrame("GameTooltip", "RetreatUIPartyInterruptCurationScanner", UIParent, "GameTooltipTemplate")
  return scanner
end

local function ReadTooltip(record, bookIndex)
  local tooltip = EnsureScanner()
  if not tooltip then return "", false end

  tooltip:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
  tooltip:ClearLines()
  local shown = false

  if bookIndex and type(tooltip.SetSpellBookItem) == "function" then
    shown = pcall(tooltip.SetSpellBookItem, tooltip, bookIndex, BOOKTYPE_SPELL or "spell")
  end
  if not shown and type(tooltip.SetHyperlink) == "function" then
    local spellID = RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(record) or tonumber(record.id)
    if spellID and spellID > 0 then
      shown = pcall(tooltip.SetHyperlink, tooltip, "spell:" .. tostring(spellID))
    end
  end
  if not shown then return "", false end

  local parts = {}
  local count = type(tooltip.NumLines) == "function" and (tonumber(tooltip:NumLines()) or 0) or 0
  for index = 1, count do
    for _, side in ipairs({"TextLeft", "TextRight"}) do
      local fontString = _G["RetreatUIPartyInterruptCurationScanner" .. side .. tostring(index)]
      local text = fontString and type(fontString.GetText) == "function" and fontString:GetText() or nil
      if text and text ~= "" then parts[#parts + 1] = Normalize(text) end
    end
  end
  return table.concat(parts, "\n"), true
end

local function CooldownFromTooltip(text)
  text = Normalize(text)
  local value = text:match("([%d%.]+)%s*min%s+cooldown")
  if value then return (tonumber(value) or 0) * 60 end
  value = text:match("([%d%.]+)%s*sec%s+cooldown")
  if value then return tonumber(value) or 0 end
  value = text:match("([%d%.]+)%s*second%s+cooldown")
  if value then return tonumber(value) or 0 end
  return 0
end

local function IsStrictDirectTooltip(text)
  if text == "" or not ContainsAny(text, DIRECT_PHRASES) then return false end
  if ContainsAny(text, AREA_PHRASES) then return false end
  return true
end

local function IsControlOnlyTooltip(text)
  if text == "" then return false end
  return ContainsAny(text, CONTROL_PHRASES) and not ContainsAny(text, DIRECT_PHRASES)
end

local function SaveOriginal(record)
  if record.__ruiInterruptOriginalSaved then return end
  record.__ruiInterruptOriginalSaved = true
  record.__ruiInterruptOriginalCategory = record.category
  record.__ruiInterruptOriginalDirect = record.directInterrupt
  record.__ruiInterruptOriginalPrimary = record.primaryInterrupt
end

local function RestoreOriginal(record)
  SaveOriginal(record)
  record.category = record.__ruiInterruptOriginalCategory
  record.directInterrupt = record.__ruiInterruptOriginalDirect
  record.primaryInterrupt = record.__ruiInterruptOriginalPrimary
  record.partyInterruptCurated = nil
  record.partyInterruptExclusion = nil
end

local function MarkDirect(record, reason)
  record.partyInterruptOriginalCategory = record.partyInterruptOriginalCategory or record.category
  record.category = "interrupt"
  record.directInterrupt = true
  record.partyInterruptCurated = reason or "direct"
  record.partyInterruptExclusion = nil
end

local function MarkExcluded(record, reason)
  record.directInterrupt = false
  record.primaryInterrupt = false
  record.partyInterruptCurated = "excluded"
  record.partyInterruptExclusion = reason or "not a direct school-lock interrupt"
end

local function CandidateRecord(record)
  if type(record) ~= "table" or IsArcaneTorrent(record) then return false end
  if record.__ruiInterruptOriginalDirect ~= nil then return true end

  local category = Normalize(record.__ruiInterruptOriginalCategory or record.category)
  if category == "interrupt" then return true end
  if category ~= "control" and category ~= "utility" and category ~= "racial" then return false end
  if record.trackCooldown == false then return false end

  local hint = tonumber(record.cooldownHint) or 0
  return hint <= 45
end

local function CurateRecord(record, bookIndex)
  RestoreOriginal(record)
  if IsArcaneTorrent(record) then
    MarkExcluded(record, "Arcane Torrent uses the separate racial slot")
    return false
  end

  -- Explicit class metadata always wins.
  if record.__ruiInterruptOriginalDirect == true then
    MarkDirect(record, "explicit metadata")
    return true
  elseif record.__ruiInterruptOriginalDirect == false then
    MarkExcluded(record, "explicit metadata")
    return false
  end

  if not CandidateRecord(record) then return false end

  local text, scanned = ReadTooltip(record, bookIndex)
  local tooltipCooldown = CooldownFromTooltip(text)
  local cooldown = tonumber(record.cooldownHint) or 0
  if cooldown <= 0 and tooltipCooldown > 0 then
    cooldown = tooltipCooldown
    record.cooldownHint = tooltipCooldown
  end

  if IsStrictDirectTooltip(text) then
    if cooldown > 45 then
      MarkExcluded(record, "long-cooldown disruption, not the ordinary kick")
      return false
    end
    MarkDirect(record, "verified school-lock tooltip")
    return true
  end

  local originalCategory = Normalize(record.__ruiInterruptOriginalCategory)
  if originalCategory == "interrupt" then
    if cooldown > 45 then
      MarkExcluded(record, "long-cooldown disruption")
    elseif scanned and IsControlOnlyTooltip(text) then
      MarkExcluded(record, "control/silence without a direct school lock")
    elseif scanned and text ~= "" then
      MarkExcluded(record, "tooltip does not describe a direct school lock")
    else
      -- Some Ascension custom hyperlinks are unavailable until learned. Keep
      -- only short catalogue entries as a conservative fallback.
      MarkDirect(record, "short interrupt catalogue fallback")
      return true
    end
    return false
  end
  return false
end

local function RecordNameIndex(database)
  local result = {}
  for _, record in ipairs(database.spells or {}) do
    result[Normalize(record.name)] = record
    for _, alias in ipairs(record.aliases or {}) do result[Normalize(alias)] = record end
  end
  return result
end

local function SpellbookRecords()
  local records = {}
  if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function" then return records end
  if type(GetSpellBookItemInfo) ~= "function" then return records end

  local bookType = BOOKTYPE_SPELL or "spell"
  local totalTabs = tonumber(GetNumSpellTabs()) or 0
  for tab = 1, totalTabs do
    local _, _, offset, count = GetSpellTabInfo(tab)
    offset, count = tonumber(offset) or 0, tonumber(count) or 0
    for index = offset + 1, offset + count do
      local itemType, spellID = GetSpellBookItemInfo(index, bookType)
      spellID = tonumber(spellID)
      if itemType == "SPELL" or itemType == "FUTURESPELL" or spellID then
        local name, rank
        if type(GetSpellBookItemName) == "function" then name, rank = GetSpellBookItemName(index, bookType) end
        if (not name or name == "") and spellID and type(GetSpellInfo) == "function" then name, rank = GetSpellInfo(spellID) end
        if name and name ~= "" then
          records[#records + 1] = {index=index, id=spellID, name=name, rank=rank}
        end
      end
    end
  end
  return records
end

local function AddOrPromoteLearnedInterrupt(database, nameIndex, learned)
  local probe = {name=learned.name, id=learned.id, category="utility", trackCooldown=true}
  local text, scanned = ReadTooltip(probe, learned.index)
  if not scanned or not IsStrictDirectTooltip(text) or ContainsAny(text, AREA_PHRASES) then return false end

  local cooldown = CooldownFromTooltip(text)
  if cooldown > 45 then return false end
  if cooldown <= 0 and learned.id and type(GetSpellBaseCooldown) == "function" then
    local ok, milliseconds = pcall(GetSpellBaseCooldown, learned.id)
    if ok and tonumber(milliseconds) and tonumber(milliseconds) > 0 then cooldown = tonumber(milliseconds) / 1000 end
  end

  local record = nameIndex[Normalize(learned.name)]
  if record then
    if learned.id and tonumber(record.id) ~= tonumber(learned.id) then
      record.knownRankIDs = record.knownRankIDs or {}
      local found = false
      for _, spellID in ipairs(record.knownRankIDs) do if tonumber(spellID) == tonumber(learned.id) then found = true break end end
      if not found then record.knownRankIDs[#record.knownRankIDs + 1] = learned.id end
    end
    if (tonumber(record.cooldownHint) or 0) <= 0 and cooldown > 0 then record.cooldownHint = cooldown end
    MarkDirect(record, "learned spellbook school-lock")
    return true
  end

  record = {
    name = learned.name,
    id = learned.id,
    category = "interrupt",
    hudRow = "utility",
    order = 95,
    trackCooldown = true,
    partyCooldown = true,
    cooldownCategory = "interrupt",
    directInterrupt = true,
    primaryInterrupt = true,
    cooldownHint = cooldown,
    sourceTab = "RuntimeSpellbook",
    runtimeDiscovered = true,
    partyInterruptCurated = "learned spellbook school-lock",
  }
  database.spells[#database.spells + 1] = record
  nameIndex[Normalize(record.name)] = record
  return true
end

local function SelectPrimary(database)
  local candidates = {}
  for _, record in ipairs(database.spells or {}) do
    if record.directInterrupt == true and not IsArcaneTorrent(record) then candidates[#candidates + 1] = record end
  end
  table.sort(candidates, function(left, right)
    local leftExplicit = left.__ruiInterruptOriginalPrimary == true
    local rightExplicit = right.__ruiInterruptOriginalPrimary == true
    if leftExplicit ~= rightExplicit then return leftExplicit end
    local leftCooldown = tonumber(left.cooldownHint) or 9999
    local rightCooldown = tonumber(right.cooldownHint) or 9999
    if leftCooldown <= 0 then leftCooldown = 9999 end
    if rightCooldown <= 0 then rightCooldown = 9999 end
    if leftCooldown ~= rightCooldown then return leftCooldown < rightCooldown end
    local leftOrder = tonumber(left.order) or 9999
    local rightOrder = tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    return tostring(left.name) < tostring(right.name)
  end)
  for index, record in ipairs(candidates) do record.primaryInterrupt = index == 1 end
end

local function CurateAllRecords()
  local detectedClass = RUI.GetDetectedClass and RUI:GetDetectedClass() or nil
  for className, database in pairs(RUI.spellDatabase or {}) do
    database.spells = database.spells or {}
    for _, record in ipairs(database.spells) do CurateRecord(record, nil) end

    if className == detectedClass then
      local nameIndex = RecordNameIndex(database)
      for _, learned in ipairs(SpellbookRecords()) do AddOrPromoteLearnedInterrupt(database, nameIndex, learned) end
    end
    SelectPrimary(database)
  end
  curated = true
  RUI._partyInterruptCurationRevision = revision
  return true
end

function RUI:CuratePartyInterruptDefinitions()
  local result = CurateAllRecords()
  if type(self.RefreshPartyUtilityCombatLogIndex) == "function" then self:RefreshPartyUtilityCombatLogIndex() end
  return result
end

function RUI:GetCuratedPartyInterrupts(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local database = self.spellDatabase and self.spellDatabase[className]
  local included, excluded = {}, {}
  for _, record in ipairs(database and database.spells or {}) do
    if record.directInterrupt == true and not IsArcaneTorrent(record) then
      included[#included + 1] = record
    elseif Normalize(record.__ruiInterruptOriginalCategory) == "interrupt" and record.directInterrupt == false then
      excluded[#excluded + 1] = record
    end
  end
  return included, excluded
end

function RUI:InitializePartyUtilityTracker(...)
  CurateAllRecords()
  return originalInitialize(self, ...)
end

SLASH_RUIPARTYINTERRUPTLIST1 = "/ruiinterruptlist"
SlashCmdList.RUIPARTYINTERRUPTLIST = function()
  CurateAllRecords()
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass() or "Unknown"
  local included, excluded = RUI:GetCuratedPartyInterrupts(className)
  RUI:Print("Direct interrupts for " .. tostring(className) .. ":")
  if #included == 0 then RUI:Print("None detected.") end
  for _, record in ipairs(included) do
    RUI:Print(string.format("+ %s (%s, %.1fs)%s", tostring(record.name), tostring(record.id or "name"), tonumber(record.cooldownHint) or 0, record.primaryInterrupt and " PRIMARY" or ""))
  end
  for _, record in ipairs(excluded) do
    RUI:Print("- Excluded " .. tostring(record.name) .. ": " .. tostring(record.partyInterruptExclusion or "not direct"))
  end
end

local events = CreateFrame("Frame")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED", "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
}) do pcall(events.RegisterEvent, events, eventName) end

events:SetScript("OnEvent", function()
  RUI:After(0.20, function()
    CurateAllRecords()
    if curated and type(RUI.RefreshPartyUtility) == "function" then RUI:RefreshPartyUtility() end
    if type(RUI.RefreshPartyUtilityCombatLogIndex) == "function" then RUI:RefreshPartyUtilityCombatLogIndex() end
  end)
end)

RUI._partyInterruptCurationLoaded = true
