-- Theme.lua
-- The only place for colors, fonts and sizes. Do not hard-code these anywhere else.

local ADDON, TM = ...

local function Hex(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
        hex = hex,
    }
end

local Theme = {}
TM.Theme = Theme

Theme.name = "Shadow"

Theme.colors = {
    windowBg      = Hex("14171C"),
    border        = Hex("2C333D"),
    cardBg        = Hex("1E232B"),
    barTrack      = Hex("262C35"),
    text          = Hex("E8ECF1"),
    muted         = Hex("9AA4B2"),
    footer        = Hex("8A94A3"),
    accent        = Hex("3DD6A3"),
    warning       = Hex("F2C14E"),
    warningBox    = Hex("2A2310"),
    warningBorder = Hex("B8860B"),
    danger        = Hex("E5484D"),
}

-- Custom fonts (Space Grotesk for the name and big numbers, Inter for the rest)
-- will be dropped into Media/Fonts. Until then, use the game's standard font.
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

Theme.fonts = {
    display = DEFAULT_FONT,   -- name and big numbers (Space Grotesk Bold later)
    body    = DEFAULT_FONT,   -- everything else (Inter later)
    bodyBold = DEFAULT_FONT,  -- labels and headings (Inter SemiBold later)
}

Theme.sizes = {
    windowWidth  = 420,
    windowHeight = 680,
    borderSize   = 1,
    padding      = 16,
    gap          = 8,

    logo         = 32,
    headerHeight = 64,
    tabHeight    = 32,
    tabUnderline = 2,
    footerHeight = 40,

    cardHeight   = 64,
    rowHeight    = 24,
    barHeight    = 6,
    dot          = 8,

    -- text (12 is the smallest size anywhere)
    titleText    = 20,
    taglineText  = 12,
    tabText      = 14,
    bigNumber    = 56,
    bigLabel     = 14,
    cardLabel    = 12,
    cardValue    = 20,
    heading      = 12,
    bodyText     = 13,
    footerText   = 12,
}

-- Fixed in 0.1.0. Becomes a setting in 0.2.0.
Theme.lowAmmo = 200

Theme.textures = {
    solid = "Interface\\Buttons\\WHITE8x8",
    logo  = "Interface\\AddOns\\Tallymark\\Media\\Logo",
}

-- Wraps text in a color code for chat output. Example: Theme:Color("accent", "Tallymark")
function Theme:Color(key, text)
    local c = self.colors[key]
    if not c then return text end
    return "|cff" .. c.hex .. text .. "|r"
end

-- Returns r, g, b, a for a color key.
function Theme:RGB(key, alpha)
    local c = self.colors[key]
    return c.r, c.g, c.b, alpha or 1
end
