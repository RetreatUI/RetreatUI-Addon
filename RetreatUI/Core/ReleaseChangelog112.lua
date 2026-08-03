local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.28",
  summary = "Restored the beta.26 class research behind explicit HUD whitelists, without reintroducing the HUD flood.",
  changes = {
    "Restored verified Pyromancer healer runtime IDs, active effects and Flameweaving support while keeping newly audited actions data-only and preserving the existing row limits.",
    "Restored Tinker Overcharge and Discombobulate as the only newly approved row actions, plus Eureka, Nanobot effects and the compact personal-pet tracker. Tinker remains locked to seven core and eight utility icons.",
    "Restored verified Fleshweaver, Sanguine and Accursed Bloodmage data without changing Eternal Bloodmage or automatically adding the audited actions to any HUD row.",
    "Restored Templar runtime variants, Oath Chain resource coverage, Divine Stand and Holy Stagger. Oaths remain class states and are never promoted into Main Rotation.",
    "Restored Chronomancer runtime variants, Endless Sands and Aeon/Sands resource coverage. Hasten and Time Out remain data-only until explicitly approved for the HUD.",
    "Restored multi-runtime cooldown and charge support without allowing replacement IDs to count as proof that an ability is learned.",
    "Added a shared audit guard: unapproved audit records cannot force themselves into core, utility, target-debuff or party-cooldown displays.",
    "Party utility and party interrupt tracking remain removed.",
  },
}
