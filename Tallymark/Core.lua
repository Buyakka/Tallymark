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

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------

-- Account-wide settings (TallymarkDB).
local DB_DEFAULTS = {
    window = {
        shown    = false,
        point    = "CENTER",
        relPoint = "CENTER",
        x        = 0,
        y        = 0,
    },
}

-- Per character stats (TallymarkCharDB). Stats tables come in later steps.
local CHAR_DEFAULTS = {}

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
    FillDefaults(TallymarkCharDB, CHAR_DEFAULTS)

    TM.db = TallymarkDB
    TM.char = TallymarkCharDB
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local COMMANDS = {
    { "/tally",        "Show or hide the Tallymark window." },
    { "/tally help",   "List all commands." },
    { "/tally status", "Show version and saved settings." },
    { "/tally reset",  "Move the window back to the center." },
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

SLASH_TALLY1 = "/tally"
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
        TM:Print("Window moved to the center.")
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
        TM.UI:Init()
        TM:Print("v" .. TM.VERSION .. " loaded. Type /tally help")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
