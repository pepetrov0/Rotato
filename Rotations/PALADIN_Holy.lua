local ADDON_NAME, ns = ...

ns.Rotation{
    class = "PALADIN",
    spec = 1, -- Holy

    -- raid flasks/elixirs worth reminding about for this spec
    consumables = { "Elixir of Lightning Speed", "Elixir of Mighty Thoughts" },

    -- Seal of Wisdom is the only seal that matters
    -- which Judgement you use: casting one of them makes it the current one (saved)
    variants = {
        judgement = {
            default = "light",
            light = { "Judgement of Light" },
            wisdom = { "Judgement of Wisdom" },
        },
    },

    reminders = {
        { "Seal of Wisdom", when = function(c) return not c.buff("Seal of Wisdom").up end },
    },

    highprio = {
        { "Seal of Wisdom", when = function(c) return not c.buff("Seal of Wisdom").up end },
        -- keep the current Judgement on the target (from any paladin)
        { variant = "judgement", when = function(c)
            return c.target.hostile and not c.debuff(c.variantName("judgement"), { any = true }).up
        end },
    },

    rotations = {
        single = {
            -- single-target buffs of yours: refresh when nobody in the group has it or it has under 15s left
            { "Beacon of Light", when = function(c)
                local beacon = c.groupBuff("Beacon of Light")
                return not beacon.up or beacon.remains < 15
            end },
            { "Sacred Shield", when = function(c)
                local shield = c.groupBuff("Sacred Shield")
                return not shield.up or shield.remains < 15
            end },
            -- keeps Judgements of the Pure up
            { variant = "judgement", when = function(c)
                local pure = c.buff("Judgements of the Pure")
                return not pure.up or pure.remains < 30
            end },
            { "Holy Light" },
        },
    },

    trackers = {
        { buff = "Seal of Wisdom" },
        { buff = "Judgements of the Pure", always = true },
        { debuff = { variant = "judgement" }, any = true },
        -- something you can Cleanse on mouseover, else target, else yourself
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
        { spell = "Divine Sacrifice", buff = "Divine Sacrifice" },
    },

    offensives = {
        -- best used while Divine Plea is up
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c)
            return c.buff("Divine Plea").up and c.ready("Avenging Wrath")
        end },
        { spell = "Divine Illumination", buff = "Divine Illumination", recommend = function(c)
            return c.buff("Divine Plea").up and c.ready("Divine Illumination")
        end },
    },

    utility = {
        { spell = "Hammer of Justice", recommend = function(c)
            return c.target.hostile and c.target.casting and c.ready("Hammer of Justice")
        end },
        { spell = "Divine Plea", recommend = function(c) return c.mana < 75 and c.ready("Divine Plea") end },
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },
}
