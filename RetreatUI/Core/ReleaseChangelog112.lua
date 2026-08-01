local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.7",
  summary = "Ascension-compatible Guardian Formation macro creation and stable HUD visuals.",
  changes = {
    "Fixed Guardian Formation macro creation on Ascension clients by using the safe dynamic question-mark macro icon instead of a full spell texture path.",
    "Added real General and Character macro-slot counts before and after /ruiformacros so creation failures are no longer reported as a misleading full-slots message.",
    "Added Wrath numeric and later boolean per-character API compatibility, with automatic General-macro fallback when the client rejects Character creation.",
    "Added the actual CreateMacro or EditMacro error text when a macro still cannot be created.",
    "Retained Tower Formation macros for Pulverize, Ram, Reprisal, Broad Sweep, Shield Challenge, Shield of Denial and Heavy Blow, plus Line Advance and Assault Battle Rush.",
    "Retained the cooldown/aura ownership fix, Guardian event-burst coalescing and brief zero-cooldown stabilization from beta.6.",
  },
}
