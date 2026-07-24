local RUI = RetreatUI

RUI:RegisterClassSpellDatabase("Knight of Xoroth", {
  version = 5,
  source = "Ascension DB + RetreatUI runtime discovery + Knight of Xoroth group-buff audit",
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
    {name="Implosion", id=34132, category="rotation", hudRow="core", order=50, talent=true, trackCooldown=true},
    {name="Xorothian Sigil", id=30696, category="offensive", hudRow="core", order=60, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Burning Rage", id=34112, category="offensive", hudRow="core", order=70, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Legion's Presence", id=30428, category="offensive", hudRow="core", order=80, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},
    {name="Juggernaut", id=520294, category="defensive", hudRow="core", order=85, talent=true, trackCooldown=true, buff="Juggernaut", auraTracker=true, trackDuration=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Call: Hellfire Imp", category="summon", hudRow="core", order=90, trackCooldown=true, becomesPassiveWhen={{name="Impcaller", id=706755}}, hideWhen={{name="Impcaller", id=706755}}},
    {name="Hellish Rebuke", id=503310, category="proc", hudRow="core", order=100, trackCooldown=true, buff="Hellish Rebuke"},
    {name="Impcaller", id=706755, category="talent", trackHUD=false, auditType="active-to-passive conversion", modifies={"Call: Hellfire Imp","Shieldgore"}, effect="Call: Hellfire Imp is transformed; Shieldgore summons the imp passively"},

    -- Utility/defensive row. Interrupt, taunt, chains and displacement tools stay here.
    {name="Demon Heart", id=31701, category="defensive", hudRow="core", order=110, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Black Shield", id=30701, category="defensive", hudRow="core", order=120, talent=true, trackCooldown=true, buff="Black Shield", auraTracker=true, trackAbsorb=true, partyCooldown=true, cooldownCategory="defensive"},
    {name="Infernal Shield", category="defensive", hudRow="core", order=130, trackCooldown=true, buff="Infernal Shield", partyCooldown=true, cooldownCategory="defensive"},
    {name="Hellbound Charge", id=807247, category="mobility", hudRow="core", order=140, talent=true, trackCooldown=true, trackCharges=true},
    {name="Chainwhip", category="interrupt", hudRow="utility", order=10, trackCooldown=true, partyCooldown=true, cooldownCategory="interrupt"},
    {name="Snarl", category="taunt", hudRow="utility", order=20, trackCooldown=true, partyCooldown=true, cooldownCategory="taunt"},
    {name="Flesh Hook", category="control", hudRow="utility", order=30, group="chains", trackCooldown=true},
    {name="Chains of Xoroth", id=30699, category="control", hudRow="utility", order=40, group="chains", talent=true, trackCooldown=true},
    {name="Chains of Malice", id=803185, category="control", hudRow="utility", order=50, group="chains", talent=true, trackCooldown=true},
    {name="Hellfire Bellows", category="utility", hudRow="utility", order=60, trackCooldown=true},
    {name="Sacrificial Circle", category="utility", hudRow="utility", order=70, trackCooldown=true},
    {name="Create: Hellgate", category="utility", hudRow="utility", order=80, trackCooldown=true},
    {name="Call: Hellfire Abyssal", id=30498, category="summon", hudRow="utility", order=90, talent=true, trackCooldown=true, partyCooldown=true, cooldownCategory="offensive"},

    -- Castable 30-minute party/raid marks for RetreatUI's buff manager.
    {name="Greater Mark of Korth'azz", aliases={"Greater Mark of Korth’azz"}, id=680300, category="groupBuff", groupBuff=true, trackHUD=false, order=10, spec="War", buff="Greater Mark of Korth'azz", duration=1800, targetMode="PARTY_RAID", buffCategory="strength_fire_resistance", effect="Strength and Fire Resistance", verified="ascension-db"},
    {name="Greater Mark of Blaumeux", id=712460, category="groupBuff", groupBuff=true, trackHUD=false, order=20, spec="Hellfire", buff="Greater Mark of Blaumeux", duration=1800, targetMode="PARTY_RAID", buffCategory="spell_power_shadow_resistance", effect="Spell Power and Shadow Resistance", verified="ascension-db"},

    -- Defiance marks are catalogued by name but excluded from normal results until their live IDs are verified.
    {name="Greater Mark of Rivendare", category="groupBuff", groupBuff=true, trackHUD=false, order=30, spec="Defiance", buff="Greater Mark of Rivendare", duration=1800, targetMode="PARTY_RAID", buffCategory="stamina_frost_resistance", effect="Stamina and Frost Resistance", review=true},
    {name="Greater Mark of Zeliek", category="groupBuff", groupBuff=true, trackHUD=false, order=40, spec="Defiance", buff="Greater Mark of Zeliek", duration=1800, targetMode="PARTY_RAID", buffCategory="resource_cost_arcane_resistance", effect="Resource cost reduction and Arcane Resistance", review=true},

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
