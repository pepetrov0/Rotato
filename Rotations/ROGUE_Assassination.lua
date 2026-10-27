local ADDON_NAME, ns = ...

-- Rogue, Assassination: placeholder. Fill in the sections you need (see Rotations/HUNTER_Marksmanship.lua
-- for a complete example and Slots.lua for the side slot entry fields); reload to try it.
local Rogue = ns.Rogue

ns.Rotation{
    class = "ROGUE",
    spec = 1, -- Assassination

    -- Poison is an item, not a cast, so it is offered as one. Both out-of-combat tiers: with no
    -- target it is a reminder, and with a hostile one it is part of preparing for the pull.
    reminders = Rogue.PoisonReminders(),    -- out of combat, no hostile target; keeps the panel up until done
    preparation = Rogue.PoisonReminders(),  -- out of combat
    -- highprio = {},     -- before the rotations, in combat or with a hostile target
    -- rotations = { single = {}, multi = {}, aoe = {} },

    -- defensives = {},
    -- utility = {},
    -- trackers = {},
    -- offensives = {},
}
