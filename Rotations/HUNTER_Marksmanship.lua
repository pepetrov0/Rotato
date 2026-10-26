local ADDON_NAME, ns = ...

-- Conditions run against the condition API in Engine.lua (c);
-- c.mana is a percentage.
ns.Rotation{
    class = "HUNTER",
    spec = 2, -- Marksmanship

    -- out of combat with no hostile target; keeps the UI up until done
    reminders = {
        { "Aspect of the Viper", when = function(c)
            return not c.buff("Aspect of the Viper").up
        end },
    },

    -- out of combat
    preparation = {
        { "Hunter's Mark", when = function(c)
            return c.target.hostile and not c.debuff("Hunter's Mark", { any = true }).up
        end },
    },

    -- in combat (and with a hostile target out of it), checked before the rotations
    highprio = {
        { "Tranquilizing Shot", when = function(c) return c.target.hasBuffType("Enrage", "Magic") end },
        { "Aspect of the Viper", when = function(c)
            return c.mana < 10 and not c.buff("Aspect of the Viper").up
        end },
        { "Aspect of the Dragonhawk", when = function(c)
            return c.mana > 80 and not c.buff("Aspect of the Dragonhawk").up
        end },
    },

    -- the side slots; see Slots.lua for the entry fields
    trackers = {
        { debuff = "Hunter's Mark", any = true },
        { debuff = "Serpent Sting" },
    },

    rotations = {
        single = {
            { "Aimed Shot" },
            { "Chimera Shot" },
            { "Steady Shot" },
        },

        multi = {
            { "Multi-Shot" },
            { "Chimera Shot" },
            { "Steady Shot" },
        },

        aoe = {
            { "Multi-Shot" },
            { "Volley" },
        },
    },
}
