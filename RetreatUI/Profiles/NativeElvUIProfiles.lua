local RUI = RetreatUI
if not RUI then return end

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
  return result
end

local BASE = Copy(RUI.ElvUIProfile or {})

local function Ensure(profile, ...)
  local current = profile
  local keys = {...}
  for i = 1, #keys do
    local key = keys[i]
    current[key] = type(current[key]) == "table" and current[key] or {}
    current = current[key]
  end
  return current
end

local function Mover(profile, key, value)
  profile.movers = profile.movers or {}
  profile.movers[key] = value
end

local function Unit(profile, key)
  return Ensure(profile, "unitframe", "units", key)
end

local function Bar(profile, key)
  return Ensure(profile, "actionbar", key)
end

local function Common(profile)
  profile.nameplates = profile.nameplates or {}
  profile.nameplates.enable = false
  local general = Ensure(profile, "general")
  general.autoScale = nil
  general.customUIScale = nil
  general.uiScale = nil
  return profile
end

local function BuildFocus()
  local p = Common(Copy(BASE))
  local general = Ensure(p, "general")
  general.fontSize = 11
  general.minimap = general.minimap or {}
  general.minimap.size = 198
  general.totems = general.totems or {}
  general.totems.size = 34
  general.totems.spacing = 2

  local chat = Ensure(p, "chat")
  chat.panelWidth = 350
  chat.panelHeight = 300
  chat.fontSize = 11
  chat.tabFontSize = 11

  local uf = Ensure(p, "unitframe")
  uf.fontSize = 14
  uf.colors = uf.colors or {}
  uf.colors.healthclass = false
  uf.colors.health = {r = 0.115, g = 0.09, b = 0.085}
  uf.colors.health_backdrop = {r = 0.018, g = 0.012, b = 0.012}

  local player = Unit(p, "player")
  player.width, player.height = 252, 44
  if player.castbar then player.castbar.width = 350 end
  local target = Unit(p, "target")
  target.width, target.height = 252, 44
  if target.castbar then target.castbar.width = 252 end
  local party = Unit(p, "party")
  party.width, party.height = 184, 36
  party.horizontalSpacing = 2
  local boss = Unit(p, "boss")
  boss.width, boss.height = 184, 38
  if boss.castbar then boss.castbar.width = 184 end
  local focus = Unit(p, "focus")
  focus.width, focus.height = 170, 28
  if focus.castbar then focus.castbar.width = 170 end
  local tot = Unit(p, "targettarget")
  tot.width, tot.height = 112, 22

  Bar(p, "bar1").buttonsize = 30
  Bar(p, "bar2").buttonsize = 26
  local bar3 = Bar(p, "bar3")
  bar3.buttonsize = 24
  bar3.buttons = 12
  bar3.buttonsPerRow = 12

  Mover(p, "ElvUF_PlayerMover", "BOTTOM,ElvUIParent,BOTTOM,-292,338")
  Mover(p, "ElvUF_TargetMover", "BOTTOM,ElvUIParent,BOTTOM,292,338")
  Mover(p, "ElvUF_PlayerCastbarMover", "BOTTOM,ElvUIParent,BOTTOM,0,272")
  Mover(p, "ElvUF_TargetCastbarMover", "BOTTOM,ElvUIParent,BOTTOM,292,307")
  Mover(p, "ElvUF_PartyMover", "TOPLEFT,ElvUIParent,BOTTOMLEFT,300,650")
  Mover(p, "ElvUF_BossMover", "RIGHT,ElvUIParent,RIGHT,-245,58")
  Mover(p, "ElvUF_FocusMover", "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-520,210")
  Mover(p, "ElvAB_1", "BOTTOM,ElvUIParent,BOTTOM,0,82")
  Mover(p, "ElvAB_2", "BOTTOM,ElvUIParent,BOTTOM,0,50")
  Mover(p, "ElvAB_3", "BOTTOM,ElvUIParent,BOTTOM,0,22")
  Mover(p, "MinimapMover", "TOPRIGHT,ElvUIParent,TOPRIGHT,-5,-5")
  Mover(p, "WatchFrameMover", "TOPRIGHT,ElvUIParent,TOPRIGHT,-248,-226")

  p._retreatStyle = "focus"
  return p
end

local function BuildEdge()
  local p = Common(Copy(BASE))
  local general = Ensure(p, "general")
  general.fontSize = 12
  general.minimap = general.minimap or {}
  general.minimap.size = 226
  general.totems = general.totems or {}
  general.totems.size = 40
  general.totems.spacing = 4

  local chat = Ensure(p, "chat")
  chat.panelWidth = 410
  chat.panelHeight = 326
  chat.fontSize = 12
  chat.tabFontSize = 12

  local bags = Ensure(p, "bags")
  bags.bagSize = 46
  bags.bankSize = 46
  bags.bagWidth = 510
  bags.bankWidth = 510

  local uf = Ensure(p, "unitframe")
  uf.fontSize = 16
  uf.colors = uf.colors or {}
  uf.colors.healthclass = true
  uf.colors.health_backdrop = {r = 0.025, g = 0.025, b = 0.025}

  local player = Unit(p, "player")
  player.width, player.height = 322, 56
  if player.castbar then player.castbar.width = 322 end
  if player.name then player.name.fontSize = 12 end
  local target = Unit(p, "target")
  target.width, target.height = 322, 56
  if target.castbar then target.castbar.width = 322 end
  if target.name then target.name.fontSize = 12 end
  local party = Unit(p, "party")
  party.width, party.height = 230, 46
  party.horizontalSpacing = 5
  local boss = Unit(p, "boss")
  boss.width, boss.height = 224, 46
  if boss.castbar then boss.castbar.width = 224 end
  local focus = Unit(p, "focus")
  focus.width, focus.height = 208, 34
  if focus.castbar then focus.castbar.width = 208 end
  local tot = Unit(p, "targettarget")
  tot.width, tot.height = 150, 28
  if tot.name then tot.name.fontSize = 11 end
  local raid = Unit(p, "raid")
  raid.width, raid.height = 84, 42
  local raid40 = Unit(p, "raid40")
  raid40.width, raid40.height = 78, 36

  local bar1 = Bar(p, "bar1")
  bar1.buttonsize = 34
  local bar2 = Bar(p, "bar2")
  bar2.buttonsize = 30
  local bar3 = Bar(p, "bar3")
  bar3.buttonsize = 28
  bar3.buttons = 12
  bar3.buttonsPerRow = 12

  Mover(p, "ElvUF_PlayerMover", "BOTTOM,ElvUIParent,BOTTOM,-360,372")
  Mover(p, "ElvUF_TargetMover", "BOTTOM,ElvUIParent,BOTTOM,360,372")
  Mover(p, "ElvUF_PlayerCastbarMover", "BOTTOM,ElvUIParent,BOTTOM,-360,327")
  Mover(p, "ElvUF_TargetCastbarMover", "BOTTOM,ElvUIParent,BOTTOM,360,327")
  Mover(p, "ElvUF_TargetTargetMover", "TOPLEFT,ElvUF_TargetMover,TOPRIGHT,12,0")
  Mover(p, "ElvUF_PartyMover", "TOPLEFT,ElvUIParent,BOTTOMLEFT,220,705")
  Mover(p, "ElvUF_RaidMover", "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,24,350")
  Mover(p, "ElvUF_Raid40Mover", "TOPLEFT,ElvUIParent,BOTTOMLEFT,24,620")
  Mover(p, "ElvUF_BossMover", "RIGHT,ElvUIParent,RIGHT,-282,92")
  Mover(p, "ElvUF_FocusMover", "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-500,260")
  Mover(p, "ElvAB_1", "BOTTOM,ElvUIParent,BOTTOM,0,108")
  Mover(p, "ElvAB_2", "BOTTOM,ElvUIParent,BOTTOM,0,70")
  Mover(p, "ElvAB_3", "BOTTOM,ElvUIParent,BOTTOM,0,34")
  Mover(p, "MinimapMover", "TOPRIGHT,ElvUIParent,TOPRIGHT,-12,-12")
  Mover(p, "WatchFrameMover", "TOPRIGHT,ElvUIParent,TOPRIGHT,-292,-250")
  Mover(p, "LootFrameMover", "TOPLEFT,ElvUIParent,TOPLEFT,470,-210")

  p._retreatStyle = "edge"
  return p
end

RUI.NativeElvUIProfiles = {
  focus = BuildFocus(),
  edge = BuildEdge(),
}

function RUI:GetNativeElvUIProfile(styleKey)
  local profile = self.NativeElvUIProfiles and self.NativeElvUIProfiles[styleKey]
  return profile and Copy(profile) or nil
end

RUI._nativeElvUIProfilesLoaded = true
RUI.nativeElvUIProfilesSchema = 1
