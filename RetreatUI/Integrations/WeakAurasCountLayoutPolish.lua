local RUI = RetreatUI
if not RUI or RUI._weakAurasCountLayoutPolish then return end

-- Presentation-only wrapper around the live-verified native WeakAuras generator.
-- Trigger semantics stay untouched here.
--
-- WeakAuras owns cooldown/duration presentation. RetreatUI only positions and
-- styles the native stack/charge count so it stays readable and unobtrusive.

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
      subRegion.anchor_point = "INNER_BOTTOMRIGHT"
      subRegion.text_selfPoint = "AUTO"
      subRegion.text_anchorXOffset = -2
      subRegion.text_anchorYOffset = 2
      subRegion.text_justify = "RIGHT"
      subRegion.text_fontSize = 10
      subRegion.text_fontType = "OUTLINE"
      subRegion.text_color = {1, 1, 1, 1}
    end
  end
end

function RUI:BuildNativeTrackerImport(entry)
  local envelope, reason, auraID, mode, isUpdate, uid = BaseBuildNativeTrackerImport(self, entry)
  if envelope then PolishCountText(envelope) end
  return envelope, reason, auraID, mode, isUpdate, uid
end

RUI._weakAurasCountLayoutPolish = true
