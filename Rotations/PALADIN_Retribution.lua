local ADDON_NAME, ns = ...

-- Retribution paladin. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is
-- a percentage. The entry fields for the side slots are described in Slots.lua.

-- Any seal will do for upkeep. Vengeance is the Alliance seal and Corruption the Horde one, and
-- Command is a talent, so each character only knows some of them; the entries below are tried in
-- order and the first one that is known wins.
local SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }

ns.Rotation{
    class = "PALADIN",
    spec = 3, -- Retribution

    -- Which Judgement is in use cannot be read from the game, only from what the player casts, so
    -- casting one makes it the current one (see Rotation.lua). Retribution defaults to Wisdom: it is
    -- the one that returns mana.
    variants = {
        judgement = {
            default = "wisdom",
            light = { "Judgement of Light" },
            wisdom = { "Judgement of Wisdom" },
        },
    },

    reminders = {
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
    },

    highprio = {
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },

        -- Dispelling a friend outranks keeping debuffs and shields up. The unit is the one a heal
        -- would land on (mouseover, else target, else yourself).
        { "Cleanse", when = function(c)
            return c.debuffOfType(c.healTarget(), "Poison", "Disease", "Magic").up
        end },

        -- Keeps the current Judgement on the target. Any paladin's counts, so a friend's Judgement
        -- is not overwritten, and it is refreshed under 5 seconds so it never actually drops.
        -- Every Judgement also grants the group Replenishment (Judgements of the Wise), so a missing or
        -- expiring Replenishment calls for one even while the debuff is healthy.
        { variant = "judgement", when = function(c)
            if not c.target.hostile then return false end
            local replenishment = c.buff("Replenishment")
            if not replenishment.up or replenishment.remains < 5 then return true end
            local judgement = c.debuff(c.variantName("judgement"), { any = true })
            return not judgement.up or judgement.remains < 5
        end },
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
        -- something you can Cleanse on the unit the next heal would go to
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
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
