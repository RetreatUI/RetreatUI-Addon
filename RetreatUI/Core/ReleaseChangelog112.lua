local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.20",
  summary = "Buff Manager raid-buff coverage rebuilt from the verified Conquest of Azeroth class-buff table.",
  changes = {
    "Replaced the Buff Manager raid-buff catalogue and equivalent-effect groups with the supplied Conquest of Azeroth class-buff reference.",
    "Separated mana regeneration (MP5) from resource-cost reduction so one effect no longer incorrectly satisfies the other.",
    "Added Barbarian Brutal Shout and Enduring Shout, plus Ranger Wild Blessing, using safe name-first spellbook resolution where IDs are not yet verified.",
    "Corrected multi-effect coverage for Man'ari Intuition, Earthen Endurance, Mark of Zeliek, Devotion of Grace, Beetle Pheromones, Spirit Wuju and Knight's Edict.",
    "Removed unverified raid-effect mappings and extra non-reference families from the active Buff Manager catalogue, including Demonfire Pact, Chill of the Tomb, Footpad's Adaptation and Runemaster resistance inscriptions.",
    "Honor remains exact-aura-only until its effect is confirmed; Mark of Blaumeux now covers spell power only.",
    "Added spelling aliases for Alysrazor/Alyrazor, Dextrous/Dexterous, Perseverance/Perseverence and optional 'the' variants in Runemaster Etchings.",
    "Party utility and interrupt tracking remain fully removed and are not reintroduced by this update.",
  },
}
