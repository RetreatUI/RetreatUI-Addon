RetreatUI = {HUDWidgets={}}
local RUI = RetreatUI

local function NewFrame(parent)
  local frame = {parent=parent, shown=true, points={}}
  function frame:GetParent() return self.parent end
  function frame:IsShown() return self.shown end
  function frame:Show() self.shown=true end
  function frame:Hide() self.shown=false end
  function frame:ClearAllPoints() self.points={} end
  function frame:SetPoint(point, relativeTo, relativePoint, x, y)
    self.points[1] = {point, relativeTo, relativePoint, x or 0, y or 0}
  end
  function frame:GetPoint()
    local p=self.points[1]
    if not p then return nil end
    return p[1],p[2],p[3],p[4],p[5]
  end
  return frame
end

function RUI.HUDWidgets:BuildSpellRow(row, definitions, size, spacing)
  row.icons = row.icons or {}
  local count=#(definitions or {})
  local total=count>0 and (count*size+(count-1)*spacing) or 0
  for i, definition in ipairs(definitions or {}) do
    local icon=row.icons[i] or NewFrame(row)
    row.icons[i]=icon
    icon.definition=definition
    icon:Show()
    icon:ClearAllPoints()
    icon:SetPoint("CENTER",row,"CENTER",-total/2+size/2+(i-1)*(size+spacing),0)
  end
  for i=count+1,#row.icons do row.icons[i]:Hide() end
end

dofile("RetreatUI_Classes/MainBarWrap.lua")

local input={}
for i=1,11 do input[i]={name="Spell "..i} end
local first, overflow=RUI:SplitMainBarDefinitions(input,9)
assert(#first==9 and #overflow==2,"split must be 9 + rest")
assert(first[9].name=="Spell 9" and overflow[1].name=="Spell 10","split order changed")

local root=NewFrame(nil)
local core=NewFrame(root)
local utility=NewFrame(root)
core:SetPoint("CENTER",nil,"CENTER",0,-183)
utility:SetPoint("CENTER",nil,"CENTER",0,-224)

RUI.HUDWidgets:BuildSpellRow(core,input,38,1,function() return true end,function() return nil end)
RUI.HUDWidgets:BuildSpellRow(utility,{{name="Wall"},{name="Kick"},{name="Dash"}},32,1,function() return true end,function() return nil end)

assert(core.__ruiMainBarFirstLineCount==9,"main first line must contain nine")
assert(core.__ruiMainBarOverflowCount==2,"main overflow must contain the rest")
for i=1,9 do
  assert(core.icons[i]:IsShown(),"first nine main icons must be shown")
end
assert(not core.icons[10] or not core.icons[10]:IsShown(),"main must not render a second visual row")

local expected={"Spell 10","Spell 11","Wall","Kick","Dash"}
for i,name in ipairs(expected) do
  assert(utility.icons[i] and utility.icons[i]:IsShown(),"missing merged utility icon "..name)
  assert(utility.icons[i].definition.name==name,"merged utility order changed at "..i)
end
assert(utility.__ruiMergedMainOverflowCount==2,"utility must record two merged main icons")
local _,_,_,_,utilityY=utility:GetPoint()
assert(utilityY==-224,"utility row must stay at its normal anchor")

local nine={}
for i=1,9 do nine[i]=input[i] end
RUI.HUDWidgets:BuildSpellRow(core,nine,38,1,function() return true end,function() return nil end)
RUI.HUDWidgets:BuildSpellRow(utility,{{name="Wall"},{name="Kick"}},32,1,function() return true end,function() return nil end)
assert(utility.__ruiMergedMainOverflowCount==0,"overflow must clear when main returns to nine")
assert(utility.icons[1].definition.name=="Wall" and utility.icons[2].definition.name=="Kick",
  "utility must return to defensive and utility-only entries")
assert(not utility.icons[3]:IsShown(),"stale merged overflow icon must be hidden")

print("RetreatUI main overflow-to-utility tests passed")
