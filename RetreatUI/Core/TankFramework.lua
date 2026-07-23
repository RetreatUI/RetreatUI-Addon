local RUI = RetreatUI

RUI.tankProfiles = RUI.tankProfiles or {}


local DEFAULT_SLOT_ORDER = {
  builder = 10,
  spender = 20,
  rotational = 30,
  defensive = 50,
  mobility = 60,
  dispel = 70,
  taunt = 90,
  interrupt = 100,
}

function RUI:RegisterTankProfile(className, profile)
  if type(className) ~= "string" or className == "" or type(profile) ~= "table" then return false end
  profile.className = className
  self.tankProfiles[className] = profile
  return true
end

function RUI:GetTankProfile(className)
  className = self:NormalizeClassName(className or self:GetDetectedClass())
  return self.tankProfiles[className]
end

function RUI:GetTankHUDDefinitions(className, row)
  local definitions = self:GetHUDSpellDefinitions(className, row) or {}
  table.sort(definitions, function(left, right)
    -- Explicit class-data order is authoritative. The shared slot order is only
    -- a fallback for future records that do not define an order themselves.
    local leftSlot = tonumber(left.tankOrder) or tonumber(left.order) or DEFAULT_SLOT_ORDER[left.tankSlot or left.category] or 999
    local rightSlot = tonumber(right.tankOrder) or tonumber(right.order) or DEFAULT_SLOT_ORDER[right.tankSlot or right.category] or 999
    if leftSlot ~= rightSlot then return leftSlot < rightSlot end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return definitions
end

local function UnitHasDispelType(unit, wanted)
  if not UnitExists or not UnitExists(unit) or not UnitDebuff then return false end
  for index = 1, 40 do
    local name, _, _, _, debuffType = UnitDebuff(unit, index)
    if not name then break end
    if debuffType and string.upper(tostring(debuffType)) == wanted then return true end
  end
  return false
end

function RUI:HasDispellableMagicDebuff()
  if UnitHasDispelType("player", "MAGIC") then return true end
  for index = 1, 4 do
    if UnitHasDispelType("party" .. tostring(index), "MAGIC") then return true end
  end
  return false
end

function RUI:TargetHasInterruptibleCast()
  if not UnitExists or not UnitExists("target") then return false end
  if UnitCastingInfo then
    local name, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
    if name then return not notInterruptible end
  end
  if UnitChannelInfo then
    local name, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
    if name then return not notInterruptible end
  end
  return false
end

function RUI:ApplyTankUtilityHighlight(icon, definition)
  if not icon or type(definition) ~= "table" then return false end
  local category = string.lower(tostring(definition.category or definition.tankSlot or ""))
  local relevant = false
  local color

  if category == "dispel" then
    relevant = self:HasDispellableMagicDebuff()
    color = {0.15, 0.70, 1.00, 1}
  elseif category == "interrupt" then
    relevant = self:TargetHasInterruptibleCast()
    color = {1.00, 0.28, 0.08, 1}
  end

  if relevant and self.HUDWidgets and self.HUDWidgets.SetBorder then
    local alpha = 0.55 + 0.45 * math.abs(math.sin(GetTime() * 7))
    self.HUDWidgets:SetBorder(icon, color, alpha)
    return true
  end
  return false
end

function RUI:GetTankMechanicLayout()
  local layout = self.layout and self.layout.tankFramework or nil
  return layout or {
    build = {x=-105, y=-96},
    core = {x=105, y=-96},
    state = {x=-167, y=-96},
  }
end

RUI._tankFrameworkLoaded = true
