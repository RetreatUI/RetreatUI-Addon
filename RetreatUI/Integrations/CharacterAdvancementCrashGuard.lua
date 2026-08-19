local RUI = RetreatUI
if not RUI then return end

-- Ascension can terminate the entire client with a native assertion when
-- Character Advancement/talent state contains a stale or missing build entry.
-- Lua pcall cannot catch that native failure. beta.20 therefore never queries
-- Character Advancement or talent-group APIs from RetreatUI's live path.
--
-- Spell visibility is resolved only from the live spellbook: the same set of
-- spells the client has actually exposed to the player.

function RUI:GetActiveAdvancementSlot()
  -- beta.20 does not need an advancement slot. Returning a stable value keeps
  -- legacy callers harmless without touching talent/advancement state.
  return 1
end

function RUI:IsAdvancementEntryLearned(_)
  -- Returning nil tells SpellDatabase.lua that Character Advancement did not
  -- provide an authoritative answer, so it falls back to spellbook name/ID.
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
