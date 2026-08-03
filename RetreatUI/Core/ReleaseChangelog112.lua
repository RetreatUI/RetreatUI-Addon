local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.27",
  summary = "Emergency rollback of the beta.26 class audit that flooded class HUD rows with unrelated abilities.",
  changes = {
    "Restored the complete beta.25 class database, HUD definitions and class load order.",
    "Removed the beta.26 Pyromancer, Tinker, Bloodmage, Templar and Chronomancer audit overlays from the live addon.",
    "Removed the beta.26 multi-runtime spell changes and the personal Tinker pet tracker.",
    "HUD rows once again contain only the previously curated active abilities, cooldowns, defensives, utility and procs.",
    "Eternal Bloodmage remains unchanged.",
    "Party utility and party interrupt tracking remain removed.",
  },
}
