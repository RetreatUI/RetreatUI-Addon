local RUI = RetreatUI
if not RUI then return end

RUI.ProfileImportPayloads = RUI.ProfileImportPayloads or {}
RUI.profilePayloadIntegrity = RUI.profilePayloadIntegrity or {}
local P = RUI._profilePayloadParts or {}

local function Exact(value, length, prefix, suffix)
  if type(value) ~= "string" or #value ~= length then return nil end
  if prefix and string.sub(value, 1, #prefix) ~= prefix then return nil end
  if suffix and string.sub(value, -#suffix) ~= suffix then return nil end
  return value
end

local elv1440 = Exact(P.f_e1440, 8004, "!E2!", "D09PT7b+Dw==")
local elv1080 = Exact(P.f_e1080, 7908, "!E2!", "djw6OTvZ+l8=")
local details = Exact(P.f_details, 12460, "D!ProfileV2-", "5R6dndPP/ws=")

RUI.profilePayloadIntegrity.focus = {
  elvui1440 = elv1440 ~= nil,
  elvui1080 = elv1080 ~= nil,
  details = details ~= nil,
}
RUI.profilePayloadIntegrity.focus.ok = elv1440 ~= nil and elv1080 ~= nil and details ~= nil

RUI.ProfileImportPayloads.focus = {
  label = "Retreat Focus",
  elvui = {
    ["1440p"] = {profile = elv1440},
    ["1080p"] = {profile = elv1080},
  },
  details = {
    ["1440p"] = details,
    ["1080p"] = details,
  },
}
