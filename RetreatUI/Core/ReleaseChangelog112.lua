local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.25",
  summary = "Audited Cultist HUD coverage and complete World Map HUD suppression.",
  changes = {
    "Added the missing Cultist main abilities Darkwither, Blade of the Empire, Gaze of C'Thun: Corruption, Hammer of the Twisting Light, Entropic Slam and Eldritch Devastation.",
    "Added Dreadnought, Void Shield and Herald of the Depths with their active durations on the same cooldown icons.",
    "Added the missing Cultist support tools Malevolence, Eldritch Shock, Sanity Tap, Sermon of Dread, Eldritch Mending, Test of Pride, Horrifying Presence, Isolate, Horrorbolt, Wrath of the Black Empire and Satiate.",
    "Added native Total Madness tracking and exact 30-second uptime displays for the four Cultist tentacle totem slots.",
    "Added Shadow of the Void, Void Monstrosity, Saronite Blessing and Threat Gene to the active Cultist proc row.",
    "Corrected replacement cooldown and charge IDs for Gaze of C'Thun, Forbidden Ritual, Empire's Grasp, Obliteration Beam and Dreadfall, and restored verified active durations on existing Cultist abilities.",
    "The complete RetreatUI HUD now hides while the World Map is open and restores when the map closes.",
    "Did not import the WeakAura, duplicate Buff Manager reminders, add item/racial trackers, add the Black Blood group scanner or restore party utility and interrupt tracking.",
  },
}
