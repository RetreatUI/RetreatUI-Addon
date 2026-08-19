local RUI = RetreatUI
if not RUI or RUI._weakAurasCountLayoutPolish then return end

-- Presentation-only wrapper around the already live-verified native WeakAuras
-- generator. Trigger semantics stay untouched here.
--
-- Native stack/charge count (%s) belongs in the lower-right corner. For charge
-- abilities, the large OmniCC/countdown number is hidden while at least one
-- charge remains; it is only allowed back at zero charges, when the ability is
-- actually unavailable. This keeps 2/1 charge states clean and readable.

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

local function AddZeroChargePresentationCondition(data, triggerIndex, countIndex, showCooldownText)
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

  -- At zero charges the corner count is redundant. Hide it and, when the user
  -- has Cooldown text enabled, let OmniCC/the native cooldown number appear.
  if countIndex then
    condition.changes[#condition.changes + 1] = {
      property = "sub." .. tostring(countIndex) .. ".text_visible",
      value = false,
    }
  end
  if showCooldownText then
    condition.changes[#condition.changes + 1] = {
      property = "cooldownTextDisabled",
      value = false,
    }
  end

  data.conditions[#data.conditions + 1] = condition
end

local function PolishPresentation(envelope, entry)
  if type(envelope) ~= "table" or type(envelope.d) ~= "table" then return end
  local data = envelope.d
  local countIndex, countText = FindCountSubRegion(data)

  if countText then
    -- Compact ElvUI/Naowh-style corner count rather than a second centered value.
    countText.anchor_point = "INNER_BOTTOMRIGHT"
    countText.text_selfPoint = "AUTO"
    countText.text_anchorXOffset = -2
    countText.text_anchorYOffset = 2
    countText.text_justify = "RIGHT"
    countText.text_fontSize = 11
    countText.text_fontType = "OUTLINE"
    countText.text_color = {1, 1, 1, 1}
  end

  if HasType(entry, "charges") then
    local settings = type(entry.settings) == "table" and entry.settings or {}
    local showCooldownText = settings.showCooldownText ~= false

    -- Hide the giant recharge number while 1+ charges remain. The already
    -- verified charge state still drives the icon and the lower-right %s count.
    data.cooldownTextDisabled = true

    AddZeroChargePresentationCondition(
      data,
      FindCooldownTriggerIndex(data),
      countIndex,
      showCooldownText
    )
  end
end

function RUI:BuildNativeTrackerImport(entry)
  local envelope, reason, auraID, mode, isUpdate, uid = BaseBuildNativeTrackerImport(self, entry)
  if envelope then PolishPresentation(envelope, entry) end
  return envelope, reason, auraID, mode, isUpdate, uid
end

RUI._weakAurasCountLayoutPolish = true
