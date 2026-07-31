local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.22",
  summary = "Slot-first trinket HUD reliability hotfix.",
  changes = {
    "Replaced the item-ID-dependent trinket tracker with a slot-first engine for Ascension custom items.",
    "Added item-link, inventory texture, item-info, tooltip, paper-doll and cooldown detection fallbacks for slots 13 and 14.",
    "Added a UIParent position fallback when the live ElvUI player frame cannot be resolved.",
    "Made the trinket HUD initialize itself after login and refresh repeatedly while the item cache finishes loading.",
    "Added /ruit status, /ruit refresh and /ruit preview diagnostics for live testing.",
    "Preserved equipped-item cooldowns and learned trinket proc-duration tracking when standard item data is available.",
  },
}
