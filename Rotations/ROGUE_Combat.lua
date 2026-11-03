local ADDON_NAME, ns = ...
-- Only the player's class's rotations are kept in memory.
if select(2, UnitClass("player")) ~= "ROGUE" then return end

-- Combat rogue. Conditions are functions of `c`, the condition API in Engine.lua; c.comboPoints is
-- the number of points on the current target. The entry fields for the side slots are described in
-- Slots.lua.

local Rogue = ns.Rogue

local SLICE_AND_DICE = "Slice and Dice"
local EXPOSE_ARMOR = "Expose Armor"
local REFRESH_BELOW = 5 -- seconds left at which a refresh is worth the points

-- Slice and Dice is kept up with whatever points are already banked: even a one-point refresh buys
-- the full haste, and finishing it before it drops spares the build-up afterwards.
local function SliceAndDiceDue(c)
    local buff = c.buff(SLICE_AND_DICE)
    return c.comboPoints >= 1 and (not buff.up or buff.remains < REFRESH_BELOW)
end

-- Expose Armor and Sunder Armor share one armor-reduction slot, and any player's copy fills it, so
-- the rogue only spends points on it while neither is on the target. It is a raid-wide gain and
-- costs a finisher, so it is worth it on a boss only, and only for a rogue who has learned it.
local ARMOR_DEBUFFS = { EXPOSE_ARMOR, "Sunder Armor" }

local function ExposeArmorDue(c)
    -- hostile rules out a boss's corpse, on which the points could still be banked
    if not c.target.hostile or not c.target.boss or not c.spell(EXPOSE_ARMOR).known then return false end
    for _, name in ipairs(ARMOR_DEBUFFS) do
        if c.debuffAny(name).up then return false end
    end
    -- any point will do: the debuff is up as soon as it lands, even if it only lasts 6 seconds
    return c.comboPoints >= 1
end

ns.Rotation{
    name = "Combat Rogue",
    icon = "Interface\\Icons\\Ability_BackStab",
    class = "ROGUE",

    -- Poison is an item, not a cast, so it is offered as one. Both out-of-combat tiers: with no
    -- target it is a reminder, and with a hostile one it is part of preparing for the pull.
    reminders = Rogue.PoisonReminders(),
    preparation = Rogue.PoisonReminders(),

    highprio = {
        -- Upkeep ahead of any damage finisher, and it needs no target of its own: the combo points
        -- only exist while there is one, so the check covers it.
        { SLICE_AND_DICE, when = SliceAndDiceDue },
        -- Below Slice and Dice: the rogue's own upkeep comes first, and the armor debuff is only
        -- the raid's. Bosses only; on trash the points are better spent on damage.
        { EXPOSE_ARMOR, when = ExposeArmorDue },
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
        -- Everything else the spec has is single-target, so the knives are the whole rotation.
        aoe = {
            { "Fan of Knives" },
        },
    },

    trackers = {
        { buff = SLICE_AND_DICE },
        { debuff = "Rupture" }, -- only yours counts: the bleed it tracks is your own
        -- The armor-reduction slot, filled by either debuff from any caster. Only for a rogue who
        -- can apply one, so it does not sit red for someone who cannot act on it.
        { debuff = ARMOR_DEBUFFS, when = function(c) return c.spell(EXPOSE_ARMOR).known end },
    },

    offensives = {
        -- worth using on cooldown
        { spell = "Blade Flurry", buff = "Blade Flurry", recommend = function(c) return c.ready("Blade Flurry") end },
        -- below half energy too: it refills the bar, so using it on a full one wastes the regen
        { spell = "Adrenaline Rush", buff = "Adrenaline Rush", recommend = function(c)
            return c.energy < 50 and c.ready("Adrenaline Rush")
        end },
        -- no aura to sweep: it is over in a couple of seconds. It locks the rogue out while it runs,
        -- so it is only worth using below half energy, where the idle time wastes the least regen.
        { spell = "Killing Spree", recommend = function(c)
            return c.energy < 50 and c.ready("Killing Spree")
        end },
    },

    defensives = {
        { spell = "Evasion", buff = "Evasion" },
        { spell = "Cloak of Shadows", buff = "Cloak of Shadows" },
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
