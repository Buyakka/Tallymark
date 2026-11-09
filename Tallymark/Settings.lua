-- Settings.lua
-- Settings live inside the main Tallymark window: the gear switches the
-- window to settings mode (see UI:ShowSettings). Also opened by the minimap
-- right-click, /tally settings, and Options > AddOns > Tallymark.
-- Changes apply right away.
-- Sections: General, Small window, Ammo, Journey. Appearance (styles, colors)
-- and History come in later versions.

local ADDON, TM = ...

local Settings = {}
TM.Settings = Settings

local function T() return TM.Theme end
local W = TM.W

-- Settings that "Reset settings" puts back. Window position, open tab and
-- the stats themselves are never touched.
local RESET_KEYS = {
    { "window", "small" }, { "mini", "scale" }, { "mini", "opacity" }, { "window", "locked" }, { "window", "scale" }, { "window", "opacity" },
    { "window", "hideInCombat" }, { "mini", "hideInCombat" },
    { "minimap", "hide" },
    { "ammo", "warn" }, { "ammo", "warnAt" },
    { "ammo", "popup" }, { "ammo", "popupSeconds" },
    { "journey", "stride" },
    { "units" },
}

-- Re-read every control and update the main window.
local function RefreshAll()
    for _, c in ipairs(Settings.controls or {}) do c:Refresh() end
    TM.UI:ApplyScale()
    TM.UI:ApplyOpacity()
    TM.UI:Refresh()
end

-- Resetting stats asks first, since it can't be undone.
local RESET_WHAT = {
    journey = "your journey stats (steps and distance)",
    ammo    = "your ammo stats (shots, fights and dungeon runs)",
    all     = "ALL your stats (journey and ammo)",
}

local function DoResetStats(kind)
    if kind == "journey" or kind == "all" then TM.Journey:Reset() end
    if kind == "ammo" or kind == "all" then TM.Arrows:Reset() end
    TM.UI:Refresh()
    TM:Print("Stats reset for " .. (TM:CharName()) .. ".")
end

StaticPopupDialogs["TALLYMARK_RESET_STATS"] = {
    -- string.char(10) is a line break (kept out of the quotes on purpose).
    text = "Reset %s for %s?" .. string.rep(string.char(10), 2) .. "They go back to zero. This can't be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(self, data) DoResetStats(data or self.data) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

local function AskResetStats(kind)
    StaticPopup_Show("TALLYMARK_RESET_STATS", RESET_WHAT[kind], (TM:CharName()), kind)
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
    wipe(TM.db.ammo.miniHidden)   -- every shot shows on the small window again
    TM.MinimapButton:SetHidden(TM.db.minimap.hide)
    RefreshAll()
    TM.Mini:Refresh()
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
        -- A fixed width (the page's width) so the text wraps onto more lines
        -- instead of ending in "...", and its height is right when measured.
        n:SetWidth(T().sizes.windowWidth - T().sizes.padding * 2)
        n:SetMaxLines(4)
        n:SetText(text)
        y = y - n:GetStringHeight()
    end
    return s
end

local function BuildGeneral(page)
    local s = Stacker(page)
    s.Heading("WINDOW", 0)
    s.Add(W.Checkbox(page, "Lock window position", "Stops both windows from being dragged by accident.",
        function() return TM.db.window.locked end,
        function(v) TM.UI:SetLocked(v) end))
    -- The size is applied when the mouse is let go. Resizing while dragging would
    -- move the slider under the mouse, since the slider is inside this window.
    local size = s.Add(W.Slider(page, "Window size", "Applies when you let go of the slider.", 70, 130, 5,
        function(v) return string.format("%d%%", v) end,
        function() return math.floor((TM.db.window.scale or 1) * 100 + 0.5) end,
        function(v) TM.db.window.scale = v / 100 end))
    size.slider:HookScript("OnMouseUp", function() TM.UI:ApplyScale() end)
    s.Add(W.Slider(page, "Window opacity", "Lower it to see the game through the window.", 20, 100, 5,
        function(v) return string.format("%d%%", v) end,
        function() return math.floor((TM.db.window.opacity or 1) * 100 + 0.5) end,
        function(v)
            TM.db.window.opacity = v / 100
            TM.UI:ApplyOpacity()
        end))
    s.Add(W.Checkbox(page, "Hide during combat", "Big window only. The small window has its own.",
        function() return TM.db.window.hideInCombat end,
        function(v) TM.db.window.hideInCombat = v end))

    s.Heading("MINIMAP")
    s.Add(W.Checkbox(page, "Show minimap button", "You can always open Tallymark with /tally.",
        function() return not TM.db.minimap.hide end,
        function(v) TM.MinimapButton:SetHidden(not v) end))

    -- Stats are saved per character. Each button asks before resetting.
    s.Heading("YOUR STATS")
    s.Note("Only for " .. (TM:CharName()) .. ". Your other characters keep theirs.", 6)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(32)
    local x = 0
    local buttons = { { "journey", "Reset journey" } }
    if TM.Arrows and TM.Arrows.enabled then buttons[#buttons + 1] = { "ammo", "Reset ammo" } end
    buttons[#buttons + 1] = { "all", "Reset all" }
    for _, b in ipairs(buttons) do
        local btn = W.TextButton(row, b[2])
        btn:SetPoint("LEFT", x, 0)
        btn:SetScript("OnClick", function() AskResetStats(b[1]) end)
        x = x + btn:GetWidth() + 8
    end
    s.Add(row, 10)
end

-- The small window has its own size and opacity. While this page is open and
-- the small window is on, it shows next to settings as a live preview.
local function BuildMini(page)
    local s = Stacker(page)
    s.Heading("SMALL WINDOW", 0)
    s.Add(W.Checkbox(page, "Use the small window", "Steps and ammo in a small card, instead of this window.",
        function() return TM.db.window.small end,
        function(v) TM.UI:SetSmall(v) end))
    s.Add(W.Slider(page, "Size", nil, 70, 130, 5,
        function(v) return string.format("%d%%", v) end,
        function() return math.floor((TM.db.mini.scale or 1) * 100 + 0.5) end,
        function(v)
            TM.db.mini.scale = v / 100
            TM.Mini:ApplyLook()
        end))
    s.Add(W.Slider(page, "Opacity", nil, 20, 100, 5,
        function(v) return string.format("%d%%", v) end,
        function() return math.floor((TM.db.mini.opacity or 1) * 100 + 0.5) end,
        function(v)
            TM.db.mini.opacity = v / 100
            TM.Mini:ApplyLook()
        end))
    s.Add(W.Checkbox(page, "Hide during combat", "Off: it stays up so you can watch the fight live.",
        function() return TM.db.mini.hideInCombat end,
        function(v) TM.db.mini.hideInCombat = v end))

    -- Which shots get a row on the small window. Saved by English name so it
    -- works the same on every game language. Account-wide.
    if TM.Arrows and TM.Arrows.enabled then
        s.Heading("SHOTS TO SHOW")
        local hidden = function() return TM.db.ammo.miniHidden end
        local function Changed()
            for _, c in ipairs(page.shotBoxes) do c:Refresh() end
            TM.Mini:Refresh()
        end

        -- All · None links on the heading line.
        local function Link(label)
            local b = CreateFrame("Button", nil, page)
            b.text = W.Text(b, "bodyBold", T().sizes.heading, "accent", "RIGHT")
            b.text:SetPoint("RIGHT")
            b.text:SetText(label)
            b:SetSize(math.ceil(b.text:GetUnboundedStringWidth()) + 4, 18)
            b:SetScript("OnEnter", function(self) W.SetColor(self.text, "text") end)
            b:SetScript("OnLeave", function(self) W.SetColor(self.text, "accent") end)
            return b
        end
        local none = Link("NONE")
        local sep = W.Text(page, "bodyBold", T().sizes.heading, "muted", "RIGHT")
        local all = Link("ALL")
        local grid = CreateFrame("Frame", nil, page)

        local shots = TM.Arrows:ShotList()
        local ROW = 26
        local colW = (T().sizes.windowWidth - T().sizes.padding * 2) / 2
        grid:SetHeight(math.ceil(#shots / 2) * ROW)
        page.shotBoxes = {}
        for i, sh in ipairs(shots) do
            local box = W.Checkbox(grid, sh.name or sh.en, nil,
                function() return not hidden()[sh.en] end,
                function(v)
                    hidden()[sh.en] = (not v) or nil
                    TM.Mini:Refresh()
                end)
            box:SetWidth(colW - 8)
            box:SetPoint("TOPLEFT", ((i - 1) % 2) * colW, -math.floor((i - 1) / 2) * ROW)
            page.shotBoxes[i] = box
            Settings.controls[#Settings.controls + 1] = box
        end
        s.Add(grid, 10)
        -- Links sit on the heading's line, right side, 10 + 12 above the grid.
        none:SetPoint("BOTTOMRIGHT", grid, "TOPRIGHT", 0, 8)
        sep:SetPoint("RIGHT", none, "LEFT", -6, 0)
        sep:SetText("·")
        all:SetPoint("RIGHT", sep, "LEFT", -6, 0)
        all:SetScript("OnClick", function()
            wipe(hidden())
            Changed()
        end)
        none:SetScript("OnClick", function()
            for _, sh in ipairs(shots) do hidden()[sh.en] = true end
            Changed()
        end)

        s.Note("A shot shows once you know it or have used it. The small window shows while this page is open.", 12)
    else
        s.Note("While this page is open, the small window shows on screen so you can see your changes.", 16)
    end
end

local function BuildAmmo(page)
    local s = Stacker(page)
    local hunter = TM.Arrows and TM.Arrows.enabled
    if not hunter then
        s.Note("Ammo tracking is for hunters. These settings apply to your hunters.")
    end
    -- One amount drives both warnings; each can be turned on or off.
    s.Heading("LOW AMMO", hunter and 0 or 16)
    s.Add(W.NumberBox(page, "Warn me at", "When this many arrows or bullets are left, or fewer.", 1, 5000, 0,
        function() return TM.db.ammo.warnAt end,
        function(v)
            TM.db.ammo.warnAt = v
            TM.UI:Refresh()
        end), 8)

    s.Heading("HOW TO WARN ME")
    s.Add(W.Checkbox(page, "On the window", "Ammo card turns gold, with a bell and a reminder box.",
        function() return TM.db.ammo.warn end,
        function(v)
            TM.db.ammo.warn = v
            TM.UI:Refresh()
        end))
    s.Add(W.Checkbox(page, "Pop-up alert", "A short alert mid-screen, also during a fight.",
        function() return TM.db.ammo.popup end,
        function(v) TM.db.ammo.popup = v end))
    s.Add(W.Slider(page, "Pop-up shows for", nil, 1, 10, 1,
        function(v) return string.format("%d sec", v) end,
        function() return TM.db.ammo.popupSeconds end,
        function(v) TM.db.ammo.popupSeconds = v end))

    local test = W.TextButton(page, "Show a test alert")
    test:SetScript("OnClick", function() TM.Popup:ShowLowAmmo(math.max(0, (TM.db.ammo.warnAt or 200) - 1), true) end)
    s.Add(test, 16, true)

    -- Shots fired before the player installed Tallymark. Set (not added each
    -- time), so typing it again never counts it twice. Per character.
    if hunter then
        s.Heading("BEFORE TALLYMARK")
        s.Add(W.NumberBox(page, "Shots before Tallymark",
            "Arrows and bullets you used before you installed it. Added to All time.", 0, 9999999, 0,
            function() return TM.Arrows:Data().before or 0 end,
            function(v)
                TM.Arrows:Data().before = v
                TM.UI:Refresh()
            end))
    end
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
        "How far one step goes. 1 yard is about 0.9 m. Past steps don't change.", 0.3, 3, 2,
        function() return TM.db.journey.stride end,
        function(v) TM.db.journey.stride = v end))
end

local SECTIONS = {
    { key = "general", label = "General",      build = BuildGeneral },
    { key = "mini",    label = "Small window", build = BuildMini },
    { key = "ammo",    label = "Ammo",         build = BuildAmmo },
    { key = "journey", label = "Journey",      build = BuildJourney },
}

Settings.SECTIONS = SECTIONS
Settings.ResetToDefault = ResetToDefault

---------------------------------------------------------------------------
-- Hooks for the main window
---------------------------------------------------------------------------

-- Builds one page per section inside parent (the main window's content area).
-- Each section gets .page. The window makes the tab buttons.
function Settings:BuildPages(parent)
    self.controls = {}
    for _, sec in ipairs(SECTIONS) do
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page:Hide()
        sec.build(page)
        sec.page = page
    end
end

-- Re-read every control (called when settings open).
function Settings:Refresh()
    RefreshAll()
end

function Settings:Open(section)
    TM.db.window.shown = true
    TM.UI:GetFrame():Show()          -- settings always use the big window
    TM.UI:ShowSettings(true, section)
end

-- toStats: leave settings to the big window's stats (the gear button).
function Settings:Toggle(toStats)
    if TM.UI:IsSettingsShown() then
        TM.UI:ShowSettings(false, nil, toStats)
    else
        self:Open()
    end
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
