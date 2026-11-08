-- Mini.lua
-- The small window: a compact card that can stay on screen all the time.
-- Turned on with Settings > General > "Small window". When it is on, /tally,
-- /tm and the minimap left-click show or hide this card instead of the big
-- window. Click the card for the full window, right-click for settings.
-- Closing the full window comes back to the card.
-- Shows steps today, distance today, and for hunters: ammo this fight (or
-- last fight) and arrows or bullets left (gold when low).
-- It has its own position, size and opacity, and follows the lock and
-- hide-in-combat settings.

local ADDON, TM = ...

local Mini = {}
TM.Mini = Mini

local function T() return TM.Theme end
local W = TM.W

local WIDTH   = 200
local PAD     = 12
local ROW     = 26

local function SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local m = TM.db.mini
    m.point, m.relPoint = point or "RIGHT", relPoint or "RIGHT"
    m.x = math.floor((x or 0) + 0.5)
    m.y = math.floor((y or 0) + 0.5)
end

local function ApplyPosition(frame)
    local m = TM.db.mini
    frame:ClearAllPoints()
    frame:SetPoint(m.point or "RIGHT", UIParent, m.relPoint or "RIGHT", m.x or -60, m.y or 120)
end

local function Capital(s)
    return (s:gsub("^%l", string.upper))
end

-- One line: label on the left, value on the right.
local function Row(f, index)
    local S = T().sizes
    local y = -(PAD + (index - 1) * ROW)
    local label = W.Text(f, "body", S.cardLabel, "muted")
    label:SetPoint("TOPLEFT", PAD, y - 5)
    local value = W.Text(f, "display", 16, "text", "RIGHT")
    value:SetPoint("TOPRIGHT", -PAD, y - 2)
    value:SetPoint("LEFT", label, "RIGHT", 8, 0)
    return { label = label, value = value }
end

local function Build()
    local f = W.Box(UIParent, "windowBg", "border", T().radius.card)
    f:SetWidth(WIDTH)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self.dragged = true
        if not TM.db.window.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    -- Left-click: the full window (Ammo, Journey, History). Right-click: settings.
    -- A drag is not a click.
    f:SetScript("OnMouseUp", function(self, button)
        if self.dragged then
            self.dragged = false
            return
        end
        if button == "RightButton" then
            TM.Settings:Open()
        elseif button == "LeftButton" then
            TM.UI:ShowFull()
        end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Tallymark")
        GameTooltip:AddLine("Click: full window (Ammo, Journey, History)", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.rows = {}
    for i = 1, 5 do f.rows[i] = Row(f, i) end

    -- Refresh once per second while shown (combat count, steps).
    f:SetScript("OnShow", function()
        Mini:Refresh()
        if Mini.ticker then Mini.ticker:Cancel() end
        Mini.ticker = C_Timer.NewTicker(1, function() Mini:Refresh() end)
    end)
    f:SetScript("OnHide", function()
        if Mini.ticker then Mini.ticker:Cancel() end
        Mini.ticker = nil
    end)

    ApplyPosition(f)
    f:Hide()
    return f
end

local function SetRow(row, label, value, color)
    row.label:SetText(label)
    row.value:SetText(value)
    W.SetColor(row.value, color or "text")
    row.label:Show()
    row.value:Show()
end

function Mini:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local J, A = TM.Journey, TM.Arrows
    local today = J:Data().today
    local rows = f.rows
    SetRow(rows[1], "Steps today", TM.Commas(today.steps))
    SetRow(rows[2], "Distance today", J:FormatDistance(today.yards))
    local count = 2

    if A and A.enabled then
        local fight = A:CurrentFight()
        if fight then
            SetRow(rows[3], Capital(A:AmmoWord(2)) .. " this fight", TM.Commas(fight.shots), "accent")
        else
            local last = A:LastFight()
            SetRow(rows[3], Capital(A:AmmoWord(2)) .. " last fight", last and TM.Commas(last.shots) or "0")
        end

        local n, state = A:AmmoCount()
        local warnAt = TM:LowAmmoAt()
        local text, low = "0", warnAt ~= nil
        if state == "secret" then
            text, low = n, false          -- shown as is, no math on a secret
        elseif state ~= "none" then
            text, low = TM.Commas(n), warnAt ~= nil and n < warnAt
        end
        -- Every shot since install (plus any typed in from before), until a reset.
        SetRow(rows[4], Capital(A:AmmoWord(2)) .. " all time", TM.Commas(A:LifetimeTotal()))
        SetRow(rows[5], Capital(A:AmmoWord(2)) .. " left", text, low and "warning" or "text")
        count = 5
    end

    for i = count + 1, #rows do
        rows[i].label:Hide()
        rows[i].value:Hide()
    end
    f:SetHeight(PAD * 2 + count * ROW - 4)
end

function Mini:GetFrame()
    if not self.frame then
        self.frame = Build()
        self:ApplyLook()
    end
    return self.frame
end

-- Size and opacity from Settings > Small window (separate from the big window).
function Mini:ApplyLook()
    if not self.frame then return end
    local w = TM.db.mini
    self.frame:SetScale(math.max(0.7, math.min(1.3, tonumber(w.scale) or 1)))
    self.frame:SetAlpha(math.max(0.2, math.min(1, tonumber(w.opacity) or 1)))
end

function Mini:ResetPosition()
    local m, D = TM.db.mini, TM.DB_DEFAULTS.mini
    m.point, m.relPoint, m.x, m.y = D.point, D.relPoint, D.x, D.y
    if self.frame then ApplyPosition(self.frame) end
end

function Mini:Show()
    self:GetFrame():Show()
end

function Mini:Hide()
    if self.frame then self.frame:Hide() end
end

function Mini:IsShown()
    return self.frame and self.frame:IsShown() or false
end
