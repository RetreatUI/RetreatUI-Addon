local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.17",
  summary = "Compact interrupts, selectable ElvUI unit frames and a native Runemaster HUD conversion.",
  changes = {
    "Rebuilt the Party Interrupt Tracker as a smaller compact panel with lower rows, tighter spacing and reduced text size.",
    "Fixed interrupt spell icons being created but left hidden; every available interrupt now shows its actual spell icon beside the owner name.",
    "Restored movable and scalable Party Interrupts in /rui hud without the automatic party anchor overwriting custom placement.",
    "Expanded /rui hud with selectable player, target, target-of-target, pet, focus, party, raid and player/target castbar handles.",
    "ElvUI unit-frame handles can now be dragged, scaled from 60% to 160% and reset to the supplied RetreatUI baseline.",
    "Converted the supplied Runemaster WeakAura reference into the native RetreatUI class format with compact learned-only rows.",
    "Added Inscribed Runes resource segments plus active-only Runemaster engraving, sigil, carving and buff coverage.",
    "Capped and centred Runemaster rows to prevent overlap with power, resources, unit frames and nearby trackers.",
  },
}
