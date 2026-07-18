local RUI = RetreatUI

local BOOK = BOOKTYPE_SPELL or "spell"

-- Only normal, race-specific active racials are allowed here.
-- Ascension's selectable/custom racial abilities are intentionally excluded.
local RACIALS_BY_RACE = {
  Human = {
    ["every man for himself"] = true,
    ["will to survive"] = true,
  },
  Orc = {
    ["blood fury"] = true,
  },
  Dwarf = {
    ["stoneform"] = true,
  },
  NightElf = {
    ["shadowmeld"] = true,
  },
  Scourge = {
    ["will of the forsaken"] = true,
    ["cannibalize"] = true,
  },
  Tauren = {
    ["war stomp"] = true,
  },
  Gnome = {
    ["escape artist"] = true,
    ["gnomish escape"] = true,
  },
  Troll = {
    ["berserking"] = true,
  },
  BloodElf = {
    ["arcane torrent"] = true,
  },
  Draenei = {
    ["gift of the naaru"] = true,
  },
  Goblin = {
    ["rocket jump"] = true,
    ["rocket barrage"] = true,
  },
  Worgen = {
    ["darkflight"] = true,
  },
  Pandaren = {
    ["quaking palm"] = true,
  },
  Nightborne = {
    ["arcane pulse"] = true,
  },
  HighmountainTauren = {
    ["bull rush"] = true,
  },
  VoidElf = {
    ["spatial rift"] = true,
  },
  LightforgedDraenei = {
    ["light's judgment"] = true,
  },
  DarkIronDwarf = {
    ["fireblood"] = true,
  },
  MagharOrc = {
    ["ancestral call"] = true,
  },
  ZandalariTroll = {
    ["regeneratin'"] = true,
  },
  KulTiran = {
    ["haymaker"] = true,
  },
  Vulpera = {
    ["bag of tricks"] = true,
  },
  Mechagnome = {
    ["hyper organic light originator"] = true,
  },
  Dracthyr = {
    ["tail swipe"] = true,
    ["wing buffet"] = true,
  },
  Earthen = {
    ["azerite surge"] = true,
  },
}

local RACE_ALIASES = {
  human = "Human",
  orc = "Orc",
  dwarf = "Dwarf",
  nightelf = "NightElf",
  undead = "Scourge",
  scourge = "Scourge",
  forsaken = "Scourge",
  tauren = "Tauren",
  gnome = "Gnome",
  troll = "Troll",
  bloodelf = "BloodElf",
  draenei = "Draenei",
  goblin = "Goblin",
  worgen = "Worgen",
  pandaren = "Pandaren",
  nightborne = "Nightborne",
  highmountaintauren = "HighmountainTauren",
  voidelf = "VoidElf",
  lightforgeddraenei = "LightforgedDraenei",
  darkirondwarf = "DarkIronDwarf",
  magharorc = "MagharOrc",
  zandalari = "ZandalariTroll",
  zandalaritroll = "ZandalariTroll",
  kultiran = "KulTiran",
  vulpera = "Vulpera",
  mechagnome = "Mechagnome",
  dracthyr = "Dracthyr",
  earthen = "Earthen",
}

local function Lower(value)
  return string.lower(tostring(value or ""))
end

local function Normalize(value)
  return (Lower(value):gsub("[^%a%d]", ""))
end

local function PlayerRaceKey()
  if not UnitRace then return nil, nil end
  local localized, token = UnitRace("player")
  if token and RACIALS_BY_RACE[token] then return token, localized or token end

  local tokenKey = RACE_ALIASES[Normalize(token)]
  if tokenKey and RACIALS_BY_RACE[tokenKey] then return tokenKey, localized or tokenKey end

  local localizedKey = RACE_ALIASES[Normalize(localized)]
  if localizedKey and RACIALS_BY_RACE[localizedKey] then return localizedKey, localized or localizedKey end

  return nil, localized or token
end

local function SpellbookName(index)
  if GetSpellBookItemName then
    local name = GetSpellBookItemName(index, BOOK)
    if name then return name end
  end
  if GetSpellName then
    local name = GetSpellName(index, BOOK)
    if name then return name end
  end
  return nil
end

local function SpellID(index, name)
  if GetSpellBookItemInfo then
    local ok, _, itemID = pcall(GetSpellBookItemInfo, index, BOOK)
    if ok and tonumber(itemID) then return tonumber(itemID) end
  end
  if GetSpellLink then
    local ok, link = pcall(GetSpellLink, index, BOOK)
    local id = ok and link and tonumber(string.match(link, "spell:(%d+)"))
    if id then return id end
  end
  if GetSpellInfo and name then
    local ok, _, _, _, _, _, _, infoID = pcall(GetSpellInfo, name)
    if ok and tonumber(infoID) then return tonumber(infoID) end
  end
  return nil
end

local function IsPassive(index, spellID)
  if not IsPassiveSpell then return false end
  local ok, passive = pcall(IsPassiveSpell, index, BOOK)
  if ok and passive ~= nil then return passive == true or passive == 1 end
  if spellID then
    ok, passive = pcall(IsPassiveSpell, spellID)
    if ok and passive ~= nil then return passive == true or passive == 1 end
  end
  return false
end

local function SpellbookEndIndex()
  if not GetNumSpellTabs or not GetSpellTabInfo then return 300 end
  local tabs = tonumber(GetNumSpellTabs()) or 0
  local highest = 0
  for tab = 1, tabs do
    local _, _, offset, count = GetSpellTabInfo(tab)
    offset, count = tonumber(offset) or 0, tonumber(count) or 0
    highest = math.max(highest, offset + count)
  end
  return math.max(highest + 20, 300)
end

function RUI:GetPlayerRaceKey()
  local key, displayName = PlayerRaceKey()
  return key, displayName
end

function RUI:InvalidateRacialCache()
  self.racialSpells = nil
  self.racialRaceKey = nil
end

function RUI:ScanRacialSpells(force)
  local raceKey, raceDisplay = PlayerRaceKey()
  if self.racialSpells and self.racialRaceKey == raceKey and not force then
    return self.racialSpells
  end

  local allowed = raceKey and RACIALS_BY_RACE[raceKey] or nil
  local found, seen = {}, {}

  if allowed then
    local endIndex = SpellbookEndIndex()
    for index = 1, endIndex do
      local name = SpellbookName(index)
      if name then
        local lower = Lower(name)
        if allowed[lower] and not seen[lower] then
          local spellID = SpellID(index, name)
          if not IsPassive(index, spellID) then
            seen[lower] = true
            found[#found + 1] = {
              name = name,
              spellID = spellID,
              bookIndex = index,
              racial = true,
              raceKey = raceKey,
              raceName = raceDisplay or raceKey,
              buff = name,
            }
          end
        end
      end
    end
  end

  self.racialRaceKey = raceKey
  self.racialSpells = found
  return found
end

function RUI:GetRacialSpellDefinitions(force)
  local output = {}
  for _, racial in ipairs(self:ScanRacialSpells(force)) do
    output[#output + 1] = {
      name = racial.name,
      spellID = racial.spellID,
      bookIndex = racial.bookIndex,
      racial = true,
      raceKey = racial.raceKey,
      raceName = racial.raceName,
      buff = racial.buff,
    }
  end
  return output
end
