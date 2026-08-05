local RUI = RetreatUI
if not RUI then return end

-- Ascension can terminate the entire client with a native assertion when
-- unsafe learned-state or Character Advancement APIs are queried while the
-- build contains a stale/missing build entry. Lua pcall cannot catch that
-- native failure, so RetreatUI must not use those APIs in its live HUD path.
--
-- Spell visibility is resolved from the live spellbook instead. This is the
-- same information the player can actually cast and is safe across broken or
-- partially migrated Character Advancement builds.

function RUI:GetActiveAdvancementSlot()
  return 1
end

function RUI:IsAdvancementEntryLearned(_)
  -- Returning nil tells SpellDatabase.lua that Character Advancement did not
  -- provide an authoritative answer, so it falls back to spellbook name/ID.
  -- Do not call native Character Advancement tables here: invalid build entries
  -- crash the
  -- executable before Lua error handling can run.
  return nil
end

function RUI:IsSpellIDLearned(spellID)
  spellID = tonumber(spellID)
  if not spellID then return false end
  if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end
  return self.spellbook ~= nil
    and self.spellbook.idSet ~= nil
    and self.spellbook.idSet[spellID] == true
end

RUI.characterAdvancementQueriesDisabled = true
RUI._characterAdvancementCrashGuardLoaded = true
