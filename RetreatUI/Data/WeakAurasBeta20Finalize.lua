local RUI = RetreatUI
if not RUI then return end
local payloads = RUI.Beta20WeakAuras
if type(payloads) ~= "table" then return end
local count = 0
for className, payload in pairs(payloads.classes or {}) do
  if type(className) == "string" and type(payload) == "string" and payload:sub(1, 6) == "!WA:2!" then
    count = count + 1
  end
end
payloads.classPayloadCount = count
payloads.generatedFor = "1.1.7-beta.20"
payloads.weakAurasVersion = "5.21.2"
RUI.NaowhCoAWeakAuras = nil
RUI._beta20StaticWeakAuraPayloadsLoaded = count == 21
  and type(payloads.general) == "string"
  and payloads.general:sub(1, 6) == "!WA:2!"
