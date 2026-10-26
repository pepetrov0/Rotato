local ADDON_NAME, ns = ...

-- Conditions run against the condition API in Engine.lua (c);
-- c.mana is a percentage.
-- the aspects tracked on the side; Dragonhawk and Wild are interchangeable for damage
local ASPECTS = {
    "Aspect of the Dragonhawk", "Aspect of the Wild", "Aspect of the Viper", "Aspect of the Hawk",
    "Aspect of the Beast", "Aspect of the Monkey", "Aspect of the Pack", "Aspect of the Cheetah",
}
local DPS_ASPECTS = { "Aspect of the Dragonhawk", "Aspect of the Wild" }

ns.Rotation{
    class = "HUNTER",
    spec = 2, -- Marksmanship

    -- raid flasks/elixirs worth reminding about for this spec
    consumables = { "Flask of Endless Rage", "Elixir of Lightning Speed" },

    -- out of combat with no hostile target; keeps the UI up until done
    reminders = {
        { "Trueshot Aura", when = function(c) return not c.buff("Trueshot Aura").up end },
        { "Revive Pet", when = function(c) return c.pet.dead end },
        { "Call Pet", when = function(c) return c.pet.missing end },
        { "Feed Pet", when = function(c) return c.pet.hungry end },
        { "Mend Pet", when = function(c)
            return c.pet.exists and c.pet.hp < 100 and not c.pet.buff("Mend Pet").up
        end },
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
        { "Trueshot Aura", when = function(c) return not c.buff("Trueshot Aura").up end },
        { "Tranquilizing Shot", when = function(c) return c.target.hasBuffType("Enrage", "Magic") end },
        { "Mend Pet", when = function(c)
            return c.combat and c.pet.exists and c.pet.hp < 50 and not c.pet.buff("Mend Pet").up
        end },
        { "Aspect of the Viper", when = function(c)
            return c.mana < 10 and not c.buff("Aspect of the Viper").up
        end },
        { "Kill Shot", when = function(c) return c.target.hostile and c.target.hp < 20 end },
        { "Aspect of the Dragonhawk", when = function(c)
            return c.mana > 80 and not c.anyBuff(DPS_ASPECTS).up
        end },
    },

    -- the side slots; see Slots.lua for the entry fields
    defensives = {
        { spell = "Feign Death", buff = "Feign Death" },
        { spell = "Disengage" },
        { spell = "Deterrence", buff = "Deterrence" },
    },
    utility = {
        -- best used right before Chimera Shot
        { spell = "Misdirection", buff = "Misdirection", recommend = function(c)
            return c.ready("Misdirection") and c.ready("Chimera Shot") and not c.buff("Misdirection").up
        end },
        -- worth it once Misdirection or Rapid Fire is deep into its cooldown
        { spell = "Readiness", recommend = function(c)
            return c.ready("Readiness") and (c.cd("Misdirection") > 15 or c.cd("Rapid Fire") > 15)
        end },
        { spell = "Call Pet", when = function(c) return c.pet.missing end, recommend = function() return true end },
        { spell = "Feed Pet", when = function(c) return c.pet.hungry end, recommend = function(c) return not c.combat end },
        { spell = "Revive Pet", when = function(c) return c.pet.dead end },
    },
    offensives = {
        { spell = "Rapid Fire", buff = "Rapid Fire" },
    },
    trackers = {
        { buff = ASPECTS },
        { debuff = "Hunter's Mark", any = true },
        { debuff = "Serpent Sting" },
        { targetBuffType = { "Magic", "Enrage" } }, -- something to Tranquilizing Shot off the target
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
