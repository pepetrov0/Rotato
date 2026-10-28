local ADDON_NAME, ns = ...

-- Protection paladin. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is
-- a percentage. The entry fields for the side slots are described in Slots.lua.

local Paladin = ns.Paladin

-- Either blessing counts, and so does another paladin's: only one Sanctuary can be on a target, so
-- covering it ourselves would just overwrite theirs. The single blessing is the one suggested
-- because the greater one needs a reagent.
local SANCTUARY = { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" }

-- Sacred Shield lasts a minute, so it is renewed with a margin; Holy Shield lasts 10 seconds and
-- is part of the rotation's threat and block, so it is renewed late enough not to waste charges.
local SACRED_SHIELD_REFRESH = 15
local HOLY_SHIELD_REFRESH = 3

local function RighteousFury()
    return { "Righteous Fury", when = function(c) return not c.buff("Righteous Fury").up end }
end

local function Sanctuary()
    return { "Blessing of Sanctuary", when = function(c) return not c.anyBuff(SANCTUARY).up end }
end

ns.Rotation{
    class = "PALADIN",
    spec = 2, -- Protection

    -- The current Judgement follows what the player casts (see Rotation.lua).
    -- Protection defaults to Light: the healing on the tank's own hits is worth more than the mana
    -- of Wisdom.
    variants = { judgement = Paladin.JudgementVariant("light") },

    reminders = Paladin.List{
        RighteousFury(),
        Sanctuary(),
        Paladin.SealUpkeep(),
    },

    highprio = Paladin.List{
        -- Without it the paladin generates no threat, so it outranks everything else
        RighteousFury(),

        Sanctuary(),

        Paladin.SealUpkeep(),

        Paladin.Cleanse(),

        { "Sacred Shield", when = function(c)
            local shield = c.buff("Sacred Shield")
            return not shield.up or shield.remains < SACRED_SHIELD_REFRESH
        end },

        -- Kept up whenever it is off cooldown; the buff only lasts 15 seconds of its 60 second cooldown
        { "Divine Plea", when = function(c) return not c.buff("Divine Plea").up end },

        { "Holy Shield", when = function(c)
            local shield = c.buff("Holy Shield")
            return not shield.up or shield.remains < HOLY_SHIELD_REFRESH
        end },

        -- Keeps the current Judgement on the target. Any paladin's counts, so a friend's Judgement
        -- is not overwritten, and it is refreshed under 5 seconds so it never actually drops.
        { variant = "judgement", when = function(c)
            return Paladin.JudgementDue(c)
        end },
    },

    rotations = {
        single = {
            -- Only usable under 20% health, which the game enforces, so no explicit threshold here
            { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
            { "Hammer of the Righteous" },
            { "Shield of Righteousness" },
            { variant = "judgement" },
            { "Consecration" },
        },
    },

    -- Righteous Fury is left out: it is a reminder and a top priority, so a slot would only repeat it
    trackers = Paladin.CommonTrackers({
        { buff = "Sacred Shield" },
        { buff = "Holy Shield" },
        -- one of the main mana sources of a tank, so a gap in it is worth seeing
        { buff = "Divine Plea" },
        -- Ardent Defender is a passive: the only thing to track is the 2 minute lockout it leaves
        -- after saving the paladin, while it cannot save them again. It is blocking, not something
        -- to fix, so it hides itself when absent and gets the blue border while it counts down.
        { playerDebuff = "Ardent Defender", show = "active", blocking = true },
    }),

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        -- Forbearance refuses these two, so they gray out while it runs
        { spell = "Divine Protection", buff = "Divine Protection", discourage = Paladin.ShieldsBlocked },
        { spell = "Hand of Protection", buff = "Hand of Protection",
          discourage = Paladin.HandOfProtectionBlocked },
        { buff = "Deliverance", show = "active" },
        { spell = "Divine Sacrifice", buff = "Divine Guardian" },
    },

    utility = {
        Paladin.HammerOfJustice(),
        { spell = "Hand of Reckoning" },
        { spell = "Righteous Defense" },
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },

    offensives = {
        -- worth using on cooldown
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c) return c.ready("Avenging Wrath") end },
    },
}
