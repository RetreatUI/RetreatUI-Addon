local RUI = RetreatUI
if not RUI then return end

local function ResolveFont()
    if ElvUI and ElvUI[1] and ElvUI[1].media and ElvUI[1].media.normFont then
        return ElvUI[1].media.normFont
    end

    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

RUI.theme = {
    background = { 0.035, 0.039, 0.047, 0.96 },
    panel = { 0.075, 0.082, 0.094, 0.96 },
    border = { 0, 0, 0, 1 },
    accent = { 0.78, 0.60, 0.33, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    muted = { 0.58, 0.60, 0.64, 1 },
    energy = { 0.88, 0.76, 0.12, 1 },
    combo = { 0.95, 0.30, 0.18, 1 },
    texture = "Interface\\Buttons\\WHITE8X8",
}

function RUI:GetFont()
    return ResolveFont()
end

function RUI:ApplyFont(fontString, size, flags)
    if not fontString then return end
    fontString:SetFont(self:GetFont(), size or 12, flags or "OUTLINE")
end

function RUI:ApplyBackdrop(frame, background)
    if not frame or type(frame.SetBackdrop) ~= "function" then return end

    frame:SetBackdrop({
        bgFile = self.theme.texture,
        edgeFile = self.theme.texture,
        edgeSize = 1,
    })

    local color = background or self.theme.panel
    frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    frame:SetBackdropBorderColor(
        self.theme.border[1],
        self.theme.border[2],
        self.theme.border[3],
        self.theme.border[4] or 1
    )
end

function RUI:CreateBackdropFrame(parent, frameType)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame(frameType or "Frame", nil, parent, template)
    self:ApplyBackdrop(frame)
    return frame
end
