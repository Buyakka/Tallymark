-- Mini.lua
-- The small window: a compact card that can stay on screen all the time.
-- Turned on with Settings > Small window. When it is on, /tally, /tm and the
-- minimap left-click show or hide this card instead of the big window.
-- Click the card for the full window, right-click for settings.
--
-- Layout, top to bottom:
--   header:  logo, TALLYMARK, and "IN COMBAT 0:42" during a fight
--   tiles:   shots this fight (or last fight) and ammo left (red when low)
--   shots:   one row per shot picked in settings, with Fight and Total columns
--   total:   all shots, this fight and all time
--   footer:  steps and distance today
-- Non-hunters get steps and distance in the tiles, and nothing else.
--
-- It has its own position, size, opacity and hide-in-combat setting, and
-- follows the lock setting of the big window.

local ADDON, TM = ...

local Mini = {}
TM.Mini = Mini

local function T() return TM.Theme end
local W = TM.W

local WIDTH    = 280
local PAD      = 12
local GAP      = 8
local TILE_H   = 58
local ROW_H    = 20
local COL_W    = 58     -- width of the Fight and Total columns
local COL_GAP  = 6
local NAME_W   = WIDTH - PAD * 2 - COL_W * 2 - COL_GAP * 2

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

local function Commas(n) return TM.Commas(n) end

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

-- A card with a big number on top and a muted label under it.
local function Tile(f, index)
    local S = T().sizes
    local width = (WIDTH - PAD * 2 - GAP) / 2
    local card = W.Box(f, "cardBg", "cardBg", T().radius.card)
    card:SetSize(width, TILE_H)
    card:SetPoint("TOPLEFT", PAD + (index - 1) * (width + GAP), -(PAD + 26))

    card.value = W.Text(card, "display", 22, "text")
    card.value:SetPoint("TOPLEFT", 10, -9)
    card.value:SetPoint("RIGHT", -8, 0)

    card.label = W.Text(card, "body", S.cardLabel, "muted")
    card.label:SetPoint("BOTTOMLEFT", 10, 9)
    card.label:SetPoint("RIGHT", -8, 0)
    return card
end

-- A table line: name on the left, two number columns on the right.
local function Line(f, font, color)
    local S = T().sizes
    local l = {}
    l.name = W.Text(f, font, S.bodyText, color)
    l.name:SetWidth(NAME_W)
    -- Fixed width and centered, so each number sits under the middle of its heading.
    l.fight = W.Text(f, font, S.bodyText, color, "CENTER")
    l.fight:SetWidth(COL_W)
    l.all = W.Text(f, font, S.bodyText, color, "CENTER")
    l.all:SetWidth(COL_W)
    function l:Place(y)
        self.name:ClearAllPoints()
        self.name:SetPoint("TOPLEFT", PAD, y)
        self.all:ClearAllPoints()
        self.all:SetPoint("TOPRIGHT", -PAD, y)
        self.fight:ClearAllPoints()
        self.fight:SetPoint("TOPRIGHT", -(PAD + COL_W + COL_GAP), y)
    end
    function l:SetShown(on)
        self.name:SetShown(on)
        self.fight:SetShown(on)
        self.all:SetShown(on)
    end
    return l
end

local function HLine(f)
    local d = W.Divider(f)
    d:SetPoint("LEFT", PAD, 0)
    d:SetPoint("RIGHT", -PAD, 0)
    return d
end

local function PlaceLine(d, y)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", PAD, y)
    d:SetPoint("TOPRIGHT", -PAD, y)
end

local function Build()
    local S = T().sizes
    local f = W.Box(UIParent, "windowBg", "border", T().radius.window)
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
            TM.Settings:Open("mini")
        elseif button == "LeftButton" then
            TM.UI:ShowFull()
        end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Tallymark", T():RGB("accent"))
        GameTooltip:AddLine("Click: full window (Ammo, Journey, History)", T():RGB("text"))
        GameTooltip:AddLine("Right-click: settings, pick which shots show", T():RGB("text"))
        GameTooltip:AddLine("Drag: move", T():RGB("text"))
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Header
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T().textures.logo)
    logo:SetSize(18, 18)
    logo:SetPoint("TOPLEFT", PAD, -PAD + 1)
    local title = W.Text(f, "bodyBold", S.heading, "text")
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("TALLYMARK")

    f.combat = W.Text(f, "bodyBold", S.heading, "accent", "RIGHT")
    f.combat:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -PAD - 8)
    f.dot = f:CreateTexture(nil, "ARTWORK")
    f.dot:SetTexture(T().textures.circle)
    f.dot:SetVertexColor(T():RGB("accent"))
    f.dot:SetSize(S.dot, S.dot)
    f.dot:SetPoint("RIGHT", f.combat, "LEFT", -6, 0)

    -- Tiles
    f.tiles = { Tile(f, 1), Tile(f, 2) }

    -- Shot table
    f.head = Line(f, "bodyBold", "muted")
    for _, fs in ipairs({ f.head.name, f.head.fight, f.head.all }) do
        fs:SetFont(fs:GetFont(), S.cardLabel, "")
    end
    f.head.name:SetText("SHOTS")
    f.head.all:SetText("TOTAL")
    f.empty = W.Text(f, "body", S.cardLabel, "muted")
    f.empty:SetText("No shots picked. Right-click to pick some.")
    f.lines = {}
    f.line1 = HLine(f)
    f.total = Line(f, "bodyBold", "text")

    -- Footer
    f.line2 = HLine(f)
    f.steps = W.Text(f, "bodyBold", S.bodyText, "text")
    f.dist = W.Text(f, "bodyBold", S.bodyText, "text", "RIGHT")

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

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function Clock(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Shots picked in settings that the character knows or has used, most used first.
local function PickedShots(fightBy, allBy)
    local A = TM.Arrows
    local hidden = TM.db.ammo.miniHidden or {}
    local list = {}
    for i, s in ipairs(A:ShotList()) do
        if not hidden[s.en] then
            local name = s.name or s.en
            local all = allBy[name] or 0
            local fight = fightBy[name] or 0
            if all > 0 or fight > 0 or A:KnowsShot(s) then
                list[#list + 1] = { name = name, fight = fight, all = all, order = i }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.all ~= b.all then return a.all > b.all end
        return a.order < b.order
    end)
    return list
end

local function SetNumber(fs, n, live)
    fs:SetText(Commas(n))
    if n == 0 then
        W.SetColor(fs, "muted")
    else
        W.SetColor(fs, live and "accent" or "text")
    end
end

function Mini:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local J, A = TM.Journey, TM.Arrows
    local today = J:Data().today
    local hunter = A and A.enabled
    local fight = hunter and A:CurrentFight()

    -- Header
    if fight then
        f.combat:SetText("IN COMBAT · " .. Clock(GetTime() - fight.started))
        f.combat:Show()
        f.dot:Show()
    else
        f.combat:Hide()
        f.dot:Hide()
    end

    local t1, t2 = f.tiles[1], f.tiles[2]
    local y = -(PAD + 26 + TILE_H)

    if not hunter then
        t1.value:SetText(Commas(today.steps))
        t1.label:SetText("Steps today")
        t2.value:SetText(J:FormatDistance(today.yards))
        t2.label:SetText("Distance today")
        W.SetColor(t1.value, "text")
        W.SetColor(t2.value, "text")
        W.SetBoxColors(t2, "cardBg", "cardBg")
        f.head:SetShown(false)
        f.empty:Hide()
        for _, l in ipairs(f.lines) do l:SetShown(false) end
        f.line1:Hide()
        f.total:SetShown(false)
        f.line2:Hide()
        f.steps:Hide()
        f.dist:Hide()
        f:SetHeight(-y + PAD)
        return
    end

    -- Tile 1: shots this fight, or the last fight out of combat.
    local source = fight or A:LastFight()
    local fightShots = source and source.shots or 0
    t1.value:SetText(Commas(fightShots))
    W.SetColor(t1.value, fight and "accent" or "text")
    t1.label:SetText(A:AmmoWord(2) .. (fight and " this fight" or " last fight"))

    -- Tile 2: ammo left, red at or under the warning amount.
    local n, state = A:AmmoCount()
    local warnAt = TM:LowAmmoAt()
    local text, low = "0", warnAt ~= nil
    if state == "secret" then
        text, low = n, false          -- shown as is, no math on a secret
    elseif state ~= "none" then
        text, low = Commas(n), warnAt ~= nil and n <= warnAt
    end
    t2.value:SetText(text)
    t2.label:SetText(A:AmmoWord(2) .. " left")
    W.SetColor(t2.value, low and "lowAmmo" or "text")
    W.SetBoxColors(t2, "cardBg", low and "lowAmmoBorder" or "cardBg")

    -- Shot table
    y = y - 14
    f.head.fight:SetText("FIGHT")   -- this fight in combat, the last fight after it
    f.head:Place(y)
    f.head:SetShown(true)
    y = y - 18

    local list = PickedShots(source and source.byShot or {}, A:Data().byShot or {})
    for i, s in ipairs(list) do
        local l = f.lines[i]
        if not l then
            l = Line(f, "body", "text")
            f.lines[i] = l
        end
        l:Place(y)
        l:SetShown(true)
        l.name:SetText(s.name)
        SetNumber(l.fight, s.fight, fight ~= nil)
        SetNumber(l.all, s.all)
        y = y - ROW_H
    end
    for i = #list + 1, #f.lines do f.lines[i]:SetShown(false) end
    if #list == 0 then
        f.empty:ClearAllPoints()
        f.empty:SetPoint("TOPLEFT", PAD, y)
        f.empty:Show()
        y = y - ROW_H
    else
        f.empty:Hide()
    end

    -- Total: every shot, including ones not picked above.
    y = y - 4
    PlaceLine(f.line1, y)
    f.line1:Show()
    y = y - 8
    f.total:Place(y)
    f.total:SetShown(true)
    f.total.name:SetText("All " .. A:AmmoWord(2))
    f.total.fight:SetText(Commas(fightShots))
    W.SetColor(f.total.fight, fight and "accent" or "text")
    f.total.all:SetText(Commas(A:LifetimeTotal()))   -- includes shots typed in from before
    y = y - ROW_H

    -- Footer: steps and distance today
    y = y - 4
    PlaceLine(f.line2, y)
    f.line2:Show()
    y = y - 9
    f.steps:ClearAllPoints()
    f.steps:SetPoint("TOPLEFT", PAD, y)
    f.steps:SetText(Commas(today.steps) .. T():Color("muted", " steps today"))
    f.steps:Show()
    f.dist:ClearAllPoints()
    f.dist:SetPoint("TOPRIGHT", -PAD, y)
    f.dist:SetText(J:FormatDistance(today.yards))
    f.dist:Show()
    y = y - 16

    f:SetHeight(-y + PAD)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

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
