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

-- The shared resource renderer refreshes its label continuously. Hiding the
-- label only during activation therefore allowed "INSCRIBED RUNES 0 / 4" to
-- return later. Shadow Show() on this one FontString so every future refresh
-- remains icon-only without changing labelled resources for other classes.
local function LockInscribedRunesLabel()
  local root = _G.RetreatUIRunemasterHUD
  local label = root and root.resourceLabel
  if not label then return end

  if not label._retreatUIOriginalShow then
    label._retreatUIOriginalShow = label.Show
    label.Show = function(self)
      self:SetText("")
      self:SetAlpha(0)
      self:Hide()
    end
  end

  label:SetText("")
  label:SetAlpha(0)
  label:Hide()
end

if module then
  local originalActivate = module.activate
  function module:activate(...)
    local result
    if originalActivate then result = originalActivate(self, ...) end
    LockInscribedRunesLabel()
    return result
  end

  local originalRefreshLayout = module.refreshLayout
  function module:refreshLayout(...)
    local result
    if originalRefreshLayout then result = originalRefreshLayout(self, ...) end
    LockInscribedRunesLabel()
    return result
  end
end
