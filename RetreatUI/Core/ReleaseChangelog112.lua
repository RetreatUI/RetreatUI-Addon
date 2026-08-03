local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.2-beta.24",
  summary = "Wago-sourced Starcaller, Felsworn, resource cleanup and Zul'Gurub coverage.",
  changes = {
    "Added the missing Starcaller aspects, Lunar Phase, defensive tools, taunt, mobility and long cooldowns from the audited Starcaller package.",
    "Added Felsworn pact states, missing active procs, Betray, Blood of Mannoroth, Blur, Eye of Archimonde and Fel Bargain from the audited Felsworn package.",
    "Extended the safe native-resource cleanup with CoAMultiCastActionBarFrame and CoAResourceOrb from the audited resource-bar package.",
    "Registered the original Zul'Gurub raid package through WeakAuras companion data; /ruizg opens the normal WeakAuras import review.",
    "Does not import, delete, reposition or restyle any personal WeakAuras automatically.",
    "Party utility and interrupt tracking remain removed.",
  },
}
