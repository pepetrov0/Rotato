local ADDON_NAME, ns = ...

local FADE_TIME = 0.5  -- seconds to fade in/out
local HIDE_DELAY = 3   -- seconds of calm before fading out, avoids flicker between pulls
local POLL = 0.25

-- "Dangerous" for now: in combat, a living hostile target selected (about to pull),
-- or the frame being positioned. Returns the reason, or nil when calm.
local function DangerReason()
    if UnitAffectingCombat("player") then return "in combat" end
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
        return "hostile target"
    end
    if IsShiftKeyDown() or ns.frame.dragging then return "positioning" end
end

function ns.InitVisibility()
    local f = ns.frame
    local shown, calm, acc = false, 0, 0
    f:SetAlpha(0)

    local poller = CreateFrame("Frame")
    poller:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < POLL then return end
        local dt = acc
        acc = 0

        local reason = DangerReason()
        if reason then
            calm = 0
            if not shown then
                shown = true
                UIFrameFadeIn(f, FADE_TIME, f:GetAlpha(), 1)
                ns.Print("showing (" .. reason .. ")")
            end
        elseif shown then
            calm = calm + dt
            if calm >= HIDE_DELAY then
                shown = false
                UIFrameFadeOut(f, FADE_TIME, f:GetAlpha(), 0)
                ns.Print("hiding (no danger)")
            end
        end
    end)
end
