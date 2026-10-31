local ADDON_NAME, ns = ...

-- Blood death knight tank. Conditions are functions of `c`, the condition API in Engine.lua. The
-- entry fields for the side slots are described in Slots.lua.

-- The rotation shared by single target and AoE: `bloodSpenders` are the blood rune abilities.
local function Rotation(bloodSpenders)
    local list = {
        { "Icy Touch", when = function(c)
            return not c.debuff("Frost Fever").up or c.buff("Killing Machine").up
        end },
        { "Plague Strike", when = function(c) return not c.debuff("Blood Plague").up end },
    }
    for _, spender in ipairs(bloodSpenders) do list[#list + 1] = spender end
    list[#list + 1] = { "Death Strike" }
    return list
end

local function BloodRune(name, extra)
    return { name, when = function(c) return c.runes.blood > 0 and (not extra or extra(c)) end }
end

-- Pestilence spreads the diseases, which is only worth doing now and then
local PESTILENCE_INTERVAL = 15

-- Damage buffs Hysteria does not stack with (patch 3.1). Only the ones a Hysteria target is likely
-- to have are listed: a rogue's Tricks, a warrior's Death Wish, a paladin's Avenging Wrath.
local HYSTERIA_CONFLICTS = { "Tricks of the Trade", "Death Wish", "Avenging Wrath" }

local function HysteriaBlocked(c)
    local unit = c.healTarget()
    for _, name in ipairs(HYSTERIA_CONFLICTS) do
        if c.buffOnAny(unit, name).up then return true end
    end
    return false
end

local function FrostPresence()
    return { "Frost Presence", when = function(c) return not c.buff("Frost Presence").up end }
end

ns.Rotation{
    name = "Blood Death Knight",
    icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    filter = function(c) return c.class == "DEATHKNIGHT" and c.spec == 1 and c.level >= 80 end,

    reminders = {
        FrostPresence(),
    },

    -- Frost Presence is where the tank's threat and damage reduction come from
    highprio = {
        FrostPresence(),
    },

    rotations = {
        single = Rotation({ BloodRune("Blood Strike") }),
        aoe = (function()
            local list = Rotation({
                BloodRune("Pestilence", function(c) return c.sinceCast("Pestilence") >= PESTILENCE_INTERVAL end),
                BloodRune("Blood Boil"),
            })
            table.insert(list, 1, { "Death and Decay" })
            return list
        end)(),
    },

    trackers = {
        { debuff = "Frost Fever" },
        { debuff = "Blood Plague" },
        -- a talent proc, so its name is not in the spellbook
        { buff = "Blade Barrier", always = true },
        -- on whoever Hysteria would go to, where they would waste it
        { healTargetBuffAny = "Tricks of the Trade", show = "active", blocking = true },
        { healTargetBuffAny = "Death Wish", show = "active", blocking = true },
        { healTargetBuffAny = "Avenging Wrath", show = "active", blocking = true },
    },

    utility = {
        { spell = "Dark Command" },
        -- Worth it once there is no frost or unholy rune left to spend
        { spell = "Empower Rune Weapon", recommend = function(c)
            return c.ready("Empower Rune Weapon") and c.runes.frost == 0 and c.runes.unholy == 0
        end },
        { spell = "Death Grip" },
    },

    offensives = {
        { spell = "Hysteria", buff = "Hysteria", discourage = HysteriaBlocked },
        { spell = "Army of the Dead" },
    },

    defensives = {
        { spell = "Icebound Fortitude", buff = "Icebound Fortitude" },
        { spell = "Anti-Magic Shell", buff = "Anti-Magic Shell" },
        { spell = "Death Pact" },
        -- the aura sits on the enemy, so it is read as a debuff on the target
        { spell = "Mark of Blood", debuff = "Mark of Blood" },
        { spell = "Blood Tap", buff = "Blood Armor" },
    },
}
