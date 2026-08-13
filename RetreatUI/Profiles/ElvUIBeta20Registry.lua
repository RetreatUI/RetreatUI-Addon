local RUI = RetreatUI
if not RUI then return end

-- beta.20 canonical registry names consumed by the CoA ElvUI importer.
-- Keep the serialized profile payloads untouched; only normalize the in-memory
-- keys once after the payload file loads.
if type(RUI.Beta20ElvUIExports) ~= "table" and type(RUI.NaowhElvUIExports) == "table" then
  RUI.Beta20ElvUIExports = RUI.NaowhElvUIExports
end
if type(RUI.Beta20ElvUIScales) ~= "table" and type(RUI.NaowhElvUIScales) == "table" then
  RUI.Beta20ElvUIScales = RUI.NaowhElvUIScales
end

RUI.NaowhElvUIExports = nil
RUI.NaowhElvUIScales = nil
RUI._beta20ElvUIRegistryReady = type(RUI.Beta20ElvUIExports) == "table"
