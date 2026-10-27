local ADDON_NAME, ns = ...

-- Retribution paladin. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is
-- a percentage. The entry fields for the side slots are described in Slots.lua.

local Paladin = ns.Paladin
local SEALS = Paladin.SEALS

ns.Rotation{
    class = "PALADIN",
    spec = 3, -- Retribution

    -- The current Judgement follows what the player casts (see Rotation.lua).
    -- Retribution defaults to Wisdom: it is the one that returns mana.
    variants = { judgement = Paladin.JudgementVariant("wisdom") },

    reminders = Paladin.List{
        Paladin.SealUpkeep(),
    },

    highprio = Paladin.List{
        Paladin.SealUpkeep(),

        Paladin.Cleanse(),

        -- Keeps the current Judgement on the target. Any paladin's counts, so a friend's Judgement
        -- is not overwritten, and it is refreshed under 5 seconds so it never actually drops.
        -- Every Judgement also grants the group Replenishment (Judgements of the Wise), so a missing or
        -- expiring Replenishment calls for one even while the debuff is healthy.
        { variant = "judgement", when = function(c)
            if not c.target.hostile then return false end
            local replenishment = c.buff("Replenishment")
            if not replenishment.up or replenishment.remains < 5 then return true end
            return Paladin.JudgementDue(c)
        end },

        -- Below this mana the Plea is worth its healing penalty; it is not suggested while it is up
        { "Divine Plea", when = function(c) return c.mana < 50 and not c.buff("Divine Plea").up end },
    },

    rotations = {
        single = {
            -- Only usable under 20% health, which the game enforces, so no explicit threshold here
            { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
            { "Divine Storm" },
            -- When mana runs low the Judgement jumps ahead of Crusader Strike, because Judgement of
            -- Wisdom is what returns mana.
            { variant = "judgement", when = function(c) return c.mana < 50 end },
            { "Crusader Strike" },
            { "Exorcism", when = function(c) return c.buff("The Art of War").up end }, -- the proc makes it instant
            { variant = "judgement" },
            { "Holy Wrath", when = function(c)
                -- it only hits these two types, anything else would be a wasted cooldown
                local creatureType = c.target.creatureType
                return creatureType == "Demon" or creatureType == "Undead"
            end },
            { "Consecration" },
        },
    },

    trackers = {
        { buff = SEALS },
        { debuff = { variant = "judgement" }, any = true },
        Paladin.CleanseTracker(),
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
    },

    utility = {
        Paladin.HammerOfJustice(),
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },

    offensives = {
        -- worth using on cooldown
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c) return c.ready("Avenging Wrath") end },
    },
}
