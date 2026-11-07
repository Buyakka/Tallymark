-- Core.lua
-- Startup, events, SavedVariables, migrations, slash commands.

local ADDON, TM = ...

-- Bump this when the saved data layout changes, and add a migration below.
TM.SCHEMA = 1

---------------------------------------------------------------------------
-- Version (read from the TOC so footer and TOC always match)
---------------------------------------------------------------------------

local function ReadVersion()
    local ok, v = pcall(function()
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            return C_AddOns.GetAddOnMetadata(ADDON, "Version")
        end
    end)
    if ok and type(v) == "string" and v ~= "" then
        return v
    end
    return "?"
end

TM.VERSION = ReadVersion()

---------------------------------------------------------------------------
-- Chat output (local chat frame only, never sent to other players)
---------------------------------------------------------------------------

function TM:Print(msg)
    local prefix = TM.Theme:Color("accent", "Tallymark") .. ": "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    end
end

-- 12345 -> "12,345"
function TM.Commas(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------

-- Account-wide settings (TallymarkDB).
local DB_DEFAULTS = {
    units = "miles",            -- "miles" or "km"
    window = {
        shown    = false,
        locked   = false,
        scale    = 1.0,         -- window size, 0.7 to 1.3
        opacity  = 1.0,         -- whole window (and small window), 0.2 to 1
        small    = false,       -- show the small window instead of the big one
        hideInCombat = false,
        point    = "CENTER",
        relPoint = "CENTER",
        x        = 0,
        y        = 0,
    },
    mini = {                    -- small window: own size, opacity and position
        scale    = 1.0,
        opacity  = 1.0,
        point    = "RIGHT",
        relPoint = "RIGHT",
        x        = -60,
        y        = 120,
    },
    minimap = {
        hide  = false,
        angle = 225,                -- degrees around the minimap (bottom left)
    },
    ammo = {
        warn   = true,              -- low ammo warning on the window (gold card, box)
        warnAt = 200,               -- warn below this many arrows or bullets
        popup        = true,        -- pop-up alert when ammo drops below warnAt
        popupSeconds = 3,           -- how long the pop-up stays before fading
    },
    journey = {
        stride = 1.0,               -- yards per step
    },
}
TM.DB_DEFAULTS = DB_DEFAULTS

-- The low ammo amount, or nil when the warning is turned off.
function TM:LowAmmoAt()
    local a = self.db and self.db.ammo
    if not a or not a.warn then return nil end
    return a.warnAt
end

-- Amount the pop-up alert fires below (same as the window warning), or nil
-- when the pop-up is off. Works even if the window warning is turned off.
function TM:PopupAt()
    local a = self.db and self.db.ammo
    if not a or not a.popup then return nil end
    return a.warnAt or 200
end

-- Per character stats (TallymarkCharDB). Each module adds its own table here
-- when its file loads (for example TM.CHAR_DEFAULTS.journey in Journey.lua).
TM.CHAR_DEFAULTS = {}

-- Copy any missing keys from defaults into t. Never overwrites existing values.
local function FillDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then
                t[k] = {}
            end
            FillDefaults(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
end

TM.FillDefaults = FillDefaults

-- The character's name and class file name (for the class color).
-- Stats are saved per character, so the window shows whose they are.
-- The realm is left out: on Forever it reads like "CAMWOW US1 Realm 7 PvE",
-- which means nothing to players.
function TM:CharName()
    local name = UnitName("player") or "?"
    local _, class = UnitClass("player")
    return name, class
end

-- Migrations: MIGRATIONS[n] upgrades a table from schema n-1 to schema n.
-- Never wipe data here. Only move or add.
local DB_MIGRATIONS = {
    -- [2] = function(db) end,
}
local CHAR_MIGRATIONS = {
    -- [2] = function(db) end,
}

local function Migrate(db, migrations)
    local from = tonumber(db.schema) or 0
    for n = from + 1, TM.SCHEMA do
        local fn = migrations[n]
        if fn then
            local ok, err = pcall(fn, db)
            if not ok then
                TM:Print("Migration to schema " .. n .. " failed: " .. tostring(err))
                return
            end
        end
        db.schema = n
    end
end

local function SetupDB()
    if type(TallymarkDB) ~= "table" then
        TallymarkDB = {}
    end
    if type(TallymarkCharDB) ~= "table" then
        TallymarkCharDB = {}
    end

    Migrate(TallymarkDB, DB_MIGRATIONS)
    Migrate(TallymarkCharDB, CHAR_MIGRATIONS)

    FillDefaults(TallymarkDB, DB_DEFAULTS)
    FillDefaults(TallymarkCharDB, TM.CHAR_DEFAULTS)

    TM.db = TallymarkDB
    TM.char = TallymarkCharDB
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local COMMANDS = {
    { "/tally  or  /tm", "Show or hide the Tallymark window." },
    { "/tally minimap", "Show or hide the minimap button." },
    { "/tally help",   "List all commands." },
    { "/tally settings", "Open settings (or click the gear)." },
    { "/tally status", "Show version and saved settings." },
    { "/tally reset",  "Move both windows back to where they started." },
    { "/tally test",   "Check what Tallymark can read here (try in and out of combat)." },
    { "/tally test shots", "List every tracked shot with its name in your game language." },
    { "/tally debug journey", "Show the last moves and your journey totals." },
    { "/tally debug arrows",  "Hunters: show ammo, fights and the last shots." },
}

local function PrintHelp()
    TM:Print("Commands:")
    for _, c in ipairs(COMMANDS) do
        TM:Print("  " .. TM.Theme:Color("text", c[1]) .. "  " .. TM.Theme:Color("muted", c[2]))
    end
end

local function PrintStatus()
    local w = TM.db.window
    TM:Print("Version " .. TM.VERSION)
    TM:Print("Account data schema: " .. tostring(TM.db.schema))
    TM:Print("Character data schema: " .. tostring(TM.char.schema))
    TM:Print(string.format("Window: %s, at %s %d, %d",
        w.shown and "shown" or "hidden", tostring(w.point), w.x or 0, w.y or 0))
end

---------------------------------------------------------------------------
-- /tally test: what can the addon read right here, right now?
-- Run it out of combat, in combat and inside a dungeon.
---------------------------------------------------------------------------

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function Shown(v)
    if v == nil then return "?" end
    if issecretvalue and issecretvalue(v) then return "secret" end
    return tostring(v)
end

local function YesNo(fn, ...)
    local v = SafeCall(fn, ...)
    if v == nil then return "?" end
    if issecretvalue and issecretvalue(v) then return "secret" end
    return v and "yes" or "no"
end

local function PrintTest()
    local T = TM.Theme
    local A = TM.Arrows

    TM:Print(T:Color("text", "Test") .. "  (Tallymark v" .. TM.VERSION .. ")")

    local version, build, _, toc = SafeCall(GetBuildInfo)
    TM:Print(string.format("  Client: interface %s, version %s, build %s", Shown(toc), Shown(version), Shown(build)))

    local inInstance, kind = SafeCall(IsInInstance)
    local where = Shown(SafeCall(GetRealZoneText))
    if inInstance == nil or (issecretvalue and issecretvalue(inInstance)) then
        where = where .. " (instance: " .. Shown(inInstance) .. ")"
    elseif inInstance then
        where = where .. " (inside " .. Shown(kind) .. " instance)"
    else
        where = where .. " (open world)"
    end
    TM:Print("  Where: " .. where .. ", in combat: " .. YesNo(UnitAffectingCombat, "player"))

    local pos = TM.Journey:PositionState()
    TM:Print("  Position readable: " .. T:Color(pos == "yes" and "accent" or "warning", pos))

    if not A.enabled then
        TM:Print("  Ammo and casts: hunters only.")
        return
    end

    local n, state = A:AmmoCount()
    local ammoText
    if state == "yes" then
        ammoText = T:Color("accent", "yes") .. " (" .. n .. " " .. A:AmmoWord(n) .. ")"
    elseif state == "secret" then
        ammoText = T:Color("warning", "secret")
    else
        ammoText = T:Color("warning", "no ammo equipped")
    end
    TM:Print("  Ammo count readable: " .. ammoText .. ", type: " .. A:AmmoKind())

    -- Shot list: does every spell ID turn into a name in this game language?
    local shots = A:ShotListCheck()
    local found, missing = 0, {}
    for _, s in ipairs(shots) do
        if s.name then found = found + 1 else missing[#missing + 1] = s.en .. " (" .. s.id .. ")" end
    end
    local shotLine = string.format("%d of %d found", found, #shots)
    TM:Print("  Shot list: " .. T:Color(#missing == 0 and "accent" or "warning", shotLine))
    if #missing > 0 then
        TM:Print("    " .. T:Color("warning", "Not found: " .. table.concat(missing, ", ")))
    end

    TM:Print(T:Color("text", "  Last casts (oldest first)"))
    local list = A:RecentCasts()
    if #list == 0 then TM:Print("    none yet") end
    for _, c in ipairs(list) do
        local ammo
        if c.drop == nil then
            ammo = T:Color("muted", "ammo: " .. (c.ammoState == "yes" and "unknown" or c.ammoState))
        elseif c.drop > 0 then
            ammo = T:Color("accent", "ammo -" .. c.drop)
        else
            ammo = T:Color("muted", "ammo no change")
        end
        TM:Print(string.format("    %s  %s  %s", c.name,
            c.counted and "counted" or T:Color("muted", "not counted"), ammo))
    end

    -- Which spells really use ammo? Flag the ones that disagree with the shot list.
    local stats = A:SpellStats()
    local names = {}
    for name in pairs(stats) do names[#names + 1] = name end
    table.sort(names)
    if #names > 0 then
        TM:Print(T:Color("text", "  This session: did ammo go down after the spell?"))
    end
    for _, name in ipairs(names) do
        local s = stats[name]
        local inList = A:IsShot(name)
        local note = ""
        if inList and s.drops == 0 then
            note = T:Color("warning", "  in shot list, but used no ammo")
        elseif not inList and s.drops > 0 then
            note = T:Color("warning", "  NOT in shot list, but ammo went down")
        end
        TM:Print(string.format("    %s: %d of %d casts%s", name, s.drops, s.casts, note))
    end
end

SLASH_TALLY1 = "/tally"
SLASH_TALLY2 = "/tm"
SlashCmdList["TALLY"] = function(msg)
    if not TM.db then return end
    local cmd = strtrim(msg or ""):lower()

    if cmd == "" then
        TM.UI:Toggle()
    elseif cmd == "help" then
        PrintHelp()
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "reset" then
        TM.UI:ResetPosition()
        TM:Print("Windows moved back to where they started.")
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        TM.Settings:Open()
    elseif cmd == "minimap" then
        local hide = not TM.db.minimap.hide
        TM.MinimapButton:SetHidden(hide)
        TM:Print(hide and "Minimap button hidden. Type /tally minimap to bring it back."
            or "Minimap button shown.")
    elseif cmd == "test" then
        PrintTest()
    elseif cmd == "test shots" then
        -- Every shot ID with the name the game gives it in this language.
        TM:Print("Shot list (spell ID: name in your game language)")
        for _, s in ipairs(TM.Arrows:ShotListCheck()) do
            local ids = tostring(s.id)
            for _, a in ipairs(s.alt or {}) do ids = ids .. "/" .. a end
            local text = s.name and (s.name .. (s.usedId ~= s.id and (" (found with " .. s.usedId .. ")") or ""))
                or TM.Theme:Color("warning", "not found (" .. s.en .. ")")
            TM:Print(string.format("  %s: %s", ids, text))
        end
    elseif cmd == "debug journey" then
        TM.Journey:PrintDebug()
    elseif cmd == "debug arrows" or cmd == "debug ammo" then
        TM.Arrows:PrintDebug()
    else
        TM:Print("Unknown command. Type /tally help")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        SetupDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if not TM.db then return end
        TM.Journey:Init()
        TM.Arrows:Init()
        TM.UI:Init()
        TM.MinimapButton:Init()
        TM.Settings:RegisterInGameOptions()
        TM:Print("v" .. TM.VERSION .. " loaded. Type /tally help")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
