local RUI = RetreatUI
if not RUI then return end

-- One canonical beta.20 registry. Keep the historical branch name as an alias
-- only so already-generated payload fragments land in this exact same table.
local registry = RUI.Beta20WeakAuras or RUI.NaowhCoAWeakAuras or {classes = {}}
registry.classes = registry.classes or {}
RUI.Beta20WeakAuras = registry
RUI.NaowhCoAWeakAuras = registry

-- Release packaging replaces/populates this table with the finished General +
-- 21 CoA !WA:2! payload strings. Individual source payload fragments also write
-- into the same aliased registry above.
registry.generatedFor = registry.generatedFor or "source-placeholder"
