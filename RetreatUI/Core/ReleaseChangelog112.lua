local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.5",
  summary = "Guardian Standard aura tracking, tooltip-scanner safety and Heroic Resolve utility placement.",
  changes = {
    "Added direct player-aura tracking for active Guardian Standards. Standard of Recovery now uses aura ID 500266 and displays its actual remaining uptime even when Ascension does not expose the banner through GetTotemInfo.",
    "Kept GetTotemInfo and cast-event fallbacks for Standards that do not create a player aura, including Standard of Valiance.",
    "Prevented Guardian Standards from entering the live cooldown tooltip scanner, avoiding the Ascension GameTooltipMods nil-line error triggered by Standard of Recovery spell ID 500260.",
    "Moved Heroic Resolve into the Guardian utility row as an explicit exception while preserving its cooldown and active five-second duration on the same icon.",
    "Retained rank-safe Ram tracking, Brace and Raise Shield in the main row, the Guardian offensive/defensive cooldown policy, and restored permanent left chat.",
    "Tracked the Guardian Reprisal availability proc using aura ID 504885, showing the six-second duration and glow on the existing Reprisal ability icon.",
    "Removed Pyromancer Heat from target aura displays, retained native Heat/Ember cleanup, and preserved the approved ElvUI, raid-frame and compact MobSpells baselines.",
  },
}
