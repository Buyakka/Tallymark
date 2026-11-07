-- Arrows.lua
-- Hunters only. Counts shots live (arrows or bullets), per fight, per dungeon and lifetime.
-- Also reads ammo left from the ammo slot as a second source.
-- Never reads enemy names or GUIDs. Zone name and time only.

local ADDON, TM = ...

local Arrows = {}
TM.Arrows = Arrows

local AMMO_SLOT      = INVSLOT_AMMO or 0
local RANGED_SLOT    = INVSLOT_RANGED or 18
local CLASS_PROJECTILE = 6
local SUBCLASS_ARROW   = 2
local SUBCLASS_BULLET  = 3
local KEEP_FIGHTS    = 50
local KEEP_DUNGEONS  = 20
local KEEP_CASTS     = 10
local PULL_WINDOW    = 2    -- seconds: a shot right before combat starts counts for that fight

-- Shots that may use ammo, by spell ID (rank 1 of each).
-- The game gives us the name in the player's own language for each ID, so
-- counting works on German, French, Spanish and other clients too.
-- All ranks of a spell share the same name, so one ID per spell is enough.
-- Some of these may not use ammo in Forever. /tally test checks this, and
-- also checks that every ID below turns into a real spell name.
local SHOT_IDS = {
    { id = 75,    en = "Auto Shot" },
    { id = 3044,  en = "Arcane Shot" },
    { id = 19434, en = "Aimed Shot" },
    { id = 2643,  en = "Multi-Shot" },
    { id = 5116,  en = "Concussive Shot" },
    { id = 19503, en = "Scatter Shot" },
    { id = 20736, en = "Distracting Shot" },
    { id = 19801, en = "Tranquilizing Shot" },
    { id = 1978,  en = "Serpent Sting" },
    { id = 3034,  en = "Viper Sting" },
    { id = 3043,  en = "Scorpid Sting" },
    -- Wyvern Sting (classic IDs 19386, 24132, 24133) is not listed: none of those
    -- IDs exist in the Forever client (checked in game on 1.60.1 build 70840),
    -- and guides list it as a classic talent removed in Forever.
    -- If it comes back, add: { id = 19386, en = "Wyvern Sting", alt = { 24132, 24133 } },
    -- (alt = other rank IDs to try if the main one isn't found.)
}

-- Name -> true. Filled with the English names now, and with the player's
-- language names in Arrows:Init (BuildShotNames).
local SHOTS = {}
for _, s in ipairs(SHOT_IDS) do SHOTS[s.en] = true end
local UNKNOWN_SHOT = "Unknown shot"

---------------------------------------------------------------------------
-- Safe reads
---------------------------------------------------------------------------

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function SafeBool(fn, ...)
    local v = Safe(fn, ...)
    if v == nil or IsSecret(v) then return false end
    return v and true or false
end

-- "arrow", "bullet", "none" or "unknown"
local function ReadAmmoKind()
    local id = Safe(GetInventoryItemID, "player", AMMO_SLOT)
    if id == nil then return "none" end
    if IsSecret(id) then return "unknown" end
    if not (C_Item and C_Item.GetItemInfoInstant) then return "unknown" end
    local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, id)
    if not ok or IsSecret(classID) or IsSecret(subClassID) then return "unknown" end
    if classID == CLASS_PROJECTILE then
        if subClassID == SUBCLASS_ARROW then return "arrow" end
        if subClassID == SUBCLASS_BULLET then return "bullet" end
    end
    return "unknown"
end

-- Returns value, state. state is "yes", "secret" or "none".
-- A secret value can be shown with SetText but never used in math.
local function ReadAmmoCount()
    local id = Safe(GetInventoryItemID, "player", AMMO_SLOT)
    if id == nil then return nil, "none" end
    local n = Safe(GetInventoryItemCount, "player", AMMO_SLOT)
    if n == nil then return nil, "none" end
    if IsSecret(n) then return n, "secret" end
    return n, "yes"
end

local function HasRangedWeapon()
    local id = Safe(GetInventoryItemID, "player", RANGED_SLOT)
    return id ~= nil
end

local function SafeText(fn)
    local s = Safe(fn)
    if type(s) == "string" and not IsSecret(s) and s ~= "" then return s end
    return nil
end

-- Zone, for example "Dun Morogh" or "The Deadmines".
local function ZoneName()
    return SafeText(GetRealZoneText) or SafeText(GetInstanceInfo) or "Unknown zone"
end

-- Returns zone, subzone, continent. Subzone and continent may be nil.
-- In the open world GetInstanceInfo gives the continent ("Eastern Kingdoms").
-- Inside a dungeon it gives the dungeon name, so there is no continent then.
local function Location()
    local zone = ZoneName()
    local sub = SafeText(GetSubZoneText)
    if sub == zone then sub = nil end

    local continent
    local inInstance = Safe(IsInInstance)
    if not IsSecret(inInstance) and not inInstance then
        continent = SafeText(GetInstanceInfo)
        if continent == zone then continent = nil end
    end
    return zone, sub, continent
end

-- "Coldridge Valley, Dun Morogh", or just "Dun Morogh" when there is no area name.
function Arrows:ShortPlace(f)
    if f.subzone then return f.subzone .. ", " .. f.zone end
    return f.zone
end

-- Same, plus the continent when known.
function Arrows:FullPlace(f)
    local s = self:ShortPlace(f)
    if f.continent then s = s .. ", " .. f.continent end
    return s
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

TM.CHAR_DEFAULTS.arrows = {
    lifetime   = { total = 0, arrow = 0, bullet = 0, unknown = 0 },
    byShot     = {},        -- lifetime count per shot name
    fights     = {},        -- last KEEP_FIGHTS fights, newest last
    fightCount = 0,
    dungeons   = {},        -- last KEEP_DUNGEONS dungeon runs, newest last
    dungeon    = nil,       -- the open dungeon run, kept across /reload
    lastAmmo   = nil,       -- last readable ammo count
}

local function Data()
    return TM.char.arrows
end

-- In memory only.
local fight            -- the current fight, nil out of combat
local merchantOpen = false
local pending = {}     -- shots just before combat started: { t, name }
local casts = {}       -- last few player casts, for debug and /tally test
local spellStats = {}  -- this session: spell name -> { casts, drops } (did ammo go down after it)

local function PushLimited(list, item, limit)
    table.insert(list, item)
    while #list > limit do
        table.remove(list, 1)
    end
end

local function UpdateAmmo()
    local n, state = ReadAmmoCount()
    if state == "yes" then
        Data().lastAmmo = n
    end
    return n, state
end

---------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------

local function AddToFight(name)
    fight.shots = fight.shots + 1
    fight.byShot[name] = (fight.byShot[name] or 0) + 1
end

local function CountShot(name)
    local d = Data()
    local kind = ReadAmmoKind()
    if kind ~= "arrow" and kind ~= "bullet" then kind = "unknown" end

    d.lifetime.total = d.lifetime.total + 1
    d.lifetime[kind] = (d.lifetime[kind] or 0) + 1
    d.byShot[name] = (d.byShot[name] or 0) + 1

    if d.dungeon then
        d.dungeon.shots = d.dungeon.shots + 1
    end

    if fight then
        AddToFight(name)
    else
        -- Ammo read now is still the count BEFORE this shot.
        -- The game removes the bullet or arrow a moment after this event.
        local ammo, state = ReadAmmoCount()
        PushLimited(pending, {
            t = GetTime(),
            name = name,
            ammoBefore = (state == "yes") and ammo or nil,
        }, 5)
    end
end

local function OnSpellcast(spellID)
    local name, counted

    if IsSecret(spellID) then
        name = "secret"
        -- Can't read the spell. Count it only if we have a bow or gun and are in a fight.
        if fight and HasRangedWeapon() then
            CountShot(UNKNOWN_SHOT)
            counted = true
        end
    else
        local n = C_Spell and C_Spell.GetSpellName and Safe(C_Spell.GetSpellName, spellID)
        if n == nil or IsSecret(n) then
            name = "secret"
        else
            name = n
            if SHOTS[n] then
                CountShot(n)
                counted = true
            end
        end
    end

    local ammo, state = ReadAmmoCount()

    -- The count now is the "after" for the previous cast. Learn which spells use ammo.
    local prev = casts[#casts]
    if prev and prev.ammo and state == "yes" then
        prev.after = ammo
        local drop = prev.ammo - ammo
        if prev.name ~= "secret" then
            local s = spellStats[prev.name] or { casts = 0, drops = 0 }
            s.casts = s.casts + 1
            if drop > 0 then s.drops = s.drops + 1 end
            spellStats[prev.name] = s
        end
    end

    PushLimited(casts, {
        name = name,
        counted = counted or false,
        ammo = (state == "yes") and ammo or nil,
        ammoState = state,
    }, KEEP_CASTS)
end

---------------------------------------------------------------------------
-- Fights
---------------------------------------------------------------------------

local function StartFight()
    local n, state = UpdateAmmo()
    local zone, subzone, continent = Location()
    fight = {
        date      = time(),
        started   = GetTime(),
        zone      = zone,
        subzone   = subzone,
        continent = continent,
        kind      = ReadAmmoKind(),
        shots     = 0,
        byShot    = {},
        startAmmo = (state == "yes") and n or nil,
        merchant  = merchantOpen,
    }

    -- Shots fired in the last moment before combat (the pull) belong to this fight.
    -- Start the ammo check from the count before the first pull shot.
    local now = GetTime()
    local firstPull = true
    for _, p in ipairs(pending) do
        if now - p.t <= PULL_WINDOW then
            AddToFight(p.name)
            if firstPull then
                fight.startAmmo = p.ammoBefore
                firstPull = false
            end
        end
    end
    wipe(pending)

    if Data().dungeon then
        Data().dungeon.fights = Data().dungeon.fights + 1
    end
end

local function EndFight()
    if not fight then return end
    local d = Data()
    local n, state = UpdateAmmo()

    local ammoDelta
    if fight.startAmmo and state == "yes" and not fight.merchant and not merchantOpen then
        ammoDelta = fight.startAmmo - n
    end

    if fight.shots > 0 or (ammoDelta and ammoDelta > 0) then
        d.fightCount = d.fightCount + 1
        PushLimited(d.fights, {
            n         = d.fightCount,
            date      = fight.date,
            zone      = fight.zone,
            subzone   = fight.subzone,
            continent = fight.continent,
            kind      = fight.kind,
            duration  = math.floor(GetTime() - fight.started + 0.5),
            shots     = fight.shots,
            byShot    = fight.byShot,
            ammoDelta = ammoDelta,
        }, KEEP_FIGHTS)
    end
    fight = nil
end

---------------------------------------------------------------------------
-- Dungeons
---------------------------------------------------------------------------

local function CloseDungeon()
    local d = Data()
    local run = d.dungeon
    if not run then return end
    run.ended = time()
    PushLimited(d.dungeons, run, KEEP_DUNGEONS)
    d.dungeon = nil
end

local function CheckInstance()
    local d = Data()
    local inInstance, kind = Safe(IsInInstance)
    if IsSecret(inInstance) or IsSecret(kind) then return end

    if inInstance and (kind == "party" or kind == "raid") then
        local zone = ZoneName()
        if d.dungeon and d.dungeon.zone == zone then
            return  -- same run, for example after a /reload
        end
        CloseDungeon()
        d.dungeon = { zone = zone, started = time(), shots = 0, fights = 0 }
    else
        CloseDungeon()
    end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function Arrows:IsHunter()
    local class = Safe(UnitClassBase, "player")
    return not IsSecret(class) and class == "HUNTER"
end

-- "arrows" or "bullets", for labels. Pass a count to get "1 bullet" right.
-- Pass a kind ("arrow"/"bullet") to use a saved fight's ammo instead of what is equipped now.
function Arrows:AmmoWord(count, kind)
    kind = kind or ReadAmmoKind()
    local word = kind == "bullet" and "bullet" or "arrow"
    if count == 1 then return word end
    return word .. "s"
end

-- Read-only helpers for the window.
function Arrows:Data() return Data() end
function Arrows:CurrentFight() return fight end
function Arrows:LastFight()
    local list = Data().fights
    return list[#list]
end
-- Returns value, state ("yes", "secret", "none").
function Arrows:AmmoCount() return ReadAmmoCount() end
function Arrows:AmmoKind() return ReadAmmoKind() end
function Arrows:IsShot(name) return SHOTS[name] == true end

-- Last casts, oldest first. Each has name, counted, ammo (before), ammoState,
-- and drop: how much ammo went down after it (nil if unknown).
function Arrows:RecentCasts()
    local list = {}
    local now, state = ReadAmmoCount()
    for i, c in ipairs(casts) do
        local after = c.after
        if after == nil and i == #casts and state == "yes" then after = now end
        local drop
        if c.ammo and after then drop = c.ammo - after end
        list[i] = { name = c.name, counted = c.counted, ammoState = c.ammoState, drop = drop }
    end
    return list
end

function Arrows:SpellStats() return spellStats end

-- Looks up each shot's name in the player's language.
-- Keeps the result per ID so /tally test can show what was found.
local function BuildShotNames()
    local function Lookup(id)
        local name = C_Spell and C_Spell.GetSpellName and Safe(C_Spell.GetSpellName, id)
        if type(name) == "string" and not IsSecret(name) and name ~= "" then return name end
    end
    for _, s in ipairs(SHOT_IDS) do
        s.name, s.usedId = nil, nil
        -- Try the main ID, then any other ranks listed in alt.
        local ids = { s.id }
        for _, a in ipairs(s.alt or {}) do ids[#ids + 1] = a end
        for _, id in ipairs(ids) do
            local name = Lookup(id)
            if name then
                s.name, s.usedId = name, id
                SHOTS[name] = true
                break
            end
        end
    end
end

-- For /tally test: { id, en, name } for every shot. name is nil if the ID didn't resolve.
function Arrows:ShotListCheck()
    if not self.enabled then BuildShotNames() end   -- non-hunters never ran Init's lookup
    return SHOT_IDS
end

function Arrows:Init()
    if not self:IsHunter() then return end
    self.enabled = true
    BuildShotNames()

    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    f:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("MERCHANT_CLOSED")

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            OnSpellcast(spellID)
        elseif event == "PLAYER_REGEN_DISABLED" then
            StartFight()
        elseif event == "PLAYER_REGEN_ENABLED" then
            EndFight()
        elseif event == "PLAYER_ENTERING_WORLD" then
            CheckInstance()
            UpdateAmmo()
        elseif event == "MERCHANT_SHOW" then
            merchantOpen = true
            if fight then fight.merchant = true end
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
        else
            UpdateAmmo()
        end
        -- Let the window update its numbers (it does nothing while hidden).
        if TM.UI and TM.UI.Refresh then TM.UI:Refresh() end
    end)

    -- Logged in or reloaded mid-fight.
    if SafeBool(UnitAffectingCombat, "player") then
        StartFight()
    end
    CheckInstance()
    UpdateAmmo()
end

local function FormatTime(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function SortedCounts(t)
    local list = {}
    for name, n in pairs(t) do list[#list + 1] = { name = name, n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    return list
end

function Arrows:PrintDebug()
    local T = TM.Theme
    if not self.enabled then
        TM:Print("Arrow tracking is for hunters only.")
        return
    end
    local d = Data()
    local word = self:AmmoWord()

    local n, state = ReadAmmoCount()
    local ammoText
    if state == "none" then
        ammoText = "no ammo equipped"
    elseif state == "secret" then
        ammoText = "hidden right now (secret)"
    else
        ammoText = tostring(n) .. " " .. self:AmmoWord(n)
    end
    TM:Print(T:Color("text", "Ammo: ") .. ReadAmmoKind() .. ", " .. ammoText)

    if fight then
        TM:Print(T:Color("accent", "In combat") .. string.format("  %d %s this fight, %s",
            fight.shots, self:AmmoWord(fight.shots), FormatTime(math.floor(GetTime() - fight.started))))
    end
    if d.dungeon then
        TM:Print(T:Color("text", "Dungeon: ") .. string.format("%s, %d %s, %d fights",
            d.dungeon.zone, d.dungeon.shots, self:AmmoWord(d.dungeon.shots), d.dungeon.fights))
    end

    TM:Print(T:Color("text", "Lifetime") .. string.format("  %d shots (%d arrows, %d bullets, %d unknown)",
        d.lifetime.total, d.lifetime.arrow, d.lifetime.bullet, d.lifetime.unknown))
    for _, s in ipairs(SortedCounts(d.byShot)) do
        TM:Print(string.format("  %s: %d", s.name, s.n))
    end

    TM:Print(T:Color("text", "Last fights"))
    if #d.fights == 0 then TM:Print("  none yet") end
    for i = math.max(1, #d.fights - 4), #d.fights do
        local f = d.fights[i]
        local check = ""
        if f.ammoDelta then
            check = "  ammo used: " .. f.ammoDelta
            if f.ammoDelta ~= f.shots then
                check = check .. T:Color("warning", " (differs)")
            end
        end
        TM:Print(string.format("  %s · fight %d  %d %s · %s%s",
            self:FullPlace(f), f.n, f.shots, self:AmmoWord(f.shots, f.kind), FormatTime(f.duration), check))
    end

    TM:Print(T:Color("text", "Last casts (oldest first)"))
    if #casts == 0 then TM:Print("  none yet") end
    for _, c in ipairs(casts) do
        local ammo = c.ammo and ("ammo before shot: " .. c.ammo) or ("ammo: " .. c.ammoState)
        TM:Print(string.format("  %s  %s  %s", c.name,
            c.counted and T:Color("accent", "counted") or T:Color("muted", "not counted"),
            T:Color("muted", ammo)))
    end
end
