local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2",
  summary = "Stable release with the current class changes, crash protection and performance refresh system.",
  changes = {
    "Promoted the tested beta.30 codebase to the stable Release channel.",
    "Permanently removed party utility, interrupt, combat-res, dispel, external and group-defensive tracking from RetreatUI and from the modular installer.",
    "Added an upgrade migration that disables retired party-tracker SavedVariables and prevents older profiles from re-enabling them.",
    "Collapsed overlapping spell, talent and build event bursts into one debounced HUD refresh with one optional delayed settlement check.",
    "Added shared spellbook scan caching and deferred expensive build/HUD reconstruction until combat ends.",
    "Optimized NPC cooldown tracking with GUID-to-nameplate and spell-texture caches.",
    "Retains the Character Advancement native-crash guard, curated class data and explicit HUD whitelists.",
    "Eternal Bloodmage remains isolated from non-Eternal Bloodmage audit records.",
  },
}
