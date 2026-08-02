local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.19",
  summary = "Party utility and interrupt tracking removed completely for client stability.",
  changes = {
    "Removed PartyUtility, Party Utility V4, RetreatCD, discovery, unit-event guard, combat-log hotfix, interrupt curation and legacy bridge code from the active addon and from main.",
    "Removed the Party Trackers option from the modular installer and force-disabled the old partyUtility and partyInterrupts SavedVariable flags.",
    "No party combat-log parser, party addon-message cooldown sync, interrupt frame or utility tracker is initialized in this build.",
    "Retained Buff Manager, class HUDs, trinket tracking, TurboPlates, NPC ability tracking, profiles and user assignments unchanged.",
    "The removed tracker implementations remain available in Git history for a later isolated redesign.",
    "A full game and launcher restart is required so no Lua state from an older build remains in memory.",
  },
}
