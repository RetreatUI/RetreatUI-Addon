local RUI = RetreatUI
if not RUI then return end

local P = RUI._profilePayloadParts or {}

RUI.ReferenceElvUIProfiles = {
  focus = {
    ["1440p"] = P.f_e1440,
    ["1080p"] = P.f_e1080,
  },
  edge = {
    ["1440p"] = P.e_e1440,
    ["1080p"] = P.e_e1080,
  },
}

RUI._beta50ReferenceProfileLoader = true
