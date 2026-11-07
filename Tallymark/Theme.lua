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

-- Custom fonts (Space Grotesk, Inter) arrive in Step 4.
-- Until then, use the game's standard font so nothing breaks.
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

Theme.fonts = {
    title = DEFAULT_FONT,
    body  = DEFAULT_FONT,
}

Theme.sizes = {
    windowWidth  = 420,
    windowHeight = 680,
    borderSize   = 1,
    padding      = 16,
    titleText    = 18,
    bodyText     = 12,
    footerText   = 12,
}

Theme.textures = {
    solid = "Interface\\Buttons\\WHITE8x8",
}

-- Wraps text in a color code for chat output. Example: Theme:Color("accent", "Tallymark")
function Theme:Color(key, text)
    local c = self.colors[key]
    if not c then return text end
    return "|cff" .. c.hex .. text .. "|r"
end
