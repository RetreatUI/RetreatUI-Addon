local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.6",
  summary = "Guardian Formation-dance macros and stable cooldown/aura HUD visuals.",
  changes = {
    "Fixed rapid HUD flickering when a duration-tracked Guardian ability was active while the same spell was on cooldown. Active aura timers now remain authoritative until the buff expires.",
    "Added /ruiforms to print the live stance indices exposed by Ascension for Tower, Assault and Line Formation.",
    "Added /ruiformacros to create or update character-specific Formation-dance macros using the live stance indices instead of hardcoded assumptions.",
    "Generated Tower Formation macros for Pulverize, Ram, Reprisal, Broad Sweep, Shield Challenge, Shield of Denial and Heavy Blow.",
    "Generated a Line Formation macro for Advance and an Assault Formation macro for Battle Rush.",
    "Retained direct Standard of Recovery aura tracking, Guardian tooltip-scanner safety, Heroic Resolve in utility, rank-safe Ram tracking and the restored left chat.",
  },
}
