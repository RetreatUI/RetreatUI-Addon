local RUI = RetreatUI
if not RUI or RUI._weakAurasCountLayoutPolish then return end

-- Presentation-only wrapper around the live-verified native WeakAuras generator.
-- Trigger semantics stay untouched here.
--
-- Charge/stack count belongs in the lower-right corner. Charge trackers never
-- use OmniCC / cooldown-frame countdown numbers; when charges reach zero, a
-- small native WeakAuras %p text is shown in the center instead.

local BaseBuildNativeTrackerImport = RUI.BuildNativeTrackerImport
if type(BaseBuildNativeTrackerImport) ~= "function" then return end

local function HasType(entry, wanted)
  if type(entry) ~= "table" then return false end
  if entry.trackingType == wanted then return true end
  if type(entry.trackingTypes) == "table" then
    for _, value in ipairs(entry.trackingTypes) do
      if value == wanted then return true end
    end
  end
  return false
end

local function FindCountSubRegion(data)
  local subRegions = type(data) == "table" and data.subRegions or nil
  if type(subRegions) ~= "table" then return nil, nil end
  for index, subRegion in ipairs(subRegions) do
    if type(subRegion) == "table"
      and subRegion.type == "subtext"
      and subRegion.text_text == "%s"
    then
      return index, subRegion
    end
  end
  return nil, nil
end

local function FindCooldownTriggerIndex(data)
  for index, triggerData in ipairs((data and data.triggers) or {}) do
    if type(triggerData) == "table" and type(triggerData.trigger) == "table"
      and triggerData.trigger.event == "Cooldown Progress (Spell)" then
      return index
    end
  end
  return nil
end

local function AddNativeCooldownText(data)
  data.subRegions = type(data.subRegions) == "table" and data.subRegions or {}
  local text = {
    type = "subtext",
    text_text = "%p",
    text_visible = false,
    text_color = {1, 1, 1, 1},
    text_fontSize = 12,
    text_fontType = "OUTLINE",
    text_justify = "CENTER",
    text_selfPoint = "AUTO",
    anchor_point = "CENTER",
    text_anchorXOffset = 0,
    text_anchorYOffset = 0,
  }
  data.subRegions[#data.subRegions + 1] = text
  return #data.subRegions
end

local function AddZeroChargePresentationCondition(data, triggerIndex, countIndex, timerIndex)
  if not triggerIndex then return end
  data.conditions = type(data.conditions) == "table" and data.conditions or {}

  local condition = {
    check = {
      trigger = triggerIndex,
      variable = "charges",
      op = "==",
      value = "0",
    },
    changes = {},
  }

  if countIndex then
    condition.changes[#condition.changes + 1] = {
      property = "sub." .. tostring(countIndex) .. ".text_visible",
      value = false,
    }
  end

  if timerIndex then
    condition.changes[#condition.changes + 1] = {
      property = "sub." .. tostring(timerIndex) .. ".text_visible",
      value = true,
    }
  end

  data.conditions[#data.conditions + 1] = condition
end

local function PolishPresentation(envelope, entry)
  if type(envelope) ~= "table" or type(envelope.d) ~= "table" then return end
  local data = envelope.d
  local countIndex, countText = FindCountSubRegion(data)

  if countText then
    countText.anchor_point = "INNER_BOTTOMRIGHT"
    countText.text_selfPoint = "AUTO"
    countText.text_anchorXOffset = -2
    countText.text_anchorYOffset = 2
    countText.text_justify = "RIGHT"
    countText.text_fontSize = 10
    countText.text_fontType = "OUTLINE"
    countText.text_color = {1, 1, 1, 1}
  end

  if HasType(entry, "charges") then
    local settings = type(entry.settings) == "table" and entry.settings or {}
    local showCooldownText = settings.showCooldownText ~= false

    -- Always suppress OmniCC / cooldown-frame numbers on charge icons. This is
    -- independent of charge state, so their external styling can never cover
    -- the corner count.
    data.cooldownTextDisabled = true

    local timerIndex
    if showCooldownText then
      timerIndex = AddNativeCooldownText(data)
    end

    AddZeroChargePresentationCondition(
      data,
      FindCooldownTriggerIndex(data),
      countIndex,
      timerIndex
    )
  end
end

function RUI:BuildNativeTrackerImport(entry)
  local envelope, reason, auraID, mode, isUpdate, uid = BaseBuildNativeTrackerImport(self, entry)
  if envelope then PolishPresentation(envelope, entry) end
  return envelope, reason, auraID, mode, isUpdate, uid
end

RUI._weakAurasCountLayoutPolish = true
