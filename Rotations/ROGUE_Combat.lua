local ADDON_NAME, ns = ...

-- Combat rogue. Conditions are functions of `c`, the condition API in Engine.lua; c.comboPoints is
-- the number of points on the current target. The entry fields for the side slots are described in
-- Slots.lua.

local SLICE_AND_DICE = "Slice and Dice"
local REFRESH_BELOW = 5 -- seconds left at which a refresh is worth the points

-- Slice and Dice is kept up with whatever points are already banked: even a one-point refresh buys
-- the full haste, and finishing it before it drops spares the build-up afterwards.
local function SliceAndDiceDue(c)
    local buff = c.buff(SLICE_AND_DICE)
    return c.comboPoints >= 1 and (not buff.up or buff.remains < REFRESH_BELOW)
end

ns.Rotation{
    class = "ROGUE",
    spec = 2, -- Combat

    highprio = {
        -- Upkeep ahead of any damage finisher, and it needs no target of its own: the combo points
        -- only exist while there is one, so the check covers it.
        { SLICE_AND_DICE, when = SliceAndDiceDue },
    },

    rotations = {
        single = {
            -- Only while the bleed is missing; a running one is left alone until it expires, so the
            -- points in between go to Eviscerate.
            { "Rupture", when = function(c)
                return c.comboPoints >= 5 and not c.debuff("Rupture").up
            end },
            { "Eviscerate", when = function(c) return c.comboPoints >= 5 end },
            { "Sinister Strike" },
        },
    },

    trackers = {
        { buff = SLICE_AND_DICE },
        { debuff = "Rupture" }, -- only yours counts: the bleed it tracks is your own
    },

    defensives = {
        { spell = "Evasion", buff = "Evasion" },
        { spell = "Feint", buff = "Feint" },
        { spell = "Vanish", buff = "Vanish" },
    },

    utility = {
        { spell = "Sprint", buff = "Sprint" },
        -- recommended only while there is something to interrupt, so it does not flash all fight
        { spell = "Kick", recommend = function(c)
            return c.target.hostile and c.target.interruptible and c.ready("Kick")
        end },
        { spell = "Dismantle" },
    },
}
