-- Widgets.lua
-- Shared building blocks for every Tallymark window: text, rounded boxes,
-- icon buttons, and the settings controls (checkbox, slider, switch,
-- number box, button). All colors, fonts and sizes come from Theme.lua.

local ADDON, TM = ...

local W = {}
TM.W = W

local function T() return TM.Theme end

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------

function W.Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if not fs:SetFont(T().fonts[font], size, "") then
        fs:SetFont(T().fallbackFont, size, "")
    end
    fs:SetTextColor(T():RGB(color))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.SetColor(fs, color)
    fs:SetTextColor(T():RGB(color))
end

function W.Solid(parent, color, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(T().textures.solid)
    tex:SetVertexColor(T():RGB(color))
    if color == "barTrack" then   -- empty part of a bar fades with the window
        tex.tmTrack = true
        local o = TM.db and TM.db.window and tonumber(TM.db.window.opacity) or 1
        tex:SetAlpha(math.max(0.2, math.min(1, o)))
    end
    return tex
end

-- One rounded rectangle made of textures: 4 circle-quarter corners + 3 strips.
-- inset moves it in from the frame edges. Returns the list of textures.
local function RoundedLayer(f, radius, inset, sublevel)
    local tex = {}
    local function piece()
        local t = f:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        tex[#tex + 1] = t
        return t
    end
    local circle = T().textures.circle
    local corners = {
        { "TOPLEFT",     0,   0.5, 0,   0.5,  inset, -inset },
        { "TOPRIGHT",    0.5, 1,   0,   0.5, -inset, -inset },
        { "BOTTOMLEFT",  0,   0.5, 0.5, 1,    inset,  inset },
        { "BOTTOMRIGHT", 0.5, 1,   0.5, 1,   -inset,  inset },
    }
    for _, c in ipairs(corners) do
        local t = piece()
        t:SetTexture(circle)
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetSize(radius, radius)
        t:SetPoint(c[1], c[6], c[7])
    end
    local solid = T().textures.solid
    local mid = piece()          -- full height, between the corners
    mid:SetTexture(solid)
    mid:SetPoint("TOPLEFT", inset + radius, -inset)
    mid:SetPoint("BOTTOMRIGHT", -(inset + radius), inset)
    local left = piece()
    left:SetTexture(solid)
    left:SetPoint("TOPLEFT", inset, -(inset + radius))
    left:SetPoint("BOTTOMLEFT", inset, inset + radius)
    left:SetWidth(radius)
    local right = piece()
    right:SetTexture(solid)
    right:SetPoint("TOPRIGHT", -inset, -(inset + radius))
    right:SetPoint("BOTTOMRIGHT", -inset, inset + radius)
    right:SetWidth(radius)
    return tex
end

local function Tint(list, color)
    for _, t in ipairs(list) do t:SetVertexColor(T():RGB(color)) end
end

-- A frame with a rounded background and a 1px rounded border.
-- Pass the same color for bg and border for no visible border.
function W.Box(parent, bg, border, radius)
    local f = CreateFrame("Frame", nil, parent)
    radius = radius or T().radius.card
    local b = T().sizes.borderSize
    f.borderTex = RoundedLayer(f, radius, 0, -8)
    f.bgTex = RoundedLayer(f, math.max(1, radius - b), b, -7)
    Tint(f.borderTex, border)
    Tint(f.bgTex, bg)
    f.bgKey = bg
    W.ApplyBoxOpacity(f)
    return f
end

function W.SetBoxColors(f, bg, border)
    Tint(f.bgTex, bg)
    Tint(f.borderTex, border)
    f.bgKey = bg
    W.ApplyBoxOpacity(f)
end

-- Window and card backgrounds follow the "Background opacity" setting so the
-- game shows through. Text, buttons and warning boxes stay solid.
local SEE_THROUGH = { windowBg = true, cardBg = true, barTrack = true }

local function Opacity()
    local o = TM.db and TM.db.window and tonumber(TM.db.window.opacity) or 1
    return math.max(0.2, math.min(1, o))
end

function W.ApplyBoxOpacity(f)
    local a = SEE_THROUGH[f.bgKey] and Opacity() or 1
    for _, t in ipairs(f.bgTex) do t:SetAlpha(a) end
    for _, t in ipairs(f.borderTex) do t:SetAlpha(a) end
end

-- Re-apply opacity to every box and bar track inside a frame (after the
-- setting changes). Runs only on change, never per frame.
function W.ApplyOpacityTree(frame)
    if frame.bgTex then W.ApplyBoxOpacity(frame) end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.tmTrack then region:SetAlpha(Opacity()) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        W.ApplyOpacityTree(child)
    end
end

function W.Divider(parent)
    local line = W.Solid(parent, "border", "BORDER")
    line:SetHeight(T().sizes.borderSize)
    return line
end

-- Small tooltip helper: first line bright, the rest muted.
local function ShowTip(owner, lines, anchor)
    if not lines or #lines == 0 then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        GameTooltip:AddLine(line, T():RGB(i == 1 and "text" or "muted"))
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- Square icon button with a rounded border, like the design's gear and close.
-- tooltip is a function returning the lines to show on hover.
function W.IconButton(parent, texture, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(28, 28)
    local box = W.Box(btn, "windowBg", "border", T().radius.button)
    box:SetAllPoints()
    box:SetFrameLevel(btn:GetFrameLevel())
    btn.box = box

    btn.icon = box:CreateTexture(nil, "OVERLAY")   -- on the box, so the box doesn't cover it
    btn.icon:SetTexture(texture)
    btn.icon:SetSize(16, 16)
    btn.icon:SetPoint("CENTER")
    btn.color = "muted"
    btn.icon:SetVertexColor(T():RGB(btn.color))

    btn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(T():RGB("text"))
        W.SetBoxColors(self.box, "cardBg", "border")
        if tooltip then ShowTip(self, tooltip()) end
    end)
    btn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(T():RGB(self.color))
        W.SetBoxColors(self.box, "windowBg", "border")
        GameTooltip:Hide()
    end)
    return btn
end

-- Text button. primary = teal fill (like the design's Save), else outlined.
function W.TextButton(parent, label, primary)
    local S = T().sizes
    local btn = CreateFrame("Button", nil, parent)
    local box = W.Box(btn, primary and "accent" or "cardBg", primary and "accent" or "border",
        T().radius.button)
    box:SetAllPoints()
    box:SetFrameLevel(btn:GetFrameLevel())
    btn.box = box
    btn.text = W.Text(box, "bodyBold", S.bodyText, primary and "windowBg" or "text", "CENTER")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    btn:SetSize(btn.text:GetStringWidth() + 32, 32)
    btn:SetScript("OnEnter", function(self)
        if primary then
            self.box:SetAlpha(0.85)
        else
            W.SetBoxColors(self.box, "barTrack", "border")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if primary then
            self.box:SetAlpha(1)
        else
            W.SetBoxColors(self.box, "cardBg", "border")
        end
    end)
    return btn
end

---------------------------------------------------------------------------
-- Settings controls
-- Each takes get() and set(value). Call control:Refresh() to re-read get().
---------------------------------------------------------------------------

-- Label on the left, with an optional muted line under it.
local function LabelBlock(row, label, desc)
    local S = T().sizes
    row.label = W.Text(row, "body", S.bodyText, "text")
    row.label:SetText(label)
    if desc then
        row.desc = W.Text(row, "body", S.cardLabel, "muted")
        row.desc:SetText(desc)
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        -- Same right edge as the label, so it never runs under a box or value.
        row.desc:SetPoint("RIGHT", row.label, "RIGHT", 0, 0)
    end
end

-- Checkbox with a label. Click the box or the label.
function W.Checkbox(parent, label, desc, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(desc and 44 or 28)
    LabelBlock(row, label, desc)

    local box = W.Box(row, "cardBg", "border", T().radius.button)
    box:SetSize(20, 20)
    box:SetPoint("TOPLEFT", 0, -2)
    row.box = box
    row.label:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, -2)
    row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(T().textures.check)
    mark:SetSize(16, 16)
    mark:SetPoint("CENTER")
    mark:SetVertexColor(T():RGB("windowBg"))

    function row:Refresh()
        local on = get() and true or false
        mark:SetShown(on)
        if on then
            W.SetBoxColors(box, "accent", "accent")
        else
            W.SetBoxColors(box, "cardBg", "border")
        end
    end
    row:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    row:SetScript("OnEnter", function() W.SetColor(row.label, "accent") end)
    row:SetScript("OnLeave", function() W.SetColor(row.label, "text") end)
    row:Refresh()
    return row
end

-- Slider with a label on the left and the value on the right.
-- format(value) returns the text shown, for example "100%".
function W.Slider(parent, label, desc, minV, maxV, step, format, get, set)
    local S = T().sizes
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(desc and 62 or 46)
    LabelBlock(row, label, desc)
    row.label:SetPoint("TOPLEFT")
    row.label:SetPoint("RIGHT", row, "RIGHT", -60, 0)

    row.value = W.Text(row, "bodyBold", S.bodyText, "text", "RIGHT")
    row.value:SetPoint("TOPRIGHT")

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(16)
    slider:SetPoint("BOTTOMLEFT", 0, 0)
    slider:SetPoint("BOTTOMRIGHT", 0, 0)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    local track = W.Solid(slider, "barTrack", "BACKGROUND")
    track:SetHeight(S.barHeight)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    local fill = W.Solid(slider, "accent", "ARTWORK")
    fill:SetHeight(S.barHeight)
    fill:SetPoint("LEFT", track, "LEFT")

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(T().textures.circle)
    thumb:SetVertexColor(T():RGB("text"))
    thumb:SetSize(16, 16)
    slider:SetThumbTexture(thumb)

    local function Show(v)
        row.value:SetText(format(v))
        local width = slider:GetWidth()
        if not width or width <= 0 then width = 300 end
        fill:SetWidth(math.max(1, width * (v - minV) / (maxV - minV)))
    end

    local loading = false
    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if not loading then set(v) end
    end)
    slider:SetScript("OnSizeChanged", function() Show(slider:GetValue()) end)

    function row:Refresh()
        loading = true
        slider:SetValue(get())
        loading = false
        Show(get())
    end
    row.slider = slider
    row:Refresh()
    return row
end

-- Two or more choices side by side, one selected (like Miles | Kilometers).
-- options = { { value = "miles", text = "Miles" }, ... }
function W.Switch(parent, label, desc, options, get, set)
    local S = T().sizes
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(desc and 70 or 54)
    LabelBlock(row, label, desc)
    row.label:SetPoint("TOPLEFT")
    row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local group = W.Box(row, "cardBg", "border", T().radius.button)
    group:SetHeight(30)
    group:SetPoint("BOTTOMLEFT")
    local buttons, x = {}, 3
    for _, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, group)
        b.bg = W.Box(b, "cardBg", "cardBg", T().radius.button - 1)
        b.bg:SetAllPoints()
        b.bg:SetFrameLevel(b:GetFrameLevel())
        b.text = W.Text(b.bg, "bodyBold", S.bodyText, "muted", "CENTER")
        b.text:SetPoint("CENTER")
        b.text:SetText(opt.text)
        b:SetSize(b.text:GetStringWidth() + 28, 24)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 2
        b.value = opt.value
        b:SetScript("OnClick", function()
            set(opt.value)
            row:Refresh()
        end)
        buttons[#buttons + 1] = b
    end
    group:SetWidth(x + 1)

    function row:Refresh()
        local current = get()
        for _, b in ipairs(buttons) do
            local on = b.value == current
            W.SetBoxColors(b.bg, on and "accent" or "cardBg", on and "accent" or "cardBg")
            W.SetColor(b.text, on and "windowBg" or "muted")
        end
    end
    row:Refresh()
    return row
end

-- Number box with a label. Typed values are kept between minV and maxV.
-- decimals = how many digits after the dot are allowed (0 for whole numbers).
function W.NumberBox(parent, label, desc, minV, maxV, decimals, get, set)
    local S = T().sizes
    local row = CreateFrame("Frame", nil, parent)
    -- The note sits beside the box, so a longer one gets a second line.
    local twoLines = desc and #desc > 40
    row:SetHeight(twoLines and 60 or desc and 44 or 30)
    LabelBlock(row, label, desc)
    row.label:SetPoint("TOPLEFT", 0, -6)
    row.label:SetPoint("RIGHT", row, "RIGHT", -100, 0)
    if twoLines then
        row.desc:SetWordWrap(true)
        row.desc:SetMaxLines(2)
    end

    local box = W.Box(row, "cardBg", "border", T().radius.button)
    box:SetSize(84, 28)
    box:SetPoint("TOPRIGHT")

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAllPoints()
    edit:SetTextInsets(10, 10, 0, 0)
    edit:SetAutoFocus(false)
    edit:SetJustifyH("RIGHT")
    if not edit:SetFont(T().fonts.bodyBold, S.bodyText, "") then
        edit:SetFont(T().fallbackFont, S.bodyText, "")
    end
    edit:SetTextColor(T():RGB("text"))

    local function Format(v)
        if decimals > 0 then return string.format("%." .. decimals .. "f", v) end
        return tostring(math.floor(v + 0.5))
    end

    local function Commit()
        local v = tonumber(edit:GetText())
        if v then
            local m = 10 ^ decimals
            v = math.floor(v * m + 0.5) / m
            v = math.max(minV, math.min(maxV, v))
            set(v)
        end
        edit:SetText(Format(get()))
        edit:ClearFocus()
    end
    edit:SetScript("OnEnterPressed", Commit)
    edit:SetScript("OnEditFocusLost", Commit)
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText(Format(get()))
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function()
        W.SetBoxColors(box, "cardBg", "accent")
    end)
    edit:HookScript("OnEditFocusLost", function()
        W.SetBoxColors(box, "cardBg", "border")
    end)

    function row:Refresh()
        edit:SetText(Format(get()))
    end
    row:Refresh()
    return row
end

-- Heading in small caps style, muted.
function W.Heading(parent, text)
    local h = W.Text(parent, "bodyBold", T().sizes.heading, "muted")
    h:SetText(text)
    return h
end
