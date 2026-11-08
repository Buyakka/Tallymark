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
    -- Ammo left at or under the "Warn me at" amount. Brighter than danger
    -- so it passes 4.5:1 contrast on the window and card backgrounds.
    lowAmmo       = Hex("FF6B6B"),
    lowAmmoBorder = Hex("B23A3A"),
}

-- Fonts: Space Grotesk Bold for the name and big numbers, Inter for the rest.
-- Both are SIL Open Font License (see Media/Fonts/OFL-*.txt).
-- If a font file fails to load, the game's standard font is used instead.
local FONT_DIR = "Interface\\AddOns\\Tallymark\\Media\\Fonts\\"

Theme.fallbackFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

Theme.fonts = {
    display  = FONT_DIR .. "SpaceGrotesk-Bold.ttf",  -- name and big numbers
    body     = FONT_DIR .. "Inter-Regular.ttf",      -- everything else
    bodyBold = FONT_DIR .. "Inter-SemiBold.ttf",     -- labels and headings
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

local MEDIA = "Interface\\AddOns\\Tallymark\\Media\\"

Theme.textures = {
    solid  = "Interface\\Buttons\\WHITE8x8",
    logo   = MEDIA .. "Logo",
    minimapIcon = MEDIA .. "Icons\\MinimapIcon",   -- arrowhead only, sits in the gold ring
    -- white icons, tinted with a theme color in game
    circle = MEDIA .. "Icons\\Circle",   -- used for rounded corners
    gear   = MEDIA .. "Icons\\Gear",
    close  = MEDIA .. "Icons\\Close",
    bell   = MEDIA .. "Icons\\Bell",
}

-- Corner radius per piece (pixels).
Theme.radius = {
    window = 8,
    card   = 6,
    button = 4,
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
