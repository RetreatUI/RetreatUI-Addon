local RUI = RetreatUI
if not RUI then return end
RUI.ProfileImportPayloads = RUI.ProfileImportPayloads or {}
-- Exact imported payload is filled by the beta.45 profile conversion pass.
-- Runtime safely falls back to the verified CoA profile if the imported payload is unavailable.
RUI.ProfileImportPayloads.focus = RUI.ProfileImportPayloads.focus or {
  label = "Retreat Focus",
  elvui = {},
  details = {},
}
