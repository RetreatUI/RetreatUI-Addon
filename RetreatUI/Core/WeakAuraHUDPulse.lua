local RUI = RetreatUI
if not RUI then return end

-- Ascension exposes several class resources through custom frames rather than a
-- normal UnitPower token. The old AdvancedHUD sampled those frames every 0.12s.
-- Keep the exact cadence, but only use it to wake WeakAuras' resource triggers;
-- the visible HUD itself remains fully owned by WeakAuras.
local running = false

local function Pulse()
  if not running then return end
  if RUI.weakAuraHUDMode == true and WeakAuras and type(WeakAuras.ScanEvents) == "function" then
    pcall(WeakAuras.ScanEvents, "UNIT_POWER_FREQUENT", "player")
  end
  if type(RUI.After) == "function" then
    RUI:After(0.12, Pulse)
  else
    running = false
  end
end

function RUI:StartWeakAuraHUDPulse()
  if running then return true end
  running = true
  Pulse()
  return true
end

function RUI:StopWeakAuraHUDPulse()
  running = false
  return true
end

RUI._weakAuraHUDPulseLoaded = true
RUI._weakAuraHUDPulseRevision = 1
