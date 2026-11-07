-- Journey.lua
-- Distance, steps and travel types. Reads the player's position every 0.5s.

local ADDON, TM = ...

local Journey = {}
TM.Journey = Journey

local TICK_SECONDS   = 0.5
local MAX_YARDS_TICK = 100      -- bigger jumps are teleports, hearthstones, zoning
local MIN_YARDS_TICK = 0.05     -- ignore tiny jitter while standing still
local DEFAULT_STRIDE = 1.0      -- yards per step; the player can change it in settings
local YARDS_PER_MILE = 1760
local METERS_PER_YARD = 0.9144
local DEBUG_KEEP     = 10

-- Travel types, in the order they are checked each tick.
Journey.TYPES = { "flight", "ghost", "swim", "mounted", "foot" }
Journey.LABELS = {
    foot    = "On foot",
    mounted = "Mounted",
    flight  = "Flight paths",
    swim    = "Swimming",
    ghost   = "As a ghost",
}
local STEP_TYPES = { foot = true, ghost = true }

---------------------------------------------------------------------------
-- Safe reads (never throw, never compare a secret)
---------------------------------------------------------------------------

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

local function SafeBool(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    if not ok or IsSecret(v) then return false end
    return v and true or false
end

-- Returns x, y, instanceID or nil plus a reason.
local function ReadPosition()
    if type(UnitPosition) ~= "function" then return nil, "no api" end
    local ok, a, b, _, inst = pcall(UnitPosition, "player")
    if not ok then return nil, "error" end
    if a == nil or b == nil then return nil, "nil" end
    if IsSecret(a) or IsSecret(b) or IsSecret(inst) then return nil, "secret" end
    return a, b, inst
end

local function TravelType()
    if SafeBool(UnitOnTaxi, "player") then return "flight" end
    if SafeBool(UnitIsDeadOrGhost, "player") then return "ghost" end
    if SafeBool(IsSwimming) then return "swim" end
    if SafeBool(IsMounted) then return "mounted" end
    return "foot"
end

local function Today()
    return date("%Y-%m-%d")
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

-- Merged into TallymarkCharDB by Core (missing keys only, never overwrites).
TM.CHAR_DEFAULTS.journey = {
    yards = { foot = 0, mounted = 0, flight = 0, swim = 0, ghost = 0 },
    steps = 0,
    today = { date = "", steps = 0, yards = 0 },
}

local function Data()
    return TM.char.journey
end

local function CheckNewDay()
    local t = Data().today
    local d = Today()
    if t.date ~= d then
        t.date, t.steps, t.yards = d, 0, 0
    end
end

-- Current session lives in memory only.
local session = { yards = 0, steps = 0, started = 0 }
local last           -- { x, y, inst }
local debugTicks = {}

local function LogTick(entry)
    table.insert(debugTicks, entry)
    if #debugTicks > DEBUG_KEEP then
        table.remove(debugTicks, 1)
    end
end

---------------------------------------------------------------------------
-- Tick
---------------------------------------------------------------------------

local function Tick()
    local x, y, inst = ReadPosition()
    if not x then
        last = nil
        LogTick({ skip = y })   -- y holds the reason here
        return
    end

    if not last or last.inst ~= inst then
        last = { x = x, y = y, inst = inst }
        LogTick({ skip = "start" })
        return
    end

    local dx, dy = x - last.x, y - last.y
    local dist = math.sqrt(dx * dx + dy * dy)
    last.x, last.y = x, y

    if dist > MAX_YARDS_TICK then
        LogTick({ skip = "jump", dist = dist })
        return
    end
    if dist < MIN_YARDS_TICK then
        return
    end

    local kind = TravelType()
    local d = Data()
    CheckNewDay()

    d.yards[kind] = (d.yards[kind] or 0) + dist
    d.today.yards = d.today.yards + dist
    session.yards = session.yards + dist

    if STEP_TYPES[kind] then
        local stride = (TM.db.journey and tonumber(TM.db.journey.stride)) or DEFAULT_STRIDE
        if stride <= 0 then stride = DEFAULT_STRIDE end
        local steps = dist / stride
        d.steps = d.steps + steps
        d.today.steps = d.today.steps + steps
        session.steps = session.steps + steps
    end

    LogTick({ kind = kind, dist = dist })
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Read-only helpers for the window.
function Journey:Data()
    CheckNewDay()
    return Data()
end
function Journey:Session() return session end

-- "yes", "nil", "secret", "no api" or "error". Used by /tally test.
function Journey:PositionState()
    local x, reason = ReadPosition()
    if x then return "yes" end
    return reason
end

function Journey:TotalYards()
    local total = 0
    for _, v in pairs(Data().yards) do total = total + v end
    return total
end

-- Formats yards as miles or km, based on the account setting.
function Journey:FormatDistance(yards)
    if TM.db.units == "km" then
        return string.format("%.2f km", yards * METERS_PER_YARD / 1000)
    end
    return string.format("%.2f mi", yards / YARDS_PER_MILE)
end

function Journey:Init()
    CheckNewDay()
    session.started = GetTime()
    self.ticker = C_Timer.NewTicker(TICK_SECONDS, Tick)

    local f = CreateFrame("Frame")
    -- Loading screens move you far away. Start fresh after each one.
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() last = nil end)
end

function Journey:PrintDebug()
    local T = TM.Theme
    local d = Data()
    CheckNewDay()

    TM:Print(T:Color("text", "Journey: last ticks (oldest first)"))
    if #debugTicks == 0 then
        TM:Print("  none yet")
    end
    for _, e in ipairs(debugTicks) do
        if e.skip then
            local extra = e.dist and string.format(" (%.1f yd)", e.dist) or ""
            TM:Print(T:Color("muted", "  skipped: " .. e.skip .. extra))
        else
            TM:Print(string.format("  %s  %.2f yd", self.LABELS[e.kind], e.dist))
        end
    end

    TM:Print(T:Color("text", "Lifetime"))
    TM:Print(string.format("  Steps: %d   Distance: %s",
        math.floor(d.steps), self:FormatDistance(self:TotalYards())))
    for _, kind in ipairs({ "foot", "mounted", "flight", "swim", "ghost" }) do
        TM:Print(string.format("  %s: %s", self.LABELS[kind], self:FormatDistance(d.yards[kind] or 0)))
    end

    TM:Print(T:Color("text", "Today") .. string.format("  Steps: %d   Distance: %s",
        math.floor(d.today.steps), self:FormatDistance(d.today.yards)))
    TM:Print(T:Color("text", "This session") .. string.format("  Steps: %d   Distance: %s",
        math.floor(session.steps), self:FormatDistance(session.yards)))
end
