local RUI = RetreatUI
if not RUI then return end

-- The old beta.20 installer bundled a fixed Details profile string using a
-- D!ProfileV2 assumption. The exact Ascension Details build audited for
-- beta.28 uses its own native print export/import string without that prefix.
--
-- Do not let the legacy installer invoke the incompatible fixed payload. The
-- new AscensionProfileAdapters layer owns native Details profile capture/import.

function RUI:InstallDetailsProfile()
  return true, "Fixed Details profile installation is retired. Details profiles are now managed through the native RetreatUI profile adapter."
end

function RUI:ValidateDetailsProfile()
  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then
    return false, "Details is not loaded"
  end
  if type(details.ExportCurrentProfile) ~= "function" or type(details.ImportProfile) ~= "function" then
    return false, "The audited Ascension Details native profile API is unavailable"
  end
  return true, "Details native profile API is ready"
end

RUI._legacyFixedDetailsProfileRetired = true
