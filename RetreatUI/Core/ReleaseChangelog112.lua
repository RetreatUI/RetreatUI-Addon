local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.23",
  summary = "Stable beta.22 recovery baseline with the verified CoA raid-buff catalog restored.",
  changes = {
    "Restored only the verified Buff Manager catalog previously tested in beta.20.",
    "Separated MP5 from resource-cost reduction so those effects no longer satisfy each other incorrectly.",
    "Restored Barbarian Brutal Shout and Enduring Shout, Ranger Wild Blessing, and the verified multi-effect raid buffs.",
    "Kept the beta.22 recovery codebase unchanged outside BuffManager.lua, version metadata and this changelog.",
    "Party utility and interrupt tracking remain physically removed and disabled.",
  },
}
