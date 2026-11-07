-- UI.lua
-- The Shadow window: header, tabs (Ammo, Journey, History), footer.
-- Numbers refresh on events, plus once per second while the window is open.
-- All colors, fonts and sizes come from Theme.lua.

local ADDON, TM = ...

local UI = {}
TM.UI = UI

local MAX_SHOT_ROWS    = 5
local MAX_HISTORY_ROWS = 10
local TRAVEL_ORDER = { "foot", "mounted", "flight", "swim", "ghost" }

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function T() return TM.Theme end

local function Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(T().fonts[font], size, "")
    fs:SetTextColor(T():RGB(color))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function SetColor(fs, color)
    fs:SetTextColor(T():RGB(color))
end

local function Solid(parent, color, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(T().textures.solid)
    tex:SetVertexColor(T():RGB(color))
    return tex
end

local function Box(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = T().textures.solid,
        edgeFile = T().textures.solid,
        edgeSize = T().sizes.borderSize,
    })
    f:SetBackdropColor(T():RGB(bg))
    f:SetBackdropBorderColor(T():RGB(border))
    return f
end

local function SetBoxColors(f, bg, border)
    f:SetBackdropColor(T():RGB(bg))
    f:SetBackdropBorderColor(T():RGB(border))
end

local function Divider(parent)
    local line = Solid(parent, "border", "BORDER")
    line:SetHeight(T().sizes.borderSize)
    return line
end

-- 12345 -> "12,345"
local function Commas(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Clock(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------------------
-- Window position and lock
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
-- Shared pieces: cards and bar rows
---------------------------------------------------------------------------

-- Three cards in a row. Returns a list of { frame, label, value }.
local function CardRow(parent, y, labels)
    local S = T().sizes
    local width = (S.windowWidth - S.padding * 2 - S.gap * 2) / 3
    local cards = {}
    for i, label in ipairs(labels) do
        local card = Box(parent, "cardBg", "border")
        card:SetSize(width, S.cardHeight)
        card:SetPoint("TOPLEFT", (i - 1) * (width + S.gap), y)

        local l = Text(card, "bodyBold", S.cardLabel, "muted")
        l:SetPoint("TOPLEFT", 10, -10)
        l:SetPoint("RIGHT", -10, 0)
        l:SetText(label)

        local v = Text(card, "display", S.cardValue, "text")
        v:SetPoint("BOTTOMLEFT", 10, 10)
        v:SetPoint("RIGHT", -10, 0)

        cards[i] = { frame = card, label = l, value = v }
    end
    return cards
end

-- A row with a name on the left, a value on the right and a bar under them.
local function BarRow(parent, y)
    local S = T().sizes
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT")
    row:SetHeight(S.rowHeight + S.barHeight + 4)

    row.name = Text(row, "body", S.bodyText, "text")
    row.name:SetPoint("TOPLEFT")
    row.name:SetPoint("RIGHT", -90, 0)

    row.value = Text(row, "body", S.bodyText, "text", "RIGHT")
    row.value:SetPoint("TOPRIGHT")

    row.track = Solid(row, "barTrack", "BACKGROUND")
    row.track:SetPoint("BOTTOMLEFT", 0, 4)
    row.track:SetPoint("BOTTOMRIGHT", 0, 4)
    row.track:SetHeight(S.barHeight)

    row.fill = Solid(row, "accent", "ARTWORK")
    row.fill:SetPoint("TOPLEFT", row.track)
    row.fill:SetPoint("BOTTOMLEFT", row.track)
    return row
end

local function SetBar(row, ratio)
    local width = row.track:GetWidth()
    if not width or width <= 0 then
        width = T().sizes.windowWidth - T().sizes.padding * 2
    end
    ratio = math.max(0, math.min(1, ratio or 0))
    if ratio <= 0 then
        row.fill:Hide()
    else
        row.fill:Show()
        row.fill:SetWidth(math.max(1, width * ratio))
    end
end

local function Heading(parent, y, text)
    local h = Text(parent, "bodyBold", T().sizes.heading, "muted")
    h:SetPoint("TOPLEFT", 0, y)
    h:SetText(text)
    return h
end

---------------------------------------------------------------------------
-- Ammo tab
---------------------------------------------------------------------------

local function BuildAmmo(page)
    local S = T().sizes
    local p = {}

    -- Combat line: teal dot + "IN COMBAT · 0:42"
    p.combat = CreateFrame("Frame", nil, page)
    p.combat:SetPoint("TOPLEFT")
    p.combat:SetSize(200, 16)
    local dot = Solid(p.combat, "accent")
    dot:SetSize(S.dot, S.dot)
    dot:SetPoint("LEFT")
    p.combatText = Text(p.combat, "bodyBold", S.heading, "accent")
    p.combatText:SetPoint("LEFT", dot, "RIGHT", 6, 0)

    p.big = Text(page, "display", S.bigNumber, "text")
    p.big:SetPoint("TOPLEFT", 0, -22)
    p.bigLabel = Text(page, "body", S.bigLabel, "muted")
    p.bigLabel:SetPoint("TOPLEFT", p.big, "BOTTOMLEFT", 0, -4)

    -- Third card label follows the ammo type: "BULLETS LEFT" or "ARROWS LEFT".
    -- It counts ammo in all bags, not only the quiver or ammo pouch.
    p.cards = CardRow(page, -124, { "DUNGEON", "LIFETIME", "AMMO LEFT" })

    Heading(page, -204, "BY SHOT · LIFETIME")
    p.rows = {}
    for i = 1, MAX_SHOT_ROWS do
        p.rows[i] = BarRow(page, -224 - (i - 1) * 34)
    end
    p.noShots = Text(page, "body", S.bodyText, "muted")
    p.noShots:SetPoint("TOPLEFT", 0, -224)
    p.noShots:SetText("No shots yet. Go fire a few!")

    -- Steps today row at the bottom
    local line = Divider(page)
    line:SetPoint("BOTTOMLEFT", 0, 32)
    line:SetPoint("BOTTOMRIGHT", 0, 32)
    local stepsLabel = Text(page, "body", S.bodyText, "muted")
    stepsLabel:SetPoint("BOTTOMLEFT", 0, 8)
    stepsLabel:SetText("Steps today")
    p.steps = Text(page, "bodyBold", S.bodyText, "text", "RIGHT")
    p.steps:SetPoint("BOTTOMRIGHT", 0, 8)

    -- Low ammo box, above the steps row
    p.low = Box(page, "warningBox", "warningBorder")
    p.low:SetPoint("BOTTOMLEFT", 0, 44)
    p.low:SetPoint("BOTTOMRIGHT", 0, 44)
    p.low:SetHeight(44)
    p.lowText = Text(p.low, "bodyBold", S.bodyText, "warning")
    p.lowText:SetPoint("LEFT", 12, 0)
    p.lowText:SetPoint("RIGHT", -12, 0)

    page.parts = p
end

local function RefreshAmmo(page)
    local p = page.parts
    local A = TM.Arrows
    local d = A:Data()
    local fight = A:CurrentFight()

    if fight then
        p.combat:Show()
        p.combatText:SetText("IN COMBAT · " .. Clock(GetTime() - fight.started))
        p.big:SetText(Commas(fight.shots))
        p.bigLabel:SetText(A:AmmoWord(fight.shots) .. " this fight")
    else
        p.combat:Hide()
        local last = A:LastFight()
        if last then
            p.big:SetText(Commas(last.shots))
            p.bigLabel:SetText(A:AmmoWord(last.shots, last.kind) .. " last fight")
        else
            p.big:SetText("0")
            p.bigLabel:SetText(A:AmmoWord(0) .. " this fight")
        end
    end

    -- Cards
    p.cards[1].value:SetText(d.dungeon and Commas(d.dungeon.shots) or "-")
    p.cards[2].value:SetText(Commas(d.lifetime.total))

    local n, state = A:AmmoCount()
    local quiver = p.cards[3]
    quiver.label:SetText(A:AmmoWord(2):upper() .. " LEFT")
    local low = false
    if state == "none" then
        quiver.value:SetText("0")
        low = true
    elseif state == "secret" then
        quiver.value:SetText(n)   -- shown as is, no math on a secret
    else
        quiver.value:SetText(Commas(n))
        low = n < T().lowAmmo
    end
    if low then
        SetBoxColors(quiver.frame, "cardBg", "warningBorder")
        SetColor(quiver.value, "warning")
        p.low:Show()
        if state == "none" then
            p.lowText:SetText("No ammo equipped")
        else
            p.lowText:SetText(string.format("Low ammo: %s %s left", Commas(n), A:AmmoWord(n)))
        end
    else
        SetBoxColors(quiver.frame, "cardBg", "border")
        SetColor(quiver.value, "text")
        p.low:Hide()
    end

    -- By shot (lifetime)
    local list = {}
    for name, count in pairs(d.byShot) do list[#list + 1] = { name = name, n = count } end
    table.sort(list, function(a, b) return a.n > b.n end)
    local top = list[1] and list[1].n or 0
    p.noShots:SetShown(#list == 0)
    for i, row in ipairs(p.rows) do
        local s = list[i]
        if s then
            row:Show()
            row.name:SetText(s.name)
            row.value:SetText(Commas(s.n))
            SetBar(row, s.n / top)
        else
            row:Hide()
        end
    end

    p.steps:SetText(Commas(TM.Journey:Data().today.steps))
end

---------------------------------------------------------------------------
-- Journey tab
---------------------------------------------------------------------------

local function BuildJourney(page)
    local S = T().sizes
    local p = {}

    p.big = Text(page, "display", S.bigNumber, "text")
    p.big:SetPoint("TOPLEFT", 0, -22)
    p.bigLabel = Text(page, "body", S.bigLabel, "muted")
    p.bigLabel:SetPoint("TOPLEFT", p.big, "BOTTOMLEFT", 0, -4)
    p.bigLabel:SetText("steps lifetime")

    p.cards = CardRow(page, -124, { "DISTANCE", "STEPS TODAY", "THIS SESSION" })

    Heading(page, -204, "HOW YOU TRAVELED · LIFETIME")
    p.rows = {}
    for i, kind in ipairs(TRAVEL_ORDER) do
        local row = BarRow(page, -224 - (i - 1) * 34)
        row.name:SetText(TM.Journey.LABELS[kind])
        row.kind = kind
        p.rows[i] = row
    end

    local line = Divider(page)
    line:SetPoint("BOTTOMLEFT", 0, 32)
    line:SetPoint("BOTTOMRIGHT", 0, 32)
    local todayLabel = Text(page, "body", S.bodyText, "muted")
    todayLabel:SetPoint("BOTTOMLEFT", 0, 8)
    todayLabel:SetText("Distance today")
    p.today = Text(page, "bodyBold", S.bodyText, "text", "RIGHT")
    p.today:SetPoint("BOTTOMRIGHT", 0, 8)

    page.parts = p
end

local function RefreshJourney(page)
    local p = page.parts
    local J = TM.Journey
    local d = J:Data()
    local session = J:Session()

    p.big:SetText(Commas(d.steps))
    p.cards[1].value:SetText(J:FormatDistance(J:TotalYards()))
    p.cards[2].value:SetText(Commas(d.today.steps))
    p.cards[3].value:SetText(Commas(session.steps))

    local top = 0
    for _, kind in ipairs(TRAVEL_ORDER) do
        top = math.max(top, d.yards[kind] or 0)
    end
    for _, row in ipairs(p.rows) do
        local yards = d.yards[row.kind] or 0
        row.value:SetText(J:FormatDistance(yards))
        SetBar(row, top > 0 and yards / top or 0)
    end

    p.today:SetText(J:FormatDistance(d.today.yards))
end

---------------------------------------------------------------------------
-- History tab
---------------------------------------------------------------------------

local function BuildHistory(page)
    local S = T().sizes
    local p = {}

    Heading(page, 0, "RECENT FIGHTS")
    p.empty = Text(page, "body", S.bodyText, "muted")
    p.empty:SetPoint("TOPLEFT", 0, -24)

    p.rows = {}
    for i = 1, MAX_HISTORY_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", 0, -20 - (i - 1) * 48)
        row:SetPoint("RIGHT")
        row:SetHeight(48)

        row.place = Text(row, "body", S.bodyText, "text")
        row.place:SetPoint("TOPLEFT", 0, -8)
        row.place:SetPoint("RIGHT")

        row.info = Text(row, "body", S.bodyText, "muted")
        row.info:SetPoint("TOPLEFT", row.place, "BOTTOMLEFT", 0, -4)
        row.info:SetPoint("RIGHT")

        local line = Divider(row)
        line:SetPoint("BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT")

        p.rows[i] = row
    end

    page.parts = p
end

local function RefreshHistory(page)
    local p = page.parts
    local A = TM.Arrows
    local fights = A.enabled and A:Data().fights or {}

    if #fights == 0 then
        p.empty:Show()
        p.empty:SetText(A.enabled and "No fights yet. Fights with shots show up here."
            or "Fight history is for hunters for now.")
    else
        p.empty:Hide()
    end

    for i, row in ipairs(p.rows) do
        local f = fights[#fights - i + 1]   -- newest first
        if f then
            row:Show()
            row.place:SetText(A:ShortPlace(f) .. " · fight " .. f.n)
            row.info:SetText(string.format("%s %s · %s",
                Commas(f.shots), A:AmmoWord(f.shots, f.kind), Clock(f.duration)))
        else
            row:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local TABS = {
    { key = "ammo",    label = "Ammo",    build = BuildAmmo,    refresh = RefreshAmmo, hunterOnly = true },
    { key = "journey", label = "Journey", build = BuildJourney, refresh = RefreshJourney },
    { key = "history", label = "History", build = BuildHistory, refresh = RefreshHistory },
}

local function TabAllowed(tab)
    return not tab.hunterOnly or (TM.Arrows and TM.Arrows.enabled)
end

local function DefaultTab()
    return (TM.Arrows and TM.Arrows.enabled) and "ammo" or "journey"
end

function UI:SelectTab(key)
    local chosen
    for _, tab in ipairs(TABS) do
        if tab.key == key and TabAllowed(tab) then chosen = tab end
    end
    chosen = chosen or TABS[DefaultTab() == "ammo" and 1 or 2]
    TM.db.window.tab = chosen.key
    self.activeTab = chosen

    for _, tab in ipairs(TABS) do
        local active = (tab == chosen)
        if tab.page then tab.page:SetShown(active) end
        if tab.button then
            SetColor(tab.button.text, active and "text" or "muted")
            tab.button.underline:SetShown(active)
        end
    end
    self:Refresh()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function UpdateLockButton(btn)
    btn.text:SetText(TM.db.window.locked and "Unlock" or "Lock")
end

local function HeaderButton(parent, label)
    local S = T().sizes
    local btn = CreateFrame("Button", nil, parent)
    btn.text = Text(btn, "bodyBold", S.bodyText, "muted", "CENTER")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    btn:SetSize(math.max(24, btn.text:GetStringWidth() + 12), 24)
    btn:SetScript("OnEnter", function(self) SetColor(self.text, "text") end)
    btn:SetScript("OnLeave", function(self) SetColor(self.text, "muted") end)
    return btn
end

local function Build()
    local S = T().sizes

    local f = Box(UIParent, "windowBg", "border")
    f:SetSize(S.windowWidth, S.windowHeight)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not TM.db.window.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    -- Header
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T().textures.logo)
    logo:SetSize(S.logo, S.logo)
    logo:SetPoint("TOPLEFT", S.padding, -S.padding)

    local title = Text(f, "display", S.titleText, "text")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 0)
    title:SetText("Tallymark")

    local tagline = Text(f, "bodyBold", S.taglineText, "muted")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    tagline:SetText("EVERY STEP. EVERY SHOT.")

    local close = HeaderButton(f, "X")
    close:SetPoint("TOPRIGHT", -S.padding + 6, -S.padding + 2)
    close:SetScript("OnClick", function() UI:Hide() end)

    local lock = HeaderButton(f, "Unlock")
    lock:SetPoint("RIGHT", close, "LEFT", -4, 0)
    lock:SetScript("OnClick", function(self)
        TM.db.window.locked = not TM.db.window.locked
        UpdateLockButton(self)
    end)
    UpdateLockButton(lock)

    -- Tabs
    local x = S.padding
    for _, tab in ipairs(TABS) do
        if TabAllowed(tab) then
            local btn = CreateFrame("Button", nil, f)
            btn.text = Text(btn, "bodyBold", S.tabText, "muted", "CENTER")
            btn.text:SetPoint("CENTER", 0, 2)
            btn.text:SetText(tab.label)
            btn:SetSize(btn.text:GetStringWidth() + 20, S.tabHeight)
            btn:SetPoint("TOPLEFT", x, -S.headerHeight)
            x = x + btn:GetWidth() + S.gap

            btn.underline = Solid(btn, "accent")
            btn.underline:SetHeight(S.tabUnderline)
            btn.underline:SetPoint("BOTTOMLEFT", 0, 0)
            btn.underline:SetPoint("BOTTOMRIGHT", 0, 0)

            btn:SetScript("OnClick", function() UI:SelectTab(tab.key) end)
            btn:SetScript("OnEnter", function(self) SetColor(self.text, "text") end)
            btn:SetScript("OnLeave", function()
                SetColor(btn.text, UI.activeTab == tab and "text" or "muted")
            end)
            tab.button = btn
        end
    end
    local tabLine = Divider(f)
    tabLine:SetPoint("TOPLEFT", 0, -(S.headerHeight + S.tabHeight))
    tabLine:SetPoint("TOPRIGHT", 0, -(S.headerHeight + S.tabHeight))

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", S.padding, -(S.headerHeight + S.tabHeight + S.padding))
    content:SetPoint("BOTTOMRIGHT", -S.padding, S.footerHeight + S.padding)

    for _, tab in ipairs(TABS) do
        if TabAllowed(tab) then
            local page = CreateFrame("Frame", nil, content)
            page:SetAllPoints()
            page:Hide()
            tab.build(page)
            tab.page = page
        end
    end

    -- Footer
    local footLine = Divider(f)
    footLine:SetPoint("BOTTOMLEFT", 0, S.footerHeight)
    footLine:SetPoint("BOTTOMRIGHT", 0, S.footerHeight)

    local version = Text(f, "body", S.footerText, "footer")
    version:SetPoint("BOTTOMLEFT", S.padding, 14)
    version:SetText("Tallymark v" .. TM.VERSION)

    local author = Text(f, "body", S.footerText, "footer", "RIGHT")
    author:SetPoint("BOTTOMRIGHT", -S.padding, 14)
    author:SetText("by Buyaka")

    -- Tick once per second while open (combat timer, journey numbers).
    f:SetScript("OnShow", function()
        UI:Refresh()
        if UI.ticker then UI.ticker:Cancel() end
        UI.ticker = C_Timer.NewTicker(1, function() UI:Refresh() end)
    end)
    f:SetScript("OnHide", function()
        if UI.ticker then UI.ticker:Cancel() end
        UI.ticker = nil
    end)

    ApplyPosition(f)
    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function UI:Init()
    if TM.db.window.shown then
        self:Show()
    end
end

function UI:GetFrame()
    if not self.frame then
        self.frame = Build()
        self:SelectTab(TM.db.window.tab or DefaultTab())
    end
    return self.frame
end

function UI:Refresh()
    if not (self.frame and self.frame:IsShown() and self.activeTab) then return end
    local tab = self.activeTab
    local ok, err = pcall(tab.refresh, tab.page)
    if not ok and not self.warned then
        self.warned = true
        TM:Print("Window refresh failed: " .. tostring(err))
    end
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
