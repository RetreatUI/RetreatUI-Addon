local RUI = RetreatUI

-- Fortitude tank data. Spell IDs are intentionally discovered from the live
-- Ascension spellbook so the addon cannot bind to stale or guessed IDs. Verified IDs can be pinned after the first in-game test pass.
RUI:RegisterClassSpellDatabase("Venomancer", {
  version = 3,
  source = "Ascension Sidekick Fortitude talent audit + Ascension DB + live spellbook discovery",
  loadout = "Fortitude",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="exposedFlesh", name="Exposed Flesh", type="stacks", position="resource"},
    {key="carapaceRegeneration", name="Carapace Regeneration", type="stacks", max=5, position="resource"},
  },
  spells = {
    -- Same primary HUD row and ordering model as Knight of Xoroth.
    {name="Chitin Rush", category="rotation", tankSlot="builder", hudRow="core", order=10, trackCooldown=true},
    {name="Venomtip Poison", category="rotation", hudRow="utility", order=10, trackCooldown=true, targetDebuff=true},
    {name="Hivebreak", category="rotation", hudRow="core", order=20, trackCooldown=true},
    {name="Carapace Crash", category="rotation", hudRow="core", order=30, trackCooldown=true},
    {name="Claw Strike", category="rotation", trackHUD=false},
    {name="Expulsion", category="rotation", tankSlot="spender", hudRow="core", order=40, trackCooldown=true, shed=true},
    {name="Barbed Stinger", category="rotation", tankSlot="spender", hudRow="core", order=50, trackCooldown=true, shed=true, targetDebuff=true},
    {name="Regrow Exoskeleton", category="defensive", tankSlot="defensive", hudRow="core", order=60, trackCooldown=true, shed=true, buff="Regrow Exoskeleton", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},

    -- Same secondary row position, icon size and dynamic centering as Xoroth.
    {name="Harden", category="defensive", hudRow="core", order=70, trackCooldown=true, buff="Harden", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive", requiresForm="Beetle Form"},
    {name="Lifeblood", category="defensive", hudRow="core", order=80, trackCooldown=true, buff="Lifeblood", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Vile Sting", category="taunt", tankSlot="taunt", hudRow="utility", order=20, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Nullifying Toxin", category="interrupt", tankSlot="interrupt", hudRow="utility", order=30, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Catalyst", category="offensive", hudRow="utility", order=40, trackCooldown=true, buff="Catalyst", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Locust Swarm", category="offensive", hudRow="utility", order=50, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Molt", category="utility", hudRow="utility", order=60, trackCooldown=true},
    {name="Toxic Sludge", category="control", hudRow="utility", order=70, trackCooldown=true, targetDebuff=true},
    {name="Carapace Regeneration", category="resource", trackHUD=false, counterTracker=true, trackCooldown=true, trackCharges=true, buff="Carapace Regeneration", auraTracker=true, trackDuration=true, baseMaxStacks=3, maxStacksTalent="Fortify Carapace", talentMaxStacks=5},

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