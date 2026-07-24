local RUI = RetreatUI

RUI:RegisterClassSpellDatabase("Bloodmage", {
  version = 3,
  source = "User-verified Eternal talent/spell tooltips and Bloodmage group-buff tooltips; live spellbook discovery for unpinned IDs",
  loadout = "Eternal",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="bloodBond", name="Blood Bond", type="ally", position="resource"},
  },
  spells = {
    -- Main row: rotational decisions and major cooldowns only.
    {name="Bloodfang Bite", id=501696, category="rotation", tankSlot="rotational", trackHUD=false, trackCooldown=true, requiresForm="Cursed Form"},
    {name="Rotclaw", category="rotation", tankSlot="builder", hudRow="core", order=20, trackCooldown=true, trackCharges=true},
    {name="Animated Blood", id=573299, category="rotation", tankSlot="rotational", hudRow="core", order=25, trackCooldown=true},
    {name="Night Hunter's Howl", id=500124, category="rotation", tankSlot="rotational", hudRow="core", order=50, trackCooldown=true},
    {name="Monstrous Hunger", id=804811, category="offensive", tankSlot="rotational", hudRow="core", order=60, trackCooldown=true, buff="Monstrous Hunger", auraTracker=true, trackDuration=true},
    {name="Eternal Resolve", id=801962, category="defensive", tankSlot="defensive", hudRow="core", order=80, trackCooldown=true, buff="Eternal Resolve", trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Blood Pact", id=801955, category="defensive", tankSlot="defensive", hudRow="core", order=90, trackCooldown=true, buff="Blood Pact", trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Liquify", category="defensive", tankSlot="defensive", hudRow="core", order=95, trackCooldown=true, buff="Liquify", trackDuration=true, requiresForm="Mortal Form", talent=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Apotheosis", id=804203, category="defensive", tankSlot="defensive", hudRow="core", order=100, trackCooldown=true, buff="Apotheosis", trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Blood Tap", id=707900, category="resource", tankSlot="rotational", hudRow="core", order=110, trackCooldown=true},

    -- Small row: mobility, taunts, stance controls, ally tools and niche utility.
    {name="Lunge", id=500126, category="mobility", tankSlot="mobility", hudRow="utility", order=10, trackCooldown=true, requiresForm="Cursed Form"},
    {name="Bare Fangs", id=801957, category="taunt", tankSlot="taunt", hudRow="utility", order=20, trackCooldown=true, requiresForm="Cursed Form", partyCooldown=true, cooldownCategory="taunt"},
    {name="Blood Howl", id=800782, category="taunt", tankSlot="taunt", hudRow="utility", order=30, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Blood Curse", id=562720, category="stance", hudRow="utility", order=40, trackCooldown=true, buff="Cursed Form", trackDuration=true, requiresForm="Mortal Form"},
    {name="Moon Gaze", id=562723, category="stance", trackHUD=false, trackCooldown=true, hideInCombat=true, requiresForm="Cursed Form"},
    {name="Hemostasis", category="control", hudRow="utility", order=50, trackCooldown=true},
    {name="Blood Veil", category="utility", hudRow="utility", order=60, trackCooldown=true},
    {name="Transfusion", id=705734, category="utility", hudRow="utility", order=70, trackCooldown=true},
    {name="Blood Bond", category="ally", trackHUD=false, allyTracker=true, trackCooldown=true, buff="Blood Bond"},
    {name="Shadow Howl", id=806177, category="utility", hudRow="utility", order=80, trackCooldown=true},
    {name="Fleshcraft", id=801952, category="utility", hudRow="utility", order=90, trackCooldown=true},
    {name="Scarlet Delirium", id=801074, category="control", hudRow="utility", order=100, trackCooldown=true, requiresForm="Mortal Form"},
    {name="Blood Feast", id=706605, category="utility", hudRow="utility", order=110, trackCooldown=true, requiresForm="Mortal Form", hideInCombat=true},

    -- Castable 30-minute party/raid buffs for RetreatUI's buff manager.
    {name="Greater Sanguinary Offering", id=680299, category="groupBuff", groupBuff=true, trackHUD=false, order=10, spec="Sanguine", buff="Greater Sanguinary Offering", duration=1800, targetMode="PARTY_RAID", buffCategory="stamina", effect="Stamina", verified="user-tooltip"},
    {name="Greater Bloodsoaked Offering", id=572406, category="groupBuff", groupBuff=true, trackHUD=false, order=20, spec="Sanguine", buff="Greater Bloodsoaked Offering", duration=1800, targetMode="PARTY_RAID", buffCategory="spirit", effect="Spirit", verified="user-tooltip"},
    {name="Greater Bloodthorns", id=572116, category="groupBuff", groupBuff=true, trackHUD=false, order=30, spec="Fleshweaver", buff="Greater Bloodthorns", duration=1800, targetMode="PARTY_RAID", buffCategory="thorns", effect="Retaliatory Shadow damage", verified="user-tooltip"},

    -- Buff/proc row. Passive talents never become action buttons.
    {name="Saturating Sutures", category="proc", trackHUD=false, auraTracker=true, buff="Saturating Sutures", trackDuration=true, talent=true},
    {name="Blood Rush", id=863848, category="proc", trackHUD=false, auraTracker=true, buff="Blood Rush", trackDuration=true, talent=true},
    {name="Enraging Howls", id=504551, category="buff", trackHUD=false, auraTracker=true, buff="Enraging Howls", trackDuration=true, talent=true},
    {name="Call of the Darkwing", category="proc", trackHUD=false, auraTracker=true, buff="Call of the Darkwing", trackDuration=true, talent=true},

    -- Target debuff used by Eternal's auto-attack healing and TurboPlates.
    {name="Bite Wound", category="debuff", order=10, targetDebuff=true, auraBar=true, appliedBy="Bloodfang Bite"},

    -- Talent audit metadata.
    {name="Eternal Curse", id=800157, category="talent", trackHUD=false, talent=true, modifies={"Cursed Form","Lunge","Bloodfang Bite","Bare Fangs"}},
    {name="Petrified Legions", category="talent", trackHUD=false, talent=true, modifies={"Call of the Darkwing"}},
    {name="Blood Clot", category="talent", trackHUD=false, talent=true, modifies={"Scarlet Delirium"}},
    {name="Mucking Around", category="talent", trackHUD=false, talent=true, modifies={"Scarlet Delirium"}},
  },
})
