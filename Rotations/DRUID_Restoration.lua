local ADDON_NAME, ns = ...

-- Restoration druid. Conditions are functions of `c`, the condition API in Engine.lua. Healing goes
-- to c.healTarget(): the mouseover if it is a living friend, else the target, else yourself, which
-- is where a mouseover/target/self macro would send the spell.
-- True when any other group member satisfies test(unit). Only party members who are really there
-- count (they exist and are connected).
local function AnyOtherMember(test)
    local raid = GetNumRaidMembers()
    local prefix, count = "party", GetNumPartyMembers()
    if raid > 0 then prefix, count = "raid", raid end
    for i = 1, count do
        local unit = prefix .. i
        if not UnitIsUnit(unit, "player") and UnitExists(unit) and UnitIsConnected(unit) and test(unit) then
            return true
        end
    end
    return false
end

ns.Rotation{
    class = "DRUID",
    spec = 3, -- Restoration

    highprio = {
        { "Tree of Life", when = function(c) return not c.buff("Tree of Life").up end },

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

    -- Your own hots on the unit a heal would go to, so a missing one shows red before you cast it
    trackers = {
        { healTargetBuff = "Rejuvenation" },
        { healTargetBuff = "Regrowth" },
        { healTargetBuff = "Lifebloom" },
        { healTargetBuff = "Wild Growth" },
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
            return c.combat and c.ready("Rebirth") and AnyOtherMember(UnitIsDead)
        end },
        { spell = "Nature's Swiftness", buff = "Nature's Swiftness" },
    },
}
