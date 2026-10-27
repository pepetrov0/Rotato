local ADDON_NAME, ns = ...

-- Holy paladin. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is a
-- percentage. The entry fields for the side slots are described in Slots.lua.

ns.Rotation{
    class = "PALADIN",
    spec = 1, -- Holy

    -- Which Judgement is in use cannot be read from the game, only from what the player casts, so
    -- casting one makes it the current one (see Rotation.lua). Entries say { variant = "judgement" }
    -- and follow it. The choice is not saved, a new session starts on the default.
    variants = {
        judgement = {
            default = "light",
            light = { "Judgement of Light" },
            wisdom = { "Judgement of Wisdom" },
        },
    },

    -- Seal of Wisdom is the only seal that matters for a healer, so unlike Retribution there is
    -- no list of alternatives to choose from.
    reminders = {
        { "Seal of Wisdom", when = function(c) return not c.buff("Seal of Wisdom").up end },
    },

    highprio = {
        { "Seal of Wisdom", when = function(c) return not c.buff("Seal of Wisdom").up end },

        -- Dispelling a friend outranks keeping debuffs and shields up. The unit is the one a heal
        -- would land on (mouseover, else target, else yourself).
        { "Cleanse", when = function(c)
            return c.debuffOfType(c.healTarget(), "Poison", "Disease", "Magic").up
        end },

        -- Beacon and Sacred Shield are single-target, so "missing" means missing on everyone in
        -- the group, not on whoever happens to be targeted. Refreshed under 15 seconds so they
        -- are replaced before they run out.
        { "Beacon of Light", when = function(c)
            local beacon = c.groupBuff("Beacon of Light")
            return not beacon.up or beacon.remains < 15
        end },
        { "Sacred Shield", when = function(c)
            local shield = c.groupBuff("Sacred Shield")
            return not shield.up or shield.remains < 15
        end },

        -- One Judgement keeps up two things. The debuff: any paladin's counts, so a friend's Judgement
        -- is not overwritten, and it is refreshed under 5 seconds so it never actually drops. And
        -- Judgements of the Pure, which comes from judging, so it is renewed with a wider margin.
        { variant = "judgement", when = function(c)
            if not c.target.hostile then return false end
            local pure = c.buff("Judgements of the Pure")
            if not pure.up or pure.remains < 30 then return true end
            local judgement = c.debuff(c.variantName("judgement"), { any = true })
            return not judgement.up or judgement.remains < 5
        end },

        -- Below this mana the Plea is worth its healing penalty; it is not suggested while it is up
        { "Divine Plea", when = function(c) return c.mana < 75 and not c.buff("Divine Plea").up end },
    },

    rotations = {
        single = {
            { "Holy Light" },
        },
    },

    trackers = {
        { buff = "Seal of Wisdom" },
        -- `always`: this is a talent passive, so its name is not in the spellbook and it would be
        -- hidden while missing, which is exactly when it should be shown
        { buff = "Judgements of the Pure", always = true },
        { debuff = { variant = "judgement" }, any = true },
        -- something you can Cleanse on the unit the next heal would go to
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
        { spell = "Divine Sacrifice", buff = "Divine Guardian" },
    },

    utility = {
        { spell = "Hammer of Justice", recommend = function(c)
            return c.target.hostile and c.target.casting and c.ready("Hammer of Justice")
        end },
        -- Early, at 75%, because the offensive cooldowns below are recommended while it is up
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },

    -- Recommended while Divine Plea is up.
    offensives = {
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c)
            return c.buff("Divine Plea").up and c.ready("Avenging Wrath")
        end },
        { spell = "Divine Illumination", buff = "Divine Illumination", recommend = function(c)
            return c.buff("Divine Plea").up and c.ready("Divine Illumination")
        end },
    },
}
