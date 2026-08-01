local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

local W = RUI.HUDWidgets
if W._retreatCooldownStabilityLoaded then return end

local originalSetCooldownDisplay = W.SetCooldownDisplay
local originalUpdateSpellRow = W.UpdateSpellRow

local function ActiveTrackedAura(frame)
  if not frame then return nil end
  local expires = tonumber(frame.__ruiTrackedAuraExpires) or 0
  if expires <= GetTime() + 0.05 then
    frame.__ruiTrackedAuraExpires = nil
    return nil
  end
  return expires - GetTime()
end

-- AdvancedHUD has a lightweight 0.10-second cooldown timer pass. Previously it
-- could overwrite an active green aura-duration display with the spell's own
-- cooldown, while UNIT_AURA immediately changed it back. That visual race was
-- the source of the rapid icon/text flicker after using duration-tracked spells.
function W:SetCooldownDisplay(frame, remaining, active)
  local auraRemaining = ActiveTrackedAura(frame)
  if auraRemaining then
    originalSetCooldownDisplay(self, frame, 0, false)
    if frame.cooldownShade then frame.cooldownShade:Hide() end
    if frame.texture and frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
    if frame.cooldownText then
      frame.cooldownText:SetText(self:FormatCooldown(auraRemaining))
      frame.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
    end
    return
  end
  return originalSetCooldownDisplay(self, frame, remaining, active)
end

local function AuraForDefinition(definition, auraCallback)
  if type(definition) ~= "table" or type(auraCallback) ~= "function" then return nil end
  local aura
  if definition.buff then aura = auraCallback(definition.buff) end
  if not aura and definition.buffID then aura = auraCallback(definition.buffID) end
  if not aura and definition.auraID then aura = auraCallback(definition.auraID) end
  return aura
end

function W:UpdateSpellRow(row, auraCallback)
  originalUpdateSpellRow(self, row, auraCallback)

  for _, icon in ipairs((row and row.icons) or {}) do
    local definition = icon.definition
    local aura = icon:IsShown() and AuraForDefinition(definition, auraCallback) or nil
    if definition and definition.trackDuration == true
      and definition.separateAuraTracker ~= true
      and aura and tonumber(aura.expires) and tonumber(aura.expires) > GetTime() + 0.05 then
      icon.__ruiTrackedAuraExpires = tonumber(aura.expires)
    else
      icon.__ruiTrackedAuraExpires = nil
    end
  end
end

W._retreatCooldownStabilityLoaded = true
