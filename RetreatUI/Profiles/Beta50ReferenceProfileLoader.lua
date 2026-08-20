local RUI = RetreatUI
if not RUI then return end

local P = RUI._profilePayloadParts or {}

local function Exact(value, length, prefix, suffix)
  if type(value) ~= "string" or #value ~= length then return nil end
  if prefix and string.sub(value, 1, #prefix) ~= prefix then return nil end
  if suffix and string.sub(value, -#suffix) ~= suffix then return nil end
  return value
end

-- Only syntactically validated data chunks are loaded by beta.50. The broken
-- Edge 1440 chunk from beta.48 is deliberately excluded from the TOC, so this
-- resolution uses the native CoA fallback instead of risking a parse failure.
RUI.ReferenceElvUIProfiles = {
  focus = {
    ["1440p"] = { profile = Exact(P.f_e1440, 8004, "!E2!", "D09PT7b+Dw==") },
    ["1080p"] = { profile = Exact(P.f_e1080, 7908, "!E2!", "djw6OTvZ+l8=") },
  },
  edge = {
    ["1440p"] = nil,
    ["1080p"] = {
      profile = Exact(P.e_e1080, 7620, "!E1!", "72R(3WpRO)V)"),
      private = Exact(P.e_private, 164, "!E1!", "YlQTnLJ3kU1)"),
    },
  },
}

RUI._beta50ReferenceProfileLoader = true
RUI.beta50ReferenceProfileSchema = 2
