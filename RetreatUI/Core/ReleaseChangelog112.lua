local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.17",
  summary = "RetreatCD live-test hardening and precise matched-ability diagnostics.",
  changes = {
    "Confirmed through a full dungeon test that Ascension's direct legacy combat-log payload is stable and correctly associates thousands of party casts with their owners.",
    "Disabled RetreatCD's unreliable UNIT_SPELLCAST_SUCCEEDED fallback after live output showed Ascension rank/action values being mistaken for spell IDs, including a false Vendom Bolt to Shield Bash ID collision.",
    "Kept legacy combat-log tracking, pet GUID ownership, RetreatUI addon sync, cooldown deduplication and the existing Party Utility V4 display unchanged.",
    "Replaced the beta.16 discovery module in the load order with a combat-log-only v2 filter; the previous discovery file remains in the repository for rollback.",
    "Filters internal Rank entries, NYI names, low-ID rank/action noise and high-frequency names such as Temple Guardian from the default candidate list.",
    "Uses strong and weak utility-name confidence plus plausible CoA IDs and observed cast intervals instead of treating every Shield, Guardian or Immunity name as a cooldown.",
    "Added /ruicd matched to show exactly which known party abilities were recognized, who cast them and how many times.",
    "Retained /ruicd unknown for filtered candidates and /ruicd raw for every unmatched combat-log cast.",
    "No global combat-log API is replaced, no combat-log entries are cleared and no tooltip or Character Advancement scanning is introduced.",
  },
}
