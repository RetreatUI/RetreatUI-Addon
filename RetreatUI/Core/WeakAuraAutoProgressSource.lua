local RUI = RetreatUI
if not RUI then return end

-- RetreatUI custom stateupdate triggers provide their own progressType/value or
-- progressType/duration/expirationTime fields. WeakAuras 5.21.2 must therefore
-- read progress directly from the active state (progressSource trigger -1).
--
-- Using {1, ""} leaves the region without a concrete number/timer descriptor.
-- On the Ascension client that can leave an Icon region on its previous/static
-- progress path even when the custom state has been converted to a safe timed
-- state, which is exactly what the beta.5 crash locals showed.
--
-- Apply automatic state progress to every generated HUD leaf that consumes
-- RetreatUI custom states. This lets Icon:UpdateProgress dispatch from the real
-- state.progressType and also fixes Resource/Target bars to use the same source
-- of truth as their triggers.

local originalBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(originalBuildWeakAuraHUDPackage) ~= "function" then return end

local function UsesRetreatUICustomState(display)
  if type(display) ~= "table" then return false end
  if display.regionType ~= "icon" and display.regionType ~= "aurabar" then return false end
  local triggerSet = display.triggers and display.triggers[1]
  local trigger = triggerSet and triggerSet.trigger
  return trigger and trigger.type == "custom" and trigger.custom_type == "stateupdate"
end

function RUI:BuildWeakAuraHUDPackage(...)
  local packageData, buildError = originalBuildWeakAuraHUDPackage(self, ...)
  if type(packageData) ~= "table" then return packageData, buildError end

  local patched = 0
  for _, display in ipairs(packageData.displays or {}) do
    if UsesRetreatUICustomState(display) then
      display.progressSource = {-1, ""}
      display.retreatUIAutoProgressSource = true
      patched = patched + 1
    end
  end

  packageData.autoProgressSource = {
    enabled = true,
    patched = patched,
    sourceTrigger = -1,
  }
  return packageData, buildError
end

RUI._weakAuraAutoProgressSourceLoaded = true
RUI._weakAuraAutoProgressSourceRevision = 1
