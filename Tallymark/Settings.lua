-- Settings.lua
-- The settings window (opened by the gear, the minimap right-click, or
-- Options > AddOns > Tallymark). Changes apply right away.
-- Sections: General, Ammo warning, Journey. Appearance (styles, colors)
-- and History come in later versions.

local ADDON, TM = ...

local Settings = {}
TM.Settings = Settings

local function T() return TM.Theme end
local W = TM.W

local WIDTH, HEIGHT = 580, 480
local NAV_WIDTH = 170

-- Settings that "Reset to default" puts back. Window position, open tab and
-- the stats themselves are never touched.
local RESET_KEYS = {
    { "window", "locked" }, { "window", "scale" }, { "window", "hideInCombat" },
    { "minimap", "hide" },
    { "ammo", "warn" }, { "ammo", "warnAt" }, { "ammo", "popup" },
    { "journey", "stride" },
    { "units" },
}

-- Re-read every control and update the main window.
local function RefreshAll()
    for _, c in ipairs(Settings.controls or {}) do c:Refresh() end
    TM.UI:ApplyScale()
    TM.UI:Refresh()
end

local function ResetToDefault()
    local D = TM.DB_DEFAULTS
    for _, key in ipairs(RESET_KEYS) do
        if #key == 1 then
            TM.db[key[1]] = D[key[1]]
        else
            TM.db[key[1]][key[2]] = D[key[1]][key[2]]
        end
    end
    TM.MinimapButton:SetHidden(TM.db.minimap.hide)
    RefreshAll()
    TM:Print("Settings reset to default.")
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

-- Stacks controls top to bottom on a page.
local function Stacker(page)
    local y = 0
    local s = {}
    -- keepWidth: leave the control at its own width (buttons) instead of full width.
    function s.Add(ctrl, gap, keepWidth)
        y = y - (gap or 14)
        ctrl:SetPoint("TOPLEFT", 0, y)
        if not keepWidth then
            ctrl:SetPoint("RIGHT", page, "RIGHT", 0, 0)
        end
        y = y - ctrl:GetHeight()
        if ctrl.Refresh then
            Settings.controls[#Settings.controls + 1] = ctrl
        end
        return ctrl
    end
    function s.Heading(text, gap)
        local h = W.Heading(page, text)
        y = y - (gap or 20)
        h:SetPoint("TOPLEFT", 0, y)
        y = y - h:GetStringHeight()
    end
    -- A muted line of text that can wrap.
    function s.Note(text, gap)
        local n = W.Text(page, "body", T().sizes.cardLabel, "muted")
        n:SetWordWrap(true)
        y = y - (gap or 0)
        n:SetPoint("TOPLEFT", 0, y)
        n:SetPoint("RIGHT", page, "RIGHT", 0, 0)
        n:SetText(text)
        y = y - n:GetStringHeight()
    end
    return s
end

local function BuildGeneral(page)
    local s = Stacker(page)
    s.Heading("WINDOW", 0)
    s.Add(W.Checkbox(page, "Lock window position", "Stops the window from being dragged by accident.",
        function() return TM.db.window.locked end,
        function(v) TM.UI:SetLocked(v) end))
    s.Add(W.Slider(page, "Window size", nil, 70, 130, 5,
        function(v) return string.format("%d%%", v) end,
        function() return math.floor((TM.db.window.scale or 1) * 100 + 0.5) end,
        function(v)
            TM.db.window.scale = v / 100
            TM.UI:ApplyScale()
        end))
    s.Add(W.Checkbox(page, "Hide the window during combat", "It comes back by itself when the fight ends.",
        function() return TM.db.window.hideInCombat end,
        function(v) TM.db.window.hideInCombat = v end))

    s.Heading("MINIMAP")
    s.Add(W.Checkbox(page, "Show minimap button", "You can always open Tallymark with /tally or /tm.",
        function() return not TM.db.minimap.hide end,
        function(v) TM.MinimapButton:SetHidden(not v) end))
end

local function BuildAmmo(page)
    local s = Stacker(page)
    local hunter = TM.Arrows and TM.Arrows.enabled
    if not hunter then
        s.Note("Ammo tracking is for hunters. These settings apply to your hunters.")
    end
    s.Heading("LOW AMMO WARNING", hunter and 0 or 16)
    s.Add(W.Checkbox(page, "Low ammo warning", "Gold ammo card, bell and a reminder box on the window.",
        function() return TM.db.ammo.warn end,
        function(v)
            TM.db.ammo.warn = v
            TM.UI:Refresh()
        end))
    s.Add(W.NumberBox(page, "Warn me below", "Arrows or bullets left, in all your bags.", 1, 5000, 0,
        function() return TM.db.ammo.warnAt end,
        function(v)
            TM.db.ammo.warnAt = v
            TM.UI:Refresh()
        end))
    s.Add(W.Checkbox(page, "Pop-up alert", "A short alert near the top of the screen when you drop below that amount.",
        function() return TM.db.ammo.popup end,
        function(v) TM.db.ammo.popup = v end))

    local test = W.TextButton(page, "Show a test alert")
    test:SetScript("OnClick", function() TM.Popup:ShowLowAmmo(TM.db.ammo.warnAt - 1, true) end)
    s.Add(test, 16, true)
end

local function BuildJourney(page)
    local s = Stacker(page)
    s.Heading("DISTANCE", 0)
    s.Add(W.Switch(page, "Show distance in", nil,
        { { value = "miles", text = "Miles" }, { value = "km", text = "Kilometers" } },
        function() return TM.db.units end,
        function(v)
            TM.db.units = v
            TM.UI:Refresh()
        end))

    s.Heading("STEPS")
    s.Add(W.NumberBox(page, "Step length (yards)",
        "1.0 = one yard (about 0.9 m). Only new steps use a new length.", 0.3, 3, 2,
        function() return TM.db.journey.stride end,
        function(v) TM.db.journey.stride = v end))
end

local SECTIONS = {
    { key = "general", label = "General",      build = BuildGeneral },
    { key = "ammo",    label = "Ammo warning", build = BuildAmmo },
    { key = "journey", label = "Journey",      build = BuildJourney },
}

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

function Settings:Select(key)
    for _, sec in ipairs(SECTIONS) do
        local on = sec.key == key
        sec.page:SetShown(on)
        W.SetColor(sec.button.text, on and "text" or "muted")
        sec.button.bar:SetShown(on)
        W.SetBoxColors(sec.button.bg, on and "cardBg" or "windowBg", on and "cardBg" or "windowBg")
    end
    self.current = key
end

local function Build()
    local S = T().sizes
    Settings.controls = {}

    local f = W.Box(UIParent, "windowBg", "border", T().radius.window)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Header
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T().textures.logo)
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", S.padding, -S.padding)
    local title = W.Text(f, "display", 16, "text")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("Tallymark Settings")

    local close = W.IconButton(f, T().textures.close)
    close:SetPoint("TOPRIGHT", -S.padding, -12)
    close:SetScript("OnClick", function() f:Hide() end)

    local headLine = W.Divider(f)
    headLine:SetPoint("TOPLEFT", 0, -56)
    headLine:SetPoint("TOPRIGHT", 0, -56)

    -- Left navigation
    local navLine = W.Solid(f, "border", "BORDER")
    navLine:SetWidth(S.borderSize)
    navLine:SetPoint("TOPLEFT", NAV_WIDTH, -56)
    navLine:SetPoint("BOTTOMLEFT", NAV_WIDTH, 56)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", NAV_WIDTH + 24, -56 - 20)
    content:SetPoint("BOTTOMRIGHT", -24, 56 + 12)

    for i, sec in ipairs(SECTIONS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(NAV_WIDTH - 24, 34)
        b:SetPoint("TOPLEFT", 12, -56 - 12 - (i - 1) * 38)
        b.bg = W.Box(b, "windowBg", "windowBg", T().radius.button)
        b.bg:SetAllPoints()
        b.bg:SetFrameLevel(b:GetFrameLevel())
        b.bar = W.Solid(b.bg, "accent", "OVERLAY")
        b.bar:SetSize(3, 20)
        b.bar:SetPoint("LEFT", 0, 0)
        b.text = W.Text(b.bg, "bodyBold", S.bodyText, "muted")
        b.text:SetPoint("LEFT", 14, 0)
        b.text:SetText(sec.label)
        b:SetScript("OnClick", function() Settings:Select(sec.key) end)
        b:SetScript("OnEnter", function() W.SetColor(b.text, "text") end)
        b:SetScript("OnLeave", function()
            W.SetColor(b.text, Settings.current == sec.key and "text" or "muted")
        end)
        sec.button = b

        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints()
        page:Hide()
        sec.build(page)
        sec.page = page
    end

    -- Footer
    local footLine = W.Divider(f)
    footLine:SetPoint("BOTTOMLEFT", 0, 56)
    footLine:SetPoint("BOTTOMRIGHT", 0, 56)

    local version = W.Text(f, "body", S.footerText, "footer")
    version:SetPoint("BOTTOMLEFT", S.padding, 22)
    version:SetText("Tallymark v" .. TM.VERSION .. " beta · by Buyaka")

    local reset = W.TextButton(f, "Reset to default")
    reset:SetPoint("BOTTOMRIGHT", -S.padding, 12)
    reset:SetScript("OnClick", ResetToDefault)

    f:SetScript("OnShow", RefreshAll)
    f:Hide()
    return f
end

function Settings:GetFrame()
    if not self.frame then
        self.frame = Build()
        self:Select("general")
    end
    return self.frame
end

function Settings:Toggle()
    local f = self:GetFrame()
    f:SetShown(not f:IsShown())
end

function Settings:Open(section)
    local f = self:GetFrame()
    if section then self:Select(section) end
    f:Show()
end

---------------------------------------------------------------------------
-- Options > AddOns > Tallymark (the game's own options screen)
-- A small page with a button that opens our settings window, the same way
-- Baganator and Chattynator do it.
---------------------------------------------------------------------------

function Settings:RegisterInGameOptions()
    if not (_G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory) then
        return
    end
    local panel = CreateFrame("Frame")
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T().textures.logo)
    logo:SetSize(64, 64)
    logo:SetPoint("CENTER", 0, 80)

    local title = W.Text(panel, "display", 28, "text", "CENTER")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -12)
    title:SetText("Tallymark")

    local tagline = W.Text(panel, "bodyBold", 12, "muted", "CENTER")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    tagline:SetText("EVERY STEP. EVERY SHOT.")

    local open = W.TextButton(panel, "Open Tallymark settings", true)
    open:SetPoint("TOP", tagline, "BOTTOM", 0, -24)
    open:SetScript("OnClick", function() Settings:Open() end)

    local ok, category = pcall(_G.Settings.RegisterCanvasLayoutCategory, panel, "Tallymark")
    if ok and category then
        pcall(_G.Settings.RegisterAddOnCategory, category)
    end
end
