local ADDON_NAME, ns = ...

-- Protection paladin, built on the Retribution file. Conditions are functions of `c`, the condition
-- API in Engine.lua; c.mana is a percentage. The entry fields for the side slots are described in
-- Slots.lua.

-- Any seal will do for upkeep. Vengeance is the Alliance seal and Corruption the Horde one, and
-- Command is a talent, so each character only knows some of them; the entries below are tried in
-- order and the first one that is known wins.
local SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }

-- Either blessing counts, and so does another paladin's: only one Sanctuary can be on a target, so
-- covering it ourselves would just overwrite theirs. The single blessing is the one suggested
-- because the greater one needs a reagent.
local SANCTUARY = { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" }

-- Sacred Shield lasts a minute, so it is renewed with a margin; Holy Shield lasts 10 seconds and
-- is part of the rotation's threat and block, so it is renewed late enough not to waste charges.
local SACRED_SHIELD_REFRESH = 15
local HOLY_SHIELD_REFRESH = 3

ns.Rotation{
    class = "PALADIN",
    spec = 2, -- Protection

    -- Which Judgement is in use cannot be read from the game, only from what the player casts, so
    -- casting one makes it the current one (see Rotation.lua). Protection defaults to Light: the
    -- healing on the tank's own hits is worth more than the mana of Wisdom.
    variants = {
        judgement = {
            default = "light",
            light = { "Judgement of Light" },
            wisdom = { "Judgement of Wisdom" },
        },
    },

    reminders = {
        { "Righteous Fury", when = function(c) return not c.buff("Righteous Fury").up end },
        { "Blessing of Sanctuary", when = function(c) return not c.anyBuff(SANCTUARY).up end },
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
    },

    highprio = {
        -- Without it the paladin generates no threat, so it outranks everything else
        { "Righteous Fury", when = function(c) return not c.buff("Righteous Fury").up end },

        { "Blessing of Sanctuary", when = function(c) return not c.anyBuff(SANCTUARY).up end },

        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },

        { "Sacred Shield", when = function(c)
            local shield = c.buff("Sacred Shield")
            return not shield.up or shield.remains < SACRED_SHIELD_REFRESH
        end },

        -- Same threshold as the utility recommendation; Plea cuts healing received, so it is only
        -- worth its place once mana actually runs low.
        { "Divine Plea", when = function(c) return c.mana < 50 end },

        { "Holy Shield", when = function(c)
            local shield = c.buff("Holy Shield")
            return not shield.up or shield.remains < HOLY_SHIELD_REFRESH
        end },

        -- Keeps the current Judgement on the target. Any paladin's counts, so a friend's Judgement
        -- is not overwritten, and it is refreshed under 5 seconds so it never actually drops.
        { variant = "judgement", when = function(c)
            if not c.target.hostile then return false end
            local judgement = c.debuff(c.variantName("judgement"), { any = true })
            return not judgement.up or judgement.remains < 5
        end },

        -- Only usable under 20% health, which the game enforces, so no explicit threshold here
        { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
    },

    rotations = {
        single = {
            { "Hammer of the Righteous" },
            { "Shield of Righteousness" },
            { variant = "judgement" },
            { "Consecration" },
        },
    },

    -- Righteous Fury is left out: it is a reminder and a top priority, so a slot would only repeat it
    trackers = {
        { buff = SEALS },
        { debuff = { variant = "judgement" }, any = true },
        { buff = "Sacred Shield" },
        { buff = "Holy Shield" },
        -- something you can Cleanse on the unit the next heal would go to
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
        { buff = "Deliverance", show = "active" },
        { spell = "Divine Sacrifice", buff = "Divine Sacrifice" },
    },

    utility = {
        { spell = "Hammer of Justice", recommend = function(c)
            return c.target.hostile and c.target.casting and c.ready("Hammer of Justice")
        end },
        { spell = "Divine Plea", recommend = function(c) return c.mana < 50 and c.ready("Divine Plea") end },
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },

    offensives = {
        -- worth using on cooldown
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c) return c.ready("Avenging Wrath") end },
    },
}
