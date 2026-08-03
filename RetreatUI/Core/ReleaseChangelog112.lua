local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.26",
  summary = "Healer Pyromancer, healer Tinker, Bloodmage, Templar and Chronomancer source audit plus a full 21-class data review.",
  changes = {
    "Added missing healer Pyromancer actions, skin and Flamecasting states, exact active aura IDs and replacement cooldown IDs from g1d1f6fiC.",
    "Added healer Tinker Overcharge, Discombobulate, Eureka and Nanobot effects plus a compact personal Tinker-pet action and mana tracker from w-XCZHABg.",
    "Added verified Fleshweaver, Sanguine and Accursed Bloodmage actions and active effects from 25AZFWqQH. Eternal records and Eternal HUD behavior are explicitly unchanged.",
    "Added the remaining Templar spec variants, Oath Chain resource ID, Divine Stand and Holy Stagger coverage from Sidekick w_173c2281.",
    "Added healer Chronomancer Aeon of Resilience, Hasten, Time Out, active Endless Sands, Sands/Aeon resource IDs and replacement cooldown IDs from Sidekick w_cb1725f1.",
    "The shared spell runtime layer now supports multiple Ascension replacement IDs for one learned ability without duplicating its HUD icon.",
    "Reviewed every RetreatUI class database. All 21 classes have collector data; structural duplicate/no-ID warnings were retained where they represent intentional passives, resources or spell variants rather than proven missing abilities.",
    "The supplied WeakAuras were used only as implementation references. Their layouts, trinkets, racials, generic reminders and party utility or interrupt scanners were not imported.",
  },
}
