local ADDON_NAME, ns = ...

-- Paladin, Protection: placeholder. Fill in the sections you need (see Rotations/HUNTER_Marksmanship.lua
-- for a complete example and Slots.lua for the side slot entry fields); reload to try it.
ns.Rotation{
    class = "PALADIN",
    spec = 2, -- Protection

    -- reminders = {},    -- out of combat, no hostile target; keeps the panel up until done
    -- preparation = {},  -- out of combat
    -- highprio = {},     -- before the rotations, in combat or with a hostile target
    -- rotations = { single = {}, multi = {}, aoe = {} },

    -- defensives = {},
    -- utility = {},
    trackers = {
        -- something you can Cleanse on mouseover, else target, else yourself
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },
    -- offensives = {},
}
