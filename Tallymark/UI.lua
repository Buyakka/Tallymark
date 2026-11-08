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

-- Shared building blocks live in Widgets.lua.
local W = TM.W
local Text, SetColor, Solid = W.Text, W.SetColor, W.Solid
local Box, SetBoxColors, Divider = W.Box, W.SetBoxColors, W.Divider
local IconButton = W.IconButton

local function Commas(n) return TM.Commas(n) end

-- "bullets" -> "Bullets"
local function Capital(s)
    return (s:gsub("^%l", string.upper))
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

-- Hides the big window from our own code. A hide that doesn't come from here
-- (the Escape key) is treated like clicking the X, see UI:ClosedByGame.
local function HideFrame(frame)
    UI.internalHide = true
    frame:Hide()
    UI.internalHide = false
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
        local card = Box(parent, "cardBg", "cardBg")
        card:SetSize(width, S.cardHeight)
        card:SetPoint("TOPLEFT", (i - 1) * (width + S.gap), y)

        local l = Text(card, "body", S.cardLabel, "muted")
        l:SetPoint("TOPLEFT", 10, -10)
        l:SetPoint("RIGHT", -28, 0)
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

local RefreshAmmo   -- defined below; the Fight | All time switch calls it

local function BuildAmmo(page)
    local S = T().sizes
    local p = {}

    -- Combat line: teal dot + "IN COMBAT · 0:42"
    p.combat = CreateFrame("Frame", nil, page)
    p.combat:SetPoint("TOPLEFT")
    p.combat:SetSize(200, 16)
    local dot = p.combat:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(T().textures.circle)   -- round dot, like the design
    dot:SetVertexColor(T():RGB("accent"))
    dot:SetSize(S.dot, S.dot)
    dot:SetPoint("LEFT")
    p.combatText = Text(p.combat, "bodyBold", S.heading, "accent")
    p.combatText:SetPoint("LEFT", dot, "RIGHT", 6, 0)

    p.big = Text(page, "display", S.bigNumber, "text")
    p.big:SetPoint("TOPLEFT", 0, -22)
    p.bigLabel = Text(page, "body", S.bigLabel, "muted")
    p.bigLabel:SetPoint("BOTTOMLEFT", p.big, "BOTTOMRIGHT", 10, 10)

    -- Third card label follows the ammo type: "Bullets left" or "Arrows left".
    -- It counts ammo in all bags, not only the quiver or ammo pouch.
    p.cards = CardRow(page, -110, { "Dungeon", "All time", "Ammo left" })

    -- Bell on the ammo card: shown while the low ammo warning is on.
    local bell = p.cards[3].frame:CreateTexture(nil, "OVERLAY")
    bell:SetTexture(T().textures.bell)
    bell:SetSize(16, 16)
    bell:SetPoint("TOPRIGHT", -8, -8)
    p.bell = bell

    p.shotHeading = Heading(page, -204, "BY SHOT · THIS FIGHT")

    -- Fight | All time switch on the right of the heading.
    local function ViewButton(label)
        local b = CreateFrame("Button", nil, page)
        b.text = Text(b, "bodyBold", S.heading, "muted", "RIGHT")
        b.text:SetPoint("RIGHT")
        b.text:SetText(label)
        b:SetSize(math.ceil(b.text:GetUnboundedStringWidth()) + 4, 18)
        return b
    end
    p.viewAll = ViewButton("ALL TIME")
    p.viewAll:SetPoint("TOPRIGHT", 0, -202)
    local sep = Text(page, "bodyBold", S.heading, "muted", "RIGHT")
    sep:SetPoint("RIGHT", p.viewAll, "LEFT", -6, 0)
    sep:SetText("·")
    p.viewFight = ViewButton("FIGHT")
    p.viewFight:SetPoint("RIGHT", sep, "LEFT", -6, 0)
    local function SetView(view)
        TM.db.ammo.shotView = view
        RefreshAmmo(page)
    end
    p.viewFight:SetScript("OnClick", function() SetView("fight") end)
    p.viewAll:SetScript("OnClick", function() SetView("all") end)

    p.rows = {}
    for i = 1, MAX_SHOT_ROWS do
        local row = BarRow(page, -224 - (i - 1) * 34)
        row.name:SetPoint("RIGHT", -150, 0)   -- room for "12 · 1,234 all time"
        row:SetScript("OnEnter", function(self)
            if not self.others then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Other shots", T():RGB("text"))
            local mr, mg, mb = T():RGB("muted")
            local tr, tg, tb = T():RGB("text")
            for _, o in ipairs(self.others) do
                local v = Commas(o.n)
                if self.allTime then
                    v = v .. " · " .. Commas(self.allTime[o.name] or o.n) .. " all time"
                end
                GameTooltip:AddDoubleLine(o.name, v, mr, mg, mb, tr, tg, tb)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.rows[i] = row
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
    p.low = Box(page, "warningBox", "warningBox")
    p.low:SetPoint("BOTTOMLEFT", 0, 44)
    p.low:SetPoint("BOTTOMRIGHT", 0, 44)
    p.low:SetHeight(44)
    p.lowText = Text(p.low, "body", S.bodyText, "warning")
    p.lowText:SetPoint("LEFT", 12, 0)
    p.lowText:SetPoint("RIGHT", -12, 0)

    page.parts = p
end

function RefreshAmmo(page)
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
    p.cards[2].value:SetText(Commas(A:LifetimeTotal()))   -- includes shots typed in from before

    local n, state = A:AmmoCount()
    local quiver = p.cards[3]
    quiver.label:SetText(Capital(A:AmmoWord(2)) .. " left")
    local warnAt = TM:LowAmmoAt()   -- nil when the warning is turned off
    local low = false
    if state == "none" then
        quiver.value:SetText("0")
        low = warnAt ~= nil
    elseif state == "secret" then
        quiver.value:SetText(n)   -- shown as is, no math on a secret
    else
        quiver.value:SetText(Commas(n))
        low = warnAt ~= nil and n <= warnAt
    end
    p.bell:SetShown(warnAt ~= nil)
    if low then
        -- Red number, border and bell so low ammo stands out at a glance.
        SetBoxColors(quiver.frame, "cardBg", "lowAmmoBorder")
        SetColor(quiver.value, "lowAmmo")
        p.bell:SetVertexColor(T():RGB("lowAmmo"))
        p.low:Show()
        if state == "none" then
            p.lowText:SetText("No ammo equipped. Time to restock.")
        else
            p.lowText:SetText(string.format("Low ammo: %s %s left. Time to restock.",
                Commas(n), A:AmmoWord(n)))
        end
    else
        SetBoxColors(quiver.frame, "cardBg", "cardBg")
        SetColor(quiver.value, "text")
        p.bell:SetVertexColor(T():RGB("muted"))
        p.low:Hide()
    end

    -- By shot. Fight view: this fight in combat, the last fight out of combat,
    -- with each shot's all-time count next to it. All time view: every shot ever.
    local allTime = d.byShot or {}
    local showAll = TM.db.ammo.shotView == "all"
    local byShot
    if showAll then
        byShot = allTime
        p.shotHeading:SetText("BY SHOT · ALL TIME")
    else
        local source = fight or A:LastFight()
        byShot = source and source.byShot or {}
        p.shotHeading:SetText(fight and "BY SHOT · THIS FIGHT" or "BY SHOT · LAST FIGHT")
    end
    SetColor(p.viewFight.text, showAll and "muted" or "accent")
    SetColor(p.viewAll.text, showAll and "accent" or "muted")

    local list = {}
    for name, count in pairs(byShot) do list[#list + 1] = { name = name, n = count } end
    table.sort(list, function(a, b) return a.n > b.n end)

    -- More shots than rows: the last row adds up the rest.
    if #list > MAX_SHOT_ROWS then
        local rest = 0
        for i = MAX_SHOT_ROWS, #list do rest = rest + list[i].n end
        local others = #list - MAX_SHOT_ROWS + 1
        local hidden = {}
        for i = MAX_SHOT_ROWS, #list do hidden[#hidden + 1] = list[i] end
        for i = #list, MAX_SHOT_ROWS, -1 do list[i] = nil end
        list[MAX_SHOT_ROWS] = { name = string.format("%d other shots", others), n = rest, other = hidden }
    end

    local top = 0
    for _, s in ipairs(list) do top = math.max(top, s.n) end
    p.noShots:SetShown(#list == 0)
    for i, row in ipairs(p.rows) do
        local s = list[i]
        if s then
            row:Show()
            row.name:SetText(s.name)
            local value = Commas(s.n)
            if not showAll and not s.other then
                value = value .. T():Color("muted", " · " .. Commas(allTime[s.name] or s.n) .. " all time")
            end
            row.value:SetText(value)
            SetBar(row, top > 0 and s.n / top or 0)
            -- Hover "N other shots" to see each one.
            row.others = s.other
            row.allTime = (not showAll) and allTime or nil
            row:EnableMouse(s.other ~= nil)
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
    p.bigLabel:SetPoint("BOTTOMLEFT", p.big, "BOTTOMRIGHT", 10, 10)
    p.bigLabel:SetText("steps lifetime")

    p.cards = CardRow(page, -110, { "Distance", "Steps today", "This session" })

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

-- Shows one settings section (General, Small window, Ammo, Journey).
function UI:SelectSettings(key)
    local sections = TM.Settings.SECTIONS
    local found = false
    for _, sec in ipairs(sections) do
        if sec.key == key then found = true end
    end
    if not found then key = sections[1].key end
    self.settingsTab = key
    for _, sec in ipairs(sections) do
        local on = sec.key == key
        if sec.page then sec.page:SetShown(on) end
        if sec.button then
            SetColor(sec.button.text, on and "text" or "muted")
            sec.button.underline:SetShown(on)
        end
    end
    self:UpdateMiniPreview()
end

-- On the Small window settings page, show the small window next to settings
-- (when it is turned on) so size and opacity changes can be seen live.
function UI:UpdateMiniPreview()
    if not self.settingsOn then return end
    if self.settingsTab == "mini" and TM.db.window.small then
        TM.Mini:Show()
    else
        TM.Mini:Hide()
    end
end

function UI:IsSettingsShown()
    return self.settingsOn == true and self.frame ~= nil and self.frame:IsShown()
end

-- Switches the window between stats (off) and settings (on).
-- toStats: when leaving settings, stay on the big window's stats (the gear)
-- even if the small window is on. Done, X and the minimap go to the small one.
function UI:ShowSettings(on, section, toStats)
    self:GetFrame()
    self.settingsOn = on and true or false

    self.statsBar:SetShown(not on)
    self.settingsBar:SetShown(on)
    self.statsFoot:SetShown(not on)
    self.settingsFoot:SetShown(on)

    if on then
        for _, tab in ipairs(TABS) do
            if tab.page then tab.page:Hide() end
        end
        TM.Settings:Refresh()
        self:SelectSettings(section or self.settingsTab or "general")
    else
        for _, sec in ipairs(TM.Settings.SECTIONS) do
            if sec.page then sec.page:Hide() end
        end
        self:SelectTab(TM.db.window.tab or DefaultTab())
    end

    self.gear.color = on and "accent" or "muted"
    self.gear.icon:SetVertexColor(T():RGB(self.gear.color))

    -- Settings always use the big window. Leaving settings in small window
    -- mode (X, Escape, minimap) swaps back to the small window. Done and the
    -- gear go to the big window's stats instead.
    if not on and TM.db.window.small and not self.closing then
        if toStats then
            TM.Mini:Hide()
        else
            self:Show()
        end
    end
end

function UI:SelectTab(key)
    if self.settingsOn then return end   -- stats tabs are hidden in settings mode
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

local function Build()
    local S = T().sizes

    local f = Box(UIParent, "windowBg", "border", T().radius.window)
    -- A global name so the Escape key can close it, like the game's own windows.
    _G.TallymarkWindow = f
    tinsert(UISpecialFrames, "TallymarkWindow")
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

    local close = IconButton(f, T().textures.close, function()
        return { "Close (Esc)", "Type /tm or click the minimap button to open again." }
    end)
    close:SetPoint("TOPRIGHT", -S.padding, -S.padding + 2)
    close:SetScript("OnClick", function() UI:Hide() end)

    -- Gear: switches this window between stats and settings.
    local gear = IconButton(f, T().textures.gear, function()
        if UI:IsSettingsShown() then
            return { "Back to stats", "Your settings are already saved." }
        end
        return { "Settings", "Window size, small window, ammo warning, miles or km, and more." }
    end)
    gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
    gear:SetScript("OnClick", function(self)
        TM.Settings:Toggle(true)          -- from settings, back to these stats
        self:GetScript("OnEnter")(self)   -- refresh the tooltip text
    end)
    UI.gear = gear

    -- Two tab rows in the same place: stats tabs and settings tabs.
    -- isActive(item) tells which button is underlined.
    local function TabRow(items, onClick, isActive)
        local row = CreateFrame("Frame", nil, f)
        row:SetPoint("TOPLEFT", 0, -S.headerHeight)
        row:SetPoint("RIGHT")
        row:SetHeight(S.tabHeight)
        local x = S.padding
        for _, item in ipairs(items) do
            local btn = CreateFrame("Button", nil, row)
            btn.text = Text(btn, "bodyBold", S.tabText, "muted", "CENTER")
            btn.text:SetPoint("CENTER", 0, 2)
            btn.text:SetText(item.label)
            btn:SetSize(btn.text:GetStringWidth() + 20, S.tabHeight)
            btn:SetPoint("TOPLEFT", x, 0)
            x = x + btn:GetWidth() + S.gap

            btn.underline = Solid(btn, "accent")
            btn.underline:SetHeight(S.tabUnderline)
            btn.underline:SetPoint("BOTTOMLEFT", 0, 0)
            btn.underline:SetPoint("BOTTOMRIGHT", 0, 0)

            btn:SetScript("OnClick", function() onClick(item.key) end)
            btn:SetScript("OnEnter", function(self) SetColor(self.text, "text") end)
            btn:SetScript("OnLeave", function()
                SetColor(btn.text, isActive(item) and "text" or "muted")
            end)
            item.button = btn
        end
        return row
    end

    local statTabs = {}
    for _, tab in ipairs(TABS) do
        if TabAllowed(tab) then statTabs[#statTabs + 1] = tab end
    end
    UI.statsBar = TabRow(statTabs, function(key) UI:SelectTab(key) end,
        function(item) return UI.activeTab == item end)
    UI.settingsBar = TabRow(TM.Settings.SECTIONS, function(key) UI:SelectSettings(key) end,
        function(item) return UI.settingsTab == item.key end)
    UI.settingsBar:Hide()

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
    TM.Settings:BuildPages(content)   -- settings pages share the same content area

    -- Footer: version and author for stats, Reset and Done for settings.
    local footLine = Divider(f)
    footLine:SetPoint("BOTTOMLEFT", 0, S.footerHeight)
    footLine:SetPoint("BOTTOMRIGHT", 0, S.footerHeight)

    local statsFoot = CreateFrame("Frame", nil, f)
    statsFoot:SetPoint("BOTTOMLEFT")
    statsFoot:SetPoint("BOTTOMRIGHT")
    statsFoot:SetHeight(S.footerHeight)
    -- Left: whose stats these are (saved per character), in class color.
    local who = Text(statsFoot, "body", S.footerText, "footer")
    who:SetPoint("LEFT", S.padding, 0)
    who:SetPoint("RIGHT", statsFoot, "CENTER", 40, 0)
    local name, class = TM:CharName()
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    who:SetText(name)
    if cc then who:SetTextColor(cc.r, cc.g, cc.b) end
    local author = Text(statsFoot, "body", S.footerText, "footer", "RIGHT")
    author:SetPoint("RIGHT", -S.padding, 0)
    author:SetText("v" .. TM.VERSION .. " · by Buyaka")
    UI.statsFoot = statsFoot

    local settingsFoot = CreateFrame("Frame", nil, f)
    settingsFoot:SetPoint("BOTTOMLEFT")
    settingsFoot:SetPoint("BOTTOMRIGHT")
    settingsFoot:SetHeight(S.footerHeight)
    local reset = TM.W.TextButton(settingsFoot, "Reset settings")   -- settings only, never stats
    reset:SetHeight(28)
    reset:SetPoint("LEFT", S.padding, 0)
    reset:SetScript("OnClick", function() TM.Settings.ResetToDefault() end)
    local done = TM.W.TextButton(settingsFoot, "Done", true)
    done:SetHeight(28)
    done:SetPoint("RIGHT", -S.padding, 0)
    done:SetScript("OnClick", function() UI:ShowSettings(false, nil, true) end)   -- back to stats
    settingsFoot:Hide()
    UI.settingsFoot = settingsFoot

    -- Tick once per second while open (combat timer, journey numbers).
    f:SetScript("OnShow", function()
        UI:Refresh()
        if UI.ticker then UI.ticker:Cancel() end
        UI.ticker = C_Timer.NewTicker(1, function() UI:Refresh() end)
    end)
    f:SetScript("OnHide", function()
        if UI.ticker then UI.ticker:Cancel() end
        UI.ticker = nil
        -- Only a real close (Escape). When the whole UI hides (Alt+Z, loading
        -- screens) the window is still "shown" and comes back by itself.
        if not UI.internalHide and not f:IsShown() then UI:ClosedByGame() end
    end)

    ApplyPosition(f)
    HideFrame(f)
    return f
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function UI:Init()
    if TM.db.window.shown then
        self:Show()
    end

    -- "Hide the window during combat": hide when combat starts, bring it back after.
    -- Only a window the player had open comes back. A closed window stays closed.
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if not self.frame then self:GetFrame() end
        if event == "PLAYER_REGEN_DISABLED" then
            -- Each window has its own choice. By default the small window
            -- stays up so players can watch their numbers live in the fight.
            if TM.db.window.hideInCombat and self.frame:IsShown() then
                self.hiddenForCombat = true
                HideFrame(self.frame)      -- db "shown" stays true on purpose
            end
            if TM.db.mini.hideInCombat and TM.Mini:IsShown() then
                self.miniHiddenForCombat = true
                TM.Mini:Hide()
            end
        else
            -- Bring each window back exactly as it was (stats or settings).
            if self.hiddenForCombat then
                self.hiddenForCombat = false
                if TM.db.window.shown then self.frame:Show() end
            end
            if self.miniHiddenForCombat then
                self.miniHiddenForCombat = false
                if TM.db.window.shown then TM.Mini:Show() end
            end
        end
    end)
end

function UI:GetFrame()
    if not self.frame then
        self.frame = Build()
        self:ApplyScale()
        self:ApplyOpacity()
        self:SelectTab(TM.db.window.tab or DefaultTab())
    end
    return self.frame
end

-- Lock or unlock dragging the window.
function UI:SetLocked(locked)
    TM.db.window.locked = locked and true or false
end

-- Window size from settings (0.7 to 1.3). Also sizes the small window.
function UI:ApplyScale()
    TM.Mini:ApplyLook()
    if not self.frame then return end
    local s = tonumber(TM.db.window.scale) or 1
    s = math.max(0.7, math.min(1.3, s))
    self.frame:SetScale(s)
end

-- Window opacity from settings (0.2 to 1). Fades the whole window, text
-- included, so the game shows through. Also fades the small window.
function UI:ApplyOpacity()
    TM.Mini:ApplyLook()
    if not self.frame then return end
    local o = tonumber(TM.db.window.opacity) or 1
    self.frame:SetAlpha(math.max(0.2, math.min(1, o)))
end

function UI:Refresh()
    TM.Mini:Refresh()
    if not (self.frame and self.frame:IsShown() and self.activeTab) then return end
    if self.settingsOn then return end   -- stats are hidden while settings are open
    local tab = self.activeTab
    local ok, err = pcall(tab.refresh, tab.page)
    if not ok and not self.warned then
        self.warned = true
        TM:Print("Window refresh failed: " .. tostring(err))
    end
end

-- Shows the stats: the small window when "Small window" is on, else the big one.
function UI:Show()
    TM.db.window.shown = true
    if TM.db.window.small then
        if self.frame and not self.settingsOn then HideFrame(self.frame) end
        TM.Mini:Show()
    else
        TM.Mini:Hide()
        self:GetFrame():Show()
    end
end

function UI:Hide()
    -- With the small window on, closing the big window (settings or stats)
    -- goes back to the small window instead of hiding everything.
    if TM.db.window.small and self.frame and self.frame:IsShown() then
        self.closing = true
        if self.settingsOn then self:ShowSettings(false) end
        self.closing = false
        HideFrame(self.frame)
        TM.Mini:Show()
        TM.db.window.shown = true
        return
    end
    if self.frame then
        -- Next time the window opens, it opens on the stats, not settings.
        self.closing = true
        if self.settingsOn then self:ShowSettings(false) end
        self.closing = false
        HideFrame(self.frame)
    end
    TM.Mini:Hide()
    TM.db.window.shown = false
end

-- The game closed the window (Escape). Same result as clicking the X: leave
-- settings, then show the small window if it is on, else stay closed.
function UI:ClosedByGame()
    self.closing = true
    if self.settingsOn then self:ShowSettings(false) end
    self.closing = false
    if TM.db.window.small then
        TM.Mini:Show()
        TM.db.window.shown = true
    else
        TM.Mini:Hide()
        TM.db.window.shown = false
    end
end

-- Opens the big window on its stats (Ammo, Journey, History), also when the
-- small window is on. Clicking the small window does this.
function UI:ShowFull()
    TM.db.window.shown = true
    self:GetFrame():Show()
    if self.settingsOn then self:ShowSettings(false, nil, true) end
    TM.Mini:Hide()
end

-- Settings > "Small window" changed while settings are open.
function UI:SetSmall(on)
    TM.db.window.small = on and true or false
    self:UpdateMiniPreview()
end

function UI:Toggle()
    if (self.frame and self.frame:IsShown()) or TM.Mini:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Puts both windows back in their starting spots (/tally reset).
function UI:ResetPosition()
    local w = TM.db.window
    w.point, w.relPoint, w.x, w.y = "CENTER", "CENTER", 0, 0
    if self.frame then
        ApplyPosition(self.frame)
    end
    TM.Mini:ResetPosition()
end
