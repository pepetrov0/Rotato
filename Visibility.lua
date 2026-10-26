local ADDON_NAME, ns = ...

local FADE_OUT_TIME = 0.25 -- showing is instant, only hiding fades
local HIDE_DELAY = 3   -- seconds of calm before fading out, avoids flicker between pulls
local POLL = 0.1

-- "Dangerous" for now: in combat, a living hostile target selected (about to pull),
-- or the frame being positioned (Shift held with the cursor over it, so Shift alone does nothing). Returns the reason, or nil when calm.
local function DangerReason()
    if UnitAffectingCombat("player") then return "in combat" end
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
        return "hostile target"
    end
    if ns.frame.dragging or (IsShiftKeyDown() and ns.frame:IsMouseOver()) then return "positioning" end
end

function ns.InitVisibility()
    local f = ns.frame
    local shown, calm, acc = false, 0, 0
    f:SetAlpha(0)

    local function Check(dt)
        local reason = DangerReason()
        if reason then
            calm = 0
            if not shown then
                shown = true
                UIFrameFadeRemoveFrame(f) -- cancel a fade-out in progress
                f:SetAlpha(1)
                ns.Print("showing (" .. reason .. ")")
            end
        elseif shown then
            calm = calm + dt
            if calm >= HIDE_DELAY then
                shown = false
                UIFrameFadeOut(f, FADE_OUT_TIME, f:GetAlpha(), 0)
                ns.Print("hiding (no danger)")
            end
        end
    end

    -- events make showing instant; the poll covers things without an event (target dying, delay timer)
    local poller = CreateFrame("Frame")
    poller:RegisterEvent("PLAYER_REGEN_DISABLED")
    poller:RegisterEvent("PLAYER_TARGET_CHANGED")
    poller:RegisterEvent("MODIFIER_STATE_CHANGED")
    poller:SetScript("OnEvent", function() Check(0) end)
    poller:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < POLL then return end
        Check(acc)
        acc = 0
    end)
end
