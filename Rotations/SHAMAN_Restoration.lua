local ADDON_NAME, ns = ...

-- Restoration shaman. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is a
-- percentage. The entry fields for the side slots are described in Slots.lua.

-- Earthliving Weapon is an enchant, not an aura, and the game does not say which enchant it is
-- (see c.mainHandEnchant). It is renewed under 5 minutes so it never runs out in the middle of a fight.
local function EarthlivingWeapon()
    return { "Earthliving Weapon", when = function(c)
        local enchant = c.mainHandEnchant()
        return not enchant.up or enchant.remains < 5 * 60
    end }
end

local function WaterShield()
    return { "Water Shield", when = function(c)
        local shield = c.buff("Water Shield")
        return not shield.up or shield.remains < 15
    end }
end

-- Bloodlust is the Horde spell and Heroism the Alliance one; a character only knows one of them
-- and an unknown spell is hidden. Neither is worth using while the other's debuff is on the player.
local function Lust(spell, buff, debuff)
    return { spell = spell, buff = buff,
        discourage = function(c) return c.selfDebuff(debuff).up end }
end

ns.Rotation{
    name = "Restoration Shaman",
    filter = function(c) return c.class == "SHAMAN" and c.spec == 3 and c.level >= 80 end,

    reminders = {
        EarthlivingWeapon(),
        WaterShield(),
    },

    highprio = {
        EarthlivingWeapon(),

        -- Cleanse Spirit takes poison, disease and curse off the unit a heal would land on
        { "Cleanse Spirit", when = function(c)
            return c.debuffOfType(c.healTarget(), "Poison", "Disease", "Curse").up
        end },

        WaterShield(),

        -- Earth Shield is single-target: "missing" means missing on everyone in the group
        { "Earth Shield", when = function(c)
            if not c.inGroup then return false end
            local shield = c.groupBuff("Earth Shield")
            return not shield.up or shield.remains < 15
        end },

        { "Wrath of Air Totem", when = function(c) return not c.buff("Wrath of Air Totem").up end },

        -- Both heals grant Tidal Waves, so they are cast to get it back; Riptide first, and Chain
        -- Heal takes over while Riptide is on cooldown
        { "Riptide", when = function(c) return not c.buff("Tidal Waves").up end },
        { "Chain Heal", when = function(c) return not c.buff("Tidal Waves").up end },
    },

    -- The modes are fixed (see Mode.lua), so the middle one, multi, is the Lesser Healing Wave
    -- rotation. Casting one of these heals switches to its rotation.
    rotations = {
        single = { { "Healing Wave" } },
        multi = { { "Lesser Healing Wave" } },
        aoe = { { "Chain Heal" } },
    },

    trackers = {
        -- `always`: this is a talent passive, so its name is not in the spellbook and it would be
        -- hidden while missing
        { buff = "Tidal Waves", always = true },
        { buff = "Water Shield" },
        { buff = "Wrath of Air Totem" },
        { healTargetDebuffType = { "Poison", "Disease", "Curse" } },
    },

    utility = {
        { spell = "Mana Tide Totem", buff = "Mana Tide", recommend = function(c)
            return c.mana < 75 and c.ready("Mana Tide Totem")
        end },
        { spell = "Nature's Swiftness", buff = "Nature's Swiftness" },
    },

    offensives = {
        Lust("Bloodlust", "Bloodlust", "Sated"),
        Lust("Heroism", "Heroism", "Exhaustion"),
    },
}
