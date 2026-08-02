local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.18",
  summary = "Emergency rollback after Ascension Character Advancement assertion failure.",
  changes = {
    "Removed RetreatCD, RetreatCDUnitGuard and RetreatCDDiscoveryV2 from the live TOC load order after the native Ascension client assertion CharacterAdvancementBuildEntry::UpdatePointers: entry 14265 not found returned during live testing.",
    "Retained the stable Party Utility V4 base, Buff Manager, class HUDs, stance layout and all existing profiles.",
    "Kept the RetreatCD source files in the repository for isolated investigation, but none of them are loaded by beta.18.",
    "This is a client-safety rollback; remote non-RetreatUI party cooldown detection is therefore disabled again.",
    "No SavedVariables or user profiles are deleted or reset by this rollback.",
  },
}
