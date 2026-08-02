local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.12",
  summary = "One global trinket-relative lane for every active class stance and form.",
  changes = {
    "Unified the legacy form tracker and the grouped class-state tracker under one shared layout manager instead of using class-specific coordinates.",
    "Placed every visible stance, form, formation, aspect, oath and presence directly to the right of the RetreatUI trinket tracker.",
    "Made hidden states consume no space so multiple active class states remain in one compact left-to-right row.",
    "Moved every state label above its icon, including Necromancer Undead Assault, Protect and Pacify modes that previously displayed text underneath.",
    "Fixed the Necromancer Protect icon overlapping the second trinket by reducing the old form tracker's oversized invisible container to the actual icon footprint.",
    "Retained beta.11 interrupt curation unchanged while the class-by-class interrupt audit is still in progress.",
  },
}
