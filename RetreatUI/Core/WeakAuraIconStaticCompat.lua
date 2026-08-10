local RUI = RetreatUI
if not RUI then return end

-- WeakAuras 5.21.2's Icon region has an Ascension-specific failure mode when a
-- cooldown-enabled icon is driven by a static custom state. On this client,
-- Cooldown:SetCooldown() can leave cooldown.duration populated while the
-- WeakAuras-owned cooldown.expirationTime field is nil. Icon:PreShow() then
-- evaluates cooldown.expirationTime - cooldown.duration and errors before the
-- display can finish loading.
--
-- Keep real cooldown states timed, but encode otherwise-static ICON states as a
-- zero-duration timed state at the final trigger boundary. UpdateTime() then
-- clears the icon cooldown to duration=0 / expirationTime=0, so PreShow() never
-- enters the subtraction branch. Bars/resources keep their normal static state
-- semantics; this compatibility layer only touches regionType="icon" displays.

local originalBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(originalBuildWeakAuraHUDPackage) ~= "function" then return end

local STATIC_ICON_PATCH = [[
  if state.progressType ~= "timed" then
    state.progressType = "timed"
    state.duration = 0
    state.expirationTime = 0
    state.value = nil
    state.total = nil
    state.autoHide = false
  end
]]

local function InsertAfterPlain(text, needle, addition)
  if type(text) ~= "string" or type(needle) ~= "string" or needle == "" then
    return text, false
  end
  local first, last = string.find(text, needle, 1, true)
  if not first then return text, false end
  return string.sub(text, 1, last) .. addition .. string.sub(text, last + 1), true
end

local function PatchIconCustomTrigger(display)
  if type(display) ~= "table" or display.regionType ~= "icon" or display.cooldown ~= true then
    return true, false
  end

  local triggerSet = display.triggers and display.triggers[1]
  local trigger = triggerSet and triggerSet.trigger
  local custom = trigger and trigger.custom
  if type(custom) ~= "string" or custom == "" then
    return false, false
  end

  local patched, changed = InsertAfterPlain(
    custom,
    "for key, value in pairs(snapshot) do state[key] = value end",
    STATIC_ICON_PATCH
  )
  if not changed then
    patched, changed = InsertAfterPlain(
      custom,
      "for field, value in pairs(snapshot) do state[field] = value end",
      STATIC_ICON_PATCH
    )
  end

  if not changed then return false, false end
  trigger.custom = patched
  display.retreatUIIconStaticCompat = true
  return true, true
end

function RUI:BuildWeakAuraHUDPackage(...)
  local packageData, buildError = originalBuildWeakAuraHUDPackage(self, ...)
  if type(packageData) ~= "table" then return packageData, buildError end

  local iconCount, patchedCount = 0, 0
  for _, display in ipairs(packageData.displays or {}) do
    if type(display) == "table" and display.regionType == "icon" and display.cooldown == true then
      iconCount = iconCount + 1
      local ok, changed = PatchIconCustomTrigger(display)
      if not ok then
        return nil, "WeakAura icon compatibility patch could not be applied to " .. tostring(display.id or "unknown icon")
      end
      if changed then patchedCount = patchedCount + 1 end
    end
  end

  packageData.iconStaticCompat = {
    enabled = true,
    icons = iconCount,
    patched = patchedCount,
    weakAurasVersion = "5.21.2-compatible",
  }
  return packageData, buildError
end

RUI._weakAuraIconStaticCompatLoaded = true
RUI._weakAuraIconStaticCompatRevision = 1
