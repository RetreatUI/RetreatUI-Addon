local RUI = RetreatUI
if not RUI then return end

local ICON_SIZE = 36
local ICON_SPACING = 4
local MAIN_FIRST_LINE_MAX = 9

local function SetCooldown(cooldown, startTime, duration, enabled)
    if not cooldown then return end
    startTime = tonumber(startTime) or 0
    duration = tonumber(duration) or 0
    enabled = enabled == nil and 1 or enabled

    if duration > 0 and enabled ~= 0 then
        cooldown:Show()
        if type(cooldown.SetCooldown) == "function" then
            cooldown:SetCooldown(startTime, duration)
        elseif type(CooldownFrame_Set) == "function" then
            CooldownFrame_Set(cooldown, startTime, duration, enabled)
        end
    else
        cooldown:Hide()
    end
end

function RUI:CreateSpellIcon(parent, spellName)
    local frame = self:CreateBackdropFrame(parent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame.spellName = spellName

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame.icon)
    if type(frame.cooldown.SetDrawEdge) == "function" then
        frame.cooldown:SetDrawEdge(false)
    end

    frame.timer = frame:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(frame.timer, 11, "OUTLINE")
    frame.timer:SetPoint("CENTER")
    frame.timer:SetText("")

    frame:SetScript("OnEnter", function(selfFrame)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfFrame, "ANCHOR_RIGHT")
        if type(GameTooltip.SetSpellByID) == "function" then
            local learned = RUI:GetLearnedSpell(selfFrame.spellName)
            if learned and learned.spellID then
                GameTooltip:SetSpellByID(learned.spellID)
            else
                GameTooltip:SetText(selfFrame.spellName)
            end
        else
            GameTooltip:SetText(selfFrame.spellName)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    return frame
end

function RUI:UpdateSpellIcon(frame)
    if not frame or not frame.spellName then return end

    local learned = self:GetLearnedSpell(frame.spellName)
    if not learned then
        frame:Hide()
        return
    end

    frame.icon:SetTexture(learned.texture or self:GetSpellTextureSafe(frame.spellName))

    local startTime, duration, enabled = GetSpellCooldown(frame.spellName)
    SetCooldown(frame.cooldown, startTime, duration, enabled)

    local usable, noMana = IsUsableSpell(frame.spellName)
    if usable then
        frame.icon:SetVertexColor(1, 1, 1, 1)
    elseif noMana then
        frame.icon:SetVertexColor(0.45, 0.55, 1, 1)
    else
        frame.icon:SetVertexColor(0.45, 0.45, 0.45, 1)
    end

    frame:Show()
end

function RUI:CreateSpellRow(parent, spellNames)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(1, ICON_SIZE)
    row.icons = {}

    for _, spellName in ipairs(spellNames or {}) do
        local icon = self:CreateSpellIcon(row, spellName)
        row.icons[#row.icons + 1] = icon
    end

    return row
end

local function LayoutLine(icons, startIndex, count, yOffset)
    if count <= 0 then return end

    local width = count * ICON_SIZE + math.max(0, count - 1) * ICON_SPACING
    local firstX = -width / 2 + ICON_SIZE / 2

    for lineIndex = 1, count do
        local icon = icons[startIndex + lineIndex - 1]
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", icon:GetParent(), "CENTER", firstX + (lineIndex - 1) * (ICON_SIZE + ICON_SPACING), yOffset)
    end
end

function RUI:LayoutSpellRow(row, firstLineMaximum)
    if not row or not row.icons then return 0 end

    local visible = {}
    for _, icon in ipairs(row.icons) do
        if icon:IsShown() then
            visible[#visible + 1] = icon
        end
    end

    local maximum = tonumber(firstLineMaximum) or MAIN_FIRST_LINE_MAX
    local firstCount = math.min(#visible, maximum)
    local secondCount = math.max(0, #visible - firstCount)

    LayoutLine(visible, 1, firstCount, 0)
    LayoutLine(visible, firstCount + 1, secondCount, -(ICON_SIZE + ICON_SPACING))

    row:SetHeight(secondCount > 0 and (ICON_SIZE * 2 + ICON_SPACING) or ICON_SIZE)
    return secondCount > 0 and 2 or 1
end

function RUI:UpdateSpellRow(row, firstLineMaximum)
    if not row or not row.icons then return 0 end

    for _, icon in ipairs(row.icons) do
        self:UpdateSpellIcon(icon)
    end

    return self:LayoutSpellRow(row, firstLineMaximum)
end

function RUI:CreateResourceBar(parent, width, height)
    local holder = self:CreateBackdropFrame(parent)
    holder:SetSize(width or 300, height or 18)

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(self.theme.texture)
    bar:SetStatusBarColor(
        self.theme.energy[1],
        self.theme.energy[2],
        self.theme.energy[3],
        self.theme.energy[4] or 1
    )

    bar.value = bar:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(bar.value, 11, "OUTLINE")
    bar.value:SetPoint("CENTER")

    bar.mana = bar:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(bar.mana, 9, "OUTLINE")
    bar.mana:SetPoint("RIGHT", -5, 0)
    bar.mana:SetTextColor(
        self.theme.muted[1],
        self.theme.muted[2],
        self.theme.muted[3],
        self.theme.muted[4] or 1
    )

    holder.bar = bar
    return holder
end

RUI.constants = RUI.constants or {}
RUI.constants.iconSize = ICON_SIZE
RUI.constants.iconSpacing = ICON_SPACING
RUI.constants.mainFirstLineMax = MAIN_FIRST_LINE_MAX
