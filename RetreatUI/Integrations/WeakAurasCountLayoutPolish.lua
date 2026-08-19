local RUI = RetreatUI
if not RUI or RUI._weakAurasCountLayoutPolish then return end

-- Presentation-only wrapper around the already live-verified native WeakAuras
-- generator. Do not change trigger semantics here.
--
-- OmniCC / cooldown progress belongs in the middle of an icon. Native stack and
-- charge count (%s) belongs in the lower-right corner so the two values never
-- overlap each other.

local BaseBuildNativeTrackerImport = RUI.BuildNativeTrackerImport
if type(BaseBuildNativeTrackerImport) ~= "function" then return end

local function PolishCountText(envelope)
  if type(envelope) ~= "table" or type(envelope.d) ~= "table" then return end
  local subRegions = envelope.d.subRegions
  if type(subRegions) ~= "table" then return end

  for _, subRegion in ipairs(subRegions) do
    if type(subRegion) == "table"
      and subRegion.type == "subtext"
      and subRegion.text_text == "%s"
    then
      -- Native WeakAuras 5.21.2 SubText fields.
      subRegion.anchor_point = "INNER_BOTTOMRIGHT"
      subRegion.text_selfPoint = "AUTO"
      subRegion.text_anchorXOffset = -2
      subRegion.text_anchorYOffset = 2
      subRegion.text_justify = "RIGHT"
    end
  end
end

function RUI:BuildNativeTrackerImport(entry)
  local envelope, reason, auraID, mode, isUpdate, uid = BaseBuildNativeTrackerImport(self, entry)
  if envelope then PolishCountText(envelope) end
  return envelope, reason, auraID, mode, isUpdate, uid
end

RUI._weakAurasCountLayoutPolish = true
