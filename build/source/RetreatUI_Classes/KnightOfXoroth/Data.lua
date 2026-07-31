local RUI = RetreatUI

RUI:RegisterClassSpellDatabase("Knight of Xoroth", {
  collectorClassFile = "FLESHWARDEN",
  tabs = {"Defiance","Hellfire","War"},
  version = 6,
  source = "Ascension DB + Pyro KoX Hellfire WeakAura audit + RetreatUI runtime discovery",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="demonfire", name="Demonfire", type="stacks", max=6, position="resource"},
    {key="hellfireImp", name="Hellfire Imp", type="summon", position="resource"},
    {key="demonBlood", name="Demon's Blood", type="stacks", position="resource"},
  },
  spells = {
    -- Main combat row. The order is stable; unlearned records are omitted.
    {name="Sever", category="rotation", hudRow="core", order=10, trackCooldown=true},
    {name="Infernal Strike", id=501518, category="rotation", hudRow="core", order=15, trackCooldown=true, hideWhen={{name="Shieldgore", id=301302}}},
    {name="Unleash Pestilence", category="rotation", hudRow="core", order=20, trackCooldown=true, cooldownHint=4},

    -- Learned-only specialization abilities. Names are authoritative so higher
    -- ranks and replacement spell IDs are resolved from the live spellbook.
    {name="Shieldgore", id=301302, category="rotation", hudRow="core", order=25, talent=true, trackCooldown=true, sourceTab="Defiance", collectorEntryID=30229},
    {name="Gore", id=680941, category="rotation", hudRow="core", order=26, talent=true, trackCooldown=true, trackCharges=true, cooldownHint=8, sourceTab="War", collectorEntryID=31166},
    {name="Seeking Flame", id=560668, category="rotation", hudRow="core", order=27, talent=true, trackCooldown=true, cooldownHint=6, sourceTab="Hellfire", collectorEntryID=30709},
    {name="Blade of Xoroth", id=560675, category="rotation", hudRow="core", order=27.5, talent=true, trackCooldown=true, sourceTab="Hellfire", source="PyroKoXAudit"},
    {name="Hellmaw", id=806965, category="rotation", hudRow="core", order=28, talent=true, trackCooldown=true, sourceTab="Hellfire", collectorEntryID=31167},
    {name="Skulltaker", category="rotation", hudRow="core", order=29, talent=true, trackCooldown=true, sourceTab="Hellfire"},
    {name="Warbringer", id=570727, category="rotation", hudRow="core", order=30, talent=true, trackCooldown=true, sourceTab="War", collectorEntryID=12166},
    {name="Meatsaw", category="rotation", hudRow="core", order=31, talent=true, trackCooldown=true, sourceTab="War"},
    {name="Flames of Xoroth", id=801059, category="rotation", hudRow="core", order=32, talent=true, trackCooldown=true, targetDebuff=true, sourceTab="Hellfire"},

    -- Specialization combat cooldowns remain in the main row because they are
    -- part of the active damage plan rather than situational utility.
    {name="Pestilence of Death", id=801054, category="stance", order=35, talent=true, trackHUD=false, classState=true, sourceTab="War", collectorEntryID=29621},
    {name="Pestilence of Apocalypse", id=804786, category="stance", order=36, talent=true, trackHUD=false, classState=true, sourceTab="Hellfire", collectorEntryID=30697},
    {name="Decimation", id=524913, category="offensive", hudRow="core", order=37, talent=true, trackCooldown=true, cooldownHint=120, buff="Decimation", auraTracker=true, trackDuration=true, sourceTab="War", collectorEntryID=7810, partyCooldown=true, cooldownCategory="offensive"},
    {name="Burning Blade", id=524920, category="offensive", hudRow="core", order=38, talent=true, trackCooldown=true, cooldownHint=60, buff="Burning Blade", auraTracker=true, trackDuration=true, sourceTab="War", collectorEntryID=7889, partyCooldown=true, cooldownCategory="offensive"},
    {name="Hellstorm", id=802342, category="offensive", hudRow="core", order=39, talent=true, trackCooldown=true, cooldownHint=30, sourceTab="Hellfire", collectorEntryID=34100},
    {name="Doom", id=802602, category="offensive", hudRow="core", order=40, talent=true, trackCooldown=true, cooldownHint=30, sourceTab="Hellfire", collectorEntryID=34108, partyCooldown=true, cooldownCategory="offensive"},
    {name="Hell Scream", id=801002, category="offensive", hudRow="core", order=40.2, talent=true, trackCooldown=true, buff="Hell Scream", auraTracker=true, trackDuration=true, sourceTab="Hellfire", source="PyroKoXAudit"},
    {name="Burning Scripture", id=805696, category="offensive", hudRow="core", order=40.4, talent=true, trackCooldown=true, sourceTab="Hellfire", source="PyroKoXAudit"},
    {name="Hellfire Form", id=804006, category="offensive", hudRow="core", order=41, talent=true, trackCooldown=true, cooldownHint=120, buff="Hellfire Form", auraTracker=true, trackDuration=true, sourceTab="Hellfire", collectorEntryID=34066, partyCooldown=true, cooldownCategory="offensive"},

    {name="Chainwhip", category="interrupt", hudRow="utility", order=30, trackCooldown=true, cooldownHint=20, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Snarl", category="taunt", hudRow="utility", order=40, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Implosion", id=524897, category="rotation", hudRow="core", order=50, talent=true, trackCooldown=true, cooldownHint=40, sourceTab="Defiance", collectorEntryID=34132},
    {name="Xorothian Sigil", id=801061, category="utility", hudRow="utility", order=60, talent=true, trackCooldown=true, cooldownHint=60, sourceTab="Class", collectorEntryID=30695},
    {name="Burning Rage", id=520295, category="offensive", hudRow="core", order=70, talent=true, trackCooldown=true, cooldownHint=60, sourceTab="Class", collectorEntryID=34112, partyCooldown=true, cooldownCategory="offensive"},
    {name="Legion's Presence", id=804879, category="offensive", hudRow="core", order=80, talent=true, trackCooldown=true, cooldownHint=180, sourceTab="Defiance", collectorEntryID=30428, partyCooldown=true, cooldownCategory="offensive"},
    {name="Juggernaut", id=520294, category="defensive", hudRow="utility", order=85, talent=true, trackCooldown=true, cooldownHint=120, buff="Juggernaut", auraTracker=true, trackDuration=true, sourceTab="Class", collectorEntryID=30016, partyCooldown=true, cooldownCategory="defensive"},
    {name="Call: Hellfire Imp", id=804883, category="summon", hudRow="core", order=90, talent=true, trackCooldown=true, cooldownHint=10, sourceTab="Defiance", collectorEntryID=30236, becomesPassiveWhen={{name="Impcaller", id=706755}}, hideWhen={{name="Impcaller", id=706755}}},
    {name="Hellish Rebuke", id=503310, category="proc", order=100, trackHUD=false, buff="Hellish Rebuke", auraTracker=true},
    {name="Impcaller", id=706755, category="talent", trackHUD=false, sourceTab="Defiance", collectorEntryID=34085, auditType="active-to-passive conversion", modifies={"Call: Hellfire Imp","Shieldgore"}, effect="Call: Hellfire Imp is transformed; Shieldgore summons the imp passively"},

    -- Utility/defensive row. Chains and displacement tools stay adjacent.
    {name="Demon Heart", id=805669, category="offensive", hudRow="core", order=110, talent=true, trackCooldown=true, cooldownHint=60, sourceTab="Class", collectorEntryID=31701, partyCooldown=true, cooldownCategory="offensive"},
    {name="Black Shield", id=805679, category="defensive", hudRow="utility", order=120, talent=true, trackCooldown=true, cooldownHint=120, buff="Black Shield", auraTracker=true, trackAbsorb=true, sourceTab="Class", collectorEntryID=30701, partyCooldown=true, cooldownCategory="defensive"},
    {name="Infernal Shield", category="defensive", hudRow="utility", order=130, trackCooldown=true, buff="Infernal Shield", partyCooldown=true, cooldownCategory="defensive"},
    {name="Hellbound Charge", id=807247, category="mobility", hudRow="utility", order=140, talent=true, trackCooldown=true, trackCharges=true, cooldownHint=60, sourceTab="Class", collectorEntryID=5453},
    {name="Flesh Hook", category="control", hudRow="utility", order=10, group="chains", trackCooldown=true},
    {name="Chains of Xoroth", id=706756, category="control", hudRow="utility", order=20, group="chains", talent=true, trackCooldown=true, cooldownHint=90, sourceTab="Defiance", collectorEntryID=30699},
    {name="Chains of Malice", id=803185, category="control", hudRow="utility", order=30, group="chains", talent=true, trackCooldown=true, cooldownHint=90, sourceTab="Class", collectorEntryID=30668},
    {name="Hellfire Bellows", id=807587, category="utility", hudRow="utility", order=40, talent=true, trackCooldown=true, sourceTab="Defiance", collectorEntryID=7887},
    {name="Sacrificial Circle", id=805677, category="defensive", hudRow="utility", order=50, talent=true, trackCooldown=true, cooldownHint=60, sourceTab="Defiance", collectorEntryID=6392},
    {name="Create: Hellgate", category="utility", hudRow="utility", order=60, trackCooldown=true},
    {name="Call: Hellfire Abyssal", id=805074, category="summon", hudRow="core", order=70, talent=true, trackCooldown=true, cooldownHint=45, sourceTab="Defiance", collectorEntryID=30498, partyCooldown=true, cooldownCategory="offensive"},

    -- Active aura trackers; not shown as duplicate rotational buttons.
    {name="Suffuse", category="buff", order=10, auraTracker=true, trackDuration=true},
    {name="Hellrider", category="buff", order=30, auraTracker=true, trackDuration=true},

    -- Target debuffs applied by the player.
    {name="Bulwark of Xoroth", id=300388, category="debuff", order=5, targetDebuff=true, auraBar=true, talent=true},
    {name="Demonflare", id=503468, category="debuff", order=7, targetDebuff=true, trackHUD=false, source="PyroKoXAudit"},
    {name="Curse of Xoroth", category="debuff", order=10, targetDebuff=true},
    {name="Torn Flesh", category="debuff", order=20, targetDebuff=true},
    {name="Ritual Fire", category="debuff", order=30, targetDebuff=true},
    {name="Pestilence of Famine", category="debuff", order=40, targetDebuff=true},
    {name="Pestilence of War", category="debuff", order=50, targetDebuff=true},
    {name="Pestilence of Conquest", id=801053, category="debuff", order=60, targetDebuff=true},

    -- Ascension DB candidates that are catalogued but not placed until reviewed ingame.
    {name="Melt", id=803334, category="debuff", review=true, trackHUD=false, source="AscensionDB"},
    {name="Demonfeast", id=501497, category="rotation", review=true, trackHUD=false, source="AscensionDB"},

    {name="Impish Pestilence", id=300398, category="proc", order=10, buff="Impish Pestilence", trackDuration=true, targetDebuff=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_misc_herb_fireweedbranch", sourceTab="Hellfire", collectorEntryID=4706},
    {name="Brimstone Buckler", id=92104, category="proc", order=20, buff="Brimstone Buckler", trackDuration=true, auraTracker=true, trackHUD=false, fallbackIcon="Interface\\Icons\\Ability_Warlock_ImprovedDemonicTactics", sourceTab="Defiance", collectorEntryID=4018},
    {name="Dread", id=706502, category="proc", order=30, buff="Dread", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=10, fallbackIcon="Interface\\Icons\\Spell_Fire_Incinerate", sourceTab="Class", collectorEntryID=30013},
    {name="Demonic Bulwark", id=573066, category="proc", order=40, buff="Demonic Bulwark", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Fire_FireArmor", sourceTab="Defiance", collectorEntryID=12765},
    {name="Cinderblade", id=704959, category="proc", order=50, buff="Cinderblade", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\spell_fire_felflamering_red", sourceTab="Hellfire", collectorEntryID=30706},
    {name="Fury of Xoroth", id=802615, category="proc", order=60, buff="Fury of Xoroth", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=3, talent=true, fallbackIcon="Interface\\Icons\\inv_argusfelstalkermount_red", sourceTab="Hellfire", collectorEntryID=1710},
    {name="Infernal Steel", id=805693, category="proc", order=70, buff="Infernal Steel", trackDuration=true, auraTracker=true, trackHUD=false, fallbackIcon="Interface\\Icons\\inv_sword_1h_artifactfelomelorn_d_02", sourceTab="Hellfire", collectorEntryID=6929},
    {name="Demonic Blade", id=704957, category="proc", order=80, buff="Demonic Blade", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\nhi_blood_blade_Border", sourceTab="War", collectorEntryID=29519},
    {name="Gorged", id=680199, category="proc", order=90, buff="Gorged", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=3, talent=true, fallbackIcon="Interface\\icons\\custom_T_BloodMaw_Border", sourceTab="War", collectorEntryID=29376},
    {name="Hellknight", id=800702, category="proc", order=100, buff="Hellknight", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=5, talent=true, fallbackIcon="Interface\\Icons\\inv_helm_mail_pvphuntergladiator_o_01", sourceTab="War", collectorEntryID=34120},
    {name="A Curse from Hell", id=302548, category="proc", order=110, buff="A Curse from Hell", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\nhi_fireenchantment_Border", sourceTab="Defiance", collectorEntryID=7367},
    {name="Forgefiend's Bulwark", id=801065, category="proc", order=120, buff="Forgefiend's Bulwark", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\epic_rpg_icon_pack_fire_0004s_0000_armor_Border", sourceTab="Defiance", collectorEntryID=29625},
    {name="Hellfire Reprimand", id=706565, category="proc", order=130, buff="Hellfire Reprimand", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_plate_firelands_d_01", sourceTab="Defiance", collectorEntryID=34077},
    {name="Brimstone Splinters", id=805703, category="proc", order=140, buff="Brimstone Splinters", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_flaming_splinter", sourceTab="Hellfire", collectorEntryID=30179},
    {name="Flamewrath", id=301358, category="proc", order=150, buff="Flamewrath", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Fire_LavaSpawn", sourceTab="Hellfire", collectorEntryID=34068},
    {name="Partners in Flames", id=500578, category="proc", order=160, buff="Partners in Flames", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\5_sumimp_Border", sourceTab="Hellfire", collectorEntryID=12607},
    {name="Seething Strikes", id=300375, category="proc", order=170, buff="Seething Strikes", trackDuration=true, targetDebuff=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\epic_rpg_icon_pack_fire_0000s_0000_sword_Border", sourceTab="Hellfire", collectorEntryID=29619},
    {name="Conqueror's Will", id=520372, category="proc", order=180, buff="Conqueror's Will", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\nhi_fireghost_Border", sourceTab="War", collectorEntryID=7929},
    {name="Fiend", id=705005, category="proc", order=190, buff="Fiend", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_mace_1h_pvppandarias1_d_01", sourceTab="War", collectorEntryID=7408},
    {name="Gored", id=705015, category="proc", order=200, buff="Gored", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=2, talent=true, fallbackIcon="Interface\\Icons\\sha_ability_warrior_bloodnova_nightmare", sourceTab="War", collectorEntryID=6936},
    {name="Hellsmelted", id=705016, category="proc", order=210, buff="Hellsmelted", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Fire_Incinerate", sourceTab="War", collectorEntryID=34125},
    {name="The Butcher", id=704952, category="proc", order=220, buff="The Butcher", trackDuration=true, auraTracker=true, trackHUD=false, maxStacks=5, talent=true, fallbackIcon="Interface\\Icons\\artifactability_unholydeathknight_flagellation", sourceTab="War", collectorEntryID=7892},
    {name="Demonfire Retaliation", id=573034, category="proc", order=230, buff="Demonfire Retaliation", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\5_druideskill41_Border", sourceTab="Defiance", collectorEntryID=9485},
    {name="Fiend of Forges", id=300386, category="proc", order=240, buff="Fiend of Forges", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\icons\\uico_fire_spell_03_Border", sourceTab="Defiance", collectorEntryID=34076},
    {name="Pestilent Retaliation", id=704971, category="proc", order=260, buff="Pestilent Retaliation", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\5_bull_Border", sourceTab="Defiance", collectorEntryID=34087},
    {name="To Ashes", id=705000, category="proc", order=270, buff="To Ashes", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Spell_Fire_Volcano", sourceTab="Hellfire", collectorEntryID=34110},
    {name="Chop Shop", id=704953, category="proc", order=280, buff="Chop Shop", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\inv_weapon_shortblade_40", sourceTab="War", collectorEntryID=11212},
    {name="Hellfire Striker", id=573036, category="proc", order=290, buff="Hellfire Striker", trackDuration=true, auraTracker=true, trackHUD=false, talent=true, fallbackIcon="Interface\\Icons\\Ability_Warrior_TitansGrip", sourceTab="War", collectorEntryID=30694},
    {name="Rain of Chaos", id=704452, category="debuff", order=500, targetDebuff=true, trackHUD=false, fallbackIcon="Interface\\Icons\\Spell_Shadow_RainOfFire", sourceTab="Hellfire", collectorEntryID=7361},
  },
})
