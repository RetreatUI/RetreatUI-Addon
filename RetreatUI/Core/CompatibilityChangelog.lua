local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.21",
  summary = "Modular installer, clean Tinker HUD and reliable group cooldown tracking.",
  changes = {
    "Replaced the all-or-nothing installer with a two-page component installer and Full, HUD, Layout and Custom presets.",
    "Made Class HUD, ElvUI, nameplates, party trackers, trinkets, buffs, Details, DBM, game settings and Ascension cleanup independently selectable.",
    "Added combat-log cooldown tracking for party members who do not use RetreatUI.",
    "Reduced the interrupt tracker to one row per player with one direct interrupt and Arcane Torrent always included for Blood Elves.",
    "Added a clean Tinker ammunition tracker, separate Scrap resource, Bionics reminder, beacon uptime and missing Tinker abilities without duplicate tracking.",
    "Added language-independent Tinker detection through the TINKER token and core spell IDs.",
  },
}
