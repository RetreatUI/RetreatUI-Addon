RetreatUI = {HUDWidgets={}}
local RUI = RetreatUI

local function NewFrame(parent)
  local frame = {parent=parent, shown=true, points={}, scale=1}
  function frame:GetParent() return self.parent end
  function frame:IsShown() return self.shown end
  function frame:Show() self.shown=true end
  function frame:Hide() self.shown=false end
  function frame:GetScale() return self.scale end
  function frame:SetScale(value) self.scale=value end
  function frame:ClearAllPoints() self.points={} end
  function frame:SetPoint(point, relativeTo, relativePoint, x, y)
    self.points[1] = {point, relativeTo, relativePoint, x or 0, y or 0}
  end
  function frame:GetPoint()
    local p=self.points[1]
    if not p then return nil end
    return p[1],p[2],p[3],p[4],p[5]
  end
  function frame:SetScript(name, fn) self[name]=fn end
  return frame
end

function CreateFrame(_, _, parent) return NewFrame(parent) end

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
RUI.HUDWidgets:BuildSpellRow(utility,{{name="Kick"},{name="Dash"}},32,1,function() return true end,function() return nil end)

local _,_,_,_,firstY=core.icons[1]:GetPoint()
local _,_,_,_,ninthY=core.icons[9]:GetPoint()
local _,_,_,_,tenthY=core.icons[10]:GetPoint()
local _,_,_,_,eleventhY=core.icons[11]:GetPoint()
assert(firstY==0 and ninthY==0,"first nine icons must stay on line 1")
assert(tenthY==-39 and eleventhY==-39,"remaining icons must move to line 2")

local _,_,_,_,utilityY=utility:GetPoint()
assert(utilityY==-263,"utility row must move below wrapped main row")

local nine={}
for i=1,9 do nine[i]=input[i] end
RUI.HUDWidgets:BuildSpellRow(core,nine,38,1,function() return true end,function() return nil end)
local _,_,_,_,restoredY=utility:GetPoint()
assert(restoredY==-224,"utility row must return when main no longer wraps")

print("RetreatUI main bar wrap tests passed")
