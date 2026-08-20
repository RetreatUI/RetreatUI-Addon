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

local elv1440 = Exact(P.e_e1440, 7396, "!E1!", "2NV5)aGCg)))")
local elv1080 = Exact(P.e_e1080, 7620, "!E1!", "72R(3WpRO)V)")
local private = Exact(P.e_private, 164, "!E1!", "YlQTnLJ3kU1)")
local details1440 = Exact(P.e_details1440, 15516, "T33", "Zx9jdg9339))")
local details1080 = Exact(P.e_details1080, 15478, "T33", "81CEurF)U)7d")

RUI.profilePayloadIntegrity.edge = {
  elvui1440 = elv1440 ~= nil,
  elvui1080 = elv1080 ~= nil,
  private = private ~= nil,
  details1440 = details1440 ~= nil,
  details1080 = details1080 ~= nil,
}
RUI.profilePayloadIntegrity.edge.ok = elv1440 ~= nil and elv1080 ~= nil and private ~= nil
  and details1440 ~= nil and details1080 ~= nil

RUI.ProfileImportPayloads.edge = {
  label = "Retreat Edge",
  elvui = {
    ["1440p"] = {profile = elv1440, private = private},
    ["1080p"] = {profile = elv1080, private = private},
  },
  details = {
    ["1440p"] = details1440,
    ["1080p"] = details1080,
  },
}
