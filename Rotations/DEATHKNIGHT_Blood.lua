local ADDON_NAME, ns = ...

-- Blood death knight tank. Conditions are functions of `c`, the condition API in Engine.lua. The
-- entry fields for the side slots are described in Slots.lua.

-- The rune slots are fixed: 1-2 blood, 3-4 unholy, 5-6 frost. A slot holding a death rune still
-- counts as the slot it came from here, so Blood Tap changing a blood rune does not matter.
local FIRST_UNHOLY, LAST_FROST = 3, 6

local function UnholyAndFrostSpent()
    for rune = FIRST_UNHOLY, LAST_FROST do
        local _, _, ready = GetRuneCooldown(rune)
        if ready then return false end
    end
    return true
end

local function FrostPresence()
    return { "Frost Presence", when = function(c) return not c.buff("Frost Presence").up end }
end

ns.Rotation{
    class = "DEATHKNIGHT",
    spec = 1, -- Blood

    reminders = {
        FrostPresence(),
    },

    -- Frost Presence is where the tank's threat and damage reduction come from
    highprio = {
        FrostPresence(),
    },

    trackers = {
        { debuff = "Frost Fever" },
        { debuff = "Blood Plague" },
    },

    utility = {
        { spell = "Dark Command" },
        -- Worth it once there is no frost or unholy rune left to spend
        { spell = "Empower Rune Weapon", recommend = UnholyAndFrostSpent },
        { spell = "Death Grip" },
    },

    offensives = {
        { spell = "Hysteria", buff = "Hysteria" },
        { spell = "Army of the Dead" },
    },

    defensives = {
        { spell = "Icebound Fortitude", buff = "Icebound Fortitude" },
        { spell = "Anti-Magic Shell", buff = "Anti-Magic Shell" },
        { spell = "Death Pact" },
        { spell = "Blood Tap", buff = "Blood Armor" },
    },
}
