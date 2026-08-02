local RUI = RetreatUI
if not RUI then return end

-- Ascension may retain stale or missing Character Advancement build entries
-- while a character build is being rebuilt. Calling the native entry lookup
-- functions with one of those IDs can terminate the client with an assertion;
-- Lua pcall cannot catch a native process abort.
--
-- RetreatUI therefore treats the live spellbook as the safe source of truth.
-- SpellDatabase.lua is loaded first, then these functions deliberately replace
-- its optional direct Character Advancement lookup path.

function RUI:GetActiveAdvancementSlot()
  if type(GetActiveTalentGroup) == "function" then
    local ok, slot = pcall(GetActiveTalentGroup)
    if ok and tonumber(slot) then return tonumber(slot) end
  end
  return 1
end

function RUI:IsAdvancementEntryLearned(_)
  return nil
end

function RUI:InvalidateAdvancementEntryCache()
  -- No native advancement-entry cache remains active in safe mode.
end

RUI._characterAdvancementDirectQueriesDisabled = true
RUI._characterAdvancementSafetyLoaded = true
