local RUI = RetreatUI
if not RUI then return end

-- Compatibility stub retained for load-order stability.
-- beta.19 installs the real resource coordinator from
-- Core/WeakAuraPerformanceBeta19.lua after this file. Never synthesize retail
-- UNIT_POWER_FREQUENT through WeakAuras.ScanEvents: that wakes unrelated
-- WeakAuras globally and was a major source of CoA frame-time spikes.
function RUI:StartWeakAuraHUDPulse()
  return true
end

function RUI:StopWeakAuraHUDPulse()
  return true
end

RUI._weakAuraHUDPulseLoaded = true
RUI._weakAuraHUDPulseRevision = 2
