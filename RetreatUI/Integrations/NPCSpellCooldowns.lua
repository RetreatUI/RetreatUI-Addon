local RUI = RetreatUI

local MAX_ICONS = 4
local ICON_SIZE = 18
local ICON_SPACING = 2
local UNKNOWN_DISPLAY = 4
local UPDATE_INTERVAL = 0.10

local activeContainers = {}
local lastCastBySource = {}
local spellIndexByNPC
local updateElapsed = 0
local updater
local initialized = false

local function Lower(value)
  return type(value) == "string" and string.lower(value) or nil
end

local function GetNPCIDFromGUID(guid)
  if type(guid) ~= "string" or guid == "" then return nil end

  local modern = guid:match("^[^%-]+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if modern then return tonumber(modern) end

  -- Project Ascension's legacy GUID format, matching MobSpells' own lookup.
  if #guid >= 10 then
    local legacy = tonumber(guid:sub(-10, -7), 16)
    if legacy and legacy > 0 then return legacy end
  end
  return nil
end

local function BuildSpellIndex()
  spellIndexByNPC = {}
  if type(MobSpellsDB) ~= "table" then return spellIndexByNPC end

  for npcID, records in pairs(MobSpellsDB) do
    if type(records) == "table" then
      local index = {ids = {}, names = {}}
      for _, record in ipairs(records) do
        local spellID = type(record) == "table" and tonumber(record[1]) or nil
        if spellID and spellID > 0 then
          index.ids[spellID] = true
          local spellName = GetSpellInfo and GetSpellInfo(spellID)
          local lowered = Lower(spellName)
          if lowered then index.names[lowered] = spellID end
        end
      end
      spellIndexByNPC[tonumber(npcID) or npcID] = index
    end
  end
  return spellIndexByNPC
end

local function IsMobSpell(npcID, spellID, spellName)
  if not spellIndexByNPC then BuildSpellIndex() end
  local index = spellIndexByNPC and spellIndexByNPC[npcID]
  if not index then return false end
  if spellID and index.ids[spellID] then return true end
  local lowered = Lower(spellName)
  return lowered and index.names[lowered] ~= nil or false
end

local function GetCooldownStore()
  local db = RUI:EnsureDB()
  db.integrations.mobSpellCooldowns = db.integrations.mobSpellCooldowns or {}
  return db.integrations.mobSpellCooldowns
end

local function GetSpellKey(spellID, spellName)
  local lowered = Lower(spellName)
  if lowered and lowered ~= "" then return lowered end
  return tostring(spellID or 0)
end

local function GetKnownCooldown(npcID, spellID, spellName)
  if type(GetSpellBaseCooldown) == "function" and spellID then
    local ok, milliseconds = pcall(GetSpellBaseCooldown, spellID)
    milliseconds = ok and tonumber(milliseconds) or nil
    if milliseconds and milliseconds >= 1500 and milliseconds <= 600000 then
      return milliseconds / 1000, "api"
    end
  end

  local npcStore = GetCooldownStore()[tostring(npcID)]
  local record = npcStore and npcStore[GetSpellKey(spellID, spellName)]
  local duration = type(record) == "table" and tonumber(record.duration) or tonumber(record)
  if duration and duration >= 1.5 and duration <= 600 then return duration, "learned" end
  return nil, nil
end

local function LearnCooldown(npcID, spellID, spellName, interval)
  interval = tonumber(interval)
  if not interval or interval < 2 or interval > 180 then return nil end

  local store = GetCooldownStore()
  local npcKey = tostring(npcID)
  store[npcKey] = store[npcKey] or {}
  local key = GetSpellKey(spellID, spellName)
  local old = store[npcKey][key]
  local oldDuration = type(old) == "table" and tonumber(old.duration) or tonumber(old)

  -- NPC AI may delay casts, so the shortest observed repeat is the best estimate.
  local learned = oldDuration and math.min(oldDuration, interval) or interval
  learned = math.floor(learned * 2 + 0.5) / 2
  store[npcKey][key] = {
    duration = learned,
    spellID = spellID,
    spellName = spellName,
    learnedAt = time and time() or 0,
  }
  return learned
end

local function CreateBorder(frame)
  local border = frame:CreateTexture(nil, "BACKGROUND")
  border:SetTexture("Interface\\Buttons\\WHITE8X8")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetVertexColor(0, 0, 0, 1)
  return border
end

local function CreateIcon(container, index)
  local frame = CreateFrame("Frame", nil, container)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:EnableMouse(false)
  frame:SetPoint("LEFT", container, "LEFT", (index - 1) * (ICON_SIZE + ICON_SPACING), 0)
  frame.border = CreateBorder(frame)

  frame.texture = frame:CreateTexture(nil, "ARTWORK")
  frame.texture:SetAllPoints()
  frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  frame.shade = frame:CreateTexture(nil, "OVERLAY")
  frame.shade:SetAllPoints()
  frame.shade:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.shade:SetVertexColor(0, 0, 0, 0.48)

  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER", 0, 0)
  RUI:ApplyFont(frame.text, 9, "OUTLINE")
  frame.text:SetTextColor(1, 1, 1, 1)

  frame:Hide()
  return frame
end

local function ClearContainer(container)
  if not container then return end
  container.guid = nil
  container.entries = {}
  for _, icon in ipairs(container.icons or {}) do
    icon:Hide()
    icon.spellKey = nil
  end
  container:Hide()
  activeContainers[container] = nil
  if updater and next(activeContainers) == nil then updater:Hide() end
end

local function GetContainer(nameplate, guid)
  if not nameplate then return nil end
  local myPlate = nameplate.myPlate or nameplate.TurboPlate
  if not myPlate then return nil end

  local container = myPlate.retreatNpcCooldowns
  if not container then
    container = CreateFrame("Frame", nil, myPlate)
    container:SetSize(MAX_ICONS * ICON_SIZE + (MAX_ICONS - 1) * ICON_SPACING, ICON_SIZE)
    container:EnableMouse(false)
    container:SetFrameLevel(myPlate:GetFrameLevel() + 8)
    container.icons = {}
    container.entries = {}
    for index = 1, MAX_ICONS do
      container.icons[index] = CreateIcon(container, index)
    end
    myPlate.retreatNpcCooldowns = container
  end

  local anchor = myPlate.hp or myPlate.castbar or myPlate
  container:ClearAllPoints()
  container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)

  if container.guid ~= guid then
    ClearContainer(container)
    container.guid = guid
  end
  return container
end

local function FindNameplateByGUID(guid)
  if not guid or not C_NamePlateManager or type(C_NamePlateManager.EnumerateActiveNamePlates) ~= "function" then return nil end
  for nameplate in C_NamePlateManager.EnumerateActiveNamePlates() do
    local unit = nameplate and nameplate._unit
    if unit and UnitGUID(unit) == guid then return nameplate end
  end
  return nil
end

local function SortEntries(container)
  table.sort(container.entries, function(a, b)
    return (a.started or 0) > (b.started or 0)
  end)
  while #container.entries > MAX_ICONS do table.remove(container.entries) end
end

local function DisplaySpell(nameplate, guid, spellID, spellName, duration)
  duration = tonumber(duration)
  if not duration or duration < 1.5 then return end
  local _, _, texture = GetSpellInfo and GetSpellInfo(spellID or spellName)
  if type(texture) ~= "string" or texture == "" or string.lower(texture):find("questionmark", 1, true) then return end
  local container = GetContainer(nameplate, guid)
  if not container then return end

  local now = GetTime()
  local key = GetSpellKey(spellID, spellName)
  local entry
  for _, existing in ipairs(container.entries) do
    if existing.key == key then
      entry = existing
      break
    end
  end
  if not entry then
    entry = {key = key}
    table.insert(container.entries, entry)
  end

  entry.spellID = spellID
  entry.spellName = spellName
  entry.started = now
  entry.duration = duration
  entry.expires = duration and (now + duration) or (now + UNKNOWN_DISPLAY)
  entry.unknown = false

  SortEntries(container)
  activeContainers[container] = true
  container:Show()
  if updater then updater:Show() end
end

local function RefreshContainer(container, now)
  if not container or not container.entries then return end

  for index = #container.entries, 1, -1 do
    local entry = container.entries[index]
    if not entry.expires or entry.expires <= now then table.remove(container.entries, index) end
  end

  if #container.entries == 0 then
    container:Hide()
    activeContainers[container] = nil
    return
  end

  SortEntries(container)
  for index = 1, MAX_ICONS do
    local icon = container.icons[index]
    local entry = container.entries[index]
    if entry then
      local _, _, texture = GetSpellInfo(entry.spellID or 0)
      icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
      icon.spellKey = entry.key
      if texture then
        local remain = math.max(0, entry.expires - now)
        if remain >= 60 then
          icon.text:SetText(math.ceil(remain / 60) .. "m")
        elseif remain >= 10 then
          icon.text:SetText(tostring(math.ceil(remain)))
        else
          icon.text:SetText(string.format("%.1f", remain))
        end
        local progress = entry.duration and remain / entry.duration or 0
        icon.shade:SetAlpha(0.2 + (1 - progress) * 0.45)
        icon:Show()
      end
    else
      icon:Hide()
      icon.spellKey = nil
    end
  end
end

updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function(self, elapsed)
  updateElapsed = updateElapsed + elapsed
  if updateElapsed < UPDATE_INTERVAL then return end
  updateElapsed = 0
  local now = GetTime()
  for container in pairs(activeContainers) do RefreshContainer(container, now) end
  if next(activeContainers) == nil then self:Hide() end
end)

local function ReadCombatLog(...)
  if type(CombatLogGetCurrentEventInfo) == "function" then
    return CombatLogGetCurrentEventInfo()
  end
  return ...
end

local function HandleCombatLog(...)
  -- Avoid allocating a temporary table for every combat-log event. Boss deaths
  -- can dispatch a large burst of events, and the old allocation path amplified
  -- the resulting frame spike.
  local a1, subevent, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 = ReadCombatLog(...)

  if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "SPELL_INSTAKILL" then
    local destGUID = type(a3) == "boolean" and a8 or a6
    if destGUID then lastCastBySource[destGUID] = nil end
    return
  end

  if subevent ~= "SPELL_CAST_SUCCESS" then return end

  local sourceGUID, spellID, spellName
  if type(a3) == "boolean" then
    sourceGUID = a4
    spellID = tonumber(a12)
    spellName = a13
  else
    sourceGUID = a3
    spellID = tonumber(a9)
    spellName = a10
  end
  if not sourceGUID or not spellID then return end

  local npcID = GetNPCIDFromGUID(sourceGUID)
  if not npcID or not IsMobSpell(npcID, spellID, spellName) then return end

  local nameplate = FindNameplateByGUID(sourceGUID)
  if not nameplate then return end

  local now = GetTime()
  local key = GetSpellKey(spellID, spellName)
  lastCastBySource[sourceGUID] = lastCastBySource[sourceGUID] or {}
  local previous = lastCastBySource[sourceGUID][key]
  lastCastBySource[sourceGUID][key] = now

  local duration = select(1, GetKnownCooldown(npcID, spellID, spellName))
  if previous and now - previous > 1 then
    local learned = LearnCooldown(npcID, spellID, spellName, now - previous)
    duration = learned or duration
  end

  DisplaySpell(nameplate, sourceGUID, spellID, spellName, duration)
end

function RUI:InitializeNPCSpellCooldowns()
  if initialized then return true, "NPC spell cooldown tracker already enabled" end
  if type(MobSpellsDB) ~= "table" then return false, "MobSpells is not loaded" end
  BuildSpellIndex()
  initialized = true
  local db = self:EnsureDB()
  db.integrations.npcSpellCooldowns = db.integrations.npcSpellCooldowns or {}
  db.integrations.npcSpellCooldowns.enabled = true
  db.integrations.npcSpellCooldowns.version = self.version
  return true, "NPC spell cooldown tracker enabled"
end

function RUI:RefreshNPCSpellCooldowns()
  BuildSpellIndex()
  if not C_NamePlateManager or type(C_NamePlateManager.EnumerateActiveNamePlates) ~= "function" then return false end
  for nameplate in C_NamePlateManager.EnumerateActiveNamePlates() do
    local guid = nameplate._unit and UnitGUID(nameplate._unit)
    local container = nameplate.myPlate and nameplate.myPlate.retreatNpcCooldowns
    if container and container.guid ~= guid then ClearContainer(container) end
  end
  return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog(...)
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    RUI:ClearTable(lastCastBySource)
    for container in pairs(activeContainers) do ClearContainer(container) end
  end

  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= "MobSpells" and addonName ~= "TurboPlates" then return end
  end

  RUI:After(0.8, function()
    if type(MobSpellsDB) == "table" and type(TurboPlatesDB) == "table" then
      RUI:InitializeNPCSpellCooldowns()
    end
  end)
end)
