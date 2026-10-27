local ADDON_NAME, ns = ...

-- Restoration druid. Conditions are functions of `c`, the condition API in Engine.lua. Healing goes
-- to c.healTarget(): the mouseover if it is a living friend, else the target, else yourself, which
-- is where a mouseover/target/self macro would send the spell.
ns.Rotation{
    class = "DRUID",
    spec = 3, -- Restoration

    rotations = {
        single = {
            -- Only the player's own hots count: another druid's Rejuvenation would not stack with
            -- ours, but it is not ours to keep up either.
            { "Rejuvenation", when = function(c) return not c.buffOn(c.healTarget(), "Rejuvenation").up end },
            { "Regrowth", when = function(c) return not c.buffOn(c.healTarget(), "Regrowth").up end },

            -- It consumes one of the two hots, so without either on the unit it has nothing to
            -- work with and the game would refuse it.
            { "Swiftmend", when = function(c)
                local unit = c.healTarget()
                return c.buffOn(unit, "Rejuvenation").up or c.buffOn(unit, "Regrowth").up
            end },
            { "Nourish" },
        },
    },
}
