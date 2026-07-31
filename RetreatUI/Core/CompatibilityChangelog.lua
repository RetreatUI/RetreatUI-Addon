local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.15",
  summary = "Unsupported ElvUI 2.0 detection and compatibility protection.",
  changes = {
    "Detects Rhenyra's modified ElvUI 2.0 fork by its unique addon folders and runtime systems.",
    "Shows a full RetreatUI warning at login explaining the incompatibility, likely symptoms and removal steps.",
    "Blocks the RetreatUI installer while ElvUI 2.0 is installed instead of writing a RetreatUI profile into the unsupported fork.",
    "Disables RetreatUI's ElvUI-specific runtime changes for the session while keeping the standalone class HUD available.",
    "Requires the official Ascension ElvUI 7.27 before installation can be completed and validated.",
    "Preserves the beta.14 Ascension-ElvUI aura repair for supported installations.",
  },
}
