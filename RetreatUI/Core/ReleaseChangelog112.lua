local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.30",
  summary = "Performance candidate with centralized HUD refreshes and lighter dungeon nameplate tracking.",
  changes = {
    "Collapsed overlapping spell, talent and build event bursts into one debounced HUD refresh plus a single delayed settlement check when Ascension updates replacement spell IDs late.",
    "Disabled BuildProfiles' separate four-pass event driver and reused the already-scanned spellbook snapshot during profile refreshes.",
    "Added a short spellbook scan cache so multiple RetreatUI consumers do not walk the entire spellbook in the same rendered frames.",
    "Deferred expensive build and HUD reconstruction until combat ends when Ascension dispatches talent or spellbook events during a pull.",
    "Cached active nameplates by GUID for NPC cooldown tracking instead of enumerating every nameplate on every mob spell cast.",
    "Cached NPC spell textures, removed repeated cooldown-entry sorting and reduced the cooldown text update rate from 0.10 to 0.15 seconds.",
    "Retains beta.29's Character Advancement crash guard and all beta.28 class data and HUD whitelists.",
    "Party utility and party interrupt tracking remain removed.",
  },
}
