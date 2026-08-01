local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.11",
  summary = "Strict direct-interrupt curation for accurate party tracking.",
  changes = {
    "Replaced broad interrupt-category guessing with strict direct school-lock detection from the actual Ascension spell tooltip.",
    "Excluded long-cooldown area silences, fears and disruption abilities from the central interrupt tracker, including catalogue entries above 45 seconds unless explicitly marked as a primary interrupt.",
    "Promoted real direct interrupts that were incorrectly catalogued as control or utility, including learned base-class spells discovered directly from the active spellbook.",
    "Selected only the shortest verified ordinary interrupt as each class's primary tracker entry while retaining Arcane Torrent in its separate racial slot.",
    "Added /ruiinterruptlist to print the included and excluded interrupt definitions for the current class with the curation reason.",
    "Retained beta.10 legacy/modern combat-log compatibility, rank and alias resolution, remote utility tracking, Guardian Formation macros and HUD stability fixes.",
  },
}
