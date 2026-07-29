local RUI = RetreatUI

-- Necromancer records are intentionally name-first. Ascension has several
-- internal IDs and ranked variants for the same visible spell, while the
-- spellbook name follows the version the player has actually learned.
RUI:RegisterClassSpellDatabase("Necromancer", {
  collectorClassFile = "NECROMANCER",
  tabs = {"Animation","Death","Rime"},
  version = 2,
  source = "RetreatUI Data Collector 1.0.0: complete Necromancer class/spec tree and resolved spell catalogue",
  resources = {
    {key="primary", name="Runic Power", type="primary", position="power"},
    {key="lifeForce", name="Life Force", type="native-mirror", position="resource"},
  },
  spells = {
    --------------------------------------------------------------------------
    -- Main rotation and important personal cooldowns. Only learned/castable
    -- records are displayed, so the same data supports Rime, Death and
    -- Animation without hard-coding a level or a selected spec.
    --------------------------------------------------------------------------
    {name="Lichfrost", category="rotation", hudRow="core", order=10, trackCooldown=true, forceMain=true, glowWhenAura={"Bone King"}, glowWhenAuraID={707175}},
    {name="Flesh to Worms", id=500338, category="rotation", hudRow="core", order=30, talent=true, trackCooldown=true},
    {name="Corpse Explosion", category="rotation", hudRow="core", order=50, trackCooldown=true},
    {name="Glacial Impact", id=704355, category="rotation", hudRow="core", order=60, talent=true, trackCooldown=true},
    {name="Ice Barrage", id=801760, category="rotation", hudRow="core", order=70, talent=true, trackCooldown=true},
    {name="Lichplague", id=802132, category="rotation", hudRow="core", order=80, talent=true, trackCooldown=true},
    {name="Plague of Undeath", id=801945, category="rotation", hudRow="core", order=90, talent=true, trackCooldown=true},
    {name="March of the Dead", id=707007, category="rotation", hudRow="core", order=100, talent=true, trackCooldown=true},

    {name="Glacial Tap", id=805369, category="resource", hudRow="core", order=110, talent=true, trackCooldown=true},
    {name="Mutation", id=500342, category="offensive", hudRow="core", order=120, talent=true, trackCooldown=true, buff="Mutation", trackDuration=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Virulency", id=801938, category="offensive", hudRow="core", order=130, talent=true, trackCooldown=true, buff="Virulency", trackDuration=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Unholy Frenzy", id=91232, category="offensive", hudRow="core", order=140, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Army of the North", id=561138, category="offensive", hudRow="core", order=150, talent=true, trackCooldown=true, buff="Army of the North", trackDuration=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Frost Wyrm", id=805428, category="offensive", hudRow="core", order=160, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Bone Construct", id=531130, category="offensive", hudRow="core", order=162, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Skeletal Archer", id=805040, category="offensive", hudRow="core", order=164, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Bone Wraith", id=805032, category="offensive", hudRow="core", order=166, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Tomb King", id=805044, category="offensive", hudRow="core", order=168, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Animate: Plaguefather", id=805048, category="offensive", hudRow="core", order=169, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Bone Tithe", id=802121, category="defensive", hudRow="utility", order=170, talent=true, trackCooldown=true, buff="Bone Tithe", trackDuration=true, trackAbsorb=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Foul Invocation", id=804371, category="defensive", hudRow="utility", order=180, talent=true, trackCooldown=true, buff="Foul Invocation", trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Lich Form", id=500981, category="form", hudRow="core", order=190, talent=true, trackCooldown=true, buff="Lich Form", trackDuration=true},
    {name="Fetid Ward", id=680388, category="defensive", hudRow="utility", order=200, trackCooldown=false, buff="Fetid Ward", trackDuration=true},

    --------------------------------------------------------------------------
    -- Utility, control, commands and summons.
    --------------------------------------------------------------------------
    {name="Heartchill", id=801739, category="interrupt", hudRow="utility", order=10, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Command: Hook", id=504316, category="control", hudRow="utility", order=20, talent=true, trackCooldown=true},
    {name="Command: Bonefreeze", id=504489, category="control", hudRow="utility", order=30, talent=true, trackCooldown=true},
    {name="Command: Blight", id=504050, category="control", hudRow="utility", order=40, talent=true, trackCooldown=true},
    {name="Mass Grave", id=803741, category="control", hudRow="utility", order=50, talent=true, trackCooldown=true},
    {name="Death's Due", id=807796, category="utility", hudRow="utility", order=60, talent=true, trackCooldown=true},
    {name="Phylactery", id=500933, category="defensive", hudRow="utility", order=70, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Sacrifice Undead", category="utility", hudRow="utility", order=80, trackCooldown=true},
    {name="Summoning Ritual", id=805038, category="mobility", hudRow="utility", order=90, talent=true, trackCooldown=true},
    {name="Ritual Return", category="mobility", hudRow="utility", order=100, trackCooldown=true},
    {name="Create Frozen Reliquary", id=803772, category="utility", hudRow="utility", order=105, talent=true, trackCooldown=false},


    --------------------------------------------------------------------------
    -- Player proc/state auras. These are active-only trackers and therefore do
    -- not clutter the HUD when the related specialization/talent is absent.
    --------------------------------------------------------------------------
    {name="Tundra Warriors", id=92122, category="proc", auraTracker=true, trackHUD=false, order=10, maxStacks=3},
    {name="Deadly Bond", id=704724, category="proc", auraTracker=true, trackHUD=false, order=20},
    {name="Refreshing Chill", id=300940, category="proc", auraTracker=true, trackHUD=false, order=30},
    {name="Bone King", id=707175, category="proc", auraTracker=true, trackHUD=false, order=40},
    {name="Ner'zhul's Blessing", id=803797, category="proc", auraTracker=true, trackHUD=false, order=50},
    {name="Frozen Bodies", id=707562, category="proc", auraTracker=true, trackHUD=false, order=60, maxStacks=10},
    {name="Diabolical", id=704723, category="proc", auraTracker=true, trackHUD=false, order=70, maxStacks=15},
    {name="Death Commander", id=300235, category="proc", auraTracker=true, trackHUD=false, order=80},
    {name="Permafrost", id=704681, category="proc", auraTracker=true, trackHUD=false, order=90},
    {name="Rotting Flesh", id=574138, category="proc", auraTracker=true, trackHUD=false, order=100},
    {name="Rot Fetishist", id=805675, category="proc", auraTracker=true, trackHUD=false, order=110},
    {name="Underking", id=704701, category="proc", auraTracker=true, trackHUD=false, order=120, maxStacks=10},
    {name="Mindless Fury", id=805674, category="proc", auraTracker=true, trackHUD=false, order=130, maxStacks=5},
    {name="Frost Runes", id=705750, category="proc", auraTracker=true, trackHUD=false, order=140},
    {name="Life For Power", id=705746, category="proc", auraTracker=true, trackHUD=false, order=150, trackAbsorb=true},

    --------------------------------------------------------------------------
    -- Important self/pet-applied target debuffs. The HUD filters to this list
    -- and will not display every random debuff on the target.
    --------------------------------------------------------------------------
    {name="Crypt Plague", id=92121, category="debuff", targetDebuff=true, order=10, maxStacks=15},
    {name="Flesh to Worms", id=500338, category="debuff", targetDebuff=true, order=20},
    {name="Blight", category="debuff", targetDebuff=true, order=30},
    {name="Lichplague", id=802132, category="debuff", targetDebuff=true, order=40},
    {name="Plague of Undeath", id=801945, category="debuff", targetDebuff=true, order=50},
    {name="Expunge", id=705754, category="debuff", targetDebuff=true, order=60, maxStacks=2},
    {name="Fetid Mark", id=706948, category="debuff", targetDebuff=true, order=70, maxStacks=10},
    {name="Festering Decay", id=806324, category="debuff", targetDebuff=true, order=80},
    {name="Parasites", id=560730, category="debuff", targetDebuff=true, order=90},
    {name="Soulfreeze", id=572023, category="debuff", targetDebuff=true, order=100},
    {name="Icecrown", id=531135, category="debuff", targetDebuff=true, order=110, maxStacks=3},
    {name="Death's Due", id=807796, category="debuff", targetDebuff=true, order=120},
    {name="Zombie Plague", category="debuff", targetDebuff=true, order=130},
    {name="Disease Cloud", category="debuff", targetDebuff=true, order=140},

    {name="Entomb", id=280060, category="control", hudRow="utility", order=200, trackCooldown=true, targetDebuff=true, fallbackIcon="Interface\\Icons\\Ability_FiegnDead", sourceTab="ClassSpell", cooldownHint=60},
    {name="Gravebound Champion", id=280520, category="offensive", hudRow="core", order=400, trackCooldown=true, buff="Gravebound Champion", trackDuration=true, fallbackIcon="Interface\\Icons\\Spell_Deathknight_BloodPresence", sourceTab="ClassSpell", cooldownHint=300},
    {name="Frost Wyrm", id=280740, category="offensive", hudRow="core", order=220, trackCooldown=true, buff="Frost Wyrm", trackDuration=true, targetDebuff=true, fallbackIcon="Interface\\icons\\5_dragoncoldbreath_Border", sourceTab="ClassSpell", cooldownHint=120},

    {name="Ghoul Mastery", id=503740, category="proc", order=90, buff="Ghoul Mastery", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\ability_demonhunter_reversemagic", sourceTab="Animation", collectorEntryID=7119},
    {name="Plague Horde", id=802986, category="proc", order=110, buff="Plague Horde", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_belt_pvpwarlock_e_01", sourceTab="Animation", collectorEntryID=4238},
    {name="Creeping Crypt", id=300960, category="proc", order=120, buff="Creeping Crypt", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\ability_deathwing_sealarmorbreachgreen", sourceTab="Death", collectorEntryID=6295},
    {name="Parasite Plague", id=560730, category="proc", order=150, buff="Parasite Plague", trackDuration=true, targetDebuff=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Ability_Creature_Disease_01", sourceTab="Death", collectorEntryID=29946},
    {name="Chilling Presence", id=300958, category="proc", order=160, buff="Chilling Presence", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_DeathKnight_IceBoundFortitude", sourceTab="Rime", collectorEntryID=33723},
    {name="Master Lich", id=560848, category="proc", order=170, buff="Master Lich", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=3, talent=true, fallbackIcon="Interface\\icons\\epic_rpg_icon_pack_frost_0000s_0000_figure_Border", sourceTab="Rime", collectorEntryID=33738},
    {name="Army of the Dead", id=525600, category="proc", order=230, buff="Army of the Dead", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\_D3graspofthedead", sourceTab="Animation", collectorEntryID=7298},
    {name="Depravity", id=638403, category="proc", order=250, buff="Depravity", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_mace_1h_warfrontsforsaken_d_01", sourceTab="Animation", collectorEntryID=5766},
    {name="Dark Harvester", id=807960, category="proc", order=260, buff="Dark Harvester", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Shadow_AuraOfDarkness", sourceTab="Death", collectorEntryID=30821},
    {name="Muck Summoner", id=806086, category="proc", order=270, buff="Muck Summoner", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_fishing_lure_worm", sourceTab="Death", collectorEntryID=30915},
    {name="Curse of the Lich", id=300240, category="proc", order=280, buff="Curse of the Lich", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\_CasterCloak_Ice", sourceTab="Rime", collectorEntryID=34978},
    {name="Death and Ice", id=560012, category="proc", order=290, buff="Death and Ice", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\ability_mage_frostjaw", sourceTab="Rime", collectorEntryID=30355},
    {name="Frigid Winds", id=504357, category="proc", order=300, buff="Frigid Winds", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\custom_T_Nhance_RPG_Icons_IceWave_Border", sourceTab="Rime", collectorEntryID=7213},
    {name="Hoarfrost Hands", id=803291, category="proc", order=310, buff="Hoarfrost Hands", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Call_of_the_Sepulcher_64x64", sourceTab="Rime", collectorEntryID=6488},
    {name="Raising the Kirin Tor", id=805649, category="proc", order=320, buff="Raising the Kirin Tor", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Nature_Brilliance", sourceTab="Rime", collectorEntryID=6892},
  },
})
