local RUI = RetreatUI

-- Native RetreatUI conversion of the supplied Runemaster WeakAura pack.
-- The WA used compact centred rows with a seven-icon priority row and a
-- secondary utility row. RetreatUI keeps that structure while using learned
-- spell detection, native cooldowns, build profiles and active-only proc icons.
-- The source WeakAura remains external and is never imported or modified.
local module = RUI:RegisterAdvancedClassHUD("Runemaster", {
  frameName = "RetreatUIRunemasterHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {ARCANE=true,RIFTBLADE=true,RUNIC=true},

  maxCore = 7,
  coreIconSize = 38,
  coreSpacing = 2,
  coreOrder = {
    "Power Engraving",
    "Primordial Pulse",
    "Zenith",
    "Fists of Power",
    "Fist of the Ancients",
    "Runic Brand",
    "Warpdagger",
  },
  strictCoreOrder = false,

  maxUtility = 10,
  utilityIconSize = 30,
  utilitySpacing = 2,
  utilityOrder = {
    "Glacial Rune",
    "Silencing Rune",
    "Permafrost Rune",
    "Hurricane",
    "Runic Hurricane",
    "Granite Resolve",
    "Warding Rune",
    "Phase Out",
    "Speed Rune",
    "Resonance Rune",
  },
  strictUtilityOrder = false,

  maxProcs = 10,
})

-- Inscribed Runes is intentionally icon-only. The shared resource renderer
-- also owns labelled resources for other classes, so suppress only the
-- Runemaster label after its native HUD frame has been created.
local function HideInscribedRunesLabel()
  local root = _G.RetreatUIRunemasterHUD
  if root and root.resourceLabel then
    root.resourceLabel:SetText("")
    root.resourceLabel:SetAlpha(0)
    root.resourceLabel:Hide()
  end
end

if module then
  local originalActivate = module.activate
  function module:activate(...)
    local result
    if originalActivate then result = originalActivate(self, ...) end
    HideInscribedRunesLabel()
    return result
  end

  local originalRefreshLayout = module.refreshLayout
  function module:refreshLayout(...)
    local result
    if originalRefreshLayout then result = originalRefreshLayout(self, ...) end
    HideInscribedRunesLabel()
    return result
  end
end
