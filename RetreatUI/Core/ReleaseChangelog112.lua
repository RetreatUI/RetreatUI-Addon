local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.25",
  summary = "Audited Cultist HUD coverage and complete World Map HUD suppression.",
  changes = {
    "Added the missing Cultist main abilities Darkwither, Blade of the Empire, Gaze of C'Thun: Corruption, Hammer of the Twisting Light, Entropic Slam and Eldritch Devastation.",
    "Added Dreadnought, Void Shield and Herald of the Depths with their active durations on the same cooldown icons.",
    "Added the missing Cultist support tools Malevolence, Eldritch Shock, Sanity Tap, Sermon of Dread, Eldritch Mending, Test of Pride, Horrifying Presence, Isolate and Satiate.",
    "Added native Total Madness tracking and exact 30-second uptime displays for the four Cultist tentacle totem slots.",
    "Corrected verified Cultist runtime spell and aura IDs and restored active durations for Dark Infusion, Eldritch Eye, End Times, Abyssal Ward, Voidborne, Embrace the Void and other existing abilities.",
    "The complete RetreatUI HUD now hides while the World Map is open and restores when the map closes.",
    "Did not import the WeakAura, duplicate Buff Manager reminders, add item/racial trackers or restore party utility and interrupt tracking.",
  },
}
