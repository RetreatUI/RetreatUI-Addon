local RUI = RetreatUI
if not RUI then return end

local P = RUI._profilePayloadParts or {}

local function Exact(value, length, prefix, suffix)
  if type(value) ~= "string" or #value ~= length then return nil end
  if prefix and string.sub(value, 1, #prefix) ~= prefix then return nil end
  if suffix and string.sub(value, -#suffix) ~= suffix then return nil end
  return value
end

local edge1080 = {
  profile = Exact(P.e_e1080, 7620, "!E1!", "72R(3WpRO)V)"),
  private = Exact(P.e_private, 164, "!E1!", "YlQTnLJ3kU1)"),
}

-- The original Edge 1440 wrapper in beta.48 was syntactically broken. beta.50
-- does not load it. Until it is regenerated cleanly from the source ZIP, the
-- valid original Edge 1080 transmission is used on 1440 displays instead of
-- falling back to the generic native profile.
RUI.ReferenceElvUIProfiles = {
  focus = {
    ["1440p"] = { profile = Exact(P.f_e1440, 8004, "!E2!", "D09PT7b+Dw==") },
    ["1080p"] = { profile = Exact(P.f_e1080, 7908, "!E2!", "djw6OTvZ+l8=") },
  },
  edge = {
    ["1440p"] = edge1080,
    ["1080p"] = edge1080,
  },
}

RUI._beta50ReferenceProfileLoader = true
RUI.beta50ReferenceProfileSchema = 3
