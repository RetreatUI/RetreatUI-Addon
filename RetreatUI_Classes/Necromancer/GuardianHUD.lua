local RUI = RetreatUI
if not RUI then return end

-- Necromancer Guardian HUD.
-- Guardian classification data and several runtime ideas are derived from
-- Libellus Leti by Mortuus (LtGenZombie), used under the MIT License.
-- RetreatUI keeps its own layout, namespace, lifecycle and visual system.

local GuardianHUD = {}
RUI.NecromancerGuardianHUD = GuardianHUD

local MAX_HEALTH_ROWS = 40
local HEALTH_ROW_HEIGHT = 16
local DEFAULT_POINT = {point="TOP", relativePoint="CENTER", x=-500, y=-18}
local NAMEPLATE_CVARS = {
  "nameplateShowFriends",
  "nameplateShowFriendlyGuardians",
  "nameplateShowFriendlyPets",
}

local function GuardianDB()
  local db = RUI.EnsureDB and RUI:EnsureDB() or RetreatUIDB
  if type(db) ~= "table" then
    RetreatUIDB = RetreatUIDB or {}
    db = RetreatUIDB
  end
  db.class = db.class or {}
  db.class.Necromancer = db.class.Necromancer or {}
  db.class.Necromancer.guardianHUD = db.class.Necromancer.guardianHUD or {}
  local guardianDB = db.class.Necromancer.guardianHUD
  if guardianDB.locked == nil then guardianDB.locked = false end
  return guardianDB
end

local function SafeGetCVar(name)
  if not GetCVar then return nil end
  local ok, value = pcall(GetCVar, name)
  if ok and value ~= nil then return tostring(value) end
  return nil
end

local function SafeSetCVar(name, value)
  if not SetCVar or value == nil then return false end
  return pcall(SetCVar, name, tostring(value))
end

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function Now()
  return GetTime and GetTime() or 0
end

local MINION_TYPES = {
  ghoul = {
    label = "Ghoul", short = "GHOUL",
    icon = "Interface\\Icons\\Spell_Shadow_AnimateDead",
    names = {"Ghoul", "Geist", "Risen", "Gurgling Horror", "Putrid Ghoul", "Rotling"},
    auraIDs = {[680761]=true, [805019]=true},
    summonIDs = {[500971]=true, [45850]=true, [45861]=true},
    learned = {"Raise: Ghoul"},
  },
  abomination = {
    label = "Abomination", short = "ABOM",
    icon = "Interface\\Icons\\Ability_Creature_Disease_02",
    names = {"Abomination", "Flesh Giant", "Unholy Colossus", "Flesh Golem", "Decaying Colossus"},
    auraIDs = {[680760]=true, [685010]=true, [805017]=true},
    summonIDs = {[42650]=true, [500989]=true, [500335]=true, [803139]=true},
    learned = {"Raise: Abomination", "Raise: Unholy Colossus", "Raise: Flesh Golem", "Raise: Decaying Colossus"},
  },
  crypt_fiend = {
    label = "Crypt Fiend", short = "FIEND",
    icon = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
    names = {"Crypt Fiend", "Crypt Keeper"},
    auraIDs = {[712309]=true, [800034]=true},
    summonIDs = {[504859]=true},
    learned = {"Raise: Crypt Fiend"},
  },
  banshee = {
    label = "Banshee", short = "BANSHEE",
    icon = "Interface\\Icons\\Spell_Shadow_SummonBanshee",
    names = {"Banshee"},
    auraIDs = {},
    summonIDs = {[504861]=true},
    learned = {"Raise: Banshee"},
  },
  skeletal_warrior_lesser = {
    label = "Lesser Skeletal Warrior", short = "L.SKEL",
    icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",
    names = {"Lesser Skeletal Warrior", "Brittle Skeleton"},
    auraIDs = {[805016]=true},
    summonIDs = {[500970]=true},
    learned = {"Raise: Lesser Skeletal Warrior", "Raise: Brittle Skeleton"},
  },
  skeletal_warrior_greater = {
    label = "Greater Skeletal Warrior", short = "G.SKEL",
    icon = "Interface\\Icons\\Spell_DeathKnight_ArmyOfTheDead",
    names = {"Greater Skeletal Warrior"},
    auraIDs = {[807927]=true},
    summonIDs = {[504901]=true},
    learned = {"Raise: Greater Skeletal Warrior"},
  },
  skeletal_rogue = {
    label = "Skeletal Rogue", short = "ROGUE",
    icon = "Interface\\Icons\\Ability_Stealth",
    names = {"Skeletal Rogue", "Crypt Leaper"},
    auraIDs = {[805021]=true},
    summonIDs = {[500969]=true},
    learned = {"Raise: Skeletal Rogue", "Raise: Crypt Leaper"},
  },
  bone_wraith = {
    label = "Bone Wraith", short = "WRAITH",
    icon = "Interface\\Icons\\Spell_Shadow_ShadesOfDarkness",
    names = {"Bone Wraith", "Knight of Decay"},
    auraIDs = {},
    summonIDs = {[805032]=true, [712317]=true},
    learned = {"Animate: Bone Wraith", "Animate: Knight of Decay"},
    duration = 60,
  },
  skeletal_archer = {
    label = "Skeletal Archer", short = "ARCHER",
    icon = "Interface\\Icons\\Ability_Hunter_ImprovedSteadyShot",
    names = {"Skeletal Archer", "Grave Mage", "Putrid Ghoul"},
    auraIDs = {},
    summonIDs = {[500330]=true, [500331]=true, [500332]=true, [805040]=true},
    learned = {"Animate: Skeletal Archer", "Animate: Putrid Ghoul"},
    duration = 18,
  },
  tomb_king = {
    label = "Tomb King", short = "KING",
    icon = "Interface\\Icons\\Achievement_Boss_KelThuzad_01",
    names = {"Tomb King"},
    auraIDs = {},
    summonIDs = {[805044]=true, [355744]=true},
    learned = {"Animate: Tomb King"},
    duration = 15,
  },
  plaguefather = {
    label = "Plaguefather", short = "PLAGUE",
    icon = "Interface\\Icons\\Spell_Shadow_PlagueCloud",
    names = {"Plaguefather"},
    auraIDs = {},
    summonIDs = {[805048]=true},
    learned = {"Animate: Plaguefather"},
    duration = 60,
  },
  frost_wyrm = {
    label = "Frost Wyrm", short = "WYRM",
    icon = "Interface\\Icons\\Spell_DeathKnight_SummonDeathCharger",
    names = {"Frost Wyrm"},
    auraIDs = {},
    summonIDs = {[805428]=true},
    learned = {"Animate: Frost Wyrm", "Shatterfrost"},
    duration = 60,
  },
  lesser_zombie = {
    label = "Lesser Zombie", short = "ZOMBIE",
    icon = "Interface\\Icons\\Achievement_Character_Undead_Male",
    names = {"Lesser Zombie", "Zombie"},
    auraIDs = {},
    summonIDs = {},
    learned = {"Unrelenting Army"},
    duration = 15,
    zombie = true,
  },
}

local MINION_ORDER = {
  "abomination", "ghoul", "crypt_fiend", "banshee",
  "skeletal_warrior_greater", "skeletal_warrior_lesser", "skeletal_rogue",
  "bone_wraith", "tomb_king", "skeletal_archer", "plaguefather", "frost_wyrm",
}

local TYPE_ORDER = {}
local SPELL_TO_TYPE = {}
for index, minionID in ipairs(MINION_ORDER) do TYPE_ORDER[minionID] = index end
TYPE_ORDER.lesser_zombie = 999
for minionID, definition in pairs(MINION_TYPES) do
  for spellID in pairs(definition.summonIDs or {}) do SPELL_TO_TYPE[spellID] = minionID end
end

local ANIMATION_SPELLS = {
  "Raise: Ghoul", "Raise: Abomination", "Raise: Crypt Fiend", "Raise: Banshee",
  "Raise: Lesser Skeletal Warrior", "Raise: Greater Skeletal Warrior", "Raise: Skeletal Rogue",
  "Animate: Bone Wraith", "Animate: Knight of Decay", "Animate: Skeletal Archer",
  "Animate: Putrid Ghoul", "Animate: Tomb King", "Animate: Plaguefather",
  "Animate: Frost Wyrm", "Shatterfrost", "Unrelenting Army",
}

local function MatchesName(name, patterns)
  local normalized = Normalize(name)
  if normalized == "" then return false end
  for _, pattern in ipairs(patterns or {}) do
    local wanted = Normalize(pattern)
    if normalized == wanted or normalized:find(wanted, 1, true) then return true end
  end
  return false
end

local function ClassifyName(name)
  if not name then return nil end
  -- Most specific names first so broad Ghoul/Zombie patterns do not steal matches.
  local classifyOrder = {
    "skeletal_warrior_greater", "skeletal_warrior_lesser", "skeletal_rogue",
    "crypt_fiend", "banshee", "skeletal_archer", "bone_wraith", "tomb_king",
    "plaguefather", "frost_wyrm", "abomination", "lesser_zombie", "ghoul",
  }
  for _, minionID in ipairs(classifyOrder) do
    if MatchesName(name, MINION_TYPES[minionID].names) then return minionID end
  end
  return nil
end

local function ClassifySummon(spellID, spellName, destinationName)
  spellID = tonumber(spellID)
  if spellID and SPELL_TO_TYPE[spellID] then return SPELL_TO_TYPE[spellID] end
  local fromDestination = ClassifyName(destinationName)
  if fromDestination then return fromDestination end
  for minionID, definition in pairs(MINION_TYPES) do
    if MatchesName(spellName, definition.learned) or MatchesName(spellName, definition.names) then
      return minionID
    end
  end
  return nil
end

local function ParseCombatLogValues(values)
  if type(values) ~= "table" then return nil end
  local tokenIndex
  for index = 1, math.min(#values, 6) do
    local value = values[index]
    if type(value) == "string" and (
      value == "SPELL_SUMMON" or value == "SPELL_CREATE" or
      value == "UNIT_DIED" or value == "UNIT_DESTROYED" or value == "PARTY_KILL"
    ) then
      tokenIndex = index
      break
    end
  end
  if not tokenIndex then return nil end

  local eventType = values[tokenIndex]
  local index = tokenIndex + 1
  if type(values[index]) == "boolean" then index = index + 1 end

  local sourceGUID = values[index]
  local sourceName = values[index + 1]
  index = index + 3 -- GUID, name, flags
  if type(values[index]) == "number" and type(values[index + 1]) == "string" then
    index = index + 1 -- source raid flags on newer CLEU layouts
  end

  local destinationGUID = values[index]
  local destinationName = values[index + 1]
  index = index + 3 -- GUID, name, flags
  if type(values[index]) == "number" and (type(values[index + 1]) == "number" or type(values[index + 1]) == "nil") then
    index = index + 1 -- destination raid flags
  end

  local spellID, spellName
  if eventType == "SPELL_SUMMON" or eventType == "SPELL_CREATE" then
    spellID = tonumber(values[index])
    spellName = values[index + 1]
  end

  return {
    eventType = eventType,
    sourceGUID = sourceGUID,
    sourceName = sourceName,
    destinationGUID = destinationGUID,
    destinationName = destinationName,
    spellID = spellID,
    spellName = spellName,
  }
end

local function ReadCombatLog(...)
  if CombatLogGetCurrentEventInfo then
    local values = {CombatLogGetCurrentEventInfo()}
    local parsed = ParseCombatLogValues(values)
    if parsed then return parsed end
  end
  return ParseCombatLogValues({...})
end


local function ResolveMinionIcon(definition)
  if definition and GetSpellTexture then
    for spellID in pairs(definition.summonIDs or {}) do
      local ok, texture = pcall(GetSpellTexture, spellID)
      if ok and texture and texture ~= "" then return texture end
    end
  end
  return definition and definition.icon or "Interface\\Icons\\Spell_Shadow_AnimateDead"
end

local function StatusBarTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function FormatHealth(value)
  value = math.max(0, math.floor(tonumber(value) or 0))
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 10000 then return string.format("%.1fk", value / 1000) end
  return tostring(value)
end

local Tracker = {}
Tracker.__index = Tracker

function Tracker:SetDefaultPosition()
  self.frame:ClearAllPoints()
  self.frame:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relativePoint, DEFAULT_POINT.x, DEFAULT_POINT.y)
end

function Tracker:RestorePosition()
  local position = GuardianDB().position
  if type(position) == "table" and position.point and position.relativePoint then
    self.frame:ClearAllPoints()
    self.frame:SetPoint(position.point, UIParent, position.relativePoint, tonumber(position.x) or 0, tonumber(position.y) or 0)
  else
    self:SetDefaultPosition()
  end
end

function Tracker:SavePosition()
  local point, _, relativePoint, x, y = self.frame:GetPoint(1)
  if not point then return end
  GuardianDB().position = {
    point=point, relativePoint=relativePoint or point,
    x=tonumber(x) or 0, y=tonumber(y) or 0,
  }
end

function Tracker:ResetPosition()
  GuardianDB().position = nil
  self:SetDefaultPosition()
end

function Tracker:IsLocked()
  return GuardianDB().locked == true
end

function Tracker:UpdateLockVisual()
  local locked = self:IsLocked()
  if self.lockButton and self.lockButton.text then
    self.lockButton.text:SetText(locked and "L" or "U")
  end
  if self.dragText then
    if locked then self.dragText:Hide() else self.dragText:Show() end
  end
  if self.dragHandle then
    if locked then self.dragHandle:Hide() else self.dragHandle:Show() end
  end
end

function Tracker:RestoreHiddenPlateFrames()
  for frame, alpha in pairs(self.hiddenPlateAlpha or {}) do
    if frame and frame.SetAlpha then pcall(frame.SetAlpha, frame, alpha) end
  end
  self.hiddenPlateAlpha = {}
end

function Tracker:CloakPlateFrame(frame)
  if not frame or not frame.SetAlpha then return end
  self.hiddenPlateAlpha = self.hiddenPlateAlpha or {}
  if self.hiddenPlateAlpha[frame] == nil then
    local alpha = frame.GetAlpha and frame:GetAlpha() or 1
    self.hiddenPlateAlpha[frame] = tonumber(alpha) or 1
  end
  frame:SetAlpha(0)
end

function Tracker:CloakForcedFriendlyNameplates()
  if not self.hideForcedFriendlyPlates then return end
  local activeFrames = {}
  local function cloak(frame)
    if not frame then return end
    activeFrames[frame] = true
    self:CloakPlateFrame(frame)
  end

  for index = 1, 40 do
    local unit = "nameplate" .. tostring(index)
    local exists = (UnitName and UnitName(unit)) or (UnitExists and UnitExists(unit))
    local hostile = UnitCanAttack and UnitCanAttack("player", unit)
    if exists and not hostile then
      local plate
      if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, value = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then plate = value end
      end
      plate = plate or _G["NamePlate" .. tostring(index)]
      cloak(plate)
      if plate and plate.UnitFrame then cloak(plate.UnitFrame) end
      cloak(_G["NamePlate" .. tostring(index) .. "UnitFrame"])
    end
  end

  -- Ascension recycles nameplate frames. Restore any frame that is no longer
  -- attached to a friendly unit so an enemy plate can never inherit alpha 0.
  local restore = {}
  for frame in pairs(self.hiddenPlateAlpha or {}) do
    if not activeFrames[frame] then restore[#restore + 1] = frame end
  end
  for _, frame in ipairs(restore) do
    local alpha = self.hiddenPlateAlpha[frame]
    if frame and frame.SetAlpha then pcall(frame.SetAlpha, frame, alpha) end
    self.hiddenPlateAlpha[frame] = nil
  end
end

function Tracker:RestorePendingNameplateBackup()
  local db = GuardianDB()
  local pending = db.pendingNameplateRestore
  if type(pending) ~= "table" then return end
  for name, value in pairs(pending) do SafeSetCVar(name, value) end
  db.pendingNameplateRestore = nil
end

function Tracker:EnableNameplateSupport()
  if self.nameplateBackup then
    for _, name in ipairs(NAMEPLATE_CVARS) do
      if SafeGetCVar(name) ~= nil then SafeSetCVar(name, "1") end
    end
    self:CloakForcedFriendlyNameplates()
    return
  end

  -- If WoW closed while the tracker was active, restore the user's original
  -- values before taking a fresh backup for this session.
  self:RestorePendingNameplateBackup()

  local backup = {}
  local changed = false
  local friendsBefore = SafeGetCVar("nameplateShowFriends")
  for _, name in ipairs(NAMEPLATE_CVARS) do
    local value = SafeGetCVar(name)
    if value ~= nil then
      backup[name] = value
      if value ~= "1" then
        SafeSetCVar(name, "1")
        changed = true
      end
    end
  end

  self.nameplateBackup = backup
  self.hideForcedFriendlyPlates = friendsBefore ~= nil and friendsBefore ~= "1"
  if next(backup) then GuardianDB().pendingNameplateRestore = backup end
  if changed then self.nextRefresh = 0 end
  self:CloakForcedFriendlyNameplates()
end

function Tracker:RestoreNameplateSupport()
  self:RestoreHiddenPlateFrames()
  for name, value in pairs(self.nameplateBackup or {}) do SafeSetCVar(name, value) end
  self.nameplateBackup = nil
  self.hideForcedFriendlyPlates = false
  GuardianDB().pendingNameplateRestore = nil
end

function Tracker:CreateCountIcon(index)
  local icon = CreateFrame("Frame", "RetreatUINecromancerGuardianCount" .. tostring(index), self.frame)
  icon:SetSize(20, 20)
  RUI:SkinFrame(icon, {0.01,0.02,0.01,0.96}, {0,0,0,1})

  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", 1, -1)
  icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
  icon.texture:SetTexCoord(0.08,0.92,0.08,0.92)

  icon.count = icon:CreateFontString(nil, "OVERLAY")
  icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
  RUI:ApplyFont(icon.count, 9, "OUTLINE")
  icon.count:SetTextColor(1,1,1,1)

  icon:EnableMouse(true)
  icon:SetScript("OnEnter", function(frame)
    if not frame.definition then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(frame.definition.label or "Guardian", 0.65, 1.0, 0.35)
    GameTooltip:AddLine(tostring(frame.amount or 0) .. " active", 1, 1, 1)
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  icon:Hide()
  self.countIcons[index] = icon
  return icon
end

function Tracker:CreateHealthRow(index)
  local row = CreateFrame("StatusBar", "RetreatUINecromancerGuardianHealth" .. tostring(index), self.frame)
  row:SetSize(178, 14)
  row:SetStatusBarTexture(StatusBarTexture())
  row:SetMinMaxValues(0, 1)
  row:SetValue(1)
  RUI:SkinFrame(row, {0.012,0.018,0.012,0.94}, {0,0,0,1})

  row.icon = row:CreateTexture(nil, "OVERLAY")
  row.icon:SetSize(12, 12)
  row.icon:SetPoint("LEFT", 1, 0)
  row.icon:SetTexCoord(0.08,0.92,0.08,0.92)

  row.nameText = row:CreateFontString(nil, "OVERLAY")
  row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
  row.nameText:SetPoint("RIGHT", row, "RIGHT", -61, 0)
  row.nameText:SetJustifyH("LEFT")
  RUI:ApplyFont(row.nameText, 9, "OUTLINE")
  row.nameText:SetTextColor(1,1,1,1)

  row.healthText = row:CreateFontString(nil, "OVERLAY")
  row.healthText:SetPoint("RIGHT", row, "RIGHT", -3, 0)
  row.healthText:SetJustifyH("RIGHT")
  RUI:ApplyFont(row.healthText, 8, "OUTLINE")
  row.healthText:SetTextColor(1,1,1,1)

  row:Hide()
  self.healthRows[index] = row
  return row
end

function Tracker:HasAnimationSpell(force)
  local now = Now()
  if not force and self.learnedCache ~= nil and now < (self.learnedCacheUntil or 0) then
    return self.learnedCache
  end

  local found = false
  for _, spellName in ipairs(ANIMATION_SPELLS) do
    if RUI.IsSpellLearned and RUI:IsSpellLearned(spellName) then
      found = true
      break
    end
  end

  self.learnedCache = found
  self.learnedCacheUntil = now + 1.5
  return found
end

function Tracker:CollectAuraCounts(playerAuras)
  local counts = {}
  if not playerAuras or type(playerAuras.list) ~= "table" then return counts end

  for _, aura in ipairs(playerAuras.list) do
    local amount = math.max(1, tonumber(aura.count) or 1)
    local minionID
    local spellID = tonumber(aura.spellID)

    if spellID then
      for candidateID, definition in pairs(MINION_TYPES) do
        if definition.auraIDs and definition.auraIDs[spellID] then
          minionID = candidateID
          break
        end
      end
    end

    if not minionID then
      local auraName = Normalize(aura.name)
      for _, candidateID in ipairs(MINION_ORDER) do
        for _, candidateName in ipairs(MINION_TYPES[candidateID].names or {}) do
          if auraName == Normalize(candidateName) then
            minionID = candidateID
            break
          end
        end
        if minionID then break end
      end
    end

    if minionID then
      -- Ascension may expose one duplicate aura per permanent Guardian instead
      -- of a single stacked aura, so add matching entries rather than taking max.
      counts[minionID] = (counts[minionID] or 0) + amount
    end
  end
  return counts
end

function Tracker:IsOwnedUnit(unit, minionID, auraCounts)
  if not unit or not minionID then return false end
  if UnitCanAttack and UnitCanAttack("player", unit) then return false end
  if UnitIsEnemy and UnitIsEnemy("player", unit) then return false end
  if UnitIsUnit and UnitIsUnit(unit, "pet") then return true end

  local guid = UnitGUID and UnitGUID(unit)
  if guid and self.ownedSummons[guid] then return true end

  if UnitCreator and guid then
    local ok, creatorGUID = pcall(UnitCreator, unit)
    if ok and creatorGUID and UnitGUID and creatorGUID == UnitGUID("player") then return true end
  end

  -- Existing summons can predate the combat-log listener. Accept a matching
  -- friendly visible unit only while the player's own summon aura confirms
  -- that this exact guardian type is active.
  return (auraCounts[minionID] or 0) > 0
end

function Tracker:CollectVisibleUnits(auraCounts)
  local units, seen = {}, {}
  local tokens = {"pet", "target", "focus", "mouseover"}
  for index = 1, 40 do tokens[#tokens + 1] = "nameplate" .. tostring(index) end

  local acceptedPerType = {}
  for _, unit in ipairs(tokens) do
    local name = UnitName and UnitName(unit)
    if name then
      local minionID = ClassifyName(name)
      local guid = UnitGUID and UnitGUID(unit)
      local key = guid or unit
      if minionID and not seen[key] and self:IsOwnedUnit(unit, minionID, auraCounts) then
        local confirmedOwned = (guid and self.ownedSummons[guid]) or (UnitIsUnit and UnitIsUnit(unit, "pet"))
        local limit = math.max(1, auraCounts[minionID] or 0)
        if confirmedOwned or (acceptedPerType[minionID] or 0) < limit then
          local current = tonumber(UnitHealth and UnitHealth(unit)) or 0
          local maximum = tonumber(UnitHealthMax and UnitHealthMax(unit)) or 0
          if maximum > 0 then
            if current > maximum then maximum = current end
            seen[key] = true
            acceptedPerType[minionID] = (acceptedPerType[minionID] or 0) + 1
            units[#units + 1] = {
              unit = unit, guid = guid, name = name, minionID = minionID,
              current = math.max(0, current), maximum = math.max(1, maximum),
            }
          end
        end
      end
    end
  end

  table.sort(units, function(left, right)
    local a, b = TYPE_ORDER[left.minionID] or 900, TYPE_ORDER[right.minionID] or 900
    if a ~= b then return a < b end
    local leftPct = left.maximum > 0 and left.current / left.maximum or 1
    local rightPct = right.maximum > 0 and right.current / right.maximum or 1
    if leftPct ~= rightPct then return leftPct < rightPct end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return units
end

function Tracker:CleanSummons()
  local now = Now()
  for guid, summon in pairs(self.ownedSummons) do
    if summon.expires and summon.expires > 0 and summon.expires <= now then
      self.ownedSummons[guid] = nil
    end
  end
end

function Tracker:BuildCounts(auraCounts, visibleUnits)
  local counts = {}
  for minionID, amount in pairs(auraCounts or {}) do counts[minionID] = amount end

  local visibleCounts = {}
  for _, entry in ipairs(visibleUnits or {}) do
    visibleCounts[entry.minionID] = (visibleCounts[entry.minionID] or 0) + 1
  end
  for minionID, amount in pairs(visibleCounts) do
    counts[minionID] = math.max(counts[minionID] or 0, amount)
  end

  local trackedCounts = {}
  for _, summon in pairs(self.ownedSummons) do
    if summon.minionID and (summon.expires or MINION_TYPES[summon.minionID].duration) then
      trackedCounts[summon.minionID] = (trackedCounts[summon.minionID] or 0) + 1
    end
  end
  for minionID, amount in pairs(trackedCounts) do
    counts[minionID] = math.max(counts[minionID] or 0, amount)
  end
  return counts
end

function Tracker:UpdateCountIcons(counts)
  local active = {}
  for _, minionID in ipairs(MINION_ORDER) do
    local amount = tonumber(counts[minionID]) or 0
    if amount > 0 then active[#active + 1] = {minionID=minionID, amount=amount} end
  end

  local maximum = math.min(#active, 8)
  local size, spacing = 20, 2
  local totalWidth = maximum > 0 and maximum * size + (maximum - 1) * spacing or 0
  local theme = RUI:GetTheme()

  for index = 1, maximum do
    local item = active[index]
    local definition = MINION_TYPES[item.minionID]
    local icon = self.countIcons[index] or self:CreateCountIcon(index)
    icon.definition = definition
    icon.amount = item.amount
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (178 - totalWidth) / 2 + (index - 1) * (size + spacing), -18)
    icon.texture:SetTexture(ResolveMinionIcon(definition))
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
    icon.count:SetText(tostring(item.amount))
    icon:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    icon:Show()
  end

  for index = maximum + 1, #self.countIcons do
    self.countIcons[index].definition = nil
    self.countIcons[index]:Hide()
  end
end

function Tracker:UpdateHealthRows(visibleUnits, guardianTotal)
  local maximum = math.min(#visibleUnits, MAX_HEALTH_ROWS)
  local totalsByType, currentByType = {}, {}
  for index = 1, maximum do
    local minionID = visibleUnits[index].minionID
    totalsByType[minionID] = (totalsByType[minionID] or 0) + 1
  end

  for index = 1, maximum do
    local entry = visibleUnits[index]
    local definition = MINION_TYPES[entry.minionID]
    local row = self.healthRows[index] or self:CreateHealthRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -44 - (index - 1) * HEALTH_ROW_HEIGHT)
    row:SetMinMaxValues(0, entry.maximum)
    row:SetValue(math.min(entry.maximum, entry.current))

    local percentage = entry.maximum > 0 and entry.current / entry.maximum or 0
    local red = percentage <= 0.30 and 0.95 or (0.80 - percentage * 0.48)
    local green = percentage <= 0.30 and 0.18 or (0.25 + percentage * 0.58)
    row:SetStatusBarColor(red, green, 0.12, 0.92)
    row.icon:SetTexture(ResolveMinionIcon(definition))

    currentByType[entry.minionID] = (currentByType[entry.minionID] or 0) + 1
    local label = definition.short or definition.label
    if (totalsByType[entry.minionID] or 0) > 1 then
      label = label .. " " .. tostring(currentByType[entry.minionID])
    end
    row.nameText:SetText(label)
    row.healthText:SetText(FormatHealth(entry.current) .. "/" .. FormatHealth(entry.maximum))
    row:Show()
  end

  for index = maximum + 1, #self.healthRows do self.healthRows[index]:Hide() end

  if guardianTotal > 0 and maximum == 0 then
    self.hpHint:SetText("WAITING FOR GUARDIAN UNIT DATA")
    self.hpHint:Show()
    self.frame:SetHeight(64)
  else
    self.hpHint:Hide()
    self.frame:SetHeight(math.max(64, 48 + maximum * HEALTH_ROW_HEIGHT))
  end
end

function Tracker:Refresh(playerAuras, force)
  if not self.active or not self.parent or not self.parent:IsShown() then
    self.frame:Hide()
    return
  end

  local now = Now()
  if not force and now < (self.nextRefresh or 0) then return end
  self.nextRefresh = now + 0.35
  self:CleanSummons()
  self:CloakForcedFriendlyNameplates()

  if not playerAuras and self.readPlayerAuras then playerAuras = self.readPlayerAuras() end
  local auraCounts = self:CollectAuraCounts(playerAuras)
  local visibleUnits = self:CollectVisibleUnits(auraCounts)
  local counts = self:BuildCounts(auraCounts, visibleUnits)

  local guardianTotal, zombieTotal = 0, tonumber(counts.lesser_zombie) or 0
  for _, minionID in ipairs(MINION_ORDER) do guardianTotal = guardianTotal + (tonumber(counts[minionID]) or 0) end

  local relevant = guardianTotal > 0 or zombieTotal > 0 or self:HasAnimationSpell(force)
  if not relevant then
    self.frame:Hide()
    return
  end

  local theme = RUI:GetTheme()
  local zombieSuffix = ""
  if zombieTotal == 1 then
    zombieSuffix = "  •  1 ZOMBIE"
  elseif zombieTotal > 1 then
    zombieSuffix = "  •  " .. tostring(zombieTotal) .. " ZOMBIES"
  end

  if guardianTotal == 1 then
    self.summary:SetText("1 GUARDIAN ACTIVE" .. zombieSuffix)
    self.summary:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  elseif guardianTotal > 1 then
    self.summary:SetText(tostring(guardianTotal) .. " GUARDIANS ACTIVE" .. zombieSuffix)
    self.summary:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  else
    self.summary:SetText("NO GUARDIANS ACTIVE" .. zombieSuffix)
    self.summary:SetTextColor(1.0, 0.34, 0.14, 1)
  end

  self:UpdateCountIcons(counts)
  self:UpdateHealthRows(visibleUnits, guardianTotal)
  self.frame:Show()
end

function Tracker:HandleCombatLog(...)
  local event = ReadCombatLog(...)
  if not event then return end
  local changed = false

  if event.eventType == "SPELL_SUMMON" or event.eventType == "SPELL_CREATE" then
    local playerGUID = UnitGUID and UnitGUID("player")
    local sourceOwned = event.sourceGUID and (
      event.sourceGUID == playerGUID or self.ownedSummons[event.sourceGUID] ~= nil
    )
    if sourceOwned and event.destinationGUID then
      local minionID = ClassifySummon(event.spellID, event.spellName, event.destinationName)
      if minionID then
        local duration = tonumber(MINION_TYPES[minionID].duration)
        self.ownedSummons[event.destinationGUID] = {
          minionID = minionID,
          name = event.destinationName,
          expires = duration and (Now() + duration) or nil,
        }
        changed = true
      end
    end
  elseif event.eventType == "UNIT_DIED" or event.eventType == "UNIT_DESTROYED" or event.eventType == "PARTY_KILL" then
    if event.destinationGUID and self.ownedSummons[event.destinationGUID] then
      self.ownedSummons[event.destinationGUID] = nil
      changed = true
    end
  end

  if changed then self:Refresh(nil, true) end
end

function Tracker:HandleEvent(event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    self:HandleCombatLog(...)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    self.ownedSummons = {}
    self.learnedCache = nil
    self:EnableNameplateSupport()
    self:Refresh(nil, true)
    return
  end
  if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    self.learnedCache = nil
    self:Refresh(nil, true)
    return
  end
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or
     event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    self:Refresh(nil, false)
  end
end

function Tracker:Update()
  self:Refresh(nil, false)
end

function Tracker:Activate()
  self.active = true
  self.nextRefresh = 0
  self:EnableNameplateSupport()
  self:Refresh(nil, true)
end

function Tracker:Deactivate()
  self.active = false
  self:RestoreNameplateSupport()
  self.frame:Hide()
  for _, icon in ipairs(self.countIcons) do icon:Hide() end
  for _, row in ipairs(self.healthRows) do row:Hide() end
end

function GuardianHUD:Create(parent, readPlayerAuras)
  local tracker = setmetatable({}, Tracker)
  tracker.parent = parent
  tracker.readPlayerAuras = readPlayerAuras
  tracker.ownedSummons = {}
  tracker.countIcons = {}
  tracker.healthRows = {}
  tracker.hiddenPlateAlpha = {}
  tracker.active = false
  tracker.nextRefresh = 0

  local frame = CreateFrame("Frame", "RetreatUINecromancerGuardianHUD", parent)
  frame:SetSize(178, 142)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:Hide()
  tracker.frame = frame
  tracker:RestorePosition()

  tracker.dragHandle = CreateFrame("Button", nil, frame)
  tracker.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 2)
  tracker.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, 2)
  tracker.dragHandle:SetHeight(16)
  tracker.dragHandle:RegisterForDrag("LeftButton")
  tracker.dragHandle:RegisterForClicks("RightButtonUp")
  tracker.dragHandle:SetScript("OnDragStart", function()
    if not tracker:IsLocked() and not (InCombatLockdown and InCombatLockdown()) then
      frame:StartMoving()
    end
  end)
  tracker.dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    tracker:SavePosition()
  end)
  tracker.dragHandle:SetScript("OnClick", function(_, button)
    if button == "RightButton" and not tracker:IsLocked() and not (InCombatLockdown and InCombatLockdown()) then
      tracker:ResetPosition()
    end
  end)
  tracker.dragHandle:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tracker:IsLocked() and "Guardian HUD locked" or "Move Guardian HUD", 0.65, 1.0, 0.35)
    if tracker:IsLocked() then
      GameTooltip:AddLine("Click L to unlock it first.", 1, 1, 1)
    else
      GameTooltip:AddLine("Drag the title to move it.", 1, 1, 1)
      GameTooltip:AddLine("Right-click the title to reset its position.", 0.75, 0.75, 0.75)
    end
    GameTooltip:Show()
  end)
  tracker.dragHandle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  tracker.dragText = frame:CreateFontString(nil, "OVERLAY")
  tracker.dragText:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, 0)
  RUI:ApplyFont(tracker.dragText, 8, "OUTLINE")
  tracker.dragText:SetText("<>")
  tracker.dragText:SetTextColor(0.48, 0.55, 0.48, 0.9)

  tracker.lockButton = CreateFrame("Button", nil, frame)
  tracker.lockButton:SetSize(16, 16)
  tracker.lockButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 2)
  tracker.lockButton:SetFrameLevel(frame:GetFrameLevel() + 5)
  tracker.lockButton:RegisterForClicks("LeftButtonUp")
  tracker.lockButton.text = tracker.lockButton:CreateFontString(nil, "OVERLAY")
  tracker.lockButton.text:SetPoint("CENTER")
  RUI:ApplyFont(tracker.lockButton.text, 8, "OUTLINE")
  tracker.lockButton:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then return end
    local db = GuardianDB()
    db.locked = not db.locked
    tracker:UpdateLockVisual()
  end)
  tracker.lockButton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tracker:IsLocked() and "Unlock Guardian HUD" or "Lock Guardian HUD", 1, 1, 1)
    GameTooltip:AddLine(tracker:IsLocked() and "Click to allow moving the HUD." or "Click to prevent accidental movement.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  tracker.lockButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  tracker:UpdateLockVisual()

  tracker.summary = frame:CreateFontString(nil, "OVERLAY")
  tracker.summary:SetPoint("TOP", frame, "TOP", 0, 0)
  tracker.summary:SetWidth(220)
  tracker.summary:SetJustifyH("CENTER")
  RUI:ApplyFont(tracker.summary, 9, "OUTLINE")

  tracker.hpHint = frame:CreateFontString(nil, "OVERLAY")
  tracker.hpHint:SetPoint("TOP", frame, "TOP", 0, -48)
  tracker.hpHint:SetWidth(178)
  tracker.hpHint:SetJustifyH("CENTER")
  RUI:ApplyFont(tracker.hpHint, 8, "OUTLINE")
  tracker.hpHint:SetTextColor(0.62,0.68,0.62,1)
  tracker.hpHint:Hide()

  return tracker
end
