local ADDON_NAME, ns = ...

-- Conditions run against the condition API in Engine.lua (c);
-- c.mana is a percentage.
ns.Rotation{
    class = "HUNTER",
    spec = 2, -- Marksmanship

    -- out of combat
    prep = {
        { "Hunter's Mark", when = function(c)
            return c.target.hostile and not c.debuff("Hunter's Mark", { any = true }).up
        end },
        -- stays on screen until pressed: regenerate mana between fights
        { "Aspect of the Viper", when = function(c)
            return c.mana < 100 and not c.buff("Aspect of the Viper").up
        end },
    },

    -- in combat, checked before the mode lists
    common = {
        { "Tranquilizing Shot", when = function(c) return c.target.hasBuffType("Enrage", "Magic") end },
        { "Aspect of the Viper", when = function(c)
            return c.mana < 10 and not c.buff("Aspect of the Viper").up
        end },
        { "Aspect of the Dragonhawk", when = function(c)
            return c.mana > 80 and not c.buff("Aspect of the Dragonhawk").up
        end },
    },

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
}
