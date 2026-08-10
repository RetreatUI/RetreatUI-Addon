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
  unavailable = {0.42, 0.34, 0.18, 1},
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
    "Enduring Shout",
    "Sanguinary Offering", "Greater Sanguinary Offering",
    "Mark of Rivendare", "Greater Mark of Rivendare",
    "Foul Mandate", "Greater Foul Mandate",
    "Rite of Resolve", "Greater Rite of Resolve",
  },
  STRENGTH = {
    "Mark of Korth'azz", "Greater Mark of Korth'azz",
    "Rite of Power", "Greater Rite of Power",
  },
  MP5 = {
    "Whispers of Y'Shaarj", "Greater Whispers of Y'Shaarj",
    "Grove Instinct", "Greater Grove Instinct",
    "Seal of Al'ar", "Greater Seal of Al'ar",
    "Call of the Wind", "Greater Call of the Wind",
    "Devotion of Grace", "Greater Devotion of Grace",
    "Mana Module", "Greater Mana Module",
  },
  RESOURCE_COST = {
    "Mark of Zeliek", "Greater Mark of Zeliek",
    "Etching of the Magi", "Greater Etching of the Magi",
    "Etching of Magi", "Greater Etching of Magi",
    "Devotion of Grace", "Greater Devotion of Grace",
    "Resourceful Wuju", "Greater Resourceful Wuju",
  },
  ATTACK_POWER = {
    "Woodsman's Adaptation", "Greater Woodsman's Adaptation",
    "Primal Instinct", "Greater Primal Instinct",
    "Devotion of Dawn", "Greater Devotion of Dawn",
    "Power Module", "Greater Power Module",
    "Power Wuju", "Greater Power Wuju",
  },
  STATS = {
    "Man'ari Intuition", "Greater Man'ari Intuition",
    "Earthen Endurance", "Greater Earthen Endurance",
    "Whispers of N'Zoth", "Greater Whispers of N'Zoth",
    "Etching of the Leylines", "Greater Etching of the Leylines",
    "Etching of Leylines", "Greater Etching of Leylines",
    "Devotion of Emperors", "Greater Devotion of Emperors",
    "Gift of Fervor", "Greater Gift of Fervor",
    "Crusader's Oath", "Greater Crusader's Oath",
    "Beetle Pheromones", "Greater Beetle Pheromones",
    "Knight's Edict", "Greater Knight's Edict",
  },
  SPELL_POWER = {
    "Whispers of C'Thun", "Greater Whispers of C'Thun",
    "Mark of Blaumeux", "Greater Mark of Blaumeux",
    "Grim Mandate", "Greater Grim Mandate",
    "Devotion of Radiance", "Greater Devotion of Radiance",
    "Toxic Pheromones", "Greater Toxic Pheromones",
    "Witching Edict", "Greater Witching Edict",
  },
  AGILITY = {
    "Brutal Shout",
    "Illidari Intuition", "Greater Illidari Intuition",
    "Etching of the Dextrous", "Greater Etching of the Dextrous",
    "Etching of Dexterous", "Greater Etching of Dexterous",
    "Gift of Zeal", "Greater Gift of Zeal",
    "Spider Pheromones", "Greater Spider Pheromones",
    "Inquisitor's Edict", "Greater Inquisitor's Edict",
  },
  ARMOR = {
    "Man'ari Intuition", "Greater Man'ari Intuition",
    "Earthen Endurance", "Greater Earthen Endurance",
    "Beetle Pheromones", "Greater Beetle Pheromones",
    "Knight's Edict", "Greater Knight's Edict",
  },
  INTELLECT = {
    "Nozdormu's Wisdom", "Greater Nozdormu's Wisdom",
    "Seal of Alysrazor", "Greater Seal of Alysrazor",
    "Seal of Alyrazor", "Greater Seal of Alyrazor",
    "Celestial Mind", "Greater Celestial Mind",
    "Call of the Storm", "Greater Call of the Storm",
  },
  SPIRIT = {
    "Chromie's Wisdom", "Greater Chromie's Wisdom",
    "Spirit Wuju", "Greater Spirit Wuju",
  },
  ARCANE_RESISTANCE = {
    "Mark of Zeliek", "Greater Mark of Zeliek",
    "Arcane Protection", "Greater Arcane Protection",
  },
  FIRE_RESISTANCE = {
    "Mark of Korth'azz", "Greater Mark of Korth'azz",
    "Fire Protection", "Greater Fire Protection",
  },
  FROST_RESISTANCE = {
    "Mark of Rivendare", "Greater Mark of Rivendare",
  },
  NATURE_RESISTANCE = {
    "Essence of Nature", "Greater Essence of Nature",
    "Wild Blessing", "Greater Wild Blessing",
  },
  ALL_RESISTANCE = {
    "Earthen Endurance", "Greater Earthen Endurance",
    "Rite of Perseverance", "Greater Rite of Perseverance",
    "Rite of Perseverence", "Greater Rite of Perseverence",
    "Call of the Lightning", "Greater Call of the Lightning",
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
  Barbarian = {
    {key="brutal_shout", label="Brutal Shout", assignment="ALL", choices={
      BuffPair("brutal", "Brutal Shout", nil, nil, nil, {categories={"AGILITY"}}),
    }},
    {key="enduring_shout", label="Enduring Shout", assignment="ALL", choices={
      BuffPair("enduring", "Enduring Shout", nil, nil, nil, {categories={"STAMINA"}}),
    }},
  },

  Bloodmage = {
    {key="bloodthorns", label="Bloodthorns", assignment="ALL", choices={
      BuffPair("bloodthorns", "Bloodthorns", 501664, "Greater Bloodthorns", 572116),
    }},
    {key="offering", label="Sanguinary Offering", assignment="ALL", choices={
      BuffPair("sanguinary", "Sanguinary Offering", 707337, "Greater Sanguinary Offering", 680299, {categories={"STAMINA"}}),
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
      BuffPair("yshaarj", "Whispers of Y'shaarj", 561391, "Greater Whispers of Y'shaarj", 561392, {categories={"MP5"}}),
    }},
  },

  Felsworn = {
    {key="illidari_intuition", label="Illidari Intuition", assignment="ALL", choices={
      BuffPair("agility", "Illidari Intuition", 501329, "Greater Illidari Intuition", 680308, {categories={"AGILITY"}}),
    }},
    {key="manari_intuition", label="Man'ari Intuition", assignment="ALL", choices={
      BuffPair("armor_stats", "Man'ari Intuition", 523484, "Greater Man'ari Intuition", 523495, {categories={"ARMOR", "STATS"}}),
    }},
  },

  Guardian = {
    {key="honor", label="Honor", assignment="ALL", choices={
      BuffPair("honor", "Honor", 301232, "Greater Honor", 680280),
    }},
    {key="fire_protection", label="Fire Protection", assignment="ALL", choices={
      BuffPair("fire_resistance", "Fire Protection", 582535, "Greater Fire Protection", 582536, {categories={"FIRE_RESISTANCE"}}),
    }},
  },

  ["Knight of Xoroth"] = {
    {key="marks_of_xoroth", label="Marks of Xoroth", assignment="KNIGHT_MARK", choices={
      BuffPair("rivendare", "Mark of Rivendare", 803670, "Greater Mark of Rivendare", 803730, {categories={"STAMINA", "FROST_RESISTANCE"}}),
      BuffPair("korthazz", "Mark of Korth'azz", 707345, "Greater Mark of Korth’azz", 680300, {categories={"STRENGTH", "FIRE_RESISTANCE"}, auraNames={"Mark of Korth’azz", "Greater Mark of Korth'azz"}}),
      BuffPair("zeliek", "Mark of Zeliek", 803671, "Greater Mark of Zeliek", 803731, {categories={"ARCANE_RESISTANCE", "RESOURCE_COST"}}),
      BuffPair("blaumeux", "Mark of Blaumeux", 707696, "Greater Mark of Blaumeux", 712460, {categories={"SPELL_POWER"}}),
    }},
  },

  Necromancer = {
    {key="foul_mandate", label="Foul Mandate", assignment="ALL", choices={
      BuffPair("foul", "Foul Mandate", 573298, "Greater Foul Mandate", 680286, {categories={"STAMINA"}}),
    }},
    {key="grim_mandate", label="Grim Mandate", assignment="ALL", choices={
      BuffPair("grim", "Grim Mandate", 572789, "Greater Grim Mandate", 572790, {categories={"SPELL_POWER"}}),
    }},
  },

  Primalist = {
    {key="grove_instinct", label="Grove Instinct", assignment="ALL", choices={
      BuffPair("grove", "Grove Instinct", 572816, "Greater Grove Instinct", 572817, {categories={"MP5"}}),
    }},
    {key="primal_instinct", label="Primal Instinct", assignment="ALL", choices={
      BuffPair("primal", "Primal Instinct", 573349, "Greater Primal Instinct", 680310, {categories={"ATTACK_POWER"}}),
    }},
    {key="earthen_endurance", label="Earthen Endurance", assignment="ALL", choices={
      BuffPair("wild_defense", "Earthen Endurance", 570755, "Greater Earthen Endurance", 570756, {categories={"ARMOR", "STATS", "ALL_RESISTANCE"}}),
    }},
    {key="essence_of_nature", label="Essence of Nature", assignment="ALL", choices={
      BuffPair("nature_resistance", "Essence of Nature", 581315, "Greater Essence of Nature", 582261, {categories={"NATURE_RESISTANCE"}}),
    }},
  },

  Pyromancer = {
    {key="seal_alar", label="Seal of Al'ar", assignment="ALL", choices={
      BuffPair("alar", "Seal of Al'ar", 808012, "Greater Seal of Al'ar", 808060, {categories={"MP5"}}),
    }},
    {key="seal_alysrazor", label="Seal of Alysrazor", assignment="ALL", choices={
      BuffPair("alysrazor", "Seal of Alysrazor", 800196, "Greater Seal of Alysrazor", 570170, {categories={"INTELLECT"}, auraNames={"Seal of Alyrazor", "Greater Seal of Alyrazor"}}),
    }},
  },

  Ranger = {
    {key="woodsmans_adaptation", label="Woodsman's Adaptation", assignment="ALL", choices={
      BuffPair("attack_power", "Woodsman's Adaptation", 803666, "Greater Woodsman's Adaptation", 680294, {categories={"ATTACK_POWER"}}),
    }},
    {key="wild_blessing", label="Wild Blessing", assignment="ALL", choices={
      BuffPair("nature_resistance", "Wild Blessing", nil, "Greater Wild Blessing", nil, {categories={"NATURE_RESISTANCE"}}),
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
      BuffPair("perseverance", "Rite of Perseverance", 575841, "Greater Rite of Perseverance", 575842, {categories={"ALL_RESISTANCE"}, auraNames={"Rite of Perseverence", "Greater Rite of Perseverence"}}),
    }},
  },

  Runemaster = {
    {key="etching_leylines", label="Etching of the Leylines", assignment="ALL", choices={
      BuffPair("leylines", "Etching of the Leylines", 561236, "Greater Etching of the Leylines", 561242, {categories={"STATS"}, auraNames={"Etching of Leylines", "Greater Etching of Leylines"}}),
    }},
    {key="etching_dextrous", label="Etching of the Dextrous", assignment="ALL", choices={
      BuffPair("dextrous", "Etching of the Dextrous", 561240, "Greater Etching of the Dextrous", 561241, {categories={"AGILITY"}, auraNames={"Etching of Dexterous", "Greater Etching of Dexterous"}}),
    }},
    {key="etching_magi", label="Etching of the Magi", assignment="ALL", choices={
      BuffPair("magi", "Etching of the Magi", 560295, "Greater Etching of the Magi", 561243, {categories={"RESOURCE_COST"}, auraNames={"Etching of Magi", "Greater Etching of Magi"}}),
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
      BuffPair("wind", "Call of the Wind", 503323, "Greater Call of the Wind", 680291, {categories={"MP5"}}),
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
      BuffPair("grace", "Devotion of Grace", 300865, "Greater Devotion of Grace", 681160, {categories={"MP5", "RESOURCE_COST"}}),
    }},
  },

  Templar = {
    {key="crusaders_oath", label="Crusader's Oath", assignment="ALL", choices={
      BuffPair("fervor", "Gift of Fervor", nil, "Greater Crusader's Oath", 572630, {categories={"STATS"}, auraNames={"Crusader's Oath", "Greater Gift of Fervor"}}),
    }},
    {key="gift_zeal", label="Gift of Zeal", assignment="ALL", choices={
      BuffPair("zeal", "Gift of Zeal", 300924, "Greater Gift of Zeal", 680306, {categories={"AGILITY"}}),
    }},
  },

  Tinker = {
    {key="mana_module", label="Mana Module", assignment="ALL", choices={
      BuffPair("mana", "Mana Module", 803663, "Greater Mana Module", 803665, {categories={"MP5"}}),
    }},
    {key="power_module", label="Power Module", assignment="ALL", choices={
      BuffPair("power", "Power Module", 707688, "Greater Power Module", 680315, {categories={"ATTACK_POWER"}}),
    }},
  },

  Venomancer = {
    {key="beetle_pheromones", label="Beetle Pheromones", assignment="ALL", choices={
      BuffPair("beetle", "Beetle Pheromones", 803655, "Greater Beetle Pheromones", 803657, {categories={"ARMOR", "STATS"}}),
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
      BuffPair("cost_reduction", "Resourceful Wuju", 578344, "Greater Resourceful Wuju", 800195, {categories={"RESOURCE_COST"}}),
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
      BuffPair("armor_stats", "Knight's Edict", 523488, "Greater Knight's Edict", 523510, {categories={"ARMOR", "STATS"}}),
    }},
  },
}
BUFF_CATALOG.KnightOfXoroth = BUFF_CATALOG["Knight of Xoroth"]
BUFF_CATALOG.SunCleric = BUFF_CATALOG["Sun Cleric"]
BUFF_CATALOG.WitchDoctor = BUFF_CATALOG["Witch Doctor"]
BUFF_CATALOG.WitchHunter = BUFF_CATALOG["Witch Hunter"]

-- Build the equivalent-effect lookup from the live Buff Manager catalog as
-- well as the external CoA reminder aliases above. This keeps every class buff
-- in the same generic coverage system and avoids class-specific duplicate code.
local EQUIVALENT_ID_LOOKUPS = {}
for category in pairs(EQUIVALENT_LOOKUPS) do EQUIVALENT_ID_LOOKUPS[category] = {} end

local function RegisterEquivalentChoice(choice)
  if not choice then return end
  for _, category in ipairs(choice.categories or {}) do
    EQUIVALENT_LOOKUPS[category] = EQUIVALENT_LOOKUPS[category] or {}
    EQUIVALENT_ID_LOOKUPS[category] = EQUIVALENT_ID_LOOKUPS[category] or {}
    local names = {choice.name, choice.normalName, choice.greaterName}
    for _, value in ipairs(choice.auraNames or {}) do names[#names + 1] = value end
    for _, value in ipairs(names) do
      if value and value ~= "" then EQUIVALENT_LOOKUPS[category][NormalizeAuraName(value)] = true end
    end
    local normalID = tonumber(choice.normalID)
    local greaterID = tonumber(choice.greaterID)
    if normalID then EQUIVALENT_ID_LOOKUPS[category][normalID] = true end
    if greaterID then EQUIVALENT_ID_LOOKUPS[category][greaterID] = true end
    for _, value in ipairs(choice.auraIDs or {}) do
      value = tonumber(value)
      if value then EQUIVALENT_ID_LOOKUPS[category][value] = true end
    end
  end
end

local seenCatalogTables = {}
for _, families in pairs(BUFF_CATALOG) do
  if type(families) == "table" and not seenCatalogTables[families] then
    seenCatalogTables[families] = true
    for _, family in ipairs(families) do
      for _, choice in ipairs(family.choices or {}) do RegisterEquivalentChoice(choice) end
    end
  end
end

local unitCoverageCache = {}

local compactFrame
local managerFrame
local keybindFrame
local compactButtons = {}
local shieldButton
local managerRows = {}
local managerHeaders = {}
local keybindRows = {}
local secureBindingButtons = {}
local appliedBindingKeys = {}
local bindingOwner
local keybindsDirty = true
local RefreshKeybindFrame
local refreshElapsed = 0
local refreshPending = false
local activeClassName
local activeFamilies
local activeComposition = {}
-- Every class uses one vertical Buff Manager column. Icons never wrap into
-- additional horizontal columns, regardless of the number of learned buffs.
local COMPACT_COLUMNS = 1
local COMPACT_SLOT = 32
local SMART_FAMILY_KEY = "__smart"
local SMART_BINDING_MODE = "smart"

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
  buffDB.keybinds = buffDB.keybinds or {}
  if buffDB.keybindSchema == nil or buffDB.keybindSchema < 2 then
    buffDB.keybindSchema = 2
  end

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

  -- Older saved data could expose Slaughterhouse Offering as a second family.
  -- Fold any deliberate assignment back into the single exclusive Offering
  -- family, then remove the obsolete column from saved variables.
  if not buffDB.slaughterhouseOfferingFamilyMigration then
    local bloodmage = buffDB.assignments[NormalKey("Bloodmage")]
    if type(bloodmage) == "table" then
      local legacy = bloodmage.slaughterhouse_offering
      bloodmage.offering = bloodmage.offering or {}
      if type(legacy) == "table" then
        for bucketKey, value in pairs(legacy) do
          if value == "slaughterhouse_offering" or value == "slaughterhouse" then
            bloodmage.offering[bucketKey] = "slaughterhouse"
          elseif value == "__NONE" and bloodmage.offering[bucketKey] == nil then
            bloodmage.offering[bucketKey] = "__NONE"
          end
        end
      end
      bloodmage.slaughterhouse_offering = nil
    end
    buffDB.slaughterhouseOfferingFamilyMigration = 1
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

  -- One generic effect-coverage planner is used for every class buff.
  -- Keep the marker in SavedVariables so future migrations can distinguish the
  -- old fixed-choice behavior without resetting deliberate assignments.
  if not buffDB.genericCoveragePlannerMigration then
    buffDB.genericCoveragePlannerMigration = 1
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
  -- Buff Manager visibility must be based on the live spellbook. Ascension can
  -- report future class spells through IsSpellKnown/IsPlayerSpell before the
  -- character has actually learned them, which created empty party-buff icons.
  if name and RUI.GetSpellBookIndex and RUI:GetSpellBookIndex(name) then return true end
  if spellID and RUI.GetSpellBookIndexByID and RUI:GetSpellBookIndexByID(spellID) then return true end
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

local function ResolveChoiceRank(choice, rankMode)
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

  if rankMode == "greater" then
    local learnedGreaterID = greaterName and SpellIDByName(greaterName) or nil
    greaterID = learnedGreaterID or greaterID
    if greaterName and IsLearned(greaterName, greaterID) then
      return {
        id=greaterID, name=greaterName, displayName=displayName,
        isGreater=true, choice=choice,
      }
    end
    return nil
  end

  if rankMode == "normal" then
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

  return ResolveChoiceRank(choice, "greater") or ResolveChoiceRank(choice, "normal")
end

local function ResolveChoice(choice)
  return ResolveChoiceRank(choice, "smart")
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
      local normalSpell = ResolveChoiceRank(choice, "normal")
      local greaterSpell = ResolveChoiceRank(choice, "greater")
      local spell = greaterSpell or normalSpell
      if spell then
        resolved[#resolved + 1] = {
          choice=choice, spell=spell, normalSpell=normalSpell, greaterSpell=greaterSpell,
        }
      end
    end
    if #resolved > 0 then
      result[#result + 1] = {definition=family, choices=resolved}
    end
  end
  return result
end

local function CurrentClass()
  if RUI.ScanSpellbook then pcall(RUI.ScanSpellbook, RUI) end
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


local function MergeCoverageState(state, remaining)
  state = state or {present=false, permanent=false, remaining=nil}
  state.present = true
  if remaining == nil then
    state.permanent = true
    state.remaining = nil
  elseif not state.permanent and (not state.remaining or remaining > state.remaining) then
    -- When several equivalent buffs cover the same effect, use the longest
    -- remaining source. The effect is only expiring when every source is.
    state.remaining = remaining
  end
  return state
end

local function AuraRemaining(duration, expirationTime)
  local remaining
  if expirationTime and expirationTime > 0 and GetTime then
    remaining = math.max(0, expirationTime - GetTime())
  elseif duration and duration > 0 then
    remaining = duration
  end
  return remaining
end

local function ScanUnitCoverage(unit)
  if unitCoverageCache[unit] then return unitCoverageCache[unit] end
  local coverage = {names={}, ids={}, categories={}}
  unitCoverageCache[unit] = coverage
  if not UnitExists or not UnitExists(unit) or not UnitBuff then return coverage end

  for index=1,40 do
    local name, _, _, _, _, duration, expirationTime, _, _, _, spellID = UnitBuff(unit, index)
    if not name then break end
    local normalizedName = NormalizeAuraName(name)
    local numericID = tonumber(spellID)
    local remaining = AuraRemaining(duration, expirationTime)
    if normalizedName ~= "" then coverage.names[normalizedName] = MergeCoverageState(coverage.names[normalizedName], remaining) end
    if numericID then coverage.ids[numericID] = MergeCoverageState(coverage.ids[numericID], remaining) end

    for category, lookup in pairs(EQUIVALENT_LOOKUPS) do
      local idLookup = EQUIVALENT_ID_LOOKUPS[category]
      if (lookup and lookup[normalizedName]) or (numericID and idLookup and idLookup[numericID]) then
        coverage.categories[category] = MergeCoverageState(coverage.categories[category], remaining)
      end
    end
  end
  return coverage
end

local function AddChoiceMatchers(choice, spell, wantedNames, wantedIDs)
  local function AddName(value)
    if value and value ~= "" then wantedNames[NormalizeAuraName(value)] = true end
  end
  local function AddID(value)
    value = tonumber(value)
    if value then wantedIDs[value] = true end
  end
  AddName(choice and choice.name)
  AddName(choice and choice.normalName)
  AddName(choice and choice.greaterName)
  AddName(spell and spell.name)
  for _, value in ipairs(choice and choice.auraNames or {}) do AddName(value) end
  AddID(choice and choice.normalID)
  AddID(choice and choice.greaterID)
  AddID(spell and spell.id)
  for _, value in ipairs(choice and choice.auraIDs or {}) do AddID(value) end
end

local function BestStateRemaining(state)
  if not state or not state.present then return nil end
  if state.permanent then return nil end
  return state.remaining
end

local function ExactChoiceAuraStatus(coverage, choice, spell)
  local names, ids = {}, {}
  AddChoiceMatchers(choice, spell, names, ids)
  local best
  for name in pairs(names) do
    local state = coverage.names[name]
    if state and state.present then
      if state.permanent then return true, nil end
      if state.remaining and (not best or state.remaining > best) then best = state.remaining end
    end
  end
  for spellID in pairs(ids) do
    local state = coverage.ids[spellID]
    if state and state.present then
      if state.permanent then return true, nil end
      if state.remaining and (not best or state.remaining > best) then best = state.remaining end
    end
  end
  return best ~= nil, best
end

local function CategoriesStatus(coverage, choice)
  local categories = choice and choice.categories or {}
  if #categories == 0 then return false, nil, 0, 0 end
  local missing, minimumRemaining = 0, nil
  for _, category in ipairs(categories) do
    local state = coverage.categories[category]
    if not state or not state.present then
      missing = missing + 1
    elseif not state.permanent and state.remaining and (not minimumRemaining or state.remaining < minimumRemaining) then
      minimumRemaining = state.remaining
    end
  end
  return missing == 0, minimumRemaining, missing, #categories
end

local function RuntimeEntryByChoiceKey(familyRuntime, choiceKey)
  for _, entry in ipairs(familyRuntime and familyRuntime.choices or {}) do
    if entry.choice.key == choiceKey then return entry end
  end
end

local function FamilyExactAuraStatus(unit, familyRuntime, coverage)
  coverage = coverage or ScanUnitCoverage(unit)
  local bestKey, bestEntry, bestRemaining
  for _, choice in ipairs(familyRuntime and familyRuntime.definition and familyRuntime.definition.choices or {}) do
    local entry = RuntimeEntryByChoiceKey(familyRuntime, choice.key)
    local present, remaining = ExactChoiceAuraStatus(coverage, choice, entry and entry.spell or nil)
    if present then
      if remaining == nil then return true, nil, choice.key, entry end
      if not bestRemaining or remaining > bestRemaining then
        bestKey, bestEntry, bestRemaining = choice.key, entry, remaining
      end
    end
  end
  return bestKey ~= nil, bestRemaining, bestKey, bestEntry
end

local function AuraStatus(unit, entry, familyRuntime)
  if not UnitExists or not UnitExists(unit) then return false, nil end
  local coverage = ScanUnitCoverage(unit)

  -- A mutually exclusive family is satisfied by any active member of that
  -- family. This prevents Offerings, Marks and future exclusive families from
  -- endlessly asking the player to replace one valid active choice with another.
  if familyRuntime and #(familyRuntime.definition.choices or {}) > 1 then
    local present, remaining = FamilyExactAuraStatus(unit, familyRuntime, coverage)
    if present then return true, remaining end
  end

  local exact, exactRemaining = ExactChoiceAuraStatus(coverage, entry.choice, entry.spell)
  if exact then return true, exactRemaining end

  -- Every class buff uses the same effect-family coverage check. Equivalent
  -- buffs from any other class satisfy the row, while unrelated short procs do
  -- not appear in the curated equivalent lookup and therefore do not count.
  local covered, remaining = CategoriesStatus(coverage, entry.choice)
  return covered, remaining
end

local function AssignmentOverrideValue(casterClass, familyRuntime, bucket)
  local family = familyRuntime.definition or familyRuntime
  local store = AssignmentStore(casterClass, family.key)
  local override = store[bucket.key]
  if override == "__NONE" then return nil, true end
  if override and override ~= "" then
    if RuntimeChoiceAvailable(familyRuntime, override) then return override, true end
    return FirstRuntimeChoice(familyRuntime), true
  end
  return nil, false
end

local function AssignedChoiceKeyForMember(casterClass, familyRuntime, bucket, member)
  local manualChoice, manual = AssignmentOverrideValue(casterClass, familyRuntime, bucket)
  if manual then return manualChoice, true end

  local family = familyRuntime.definition or familyRuntime
  local choices = familyRuntime.choices or {}
  if #choices == 0 then return nil, false end
  if #choices == 1 then return choices[1].choice.key, false end

  local coverage = ScanUnitCoverage(member.unit)
  local exact, _, exactKey = FamilyExactAuraStatus(member.unit, familyRuntime, coverage)
  if exact and RuntimeChoiceAvailable(familyRuntime, exactKey) then
    return exactKey, false
  end

  local preferred = DefaultAssignment(family, bucket)
  local bestScore = -1
  local best = {}
  for _, entry in ipairs(choices) do
    local choice = entry.choice
    local exactChoice = ExactChoiceAuraStatus(coverage, choice, entry.spell)
    local covered, _, missing, categoryCount = CategoriesStatus(coverage, choice)
    local score
    if exactChoice then
      score = 0
    elseif categoryCount > 0 then
      -- Prefer the learned buff that fills the largest number of currently
      -- uncovered effects. This is the generic behavior for every class.
      score = missing
    else
      -- Exact-only long buffs still participate in the same planner.
      score = covered and 0 or 1
    end
    if score > bestScore then
      bestScore = score
      best = {entry.choice.key}
    elseif score == bestScore then
      best[#best + 1] = entry.choice.key
    end
  end

  for _, key in ipairs(best) do if key == preferred then return key, false end end
  return best[1] or FirstRuntimeChoice(familyRuntime), false
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
    for _, member in ipairs(bucket.members) do
      local assignedKey = AssignedChoiceKeyForMember(casterClass, familyRuntime, bucket, member)
      if assignedKey == choiceKey then targets[#targets + 1] = member end
    end
  end
  return targets
end

local function BuffTargetAvailability(unit, spell)
  if not unit or not UnitExists or not UnitExists(unit) then return false, "not in group" end
  if UnitIsConnected and not UnitIsConnected(unit) then return false, "offline" end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false, "dead" end

  if UnitInPhase then
    local ok, inPhase = pcall(UnitInPhase, unit)
    if ok and inPhase == false then return false, "different phase" end
  end
  if UnitIsVisible then
    local ok, visible = pcall(UnitIsVisible, unit)
    if ok and visible == false then return false, "not visible" end
  end
  if UnitInRange then
    local ok, inRange = pcall(UnitInRange, unit)
    if ok and inRange == false then return false, "out of range" end
  end

  local spellName = spell and spell.name or nil
  if spell and spell.id and GetSpellInfo then
    local ok, resolved = pcall(GetSpellInfo, spell.id)
    if ok and resolved and resolved ~= "" then spellName = resolved end
  end
  if spellName and IsSpellInRange then
    local ok, inSpellRange = pcall(IsSpellInRange, spellName, unit)
    if ok and inSpellRange == 0 then return false, "out of spell range" end
  end
  return true
end

local function ChoiceState(casterClass, familyRuntime, entry)
  local targets = AssignedTargets(casterClass, familyRuntime, entry.choice.key)
  local missing, expiring, good, unavailable = {}, {}, {}, {}
  local rangeSpell = entry.greaterSpell or entry.normalSpell or entry.spell
  for _, member in ipairs(targets) do
    local unit = member.unit
    local present, remaining = AuraStatus(unit, entry, familyRuntime)
    local valid, reason = BuffTargetAvailability(unit, rangeSpell)
    if present and (not remaining or remaining <= 0 or remaining >= 300) then
      good[#good + 1] = member
    elseif valid then
      if not present then
        missing[#missing + 1] = member
      else
        expiring[#expiring + 1] = member
      end
    else
      member.buffUnavailableReason = reason
      unavailable[#unavailable + 1] = member
    end
  end

  local status, nextMember
  if #targets == 0 then
    status = "inactive"
  elseif #missing > 0 then
    status, nextMember = "missing", missing[1]
  elseif #expiring > 0 then
    status, nextMember = "expiring", expiring[1]
  elseif #unavailable > 0 then
    status = "unavailable"
  else
    status = "ready"
  end
  return {
    status=status, targets=targets, missing=missing, expiring=expiring,
    good=good, unavailable=unavailable, nextMember=nextMember,
  }
end

local function FamilyState(casterClass, familyRuntime)
  local result = {
    status="inactive", targets={}, missing={}, expiring={}, good={}, unavailable={},
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
    for _, member in ipairs(state.unavailable or {}) do result.unavailable[#result.unavailable + 1] = member end
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
    result.status = (#result.unavailable > 0) and "unavailable" or "ready"
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


local function ClassBindingStore(className)
  local db = EnsureBuffDB()
  local classKey = NormalKey(className or "unknown")
  db.keybinds[classKey] = db.keybinds[classKey] or {}
  return db.keybinds[classKey], classKey
end

local function FamilyBindingStore(className, familyKey)
  local classStore = ClassBindingStore(className)
  familyKey = tostring(familyKey or "unknown")
  classStore[familyKey] = classStore[familyKey] or {}
  return classStore[familyKey]
end

local function CompactBindingText(key)
  key = tostring(key or "")
  if key == "" then return "" end
  key = key:gsub("CTRL%-", "C-"):gsub("SHIFT%-", "S-"):gsub("ALT%-", "A-")
  key = key:gsub("NUMPAD", "N"):gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
  key = key:gsub("BUTTON", "M")
  if #key > 8 then key = string.sub(key, 1, 8) end
  return key
end

local function BindingDisplayText(key)
  key = tostring(key or "")
  if key == "" then return "Unbound" end
  if GetBindingText then
    local ok, text = pcall(GetBindingText, key, "KEY_")
    if ok and text and text ~= "" then return text end
  end
  return key
end

local function BindingButtonName(className, familyKey, mode)
  return "RetreatUIBuffKey_" .. NormalKey(className) .. "_" .. NormalKey(familyKey) .. "_" .. tostring(mode)
end

local function EnsureBindingOwner()
  if bindingOwner then return bindingOwner end
  bindingOwner = CreateFrame("Frame", "RetreatUIBuffBindingOwner", UIParent)
  bindingOwner:SetSize(1, 1)
  bindingOwner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
  bindingOwner:Show()
  return bindingOwner
end

local function EnsureSecureBindingButton(className, familyKey, mode)
  local name = BindingButtonName(className, familyKey, mode)
  local button = secureBindingButtons[name] or _G[name]
  if not button then
    button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -25, 25)
    button:SetAlpha(0)
    button:EnableMouse(false)
    button:RegisterForClicks("AnyUp")
    button:Show()
  end
  secureBindingButtons[name] = button
  return button
end

local function ClearAppliedBindings()
  if InCombatLockdown and InCombatLockdown() then return false end
  local owner = EnsureBindingOwner()
  if ClearOverrideBindings then
    pcall(ClearOverrideBindings, owner)
  elseif SetBinding then
    for key, action in pairs(appliedBindingKeys) do
      local current = GetBindingAction and GetBindingAction(key) or ""
      if current == action then pcall(SetBinding, key) end
    end
  end
  for key in pairs(appliedBindingKeys) do appliedBindingKeys[key] = nil end
  return true
end

local function ApplyOneBinding(key, button, mouseButton)
  key = tostring(key or "")
  if key == "" or not button then return end
  local owner = EnsureBindingOwner()
  local action = "CLICK " .. tostring(button:GetName()) .. ":" .. tostring(mouseButton or "LeftButton")
  if SetOverrideBindingClick then
    pcall(SetOverrideBindingClick, owner, true, key, button:GetName(), mouseButton or "LeftButton")
  elseif SetBindingClick then
    pcall(SetBindingClick, key, button:GetName(), mouseButton or "LeftButton")
  end
  appliedBindingKeys[key] = action
end

local function UpdateSecureBindingAction(className, familyRuntime, state)
  if not familyRuntime or not familyRuntime.definition then return end
  local familyKey = familyRuntime.definition.key
  local entry = state and (state.nextEntry or state.displayEntry) or nil
  local nextMember = state and state.nextMember or nil
  local normalButton = EnsureSecureBindingButton(className, familyKey, "normal")
  local greaterButton = EnsureSecureBindingButton(className, familyKey, "greater")

  local runtimeEntry = entry and ChoiceByKey(familyRuntime, entry.choice.key) or nil
  local normalSpell = runtimeEntry and runtimeEntry.normalSpell or nil
  local greaterSpell = runtimeEntry and (runtimeEntry.greaterSpell or runtimeEntry.normalSpell) or nil
  local unit = nextMember and nextMember.unit or nil

  for _, pair in ipairs({{normalButton, normalSpell}, {greaterButton, greaterSpell}}) do
    local button, spell = pair[1], pair[2]
    local secureSpell = unit and spell and SecureSpellName(spell) or nil
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    button:SetAttribute("type1", secureSpell and "spell" or nil)
    button:SetAttribute("spell1", secureSpell)
    button:SetAttribute("unit1", secureSpell and unit or nil)
  end
end

local function UpdateSmartBindingAction(className, plan)
  local button = EnsureSecureBindingButton(className, SMART_FAMILY_KEY, SMART_BINDING_MODE)
  local spell = plan and plan.spell or nil
  local unit = plan and plan.member and plan.member.unit or nil
  local secureSpell = unit and spell and SecureSpellName(spell) or nil
  button:SetAttribute("type", nil)
  button:SetAttribute("spell", nil)
  button:SetAttribute("unit", nil)
  button:SetAttribute("type1", secureSpell and "spell" or nil)
  button:SetAttribute("spell1", secureSpell)
  button:SetAttribute("unit1", secureSpell and unit or nil)
  button.smartPlan = plan
end

local function ApplyConfiguredBindings(className, families)
  if InCombatLockdown and InCombatLockdown() then return false end
  if not keybindsDirty then return true end
  ClearAppliedBindings()
  local classStore = ClassBindingStore(className)
  local smartBinding = classStore[SMART_FAMILY_KEY]
  if smartBinding then
    ApplyOneBinding(smartBinding[SMART_BINDING_MODE], EnsureSecureBindingButton(className, SMART_FAMILY_KEY, SMART_BINDING_MODE), "LeftButton")
  end
  for _, familyRuntime in ipairs(families or {}) do
    local familyKey = familyRuntime.definition and familyRuntime.definition.key
    local binding = familyKey and classStore[familyKey] or nil
    if binding then
      ApplyOneBinding(binding.normal, EnsureSecureBindingButton(className, familyKey, "normal"), "LeftButton")
      ApplyOneBinding(binding.greater, EnsureSecureBindingButton(className, familyKey, "greater"), "LeftButton")
    end
  end
  keybindsDirty = false
  return true
end

local function SetFamilyBinding(className, familyKey, mode, key)
  if InCombatLockdown and InCombatLockdown() then
    RUI:Print("Buff keybinds cannot be changed during combat.")
    return false
  end
  local store = FamilyBindingStore(className, familyKey)
  if key == nil or key == "" then store[mode] = nil else store[mode] = key end
  keybindsDirty = true
  refreshPending = true
  return true
end

local function CurrentFamilyBinding(className, familyKey, mode)
  local store = FamilyBindingStore(className, familyKey)
  return store[mode]
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
  button.normalBind = button:CreateFontString(nil, "OVERLAY")
  Font(button.normalBind, 6)
  button.normalBind:SetPoint("TOPRIGHT", -2, -1)
  button.normalBind:SetJustifyH("RIGHT")
  button.greaterBind = button:CreateFontString(nil, "OVERLAY")
  Font(button.greaterBind, 6)
  button.greaterBind:SetPoint("BOTTOMLEFT", 2, 1)
  button.greaterBind:SetJustifyH("LEFT")

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

local function SelectSmartBuffPlan(familyStates)
  local blocked = 0
  for _, item in ipairs(familyStates or {}) do
    local state = item.state
    if state and state.nextMember and state.nextEntry then
      local spell = state.nextEntry.greaterSpell or state.nextEntry.normalSpell or state.nextEntry.spell
      if spell then
        return {
          familyRuntime=item.familyRuntime,
          familyKey=item.familyRuntime.definition and item.familyRuntime.definition.key,
          entry=state.nextEntry,
          member=state.nextMember,
          spell=spell,
          status=state.status,
        }, blocked
      end
    end
    blocked = blocked + #(state and state.unavailable or {})
  end
  return nil, blocked
end

local function RefreshCompact()
  -- SecureActionButtonTemplate frames cannot be safely created, moved, shown,
  -- hidden or retargeted during combat. Keep the last valid secure layout and
  -- refresh immediately on PLAYER_REGEN_ENABLED instead.
  if InCombatLockdown and InCombatLockdown() then return end
  BuildCompact()
  unitCoverageCache = {}
  activeClassName, activeFamilies = CurrentClass()
  BuildComposition()

  local leftOffset = EnsureBuffDB().locked and 2 or 18
  local visible = 0
  if RefreshShieldButton(leftOffset, visible + 1) then visible = visible + 1 end

  local visibleAssignedBuffs = 0
  local familyStates = {}
  for _, familyRuntime in ipairs(activeFamilies or {}) do
    local state = FamilyState(activeClassName, familyRuntime)
    familyStates[#familyStates + 1] = {familyRuntime=familyRuntime, state=state}
    UpdateSecureBindingAction(activeClassName, familyRuntime, state)
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
      local familyKey = familyRuntime.definition and familyRuntime.definition.key
      local normalKey = familyKey and CurrentFamilyBinding(activeClassName, familyKey, "normal") or nil
      local greaterKey = familyKey and CurrentFamilyBinding(activeClassName, familyKey, "greater") or nil
      button.normalBind:SetText(CompactBindingText(normalKey))
      button.greaterBind:SetText(CompactBindingText(greaterKey))

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
      elseif #(state.unavailable or {}) > 0 then
        lines[#lines + 1] = "No valid targets right now; offline, dead, phased, invisible and out-of-range players are skipped."
      else
        lines[#lines + 1] = "All assigned players are covered."
      end
      if #(familyRuntime.choices or {}) > 1 then
        lines[#lines + 1] = "Auto scans all active class buffs and switches to the uncovered exclusive choice."
      else
        lines[#lines + 1] = "Equivalent buffs from other classes count as covered."
      end
      lines[#lines + 1] = "Smart Buff bind: " .. BindingDisplayText(CurrentFamilyBinding(activeClassName, SMART_FAMILY_KEY, SMART_BINDING_MODE))
      lines[#lines + 1] = "Normal/Lesser bind: " .. BindingDisplayText(normalKey)
      lines[#lines + 1] = "Manual Greater bind: " .. BindingDisplayText(greaterKey)
      lines[#lines + 1] = "Right-click: Open assignments"
      button.tooltipTitle = familyRuntime.definition.label or (entry and entry.spell.name) or "Buff"
      button.tooltipLines = lines
      button:Show()
    end
  end

  for index=visibleAssignedBuffs+1,#compactButtons do compactButtons[index]:Hide() end
  local smartPlan, blockedTargets = SelectSmartBuffPlan(familyStates)
  UpdateSmartBindingAction(activeClassName, smartPlan)
  compactFrame.smartPlan = smartPlan
  compactFrame.smartBlockedTargets = blockedTargets
  ApplyConfiguredBindings(activeClassName, activeFamilies)
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


local MODIFIER_KEYS = {
  LSHIFT=true, RSHIFT=true, LCTRL=true, RCTRL=true, LALT=true, RALT=true,
  SHIFT=true, CTRL=true, ALT=true,
}

local function CaptureKeyName(rawKey)
  rawKey = tostring(rawKey or "")
  if rawKey == "" or MODIFIER_KEYS[rawKey] then return nil end
  local parts = {}
  if IsControlKeyDown and IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
  if IsShiftKeyDown and IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
  if IsAltKeyDown and IsAltKeyDown() then parts[#parts + 1] = "ALT" end
  parts[#parts + 1] = rawKey
  return table.concat(parts, "-")
end

local function MouseBindingKey(button)
  local map = {
    LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3",
    Button4="BUTTON4", Button5="BUTTON5", Button6="BUTTON6", Button7="BUTTON7",
  }
  return CaptureKeyName(map[button] or string.upper(tostring(button or "")))
end

local function IsOurBindingAction(action)
  return type(action) == "string" and string.find(action, "RetreatUIBuffKey_", 1, true) ~= nil
end

local function BindingConflict(key)
  if not GetBindingAction then return nil end
  local ok, action = pcall(GetBindingAction, key, true)
  if not ok or not action or action == "" then
    ok, action = pcall(GetBindingAction, key)
  end
  if ok and action and action ~= "" and not IsOurBindingAction(action) then return action end
  return nil
end

local function RemoveDuplicateClassBinding(className, familyKey, mode, key)
  if not key or key == "" then return end
  local classStore = ClassBindingStore(className)
  for otherFamily, binding in pairs(classStore) do
    if type(binding) == "table" then
      for _, otherMode in ipairs({"normal", "greater", SMART_BINDING_MODE}) do
        if binding[otherMode] == key and (otherFamily ~= familyKey or otherMode ~= mode) then
          binding[otherMode] = nil
        end
      end
    end
  end
end

local function CreateBindingField(parent, mode)
  local theme = ManagerTheme()
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(132, 26)
  button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  button:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.94)
  button:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.62)
  button.text = button:CreateFontString(nil, "OVERLAY")
  Font(button.text, 9)
  button.text:SetPoint("CENTER")
  button.text:SetText("Unbound")
  button.mode = mode
  button:SetScript("OnEnter", function(self)
    if not self.disabled then self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.9) end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.62)
  end)
  function button:SetEnabled(enabled)
    self.disabled = not enabled
    self:SetAlpha(enabled and 1 or 0.35)
    self:EnableMouse(enabled)
  end
  return button
end

local function StopBindingCapture()
  if not keybindFrame or not keybindFrame.capture then return end
  local capture = keybindFrame.capture
  capture.pendingKey = nil
  capture.row = nil
  capture.mode = nil
  capture:EnableKeyboard(false)
  capture:Hide()
end

local function CompleteBindingCapture(key)
  if not keybindFrame or not keybindFrame.capture or not keybindFrame.capture.row then return end
  local capture = keybindFrame.capture
  local row, mode = capture.row, capture.mode
  local className = keybindFrame.className
  local familyKey = row.isSmart and SMART_FAMILY_KEY
    or (row.familyRuntime and row.familyRuntime.definition and row.familyRuntime.definition.key)
  if not className or not familyKey then StopBindingCapture(); return end

  if key == "ESCAPE" then StopBindingCapture(); return end
  if key == "BACKSPACE" or key == "DELETE" then
    SetFamilyBinding(className, familyKey, mode, nil)
    StopBindingCapture()
    if RefreshKeybindFrame then RefreshKeybindFrame() end
    RefreshCompact()
    return
  end

  local conflict = BindingConflict(key)
  if conflict and capture.pendingKey ~= key then
    capture.pendingKey = key
    capture.message:SetText(BindingDisplayText(key) .. " is already used by " .. tostring(conflict) .. ". Press it again to replace.")
    capture.message:SetTextColor(1, 0.48, 0.08, 1)
    return
  end

  RemoveDuplicateClassBinding(className, familyKey, mode, key)
  SetFamilyBinding(className, familyKey, mode, key)
  StopBindingCapture()
  if RefreshKeybindFrame then RefreshKeybindFrame() end
  RefreshCompact()
end

local function BeginBindingCapture(row, mode)
  if InCombatLockdown and InCombatLockdown() then
    RUI:Print("Buff keybinds cannot be changed during combat.")
    return
  end
  if not keybindFrame or not keybindFrame.capture then return end
  local capture = keybindFrame.capture
  capture.row = row
  capture.mode = mode
  capture.pendingKey = nil
  local modeLabel = mode == SMART_BINDING_MODE and "Smart Buff / next valid target"
    or (mode == "normal" and "Normal/Lesser" or "Manual Greater")
  capture.message:SetText("Press a key for " .. tostring(row.labelText or "Buff") .. " — " .. modeLabel .. ".  Esc cancels.  Backspace clears.")
  local theme = ManagerTheme()
  capture.message:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)
  capture:Show()
  capture:EnableKeyboard(true)
  if capture.SetPropagateKeyboardInput then pcall(capture.SetPropagateKeyboardInput, capture, false) end
end

local function CreateKeybindRow(index)
  local theme = ManagerTheme()
  local row = CreateFrame("Frame", nil, keybindFrame.content)
  row:SetHeight(38)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(26, 26)
  row.icon:SetPoint("LEFT", 6, 0)
  row.icon:SetTexCoord(.08, .92, .08, .92)
  row.label = row:CreateFontString(nil, "OVERLAY")
  Font(row.label, 10)
  row.label:SetPoint("LEFT", 42, 0)
  row.label:SetWidth(230)
  row.label:SetJustifyH("LEFT")
  row.label:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)
  row.normal = CreateBindingField(row, "normal")
  row.normal:SetPoint("RIGHT", -148, 0)
  row.greater = CreateBindingField(row, "greater")
  row.greater:SetPoint("RIGHT", -8, 0)
  row.normal:SetScript("OnClick", function() if not row.normal.disabled then BeginBindingCapture(row, "normal") end end)
  row.greater:SetScript("OnClick", function() if not row.greater.disabled then BeginBindingCapture(row, "greater") end end)
  row.divider = row:CreateTexture(nil, "BORDER")
  row.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
  row.divider:SetPoint("BOTTOMLEFT", 4, 0)
  row.divider:SetPoint("BOTTOMRIGHT", -4, 0)
  row.divider:SetHeight(1)
  row.divider:SetVertexColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.22)
  keybindRows[index] = row
  return row
end

local function BuildKeybindFrame()
  if keybindFrame then return keybindFrame end
  local theme = ManagerTheme()
  keybindFrame = CreateFrame("Frame", "RetreatUIBuffKeybindManager", UIParent)
  keybindFrame:SetSize(650, 408)
  keybindFrame:SetPoint("CENTER", 0, 20)
  keybindFrame:SetFrameStrata("DIALOG")
  keybindFrame:SetClampedToScreen(true)
  keybindFrame:SetMovable(true)
  keybindFrame:EnableMouse(true)
  keybindFrame:RegisterForDrag("LeftButton")
  keybindFrame:SetScript("OnDragStart", function(self) if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end end)
  keybindFrame:SetScript("OnDragStop", keybindFrame.StopMovingOrSizing)
  RUI:SkinFrame(keybindFrame, theme.background, {theme.dim[1], theme.dim[2], theme.dim[3], 0.78})

  local accent = keybindFrame:CreateTexture(nil, "ARTWORK")
  accent:SetTexture("Interface\\Buttons\\WHITE8X8")
  accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1); accent:SetHeight(2)
  accent:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.9)

  keybindFrame.title = keybindFrame:CreateFontString(nil, "OVERLAY")
  Font(keybindFrame.title, 14)
  keybindFrame.title:SetPoint("TOPLEFT", 16, -14)
  keybindFrame.title:SetText("Buff Manager Keybinds")
  keybindFrame.classTitle = keybindFrame:CreateFontString(nil, "OVERLAY")
  Font(keybindFrame.classTitle, 10)
  keybindFrame.classTitle:SetPoint("LEFT", keybindFrame.title, "RIGHT", 10, 0)
  keybindFrame.classTitle:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

  local help = keybindFrame:CreateFontString(nil, "OVERLAY")
  Font(help, 9)
  help:SetPoint("TOPLEFT", 16, -39)
  help:SetText("Bind Smart Buff once, then press the same key repeatedly. Each press buffs one valid assigned player; manual binds remain available below.")
  help:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)

  local normalHeader = keybindFrame:CreateFontString(nil, "OVERLAY")
  Font(normalHeader, 9); normalHeader:SetPoint("TOPRIGHT", -156, -68); normalHeader:SetWidth(132); normalHeader:SetJustifyH("CENTER")
  normalHeader:SetText("NORMAL / LESSER"); normalHeader:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  local greaterHeader = keybindFrame:CreateFontString(nil, "OVERLAY")
  Font(greaterHeader, 9); greaterHeader:SetPoint("TOPRIGHT", -16, -68); greaterHeader:SetWidth(132); greaterHeader:SetJustifyH("CENTER")
  greaterHeader:SetText("MANUAL GREATER"); greaterHeader:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)

  keybindFrame.close = CreateFrame("Button", nil, keybindFrame)
  keybindFrame.close:SetSize(24, 24); keybindFrame.close:SetPoint("TOPRIGHT", -10, -10)
  keybindFrame.close:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  keybindFrame.close:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.94)
  keybindFrame.close:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.6)
  keybindFrame.close.text = keybindFrame.close:CreateFontString(nil, "OVERLAY"); Font(keybindFrame.close.text, 14); keybindFrame.close.text:SetPoint("CENTER", 0, 1); keybindFrame.close.text:SetText("×")
  keybindFrame.close:SetScript("OnClick", function() StopBindingCapture(); keybindFrame:Hide() end)

  keybindFrame.scroll = CreateFrame("ScrollFrame", nil, keybindFrame)
  keybindFrame.scroll:SetPoint("TOPLEFT", 14, -86); keybindFrame.scroll:SetPoint("BOTTOMRIGHT", -18, 50); keybindFrame.scroll:EnableMouseWheel(true)
  keybindFrame.content = CreateFrame("Frame", nil, keybindFrame.scroll); keybindFrame.content:SetSize(610, 38); keybindFrame.scroll:SetScrollChild(keybindFrame.content)
  keybindFrame.scrollBar = CreateFrame("Slider", nil, keybindFrame)
  keybindFrame.scrollBar:SetOrientation("VERTICAL"); keybindFrame.scrollBar:SetPoint("TOPRIGHT", -9, -88); keybindFrame.scrollBar:SetPoint("BOTTOMRIGHT", -9, 52); keybindFrame.scrollBar:SetWidth(5)
  keybindFrame.scrollBar:SetMinMaxValues(0,0); keybindFrame.scrollBar:SetValueStep(38); keybindFrame.scrollBar:SetValue(0)
  local thumb = keybindFrame.scrollBar:CreateTexture(nil, "OVERLAY"); thumb:SetTexture("Interface\\Buttons\\WHITE8X8"); thumb:SetSize(5,28); thumb:SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3],.72); keybindFrame.scrollBar:SetThumbTexture(thumb)
  keybindFrame.scrollBar:SetScript("OnValueChanged", function(_,value) keybindFrame.scroll:SetVerticalScroll(value or 0) end)
  keybindFrame.scroll:SetScript("OnMouseWheel", function(_,delta)
    if keybindFrame.scrollBar:IsShown() then keybindFrame.scrollBar:SetValue((keybindFrame.scrollBar:GetValue() or 0) - delta*38) end
  end)

  keybindFrame.reset = CreateFrame("Button", nil, keybindFrame)
  keybindFrame.reset:SetSize(142, 26); keybindFrame.reset:SetPoint("BOTTOMLEFT", 14, 10)
  keybindFrame.reset:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  keybindFrame.reset:SetBackdropColor(theme.panelStrong[1],theme.panelStrong[2],theme.panelStrong[3],.94); keybindFrame.reset:SetBackdropBorderColor(theme.dim[1],theme.dim[2],theme.dim[3],.6)
  keybindFrame.reset.text=keybindFrame.reset:CreateFontString(nil,"OVERLAY"); Font(keybindFrame.reset.text,9); keybindFrame.reset.text:SetPoint("CENTER"); keybindFrame.reset.text:SetText("Clear class keybinds")
  keybindFrame.reset:SetScript("OnClick", function()
    local classStore = ClassBindingStore(keybindFrame.className)
    for familyKey in pairs(classStore) do classStore[familyKey] = nil end
    keybindsDirty = true; refreshPending = true
    RefreshKeybindFrame(); RefreshCompact()
  end)

  keybindFrame.capture = CreateFrame("Frame", nil, keybindFrame)
  keybindFrame.capture:SetAllPoints(keybindFrame)
  keybindFrame.capture:SetFrameLevel(keybindFrame:GetFrameLevel() + 30)
  keybindFrame.capture:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  keybindFrame.capture:SetBackdropColor(0.02,0.02,0.025,0.96); keybindFrame.capture:SetBackdropBorderColor(theme.accent[1],theme.accent[2],theme.accent[3],.9)
  keybindFrame.capture:EnableMouse(true); keybindFrame.capture:EnableMouseWheel(true)
  keybindFrame.capture.message = keybindFrame.capture:CreateFontString(nil,"OVERLAY"); Font(keybindFrame.capture.message,12); keybindFrame.capture.message:SetPoint("CENTER"); keybindFrame.capture.message:SetWidth(540); keybindFrame.capture.message:SetJustifyH("CENTER")
  keybindFrame.capture:SetScript("OnKeyDown", function(_,key) local full=CaptureKeyName(key); if key=="ESCAPE" or key=="BACKSPACE" or key=="DELETE" then full=key end; if full then CompleteBindingCapture(full) end end)
  keybindFrame.capture:SetScript("OnMouseDown", function(_,button)
    local full=MouseBindingKey(button)
    if full == "BUTTON1" or full == "BUTTON2" then
      keybindFrame.capture.pendingKey = nil
      keybindFrame.capture.message:SetText("Use a modifier with the left or right mouse button, or choose another key.")
      keybindFrame.capture.message:SetTextColor(1, 0.48, 0.08, 1)
    elseif full then
      CompleteBindingCapture(full)
    end
  end)
  keybindFrame.capture:SetScript("OnMouseWheel", function(_,delta) CompleteBindingCapture(CaptureKeyName(delta>0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
  keybindFrame.capture:Hide()
  keybindFrame:Hide()
  return keybindFrame
end

RefreshKeybindFrame = function()
  if not keybindFrame or not keybindFrame:IsShown() then return end
  local className, families = CurrentClass()
  keybindFrame.className = className
  keybindFrame.classTitle:SetText("— " .. tostring(className or "Unknown"))

  local used = 1
  local smartRow = keybindRows[1] or CreateKeybindRow(1)
  smartRow:ClearAllPoints(); smartRow:SetPoint("TOPLEFT",0,0); smartRow:SetPoint("RIGHT",keybindFrame.content,"RIGHT",0,0)
  smartRow.isSmart = true
  smartRow.familyRuntime = nil
  smartRow.labelText = "SMART BUFF — NEXT VALID TARGET"
  smartRow.label:SetText(smartRow.labelText)
  smartRow.label:SetTextColor(1, 0.82, 0.28, 1)
  local firstFamily = families and families[1]
  local firstChoice = firstFamily and firstFamily.choices and firstFamily.choices[1]
  smartRow.icon:SetTexture(SpellTexture(firstChoice and firstChoice.spell))
  smartRow.normal:SetSize(272, 26)
  smartRow.normal:ClearAllPoints(); smartRow.normal:SetPoint("RIGHT", -8, 0)
  smartRow.normal.text:SetText(BindingDisplayText(CurrentFamilyBinding(className, SMART_FAMILY_KEY, SMART_BINDING_MODE)))
  smartRow.normal:SetEnabled(#(families or {}) > 0)
  smartRow.normal:SetScript("OnClick", function() if not smartRow.normal.disabled then BeginBindingCapture(smartRow, SMART_BINDING_MODE) end end)
  smartRow.greater:Hide()
  smartRow:Show()

  for _, familyRuntime in ipairs(families or {}) do
    used = used + 1
    local row = keybindRows[used] or CreateKeybindRow(used)
    row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-((used-1)*38)); row:SetPoint("RIGHT",keybindFrame.content,"RIGHT",0,0)
    row.isSmart = false
    row.familyRuntime = familyRuntime
    row.labelText = familyRuntime.definition.label or familyRuntime.definition.key
    row.label:SetText(row.labelText)
    row.label:SetTextColor(1, 1, 1, 1)
    local first = familyRuntime.choices and familyRuntime.choices[1]
    row.icon:SetTexture(SpellTexture(first and first.spell))
    local normalAvailable, greaterAvailable = false, false
    for _, entry in ipairs(familyRuntime.choices or {}) do
      if entry.normalSpell then normalAvailable = true end
      if entry.greaterSpell then greaterAvailable = true end
    end
    local familyKey = familyRuntime.definition.key
    row.normal:SetSize(132, 26)
    row.normal:ClearAllPoints(); row.normal:SetPoint("RIGHT", -148, 0)
    row.normal:SetScript("OnClick", function() if not row.normal.disabled then BeginBindingCapture(row, "normal") end end)
    row.greater:SetScript("OnClick", function() if not row.greater.disabled then BeginBindingCapture(row, "greater") end end)
    row.greater:Show()
    row.normal.text:SetText(normalAvailable and BindingDisplayText(CurrentFamilyBinding(className,familyKey,"normal")) or "Unavailable")
    row.greater.text:SetText(greaterAvailable and BindingDisplayText(CurrentFamilyBinding(className,familyKey,"greater")) or "Unavailable")
    row.normal:SetEnabled(normalAvailable); row.greater:SetEnabled(greaterAvailable)
    row:Show()
  end
  for index=used+1,#keybindRows do keybindRows[index]:Hide() end
  local contentHeight=math.max(38,used*38); keybindFrame.content:SetHeight(contentHeight)
  local viewport=keybindFrame.scroll:GetHeight() or 228; local maxScroll=math.max(0,contentHeight-viewport)
  keybindFrame.scrollBar:SetMinMaxValues(0,maxScroll)
  if maxScroll>0 then keybindFrame.scrollBar:Show() else keybindFrame.scrollBar:SetValue(0); keybindFrame.scroll:SetVerticalScroll(0); keybindFrame.scrollBar:Hide() end
end

local function ToggleKeybindFrame()
  local frame = BuildKeybindFrame()
  if frame:IsShown() then StopBindingCapture(); frame:Hide() else frame:Show(); RefreshKeybindFrame() end
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

  managerFrame.keybinds = CreateFrame("Button", nil, managerFrame)
  managerFrame.keybinds:SetSize(124, 26)
  managerFrame.keybinds:SetPoint("LEFT", managerFrame.reset, "RIGHT", 8, 0)
  managerFrame.keybinds:SetBackdrop({bgFile="Interface\Buttons\WHITE8X8", edgeFile="Interface\Buttons\WHITE8X8", edgeSize=1})
  managerFrame.keybinds:SetBackdropColor(theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.94)
  managerFrame.keybinds:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  managerFrame.keybinds.text = managerFrame.keybinds:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.keybinds.text, 9)
  managerFrame.keybinds.text:SetPoint("CENTER")
  managerFrame.keybinds.text:SetText("Keybinds")
  managerFrame.keybinds.text:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  managerFrame.keybinds:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.85) end)
  managerFrame.keybinds:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55) end)
  managerFrame.keybinds:SetScript("OnClick", function() ToggleKeybindFrame() end)

  managerFrame.empty = managerFrame.content:CreateFontString(nil, "OVERLAY")
  Font(managerFrame.empty, 10)
  managerFrame.empty:SetPoint("TOPLEFT", 6, -10)
  managerFrame.empty:SetText("No learned class buffs were found for this character.")
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

function RUI:ToggleBuffKeybindManager()
  ToggleKeybindFrame()
end

function RUI:GetBuffManagerKeybind(className, familyKey, mode)
  return CurrentFamilyBinding(className or select(1, CurrentClass()), familyKey, mode)
end

function RUI:GetSmartBuffManagerKeybind(className)
  return CurrentFamilyBinding(className or select(1, CurrentClass()), SMART_FAMILY_KEY, SMART_BINDING_MODE)
end

function RUI:SetBuffManagerKeybind(className, familyKey, mode, key)
  className = className or select(1, CurrentClass())
  if mode ~= "normal" and mode ~= "greater" then return false end
  RemoveDuplicateClassBinding(className, familyKey, mode, key)
  local changed = SetFamilyBinding(className, familyKey, mode, key)
  if changed then RefreshCompact() end
  return changed
end

function RUI:SetSmartBuffManagerKeybind(className, key)
  className = className or select(1, CurrentClass())
  RemoveDuplicateClassBinding(className, SMART_FAMILY_KEY, SMART_BINDING_MODE, key)
  local changed = SetFamilyBinding(className, SMART_FAMILY_KEY, SMART_BINDING_MODE, key)
  if changed then RefreshCompact() end
  return changed
end

SLASH_RETREATUIBUFFS1 = "/ruibuffs"
SlashCmdList.RETREATUIBUFFS = function(message)
  message = string.lower(tostring(message or "")):gsub("^%s+", ""):gsub("%s+$", "")
  if message == "manager" or message == "assign" or message == "assignments" then
    RUI:ToggleBuffAssignmentManager()
  elseif message == "keybind" or message == "keybinds" or message == "bind" or message == "binds" then
    RUI:ToggleBuffKeybindManager()
  elseif message == "reset" then
    local className = select(1, CurrentClass())
    ClearAssignments(className)
    RUI:Print("Buff assignments reset to automatic defaults for " .. tostring(className) .. ".")
    refreshPending = true
  else
    RUI:ToggleBuffManager()
  end
end

local events = CreateFrame("Frame")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "UNIT_AURA", "UNIT_CONNECTION", "ZONE_CHANGED_NEW_AREA",
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
    keybindsDirty = true
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
  if RefreshKeybindFrame then RefreshKeybindFrame() end
end)
