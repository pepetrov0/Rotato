local ADDON_NAME, ns = ...

-- Restoration shaman. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is a
-- percentage. The entry fields for the side slots are described in Slots.lua.

-- Earthliving Weapon is an enchant, not an aura, so the game only says that the main hand has one,
-- not which. It is renewed under 5 minutes so it never runs out in the middle of a fight.
local function EarthlivingWeapon()
    return { "Earthliving Weapon", when = function()
        local hasMain, mainExpiration = GetWeaponEnchantInfo()
        return not hasMain or mainExpiration < 5 * 60 * 1000
    end }
end

local function WaterShield()
    return { "Water Shield", when = function(c) return not c.buff("Water Shield").up end }
end

-- Bloodlust is the Horde spell and Heroism the Alliance one; a character only knows one of them
-- and an unknown spell is hidden. Neither is worth using while the other's debuff is on the player.
local function Lust(spell, buff, debuff)
    return { spell = spell, buff = buff,
        discourage = function(c) return c.selfDebuff(debuff).up end }
end

ns.Rotation{
    class = "SHAMAN",
    spec = 3, -- Restoration

    reminders = {
        EarthlivingWeapon(),
    },

    highprio = {
        EarthlivingWeapon(),
        WaterShield(),

        -- Earth Shield is single-target: "missing" means missing on everyone in the group
        { "Earth Shield", when = function(c)
            if not c.inGroup then return false end
            local shield = c.groupBuff("Earth Shield")
            return not shield.up or shield.remains < 15
        end },

        -- Cleanse Spirit takes poison, disease and curse off the unit a heal would land on
        { "Cleanse Spirit", when = function(c)
            return c.debuffOfType(c.healTarget(), "Poison", "Disease", "Curse").up
        end },
    },

    trackers = {
        -- `always`: this is a talent passive, so its name is not in the spellbook and it would be
        -- hidden while missing
        { buff = "Tidal Waves", always = true },
        { healTargetDebuffType = { "Poison", "Disease", "Curse" } },
    },

    utility = {
        { spell = "Wrath of Air Totem" },
        { spell = "Mana Tide Totem", buff = "Mana Tide", recommend = function(c)
            return c.mana < 50 and c.ready("Mana Tide Totem")
        end },
        { spell = "Nature's Swiftness", buff = "Nature's Swiftness" },
    },

    offensives = {
        Lust("Bloodlust", "Bloodlust", "Sated"),
        Lust("Heroism", "Heroism", "Exhaustion"),
    },
}
