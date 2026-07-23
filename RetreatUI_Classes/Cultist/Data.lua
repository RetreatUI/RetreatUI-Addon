local RUI = RetreatUI

-- Cultist / Dreadnought data. Runtime spellbook discovery is used deliberately:
-- Ascension advancement records, transformed spells and aura IDs do not always
-- share the same ID. The HUD therefore follows learned castable entries and
-- keeps passive talent effects attached to the ability they modify.
RUI:RegisterClassSpellDatabase("Cultist", {
  version = 3,
  source = "Cultist class tree + Dreadnought tree audit + live spellbook discovery",
  loadout = "Dreadnought",
  resources = {
    {key="mana", name="Mana", type="primary", position="power"},
    {key="insanity", name="Insanity", type="stacks", max=100, position="resource"},
  },
  spells = {
    -- Main decision row. Basic fillers remain on the action bars.
    {name="Twilight Shieldtoss", id=804208, category="rotation", tankSlot="builder", hudRow="core", order=10, trackCooldown=true, insanityScaling=true, aliases={"Twilight Shield Toss"}},
    {name="Entropic Slam", id=804152, category="rotation", hudRow="core", order=20, trackCooldown=true, requiresInsanity=60, spendsInsanity=40},
    {name="Gaze of C'Thun", id=500110, category="rotation", hudRow="core", order=30, trackCooldown=true, tentacleSynergy=true, aliases={"Gaze of C’Thun"}},
    {name="Sermon of Dread", id=620610, category="maintenance", hudRow="utility", order=10, targetDebuff=true, maintenanceDebuff=true, debuffDuration=30},
    {name="Test of Pride", id=804412, category="taunt", tankSlot="taunt", hudRow="core", order=40, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Horrifying Presence", id=500723, category="taunt", tankSlot="aoeTaunt", hudRow="core", order=50, trackCooldown=true, buff="Horrifying Presence", trackDuration=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Crushing Dissonance", category="interrupt", tankSlot="interrupt", hudRow="core", order=60, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},

    -- Secondary decision row: selected defensives, stops, movement and summons.
    {name="Dreadfall", category="movement", hudRow="core", order=70, trackCooldown=true, aliases={"Dread Fall"}},
    {name="Void-Enhanced Shield", category="defensive", hudRow="core", order=80, trackCooldown=true, buff="Void-Enhanced Shield", auraNames={"Void-Enhanced Shield","Void Enhanced Shield","Void Shield"}, auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", aliases={"Void Enhanced Shield","Void Shield"}, blockedByDebuff="Wracked Mind"},
    {name="Abyssal Ward", category="defensive", hudRow="core", order=90, trackCooldown=true, buff="Abyssal Ward", auraTracker=true, trackDuration=true, trackStacks=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Embrace the Void", category="defensive", hudRow="core", order=100, trackCooldown=true, buff="Embrace the Void", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Mass Nightmare", category="control", hudRow="utility", order=40, trackCooldown=true, conditionalHighlight="insanity80", partyCooldown=true, cooldownCategory="interrupt"},
    {name="Entropic Singularity", category="control", hudRow="utility", order=50, trackCooldown=true},
    {name="Tentacle of Yogg-Saron", id=802042, category="summon", hudRow="utility", order=60, trackCooldown=true, auraTracker=true, trackDuration=true, summonDuration=30, talentName="Tentacle of Y'Shaarj", aliases={"Tentacle of Yogg-Saron","Tentacle of Yogg Saron","Tentacle of Y'Shaarj","Tentacle of Y'shaarj","Tentacle of Y’Shaarj"}},
    {name="Satiate", id=804275, category="resource", hudRow="utility", order=70, trackCooldown=true, channelDuration=6, generatesInsanity=60, damageTakenPenalty=20},
    {name="Presence of Y'Shaarj", id=803035, category="stance", hudRow="utility", order=20, buff="Presence of Y'Shaarj", missingBuffWarning=true, aliases={"Presence of Y'shaarj","Presence of Y’Shaarj"}},

    -- Other relevant Cultist/Dreadnought abilities. They appear automatically
    -- when actually learned, but are not forced into the selected build.
    {name="Armageddon", category="defensive", hudRow="core", order=150, trackCooldown=true, buff="Armageddon", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Doomcloak", category="defensive", hudRow="core", order=160, trackCooldown=true, buff="Doomcloak", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Bulwark of Shadow", category="defensive", hudRow="core", order=170, trackCooldown=true, buff="Bulwark of Shadow", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Eldritch Bastion", category="defensive", hudRow="core", order=180, trackCooldown=true, buff="Eldritch Bastion", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Voidwarding", category="defensive", hudRow="core", order=190, trackCooldown=true, buff="Voidwarding", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Devour Magic", category="dispel", tankSlot="dispel", hudRow="utility", order=30, trackCooldown=true, aliases={"Devourer"}},
    {name="Twisted Seal", category="defensive", hudRow="core", order=200, trackCooldown=true, buff="Twisted Seal", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Grasp of Zek'voz", category="control", hudRow="utility", order=80, trackCooldown=true, aliases={"Grasp of Zek’voz"}},

    -- Known basic builders/fillers kept for spellbook auditing, not HUD space.
    {name="Void Strikes", category="rotation", trackHUD=false, aliases={"Void Strike"}},
    {name="Twilight Domain", id=807725, category="passive", trackHUD=false, auditType="threat and shadow damage passive", modifies={"Threat","Shadow Damage"}},

    -- Form and resource trackers.
    {name="Dreadnought", id=567548, category="form", order=5, counterTracker=true, trackCooldown=true, trackDuration=true, requiresInsanity=80, consumesAllInsanityOnExpire=true, transformedBy="Strength of the Black Empire", aliases={"Void Monstrosity"}},
    {name="Strength of the Black Empire", category="talent", order=10, trackHUD=false, auditType="form transformation", transformationOf="Dreadnought", modifies={"Dreadnought"}},
    {name="Insanity", category="resource", order=15, counterTracker=true, trackStacks=true},
    {name="Total Madness", category="resource", order=20, counterTracker=true, trackStacks=true},

    -- Player-applied effects worth filtering on the target when selected.
    {name="Sermon of Dread", category="debuff", order=10, targetDebuff=true, auraBar=true},
    {name="Vision of Doom", category="debuff", order=30, targetDebuff=true, auraBar=true},
    {name="Grasp of Zek'voz", category="debuff", order=40, targetDebuff=true, auraBar=true, aliases={"Grasp of Zek’voz"}},

    -- Dreadnought talents/passives with mechanical impact. They do not receive
    -- their own icons; the affected active ability or mechanic reflects them.
    {name="Dreadnought", category="talent", trackHUD=false, auditType="removes resource penalty / grants specialization", modifies={"Total Madness","Insanity"}, effect="100 Insanity no longer triggers Total Madness"},
    {name="Inner Darkness", category="talent", trackHUD=false, auditType="resource generator", modifies={"Insanity"}, effect="blocking generates Insanity"},
    {name="Deep Secrets", category="talent", trackHUD=false, auditType="resource-cost modifier", modifies={"Mana","Insanity"}, effect="each Insanity point reduces instant ability mana costs"},
    {name="General of Y'Shaarj", category="talent", trackHUD=false, auditType="adds self-heal", modifies={"Twilight Shieldtoss"}, effect="Shieldtoss heals from damage dealt"},
    {name="Eldritch Strength", category="talent", trackHUD=false, auditType="threat modifier", modifies={"Void Strikes","Twilight Shieldtoss"}},
    {name="Void-Enhanced Shield", category="talent", trackHUD=false, auditType="ability replacement / scaling absorb", transformationOf="Void Shield", modifies={"Void Shield","Insanity"}, effect="absorb and block value scale at high Insanity"},
    {name="Embodiment of Y'shaarj", category="talent", trackHUD=false, auditType="absorb modifier / proc", modifies={"Void-Enhanced Shield"}},
    {name="Shadowy Symbiosis", category="talent", trackHUD=false, auditType="critical block proc", modifies={"Block","Insanity"}},
    {name="Entropic Retaliation", category="talent", trackHUD=false, auditType="critical block proc", modifies={"Block"}},
    {name="Blessing of Y'Shaarj", category="talent", trackHUD=false, auditType="form damage modifier", modifies={"Dreadnought","Strength of the Black Empire"}},
    {name="Strength of the Sha", category="talent", trackHUD=false, auditType="stat conversion", modifies={"Strength","Spell Damage","Spell Hit"}},
    {name="Void Reaver", category="talent", trackHUD=false, auditType="proc modifies active ability", modifies={"Blade of the Empire"}},

    -- Class-tree talents/passives that change active abilities or tracking.
    {name="Darkward", category="talent", trackHUD=false, auditType="absorb modifier", modifies={"Void-Enhanced Shield","Doomcloak","Abyssal Ward"}},
    {name="Lost in the Void", category="talent", trackHUD=false, auditType="duration/heal/cooldown modifier", modifies={"Embrace the Void"}},
    {name="Mind Leak", category="talent", trackHUD=false, auditType="threshold passive", modifies={"Insanity"}, effect="reduced damage taken above 60 Insanity"},
    {name="Rapid Incantations", category="talent", trackHUD=false, auditType="threshold passive", modifies={"Insanity"}, effect="haste above 60 Insanity"},
    {name="Shroud of Pride", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Abyssal Ward"}, effect="Abyssal Ward gains three additional stacks"},
    {name="Crystalline Reflection", category="talent", trackHUD=false, auditType="ability mechanic modifier", modifies={"Void Shield"}, effect="adds damage reflection"},
    {name="Split Mind", category="talent", trackHUD=false, auditType="multi-target transformation", modifies={"Void Shield"}},
    {name="Disdain", category="talent", trackHUD=false, auditType="removes cooldown / raises cost", modifies={"Grasp of Zek'voz"}},
    {name="Overwhelming Void", category="talent", trackHUD=false, auditType="conditional cooldown modifier", modifies={"Mass Nightmare"}, effect="reduced cooldown when cast at 80+ Insanity"},
    {name="Stare Into The Abyss", category="talent", trackHUD=false, auditType="cast-time removal", modifies={"Corrupt Mind"}},
    {name="Eldritch Screams", category="talent", trackHUD=false, auditType="adds debuff", modifies={"Corrupt Mind","Mind Rot"}},
    {name="Devourer", category="talent", trackHUD=false, auditType="dispel modifier", modifies={"Devour Magic"}},
    {name="Mind Games", category="talent", trackHUD=false, auditType="cooldown/cost modifier", modifies={"Hallucination"}},
    {name="Dark Calling", category="talent", trackHUD=false, auditType="automatic low-health proc", modifies={"Health"}, effect="summons manifestations below 35% health; internal cooldown"},
    {name="Doomsayer", category="talent", trackHUD=false, auditType="resource-cost modifier", modifies={"Presence of Y'Shaarj"}},
    {name="Embodied Presences", category="talent", trackHUD=false, auditType="proc chance modifier", modifies={"Presence of Y'Shaarj"}},
    {name="Improved Sermon of Dread", category="talent", trackHUD=false, auditType="effectiveness modifier", modifies={"Sermon of Dread"}},
  },
})
