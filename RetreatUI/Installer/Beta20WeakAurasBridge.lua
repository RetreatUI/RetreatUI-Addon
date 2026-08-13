local RUI = RetreatUI
if not RUI then return end

-- WeakAuras finishes opening its import/update window asynchronously in CoA.
-- Reflect that final result in the already-open installer instead of leaving a
-- misleading optimistic status message behind.
RUI._beta20WeakAuraResultCallback = function(ok, message)
  local frame = _G.RetreatUICleanInstaller
  if not frame or not frame.result then return end
  frame.result:SetText(tostring(message or ""))
  if ok == true then
    frame.result:SetTextColor(12/255, 210/255, 157/255, 1)
  else
    frame.result:SetTextColor(1, 0.30, 0.24, 1)
  end
end
