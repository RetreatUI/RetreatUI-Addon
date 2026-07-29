local RUI = RetreatUI

function RUI:ApplyDBMTheme()
  self:EnsureAddOnLoaded({"DBM-Core", "DBM"})
  local changed = false
  local font = self:GetFontPath()
  if DBM and DBM.Options then
    DBM.Options.WarningFont = font
    DBM.Options.WarningFontStyle = "OUTLINE"
    DBM.Options.SpecialWarningFont = font
    DBM.Options.SpecialWarningFontStyle = "OUTLINE"
    changed = true
  end
  if DBT and DBT.Options then
    DBT.Options.Font = font
    DBT.Options.FontSize = 11
    DBT.Options.Texture = "Interface\\TargetingFrame\\UI-StatusBar"
    changed = true
  end
  return changed, changed and "DBM font and timer theme applied" or "DBM options were unavailable"
end
