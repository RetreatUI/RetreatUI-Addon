local RUI = RetreatUI

-- Cultist / Dreadnought preview data. Knight of Xoroth is the reference:
-- active decision abilities share one main row; only resources, forms, procs
-- and active durations are represented by separate trackers.
RUI:RegisterClassSpellDatabase("Cultist", {
  version = 3,
  source = "User supplied Cultist/Dreadnought talents and verified spell tooltips",
  loadout = "Dreadnought Preview",
  resources = {
    {key="mana", name="Mana", type="primary", position="power"},
    {key="insanity", name="Insanity", type="stacks", max=100, position="resource"},
    {key="totalMadness", name="Total Madness", type="state", position="resource"},
  },
  spells = {
    -- One Knight-style main decision row. Basic fillers remain on action bars.
    {name="Twilight Shieldtoss", id=804208, category="rotation", hudRow="core", order=10, trackCooldown=true, aliases={"Twilight Shield Toss"}},
    {name="Entropic Slam", id=804152, category="rotation", hudRow="core", order=20, trackCooldown=true, resourceThreshold=60},
    {name="Dreadfall", category="movement", hudRow="core", order=30, trackCooldown=true, aliases={"Dread Fall"}},
    {name="Dreadnought", id=567548, category="defensive", hudRow="core", order=40, trackCooldown=true, buff="Dreadnought", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", resourceThreshold=80, aliases={"Void Monstrosity","Strength of the Black Empire"}},
    {name="Void-Enhanced Shield", category="defensive", hudRow="core", order=50, trackCooldown=true, buff="Void-Enhanced Shield", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", aliases={"Void Enhanced Shield","Void Shield"}},
    {name="Abyssal Ward", category="defensive", hudRow="core", order=60, trackCooldown=true, buff="Abyssal Ward", auraTracker=true, trackDuration=true, trackStacks=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Embrace the Void", category="defensive", hudRow="core", order=70, trackCooldown=true, buff="Embrace the Void", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Test of Pride", id=804412, category="taunt", hudRow="core", order=80, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Horrifying Presence", id=500723, category="taunt", hudRow="core", order=90, trackCooldown=true, buff="Horrifying Presence", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Crushing Dissonance", category="interrupt", hudRow="core", order=100, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Mass Nightmare", category="control", hudRow="core", order=110, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt", conditionalHighlight="insanity80"},
    {name="Entropic Singularity", category="control", hudRow="core", order=120, trackCooldown=true},
    {name="Devour Magic", category="dispel", hudRow="core", order=130, trackCooldown=true, aliases={"Devourer"}},
    {name="Sermon of Dread", id=620610, category="control", hudRow="core", order=140, trackCooldown=true, targetDebuff=true},
    {name="Presence of Y'Shaarj", id=803035, category="presence", hudRow="core", order=150, trackCooldown=true, buff="Presence of Y'Shaarj", aliases={"Presence of Y'shaarj","Presence of Y’Shaarj"}},
    {name="Tentacle of Yogg-Saron", id=802042, category="summon", hudRow="core", order=160, trackCooldown=true, buff="Tentacle of Yogg-Saron", auraTracker=true, trackDuration=true, summonDuration=30, aliases={"Tentacle of Y'Shaarj","Tentacle of Y'shaarj","Tentacle of Y’Shaarj"}},
    {name="Satiate", id=804275, category="resource", hudRow="core", order=170, trackCooldown=true, buff="Satiate", auraTracker=true, trackDuration=true, warningWhileActive=true},
    {name="Twisted Seal", category="defensive", hudRow="core", order=180, trackCooldown=true, buff="Twisted Seal", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},

    -- Resource and state trackers.
    {name="Insanity", category="resource", trackHUD=false, counterTracker=true, trackStacks=true},
    {name="Total Madness", category="resource", trackHUD=false, counterTracker=true, trackStacks=true},

    -- Player-applied effects shown on the target only while active.
    {name="Sermon of Dread", id=620610, category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},
    {name="Vision of Doom", category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},
    {name="Grasp of Zek'voz", category="debuff", trackHUD=false, targetDebuff=true, auraBar=true, aliases={"Grasp of Zek’voz"}},

    -- Talents/passives that materially change decision logic.
    {name="Shroud of Pride", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Abyssal Ward"}, effect="adds three Abyssal Ward stacks"},
    {name="Overwhelming Void", category="talent", trackHUD=false, auditType="conditional cooldown modifier", modifies={"Mass Nightmare"}, effect="improves Mass Nightmare at 80+ Insanity"},
    {name="General of Y'Shaarj", category="talent", trackHUD=false, auditType="self-heal modifier", modifies={"Twilight Shieldtoss"}},
    {name="Void-Enhanced Shield", category="talent", trackHUD=false, auditType="ability replacement", transformationOf="Void Shield", modifies={"Void Shield","Insanity"}},
    {name="Lost in the Void", category="talent", trackHUD=false, auditType="duration/heal/cooldown modifier", modifies={"Embrace the Void"}},
    {name="Mind Leak", category="talent", trackHUD=false, auditType="threshold passive", modifies={"Insanity"}, effect="damage reduction above 60 Insanity"},
    {name="Rapid Incantations", category="talent", trackHUD=false, auditType="threshold passive", modifies={"Insanity"}, effect="haste above 60 Insanity"},
    {name="Dreadnought", category="talent", trackHUD=false, auditType="specialization mechanic", modifies={"Total Madness","Insanity"}},
  },
})