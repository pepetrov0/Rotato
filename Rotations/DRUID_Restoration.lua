local ADDON_NAME, ns = ...

-- Restoration druid. Conditions are functions of `c`, the condition API in Engine.lua. Healing goes
-- to c.healTarget(): the mouseover if it is a living friend, else the target, else yourself, which
-- is where a mouseover/target/self macro would send the spell.

ns.Rotation{
    name = "Restoration Druid",
    icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
    filter = function(c) return c.class == "DRUID" and c.spec == 3 and c.level >= 80 end,

    highprio = {
        { "Tree of Life", when = function(c) return not c.buff("Tree of Life").up end },

        -- Dispelling a friend outranks the hots below. The unit is the one a heal would land on
        -- (mouseover, else target, else yourself).
        { "Remove Curse", when = function(c)
            return c.debuffOfType(c.healTarget(), "Curse").up
        end },
        -- Abolish Poison keeps ticking on the heal target for a while, so while it is up the poison
        -- is already being handled and suggesting it again would just refresh it.
        { "Abolish Poison", when = function(c)
            local unit = c.healTarget()
            return c.debuffOfType(unit, "Poison").up and not c.buffOnAny(unit, "Abolish Poison").up
        end },

        -- A Clearcasting proc makes the next spell free, and a free Lifebloom is the best use of it
        { "Lifebloom", when = function(c) return c.buff("Clearcasting").up end },

        { "Wild Growth" }, -- on cooldown: the game's own cooldown is what keeps it from being suggested
    },

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

    -- Your own hots on the unit a heal would go to, so a missing one shows red before you cast it,
    -- plus something Abolish Poison / Remove Curse can take off that same unit
    trackers = {
        { healTargetBuff = "Rejuvenation" },
        { healTargetBuff = "Regrowth" },
        { healTargetBuff = "Wild Growth" },
        { healTargetDebuffType = { "Poison", "Curse" } },
        -- only shown while an Abolish Poison is ticking on that same unit, whoever cast it
        { healTargetBuffAny = "Abolish Poison", show = "active" },
    },

    defensives = {
        { spell = "Barkskin", buff = "Barkskin" },
        { spell = "Tranquility" },
    },

    utility = {
        { spell = "Innervate", buff = "Innervate", recommend = function(c)
            return c.mana < 50 and c.ready("Innervate")
        end },
        -- A combat resurrection is only worth pointing at when someone is actually down in a fight
        { spell = "Rebirth", recommend = function(c)
            return c.combat and c.ready("Rebirth") and c.anyOtherMember(UnitIsDead)
        end },
        { spell = "Nature's Swiftness", buff = "Nature's Swiftness" },
    },
}
