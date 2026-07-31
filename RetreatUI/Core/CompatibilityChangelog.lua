local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.0-beta.20",
  summary = "Ranger HUD expansion based on the supplied Archer WeakAura audit.",
  changes = {
    "Added language-independent Ranger detection through the RANGER token and core spell IDs.",
    "Added Archery Points aura ID 804329 as a five-segment Advantage resource fallback.",
    "Added Barbed Shot, Falconstrike, Elude, Horn of Perseverance and Horn of Endurance tracking.",
    "Added active duration tracking for Ranger horns and Skirmish.",
    "Reworked Ranger into compact learned-only core, utility and active-aura rows.",
  },
}
