-- UI.lua
-- Main window. In Step 1 this is an empty frame with a title, close button and footer.
-- Tabs, cards and lists come in Step 4.

local ADDON, TM = ...

local UI = {}
TM.UI = UI

local function SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local w = TM.db.window
    w.point = point or "CENTER"
    w.relPoint = relPoint or "CENTER"
    w.x = math.floor((x or 0) + 0.5)
    w.y = math.floor((y or 0) + 0.5)
end

local function ApplyPosition(frame)
    local w = TM.db.window
    frame:ClearAllPoints()
    frame:SetPoint(w.point or "CENTER", UIParent, w.relPoint or "CENTER", w.x or 0, w.y or 0)
end

local function MakeText(parent, fontKey, size, colorKey)
    local T = TM.Theme
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(T.fonts[fontKey], size, "")
    local c = T.colors[colorKey]
    fs:SetTextColor(c.r, c.g, c.b, 1)
    return fs
end

local function Build()
    local T = TM.Theme
    local S = T.sizes
    local C = T.colors

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(S.windowWidth, S.windowHeight)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    f:SetBackdrop({
        bgFile = T.textures.solid,
        edgeFile = T.textures.solid,
        edgeSize = S.borderSize,
    })
    f:SetBackdropColor(C.windowBg.r, C.windowBg.g, C.windowBg.b, 1)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)

    local title = MakeText(f, "title", S.titleText, "text")
    title:SetPoint("TOPLEFT", S.padding, -S.padding)
    title:SetText("Tallymark")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() UI:Hide() end)

    local version = MakeText(f, "body", S.footerText, "footer")
    version:SetPoint("BOTTOMLEFT", S.padding, S.padding)
    version:SetText("Tallymark v" .. TM.VERSION)

    local author = MakeText(f, "body", S.footerText, "footer")
    author:SetPoint("BOTTOMRIGHT", -S.padding, S.padding)
    author:SetText("by Buyaka")

    ApplyPosition(f)
    f:Hide()
    return f
end

function UI:Init()
    if TM.db.window.shown then
        self:Show()
    end
end

function UI:GetFrame()
    if not self.frame then
        self.frame = Build()
    end
    return self.frame
end

function UI:Show()
    self:GetFrame():Show()
    TM.db.window.shown = true
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
    TM.db.window.shown = false
end

function UI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:ResetPosition()
    local w = TM.db.window
    w.point, w.relPoint, w.x, w.y = "CENTER", "CENTER", 0, 0
    if self.frame then
        ApplyPosition(self.frame)
    end
end
