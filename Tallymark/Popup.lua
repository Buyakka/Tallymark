-- Popup.lua
-- Low ammo alert: a small gold box near the top of the screen that fades out.
-- Shown when ammo drops below the warning amount, and once after login if
-- already low. Never shows anything based on a secret value.

local ADDON, TM = ...

local Popup = {}
TM.Popup = Popup

local SHOW_SECONDS = 5
local FADE_SECONDS = 1

local function T() return TM.Theme end
local W = TM.W

local function Build()
    local S = T().sizes
    local f = W.Box(UIParent, "warningBox", "warningBorder", T().radius.card)
    f:SetSize(380, 52)
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    f:SetFrameStrata("HIGH")

    local bell = f:CreateTexture(nil, "OVERLAY")
    bell:SetTexture(T().textures.bell)
    bell:SetVertexColor(T():RGB("warning"))
    bell:SetSize(20, 20)
    bell:SetPoint("LEFT", 16, 0)

    f.text = W.Text(f, "bodyBold", S.bodyText + 1, "warning")
    f.text:SetPoint("LEFT", bell, "RIGHT", 10, 0)
    f.text:SetPoint("RIGHT", -16, 0)

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

function Popup:Show(text)
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
