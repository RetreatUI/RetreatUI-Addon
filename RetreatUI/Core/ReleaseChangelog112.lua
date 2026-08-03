local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.29",
  summary = "Emergency protection against Ascension's native Character Advancement build-entry crash.",
  changes = {
    "Disabled live Character Advancement entry queries in RetreatUI because a stale or removed build entry can terminate Ascension.exe before Lua error handling can catch it.",
    "Removed the IsSpellKnown fallback from RetreatUI's learned-spell checks; HUD visibility now uses the live spellbook, which does not touch broken Character Advancement build pointers.",
    "Collector entry IDs remain as offline audit metadata, but they are no longer queried by the live HUD.",
    "All beta.28 class data, HUD whitelists, Eternal Bloodmage behavior and personal Tinker pet tools remain included.",
    "Party utility and party interrupt tracking remain removed.",
  },
}
