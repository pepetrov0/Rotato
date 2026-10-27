local ADDON_NAME, ns = ...

-- Blood death knight tank. Conditions are functions of `c`, the condition API in Engine.lua. The
-- entry fields for the side slots are described in Slots.lua.

-- The rotation shared by single target and AoE: only the blood rune spender differs.
local function Rotation(bloodSpender)
    return {
        { "Icy Touch", when = function(c)
            return not c.debuff("Frost Fever").up or c.buff("Killing Machine").up
        end },
        { "Plague Strike", when = function(c) return not c.debuff("Blood Plague").up end },
        { bloodSpender, when = function(c) return c.runes.blood > 0 end },
        { "Death Strike" },
    }
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

    rotations = {
        single = Rotation("Blood Strike"),
        aoe = (function()
            local list = Rotation("Blood Boil")
            table.insert(list, 1, { "Death and Decay" })
            return list
        end)(),
    },

    trackers = {
        { debuff = "Frost Fever" },
        { debuff = "Blood Plague" },
        -- a talent proc, so its name is not in the spellbook
        { buff = "Blade Barrier", always = true },
    },

    utility = {
        { spell = "Dark Command" },
        -- Worth it once there is no frost or unholy rune left to spend
        { spell = "Empower Rune Weapon", recommend = function(c) return c.runes.frost == 0 and c.runes.unholy == 0 end },
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
