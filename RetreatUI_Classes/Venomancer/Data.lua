local RUI = RetreatUI

-- Fortitude tank data. Spell IDs are intentionally discovered from the live
-- Ascension spellbook so the first development branch cannot bind to stale or
-- guessed IDs. Verified IDs can be pinned after the first in-game test pass.
RUI:RegisterClassSpellDatabase("Venomancer", {
  version = 2,
  source = "Ascension Sidekick Fortitude talent audit + Ascension DB + live spellbook discovery",
  loadout = "Fortitude",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="exposedFlesh", name="Exposed Flesh", type="stacks", position="resource"},
    {key="carapaceRegeneration", name="Carapace Regeneration", type="stacks", max=5, position="resource"},
  },
  spells = {
    -- Same primary HUD row and ordering model as Knight of Xoroth.
    {name="Chitin Rush", category="rotation", hudRow="core", order=10, trackCooldown=true},
    {name="Venomtip Poison", category="rotation", hudRow="core", order=20, trackCooldown=true, targetDebuff=true},
    {name="Hivebreak", category="rotation", hudRow="core", order=30, trackCooldown=true},
    {name="Carapace Crash", category="rotation", hudRow="core", order=40, trackCooldown=true},
    {name="Claw Strike", category="rotation", hudRow="core", order=50, trackCooldown=true},
    {name="Expulsion", category="rotation", hudRow="core", order=60, trackCooldown=true, shed=true},
    {name="Barbed Stinger", category="rotation", hudRow="core", order=70, trackCooldown=true, shed=true, targetDebuff=true},
    {name="Regrow Exoskeleton", category="defensive", hudRow="core", order=80, trackCooldown=true, shed=true, partyCooldown=true, cooldownCategory="defensive"},

    -- Same secondary row position, icon size and dynamic centering as Xoroth.
    {name="Harden", category="defensive", hudRow="utility", order=10, trackCooldown=true, buff="Harden", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", requiresForm="Beetle Form"},
    {name="Lifeblood", category="defensive", hudRow="utility", order=20, trackCooldown=true, buff="Lifeblood", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Catalyst", category="offensive", hudRow="utility", order=30, trackCooldown=true, buff="Catalyst", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Molt", category="utility", hudRow="utility", order=40, trackCooldown=true},
    {name="Carapace Regeneration", category="defensive", hudRow="utility", order=50, trackCooldown=true, trackCharges=true, buff="Carapace Regeneration", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", baseMaxStacks=3, maxStacksTalent="Fortify Carapace", talentMaxStacks=5},
    {name="Vile Sting", category="taunt", hudRow="utility", order=60, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Nullifying Toxin", category="interrupt", hudRow="utility", order=70, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Locust Swarm", category="offensive", hudRow="utility", order=80, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Toxic Sludge", category="control", hudRow="utility", order=90, trackCooldown=true, targetDebuff=true},

    -- Active form/mechanic trackers.
    {name="Beetle Form", category="form", order=5, stanceTracker=true, trackDuration=false, transformedBy="Spider Lord", aliases={"Spider Lord"}},
    {name="Spider Lord", category="form", order=10, stanceTracker=true, trackDuration=false, talent=true, transformationOf="Beetle Form"},
    {name="Exposed Flesh", category="resource", order=15, counterTracker=true, trackDuration=false, trackStacks=true},

    -- Player-applied target effects.
    {name="Venomtip Poison", category="debuff", order=10, targetDebuff=true, auraBar=true},
    {name="Barbed Stinger", category="debuff", order=20, targetDebuff=true, auraBar=true},
    {name="Wicked Poison", category="debuff", order=30, targetDebuff=true, auraBar=true, talent=true},
    {name="Corrosion", category="debuff", order=40, targetDebuff=true, auraBar=true},

    -- Talents that materially change HUD behavior. Passive-only talents remain
    -- catalogued here so later logic is based on the selected build, not merely
    -- on the base spell list.
    {name="Alacrity", category="talent", trackHUD=false, auditType="adds proc/buff", modifies={"Chitin Rush"}, effect="Chitin Rush damage grants stacking dodge"},
    {name="Chitinous Surge", category="talent", trackHUD=false, auditType="cooldown modifier", modifies={"Chitin Rush"}, effect="reduces cooldown and increases damage"},
    {name="Slimy Stingers", category="talent", trackHUD=false, auditType="adds triggered effect", modifies={"Carapace Crash"}, effect="creates Beetle Slime under enemies hit"},
    {name="Toxic Expulsion", category="talent", trackHUD=false, auditType="ability mechanic replacement", modifies={"Hivebreak","Venomtip Poison"}, effect="Hivebreak consumes Venomtip duration for AoE"},
    {name="Wicked Poison", category="talent", trackHUD=false, auditType="adds proc/debuff", modifies={"Chitin Rush","Carapace Crash","Hivebreak"}},
    {name="Rapid Injection", category="talent", trackHUD=false, auditType="periodic rate modifier", modifies={"Wicked Poison"}},
    {name="Reformed", category="talent", trackHUD=false, auditType="adds conditional heal", modifies={"Regrow Exoskeleton","Barbed Stinger","Expulsion"}, effect="shedding in Beetle Form heals based on stacks cleared"},
    {name="Shedder", category="talent", trackHUD=false, auditType="cooldown modifier", modifies={"Regrow Exoskeleton","Barbed Stinger","Expulsion"}},
    {name="Unbreakable", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Exposed Flesh"}, effect="raises maximum stacks and reduces physical-damage penalty"},
    {name="Fortify Carapace", category="talent", trackHUD=false, auditType="stack cap modifier", modifies={"Carapace Regeneration"}, effect="raises maximum stacks from 3 to 5"},
    {name="Reconstructive Carapace", category="talent", trackHUD=false, auditType="resource-cost modifier", modifies={"Carapace Regeneration"}},
    {name="Improved Harden", category="talent", trackHUD=false, auditType="cooldown modifier", modifies={"Harden"}},
    {name="Vile Fury", category="talent", trackHUD=false, auditType="resource/cost modifier", modifies={"Vile Sting","Hivebreak"}},
    {name="Spider Lord", category="talent", trackHUD=false, auditType="form transformation", transformationOf="Beetle Form", modifies={"Beetle Form","Locust Swarm","Hivebreak"}},
  },
})
