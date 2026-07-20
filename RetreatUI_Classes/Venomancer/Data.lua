local RUI = RetreatUI

-- Venomancer / Fortitude preview data. Knight of Xoroth remains the reference
-- implementation: every active decision ability belongs to one dynamically
-- centred main row, while resources, procs, forms and active durations use
-- dedicated trackers.
RUI:RegisterClassSpellDatabase("Venomancer", {
  version = 3,
  source = "User supplied Venomancer talent and spell tooltips + live spellbook discovery",
  loadout = "Fortitude Preview",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="exposedFlesh", name="Exposed Flesh", type="stacks", max=10, position="resource"},
    {key="carapaceRegeneration", name="Carapace Regeneration", type="stacks", max=5, position="resource"},
  },
  spells = {
    -- One Knight-style main decision row.
    {name="Beetle Form", id=803183, category="form", hudRow="core", order=10, trackCooldown=true, buff="Beetle Form"},
    {name="Spider Form", id=800841, category="form", hudRow="core", order=20, trackCooldown=true, buff="Spider Form"},
    {name="Chitin Rush", id=803570, category="movement", hudRow="core", order=30, trackCooldown=true, requiresForm="Beetle Form"},
    {name="Claw Strike", id=803198, category="rotation", hudRow="core", order=40, trackCooldown=true, requiresForm="Beetle Form"},
    {name="Hivebreak", id=803193, category="rotation", hudRow="core", order=50, trackCooldown=true, requiresForm="Beetle Form", conditionalHighlight="deadlySting"},
    {name="Carapace Crash", id=803199, category="rotation", hudRow="core", order=60, trackCooldown=true, requiresForm="Beetle Form"},
    {name="Venomtip Poison", category="offensive", hudRow="core", order=70, trackCooldown=true, targetDebuff=true},
    {name="Expulsion", category="rotation", hudRow="core", order=80, trackCooldown=true, shed=true},
    {name="Barbed Stinger", category="control", hudRow="core", order=90, trackCooldown=true, shed=true, targetDebuff=true},
    {name="Regrow Exoskeleton", category="defensive", hudRow="core", order=100, trackCooldown=true, shed=true, buff="Regrow Exoskeleton", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Carapace Regeneration", category="defensive", hudRow="core", order=110, trackCooldown=true, trackCharges=true, buff="Carapace Regeneration", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", baseMaxStacks=3, maxStacksTalent="Fortify Carapace", talentMaxStacks=5},
    {name="Harden", id=800892, category="defensive", hudRow="core", order=120, trackCooldown=true, buff="Harden", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", requiresForm="Beetle Form"},
    {name="Lifeblood", category="defensive", hudRow="core", order=130, trackCooldown=true, buff="Lifeblood", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Burrow", category="defensive", hudRow="core", order=140, trackCooldown=true, buff="Burrow", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Vile Sting", id=805097, category="taunt", hudRow="core", order=150, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt", requiresForm="Beetle Form"},
    {name="Myotoxin", id=872304, category="dispel", hudRow="core", order=160, trackCooldown=true, targetDebuff=true},
    {name="Spindlebind", category="control", hudRow="core", order=170, trackCooldown=true},
    {name="Pinch", category="control", hudRow="core", order=180, trackCooldown=true, targetDebuff=true},
    {name="Impale", category="interrupt", hudRow="core", order=190, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Shadra's Lair", category="control", hudRow="core", order=200, trackCooldown=true, buff="Shadra's Lair", auraTracker=true, trackDuration=true, aliases={"Shadras Lair"}},
    {name="Hive Instinct", category="resource", hudRow="core", order=210, trackCooldown=true},
    {name="Toxic Stride", category="utility", hudRow="core", order=220, trackCooldown=true, buff="Toxic Stride", auraTracker=true, trackDuration=true},

    -- Long-duration venom choices are status trackers, not permanent main-row buttons.
    {name="Nullifying Venom", category="venom", trackHUD=false, venomTracker=true, aliases={"Nullifying Toxin"}},
    {name="Debilitating Venom", id=805731, category="venom", trackHUD=false, venomTracker=true},
    {name="Blight Venom", id=805776, category="venom", trackHUD=false, venomTracker=true},
    {name="Weakening Venom", category="venom", trackHUD=false, venomTracker=true},

    -- Form/resource/proc trackers.
    {name="Spider Lord", category="form", trackHUD=false, stanceTracker=true, transformationOf="Beetle Form"},
    {name="Exposed Flesh", category="resource", trackHUD=false, counterTracker=true, trackStacks=true},
    {name="Tome of Ahn'kahet", category="proc", trackHUD=false, buff="Tome of Ahn'kahet", auraTracker=true, trackDuration=true, aliases={"Tome of Ahn’kahet"}},
    {name="Deadly Sting", category="proc", trackHUD=false, buff="Deadly Sting", trackDuration=true, modifies={"Hivebreak"}},

    -- Player-applied target effects.
    {name="Venomtip Poison", category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},
    {name="Barbed Stinger", category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},
    {name="Myotoxin", id=872304, category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},
    {name="Weakening Venom", category="debuff", trackHUD=false, targetDebuff=true, auraBar=true},

    -- Passive/talent interactions used by the HUD.
    {name="Deadly Sting", category="talent", trackHUD=false, auditType="proc", modifies={"Hivebreak"}, effect="periodic damage can make Hivebreak free and deal 50% increased damage"},
    {name="Unbreakable", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Exposed Flesh"}, effect="adds five Exposed Flesh stacks"},
    {name="Fortify Carapace", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Carapace Regeneration"}, effect="raises maximum stacks from 3 to 5"},
    {name="Spider Lord", category="talent", trackHUD=false, auditType="form transformation", transformationOf="Beetle Form", modifies={"Beetle Form","Hivebreak"}},
    {name="Tome of Ahn'kahet", category="talent", trackHUD=false, auditType="free spell proc", effect="next spell costs 100% less"},
    {name="Reformed", category="talent", trackHUD=false, auditType="shed heal", modifies={"Regrow Exoskeleton","Barbed Stinger","Expulsion"}},
    {name="Shedder", category="talent", trackHUD=false, auditType="cooldown modifier", modifies={"Regrow Exoskeleton","Barbed Stinger","Expulsion"}},
  },
})