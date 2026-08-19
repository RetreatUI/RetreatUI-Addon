local RUI = RetreatUI
if not RUI then return end

local ROWS = 12
local ROW_HEIGHT = 42

local function EnsureState(self)
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.trackerBuilder = RetreatUIDB.trackerBuilder or {}
  local db = RetreatUIDB.trackerBuilder
  db.selected = db.selected or {}
  db.filters = db.filters or {learnedOnly=true, recommendedOnly=false, includeAdvanced=false, includeUntrackable=false}
  return db
end

local function ClassSelection(self, className)
  if type(className) ~= "string" or className == "" then return {} end
  local db = EnsureState(self)
  db.selected[className] = db.selected[className] or {}
  return db.selected[className]
end

function RUI:GetSelectedTrackers(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local selected = ClassSelection(self, className)
  local result = {}
  for _, value in pairs(selected) do result[#result + 1] = value end
  table.sort(result, function(a,b) return tostring(a.name) < tostring(b.name) end)
  return result
end

function RUI:IsTrackerSelected(className, key)
  return ClassSelection(self, className)[key] ~= nil
end

function RUI:ToggleTrackerSelection(item)
  if type(item) ~= "table" or type(item.key) ~= "string" or type(item.className) ~= "string" then return false end
  local selected = ClassSelection(self, item.className)
  if selected[item.key] then
    selected[item.key] = nil
    return false
  end
  local trackingType = item.trackingTypes and item.trackingTypes[1] or nil
  selected[item.key] = {
    key=item.key, className=item.className, name=item.name, spellID=item.spellID,
    auraID=item.auraID, template=item.template or "cooldown", unit=item.defaultUnit or "player",
    trackingType=trackingType, specialization=item.specialization,
  }
  return true
end

local function Backdrop(frame)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  frame:SetBackdropColor(0.035,0.035,0.04,0.98)
  frame:SetBackdropBorderColor(0.16,0.16,0.18,1)
end

local function MakeCheck(parent, label, x, y, key)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  check:SetWidth(22); check:SetHeight(22)
  check.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  check.text:SetText(label)
  check.key = key
  return check
end

local function CreateBuilder(self)
  if self.trackerBuilderFrame then return self.trackerBuilderFrame end
  if type(CreateFrame) ~= "function" or not UIParent then return nil end

  local frame = CreateFrame("Frame", "RetreatUITrackerBuilder", UIParent)
  frame:SetWidth(690); frame:SetHeight(650)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
  frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
  Backdrop(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -18)
  title:SetText("RetreatUI  •  Tracker Builder")
  frame.title = title

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  subtitle:SetText("Choose what you want to track. RetreatUI only stores the tracker definition in this test build.")
  frame.subtitle = subtitle

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  search:SetAutoFocus(false); search:SetWidth(270); search:SetHeight(24)
  search:SetPoint("TOPLEFT", 20, -70)
  frame.search = search

  local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("BOTTOMLEFT", search, "TOPLEFT", 3, 3)
  searchLabel:SetText("Search name / ID / category")

  frame.learned = MakeCheck(frame, "Learned only", 315, -67, "learnedOnly")
  frame.recommended = MakeCheck(frame, "Recommended", 445, -67, "recommendedOnly")
  frame.advanced = MakeCheck(frame, "Advanced", 315, -94, "includeAdvanced")
  frame.allEntries = MakeCheck(frame, "All entries", 445, -94, "includeUntrackable")

  local classText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  classText:SetPoint("TOPLEFT", 20, -115)
  frame.classText = classText

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOPRIGHT", -20, -117)
  status:SetJustifyH("RIGHT")
  frame.status = status

  frame.rows = {}
  for index=1, ROWS do
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT); row:SetWidth(650)
    row:SetPoint("TOPLEFT", 20, -145 - ((index-1)*ROW_HEIGHT))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(32); row.icon:SetHeight(32); row.icon:SetPoint("LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
    row.name:SetWidth(350); row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
    row.meta:SetWidth(430); row.meta:SetJustifyH("LEFT")

    row.toggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.toggle:SetWidth(82); row.toggle:SetHeight(22); row.toggle:SetPoint("RIGHT", -3, 0)
    row.toggle:SetScript("OnClick", function()
      if row.item then
        RUI:ToggleTrackerSelection(row.item)
        RUI:RefreshTrackerBuilder()
      end
    end)
    frame.rows[index] = row
  end

  frame.prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.prev:SetWidth(90); frame.prev:SetHeight(24); frame.prev:SetPoint("BOTTOMLEFT", 20, 18); frame.prev:SetText("Previous")
  frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.next:SetWidth(90); frame.next:SetHeight(24); frame.next:SetPoint("LEFT", frame.prev, "RIGHT", 8, 0); frame.next:SetText("Next")
  frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.pageText:SetPoint("LEFT", frame.next, "RIGHT", 12, 0)

  frame.prev:SetScript("OnClick", function() frame.page = math.max(1, (frame.page or 1)-1); RUI:RefreshTrackerBuilder() end)
  frame.next:SetScript("OnClick", function() frame.page = (frame.page or 1)+1; RUI:RefreshTrackerBuilder() end)

  local function RefreshFromFilter()
    frame.page = 1
    RUI:RefreshTrackerBuilder()
  end
  search:SetScript("OnTextChanged", RefreshFromFilter)
  for _, check in ipairs({frame.learned,frame.recommended,frame.advanced,frame.allEntries}) do check:SetScript("OnClick", RefreshFromFilter) end

  frame:Hide()
  self.trackerBuilderFrame = frame
  return frame
end

function RUI:RefreshTrackerBuilder()
  local frame = self.trackerBuilderFrame
  if not frame then return end
  local db = EnsureState(self)
  local filters = db.filters
  filters.learnedOnly = frame.learned:GetChecked() and true or false
  filters.recommendedOnly = frame.recommended:GetChecked() and true or false
  filters.includeAdvanced = frame.advanced:GetChecked() and true or false
  filters.includeUntrackable = frame.allEntries:GetChecked() and true or false

  local className = self.GetDetectedClass and self:GetDetectedClass() or "Unknown"
  frame.classText:SetText("Class: |cffffffff"..tostring(className).."|r")
  local catalog = self:GetTrackerCatalog(className, {
    query=frame.search:GetText() or "", learnedOnly=filters.learnedOnly, recommendedOnly=filters.recommendedOnly,
    includeAdvanced=filters.includeAdvanced, includeUntrackable=filters.includeUntrackable,
  })
  frame.catalog = catalog

  local selectedCount = #self:GetSelectedTrackers(className)
  frame.status:SetText(tostring(#catalog).." shown  •  "..tostring(selectedCount).." selected")

  local pages = math.max(1, math.ceil(#catalog / ROWS))
  frame.page = math.min(math.max(1, frame.page or 1), pages)
  frame.pageText:SetText("Page "..frame.page.." / "..pages)
  if frame.page <= 1 then frame.prev:Disable() else frame.prev:Enable() end
  if frame.page >= pages then frame.next:Disable() else frame.next:Enable() end

  for index,row in ipairs(frame.rows) do
    local item = catalog[((frame.page-1)*ROWS)+index]
    row.item = item
    if item then
      row:Show()
      row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText(item.name or "Unknown")
      local kind = table.concat(item.trackingTypes or {}, " + ")
      if kind == "" then kind = "choose type" end
      row.meta:SetText((item.specialization or "Shared").."  •  "..(item.category or "Uncategorized").."  •  ID "..tostring(item.spellID or "?").."  •  "..kind)
      row.toggle:SetText(self:IsTrackerSelected(className, item.key) and "Remove" or "Add")
    else
      row:Hide()
    end
  end
end

function RUI:OpenTrackerBuilder()
  local frame = CreateBuilder(self)
  if not frame then return false end
  local filters = EnsureState(self).filters
  frame.learned:SetChecked(filters.learnedOnly and 1 or nil)
  frame.recommended:SetChecked(filters.recommendedOnly and 1 or nil)
  frame.advanced:SetChecked(filters.includeAdvanced and 1 or nil)
  frame.allEntries:SetChecked(filters.includeUntrackable and 1 or nil)
  frame.page = 1
  self:RefreshTrackerBuilder()
  frame:Show()
  return true
end

function RUI:ToggleTrackerBuilder()
  local frame = CreateBuilder(self)
  if not frame then return false end
  if frame:IsShown() then frame:Hide(); return false end
  return self:OpenTrackerBuilder()
end
