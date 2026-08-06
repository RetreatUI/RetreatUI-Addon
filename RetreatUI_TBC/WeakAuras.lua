local RUI = RetreatUITBC
if not RUI then return end

local WeakAurasModule = {}
RUI:RegisterModule("weakauras", WeakAurasModule)

local ORDER = {
  "general",
  "druidResource",
  "druidMain",
  "druidUtility",
}

local function ImportPayload(key)
  local payload = RUI.weakAuraPayloads[key]
  if type(payload) ~= "string" or payload == "" then
    return false, key .. " payload has not been embedded yet"
  end
  if not WeakAuras or type(WeakAuras.Import) ~= "function" then
    return false, "WeakAuras is not loaded"
  end
  local ok, result = pcall(WeakAuras.Import, payload)
  return ok, result
end

function WeakAurasModule:InstallSelected()
  local db = RUI:EnsureDB()
  local class = RUI:GetPlayerClass()
  local results = {}
  if db.selected.generalWA then
    results.general = { ImportPayload("general") }
  end
  if db.selected.classWA and class == "DRUID" then
    results.druidResource = { ImportPayload("druidResource") }
    results.druidMain = { ImportPayload("druidMain") }
    results.druidUtility = { ImportPayload("druidUtility") }
  end
  return results
end

function WeakAurasModule:GetStatus()
  local status = {}
  for _, key in ipairs(ORDER) do
    status[key] = type(RUI.weakAuraPayloads[key]) == "string" and RUI.weakAuraPayloads[key] ~= ""
  end
  return status
end
