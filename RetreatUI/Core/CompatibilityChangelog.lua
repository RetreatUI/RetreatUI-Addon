local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.1",
  summary = "Stable raid-frame hotfix for the official Ascension ElvUI profile.",
  changes = {
    "Re-enabled the normal Raid frames for small raids instead of hiding them until a sixth raid member exists.",
    "Enabled the Raid-40 layout and added separate visibility rules for raids up to 25 players and raids with 26 or more players.",
    "Automatically repairs RetreatUI-managed legacy raid-frame settings in existing ElvUI profiles without deleting SavedVariables.",
    "Prevents future Unitframes & Layout installs and forced HUD refreshes from reintroducing the disabled raid-frame defaults.",
    "Preserves custom raid-frame visibility settings when they do not match RetreatUI's legacy managed values.",
  },
}
