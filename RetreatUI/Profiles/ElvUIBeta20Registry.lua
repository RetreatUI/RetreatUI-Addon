local RUI = RetreatUI
if not RUI then return end

-- Canonical beta.20 registry readiness check. The payload file itself owns the
-- RetreatUI names; no legacy/reference aliases are accepted here.
RUI._beta20ElvUIRegistryReady = type(RUI.Beta20ElvUIExports) == "table"
  and type(RUI.Beta20ElvUIScales) == "table"
