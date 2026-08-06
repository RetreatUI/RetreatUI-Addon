local addonName, ns = ...

RetreatUITBC = RetreatUITBC or {}
local RUI = RetreatUITBC

RUI.name = addonName
RUI.version = "0.1.0-beta.1"
RUI.modules = RUI.modules or {}
RUI.profilePayloads = RUI.profilePayloads or {}
RUI.weakAuraPayloads = RUI.weakAuraPayloads or {}

local defaults = {
  installerCompleted = false,
  selected = {
    elvui = true,
    plater = true,
    details = true,
    generalWA = true,
    classWA = true,
  },
  hud = {
    enabled = true,
    scale = 1,
    x = 0,
    y = 27,
  },
}

local function CopyDefaults(source, target)
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = type(target[key]) == "table" and target[key] or {}
      CopyDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

function RUI:EnsureDB()
  RetreatUITBCDB = RetreatUITBCDB or {}
  CopyDefaults(defaults, RetreatUITBCDB)
  self.db = RetreatUITBCDB
  return self.db
end

function RUI:IsAddonLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded(name)
  end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

function RUI:GetPlayerClass()
  local _, class = UnitClass("player")
  return class
end

function RUI:RegisterModule(key, module)
  assert(type(key) == "string" and key ~= "", "RetreatUI TBC module key is required")
  assert(type(module) == "table", "RetreatUI TBC module must be a table")
  self.modules[key] = module
end

function RUI:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd89032RetreatUI TBC:|r " .. tostring(message))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    RUI:EnsureDB()
  elseif event == "PLAYER_LOGIN" then
    RUI:EnsureDB()
    for _, module in pairs(RUI.modules) do
      if type(module.OnLogin) == "function" then
        local ok, err = pcall(module.OnLogin, module, RUI)
        if not ok then RUI:Print(err) end
      end
    end
    if not RUI.db.installerCompleted and C_Timer and C_Timer.After then
      C_Timer.After(2, function()
        if RUI.OpenInstaller then RUI:OpenInstaller() end
      end)
    end
  end
end)

SLASH_RETREATUITBC1 = "/ruitbc"
SlashCmdList.RETREATUITBC = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    RetreatUITBCDB = nil
    RUI:EnsureDB()
    RUI:Print("Settings reset. Reloading UI.")
    ReloadUI()
  elseif RUI.OpenInstaller then
    RUI:OpenInstaller()
  end
end
