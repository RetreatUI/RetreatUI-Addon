local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.16",
  summary = "Cleaner RetreatCD discovery after the first successful live party test.",
  changes = {
    "Confirmed that RetreatCD receives Ascension's direct legacy combat-log payload and correctly associates casts with their party owners.",
    "Added a separate discovery filter so ordinary rotational spells no longer dominate /ruicd unknown.",
    "Utility candidates are prioritized when they fire SPELL_INTERRUPT, have a utility-like name, or show a clearly long observed interval between casts.",
    "Marked the first live-test rotation noise set, including Blade of the Empire, Burning Slap, the Ballads, Sanity Tap and other rotational/offensive abilities, as hidden from the candidate view.",
    "Added /ruicd raw to retain the complete unmatched-cast list for deeper development work.",
    "The discovery filter maintains its own read-only event observations and does not change RetreatCD's cooldown state, Party Utility V4, spell database or combat-log functions.",
    "Both RetreatUI addon sync and the safe UNIT_SPELLCAST_SUCCEEDED plus legacy combat-log engine remain unchanged from beta.15.",
  },
}