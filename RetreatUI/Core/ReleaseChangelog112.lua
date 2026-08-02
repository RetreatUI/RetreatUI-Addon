local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.22",
  summary = "Emergency full-code recovery to the last user-confirmed stable baseline.",
  changes = {
    "Reset the complete active addon source to the beta.13 codebase that was confirmed stable in live Ascension testing.",
    "Removed Party Utility and interrupt tracking from the addon load order and source package.",
    "Added a recovery safety gate that removes Party Trackers from the modular installer and forces all saved tracker settings off.",
    "Rolled back every beta.14 through beta.21 runtime change for isolated review before anything is reintroduced.",
    "Preserved existing profiles and SavedVariables outside the retired party tracker settings.",
  },
}