local ADDON_NAME, ns = ...

local FADE_OUT_TIME = 0.25 -- showing is instant, only hiding fades
local HIDE_DELAY = 3   -- seconds of calm before fading out, avoids flicker between pulls
local POLL = 0.1

-- "Dangerous" for now: in combat, a living hostile target selected (about to pull),
-- a pending reminder, or the frame being unlocked for positioning. Returns the reason, or nil when calm.
local function DangerReason()
    if UnitAffectingCombat("player") then return "in combat" end
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
        return "hostile target"
    end
    local _, _, _, _, source = ns.Evaluate()
    if source == "reminders" then return "reminder" end
    if ns.unlocked then return "unlocked" end
end

-- Situations in which there is nothing to do: the frame is hidden at once, whatever else is going on
-- (except while unlocked, so it can still be configured).
local function HiddenReason()
    if UnitIsDeadOrGhost("player") then return "dead" end
    if UnitInVehicle("player") then return "in a vehicle" end
    if IsMounted() then return "mounted" end
end

function ns.InitVisibility()
    local f = ns.frame
    local shown, calm, acc = false, 0, 0
    f:SetAlpha(0)

    local hiddenFor
    local function Check(dt)
        local why = HiddenReason()
        if why and not ns.unlocked then
            if hiddenFor ~= why then
                hiddenFor = why
                if shown then
                    shown = false
                    UIFrameFadeRemoveFrame(f)
                    f:SetAlpha(0)
                    ns.Print("hiding (" .. why .. ")")
                end
            end
            return
        end
        hiddenFor = nil

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

    ns.CheckVisibility = function() Check(0) end

    -- events make showing instant; the poll covers things without an event (target dying, delay timer)
    local poller = CreateFrame("Frame")
    poller:RegisterEvent("PLAYER_REGEN_DISABLED")
    poller:RegisterEvent("PLAYER_TARGET_CHANGED")
    poller:RegisterEvent("PLAYER_DEAD")
    poller:RegisterEvent("PLAYER_ALIVE")
    poller:RegisterEvent("PLAYER_UNGHOST")
    poller:RegisterEvent("UNIT_ENTERED_VEHICLE")
    poller:RegisterEvent("UNIT_EXITED_VEHICLE")
    poller:SetScript("OnEvent", function() Check(0) end)
    poller:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < POLL then return end
        Check(acc)
        acc = 0
    end)
end
