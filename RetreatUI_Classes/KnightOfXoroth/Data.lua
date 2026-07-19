local RUI = RetreatUI

RUI:RegisterClassSpellDatabase("Knight of Xoroth", {
  version = 3,
  source = "Ascension DB + RetreatUI runtime discovery",
  resources = {
    {key="rage", name="Rage", type="primary", position="power"},
    {key="demonfire", name="Demonfire", type="stacks", max=6, position="resource"},
    {key="hellfireImp", name="Hellfire Imp", type="summon", position="resource"},
    {key="demonBlood", name="Demon's Blood", type="stacks", position="resource"},
  },
  spells = {
    -- Main combat row. The order is stable; unlearned records are omitted.
    {name="Sever", category="rotation", hudRow="core", order=10, trackCooldown=true},
    {name="Unleash Pestilence", category="rotation", hudRow="core", order=20, trackCooldown=true},
    {name="Chainwhip", category="interrupt", hudRow="core", order=30, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Snarl", category="taunt", hudRow="core", order=40, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Implosion", id=34132, category="rotation", hudRow="core", order=50, talent=true, trackCooldown=true},
    {name="Xorothian Sigil", id=30696, category="offensive", hudRow="core", order=60, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Burning Rage", id=34112, category="offensive", hudRow="core", order=70, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Legion's Presence", id=30428, category="offensive", hudRow="core", order=80, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Juggernaut", id=520294, category="defensive", hudRow="core", order=85, talent=true, trackCooldown=true, buff="Juggernaut", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Call: Hellfire Imp", category="summon", hudRow="core", order=90, trackCooldown=true, becomesPassiveWhen={{name="Impcaller", id=706755}}, hideWhen={{name="Impcaller", id=706755}}},
    {name="Hellish Rebuke", id=503310, category="proc", hudRow="core", order=100, trackCooldown=true, buff="Hellish Rebuke"},
    {name="Impcaller", id=706755, category="talent", trackHUD=false, auditType="active-to-passive conversion", modifies={"Call: Hellfire Imp","Shieldgore"}, effect="Call: Hellfire Imp is transformed; Shieldgore summons the imp passively"},

    -- Utility/defensive row. Chains and displacement tools stay adjacent.
    {name="Demon Heart", id=31701, category="defensive", hudRow="utility", order=10, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Black Shield", id=30701, category="defensive", hudRow="utility", order=20, talent=true, trackCooldown=true, buff="Black Shield", auraTracker=true, trackAbsorb=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Infernal Shield", category="defensive", hudRow="utility", order=30, trackCooldown=true, buff="Infernal Shield", partyCooldown=true, cooldownCategory="defensive"},
    {name="Hellbound Charge", id=807247, category="mobility", hudRow="utility", order=40, talent=true, trackCooldown=true, trackCharges=true},
    {name="Flesh Hook", category="control", hudRow="utility", order=50, group="chains", trackCooldown=true},
    {name="Chains of Xoroth", id=30699, category="control", hudRow="utility", order=60, group="chains", talent=true, trackCooldown=true},
    {name="Chains of Malice", id=803185, category="control", hudRow="utility", order=70, group="chains", talent=true, trackCooldown=true},
    {name="Hellfire Bellows", category="utility", hudRow="utility", order=80, trackCooldown=true},
    {name="Sacrificial Circle", category="utility", hudRow="utility", order=90, trackCooldown=true},
    {name="Create: Hellgate", category="utility", hudRow="utility", order=100, trackCooldown=true},
    {name="Call: Hellfire Abyssal", id=30498, category="summon", hudRow="utility", order=110, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},

    -- Active aura trackers; not shown as duplicate rotational buttons.
    {name="Suffuse", category="buff", order=10, auraTracker=true, trackDuration=true},
    {name="Hellrider", category="buff", order=30, auraTracker=true, trackDuration=true},

    -- Target debuffs applied by the player.
    {name="Bulwark of Xoroth", id=300388, category="debuff", order=5, targetDebuff=true, auraBar=true, talent=true},
    {name="Curse of Xoroth", category="debuff", order=10, targetDebuff=true},
    {name="Torn Flesh", category="debuff", order=20, targetDebuff=true},
    {name="Ritual Fire", category="debuff", order=30, targetDebuff=true},
    {name="Pestilence of Famine", category="debuff", order=40, targetDebuff=true},
    {name="Pestilence of War", category="debuff", order=50, targetDebuff=true},
    {name="Pestilence of Conquest", id=801053, category="debuff", order=60, targetDebuff=true},

    -- Ascension DB candidates that are catalogued but not placed until reviewed ingame.
    {name="Melt", id=803334, category="debuff", review=true, trackHUD=false, source="AscensionDB"},
    {name="Infernal Strike", id=501515, category="mobility", review=true, trackHUD=false, source="AscensionDB"},
    {name="Demonfeast", id=501497, category="rotation", review=true, trackHUD=false, source="AscensionDB"},
  },
})
