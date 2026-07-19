local RUI = RetreatUI

-- Dreadnought tank data. Runtime spellbook discovery is used deliberately:
-- Ascension advancement records, transformed spells and aura IDs do not
-- always share the same ID. Only live castable entries are shown on the HUD.
RUI:RegisterClassSpellDatabase("Cultist", {
  version = 1,
  source = "Ascension Sidekick Dreadnought guide + talent/passive audit + live spellbook discovery",
  loadout = "Dreadnought",
  resources = {
    {key="mana", name="Mana", type="primary", position="power"},
    {key="insanity", name="Insanity", type="stacks", max=100, position="resource"},
    {key="voidShield", name="Void-Enhanced Shield", type="absorb", position="resource"},
  },
  spells = {
    -- Primary row: identical layout/order system to Knight of Xoroth.
    {name="Dreadfall", category="rotation", hudRow="core", order=10, trackCooldown=true, aliases={"Dread Fall"}},
    {name="Void Strikes", category="rotation", hudRow="core", order=20, trackCooldown=true, aliases={"Void Strike"}},
    {name="Twilight Shieldtoss", category="rotation", hudRow="core", order=30, trackCooldown=true, aliases={"Twilight Shield Toss"}},
    {name="Entropic Slam", category="rotation", hudRow="core", order=40, trackCooldown=true},
    {name="Eldritch Force", category="rotation", hudRow="core", order=50, trackCooldown=true},
    {name="Void-Enhanced Shield", category="defensive", hudRow="core", order=60, trackCooldown=true, buff="Void-Enhanced Shield", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", aliases={"Void Enhanced Shield","Void Shield"}},
    {name="Armageddon", category="defensive", hudRow="core", order=70, trackCooldown=true, buff="Armageddon", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Doomcloak", category="defensive", hudRow="core", order=80, trackCooldown=true, buff="Doomcloak", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},

    -- Secondary / utility row.
    {name="Bulwark of Shadow", category="defensive", hudRow="utility", order=10, trackCooldown=true, buff="Bulwark of Shadow", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Eldritch Bastion", category="defensive", hudRow="utility", order=20, trackCooldown=true, buff="Eldritch Bastion", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Crushing Dissonance", category="interrupt", hudRow="utility", order=30, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Horrifying Presence", category="taunt", hudRow="utility", order=40, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Test of Pride", category="taunt", hudRow="utility", order=50, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Abyssal Ward", category="defensive", hudRow="utility", order=60, trackCooldown=true, buff="Abyssal Ward", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Embrace the Void", category="defensive", hudRow="utility", order=70, trackCooldown=true, buff="Embrace the Void", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Devour Magic", category="dispel", hudRow="utility", order=80, trackCooldown=true, aliases={"Devourer"}},
    {name="Twisted Seal", category="defensive", hudRow="utility", order=90, trackCooldown=true, buff="Twisted Seal", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},

    -- Form and resource trackers.
    {name="Dreadnought", category="form", order=5, stanceTracker=true, trackDuration=false, transformedBy="Strength of the Black Empire", aliases={"Void Monstrosity"}},
    {name="Strength of the Black Empire", category="talent", order=10, trackHUD=false, auditType="form transformation", transformationOf="Dreadnought", modifies={"Dreadnought"}},
    {name="Insanity", category="resource", order=15, counterTracker=true, trackStacks=true},

    -- Player-applied effects worth filtering on the target.
    {name="Sermon of Dread", category="debuff", order=10, targetDebuff=true, auraBar=true},
    {name="Presence of Y'Shaarj", category="debuff", order=20, targetDebuff=true, auraBar=true, aliases={"Presence of Y'shaarj"}},
    {name="Vision of Doom", category="debuff", order=30, targetDebuff=true, auraBar=true},
    {name="Grasp of Zek'voz", category="debuff", order=40, targetDebuff=true, auraBar=true},

    -- Dreadnought talents/passives with actual HUD or mechanical impact.
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
    {name="Shroud of Pride", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Abyssal Ward"}},
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
