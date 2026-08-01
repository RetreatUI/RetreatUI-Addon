local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

local W = RUI.HUDWidgets
if W._retreatCooldownStabilityLoaded then return end

local originalSetCooldownDisplay = W.SetCooldownDisplay
local originalUpdateSpellRow = W.UpdateSpellRow
if type(originalSetCooldownDisplay) ~= "function" or type(originalUpdateSpellRow) ~= "function" then return end

local COOLDOWN_GRACE = 0.24
local GUARDIAN_ROW_DEBOUNCE = 0.04

local function IsManagedIcon(frame)
  return frame and type(frame.definition) == "table"
end

local function SetTextIfChanged(fontString, frame, value)
  if not fontString or not frame then return end
  value = tostring(value or "")
  if frame.__ruiStableCooldownText == value then return end
  frame.__ruiStableCooldownText = value
  fontString:SetText(value)
end

local function SetCooldownColor(frame, mode)
  if not frame or not frame.cooldownText or frame.__ruiStableCooldownColor == mode then return end
  frame.__ruiStableCooldownColor = mode
  if mode == "aura" then
    frame.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
  elseif mode == "urgent" then
    frame.cooldownText:SetTextColor(1, 0.25, 0.15, 1)
  else
    frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
  end
end

local function SetShade(frame, shown)
  if not frame or not frame.cooldownShade or frame.__ruiStableShadeShown == shown then return end
  frame.__ruiStableShadeShown = shown
  if shown then frame.cooldownShade:Show() else frame.cooldownShade:Hide() end
end

local function ActiveTrackedAura(frame, now)
  local expires = tonumber(frame and frame.__ruiTrackedAuraExpires) or 0
  local remaining = expires - now
  if remaining > 0.05 then return remaining end
  if frame then frame.__ruiTrackedAuraExpires = nil end
  return 0
end

-- AdvancedHUD performs a lightweight cooldown pass every 0.10 seconds. Active
-- aura durations own the icon while they are visible, so the cooldown pass must
-- not replace their green timer, shade or saturation. Short zero-value cooldown
-- samples are also held briefly because Ascension can return one between cast,
-- charge and action-bar update events.
function W:SetCooldownDisplay(frame, remaining, active)
  if not IsManagedIcon(frame) then
    return originalSetCooldownDisplay(self, frame, remaining, active)
  end

  local now = GetTime()
  local auraRemaining = ActiveTrackedAura(frame, now)
  if auraRemaining > 0.05 then
    frame.__ruiStableCooldownActive = false
    SetShade(frame, false)
    SetTextIfChanged(frame.cooldownText, frame, self:FormatCooldown(auraRemaining))
    SetCooldownColor(frame, "aura")
    if frame.texture and frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
    return
  end

  remaining = math.max(0, tonumber(remaining) or 0)
  active = active == true and remaining > 0.05

  if active then
    frame.__ruiStableCooldownExpires = now + remaining
    frame.__ruiStableLastPositiveCooldown = now
  else
    local cachedExpires = tonumber(frame.__ruiStableCooldownExpires) or 0
    local lastPositive = tonumber(frame.__ruiStableLastPositiveCooldown) or 0
    local cachedRemaining = cachedExpires - now
    if cachedRemaining > 0.05 and (now - lastPositive) <= COOLDOWN_GRACE then
      active = true
      remaining = cachedRemaining
    else
      frame.__ruiStableCooldownExpires = nil
      frame.__ruiStableLastPositiveCooldown = nil
    end
  end

  frame.__ruiStableCooldownActive = active
  SetShade(frame, active)
  SetTextIfChanged(frame.cooldownText, frame, active and self:FormatCooldown(remaining) or "")
  SetCooldownColor(frame, active and remaining <= 3 and "urgent" or "normal")
end

local function AuraForDefinition(definition, auraCallback)
  if type(definition) ~= "table" or type(auraCallback) ~= "function" then return nil end
  local aura
  if definition.buff then aura = auraCallback(definition.buff) end
  if not aura and definition.buffID then aura = auraCallback(definition.buffID) end
  if not aura and definition.auraID then aura = auraCallback(definition.auraID) end
  return aura
end

local function CacheTrackedAuras(row, auraCallback)
  local now = GetTime()
  for _, icon in ipairs((row and row.icons) or {}) do
    local definition = icon.definition
    if icon:IsShown() and type(definition) == "table" then
      local aura = definition.trackDuration == true and definition.separateAuraTracker ~= true
        and AuraForDefinition(definition, auraCallback) or nil
      local expires = aura and tonumber(aura.expires) or 0

      if expires > now + 0.05 then
        icon.__ruiTrackedAuraExpires = expires
        icon.__ruiStableCooldownActive = false
        SetShade(icon, false)
        SetTextIfChanged(icon.cooldownText, icon, W:FormatCooldown(expires - now))
        SetCooldownColor(icon, "aura")
        if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
      else
        icon.__ruiTrackedAuraExpires = nil
        if definition.trackCharges ~= true and icon.__ruiStableCooldownActive
          and icon.texture and icon.texture.SetDesaturated then
          icon.texture:SetDesaturated(true)
        end
      end
    end
  end
end

local function IsGuardianRow(row)
  local parent = row and row.GetParent and row:GetParent() or nil
  local name = parent and parent.GetName and parent:GetName() or nil
  return name == "RetreatUIGuardianHUD"
end

local function RunRowUpdate(self, row, auraCallback)
  row.__ruiStableLastRowUpdate = GetTime()
  originalUpdateSpellRow(self, row, auraCallback)
  CacheTrackedAuras(row, auraCallback)
end

-- Guardian can emit several cooldown/action-bar events for one Formation swap
-- and the following ability. Coalesce only those row refreshes into a single
-- update window; normal 0.10-second timer updates continue uninterrupted.
function W:UpdateSpellRow(row, auraCallback)
  if not row or not IsGuardianRow(row) then
    originalUpdateSpellRow(self, row, auraCallback)
    CacheTrackedAuras(row, auraCallback)
    return
  end

  local now = GetTime()
  local elapsed = now - (tonumber(row.__ruiStableLastRowUpdate) or -100)
  if elapsed >= GUARDIAN_ROW_DEBOUNCE then
    return RunRowUpdate(self, row, auraCallback)
  end

  row.__ruiStablePendingAuraCallback = auraCallback
  if row.__ruiStableRowUpdatePending then return end
  row.__ruiStableRowUpdatePending = true
  local delay = math.max(0.01, GUARDIAN_ROW_DEBOUNCE - elapsed)
  RUI:After(delay, function()
    row.__ruiStableRowUpdatePending = false
    local callback = row.__ruiStablePendingAuraCallback
    row.__ruiStablePendingAuraCallback = nil
    if row and row.IsShown and row:IsShown() then
      RunRowUpdate(W, row, callback)
    end
  end)
end

W._retreatCooldownStabilityLoaded = true
