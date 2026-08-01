local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.10",
  summary = "Reliable party interrupt and utility cooldown detection on Ascension.",
  changes = {
    "Fixed party interrupt and utility cooldown tracking when Ascension exposes CombatLogGetCurrentEventInfo but delivers the valid legacy combat-log payload directly through COMBAT_LOG_EVENT_UNFILTERED.",
    "Added automatic fallback between direct legacy event arguments and the modern combat-log getter instead of silently accepting an empty payload.",
    "Normalised both combat-log layouts before Party Utility V4 processes them, preserving source GUID, player name, spell ID and spell name consistently.",
    "Added spell-name, alias and known-rank resolution so custom Ascension rank IDs map back to the tracked interrupt or party utility definition.",
    "Added known utility aura-application fallback for custom abilities that do not emit a normal SPELL_CAST_SUCCESS event.",
    "Retained the working Guardian Formation macros, cooldown/aura HUD stability and action-tooltip nil-line safety from the previous hotfixes.",
  },
}
