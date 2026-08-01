local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.2",
  summary = "Pyromancer target filtering, Details chat separation and Guardian stance alignment.",
  changes = {
    "Removed Pyromancer Heat (spell ID 807389) from ElvUI target AuraBars and target debuff displays while preserving normal target aura filtering.",
    "Hidden General and other left-docked chat frames whenever the RetreatUI Details profile is active, preventing chat text from appearing beneath the Details windows.",
    "Raised the shared class-state tracker by three pixels so Guardian formations align cleanly beside the trinket tracker.",
    "Implemented the supplied Guardian Tank WeakAura natively: curated Vanguard cooldown and charge rows, exact mitigation uptimes, Honor Guard and Valiant Knight effects, Energy tracking, and missing Honor/reinforcement reminders.",
    "Moved every shared class-state tracker to the right of the trinket tracker so stances, forms, aspects, oaths and formations no longer cover the player frame.",
    "Updated the RetreatUI ElvUI profile to the approved 2026-08-01 baseline, including the centered player castbar and revised pet, focus, raid, totem and utility-frame positions.",
    "Added a stronger raid-frame repair that enables Raid and Raid-40, rebuilds their ElvUI headers and reapplies the correct visibility rules.",
    "Added exact Pyromancer cleanup for CoAResourceBar, CoAResourceSegmentBar and their native Ascension resource segments.",
    "Made compact MobSpells tooltips the RetreatUI baseline by disabling ability descriptions and the Abilities label.",
    "Added /ruiraid diagnostics for reporting active profile, frame creation, visibility and shown state.",
  },
}
