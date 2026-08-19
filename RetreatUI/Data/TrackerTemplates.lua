local RUI = RetreatUI
if not RUI then return end

RUI.trackerTemplateVersion = 1
RUI.trackerTemplates = {
  cooldown = {name="Cooldown", engine="WeakAuras", defaults={unit="player", iconSize=36}},
  charges = {name="Charges", engine="WeakAuras", defaults={unit="player", iconSize=36, showStacks=true}},
  buff = {name="Buff", engine="WeakAuras", defaults={unit="player", iconSize=36, showDuration=true}},
  buff_stacks = {name="Buff + Stacks", engine="WeakAuras", defaults={unit="player", iconSize=36, showDuration=true, showStacks=true}},
  proc = {name="Proc", engine="WeakAuras", defaults={unit="player", iconSize=36, showDuration=true}},
  proc_stacks = {name="Proc + Stacks", engine="WeakAuras", defaults={unit="player", iconSize=36, showDuration=true, showStacks=true}},
  debuff = {name="Target Debuff", engine="WeakAuras", defaults={unit="target", iconSize=36, showDuration=true, ownOnly=true}},
  cooldown_aura = {name="Cooldown + Active Aura", engine="WeakAuras", defaults={unit="player", iconSize=36, showDuration=true}},
  resource = {name="Resource", engine="WeakAuras", defaults={unit="player", display="bar", width=180, height=14}},
  summon = {name="Summon", engine="WeakAuras", defaults={unit="player", iconSize=36}},
}

function RUI:GetTrackerTemplate(templateID)
  return type(templateID) == "string" and self.trackerTemplates[templateID] or nil
end

function RUI:GetTrackerTemplates()
  local result = {}
  for id, template in pairs(self.trackerTemplates) do
    result[#result + 1] = {id=id, name=template.name, engine=template.engine, defaults=template.defaults}
  end
  table.sort(result, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return result
end
