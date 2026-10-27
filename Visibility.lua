local ADDON_NAME, ns = ...

-- Decides when the frame is on screen. It is hidden unless something needs the player's
-- attention (a fight, a reminder, a short buff just activated), because a permanent overlay would
-- just be noise between fights.

local FADE_OUT_TIME = 0.25 -- fading out is cosmetic; showing never fades, it must be ready at once
local HIDE_DELAY = 3       -- calm time before fading out, so the frame does not flicker between pulls
local ACTIVE_HOLD = 30     -- longest time a running green slot keeps an already shown frame up
local POLL = 0.1           -- some changes (a target dying, the hide delay) have no event to wait for

-- Why the frame should be visible, or nil when it is calm. The reason is only used for the chat
-- report, but the order matters: the cheap, common reasons are checked first.
local function DangerReason()
    if UnitAffectingCombat("player") then return "in combat" end

    -- a living hostile target means a pull is likely about to start
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
        return "hostile target"
    end

    -- a pending reminder (a missing buff, no pet...) must stay up until the player acts on it
    -- the display's recent result when it has one (it is set up after this file)
    local _, _, _, _, source = (ns.EvaluateCached or ns.Evaluate)()
    if source == "reminders" then return "reminder" end

    -- A short green buff was just activated (Sprint, Evasion), so its timer is worth seeing; once it
    -- is up the hold below keeps the frame on screen until it ends. Slots.lua sets this each update.
    if ns.slotJustActivated then return "activated" end

    if ns.unlocked then return "unlocked" end -- so it can be moved and configured while calm
end

-- Situations where the frame is useless, so it is hidden outright whatever else is going on.
-- Unlike the fade above this has no delay: a mounted or dead player should not see it for a
-- few extra seconds.
local function HiddenReason()
    if UnitIsDeadOrGhost("player") then return "dead" end
    if UnitInVehicle("player") then return "in a vehicle" end
    if IsMounted() then return "mounted" end
end

function ns.InitVisibility()
    local f = ns.frame
    local shown, calm, held, elapsedTotal = false, 0, 0, 0
    f:SetAlpha(0)

    local hiddenFor -- last reason for the hard hide, so it is reported once rather than every poll

    local function Check(dt)
        local why = HiddenReason()
        -- an unlocked frame stays visible even then, otherwise it could not be configured
        if why and not ns.unlocked then
            if hiddenFor ~= why then
                hiddenFor = why
                if shown then
                    shown = false
                    UIFrameFadeRemoveFrame(f)
                    f:SetAlpha(0)
                    ns.Log("hiding (" .. why .. ")")
                end
            end
            return
        end
        hiddenFor = nil

        local reason = DangerReason()
        if reason then
            calm, held = 0, 0
            if not shown then
                shown = true
                UIFrameFadeRemoveFrame(f) -- a fade-out that is still running would fight the SetAlpha
                f:SetAlpha(1)
                ns.Log("showing (" .. reason .. ")")
            end
        elseif shown then
            -- A green slot running in the side rows (an active buff that helps the player) keeps the
            -- frame up so its timer can be seen, for at most ACTIVE_HOLD, and the usual hide delay only
            -- starts after that. Only a just activated short buff brings a hidden frame back (above):
            -- a long one ticking down would otherwise pop it up out of nowhere.
            -- Slots.lua sets ns.anySlotActive each update.
            if ns.anySlotActive and held < ACTIVE_HOLD then
                held, calm = held + dt, 0
            else
                calm = calm + dt
            end
            if calm >= HIDE_DELAY then
                shown = false
                UIFrameFadeOut(f, FADE_OUT_TIME, f:GetAlpha(), 0)
                ns.Log("hiding (no danger)")
            end
        end
    end

    -- lets other files (unlocking) re-evaluate immediately instead of waiting for the next poll
    ns.CheckVisibility = function() Check(0) end

    -- The events make showing instant; the poll alone could lag by up to POLL seconds.
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
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < POLL then return end
        Check(elapsedTotal)
        elapsedTotal = 0
    end)
end
