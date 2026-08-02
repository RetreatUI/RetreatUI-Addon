local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.15",
  summary = "RetreatCD: a safer OmniCD-style party cooldown event engine for CoA.",
  changes = {
    "Replaced the beta.14 bridge in the load order with the new isolated RetreatCD engine while keeping the old bridge file available for an easy rollback.",
    "Combines party and party-pet UNIT_SPELLCAST_SUCCEEDED events with direct legacy COMBAT_LOG_EVENT_UNFILTERED arguments and a read-only API fallback.",
    "Maps pet casts back to their party owner, stores activity by owner GUID and deduplicates the same cast when both event sources report it.",
    "Uses name-first matching and binds changed runtime spell IDs to the stable ability name for the rest of the session.",
    "Keeps RetreatUI addon sync and the existing Party Utility V4 display, so players with RetreatUI still provide the most exact cooldown state.",
    "Adds support for shared cooldown metadata and cooldown-reset metadata without scanning tooltips or Character Advancement entries.",
    "Includes verified Heartchill data, provisional Spellburn and Shield of Denial fallbacks, Chainwhip, Arcane Torrent and standard 3.3.5 interrupt fallbacks.",
    "Unknown abilities that actually fire SPELL_INTERRUPT are learned safely for the current session with a conservative fallback duration.",
    "Added /ruicd status, /ruicd unknown, /ruicd clear, /ruicd refresh and /ruicd find <ability> diagnostics.",
    "Never replaces CombatLogGetCurrentEventInfo, never calls CombatLogClearEntries and never mutates the RetreatUI spell database.",
  },
}