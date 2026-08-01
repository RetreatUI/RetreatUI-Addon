local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.8",
  summary = "Legacy Ascension iconIndex support for Guardian Formation macros.",
  changes = {
    "Fixed Guardian Formation macro creation against Ascension's legacy CreateMacro signature by passing numeric iconIndex 1 instead of a string icon token.",
    "Updated EditMacro to use the same numeric icon index so existing RetreatUI Formation macros can be refreshed safely.",
    "Changed the General-macro fallback to call the exact three-argument CreateMacro form instead of supplying a fourth nil argument.",
    "Retained real General and Character macro-slot counts and full API error reporting for future compatibility testing.",
    "Retained Tower Formation macros for Pulverize, Ram, Reprisal, Broad Sweep, Shield Challenge, Shield of Denial and Heavy Blow, plus Line Advance and Assault Battle Rush.",
    "Retained the Guardian cooldown/aura flicker and event-burst stutter hotfixes.",
  },
}
