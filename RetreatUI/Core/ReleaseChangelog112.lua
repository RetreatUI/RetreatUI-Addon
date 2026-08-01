local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.4",
  summary = "Guardian main-cooldown policy, rank-safe Ram tracking, active Standard uptime and restored left chat.",
  changes = {
    "Added Ram to the Guardian main rotation row using spellbook-name resolution, with spell ID 573204 retained only as the known Rank 2 fallback so future ranks remain trackable.",
    "Moved Brace into the Guardian main rotation row and preserved its cooldown and active defensive duration on the same icon.",
    "Made Guardian offensive and defensive cooldown placement data-driven: future learned cooldowns in either category automatically join the main row, while mobility, control, interrupts, taunts, racials and ordinary utility remain secondary.",
    "Added one active Guardian Standard tracker that shows the current banner name, icon and remaining uptime. GetTotemInfo is authoritative, with cast-event fallback for Standard of Valiance and Standard of Recovery.",
    "Removed permanent Standard cooldown icons from the Guardian rows because Standards are now represented by their active uptime tracker.",
    "Restored General and the permanent left ElvUI chat panel. The beta.2 chat-hiding compatibility entry point now repairs and shows the chat instead of hiding it.",
    "Tracked the Guardian Reprisal availability proc using aura ID 504885, showing the six-second duration and glow on the existing Reprisal ability icon.",
    "Moved Raise Shield into the Guardian main rotation row and enabled its native 2-charge/recharge display while keeping its active mitigation duration on the same icon.",
    "Removed Pyromancer Heat (spell ID 807389) from ElvUI target AuraBars and target debuff displays while preserving normal target aura filtering.",
    "Raised the shared class-state tracker by three pixels so Guardian formations align cleanly beside the trinket tracker.",
    "Updated the RetreatUI ElvUI profile to the approved 2026-08-01 baseline and retained the raid-frame, Pyromancer native-resource and compact MobSpells fixes.",
  },
}
