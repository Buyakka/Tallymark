-- Minimap.lua
-- Round button on the minimap edge with the seal logo.
-- Left-click: show or hide the window. Right-click: settings.
-- Drag: move the button around the minimap. Hover: quick stats.

local ADDON, TM = ...

local Button = {}
TM.MinimapButton = Button

-- Built like the standard minimap buttons other addons use: the game's own
-- gold tracking ring, dark round background and a small icon in the middle.
-- The newer UI (with the AddOns compartment) uses slightly different sizes.
local NEW_UI = AddonCompartmentFrame ~= nil
local SIZE = 31
local EDGE = 5   -- how far past the minimap edge the button sits

local BORDER_TEXTURE     = 136430   -- Interface\Minimap\MiniMap-TrackingBorder
local BACKGROUND_TEXTURE = 136467   -- Interface\Minimap\UI-Minimap-Background
local HIGHLIGHT_TEXTURE  = 136477   -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Places the button on the minimap edge at the saved angle (degrees).
local function UpdatePosition(btn)
    local angle = math.rad(TM.db.minimap.angle or 225)
    local radius = (Minimap:GetWidth() / 2) + EDGE
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Follows the cursor while dragging. Runs only during a drag, never otherwise.
local function DragUpdate(btn)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    TM.db.minimap.angle = math.floor(math.deg(math.atan2(cy - my, cx - mx)) + 0.5)
    UpdatePosition(btn)
end

local function AddLine(text, color)
    GameTooltip:AddLine(text, TM.Theme:RGB(color))
end

local function AddPair(left, right, rightColor)
    local lr, lg, lb = TM.Theme:RGB("muted")
    local rr, rg, rb = TM.Theme:RGB(rightColor or "text")
    GameTooltip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
end

local function ShowTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    AddLine("Tallymark", "accent")
    AddLine("Every step. Every shot.", "muted")
    GameTooltip:AddLine(" ")

    AddPair("Steps today", TM.Commas(TM.Journey:Data().today.steps))

    local A = TM.Arrows
    if A.enabled then
        local fight = A:CurrentFight()
        if fight then
            AddPair(A:AmmoWord(fight.shots):gsub("^%l", string.upper) .. " this fight",
                TM.Commas(fight.shots), "accent")
        end
        AddPair(A:AmmoWord(2):gsub("^%l", string.upper) .. " all time", TM.Commas(A:LifetimeTotal()))
        local n, state = A:AmmoCount()
        local label = A:AmmoWord(2):gsub("^%l", string.upper) .. " left"
        if state == "yes" then
            local at = TM:LowAmmoAt()
            AddPair(label, TM.Commas(n), (at and n < at) and "warning" or "text")
        elseif state == "none" then
            AddPair(label, "none equipped", "warning")
        end
        -- A secret count is skipped here: it can't be joined into tooltip text safely.
    end

    GameTooltip:AddLine(" ")
    AddLine("Left-click: show or hide the window", "footer")
    AddLine("Right-click: settings", "footer")
    AddLine("Drag: move this button", "footer")
    GameTooltip:Show()
end

function Button:Init()
    if not Minimap then return end

    local btn = CreateFrame("Button", nil, Minimap)
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetHighlightTexture(HIGHLIGHT_TEXTURE)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER_TEXTURE)
    border:SetPoint("TOPLEFT")

    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(BACKGROUND_TEXTURE)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(TM.Theme.textures.minimapIcon)

    if NEW_UI then
        border:SetSize(50, 50)
        background:SetSize(24, 24)
        background:SetPoint("CENTER")
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER")
    else
        border:SetSize(53, 53)
        background:SetSize(20, 20)
        background:SetPoint("TOPLEFT", 7, -5)
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
    end

    btn:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            TM.Settings:Toggle()
        else
            TM.UI:Toggle()
        end
        if GameTooltip:IsOwned(self) then ShowTooltip(self) end
    end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", DragUpdate)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    self.button = btn
    UpdatePosition(btn)
    btn:SetShown(not TM.db.minimap.hide)
end

function Button:SetHidden(hide)
    TM.db.minimap.hide = hide and true or false
    if self.button then self.button:SetShown(not hide) end
end
