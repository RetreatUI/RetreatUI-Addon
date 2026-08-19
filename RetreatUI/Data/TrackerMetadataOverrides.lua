local RUI = RetreatUI
if not RUI or type(RUI.RegisterTrackerMetadata) ~= "function" then return end

-- Verified CoA tracker identities that differ from or complete the older
-- hand-curated class records. Keep this file data-only: no runtime scanning,
-- no custom WeakAuras logic.

RUI:RegisterTrackerMetadata("Bloodmage", "name:bite wound", {
  spellID = 556234,
  auraID = 556234,
  auraName = "Bite Wound",
  category = "debuff",
  trackingTypes = {"debuff"},
  template = "debuff",
  defaultUnit = "target",
  trackable = true,
  recommended = true,
  source = "RetreatSpellDump live client scan 2026-08-04",
})

-- Bloodsores is the canonical Bloodmage stacks proof case. The curated class
-- record already carries spell id 805591 and maxStacks=5; this override makes
-- the intended native tracker semantics explicit for the Builder.
RUI:RegisterTrackerMetadata("Bloodmage", 805591, {
  spellID = 805591,
  auraID = 805591,
  auraName = "Bloodsores",
  category = "proc",
  trackingTypes = {"proc", "stacks"},
  template = "proc_stacks",
  defaultUnit = "player",
  maxStacks = 5,
  trackable = true,
  recommended = true,
  source = "RetreatUI curated Bloodmage data",
})

RUI._trackerMetadataOverrides = true
