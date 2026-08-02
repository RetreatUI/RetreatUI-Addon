local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.14",
  summary = "Safe remote party cooldown tracking for Ascension's legacy combat log.",
  changes = {
    "Added a small isolated bridge that prefers the legacy COMBAT_LOG_EVENT_UNFILTERED arguments Ascension actually sends and only reads CombatLogGetCurrentEventInfo as a fallback.",
    "Removed the need to replace or temporarily disable any global combat-log function.",
    "Uses name-first ability matching so a changed runtime spell ID can still resolve through the stable displayed spell name.",
    "Feeds verified remote casts into the existing stable Party Utility V4 sync protocol instead of replacing the tracker UI or cooldown state engine.",
    "Tracks known CoA interrupts Heartchill, Spellburn, Shield of Denial and Chainwhip, plus Arcane Torrent and standard kick names; unknown real kicks can be learned from an actual SPELL_INTERRUPT event.",
    "Does not classify broad Data Collector interrupt entries as direct kicks, and performs no new tooltip scanning or runtime spell-database mutation.",
    "Stops the Party Utility tracker from redrawing for every unrelated combat-log event; only relevant party casts trigger tracker updates.",
    "Added /ruiutilitydebug to report whether the bridge is active, which payload source is being received and the latest matched party ability.",
  },
}
