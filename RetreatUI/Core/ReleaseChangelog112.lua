local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2",
  summary = "ElvUI baseline, raid-frame and Pyromancer resource hotfix.",
  changes = {
    "Updated the RetreatUI ElvUI profile to the approved 2026-08-01 baseline, including the centered player castbar and revised pet, focus, raid, totem and utility-frame positions.",
    "Changed the chat input placement back to the ElvUI default instead of forcing it above the chat window.",
    "Added a stronger raid-frame repair that enables Raid and Raid-40, rebuilds their ElvUI headers and reapplies the correct visibility rules.",
    "Added exact Pyromancer cleanup for CoAResourceBar, CoAResourceSegmentBar and their native Ascension resource segments.",
    "Made compact MobSpells tooltips the RetreatUI baseline by disabling ability descriptions and the Abilities label.",
    "Added /ruiraid diagnostics for reporting active profile, frame creation, visibility and shown state.",
  },
}
