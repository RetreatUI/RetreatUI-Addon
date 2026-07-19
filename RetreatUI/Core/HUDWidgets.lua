local RUI = RetreatUI

RUI.HUDWidgets = RUI.HUDWidgets or {}
local W = RUI.HUDWidgets

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or fallback or {1, 1, 1, 1}
  return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function W:CreateBorder(frame)
  local border = CreateFrame("Frame", nil, frame)
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  RUI:SkinFrame(border, {0, 0, 0, 0}, {0, 0, 0, 1})
  frame.border = border
  return border
end

function W:CreateIcon(parent, size)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)

  frame.texture = frame:CreateTexture(nil, "BACKGROUND")
  frame.texture:SetPoint("TOPLEFT", 1, -1)
  frame.texture:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  self:CreateBorder(frame)

  frame.cooldownShade = frame:CreateTexture(nil, "ARTWORK")
  frame.cooldownShade:SetPoint("TOPLEFT", frame.texture, "TOPLEFT", 0, 0)
  frame.cooldownShade:SetPoint("BOTTOMRIGHT", frame.texture, "BOTTOMRIGHT", 0, 0)
  frame.cooldownShade:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.cooldownShade:SetVertexColor(0, 0, 0, 0.58)
  frame.cooldownShade:Hide()

  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY")
  frame.cooldownText:SetPoint("CENTER")
  frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
  if frame.cooldownText.SetShadowOffset then frame.cooldownText:SetShadowOffset(1, -1) end
  RUI:ApplyFont(frame.cooldownText, math.max(11, math.floor(size * 0.38)), "OUTLINE")

  frame.stackText = frame:CreateFontString(nil, "OVERLAY")
  frame.stackText:SetPoint("BOTTOMRIGHT", -2, 2)
  RUI:ApplyFont(frame.stackText, math.max(9, math.floor(size * 0.28)), "OUTLINE")

  frame:Hide()
  return frame
end

function W:SetBorder(frame, color, alpha)
  if not frame or not frame.border then return end
  local r, g, b, a = CopyColor(color, {0, 0, 0, 1})
  frame.border:SetBackdropBorderColor(r, g, b, alpha or a)
end

function W:SetIconInactive(frame, inactive)
  if not frame then return end
  frame:SetAlpha(inactive and 0.42 or 1)
  if frame.texture and frame.texture.SetDesaturated then
    frame.texture:SetDesaturated(inactive == true)
  end
end

function W:FormatCooldown(remaining)
  remaining = tonumber(remaining) or 0
  if remaining <= 0.05 then return "" end
  if remaining >= 3600 then return tostring(math.ceil(remaining / 3600)) .. "h" end
  if remaining >= 60 then return tostring(math.ceil(remaining / 60)) .. "m" end
  if remaining >= 10 then return tostring(math.ceil(remaining)) end
  return string.format("%.1f", remaining)
end

function W:SetCooldownDisplay(frame, remaining, active)
  if not frame then return end
  if active then
    if frame.cooldownShade then frame.cooldownShade:Show() end
    if frame.cooldownText then
      frame.cooldownText:SetText(self:FormatCooldown(remaining))
      if remaining <= 3 then
        frame.cooldownText:SetTextColor(1, 0.25, 0.15, 1)
      else
        frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
      end
    end
  else
    if frame.cooldownShade then frame.cooldownShade:Hide() end
    if frame.cooldownText then frame.cooldownText:SetText("") end
  end
end

local function AddCandidate(candidates, seen, value)
  if value == nil then return end
  local key = tostring(value)
  if seen[key] then return end
  seen[key] = true
  candidates[#candidates + 1] = value
end

function W:ReadSpellCooldown(definition)
  if not GetSpellCooldown or type(definition) ~= "table" then return 0, 0, 0 end

  local bookIndex = RUI.GetSpellRecordBookIndex and RUI:GetSpellRecordBookIndex(definition)
  if not bookIndex and RUI.GetSpellBookIndex then bookIndex = RUI:GetSpellBookIndex(definition.name) end
  if bookIndex then
    local ok, start, duration, enabled = pcall(GetSpellCooldown, bookIndex, BOOKTYPE_SPELL or "spell")
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end

  local candidates, seen = {}, {}
  AddCandidate(candidates, seen, RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(definition))
  AddCandidate(candidates, seen, definition.id)
  AddCandidate(candidates, seen, definition.name)
  for _, alias in ipairs(definition.aliases or {}) do AddCandidate(candidates, seen, alias) end

  for _, candidate in ipairs(candidates) do
    local ok, start, duration, enabled = pcall(GetSpellCooldown, candidate)
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end
  return 0, 0, 0
end

function W:ReadSpellCharges(definition)
  if not GetSpellCharges or type(definition) ~= "table" then return nil end
  local candidates, seen = {}, {}
  AddCandidate(candidates, seen, RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(definition))
  AddCandidate(candidates, seen, definition.id)
  AddCandidate(candidates, seen, definition.name)
  for _, alias in ipairs(definition.aliases or {}) do AddCandidate(candidates, seen, alias) end

  for _, candidate in ipairs(candidates) do
    local ok, current, maximum, start, duration = pcall(GetSpellCharges, candidate)
    current, maximum = tonumber(current), tonumber(maximum)
    if ok and current and maximum and maximum > 0 then
      return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
    end
  end
  return nil
end

function W:BuildSpellRow(row, definitions, size, spacing, learnedCallback, textureCallback)
  local visible = {}
  for _, definition in ipairs(definitions or {}) do
    local allowed = true
    if type(definition.show) == "function" then
      local ok, result = pcall(definition.show)
      allowed = ok and result ~= false
    end
    if allowed and learnedCallback(definition) then visible[#visible + 1] = definition end
  end

  local count = #visible
  local total = count > 0 and (count * size + (count - 1) * spacing) or 0
  row.icons = row.icons or {}

  for index, definition in ipairs(visible) do
    local icon = row.icons[index]
    if not icon then
      icon = self:CreateIcon(row, size)
      row.icons[index] = icon
    end
    icon.definition = definition
    icon.texture:SetTexture(textureCallback(definition) or select(3, GetSpellInfo(definition.name or "")) or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", row, "CENTER", -total / 2 + size / 2 + (index - 1) * (size + spacing), 0)
    icon:Show()
  end

  for index = count + 1, #row.icons do row.icons[index]:Hide() end
end

function W:UpdateSpellRow(row, auraCallback)
  local theme = RUI:GetTheme()
  for _, icon in ipairs(row.icons or {}) do
    if icon:IsShown() and icon.definition then
      local definition = icon.definition
      local chargeCurrent, chargeMaximum, chargeStart, chargeDuration
      if definition.trackCharges then
        chargeCurrent, chargeMaximum, chargeStart, chargeDuration = self:ReadSpellCharges(definition)
      end

      if chargeCurrent and chargeMaximum then
        local remaining = chargeDuration > 0 and math.max(0, chargeStart + chargeDuration - GetTime()) or 0
        local recharging = chargeCurrent < chargeMaximum and remaining > 0.05
        self:SetCooldownDisplay(icon, remaining, recharging)
        if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(chargeCurrent <= 0) end
        icon.stackText:SetText(string.format("%d/%d", chargeCurrent, chargeMaximum))
      else
        local start, duration, enabled = self:ReadSpellCooldown(definition)
        local remaining = duration > 0 and math.max(0, start + duration - GetTime()) or 0
        local active = duration > 1.5 and remaining > 0.05 and enabled ~= 0
        self:SetCooldownDisplay(icon, remaining, active)
        if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(active) end
        icon.stackText:SetText("")
      end

      local aura = definition.buff and auraCallback and auraCallback(definition.buff) or nil
      if aura then
        self:SetBorder(icon, theme.accent2, 1)
        if not (chargeCurrent and chargeMaximum) and aura.count and aura.count > 1 then
          icon.stackText:SetText(tostring(aura.count))
        end
      else
        self:SetBorder(icon, {0, 0, 0, 1}, 1)
      end
    end
  end
end

function W:CreateCounter(parent, options)
  options = options or {}
  local size = options.size or 38
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(options.width or 96, options.height or 70)
  frame:SetPoint("CENTER", UIParent, "CENTER", options.x or 0, (options.y or 0) - 12)

  frame.icon = self:CreateIcon(frame, size)
  frame.icon:ClearAllPoints()
  frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 12)
  frame.icon.cooldownText:SetText("")
  frame.icon.stackText:SetText("")
  frame.icon:Show()

  frame.nameText = frame:CreateFontString(nil, "OVERLAY")
  frame.nameText:SetPoint("TOP", frame.icon, "BOTTOM", 0, -2)
  frame.nameText:SetWidth(options.width or 96)
  frame.nameText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.nameText, options.nameSize or 8, "OUTLINE")
  frame.nameText:SetText(options.label or "")

  frame.valueText = frame:CreateFontString(nil, "OVERLAY")
  frame.valueText:SetPoint("TOP", frame.nameText, "BOTTOM", 0, -1)
  frame.valueText:SetWidth(options.width or 96)
  frame.valueText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.valueText, options.valueSize or 13, "OUTLINE")
  frame.valueText:SetText(options.value or "0")

  frame.fallback = options.fallback
  frame.key = options.key
  frame.maxValue = options.maxValue
  frame:Show()
  return frame
end

function W:SetCounter(frame, texture, value, active, color, pulseSpeed)
  if not frame or not frame.icon then return end
  frame.icon.texture:SetTexture(texture or frame.fallback or "Interface\\Icons\\INV_Misc_QuestionMark")
  frame.valueText:SetText(tostring(value or "0"))
  frame.icon:SetAlpha(active == false and 0.46 or 1)
  if frame.icon.texture.SetDesaturated then frame.icon.texture:SetDesaturated(active == false) end

  if color then
    local alpha = 1
    if pulseSpeed and pulseSpeed > 0 then
      alpha = 0.48 + 0.52 * math.abs(math.sin(GetTime() * pulseSpeed))
    end
    self:SetBorder(frame.icon, color, alpha)
    local r, g, b = CopyColor(color, {1, 1, 1, 1})
    frame.nameText:SetTextColor(r, g, b, 1)
    frame.valueText:SetTextColor(r, g, b, 1)
  else
    self:SetBorder(frame.icon, {0, 0, 0, 1}, 1)
    frame.nameText:SetTextColor(1, 1, 1, 1)
    frame.valueText:SetTextColor(1, 1, 1, 1)
  end
end

function W:CreateFormTracker(parent, options)
  options = options or {}
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(options.width or 92, options.height or 58)
  frame:SetPoint("CENTER", UIParent, "CENTER", options.x or 0, (options.y or 0) - 7)

  frame.icon = self:CreateIcon(frame, options.size or 38)
  frame.icon:ClearAllPoints()
  frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 7)
  frame.icon.cooldownText:SetText("")
  frame.icon.stackText:SetText("")

  frame.nameText = frame:CreateFontString(nil, "OVERLAY")
  frame.nameText:SetPoint("TOP", frame.icon, "BOTTOM", 0, -2)
  frame.nameText:SetWidth(options.width or 92)
  frame.nameText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.nameText, options.nameSize or 8, "OUTLINE")
  frame:Hide()
  return frame
end

function W:SetFormTracker(frame, name, texture, color)
  if not frame or not frame.icon then return end
  if not name then frame:Hide(); return end
  frame.icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  frame.nameText:SetText(string.upper(tostring(name)))
  local r, g, b = CopyColor(color, RUI:GetTheme().accent2)
  frame.nameText:SetTextColor(r, g, b, 1)
  self:SetBorder(frame.icon, color or RUI:GetTheme().accent2, 1)
  frame.icon:SetAlpha(1)
  frame.icon:Show()
  frame:Show()
end
