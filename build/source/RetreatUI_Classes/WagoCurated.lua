local RUI = RetreatUI
if not RUI then return end

-- Curated from the class WeakAura packs supplied by Retreat for beta.11.
-- The packs are used only as a verified source for spell names and IDs;
-- RetreatUI keeps ownership of layout, cooldown rendering and aura tracking.

local function Normalize(value)
  return type(value) == "string" and string.lower(value):gsub("[^%w]", "") or ""
end

local function CopyTable(source)
  local result = {}
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      local nested = {}
      for nestedKey, nestedValue in pairs(value) do nested[nestedKey] = nestedValue end
      result[key] = nested
    else
      result[key] = value
    end
  end
  return result
end

local function IndexRecords(records)
  local byName, byID = {}, {}
  for _, record in ipairs(records or {}) do
    if record.name then byName[Normalize(record.name)] = record end
    for _, alias in ipairs(record.aliases or {}) do byName[Normalize(alias)] = record end
    if tonumber(record.id) then byID[tonumber(record.id)] = record end
  end
  return byName, byID
end

local function BuildRecord(item, bucket, order, byName, byID)
  local source = (item.sourceName and byName[Normalize(item.sourceName)])
    or (item.name and byName[Normalize(item.name)])
    or (tonumber(item.id) and byID[tonumber(item.id)])
  local record = CopyTable(source)

  for key, value in pairs(item) do
    if key ~= "sourceName" then record[key] = value end
  end

  record.order = item.order or order
  record.trackHUD = false
  record.forceMain = nil
  record.forceUtility = nil
  record.hudRow = nil
  record.auraTracker = nil
  record.targetDebuff = item.targetDebuff == true or nil

  if bucket == "main" then
    record.category = item.category or "rotation"
    record.hudRow = "core"
    record.trackHUD = true
    record.trackCooldown = true
    record.forceMain = true
  elseif bucket == "utility" then
    record.category = item.category or "utility"
    record.hudRow = "utility"
    record.trackHUD = true
    record.trackCooldown = true
    record.forceUtility = true
  elseif bucket == "proc" then
    record.category = "proc"
    record.buff = item.buff or item.name
    record.auraID = tonumber(item.auraID) or tonumber(item.id)
    record.trackDuration = item.trackDuration ~= false
    record.auraTracker = true
  elseif bucket == "debuff" then
    record.category = "debuff"
    if item.targetResource == true then
      record.targetResource = true
      record.targetDebuff = nil
    else
      record.targetDebuff = true
    end
  end

  return record
end

local function Curate(className, packID, specification)
  local database = RUI:GetClassSpellDatabase(className)
  if not database then return end

  local byName, byID = IndexRecords(database.spells)
  local result, sequence = {}, 0
  local function AddBucket(bucket, items)
    for _, item in ipairs(items or {}) do
      sequence = sequence + 10
      result[#result + 1] = BuildRecord(item, bucket, sequence, byName, byID)
    end
  end

  AddBucket("main", specification.main)
  AddBucket("utility", specification.utility)
  AddBucket("proc", specification.procs)
  AddBucket("debuff", specification.debuffs)

  database.spells = result
  database.version = math.max(tonumber(database.version) or 1, 4)
  database.source = "Wago-curated by Retreat"
  database.wagoPackID = packID
  database.wagoPackURL = "https://wago.io/" .. packID
  database.disableLiveClassCooldowns = true
end

Curate("Felsworn", "TqH72U66p", {
  main = {
    {name="Bane", id=806812, targetDebuff=true},
    {name="Chaos Rush", id=500028, aliases={"Chaos Rush"}},
    {name="Fel Torpedo", id=520853},
    {name="Reckoning", id=802058},
    {name="Annihilation", id=803904},
    {name="Blood of Mannoroth", id=802075},
    {name="Burning Hatred", id=805239},
    {name="Infernal", id=560284},
    {name="Infernal Whipcrack", id=805243},
    {name="Manaburn", id=805248},
    {name="Annihilan Strike", id=801903},
    {name="Skull of Gul'dan", id=800225, aliases={"Skull of Gil'dan"}},
    {name="Felbane", id=525001},
  },
  utility = {
    {name="Fury of the Illidari", id=561216, category="defensive"},
    {name="Tyrant's Gaze", id=805240, category="defensive"},
    {name="Taunt", id=804220, sourceName="Tank Taunt", category="taunt"},
    {name="Fury Unleashed", id=555738, category="defensive"},
    {name="Hateforged Barrier", id=705129, category="defensive"},
    {name="Felhoof Charge", id=800204, category="mobility"},
    {name="Demonic Will", id=800209, category="defensive"},
    {name="Tyrannical Resolve", id=804823, category="taunt"},
    {name="Felbreak", id=800203, category="interrupt"},
    {name="Whispers of the Pit", id=805235, category="interrupt"},
    {name="Blur", id=578345, category="defensive"},
    {name="Illidan's Guile", id=806109, category="defensive"},
    {name="Fel Bargain", id=807942, category="utility"},
    {name="Eye of Archimonde", id=804052, category="utility"},
  },
  procs = {
    {name="Inner Demon", id=804216},
    {name="Infernal Whipcrack", id=805243},
    {name="Tyrannical Resolve", id=804823},
    {name="Demonic Will", id=800209},
    {name="Burning Hatred", id=805239},
    {name="Felstrider", id=707513},
    {name="Felguard", id=704360},
    {name="Mark of Chaos", id=524947},
    {name="Reckoning", id=802058},
    {name="Felforged", id=300490},
    {name="Carve", id=807424},
    {name="Annihilation", id=803904},
    {name="Abyssal Conditioning", id=807431},
    {name="Vengeance Is Mine", id=804822},
    {name="Oblivion", id=572889},
    {name="Nether Champion", id=705145},
    {name="Chaotic Intuition", id=300483},
    {name="Chaotic", id=681376},
    {name="Fury Unleashed", id=555738},
    {name="Sculptor of Doom", id=801235},
    {name="Fel Instincts", id=560645, aliases={"Fel Insticts"}},
    {name="Pit Lord's Rage", id=705142},
    {name="Pit Lord's Rage (Damage)", id=705143},
    {name="Blood of Mannoroth", id=802075},
    {name="Hateforged Barrier", id=705129},
    {name="Skull of Gul'dan", id=800225},
    {name="Illidan's Guile", id=806109},
  },
  debuffs = {
    {name="Bane", id=806812},
  },
})

Curate("Starcaller", "Y5UDib4zq", {
  main = {
    {name="Aspect of the Cosmos", id=801123, targetDebuff=true},
    {name="Aspect of the Goddess", id=802203},
    {name="Sentinel Blade", id=800506, sourceName="Sentinel Glaive", aliases={"Sentinel Glaive"}},
    {name="Astral Blade", id=805563},
    {name="Warden's Blade", id=806812},
    {name="Fan of Knives", id=680703},
    {name="Avatar of Vengeance", id=680822},
    {name="Trueshot", id=520590},
    {name="Starcall", id=800497},
    {name="Drawstring of Elune", id=801975},
    {name="Arrows In The Night", id=520481},
    {name="Arrow of the Goddess", id=563725},
    {name="Shadowsong Mantle", id=805439, sourceName="Shadowsong's Mandate", aliases={"Shadowsong's Mandate"}},
    {name="Moonwell", id=804739},
    {name="Starshatter", id=801135},
    {name="Huntress Saber", id=524643},
  },
  utility = {
    {name="Reverse Magic", id=570231, category="utility"},
    {name="Astral Aegis", id=806155, category="defensive"},
    {name="Halt", id=807741, category="control"},
    {name="Vial of Moonwell Water", id=804652, category="defensive"},
    {name="Shooting Star", id=800505, category="mobility"},
    {name="Stellar Drift", id=800501, category="mobility"},
    {name="Taunt", id=804386, category="taunt"},
    {name="Vigil of the Moon", id=802797, category="defensive"},
    {name="Tidal Rebirth", id=801793, category="utility"},
    {name="Celestial Aegis", id=801126, category="defensive"},
  },
  procs = {
    {name="Lunar Phase", id=802985, maxStacks=10},
    {name="Lunar Charge", id=680215},
    {name="Starfire Barrage", id=572318},
    {name="Stellar Amplification", id=801143},
    {name="Shooting Star", id=800505},
    {name="Scattering Blades", id=806738},
    {name="Arrows In The Night", id=520481},
    {name="Pulverizing Blade", id=805437},
    {name="On The Hunt", id=504006},
    {name="Continual Starfall", id=503584},
    {name="Celestial Aegis", id=801126},
    {name="Shadowsong Mantle", id=805439},
    {name="Huntress Saber", id=524643},
    {name="Avatar of Vengeance", id=680822},
    {name="Drawstring of Elune", id=801975},
  },
  debuffs = {
    {name="Shattered Stars", id=804378, targetResource=true, maxStacks=8},
    {name="Shattered Stars (Alternate)", id=254271, aliases={"Shattered Stars","Scattered Stars"}, targetResource=true, maxStacks=8},
    {name="Shattered Stars (Empowered)", id=807301, aliases={"Shattered Stars","Scattered Stars"}, targetResource=true, maxStacks=8},
  },
})

Curate("Venomancer", "zBApoum1h", {
  main = {
    {name="Wilt", id=620072, targetDebuff=true},
    {name="Spore", id=804983, targetDebuff=true},
    {name="Mycosis", id=572156},
    {name="Serpent's Fang", id=552783},
    {name="Fungarian", id=504344, sourceName="Fungal Assailant", aliases={"Fungal Assailant"}},
    {name="Green Salve", id=800902},
    {name="Shadra's Balm", id=800901},
    {name="Mending Mist", id=800899},
    {name="Alkahest", id=578310},
    {name="Expulsion", id=805094},
    {name="Barbed Stinger", id=803196},
    {name="Hive Swarm", id=560247, sourceName="Locust Swarm", aliases={"Locust Swarm"}},
    {name="Nerubian Sting", id=800882, targetDebuff=true},
    {name="Withering Venom", id=706962, targetDebuff=true},
    {name="Rotfang", id=804977, targetDebuff=true},
    {name="Facemelter", id=800871, targetDebuff=true},
    {name="Noxious Empowerment", id=804964},
    {name="Hive Instinct", id=804968},
    {name="Decay", id=800910},
    {name="Serpent Lord's Ring", id=503923},
    {name="Vile Sting", id=805097},
    {name="Pinch", id=704235},
    {name="Shadra's Aid", id=504352},
    {name="Toxic Communion", id=680767},
    {name="Extraction", id=805884},
    {name="Mycelial Replenishment", id=706021},
    {name="Serpent Lord's Amulet", id=800914},
    {name="Lifeblood", id=804963},
  },
  utility = {
    {name="Impale", id=560248, category="control"},
    {name="Carapace Regeneration", id=805931, category="defensive", trackCharges=true},
    {name="Molt", id=805102, category="mobility"},
    {name="Chitin Rush", id=803644, category="mobility"},
    {name="Regrow Exoskeleton", id=803197, category="defensive"},
    {name="Harden", id=800892, category="defensive"},
    {name="Nullifying Toxin", id=805096, category="utility"},
    {name="Celerity", id=804962, category="mobility"},
    {name="Rebirth", id=807675, category="utility"},
  },
  procs = {
    {name="Vizier Form", id=800912},
    {name="Weaver Form", id=804980},
    {name="Spider Form", id=800841},
    {name="Beetle Form", id=803183},
    {name="Serpent Lord's Ring", id=503923},
    {name="Shadra's Prayer", id=502947},
    {name="Extraction", id=805884},
    {name="Mycelial Replenishment", id=706021},
    {name="Serpent Lord's Amulet", id=800914},
    {name="Exposed Flesh", id=805095},
    {name="Acidfang", id=806602},
    {name="Deadly Sting", id=804118, aliases={"Widow's Kiss"}},
    {name="Tome of Ahk'kahet", id=705993},
    {name="Cycle of Decay", id=500219},
    {name="Adrenal Venom", id=805894},
  },
  debuffs = {
    {name="Fungal Growth", id=804971},
    {name="Barbed Stinger", id=680854},
    {name="Venomtip Poison", id=804118},
    {name="Blight Venom", id=805776},
    {name="Debilitating Venom", id=805731},
    {name="Weakening Venom", id=805778},
  },
})

Curate("Reaper", "wQdFYTpm6", {
  main = {
    {name="Ghostly Weapon", id=803997},
    {name="Withering Touch", id=573071, targetDebuff=true},
    {name="Soul Tap", id=807397},
    {name="Wraithblade", id=805258},
    {name="Spectral Scythe", id=500484},
    {name="Harvesting Grounds", id=705413, targetDebuff=true},
    {name="Endbringer", id=800922},
    {name="Harvest Time", id=803995},
    {name="Shade", id=573038},
    {name="Spectral Warden", id=805716},
    {name="Sepulchral Renewal", id=561102},
    {name="Decimate", id=500523},
    {name="Cull", id=800940},
    {name="Ghost Claw", id=803985},
  },
  utility = {
    {name="Siphon Essence", id=806125, category="interrupt"},
    {name="Scythe Rush", id=500359, category="mobility"},
    {name="Tormented Souls", id=500483, category="defensive"},
    {name="Jailer's Bargain", id=805718, category="defensive"},
    {name="Bolstered Form", id=680337, category="defensive"},
    {name="Masochistic Rage", id=803030, category="defensive"},
    {name="Limbo", id=800845, category="defensive"},
    {name="Wraithstride", id=803990, sourceName="Veilwalk", aliases={"Veilwalk"}, category="mobility"},
    {name="Chains of the Godless", id=805191, category="control"},
    {name="Ghastly Screech", id=806146, category="control"},
    {name="Soulstone Lure", id=561376, category="utility"},
  },
  procs = {
    {name="Spectral Scythe", id=500484},
    {name="Masochistic Rage", id=803030},
    {name="Decimation Ready", id=704215},
    {name="Eater of Souls", id=805181},
    {name="Tormented Souls", id=500483},
    {name="Decimation", id=704193},
    {name="Dark Soldier", id=560491},
    {name="Underwalk", id=800797},
    {name="Fatesealer", id=705443},
    {name="Soul Fragment", id=805077},
    {name="Dreadshell", id=300557},
    {name="Rite of the Reaper", id=578127},
    {name="Rite of the Wraith", id=803313},
    {name="Rite of Souls", id=575839},
    {name="Deathwind", id=502992},
  },
  debuffs = {
    {name="Essence Binder"},
    {name="Deathwind", id=502992},
    {name="Murder"},
    {name="Scythe Rush", id=500359},
    {name="Requiem"},
    {name="Soul Splinter", id=805720},
    {name="Soulrend"},
    {name="Soulslam", id=504014},
    {name="Withering Touch", id=573071},
    {name="Writhe", id=801337},
  },
})

Curate("Primalist", "hZsQ_ZVIL", {
  main = {
    {name="Spiritual Frenzy", id=502728},
    {name="Earthmother's Binding", id=805107},
    {name="Totemic Smash", id=802554},
    {name="Seismic Crash", id=503261},
    {name="Seismic Wave", id=572878},
    {name="Rylak's Bite", id=706491},
    {name="Quake", id=505157},
    {name="Primal Convergence", id=800181},
    {name="Frenzied Roar", id=800133},
    {name="Savage Frenzy", id=806549},
    {name="Grove Guardian", id=503721},
    {name="Therazane's Rage", id=503736},
    {name="Call of the Wild", id=53434},
    {name="Primal Totem", id=504229},
    {name="Sacred Grove", id=800180},
    {name="Sacred Grove (Empowered)", id=805919},
    {name="Primal Awakening", id=807560},
    {name="Nature's Call", id=800146},
    {name="Neptulon's Wrath", id=807467},
  },
  utility = {
    {name="Primal Rush", id=500770, category="mobility"},
    {name="Spirit Charge", id=504570, category="mobility"},
    {name="Rock Barrier", id=503630, category="defensive", trackCharges=true},
    {name="Ancient of War", id=504222, category="mobility"},
    {name="Earthen Avatar", id=680421, category="defensive"},
    {name="Bearskin", id=800094, category="defensive"},
    {name="Spirit Stable", id=573310, category="utility"},
  },
  procs = {
    {name="Boon of the Turtle", id=500935},
    {name="Boon of the Bear", id=500939},
    {name="Boon of the Wolf", id=800137},
    {name="Boon of the Hawk", id=500943},
    {name="Boon of the Lion", id=504856},
    {name="Primal Convergence", id=800181},
    {name="Earthen Avatar", id=680421},
    {name="Wildheart", id=803980},
    {name="Primal Awakening", id=807560},
    {name="Primal Totem", id=504229},
    {name="Grove Guardian", id=503721},
    {name="Sacred Grove", id=800180},
    {name="Call of the Wild", id=53434},
    {name="Savage Frenzy", id=806549},
    {name="Furious Howl", id=64493},
    {name="Misha's Rage", id=560975},
    {name="Culling the Herd", id=52858},
    {name="Huffer's Speed", id=560973},
    {name="Leokk's Fury", id=560974},
    {name="Rylak's Blessing", id=802595},
    {name="Earth's Rage", id=806068},
    {name="Wild Carnage", id=503717},
    {name="Wild Carnage (Alternate)", id=800041, aliases={"Wild Carnage"}},
    {name="Protective Roar", id=800142},
    {name="Frenzied Roar", id=800133},
    {name="Bearskin", id=800094},
    {name="Empowered Boon of the Turtle", id=523523},
    {name="Empowered Boon of the Bear", id=523524},
    {name="Wild and Dangerous", id=562312},
    {name="Aftershock", id=301086},
  },
  debuffs = {},
})
