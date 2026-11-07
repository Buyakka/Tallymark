-- Popup.lua
-- Low ammo alert: a small gold box in the upper middle of the screen that
-- shows right away (also during a fight) and fades out after a few seconds
-- (Settings > Ammo). It ignores the mouse, so it never blocks a click.
-- Shown when ammo drops below the pop-up amount, and once after login if
-- already low. Never shows anything based on a secret value.

local ADDON, TM = ...

local Popup = {}
TM.Popup = Popup

local FADE_SECONDS = 0.5

local function T() return TM.Theme end
local W = TM.W

local function Build()
    local S = T().sizes
    local f = W.Box(UIParent, "warningBox", "warningBorder", T().radius.card)
    f:SetSize(330, 40)              -- width is set to fit the message in Popup:Show
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
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
    fade:SetDuration(FADE_SECONDS)
    anim:SetScript("OnFinished", function() f:Hide() end)
    f.anim = anim
    f.fade = fade

    f:Hide()
    return f
end

function Popup:Show(text)
    self.frame = self.frame or Build()
    local f = self.frame
    f.anim:Stop()
    f:SetAlpha(1)
    local secs = TM.db and TM.db.ammo.popupSeconds or 3
    f.fade:SetStartDelay(math.max(1, math.min(10, secs)))
    f.text:SetText(text)
    -- Size the box to the message so it is never cut off ("Time to re...").
    -- 12 + 16 bell + 8 gap on the left, 16 on the right.
    local w = f.text.GetUnboundedStringWidth and f.text:GetUnboundedStringWidth() or f.text:GetStringWidth()
    f:SetWidth(math.max(240, math.ceil(w) + 52))
    f:Show()
    f.anim:Play()
end

-- count must be a readable number. force = show even if the pop-up setting is off (test button).
function Popup:ShowLowAmmo(count, force)
    if not force and not TM:PopupAt() then return end
    local A = TM.Arrows
    local word = A and A.AmmoWord and A:AmmoWord(count) or "arrows"
    self:Show(string.format("Low ammo: %s %s left. Time to restock.", TM.Commas(count), word))
end
