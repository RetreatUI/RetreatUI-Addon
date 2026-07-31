local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0",
  summary = "The modular RetreatUI release with reliable native HUD systems.",
  changes = {
    "Added the two-page modular installer so Class HUD, unitframes, party trackers, trinkets, buffs, nameplates, NPC tracking, Details, DBM and cleanup can be selected independently.",
    "Added the in-game HUD and ElvUI unit-frame editor with persistent per-profile placement and scaling.",
    "Rebuilt party cooldown tracking around combat-log events and reduced interrupts to one direct interrupt per player while always retaining Arcane Torrent for Blood Elves.",
    "Added clean Ranger and Tinker native HUD data without duplicate tracking, including Tinker ammunition, Scrap, Bionics and beacon uptime.",
    "Improved Runemaster detection and permanently removed the unwanted Inscribed Runes title and counter.",
    "Replaced the trinket tracker with the live-tested slot-first engine for Ascension custom items, cooldowns and proc durations.",
    "Separated Pyromancer Heat and Embers: Heat now displays only 0 / 100, Ember segments have no label, and Ascension's duplicate class-resource bar is suppressed.",
    "Kept official Ascension ElvUI compatibility protection and preserved user SavedVariables throughout installation and updates.",
  },
}
