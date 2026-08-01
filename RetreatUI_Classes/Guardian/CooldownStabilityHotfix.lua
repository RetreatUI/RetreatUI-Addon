local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

local W = RUI.HUDWidgets
if W._guardianCooldownStabilityHotfixLoaded then return end
W._guardianCooldownStabilityHotfixLoaded = true

local database = type(RUI.GetClassSpellDatabase) == "function" and RUI:GetClassSpellDatabase("Guardian") or nil
if type(database) == "table" then
  for _, definition in ipairs(database.spells or {}) do
    if type(definition) == "table" then
      local row = tostring(definition.hudRow or "")
      if row == "core" or row == "utility" or definition.forceMain == true or definition.forceUtility == true then
        definition.guardianCooldownStability = true
      end
    end
  end
end

local originalSetCooldownDisplay = W.SetCooldownDisplay
local originalUpdateSpellRow = W.UpdateSpellRow
if type(originalSetCooldownDisplay) ~= "function" or type(originalUpdateSpellRow) ~= "function" then return end

local COOLDOWN_GRACE = 0.24
local ROW_DEBOUNCE = 0.04

local function IsGuardianIcon(frame)
  return frame and type(frame.definition) == "table"
    and frame.definition.guardianCooldownStability == true
end

local function SetTextIfChanged(fontString, cacheOwner, cacheKey, value)
  if not fontString or not cacheOwner then return end
  value = tostring(value or "")
  if cacheOwner[cacheKey] == value then return end
  cacheOwner[cacheKey] = value
  fontString:SetText(value)
end

local function SetCooldownColor(frame, mode)
  if not frame or not frame.cooldownText or frame._ruiGuardianCooldownColor == mode then return end
  frame._ruiGuardianCooldownColor = mode
  if mode == "aura" then
    frame.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
  elseif mode == "urgent" then
    frame.cooldownText:SetTextColor(1, 0.25, 0.15, 1)
  else
    frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
  end
end

local function SetShade(frame, shown)
  if not frame or not frame.cooldownShade or frame._ruiGuardianShadeShown == shown then return end
  frame._ruiGuardianShadeShown = shown
  if shown then frame.cooldownShade:Show() else frame.cooldownShade:Hide() end
end

local function AuraRemaining(frame, now)
  local expires = tonumber(frame and frame._ruiGuardianAuraExpires) or 0
  local remaining = expires - now
  if remaining > 0.05 then return remaining end
  if frame then frame._ruiGuardianAuraExpires = nil end
  return 0
end

function W:SetCooldownDisplay(frame, remaining, active)
  if not IsGuardianIcon(frame) then
    return originalSetCooldownDisplay(self, frame, remaining, active)
  end

  local now = GetTime()
  local auraRemaining = AuraRemaining(frame, now)
  if auraRemaining > 0.05 then
    SetShade(frame, false)
    SetTextIfChanged(frame.cooldownText, frame, "_ruiGuardianCooldownText", self:FormatCooldown(auraRemaining))
    SetCooldownColor(frame, "aura")
    if frame.texture and frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
    frame._ruiGuardianCooldownActive = false
    return
  end

  remaining = math.max(0, tonumber(remaining) or 0)
  active = active == true and remaining > 0.05

  if active then
    frame._ruiGuardianCooldownExpires = now + remaining
    frame._ruiGuardianLastPositiveCooldown = now
  else
    local cachedExpires = tonumber(frame._ruiGuardianCooldownExpires) or 0
    local lastPositive = tonumber(frame._ruiGuardianLastPositiveCooldown) or 0
    local cachedRemaining = cachedExpires - now
    if cachedRemaining > 0.05 and (now - lastPositive) <= COOLDOWN_GRACE then
      active = true
      remaining = cachedRemaining
    else
      frame._ruiGuardianCooldownExpires = nil
      frame._ruiGuardianLastPositiveCooldown = nil
    end
  end

  frame._ruiGuardianCooldownActive = active
  SetShade(frame, active)
  SetTextIfChanged(frame.cooldownText, frame, "_ruiGuardianCooldownText", active and self:FormatCooldown(remaining) or "")
  SetCooldownColor(frame, active and remaining <= 3 and "urgent" or "normal")
end

local function FindTrackedAura(definition, auraCallback)
  if type(definition) ~= "table" or type(auraCallback) ~= "function" then return nil end
  local aura
  if definition.buff then aura = auraCallback(definition.buff) end
  if not aura and definition.buffID then aura = auraCallback(definition.buffID) end
  if not aura and definition.auraID then aura = auraCallback(definition.auraID) end
  return aura
end

local function CacheAuraOwnership(row, auraCallback)
  local now = GetTime()
  for _, icon in ipairs((row and row.icons) or {}) do
    if icon:IsShown() and IsGuardianIcon(icon) then
      local definition = icon.definition
      local aura = definition.trackDuration == true and definition.separateAuraTracker ~= true
        and FindTrackedAura(definition, auraCallback) or nil
      local expires = aura and tonumber(aura.expires) or 0
      if expires > now + 0.05 then
        icon._ruiGuardianAuraExpires = expires
        SetShade(icon, false)
        SetTextIfChanged(icon.cooldownText, icon, "_ruiGuardianCooldownText", W:FormatCooldown(expires - now))
        SetCooldownColor(icon, "aura")
        if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
      else
        icon._ruiGuardianAuraExpires = nil
        if definition.trackCharges ~= true and icon._ruiGuardianCooldownActive
          and icon.texture and icon.texture.SetDesaturated then
          icon.texture:SetDesaturated(true)
        end
      end
    end
  end
end

local function HasGuardianIcons(row)
  for _, icon in ipairs((row and row.icons) or {}) do
    if IsGuardianIcon(icon) then return true end
  end
  return false
end

local function RunRowUpdate(self, row, auraCallback)
  row._ruiGuardianLastRowUpdate = GetTime()
  originalUpdateSpellRow(self, row, auraCallback)
  CacheAuraOwnership(row, auraCallback)
end

function W:UpdateSpellRow(row, auraCallback)
  if not row or not HasGuardianIcons(row) then
    return originalUpdateSpellRow(self, row, auraCallback)
  end

  local now = GetTime()
  local elapsed = now - (tonumber(row._ruiGuardianLastRowUpdate) or -100)
  if elapsed >= ROW_DEBOUNCE then
    return RunRowUpdate(self, row, auraCallback)
  end

  row._ruiGuardianPendingAuraCallback = auraCallback
  if row._ruiGuardianRowUpdatePending then return end
  row._ruiGuardianRowUpdatePending = true
  local delay = math.max(0.01, ROW_DEBOUNCE - elapsed)
  RUI:After(delay, function()
    row._ruiGuardianRowUpdatePending = false
    local callback = row._ruiGuardianPendingAuraCallback
    row._ruiGuardianPendingAuraCallback = nil
    if row and row.IsShown and row:IsShown() then
      RunRowUpdate(W, row, callback)
    end
  end)
end

RUI._guardianCooldownStabilityHotfixLoaded = true
