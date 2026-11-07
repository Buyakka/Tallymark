-- Popup.lua
-- Low ammo alert: a small gold strip at the very top of the screen that fades
-- out quickly. Shown when ammo drops below the warning amount, and once after
-- login if already low. If you are in a fight it waits until the fight ends,
-- so it never covers your view while fighting. It ignores the mouse, so it
-- never blocks a click. Never shows anything based on a secret value.

local ADDON, TM = ...

local Popup = {}
TM.Popup = Popup

local SHOW_SECONDS = 2.5
local FADE_SECONDS = 0.5

local function T() return TM.Theme end
local W = TM.W

local function Build()
    local S = T().sizes
    local f = W.Box(UIParent, "warningBox", "warningBorder", T().radius.card)
    f:SetSize(330, 40)
    f:SetPoint("TOP", UIParent, "TOP", 0, -40)
    f:SetFrameStrata("HIGH")

    local bell = f:CreateTexture(nil, "OVERLAY")
    bell:SetTexture(T().textures.bell)
    bell:SetVertexColor(T():RGB("warning"))
    bell:SetSize(16, 16)
    bell:SetPoint("LEFT", 12, 0)

    f.text = W.Text(f, "bodyBold", S.bodyText, "warning")
    f.text:SetPoint("LEFT", bell, "RIGHT", 8, 0)
    f.text:SetPoint("RIGHT", -12, 0)

    -- Wait, then fade out, then hide. No per-frame code of our own.
    local anim = f:CreateAnimationGroup()
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(SHOW_SECONDS)
    fade:SetDuration(FADE_SECONDS)
    anim:SetScript("OnFinished", function() f:Hide() end)
    f.anim = anim

    f:Hide()
    return f
end

-- Holds an alert that came in during a fight, shown when the fight ends.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local text = Popup.pending
    Popup.pending = nil
    if text then Popup:Show(text) end
end)

function Popup:Show(text)
    if InCombatLockdown() or UnitAffectingCombat("player") then
        self.pending = text
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.frame = self.frame or Build()
    local f = self.frame
    f.anim:Stop()
    f:SetAlpha(1)
    f.text:SetText(text)
    f:Show()
    f.anim:Play()
end

-- count must be a readable number. force = show even if the pop-up setting is off (test button).
function Popup:ShowLowAmmo(count, force)
    if not force and not (TM.db.ammo.popup and TM:LowAmmoAt()) then return end
    local A = TM.Arrows
    local word = A and A.AmmoWord and A:AmmoWord(count) or "arrows"
    self:Show(string.format("Low ammo: %s %s left. Time to restock.", TM.Commas(count), word))
end
