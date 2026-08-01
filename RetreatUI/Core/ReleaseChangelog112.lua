local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.9",
  summary = "Ascension action-tooltip nil-line safety for Guardian abilities and macros.",
  changes = {
    "Fixed the Ascension FrameXML GameTooltipMods.lua lineText nil error triggered when hovering Guardian actionbar buttons or generated Formation macros, including spell ID 800319.",
    "Normalised existing blank spell-tooltip FontStrings before Ascension's OnTooltipSetSpell modification reads them, preserving the complete tooltip instead of disabling it.",
    "Added a narrow SetAction fallback that suppresses only the confirmed GameTooltipMods nil-line error after retaining the already populated tooltip.",
    "Retained the Guardian live cooldown scanner exclusion for Standards, including Standard of Recovery tooltip safety.",
    "Retained the working nine Guardian Formation macros and legacy numeric iconIndex creation introduced in beta.8.",
    "Retained the Guardian cooldown/aura flicker and event-burst stutter hotfixes.",
  },
}
