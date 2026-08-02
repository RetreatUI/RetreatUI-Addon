local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.21",
  summary = "Native Character Advancement safety hotfix.",
  changes = {
    "Added a safety layer that disables RetreatUI's direct runtime queries against Ascension's native Character Advancement entry API.",
    "Talent and ability visibility now falls back to the live spellbook when collector entry data is involved.",
    "This prevents missing or stale CA entries from triggering an unrecoverable CharacterAdvancementBuildEntry::UpdatePointers assertion through RetreatUI.",
    "The beta.20 Buff Manager raid-buff database remains included.",
    "Party utility and interrupt tracking remain fully removed.",
  },
}
