local RUI = RetreatUITBC
if not RUI then return end

local Profiles = {}
RUI:RegisterModule("profiles", Profiles)

local function Merge(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = type(target[key]) == "table" and target[key] or {}
      Merge(target[key], value)
    else
      target[key] = value
    end
  end
end

local ELVUI_PROFILE = {
  general = {
    autoAcceptInvite = false,
    stickyFrames = false,
    valuecolor = { r = 0.85, g = 0.56, b = 0.20 },
    backdropcolor = { r = 0.035, g = 0.045, b = 0.055 },
    backdropfadecolor = { r = 0.02, g = 0.025, b = 0.03, a = 0.88 },
  },
  unitframe = {
    smoothbars = true,
    colors = {
      healthclass = false,
      customhealthbackdrop = true,
      health = { r = 0.10, g = 0.62, b = 0.22 },
      health_backdrop = { r = 0.025, g = 0.025, b = 0.025 },
      power = { MANA = { r = 0.08, g = 0.28, b = 0.72 }, RAGE = { r = 0.72, g = 0.08, b = 0.06 }, ENERGY = { r = 0.82, g = 0.68, b = 0.05 } },
    },
    units = {
      player = {
        width = 260,
        height = 42,
        health = { text_format = "[health:current]", position = "RIGHT" },
        power = { enable = true, height = 14, text_format = "[power:current] / [power:max]" },
        name = { text_format = "[name:medium]", position = "LEFT" },
      },
      target = {
        width = 260,
        height = 42,
        health = { text_format = "[health:current]", position = "LEFT" },
        power = { enable = true, height = 14, text_format = "[power:current] / [power:max]" },
        name = { text_format = "[name:medium]", position = "RIGHT" },
      },
      party = {
        enable = true,
        width = 190,
        height = 34,
        health = { text_format = "[health:current-percent]", position = "RIGHT" },
        power = { enable = true, height = 5, text_format = "" },
        name = { text_format = "[name:short]", position = "LEFT" },
      },
    },
  },
}

local DETAILS_PROFILE = {
  skin = "ElvUI",
  row_height = 18,
  row_show_animation = { anim = "Fade", options = {} },
  bars_sort_direction = 1,
  toolbar_icon_file = "Interface\\AddOns\\Details\\images\\toolbar_icons",
  window_scale = 1,
  desaturated_menu = false,
  hide_in_combat_alpha = 0,
  bg_r = 0.02,
  bg_g = 0.025,
  bg_b = 0.03,
  bg_alpha = 0.88,
}

function Profiles:ApplyElvUI()
  local E = unpack and unpack(ElvUI or {})
  if not E or not E.db then return false, "ElvUI is not loaded" end
  Merge(E.db, ELVUI_PROFILE)
  if E.UpdateAll then E:UpdateAll(true) end
  return true
end

function Profiles:ApplyDetails()
  if not Details or type(Details.GetCurrentProfile) ~= "function" then
    return false, "Details is not loaded"
  end
  local profile = Details:GetCurrentProfile()
  if type(profile) ~= "table" then return false, "Details profile unavailable" end
  Merge(profile, DETAILS_PROFILE)
  if Details.RefreshMainWindow then Details:RefreshMainWindow(-1, true) end
  return true
end

function Profiles:ApplyPlater()
  if not Plater then return false, "Plater is not loaded" end
  if type(RUI.profilePayloads.plater) ~= "string" or RUI.profilePayloads.plater == "" then
    return false, "Plater payload has not been embedded yet"
  end
  if type(Plater.ImportProfile) == "function" then
    local ok, err = pcall(Plater.ImportProfile, RUI.profilePayloads.plater, true, true)
    return ok, err
  end
  return false, "This Plater build does not expose ImportProfile"
end

function Profiles:InstallSelected()
  local db = RUI:EnsureDB()
  local results = {}
  if db.selected.elvui then results.elvui = { self:ApplyElvUI() } end
  if db.selected.plater then results.plater = { self:ApplyPlater() } end
  if db.selected.details then results.details = { self:ApplyDetails() } end
  return results
end
