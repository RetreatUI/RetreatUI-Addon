local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.13",
  summary = "Emergency stability rollback for the party interrupt and utility tracker.",
  changes = {
    "Disabled the beta.10 combat-log compatibility layer that temporarily replaced CombatLogGetCurrentEventInfo while processing party casts.",
    "Disabled the beta.11 live tooltip curation layer that repeatedly scanned Ascension custom spell tooltips on login and spellbook changes.",
    "Returned the party interrupt and utility tracker to the standalone Party Utility V4 implementation while the class-by-class interrupt list is rebuilt from verified data.",
    "Kept all profiles, SavedVariables, Guardian Formation macros, HUD cooldown stability fixes and the beta.12 global stance/form layout.",
    "No interrupt database corrections from the unfinished audit have been applied in this emergency build.",
  },
}
