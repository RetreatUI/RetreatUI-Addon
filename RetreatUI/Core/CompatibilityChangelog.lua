local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.16",
  summary = "Fixes false-positive ElvUI 2.0 detection while preserving the compatibility block.",
  changes = {
    "Fixed the ElvUI 2.0 warning incorrectly appearing for users of the official Ascension ElvUI.",
    "Restored normal /rui and /rui install behaviour when the unsupported fork is not securely detected.",
    "Changed addon-folder detection to enumerate installed addons and require an exact internal folder-name match.",
    "Requires either the unique ElvUI_PartyDamage folder or multiple independent ElvUI 2.0 runtime markers before blocking the installer.",
    "No longer treats a single generic absorb or support table as sufficient proof of ElvUI 2.0.",
    "Preserves the warning and ElvUI write protection for confirmed ElvUI 2.0 installations.",
  },
}
