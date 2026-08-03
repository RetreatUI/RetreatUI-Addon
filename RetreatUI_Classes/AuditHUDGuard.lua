local RUI = RetreatUI
if not RUI then return end

-- Audit/source-reference files may enrich spell IDs, cooldown variants, aura
-- IDs and resources, but they must never silently expand the player's HUD.
-- A new audited action is data-only unless it is explicitly marked hudApproved.
local protected, approved = 0, 0

for _, database in pairs(RUI.spellDatabase or {}) do
  if type(database) == "table" then
    for _, record in ipairs(database.spells or {}) do
      if type(record) == "table" and record.auditRecord == true then
        if record.hudApproved == true then
          approved = approved + 1
        else
          record.trackHUD = false
          record.forceHUD = nil
          record.forceMain = nil
          record.forceUtility = nil
          record.partyCooldown = false
          protected = protected + 1
        end

        -- Target bars are also part of the visible HUD. They require their own
        -- explicit approval instead of being inherited from an audit package.
        if record.targetDebuff == true and record.targetApproved ~= true then
          record.targetDebuff = false
        end
      end
    end
    database.auditHUDGuardApplied = true
  end
end

RUI.auditHUDGuardSummary = {protected=protected, approved=approved}
RUI._auditHUDGuardLoaded = true
