local RUI = RetreatUI

-- RetreatUI Buff Manager implementation.
--
-- Goals:
--   * PallyPower-style compact buff bar.
--   * One secure click buffs the next assigned group member.
--   * Red = missing, orange = under five minutes, green = covered.
--   * Automatic normal/Greater rank selection from the spellbook.
--   * Class/spec assignment matrix with automatic Bloodmage Offering rules.
--
-- This module intentionally resolves spells by their spellbook names whenever
-- a stable Ascension spell ID has not yet been verified. That keeps unverified
-- database IDs out of the live casting path while still allowing learned buffs
-- to work in the live addon.

local STATUS = {
  missing  = {0.90, 0.12, 0.12, 1},
  expiring = {1.00, 0.48, 0.05, 1},
  ready    = {0.15, 0.72, 0.22, 1},
  inactive = {0.28, 0.28, 0.28, 1},
  unknown  = {0.45, 0.32, 0.12, 1},
}

local CLASS_RULES = {
  Barbarian        = {resource="ENERGY"},
  Bloodmage        = {resource="RAGE", tankSpec="Eternal"},
  Chronomancer     = {resource="MANA"},
  Cultist          = {resource="MANA", tankSpec="Dreadnaught", tankAliases={"Dreadnought"}},
  Felsworn         = {resource="ENERGY", tankSpec="Tyrant"},
  Guardian         = {resource="ENERGY", tankSpec="Vanguard"},
  ["Knight of Xoroth"] = {resource="RAGE", tankSpec="Defiance"},
  Necromancer      = {resource="RUNIC_POWER"},
  Primalist        = {resource="RAGE"},
  Pyromancer       = {resource="MANA"},
  Ranger           = {resource="FOCUS"},
  Reaper           = {resource="RUNIC_POWER", tankSpec="Domination"},
  Runemaster       = {resource="MANA"},
  Starcaller       = {resource="MANA", tankSpec="Moon Guard"},
  Stormbringer     = {resource="MANA"},
  ["Sun Cleric"] = {resource="MANA", tankSpec="Seraphim"},
  Templar          = {resource="ENERGY", tankSpec="Oathkeeper"},
  Tinker           = {resource="MANA"},
  Venomancer       = {resource="RAGE", tankSpec="Fortitude"},
  ["Witch Doctor"] = {resource="MANA"},
  ["Witch Hunter"] = {resource="MANA", tankSpec="Black Knight"},
}

local CLASS_ALIASES = {}
local function NormalKey(value)
  return string.lower(tostring(value or "")):gsub("[^%a%d]", "")
end

for className in pairs(CLASS_RULES) do CLASS_ALIASES[NormalKey(className)] = className end
CLASS_ALIASES.knightofxoroth = "Knight of Xoroth"
CLASS_ALIASES.suncleric = "Sun Cleric"
CLASS_ALIASES.witchdoctor = "Witch Doctor"
CLASS_ALIASES.witchhunter = "Witch Hunter"

-- Exclusive self-buff family. This is intentionally separate from the
-- class/spec assignment matrix: it always targets the player and only cycles
-- through shields actually present in the current spellbook.
local SELF_SHIELD_CHOICES = {
  {key="blood", name="Blood Shield"},
  {key="vital", name="Vital Shield"},
}

local function RuntimeSpellName(spellID)
  spellID = tonumber(spellID)
  if not spellID or not GetSpellInfo then return nil end
  local ok, name = pcall(GetSpellInfo, spellID)
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

local function StripGreater(name)
  local stripped = tostring(name or ""):gsub("^Greater%s+", "")
  return stripped ~= "" and stripped or nil
end

local function BuffChoice(key, greaterName, greaterID, extra)
  extra = extra or {}
  extra.key = key
  if extra.name == nil and greaterName then extra.name = StripGreater(greaterName) end
  if extra.normalName == nil and greaterName and extra.name and extra.name ~= "" then extra.normalName = extra.name end
  extra.greaterName = greaterName or extra.greaterName
  extra.greaterID = tonumber(greaterID) or tonumber(extra.greaterID)
  extra.normalID = tonumber(extra.normalID)
  return extra
end

local function BuffPair(key, normalName, normalID, greaterName, greaterID, extra)
  extra = extra or {}
  extra.normalName = normalName
  extra.normalID = normalID
  return BuffChoice(key, greaterName, greaterID, extra)
end

-- Collector-backed fallback for legacy entries that expose only a Greater ID.
-- The completed catalog below now uses explicit normal and Greater names; rank
-- selection still comes from the player's live spellbook.
local function GreaterIDChoice(key, greaterID, label, extra)
  extra = extra or {}
  extra.name = label
  return BuffChoice(key, nil, greaterID, extra)
end

-- Only long-duration buff families with an actual Greater form belong in the
-- compact Buff Manager. One normal/Greater family is always represented by one
-- button; duplicate effect rows from the spreadsheet are intentionally merged.
local function NormalizeAuraName(value)
  value = string.lower(tostring(value or ""))
  value = value:gsub("’", "'"):gsub("`", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

-- Equivalent raid-buff categories, derived from the CoA Buff Reminders data.
-- These are used only to decide whether a target is already covered by the
-- same raid-buff effect from another class. Casting still uses the active
-- character's own learned spell name and highest learned rank.
local EQUIVALENT_BUFFS = {
  STAMINA = {
    "Mark of Rivendare", "Greater Mark of Rivendare", "Enduring Shout",
    "Sanguinary Offering", "Greater Sanguinary Offering",
    "Foul Mandate", "Greater Foul Mandate", "Rite of Resolve", "Greater Rite of Resolve",
  },
  STRENGTH = {
    "Mark of Korth'azz", "Greater Mark of Korth'azz", "Honor", "Greater Honor",
    "Rite of Power", "Greater Rite of Power",
  },
  MANA = {
    "Devotion of Grace", "Greater Devotion of Grace", "Mark of Zeliek", "Greater Mark of Zeliek",
    "Etching of the Magi", "Greater Etching of the Magi", "Resourceful Wuju", "Greater Resourceful Wuju",
    "Whispers of Y'Shaarj", "Greater Whispers of Y'Shaarj", "Grove Instinct", "Greater Grove Instinct",
    "Seal of Al'ar", "Greater Seal of Al'ar", "Call of the Wind", "Greater Call of the Wind",
    "Mana Module", "Greater Mana Module", "Void Blessing", "Greater Void Blessing",
  },
  ATTACK_POWER = {
    "Devotion of Dawn", "Greater Devotion of Dawn", "Power Module", "Greater Power Module",
    "Power Wuju", "Greater Power Wuju", "Primal Instinct", "Greater Primal Instinct",
    "Woodsman's Adaptation", "Greater Woodsman's Adaptation",
  },
  STATS = {
    "Whispers of N'Zoth", "Greater Whispers of N'Zoth", "Devotion of Emperors", "Greater Devotion of Emperors",
    "Crusader's Oath", "Greater Crusader's Oath", "Etching of the Leylines", "Greater Etching of the Leylines",
    "Gift of Fervor", "Greater Gift of Fervor",
  },
  SPELL_POWER = {
    "Mark of Blaumeux", "Greater Mark of Blaumeux", "Whispers of C'Thun", "Greater Whispers of C'Thun",
    "Devotion of Radiance", "Greater Devotion of Radiance", "Witching Edict", "Greater Witching Edict",
    "Toxic Pheromones", "Greater Toxic Pheromones", "Grim Mandate", "Greater Grim Mandate",
  },
  AGILITY = {
    "Brutal Shout", "Illidari Intuition", "Greater Illidari Intuition",
    "Etching of the Dextrous", "Greater Etching of the Dextrous", "Gift of Zeal", "Greater Gift of Zeal",
    "Inquisitor's Edict", "Greater Inquisitor's Edict", "Spider Pheromones", "Greater Spider Pheromones",
  },
  ARMOR = {
    "Earthen Endurance", "Greater Earthen Endurance", "Man'ari Intuition", "Greater Man'ari Intuition",
    "Footpad's Adaptation", "Greater Footpad's Adaptation", "Knight's Edict", "Greater Knight's Edict",
    "Beetle Pheromones", "Greater Beetle Pheromones",
  },
  INTELLECT = {
    "Nozdormu's Wisdom", "Greater Nozdormu's Wisdom", "Seal of Alysrazor", "Greater Seal of Alysrazor",
    "Celestial Mind", "Greater Celestial Mind", "Call of the Storm", "Greater Call of the Storm",
  },
  SPIRIT = {
    "Chromie's Wisdom", "Greater Chromie's Wisdom", "Bloodsoaked Offering", "Greater Bloodsoaked Offering",
    "Spirit Wuju", "Greater Spirit Wuju",
  },
  ARCANE_RESISTANCE = {
    "Arcane Protection", "Greater Arcane Protection", "Inscription: Arcane", "Greater Inscription: Arcane",
    "Mark of Zeliek", "Greater Mark of Zeliek",
  },
  FIRE_RESISTANCE = {
    "Fire Protection", "Greater Fire Protection", "Inscription: Fire", "Greater Inscription: Fire",
    "Mark of Korth'azz", "Greater Mark of Korth'azz",
  },
  FROST_RESISTANCE = {
    "Chill of the Tomb", "Greater Chill of the Tomb", "Inscription: Frost", "Greater Inscription: Frost",
    "Mark of Rivendare", "Greater Mark of Rivendare",
  },
  NATURE_RESISTANCE = {
    "Essence of Nature", "Greater Essence of Nature", "Inscription: Nature", "Greater Inscription: Nature",
    "Wild Blessing",
  },
  SHADOW_RESISTANCE = {
    "Shadow Protection", "Prayer of Shadow Protection", "Mark of Blaumeux", "Greater Mark of Blaumeux",
  },
  ALL_RESISTANCE = {
    "Call of the Lightning", "Greater Call of the Lightning", "Rite of Perseverance", "Greater Rite of Perseverance",
    "Mark of the Wild", "Gift of the Wild", "Earthen Endurance", "Greater Earthen Endurance",
    "Spirit Wuju", "Greater Spirit Wuju",
  },
}

local EQUIVALENT_LOOKUPS = {}
for category, names in pairs(EQUIVALENT_BUFFS) do
  local lookup = {}
  for _, name in ipairs(names) do lookup[NormalizeAuraName(name)] = true end
  EQUIVALENT_LOOKUPS[category] = lookup
end

-- Every simultaneous normal/Greater spell family is its own button. Mutually
-- exclusive spells share one family with several choices. Bloodmage Offerings
-- are the first example: one class/spec assignment can select Sanguinary,
-- Bloodsoaked, OFF or the automatic class/resource rule, but never both.
local BUFF_CATALOG = {
  Bloodmage = {
    {key="bloodthorns", label="Bloodthorns", assignment="ALL", choices={
      BuffPair("bloodthorns", "Bloodthorns", 501664, "Greater Bloodthorns", 572116),
    }},
    {key="offering", label="Offering", assignment="BLOODMAGE_OFFERING", choices={
      BuffPair("sanguinary", "Sanguinary Offering", 707337, "Greater Sanguinary Offering", 680299, {categories={"STAMINA"}}),
      BuffPair("bloodsoaked", "Bloodsoaked Offering", 572401, "Greater Bloodsoaked Offering", 572404, {categories={"SPIRIT"}}),
    }},
  },

  Chronomancer = {
    {key="chromies_wisdom", label="Chromie's Wisdom", assignment="ALL", choices={
      BuffPair("chromie", "Chromie's Wisdom", 802829, "Greater Chromie's Wisdom", 680307, {categories={"SPIRIT"}}),
    }},
    {key="nozdormus_wisdom", label="Nozdormu's Wisdom", assignment="ALL", choices={
      BuffPair("nozdormu", "Nozdormu's Wisdom", 572395, "Greater Nozdormu's Wisdom", 572396, {categories={"INTELLECT"}}),
    }},
  },

  Cultist = {
    {key="whispers_nzoth", label="Whispers of N'Zoth", assignment="ALL", choices={
      BuffPair("nzoth", "Whispers of N'Zoth", 561386, "Greater Whispers of N'zoth", 561387, {categories={"STATS"}}),
    }},
    {key="whispers_cthun", label="Whispers of C'Thun", assignment="ALL", choices={
      BuffPair("cthun", "Whispers of C'Thun", 572905, "Greater Whispers of C'thun", 573067, {categories={"SPELL_POWER"}}),
    }},
    {key="whispers_yshaarj", label="Whispers of Y'Shaarj", assignment="ALL", choices={
      BuffPair("yshaarj", "Whispers of Y'shaarj", 561391, "Greater Whispers of Y'shaarj", 561392, {categories={"MANA"}}),
    }},
  },

  Felsworn = {
    {key="illidari_intuition", label="Illidari Intuition", assignment="ALL", choices={
      BuffPair("agility", "Illidari Intuition", 501329, "Greater Illidari Intuition", 680308, {categories={"AGILITY"}}),
    }},
    {key="manari_intuition", label="Man'ari Intuition", assignment="ALL", choices={
      BuffPair("armor_stats", "Man'ari Intuition", 523484, "Greater Man'ari Intuition", 523495, {categories={"ARMOR"}}),
    }},
  },

  Guardian = {
    {key="honor", label="Honor", assignment="ALL", choices={
      BuffPair("strength", "Honor", 301232, "Greater Honor", 680280, {categories={"STRENGTH"}}),
    }},
    {key="fire_protection", label="Fire Protection", assignment="ALL", choices={
      BuffPair("fire_resistance", "Fire Protection", 582535, "Greater Fire Protection", 582536, {categories={"FIRE_RESISTANCE"}}),
    }},
  },

  ["Knight of Xoroth"] = {
    {key="marks_of_xoroth", label="Marks of Xoroth", assignment="KNIGHT_MARK", choices={
      BuffPair("rivendare", "Mark of Rivendare", 803670, "Greater Mark of Rivendare", 803730, {categories={"STAMINA", "FROST_RESISTANCE"}}),
      BuffPair("korthazz", "Mark of Korth'azz", 707345, "Greater Mark of Korth’azz", 680300, {categories={"STRENGTH", "FIRE_RESISTANCE"}}),
      BuffPair("zeliek", "Mark of Zeliek", 803671, "Greater Mark of Zeliek", 803731, {categories={"MANA", "ARCANE_RESISTANCE"}}),
      BuffPair("blaumeux", "Mark of Blaumeux", 707696, "Greater Mark of Blaumeux", 712460, {categories={"SPELL_POWER", "SHADOW_RESISTANCE"}}),
    }},
  },

  Necromancer = {
    {key="foul_mandate", label="Foul Mandate", assignment="ALL", choices={
      BuffPair("foul", "Foul Mandate", 573298, "Greater Foul Mandate", 680286, {categories={"STAMINA"}}),
    }},
    {key="grim_mandate", label="Grim Mandate", assignment="ALL", choices={
      BuffPair("grim", "Grim Mandate", 572789, "Greater Grim Mandate", 572790, {categories={"SPELL_POWER"}}),
    }},
    {key="chill_tomb", label="Chill of the Tomb", assignment="ALL", choices={
      BuffPair("chill", "Chill of the Tomb", 572176, "Greater Chill of the Tomb", 572177, {categories={"FROST_RESISTANCE"}}),
    }},
  },

  Primalist = {
    {key="grove_instinct", label="Grove Instinct", assignment="ALL", choices={
      BuffPair("grove", "Grove Instinct", 572816, "Greater Grove Instinct", 572817, {categories={"MANA"}}),
    }},
    {key="primal_instinct", label="Primal Instinct", assignment="ALL", choices={
      BuffPair("primal", "Primal Instinct", 573349, "Greater Primal Instinct", 680310, {categories={"ATTACK_POWER"}}),
    }},
    {key="earthen_endurance", label="Earthen Endurance", assignment="ALL", choices={
      BuffPair("wild_defense", "Earthen Endurance", 570755, "Greater Earthen Endurance", 570756, {categories={"ARMOR", "ALL_RESISTANCE"}}),
    }},
    {key="essence_of_nature", label="Essence of Nature", assignment="ALL", choices={
      BuffPair("nature_resistance", "Essence of Nature", 581315, "Greater Essence of Nature", 582261, {categories={"NATURE_RESISTANCE"}}),
    }},
  },

  Pyromancer = {
    {key="seal_alar", label="Seal of Al'ar", assignment="ALL", choices={
      BuffPair("alar", "Seal of Al'ar", 808012, "Greater Seal of Al'ar", 808060, {categories={"MANA"}}),
    }},
    {key="seal_alysrazor", label="Seal of Alysrazor", assignment="ALL", choices={
      BuffPair("alysrazor", "Seal of Alysrazor", 800196, "Greater Seal of Alysrazor", 570170, {categories={"INTELLECT"}}),
    }},
  },

  Ranger = {
    {key="footpads_adaptation", label="Footpad's Adaptation", assignment="ALL", choices={
      BuffPair("armor_stats", "Footpad's Adaptation", 523494, "Greater Footpad's Adaptation", 523513, {categories={"ARMOR"}}),
    }},
    {key="woodsmans_adaptation", label="Woodsman's Adaptation", assignment="ALL", choices={
      BuffPair("attack_power", "Woodsman's Adaptation", 803666, "Greater Woodsman's Adaptation", 680294, {categories={"ATTACK_POWER"}}),
    }},
  },

  Reaper = {
    {key="rite_power", label="Rite of Power", assignment="ALL", choices={
      BuffPair("power", "Rite of Power", 578129, "Greater Rite of Power", 578130, {categories={"STRENGTH"}}),
    }},
    {key="rite_resolve", label="Rite of Resolve", assignment="ALL", choices={
      BuffPair("resolve", "Rite of Resolve", 803314, "Greater Rite of Resolve", 680298, {categories={"STAMINA"}}),
    }},
    {key="rite_perseverance", label="Rite of Perseverance", assignment="ALL", choices={
      BuffPair("perseverance", "Rite of Perseverance", 575841, "Greater Rite of Perseverance", 575842, {categories={"ALL_RESISTANCE"}}),
    }},
  },

  Runemaster = {
    {key="etching_leylines", label="Etching of the Leylines", assignment="ALL", choices={
      BuffPair("leylines", "Etching of the Leylines", 561236, "Greater Etching of the Leylines", 561242, {categories={"STATS"}}),
    }},
    {key="etching_dextrous", label="Etching of the Dextrous", assignment="ALL", choices={
      BuffPair("dextrous", "Etching of the Dextrous", 561240, "Greater Etching of the Dextrous", 561241, {categories={"AGILITY"}}),
    }},
    {key="etching_magi", label="Etching of the Magi", assignment="ALL", choices={
      BuffPair("magi", "Etching of the Magi", 560295, "Greater Etching of the Magi", 561243, {categories={"MANA"}}),
    }},
    {key="inscription_arcane", label="Inscription: Arcane", assignment="ALL", choices={
      BuffPair("arcane", "Inscription: Arcane", 561254, "Greater Inscription: Arcane", 561255, {categories={"ARCANE_RESISTANCE"}}),
    }},
    {key="inscription_fire", label="Inscription: Fire", assignment="ALL", choices={
      BuffPair("fire", "Inscription: Fire", 561250, "Greater Inscription: Fire", 561251, {categories={"FIRE_RESISTANCE"}}),
    }},
    {key="inscription_frost", label="Inscription: Frost", assignment="ALL", choices={
      BuffPair("frost", "Inscription: Frost", 561246, "Greater Inscription: Frost", 561247, {categories={"FROST_RESISTANCE"}}),
    }},
    {key="inscription_nature", label="Inscription: Nature", assignment="ALL", choices={
      BuffPair("nature", "Inscription: Nature", 561258, "Greater Inscription: Nature", 561259, {categories={"NATURE_RESISTANCE"}}),
    }},
  },

  Starcaller = {
    {key="celestial_mind", label="Celestial Mind", assignment="ALL", choices={
      BuffPair("celestial", "Celestial Mind", 301225, "Greater Celestial Mind", 680301, {categories={"INTELLECT"}}),
    }},
    {key="arcane_protection", label="Arcane Protection", assignment="ALL", choices={
      BuffPair("arcane", "Arcane Protection", 573347, "Greater Arcane Protection", 573348, {categories={"ARCANE_RESISTANCE"}}),
    }},
  },

  Stormbringer = {
    {key="call_wind", label="Call of the Wind", assignment="ALL", choices={
      BuffPair("wind", "Call of the Wind", 503323, "Greater Call of the Wind", 680291, {categories={"MANA"}}),
    }},
    {key="call_storm", label="Call of the Storm", assignment="ALL", choices={
      BuffPair("storm", "Call of the Storm", 578315, "Greater Call of the Storm", 578316, {categories={"INTELLECT"}}),
    }},
    {key="call_lightning", label="Call of the Lightning", assignment="ALL", choices={
      BuffPair("lightning", "Call of the Lightning", 575845, "Greater Call of the Lightning", 575846, {categories={"ALL_RESISTANCE"}}),
    }},
  },

  ["Sun Cleric"] = {
    {key="devotion_emperors", label="Devotion of Emperors", assignment="ALL", choices={
      BuffPair("emperors", "Devotion of Emperors", 572552, "Greater Devotion of Emperors", 572553, {categories={"STATS"}}),
    }},
    {key="devotion_dawn", label="Devotion of Dawn", assignment="ALL", choices={
      BuffPair("dawn", "Devotion of Dawn", 572389, "Greater Devotion of Dawn", 572390, {categories={"ATTACK_POWER"}}),
    }},
    {key="devotion_radiance", label="Devotion of Radiance", assignment="ALL", choices={
      BuffPair("radiance", "Devotion of Radiance", 575043, "Greater Devotion of Radiance", 575045, {categories={"SPELL_POWER"}}),
    }},
    {key="devotion_grace", label="Devotion of Grace", assignment="ALL", choices={
      BuffPair("grace", "Devotion of Grace", 300865, "Greater Devotion of Grace", 681160, {categories={"MANA"}}),
    }},
  },

  Templar = {
    {key="crusaders_oath", label="Crusader's Oath", assignment="ALL", choices={
      -- The normal single-target version is named Gift of Fervor; the group
      -- upgrade is named Greater Crusader's Oath in the Ascension client.
      BuffPair("fervor", "Gift of Fervor", nil, "Greater Crusader's Oath", 572630, {categories={"STATS"}}),
    }},
    {key="gift_zeal", label="Gift of Zeal", assignment="ALL", choices={
      BuffPair("zeal", "Gift of Zeal", 300924, "Greater Gift of Zeal", 680306, {categories={"AGILITY"}}),
    }},
  },

  Tinker = {
    {key="mana_module", label="Mana Module", assignment="ALL", choices={
      BuffPair("mana", "Mana Module", 803663, "Greater Mana Module", 803665, {categories={"MANA"}}),
    }},
    {key="power_module", label="Power Module", assignment="ALL", choices={
      BuffPair("power", "Power Module", 707688, "Greater Power Module", 680315, {categories={"ATTACK_POWER"}}),
    }},
  },

  Venomancer = {
    {key="beetle_pheromones", label="Beetle Pheromones", assignment="ALL", choices={
      BuffPair("beetle", "Beetle Pheromones", 803655, "Greater Beetle Pheromones", 803657, {categories={"ARMOR"}}),
    }},
    {key="toxic_pheromones", label="Toxic Pheromones", assignment="ALL", choices={
      BuffPair("toxic", "Toxic Pheromones", 707692, "Greater Toxic Pheromones", 712459, {categories={"SPELL_POWER"}}),
    }},
    {key="spider_pheromones", label="Spider Pheromones", assignment="ALL", choices={
      BuffPair("spider", "Spider Pheromones", 803650, "Greater Spider Pheromones", 680312, {categories={"AGILITY"}}),
    }},
  },

  ["Witch Doctor"] = {
    {key="resourceful_wuju", label="Resourceful Wuju", assignment="ALL", choices={
      BuffPair("cost_reduction", "Resourceful Wuju", 578344, "Greater Resourceful Wuju", 800195, {categories={"MANA"}}),
    }},
    {key="power_wuju", label="Power Wuju", assignment="ALL", choices={
      BuffPair("power", "Power Wuju", 707677, "Greater Power Wuju", 712458, {categories={"ATTACK_POWER"}}),
    }},
    {key="spirit_wuju", label="Spirit Wuju", assignment="ALL", choices={
      BuffPair("spirit", "Spirit Wuju", 561143, "Greater Spirit Wuju", 680872, {categories={"SPIRIT", "ALL_RESISTANCE"}}),
    }},
  },

  ["Witch Hunter"] = {
    {key="witching_edict", label="Witching Edict", assignment="ALL", choices={
      BuffPair("spell_power", "Witching Edict", 707687, "Greater Witching Edict", 681442, {categories={"SPELL_POWER"}}),
    }},
    {key="inquisitors_edict", label="Inquisitor's Edict", assignment="ALL", choices={
      BuffPair("agility", "Inquisitor's Edict", 707355, "Greater Inquisitor's Edict", 680303, {categories={"AGILITY"}}),
    }},
    {key="knights_edict", label="Knight's Edict", assignment="ALL", choices={
      BuffPair("armor_stats", "Knight's Edict", 523488, "Greater Knight's Edict", 523510, {categories={"ARMOR"}}),
    }},
  },
}
BUFF_CATALOG.KnightOfXoroth = BUFF_CATALOG["Knight of Xoroth"]
BUFF_CATALOG.SunCleric = BUFF_CATALOG["Sun Cleric"]
BUFF_CATALOG.WitchDoctor = BUFF_CATALOG["Witch Doctor"]
BUFF_CATALOG.WitchHunter = BUFF_CATALOG["Witch Hunter"]

local compactFrame
local managerFrame
local compactButtons = {}
local shieldButton
local managerRows = {}
local managerHeaders = {}
local refreshElapsed = 0
local refreshPending = false
local activeClassName
local activeFamilies
local activeComposition = {}
local COMPACT_COLUMNS = 3
local COMPACT_SLOT = 32

local function PositionCompactSlot(button, leftOffset, slotIndex)
  local column = (slotIndex - 1) % COMPACT_COLUMNS
  local row = math.floor((slotIndex - 1) / COMPACT_COLUMNS)
  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", compactFrame, "TOPLEFT", leftOffset + (column * COMPACT_SLOT), -2 - (row * COMPACT_SLOT))
end

local function EnsureBuffDB()
  local db = RUI:EnsureDB()
  db.buffManager = db.buffManager or {}
  local buffDB = db.buffManager
  buffDB.assignments = buffDB.assignments or {}
  buffDB.seenSpecs = buffDB.seenSpecs or {}

  -- Legacy Offering migration: the two old Offering columns are now one exclusive
  -- family. Preserve only deliberate spell selections; otherwise return the
  -- row to AUTO so the new tank/resource rules can choose the correct Offering.
  if not buffDB.offeringAssignmentMigration then
    local bloodmage = buffDB.assignments[NormalKey("Bloodmage")]
    if type(bloodmage) == "table" then
      local oldSanguinary = bloodmage.sanguinary_offering
      local oldBloodsoaked = bloodmage.bloodsoaked_offering
      local merged = bloodmage.offering or {}
      local bucketKeys = {}
      for key in pairs(type(oldSanguinary) == "table" and oldSanguinary or {}) do bucketKeys[key] = true end
      for key in pairs(type(oldBloodsoaked) == "table" and oldBloodsoaked or {}) do bucketKeys[key] = true end
      for bucketKey in pairs(bucketKeys) do
        local sanguinary = type(oldSanguinary) == "table" and oldSanguinary[bucketKey] or nil
        local bloodsoaked = type(oldBloodsoaked) == "table" and oldBloodsoaked[bucketKey] or nil
        if sanguinary == "sanguinary" and bloodsoaked ~= "bloodsoaked" then
          merged[bucketKey] = "sanguinary"
        elseif bloodsoaked == "bloodsoaked" and sanguinary ~= "sanguinary" then
          merged[bucketKey] = "bloodsoaked"
        elseif sanguinary == "__NONE" and bloodsoaked == "__NONE" then
          merged[bucketKey] = "__NONE"
        end
      end
      bloodmage.offering = merged
      bloodmage.sanguinary_offering = nil
      bloodmage.bloodsoaked_offering = nil
    end
    buffDB.offeringAssignmentMigration = 1
  end

  -- Legacy Knight of Xoroth Mark migration: Knight of Xoroth Marks are mutually exclusive on each
  -- target. Merge the four legacy family columns into one Marks of Xoroth
  -- assignment without discarding deliberate selections.
  if not buffDB.xorothMarkAssignmentMigration then
    local xoroth = buffDB.assignments[NormalKey("Knight of Xoroth")]
    if type(xoroth) == "table" then
      local legacy = {
        {family="mark_rivendare", choice="rivendare"},
        {family="mark_korthazz", choice="korthazz"},
        {family="mark_zeliek", choice="zeliek"},
        {family="mark_blaumeux", choice="blaumeux"},
      }
      local merged = xoroth.marks_of_xoroth or {}
      local bucketKeys = {}
      for _, item in ipairs(legacy) do
        for bucketKey in pairs(type(xoroth[item.family]) == "table" and xoroth[item.family] or {}) do
          bucketKeys[bucketKey] = true
        end
      end
      for bucketKey in pairs(bucketKeys) do
        local chosen
        local allOff = true
        for _, item in ipairs(legacy) do
          local value = type(xoroth[item.family]) == "table" and xoroth[item.family][bucketKey] or nil
          if value ~= nil and value ~= "__NONE" then allOff = false end
          if not chosen and value == item.choice then chosen = item.choice end
        end
        if chosen then merged[bucketKey] = chosen
        elseif allOff then merged[bucketKey] = "__NONE" end
      end
      xoroth.marks_of_xoroth = merged
      for _, item in ipairs(legacy) do xoroth[item.family] = nil end
    end
    buffDB.xorothMarkAssignmentMigration = 1
  end

  if buffDB.selfShield == nil then buffDB.selfShield = "blood" end
  if buffDB.locked == nil then buffDB.locked = false end
  if buffDB.barShown == nil then
    if buffDB.shown ~= nil then buffDB.barShown = buffDB.shown else buffDB.barShown = true end
  end
  return buffDB
end

local function CanonicalClass(name)
  if not name or name == "" then return nil end
  if RUI.NormalizeClassName then
    local normalized = RUI:NormalizeClassName(name)
    if normalized and CLASS_RULES[normalized] then return normalized end
  end
  return CLASS_ALIASES[NormalKey(name)] or name
end

local function IsLearned(name, spellID)
  -- Spellbook names are the primary source. Multiple ranks share the same
  -- name, and ScanSpellbook keeps the highest learned rank for that name.
  if name and RUI.IsSpellLearned and RUI:IsSpellLearned(name) then return true end
  if spellID and RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(spellID) then return true end
  if spellID and IsSpellKnown then
    local ok, learned = pcall(IsSpellKnown, spellID)
    if ok and learned then return true end
  end
  if spellID and IsPlayerSpell then
    local ok, learned = pcall(IsPlayerSpell, spellID)
    if ok and learned then return true end
  end
  return false
end

local function SpellIDByName(name)
  if not name then return nil end
  if RUI.GetSpellID then
    local spellID = RUI:GetSpellID(name)
    if spellID then return tonumber(spellID) end
  end
  -- On the 3.3 client the seventh GetSpellInfo return is cast time, not a
  -- guaranteed spell ID. Parse a real spell link instead of risking a wrong ID.
  if GetSpellLink then
    local ok, link = pcall(GetSpellLink, name)
    local spellID = ok and link and tonumber(string.match(link, "spell:(%d+)"))
    if spellID then return spellID end
  end
  return nil
end

local function ResolveChoice(choice)
  if not choice then return nil end

  local greaterID = tonumber(choice.greaterID)
  local normalID = tonumber(choice.normalID)
  local greaterName = choice.greaterName or RuntimeSpellName(greaterID)
  local normalName = choice.normalName or RuntimeSpellName(normalID) or StripGreater(greaterName)
  local displayName = choice.name
  if not displayName or displayName == "" then displayName = normalName or StripGreater(greaterName) or "Buff" end

  -- Cache names resolved from the Ascension client so aura matching and future
  -- refreshes use the exact localized spell names returned by GetSpellInfo.
  choice.greaterName = greaterName
  choice.normalName = normalName
  choice.name = displayName

  local learnedGreaterID = greaterName and SpellIDByName(greaterName) or nil
  greaterID = learnedGreaterID or greaterID
  if greaterName and IsLearned(greaterName, greaterID) then
    return {
      id=greaterID, name=greaterName, displayName=displayName,
      isGreater=true, choice=choice,
    }
  end

  local learnedNormalID = normalName and SpellIDByName(normalName) or nil
  normalID = learnedNormalID or normalID
  if normalName and IsLearned(normalName, normalID) then
    return {
      id=normalID, name=normalName, displayName=displayName,
      isGreater=false, choice=choice,
    }
  end

  return nil
end

local function ResolvedSelfShields()
  local result = {}
  for _, choice in ipairs(SELF_SHIELD_CHOICES) do
    local spellID = SpellIDByName(choice.name)
    if IsLearned(choice.name, spellID) then
      result[#result + 1] = {
        choice = {
          key = choice.key, name = choice.name, normalName = choice.name,
          normalID = spellID, auraNames = {choice.name}, auraIDs = spellID and {spellID} or {},
        },
        spell = {id=spellID, name=choice.name, displayName=choice.name, isGreater=false},
      }
    end
  end
  return result
end

local function SelfShieldByKey(learned, key)
  for _, entry in ipairs(learned or {}) do
    if entry.choice.key == key then return entry end
  end
  return nil
end

local function CurrentSelfShield(learned)
  local db = EnsureBuffDB()
  local selected = tostring(db.selfShield or "blood")
  if selected == "off" then return nil, "off" end

  local entry = SelfShieldByKey(learned, selected)
  if entry then return entry, selected end

  entry = SelfShieldByKey(learned, "blood") or SelfShieldByKey(learned, "vital")
  if entry then
    db.selfShield = entry.choice.key
    return entry, entry.choice.key
  end

  db.selfShield = "off"
  return nil, "off"
end

local function CycleSelfShield(learned)
  if not learned or #learned == 0 then return end
  local db = EnsureBuffDB()
  local _, selected = CurrentSelfShield(learned)
  local sequence = {}
  for _, key in ipairs({"blood", "vital"}) do
    if SelfShieldByKey(learned, key) then sequence[#sequence + 1] = key end
  end
  sequence[#sequence + 1] = "off"

  local currentIndex = 0
  for index, value in ipairs(sequence) do
    if value == selected then currentIndex = index break end
  end
  currentIndex = currentIndex + 1
  if currentIndex > #sequence then currentIndex = 1 end
  db.selfShield = sequence[currentIndex]
end

local function ResolvedFamilies(className)
  local result = {}
  for _, family in ipairs(BUFF_CATALOG[className] or {}) do
    local resolved = {}
    for _, choice in ipairs(family.choices or {}) do
      local spell = ResolveChoice(choice)
      if spell then resolved[#resolved + 1] = {choice=choice, spell=spell} end
    end
    if #resolved > 0 then
      result[#result + 1] = {definition=family, choices=resolved}
    end
  end
  return result
end

local function CurrentClass()
  local detected = RUI.GetDetectedClass and RUI:GetDetectedClass() or (UnitClass and select(1, UnitClass("player")))
  detected = CanonicalClass(detected)
  return detected, ResolvedFamilies(detected)
end

local function GroupUnits()
  -- Ascension is based on the 3.3 client, so prefer the legacy roster APIs and
  -- fall back to modern APIs when available.
  local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
  if raidCount <= 0 and IsInRaid and IsInRaid() then
    raidCount = GetNumGroupMembers and GetNumGroupMembers() or 0
  end
  if raidCount > 0 then
    local units = {}
    for index=1,raidCount do units[#units + 1] = "raid" .. index end
    return units
  end

  local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
  if partyCount <= 0 and IsInGroup and IsInGroup() then
    partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
  end
  if partyCount > 0 then
    local units = {"player"}
    for index=1,partyCount do units[#units + 1] = "party" .. index end
    return units
  end
  return {"player"}
end

local function UnitRole(unit)
  if GetPartyAssignment then
    local ok, assigned = pcall(GetPartyAssignment, "MAINTANK", unit)
    if ok and assigned then return "TANK" end
  end
  if UnitGroupRolesAssignedKey then
    local ok, role = pcall(UnitGroupRolesAssignedKey, unit)
    if ok and role and role ~= "NONE" then return tostring(role) end
  end
  if UnitGroupRolesAssigned then
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if ok and role and role ~= "NONE" then return tostring(role) end
  end
  return "NONE"
end

local function InfoNameFromID(value)
  value = tonumber(value)
  if not value then return nil end
  if GetSpecializationInfoByID then
    local ok, first, second = pcall(GetSpecializationInfoByID, value)
    if ok and type(first) == "string" and first ~= "" then return first end
    if ok and type(second) == "string" and second ~= "" then return second end
  end
  return nil
end

local function ProbeSpecFunction(functionName, unit)
  local fn = _G and _G[functionName]
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, unit)
  if not ok then return nil end
  if type(a) == "string" and a ~= "" then return a end
  if type(b) == "string" and b ~= "" then return b end
  return InfoNameFromID(a) or InfoNameFromID(b)
end

local function PlayerTalentSpec()
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local ok, count = pcall(GetNumTalentTabs)
  if not ok or type(count) ~= "number" then return nil end
  local bestName, bestPoints = nil, -1
  for index=1,count do
    local tabOK, name, _, points = pcall(GetTalentTabInfo, index)
    if tabOK and type(name) == "string" and type(points) == "number" and points > bestPoints then
      bestName, bestPoints = name, points
    end
  end
  return bestName
end

local function UnitSpecName(unit, className, role)
  local probes = {"UnitSpec", "GetUnitSpec", "GetUnitSpecialization", "GetInspectSpecialization"}
  local spec
  for _, functionName in ipairs(probes) do
    spec = ProbeSpecFunction(functionName, unit)
    if spec then break end
  end
  if not spec and unit == "player" then spec = PlayerTalentSpec() end

  local rule = CLASS_RULES[className]
  if role == "TANK" and rule and rule.tankSpec then return rule.tankSpec end

  if spec and spec ~= "" then
    local specKey = NormalKey(spec)
    if rule and rule.tankSpec and specKey == NormalKey(rule.tankSpec) then return rule.tankSpec end
    for _, alias in ipairs(rule and rule.tankAliases or {}) do
      if specKey == NormalKey(alias) then return rule.tankSpec end
    end
    return spec
  end
  return role == "TANK" and ((rule and rule.tankSpec) or "Tank") or "Other Specs"
end

local POWER_TYPE_NAMES = {
  [0]="MANA", [1]="RAGE", [2]="FOCUS", [3]="ENERGY", [6]="RUNIC_POWER",
}

local function UnitIdentity(unit)
  local localized, token = UnitClass and UnitClass(unit)
  local className = CanonicalClass(localized or token or "Unknown")
  local role = UnitRole(unit)
  local specName = UnitSpecName(unit, className, role)
  local rule = CLASS_RULES[className] or {}
  local runtimeResource
  if UnitPowerType then
    local ok, powerType = pcall(UnitPowerType, unit)
    if ok then runtimeResource = POWER_TYPE_NAMES[tonumber(powerType)] end
  end
  local isTank = role == "TANK" or (rule.tankSpec and NormalKey(specName) == NormalKey(rule.tankSpec))
  if not isTank then
    for _, alias in ipairs(rule.tankAliases or {}) do
      if NormalKey(specName) == NormalKey(alias) then isTank = true break end
    end
  end
  return {
    unit=unit,
    name=UnitName and (UnitName(unit) or unit) or unit,
    className=className,
    classKey=NormalKey(className),
    specName=specName,
    specKey=NormalKey(specName),
    role=role,
    isTank=isTank,
    resource=runtimeResource or rule.resource or "UNKNOWN",
  }
end

local function BuildComposition()
  local buckets, ordered = {}, {}
  local db = EnsureBuffDB()
  for _, unit in ipairs(GroupUnits()) do
    if UnitExists and UnitExists(unit) then
      local identity = UnitIdentity(unit)
      local key = identity.classKey .. "|" .. identity.specKey
      local bucket = buckets[key]
      if not bucket then
        bucket = {
          key=key, className=identity.className, classKey=identity.classKey,
          specName=identity.specName, specKey=identity.specKey,
          resource=identity.resource, isTank=identity.isTank, count=0, members={},
        }
        buckets[key] = bucket
        ordered[#ordered + 1] = bucket
      end
      bucket.count = bucket.count + 1
      bucket.members[#bucket.members + 1] = identity
      db.seenSpecs[identity.classKey] = db.seenSpecs[identity.classKey] or {}
      db.seenSpecs[identity.classKey][identity.specKey] = identity.specName
    end
  end
  table.sort(ordered, function(left, right)
    if left.className ~= right.className then return tostring(left.className) < tostring(right.className) end
    if left.isTank ~= right.isTank then return left.isTank end
    return tostring(left.specName) < tostring(right.specName)
  end)
  activeComposition = ordered
  return ordered
end

local function AssignmentStore(casterClass, familyKey)
  local db = EnsureBuffDB()
  local classKey = NormalKey(casterClass)
  db.assignments[classKey] = db.assignments[classKey] or {}
  db.assignments[classKey][familyKey] = db.assignments[classKey][familyKey] or {}
  return db.assignments[classKey][familyKey]
end

local function DefaultAssignment(family, bucket)
  local firstChoice = family.defaultChoice or (family.choices and family.choices[1] and family.choices[1].key) or nil
  if family.assignment == "BLOODMAGE_OFFERING" then
    -- One target can only receive one Offering. Tanks and physical/non-mana
    -- users receive Sanguinary; non-tank mana users receive Bloodsoaked.
    if bucket.isTank or bucket.resource ~= "MANA" then return "sanguinary" end
    return "bloodsoaked"
  end
  if family.assignment == "KNIGHT_MARK" then
    -- Marks are mutually exclusive on a target. AUTO chooses one sensible
    -- learned Mark for the target bucket; manual assignments can override it.
    if bucket.isTank then return "rivendare" end
    if bucket.resource == "MANA" then return "blaumeux" end
    return "korthazz"
  end
  if family.assignment == "NONE" then return nil end
  return firstChoice
end

local function RuntimeChoiceAvailable(familyRuntime, choiceKey)
  if not choiceKey then return false end
  for _, entry in ipairs(familyRuntime.choices or {}) do
    if entry.choice.key == choiceKey then return true end
  end
  return false
end

local function FirstRuntimeChoice(familyRuntime)
  local entry = familyRuntime.choices and familyRuntime.choices[1]
  return entry and entry.choice.key or nil
end

local function AssignedChoiceKey(casterClass, familyRuntime, bucket)
  local family = familyRuntime.definition or familyRuntime
  local store = AssignmentStore(casterClass, family.key)
  local override = store[bucket.key]
  if override == "__NONE" then return nil, true end
  if override and override ~= "" then
    if RuntimeChoiceAvailable(familyRuntime, override) then return override, true end
    return FirstRuntimeChoice(familyRuntime), true
  end

  local automatic = DefaultAssignment(family, bucket)
  if automatic == nil then return nil, false end
  if RuntimeChoiceAvailable(familyRuntime, automatic) then return automatic, false end
  return FirstRuntimeChoice(familyRuntime), false
end

local function SetAssignmentOverride(casterClass, family, bucket, value)
  local store = AssignmentStore(casterClass, family.key)
  store[bucket.key] = value
end

local function ClearAssignments(casterClass)
  local db = EnsureBuffDB()
  db.assignments[NormalKey(casterClass)] = {}
end

local function ChoiceByKey(familyRuntime, choiceKey)
  for _, entry in ipairs(familyRuntime.choices or {}) do
    if entry.choice.key == choiceKey then return entry end
  end
  return nil
end

local function AuraStatus(unit, entry)
  if not UnitExists or not UnitExists(unit) then return false, nil end
  local choice, spell = entry.choice, entry.spell
  local wantedNames, wantedIDs = {}, {}
  local function AddName(value)
    if value and value ~= "" then wantedNames[NormalizeAuraName(value)] = true end
  end
  local function AddID(value)
    value = tonumber(value)
    if value then wantedIDs[value] = true end
  end
  AddName(choice.name)
  AddName(choice.normalName)
  AddName(choice.greaterName)
  AddName(spell.name)
  for _, value in ipairs(choice.auraNames or {}) do AddName(value) end
  AddID(choice.normalID)
  AddID(choice.greaterID)
  AddID(spell.id)
  for _, value in ipairs(choice.auraIDs or {}) do AddID(value) end

  local categoryState = {}
  for _, category in ipairs(choice.categories or {}) do
    categoryState[category] = {present=false, remaining=nil}
  end

  for index=1,40 do
    local name, _, _, _, _, duration, expirationTime, _, _, _, spellID = UnitBuff(unit, index)
    if not name then break end
    local normalizedName = NormalizeAuraName(name)
    local remaining
    if expirationTime and expirationTime > 0 and GetTime then remaining = math.max(0, expirationTime - GetTime()) end
    if not remaining and duration and duration > 0 then remaining = duration end

    -- An exact normal/Greater family aura always counts as covered.
    if wantedNames[normalizedName] or (spellID and wantedIDs[tonumber(spellID)]) then
      return true, remaining
    end

    -- Otherwise accept the equivalent raid-buff effect supplied by another
    -- class. Multi-effect buffs are covered only when every required category
    -- is present on this specific target.
    for category, state in pairs(categoryState) do
      local lookup = EQUIVALENT_LOOKUPS[category]
      if lookup and lookup[normalizedName] then
        state.present = true
        if remaining and (not state.remaining or remaining < state.remaining) then state.remaining = remaining end
      end
    end
  end

  local hasCategories = false
  local minimumRemaining
  for _, category in ipairs(choice.categories or {}) do
    hasCategories = true
    local state = categoryState[category]
    if not state or not state.present then return false, nil end
    if state.remaining and (not minimumRemaining or state.remaining < minimumRemaining) then
      minimumRemaining = state.remaining
    end
  end
  if hasCategories then return true, minimumRemaining end
  return false, nil
end

local function SpellTexture(spell)
  if not spell or not GetSpellInfo then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  local _, _, texture = GetSpellInfo(spell.id or spell.name)
  return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ApplyButtonColor(button, color)
  if button.bg then button.bg:SetTexture(color[1], color[2], color[3], 0.82) end
  if button.border then button.border:SetBackdropBorderColor(color[1], color[2], color[3], 1) end
end

local function AssignedTargets(casterClass, familyRuntime, choiceKey)
  local targets = {}
  for _, bucket in ipairs(activeComposition) do
    local assignedKey = AssignedChoiceKey(casterClass, familyRuntime, bucket)
    if assignedKey == choiceKey then
      for _, member in ipairs(bucket.members) do targets[#targets + 1] = member end
    end
  end
  return targets
end

local function ChoiceState(casterClass, familyRuntime, entry)
  local targets = AssignedTargets(casterClass, familyRuntime, entry.choice.key)
  local missing, expiring, good = {}, {}, {}
  for _, member in ipairs(targets) do
    local unit = member.unit
    local valid = UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
    if valid then
      local present, remaining = AuraStatus(unit, entry)
      if not present then
        missing[#missing + 1] = member
      elseif remaining and remaining > 0 and remaining < 300 then
        expiring[#expiring + 1] = member
      else
        good[#good + 1] = member
      end
    end
  end

  local status, nextMember
  if #targets == 0 then
    status = "inactive"
  elseif #missing > 0 then
    status, nextMember = "missing", missing[1]
  elseif #expiring > 0 then
    status, nextMember = "expiring", expiring[1]
  else
    status = "ready"
  end
  return {
    status=status, targets=targets, missing=missing, expiring=expiring,
    good=good, nextMember=nextMember,
  }
end

local function FamilyState(casterClass, familyRuntime)
  local result = {
    status="inactive", targets={}, missing={}, expiring={}, good={},
    entries={}, nextEntry=nil, nextMember=nil, displayEntry=nil,
  }
  local firstWithTargets
  local firstMissing
  local firstExpiring

  for _, entry in ipairs(familyRuntime.choices or {}) do
    local state = ChoiceState(casterClass, familyRuntime, entry)
    result.entries[#result.entries + 1] = {entry=entry, state=state}
    if #state.targets > 0 and not firstWithTargets then firstWithTargets = {entry=entry, state=state} end
    for _, member in ipairs(state.targets) do result.targets[#result.targets + 1] = member end
    for _, member in ipairs(state.missing) do result.missing[#result.missing + 1] = member end
    for _, member in ipairs(state.expiring) do result.expiring[#result.expiring + 1] = member end
    for _, member in ipairs(state.good) do result.good[#result.good + 1] = member end
    if state.status == "missing" and not firstMissing then firstMissing = {entry=entry, state=state} end
    if state.status == "expiring" and not firstExpiring then firstExpiring = {entry=entry, state=state} end
  end

  local actionable = firstMissing or firstExpiring
  local display = actionable or firstWithTargets or result.entries[1]
  if actionable then
    result.status = actionable.state.status
    result.nextEntry = actionable.entry
    result.nextMember = actionable.state.nextMember
  elseif firstWithTargets then
    result.status = "ready"
  end
  result.displayEntry = display and display.entry or nil
  return result
end

local function SaveCompactPosition()
  if not compactFrame then return end
  local point, _, relativePoint, x, y = compactFrame:GetPoint(1)
  EnsureBuffDB().position = {point=point, relativePoint=relativePoint, x=x, y=y}
end

local function Font(text, size)
  if RUI.ApplyFont then RUI:ApplyFont(text, size or 10, "OUTLINE") end
end

local function SecureSpellName(spell)
  if not spell then return nil end
  if spell.id and GetSpellInfo then
    local name = GetSpellInfo(spell.id)
    if name and name ~= "" then return name end
  end
  return spell.name
end

local function CreateShieldButton()
  if shieldButton then return shieldButton end
  local button = CreateFrame("Button", "RetreatUIExclusiveShieldButton", compactFrame, "SecureActionButtonTemplate")
  button:SetSize(30, 30)
  button:RegisterForClicks("AnyUp")
  button:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
    insets={left=1,right=1,top=1,bottom=1},
  })
  button.border = button
  button.bg = button:CreateTexture(nil, "BACKGROUND")
  button.bg:SetAllPoints()
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button.icon:SetTexCoord(.08, .92, .08, .92)
  button.count = button:CreateFontString(nil, "OVERLAY")
  Font(button.count, 8)
  button.count:SetPoint("BOTTOMRIGHT", -2, 2)
  button.mode = button:CreateFontString(nil, "OVERLAY")
  Font(button.mode, 7)
  button.mode:SetPoint("TOPLEFT", 2, -1)

  button:SetScript("PostClick", function(_, mouseButton)
    if mouseButton ~= "RightButton" then return end
    if InCombatLockdown and InCombatLockdown() then
      RUI:Print("Shield selection cannot be changed during combat.")
      return
    end
    CycleSelfShield(ResolvedSelfShields())
    refreshPending = true
  end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltipTitle or "Self Shield", 1, 1, 1)
    for _, line in ipairs(self.tooltipLines or {}) do
      GameTooltip:AddLine(line, .82, .82, .82, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  shieldButton = button
  return button
end

local function RefreshShieldButton(leftOffset, slotIndex)
  local learned = ResolvedSelfShields()
  if #learned == 0 then
    if shieldButton then shieldButton:Hide() end
    return false
  end

  local button = CreateShieldButton()
  local selectedEntry, selectedKey = CurrentSelfShield(learned)
  local displayEntry = selectedEntry or SelfShieldByKey(learned, "blood") or SelfShieldByKey(learned, "vital")
  PositionCompactSlot(button, leftOffset, slotIndex)
  button.icon:SetTexture(SpellTexture(displayEntry and displayEntry.spell))
  if button.icon.SetDesaturated then button.icon:SetDesaturated(selectedKey == "off") end

  local status = "inactive"
  local remaining
  if selectedEntry then
    local present
    present, remaining = AuraStatus("player", selectedEntry)
    if not present then status = "missing"
    elseif remaining and remaining > 0 and remaining < 300 then status = "expiring"
    else status = "ready" end
  end
  ApplyButtonColor(button, STATUS[status] or STATUS.unknown)
  button.mode:SetText(selectedKey == "off" and "OFF" or "S")
  button.count:SetText(remaining and remaining > 0 and remaining < 300 and tostring(math.ceil(remaining / 60)) .. "m" or "")

  if not (InCombatLockdown and InCombatLockdown()) then
    local secureSpell = selectedEntry and SecureSpellName(selectedEntry.spell) or nil
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    button:SetAttribute("type1", secureSpell and "spell" or nil)
    button:SetAttribute("spell1", secureSpell)
    button:SetAttribute("unit1", secureSpell and "player" or nil)
    button:SetAttribute("type2", nil)
  end

  local cycleNames = {}
  for _, key in ipairs({"blood", "vital"}) do
    local entry = SelfShieldByKey(learned, key)
    if entry then cycleNames[#cycleNames + 1] = entry.spell.name end
  end
  cycleNames[#cycleNames + 1] = "OFF"
  button.tooltipTitle = selectedEntry and selectedEntry.spell.name or "Self Shield: OFF"
  button.tooltipLines = {
    selectedEntry and "Left-click: Cast on yourself." or "Shield casting is disabled.",
    "Right-click: " .. table.concat(cycleNames, " -> "),
    selectedEntry and (status == "missing" and "Aura missing." or status == "expiring" and "Aura has under 5 minutes remaining." or "Aura has over 5 minutes remaining.") or "No Shield is selected.",
    "Selection is saved across reloads and relogs.",
  }
  button:Show()
  return true
end

local function CreateCompactButton(index)
  local button = CreateFrame("Button", "RetreatUIBuffButton" .. index, compactFrame, "SecureActionButtonTemplate")
  button:SetSize(30, 30)
  button:RegisterForClicks("AnyUp")
  button:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
    insets={left=1,right=1,top=1,bottom=1},
  })
  button.border = button
  button.bg = button:CreateTexture(nil, "BACKGROUND")
  button.bg:SetAllPoints()
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button.icon:SetTexCoord(.08, .92, .08, .92)
  button.count = button:CreateFontString(nil, "OVERLAY")
  Font(button.count, 9)
  button.count:SetPoint("BOTTOMRIGHT", -2, 2)
  button.rank = button:CreateFontString(nil, "OVERLAY")
  Font(button.rank, 8)
  button.rank:SetPoint("TOPLEFT", 2, -1)

  button:SetScript("PostClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
      if RUI.ToggleBuffAssignmentManager then RUI:ToggleBuffAssignmentManager() end
    end
  end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltipTitle or "Buff", 1, 1, 1)
    for _, line in ipairs(self.tooltipLines or {}) do
      GameTooltip:AddLine(line, .82, .82, .82, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  compactButtons[index] = button
  return button
end

local function BuildCompact()
  if compactFrame then return compactFrame end
  compactFrame = CreateFrame("Frame", "RetreatUIBuffBar", UIParent)
  compactFrame:SetSize(40, 34)
  compactFrame:SetFrameStrata("MEDIUM")
  compactFrame:SetClampedToScreen(true)
  compactFrame:SetMovable(true)
  compactFrame:EnableMouse(true)
  compactFrame:RegisterForDrag("LeftButton")
  compactFrame:SetScript("OnDragStart", function(self)
    local db = EnsureBuffDB()
    if not db.locked and not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
  end)
  compactFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveCompactPosition()
  end)
  compactFrame:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
    insets={left=1,right=1,top=1,bottom=1},
  })
  compactFrame:SetBackdropColor(0.025, 0.018, 0.018, 0.88)
  compactFrame:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

  -- A dedicated drag handle is required because the secure buff buttons cover
  -- nearly the entire bar and consume mouse input themselves.
  compactFrame.dragHandle = CreateFrame("Button", nil, compactFrame)
  compactFrame.dragHandle:SetSize(16, 30)
  compactFrame.dragHandle:SetPoint("LEFT", 2, 0)
  compactFrame.dragHandle:RegisterForDrag("LeftButton")
  compactFrame.dragHandle.text = compactFrame.dragHandle:CreateFontString(nil, "OVERLAY")
  Font(compactFrame.dragHandle.text, 11)
  compactFrame.dragHandle.text:SetPoint("CENTER")
  compactFrame.dragHandle.text:SetText("<>")
  compactFrame.dragHandle:SetScript("OnDragStart", function()
    local db = EnsureBuffDB()
    if not db.locked and not (InCombatLockdown and InCombatLockdown()) then
      compactFrame:StartMoving()
    end
  end)
  compactFrame.dragHandle:SetScript("OnDragStop", function()
    compactFrame:StopMovingOrSizing()
    SaveCompactPosition()
  end)
  compactFrame.dragHandle:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(EnsureBuffDB().locked and "Buff bar locked" or "Move buff bar", 1, 1, 1)
    GameTooltip:AddLine(EnsureBuffDB().locked and "Click U/L to unlock it first." or "Drag this handle to move the bar.", .8, .8, .8, true)
    GameTooltip:Show()
  end)
  compactFrame.dragHandle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  local db = EnsureBuffDB()
  local pos = db.position
  if pos then
    compactFrame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 170)
  else
    compactFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
  end

  compactFrame.lock = CreateFrame("Button", nil, compactFrame)
  compactFrame.lock:SetSize(16, 30)
  compactFrame.lock:SetPoint("RIGHT", -2, 0)
  compactFrame.lock.text = compactFrame.lock:CreateFontString(nil, "OVERLAY")
  Font(compactFrame.lock.text, 9)
  compactFrame.lock.text:SetPoint("CENTER")
  local function UpdateLockText()
    local locked = EnsureBuffDB().locked
    compactFrame.lock.text:SetText(locked and "L" or "U")
    if locked then
      compactFrame.dragHandle:Hide()
    else
      compactFrame.dragHandle:Show()
    end
  end
  compactFrame.lock:SetScript("OnClick", function()
    local db = EnsureBuffDB()
    db.locked = not db.locked
    UpdateLockText()
    refreshPending = true
  end)
  compactFrame.lock:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(EnsureBuffDB().locked and "Unlock buff bar" or "Lock buff bar", 1, 1, 1)
    GameTooltip:AddLine(EnsureBuffDB().locked and "Click to allow moving the bar." or "Click to prevent accidental movement.", .8, .8, .8, true)
    GameTooltip:Show()
  end)
  compactFrame.lock:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  UpdateLockText()

  compactFrame.manager = CreateFrame("Button", nil, compactFrame)
  compactFrame.manager:SetSize(16, 30)
  compactFrame.manager:SetPoint("RIGHT", compactFrame.lock, "LEFT", 0, 0)
  compactFrame.manager.text = compactFrame.manager:CreateFontString(nil, "OVERLAY")
  Font(compactFrame.manager.text, 11)
  compactFrame.manager.text:SetPoint("CENTER")
  compactFrame.manager.text:SetText("+")
  compactFrame.manager:SetScript("OnClick", function()
    if RUI.ToggleBuffAssignmentManager then RUI:ToggleBuffAssignmentManager() end
  end)
  compactFrame.manager:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Buff assignments", 1, 1, 1)
    GameTooltip:AddLine("Click to open the class/spec assignment manager.", .8, .8, .8, true)
    GameTooltip:AddLine("Unlock the bar, then drag the dark background to move it.", .65, .65, .65, true)
    GameTooltip:Show()
  end)
  compactFrame.manager:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return compactFrame
end

local function RefreshCompact()
  -- SecureActionButtonTemplate frames cannot be safely created, moved, shown,
  -- hidden or retargeted during combat. Keep the last valid secure layout and
  -- refresh immediately on PLAYER_REGEN_ENABLED instead.
  if InCombatLockdown and InCombatLockdown() then return end
  BuildCompact()
  activeClassName, activeFamilies = CurrentClass()
  BuildComposition()

  local leftOffset = EnsureBuffDB().locked and 2 or 18
  local visible = 0
  if RefreshShieldButton(leftOffset, visible + 1) then visible = visible + 1 end

  local visibleAssignedBuffs = 0
  for _, familyRuntime in ipairs(activeFamilies or {}) do
    local state = FamilyState(activeClassName, familyRuntime)
    if #state.targets > 0 then
      visible = visible + 1
      visibleAssignedBuffs = visibleAssignedBuffs + 1
      local button = compactButtons[visibleAssignedBuffs] or CreateCompactButton(visibleAssignedBuffs)
      local entry = state.nextEntry or state.displayEntry
      button.familyRuntime = familyRuntime
      button.entry = entry
      button.state = state
      PositionCompactSlot(button, leftOffset, visible)
      button.icon:SetTexture(SpellTexture(entry and entry.spell))
      if button.icon.SetDesaturated then button.icon:SetDesaturated(false) end
      ApplyButtonColor(button, STATUS[state.status] or STATUS.unknown)
      button.count:SetText(#state.missing > 0 and tostring(#state.missing) or (#state.expiring > 0 and tostring(#state.expiring) or ""))
      button.rank:SetText(entry and entry.spell.isGreater and "+" or "")

      if not (InCombatLockdown and InCombatLockdown()) then
        local secureSpell = state.nextMember and entry and SecureSpellName(entry.spell) or nil
        local secureUnit = state.nextMember and state.nextMember.unit or nil
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("unit", nil)
        button:SetAttribute("type1", secureSpell and "spell" or nil)
        button:SetAttribute("spell1", secureSpell)
        button:SetAttribute("unit1", secureUnit)
        button:SetAttribute("type2", nil)
        button:SetAttribute("spell2", nil)
        button:SetAttribute("unit2", nil)
      end

      local lines = {}
      for _, choiceState in ipairs(state.entries) do
        if #choiceState.state.targets > 0 then
          local choiceName = choiceState.entry.spell.name
          local detail
          if #choiceState.state.missing > 0 then
            detail = tostring(#choiceState.state.missing) .. " missing"
          elseif #choiceState.state.expiring > 0 then
            detail = tostring(#choiceState.state.expiring) .. " under 5 minutes"
          else
            detail = "covered"
          end
          lines[#lines + 1] = choiceName .. ": " .. detail
        end
      end
      if state.nextMember and entry then
        lines[#lines + 1] = "Left-click: " .. entry.spell.name .. " on " .. state.nextMember.name
      else
        lines[#lines + 1] = "All assigned players are covered."
      end
      if #(familyRuntime.choices or {}) > 1 then
        lines[#lines + 1] = "The button automatically switches between exclusive choices."
      end
      lines[#lines + 1] = "Right-click: Open assignments"
      button.tooltipTitle = familyRuntime.definition.label or (entry and entry.spell.name) or "Buff"
      button.tooltipLines = lines
      button:Show()
    end
  end

  for index=visibleAssignedBuffs+1,#compactButtons do compactButtons[index]:Hide() end
  local sideWidth = EnsureBuffDB().locked and 36 or 52
  local usedColumns = math.min(COMPACT_COLUMNS, math.max(1, visible))
  local usedRows = math.max(1, math.ceil(visible / COMPACT_COLUMNS))
  compactFrame:SetWidth(math.max(54, (usedColumns * COMPACT_SLOT) + sideWidth))
  compactFrame:SetHeight((usedRows * COMPACT_SLOT) + 2)

  local db = EnsureBuffDB()
  if visible == 0 or not db.barShown then compactFrame:Hide() else compactFrame:Show() end
end

local function ManagerCellText(familyRuntime, choiceKey)
  if not choiceKey then return "OFF", nil end
  local entry = ChoiceByKey(familyRuntime, choiceKey)
  if not entry then return "UNAVAILABLE", nil end
  return entry.choice.name, entry
end

local function HideManagerRows(from)
  for index=from,#managerRows do managerRows[index]:Hide() end
end

local MANAGER_LABEL_WIDTH = 174
local MANAGER_CELL_WIDTH = 152
local MANAGER_CELL_STEP = 160
local MANAGER_ROW_HEIGHT = 36
local MANAGER_MIN_HEIGHT = 190
local MANAGER_MAX_HEIGHT = 500

local function ManagerTheme()
  return RUI:GetTheme()
end

local function SetCellBorder(cell, red, green, blue, alpha)
  cell.borderColor = {red, green, blue, alpha or 1}
  cell:SetBackdropBorderColor(red, green, blue, alpha or 1)
end

local function CreateManagerRow(index)
  local theme = ManagerTheme()
  local row = CreateFrame("Frame", nil, managerFrame.content)
  row:SetHeight(MANAGER_ROW_HEIGHT)

  row.label = row:CreateFontString(nil, "OVERLAY")
  Font(row.label, 10)
  row.label:SetPoint("LEFT", 6, 0)
  row.label:SetWidth(MANAGER_LABEL_WIDTH - 8)
  row.label:SetJustifyH("LEFT")
  row.label:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)

  row.divider = row:CreateTexture(nil, "BORDER")
  row.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
  row.divider:SetPoint("BOTTOMLEFT", 4, 0)
  row.divider:SetPoint("BOTTOMRIGHT", -4, 0)
  row.divider:SetHeight(1)
  row.divider:SetVertexColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.22)

  row.cells = {}
  managerRows[index] = row
  return row
end

local function CreateManagerCell(row, column)
  local theme = ManagerTheme()
  local cell = CreateFrame("Button", nil, row)
  cell:SetSize(MANAGER_CELL_WIDTH, 30)
  cell:SetPoint("LEFT", MANAGER_LABEL_WIDTH + 4 + ((column - 1) * MANAGER_CELL_STEP), 0)
  cell:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  cell:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.98)
  SetCellBorder(cell, theme.dim[1], theme.dim[2], theme.dim[3], 0.65)

  cell.icon = cell:CreateTexture(nil, "ARTWORK")
  cell.icon:SetSize(22, 22)
  cell.icon:SetPoint("LEFT", 4, 0)
  cell.icon:SetTexCoord(.08, .92, .08, .92)

  cell.text = cell:CreateFontString(nil, "OVERLAY")
  Font(cell.text, 9)
  cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 6, 0)
  cell.text:SetPoint("RIGHT", -38, 0)
  cell.text:SetJustifyH("LEFT")
  cell.text:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)

  cell.badge = CreateFrame("Frame", nil, cell)
  cell.badge:SetSize(31, 14)
  cell.badge:SetPoint("RIGHT", -4, 0)
  cell.badge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  cell.badge:SetBackdropColor(theme.panelSoft[1], theme.panelSoft[2], theme.panelSoft[3], 0.88)
  cell.badge:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.45)
  cell.badge.text = cell.badge:CreateFontString(nil, "OVERLAY")
  Font(cell.badge.text, 7)
  cell.badge.text:SetPoint("CENTER", 0, 0)

  cell:SetScript("OnEnter", function(self)
    local accent = ManagerTheme().accent
    self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.95)
    if GameTooltip and self.tooltipTitle then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
      for _, line in ipairs(self.tooltipLines or {}) do
        GameTooltip:AddLine(line, 0.76, 0.78, 0.82, true)
      end
      GameTooltip:Show()
    end
  end)
  cell:SetScript("OnLeave", function(self)
    local color = self.borderColor or {0.25, 0.25, 0.25, 1}
    self:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
    if GameTooltip then GameTooltip:Hide() end
  end)

  row.cells[column] = cell
  return cell
end

local function CycleAssignment(familyRuntime, bucket, direction)
  local family = familyRuntime.definition
  local store = AssignmentStore(activeClassName, family.key)
  local current = store[bucket.key]

  -- AUTO has no stored value, so begin cycling from the choice currently
  -- resolved by the automatic class/spec rules. OFF must remain an explicit
  -- state; otherwise nil would be mistaken for AUTO and skip the first choice.
  if current == nil or (current ~= "__NONE" and not RuntimeChoiceAvailable(familyRuntime, current)) then
    current = AssignedChoiceKey(activeClassName, familyRuntime, bucket)
  end

  local sequence = {}
  for _, entry in ipairs(familyRuntime.choices or {}) do sequence[#sequence + 1] = entry.choice.key end
  sequence[#sequence + 1] = "__NONE"

  local currentIndex = 0
  for index, value in ipairs(sequence) do
    if value == current then currentIndex = index break end
  end

  currentIndex = currentIndex + (direction or 1)
  if currentIndex > #sequence then currentIndex = 1 end
  if currentIndex < 1 then currentIndex = #sequence end
  SetAssignmentOverride(activeClassName, family, bucket, sequence[currentIndex])
  refreshPending = true
end

local function BuildManager()
  if managerFrame then return managerFrame end
  local theme = ManagerTheme()

  managerFrame = CreateFrame("Frame", "RetreatUIBuffAssignmentManager", UIParent)
  managerFrame:SetSize(700, 220)
  managerFrame:SetPoint("CENTER")
  managerFrame:SetFrameStrata("DIALOG")
  managerFrame:SetClampedToScreen(true)
  managerFrame:SetMovable(true)
  managerFrame:EnableMouse(true)
  managerFrame:RegisterForDrag("LeftButton")
  managerFrame:SetScript("OnDragStart", function(self)
    if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
  end)
  managerFrame:SetScript("OnDragStop", managerFrame.StopMovingOrSizing)
  RUI:SkinFrame(managerFrame, theme.background, {theme.dim[1], theme.dim[2], theme.dim[3], 0.72})

  managerFrame.accentLine = managerFrame:CreateTexture(nil, "ARTWORK")
  managerFrame.accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  managerFrame.accentLine:SetPoint("TOPLEFT", 1, -1)
  managerFrame.accentLine:SetPoint("TOPRIGHT", -1, -1)
  managerFrame.accentLine:SetHeight(2)
  managerFrame.accentLine:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.88)

  managerFrame.title = managerFrame:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.title, 14)
  managerFrame.title:SetPoint("TOPLEFT", 16, -14)
  managerFrame.title:SetText("Buff Assignments")
  managerFrame.title:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)

  managerFrame.classTitle = managerFrame:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.classTitle, 10)
  managerFrame.classTitle:SetPoint("LEFT", managerFrame.title, "RIGHT", 10, 0)
  managerFrame.classTitle:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

  managerFrame.help = managerFrame:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.help, 9)
  managerFrame.help:SetPoint("TOPLEFT", 16, -39)
  managerFrame.help:SetText("Left-click changes an assignment. Right-click restores Auto.")
  managerFrame.help:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)

  managerFrame.close = CreateFrame("Button", nil, managerFrame)
  managerFrame.close:SetSize(22, 22)
  managerFrame.close:SetPoint("TOPRIGHT", -10, -10)
  managerFrame.close:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  managerFrame.close:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.9)
  managerFrame.close:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  managerFrame.close.text = managerFrame.close:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.close.text, 14)
  managerFrame.close.text:SetPoint("CENTER", 0, 1)
  managerFrame.close.text:SetText("×")
  managerFrame.close.text:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  managerFrame.close:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.9)
    self.closeHover = true
  end)
  managerFrame.close:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
    self.closeHover = false
  end)
  managerFrame.close:SetScript("OnClick", function() managerFrame:Hide() end)

  managerFrame.header = CreateFrame("Frame", nil, managerFrame)
  managerFrame.header:SetPoint("TOPLEFT", 14, -66)
  managerFrame.header:SetPoint("TOPRIGHT", -14, -66)
  managerFrame.header:SetHeight(28)
  managerFrame.header:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
  managerFrame.header:SetBackdropColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.55)

  managerFrame.classHeader = managerFrame.header:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.classHeader, 9)
  managerFrame.classHeader:SetPoint("LEFT", 6, 0)
  managerFrame.classHeader:SetWidth(MANAGER_LABEL_WIDTH - 8)
  managerFrame.classHeader:SetJustifyH("LEFT")
  managerFrame.classHeader:SetText("Class / Spec")
  managerFrame.classHeader:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)

  managerFrame.scroll = CreateFrame("ScrollFrame", nil, managerFrame)
  managerFrame.scroll:SetPoint("TOPLEFT", 14, -94)
  managerFrame.scroll:SetPoint("BOTTOMRIGHT", -18, 50)
  managerFrame.scroll:EnableMouseWheel(true)

  managerFrame.content = CreateFrame("Frame", nil, managerFrame.scroll)
  managerFrame.content:SetSize(660, 36)
  managerFrame.scroll:SetScrollChild(managerFrame.content)

  managerFrame.scrollBar = CreateFrame("Slider", nil, managerFrame)
  managerFrame.scrollBar:SetOrientation("VERTICAL")
  managerFrame.scrollBar:SetPoint("TOPRIGHT", -9, -96)
  managerFrame.scrollBar:SetPoint("BOTTOMRIGHT", -9, 52)
  managerFrame.scrollBar:SetWidth(5)
  managerFrame.scrollBar:SetMinMaxValues(0, 0)
  managerFrame.scrollBar:SetValueStep(MANAGER_ROW_HEIGHT)
  managerFrame.scrollBar:SetValue(0)
  managerFrame.scrollBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
  managerFrame.scrollBar:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.65)
  local thumb = managerFrame.scrollBar:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
  thumb:SetSize(5, 28)
  thumb:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.72)
  managerFrame.scrollBar:SetThumbTexture(thumb)
  managerFrame.scrollBar:SetScript("OnValueChanged", function(_, value)
    managerFrame.scroll:SetVerticalScroll(value or 0)
  end)
  managerFrame.scroll:SetScript("OnMouseWheel", function(_, delta)
    if not managerFrame.scrollBar:IsShown() then return end
    local current = managerFrame.scrollBar:GetValue() or 0
    managerFrame.scrollBar:SetValue(current - (delta * MANAGER_ROW_HEIGHT))
  end)

  managerFrame.footerLine = managerFrame:CreateTexture(nil, "BORDER")
  managerFrame.footerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  managerFrame.footerLine:SetPoint("BOTTOMLEFT", 14, 44)
  managerFrame.footerLine:SetPoint("BOTTOMRIGHT", -14, 44)
  managerFrame.footerLine:SetHeight(1)
  managerFrame.footerLine:SetVertexColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.26)

  managerFrame.reset = CreateFrame("Button", nil, managerFrame)
  managerFrame.reset:SetSize(124, 26)
  managerFrame.reset:SetPoint("BOTTOMLEFT", 14, 10)
  managerFrame.reset:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  managerFrame.reset:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.94)
  managerFrame.reset:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  managerFrame.reset.text = managerFrame.reset:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.reset.text, 9)
  managerFrame.reset.text:SetPoint("CENTER")
  managerFrame.reset.text:SetText("Reset all to Auto")
  managerFrame.reset.text:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  managerFrame.reset:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.85)
  end)
  managerFrame.reset:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  end)
  managerFrame.reset:SetScript("OnClick", function()
    if activeClassName then ClearAssignments(activeClassName) end
    refreshPending = true
  end)

  managerFrame.empty = managerFrame.content:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.empty, 10)
  managerFrame.empty:SetPoint("TOPLEFT", 6, -10)
  managerFrame.empty:SetText("No learned Greater-capable class buffs were found for this character.")
  managerFrame.empty:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)

  managerFrame:Hide()
  return managerFrame
end

local function RefreshManager()
  if not managerFrame or not managerFrame:IsShown() then return end
  activeClassName, activeFamilies = CurrentClass()
  local composition = BuildComposition()
  local theme = ManagerTheme()

  managerFrame.classTitle:SetText("— " .. tostring(activeClassName or "Unknown"))

  for index, header in ipairs(managerHeaders) do header:Hide() end
  local familyCount = #(activeFamilies or {})
  local frameWidth = math.max(500, 224 + (familyCount * MANAGER_CELL_STEP))
  managerFrame:SetWidth(math.min(920, frameWidth))
  managerFrame.content:SetWidth(math.max(440, frameWidth - 38))

  for column, familyRuntime in ipairs(activeFamilies or {}) do
    local header = managerHeaders[column]
    if not header then
      header = managerFrame.header:CreateFontString(nil, "OVERLAY")
      Font(header, 9)
      managerHeaders[column] = header
    end
    header:ClearAllPoints()
    header:SetPoint("LEFT", MANAGER_LABEL_WIDTH + 4 + ((column - 1) * MANAGER_CELL_STEP), 0)
    header:SetWidth(MANAGER_CELL_WIDTH)
    header:SetJustifyH("CENTER")
    header:SetText(familyRuntime.definition.label or familyRuntime.definition.key)
    header:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
    header:Show()
  end

  if familyCount == 0 then managerFrame.empty:Show() else managerFrame.empty:Hide() end
  local usedRows = 0
  if familyCount > 0 then
    for _, bucket in ipairs(composition) do
      usedRows = usedRows + 1
      local row = managerRows[usedRows] or CreateManagerRow(usedRows)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -((usedRows - 1) * MANAGER_ROW_HEIGHT))
      row:SetPoint("RIGHT", managerFrame.content, "RIGHT", 0, 0)
      row.bucket = bucket

      local roleText = bucket.isTank and "  •  Tank" or ""
      local countText = bucket.count > 1 and ("  ×" .. bucket.count) or ""
      row.label:SetText(tostring(bucket.className) .. " — " .. tostring(bucket.specName) .. roleText .. countText)

      for column, familyRuntime in ipairs(activeFamilies) do
        local cell = row.cells[column] or CreateManagerCell(row, column)
        local choiceKey, manual = AssignedChoiceKey(activeClassName, familyRuntime, bucket)
        local text, entry = ManagerCellText(familyRuntime, choiceKey)
        cell.familyRuntime = familyRuntime
        cell.bucket = bucket
        cell.text:SetText(text == "OFF" and "Off" or text)

        if manual then
          cell.badge.text:SetText("SET")
          cell.badge.text:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
          cell.badge:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.5)
        else
          cell.badge.text:SetText("AUTO")
          cell.badge.text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
          cell.badge:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.38)
        end

        if entry then
          cell.icon:SetTexture(SpellTexture(entry.spell))
          cell.icon:SetTexCoord(.08, .92, .08, .92)
          cell.icon:SetVertexColor(1, 1, 1, 1)
          if cell.icon.SetDesaturated then cell.icon:SetDesaturated(false) end
          SetCellBorder(cell, theme.accent[1] * 0.48, theme.accent[2] * 0.48, theme.accent[3] * 0.48, 0.88)
        else
          cell.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
          cell.icon:SetTexCoord(0, 1, 0, 1)
          cell.icon:SetVertexColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.82)
          if cell.icon.SetDesaturated then cell.icon:SetDesaturated(false) end
          SetCellBorder(cell, theme.dim[1], theme.dim[2], theme.dim[3], 0.58)
        end

        cell.tooltipTitle = familyRuntime.definition.label or familyRuntime.definition.key
        cell.tooltipLines = {
          (manual and "Assignment: Custom" or "Assignment: Auto"),
          "Selected: " .. tostring(text == "OFF" and "Off" or text),
          "Left-click: Change selection",
          "Right-click: Restore Auto",
        }

        cell:SetScript("OnClick", function(self, mouseButton)
          if mouseButton == "RightButton" then
            SetAssignmentOverride(activeClassName, self.familyRuntime.definition, self.bucket, nil)
          else
            CycleAssignment(self.familyRuntime, self.bucket, 1)
          end
          refreshPending = true
        end)
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        cell:Show()
      end
      for column=familyCount+1,#row.cells do row.cells[column]:Hide() end
      row:Show()
    end
  end
  HideManagerRows(usedRows + 1)

  local contentHeight = math.max(MANAGER_ROW_HEIGHT, usedRows * MANAGER_ROW_HEIGHT)
  managerFrame.content:SetHeight(contentHeight)

  local desiredHeight = 140 + contentHeight
  managerFrame:SetHeight(math.max(MANAGER_MIN_HEIGHT, math.min(MANAGER_MAX_HEIGHT, desiredHeight)))

  local viewportHeight = managerFrame.scroll:GetHeight() or MANAGER_ROW_HEIGHT
  local maxScroll = math.max(0, contentHeight - viewportHeight)
  managerFrame.scrollBar:SetMinMaxValues(0, maxScroll)
  if maxScroll > 0 then
    managerFrame.scrollBar:Show()
    local current = math.min(managerFrame.scrollBar:GetValue() or 0, maxScroll)
    managerFrame.scrollBar:SetValue(current)
  else
    managerFrame.scrollBar:SetValue(0)
    managerFrame.scroll:SetVerticalScroll(0)
    managerFrame.scrollBar:Hide()
  end
end

function RUI:ToggleBuffAssignmentManager()
  local manager = BuildManager()
  if manager:IsShown() then
    manager:Hide()
  else
    manager:Show()
    RefreshManager()
  end
end

function RUI:ToggleBuffManager()
  BuildCompact()
  local db = EnsureBuffDB()
  db.barShown = not db.barShown
  RefreshCompact()
end

local function PrintStatus()
  local className, families = CurrentClass()
  RUI:Print("Buff Manager class: " .. tostring(className))
  RUI:Print("Learned buff families: " .. tostring(#(families or {})))
  local learnedShields = ResolvedSelfShields()
  local _, selectedShield = CurrentSelfShield(learnedShields)
  RUI:Print("Self Shield: " .. tostring(selectedShield) .. " (" .. tostring(#learnedShields) .. " learned)")
  for _, familyRuntime in ipairs(families or {}) do
    local names = {}
    for _, entry in ipairs(familyRuntime.choices or {}) do
      names[#names + 1] = entry.spell.name
    end
    RUI:Print((familyRuntime.definition.label or familyRuntime.definition.key) .. ": " .. table.concat(names, ", "))
  end
end

SLASH_RETREATUIBUFFS1 = "/ruibuffs"
SlashCmdList.RETREATUIBUFFS = function(message)
  message = string.lower(tostring(message or "")):gsub("^%s+", ""):gsub("%s+$", "")
  if message == "manager" or message == "assign" or message == "assignments" then
    RUI:ToggleBuffAssignmentManager()
  elseif message == "reset" then
    local className = select(1, CurrentClass())
    ClearAssignments(className)
    RUI:Print("Buff assignments reset to automatic defaults for " .. tostring(className) .. ".")
    refreshPending = true
  elseif message == "status" or message == "debug" then
    PrintStatus()
  else
    RUI:ToggleBuffManager()
  end
end

local events = CreateFrame("Frame")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "UNIT_AURA",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
  "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "ASCENSION_KNOWN_ENTRIES_UPDATED", "LEARNED_SPELL_IN_TAB",
  "PLAYER_ROLES_ASSIGNED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
    or event == "CHARACTER_POINTS_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
    or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED"
    or event == "ASCENSION_KNOWN_ENTRIES_UPDATED" or event == "LEARNED_SPELL_IN_TAB" then
    if RUI.ScanSpellbook then RUI:ScanSpellbook() end
  end
  if event == "PLAYER_LOGIN" then
    BuildCompact()
    BuildManager()
  end
  refreshPending = true
end)

events:SetScript("OnUpdate", function(_, elapsed)
  refreshElapsed = refreshElapsed + elapsed
  if not refreshPending and refreshElapsed < 0.50 then return end
  if refreshElapsed < 0.15 then return end
  refreshElapsed = 0
  refreshPending = false
  RefreshCompact()
  RefreshManager()
end)
