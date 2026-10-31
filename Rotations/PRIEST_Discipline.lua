local ADDON_NAME, ns = ...

-- Discipline priest. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is a
-- percentage. The entry fields for the side slots are described in Slots.lua.

-- Buffs Power Infusion does not stack with: the other haste buffs, and Arcane Power, which a cast
-- of it on the mage is refused over.
local POWER_INFUSION_CONFLICTS = { "Bloodlust", "Heroism", "Arcane Power" }

-- Checked on whoever it would go to (mouseover, else target, else yourself), like the shield.
local function PowerInfusionBlocked(c)
    local unit = c.healTarget()
    for _, name in ipairs(POWER_INFUSION_CONFLICTS) do
        if c.buffOnAny(unit, name).up then return true end
    end
    return false
end

ns.Rotation{
    name = "Discipline Priest",
    filter = function(c) return c.class == "PRIEST" and c.spec == 1 and c.level >= 80 end,

    reminders = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
    },

    highprio = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
        -- below 20% mana the Shadowfiend is worth more than any heal, it is the mana source
        { "Shadowfiend", when = function(c) return c.mana < 20 end },

        -- Last, so it only comes up when nothing more urgent is waiting. The unit is the one a heal
        -- would land on (mouseover, else target, else yourself).
        { "Dispel Magic", when = function(c)
            return c.debuffOfType(c.healTarget(), "Magic").up
        end },
        -- Abolish Disease keeps ticking on the heal target for a while, so while it is up the
        -- disease is already being handled and suggesting it again would just refresh it.
        { "Abolish Disease", when = function(c)
            local unit = c.healTarget()
            return c.debuffOfType(unit, "Disease").up and not c.buffOnAny(unit, "Abolish Disease").up
        end },
    },

    rotations = {
        single = {
            { "Penance" },
            { "Prayer of Mending" },

            -- Weakened Soul is checked on whoever the shield would actually go to (mouseover, else
            -- target, else yourself): looking only at the target would suggest a shield that the
            -- mouseover cannot take. manaOnly because the game was seen reporting the spell as
            -- unusable while an enemy was targeted, even though it is cast on someone else.
            { "Power Word: Shield", manaOnly = true, when = function(c)
                return not c.debuffOn(c.healTarget(), "Weakened Soul").up
            end },

            { "Flash Heal" },
        },
    },

    trackers = {
        { buff = "Inner Fire" },
        -- Blocking, not a problem: it ending means the Shield is available again, so it gets the
        -- blue blocking border instead of the red one. It hides itself when absent.
        { healTargetDebuff = "Weakened Soul", show = "active", blocking = true },
        -- something you can dispel (Dispel Magic / Abolish Disease) on that same unit
        { healTargetDebuffType = { "Disease", "Magic" } },
        -- only shown while an Abolish Disease is ticking on that same unit, whoever cast it
        { healTargetBuffAny = "Abolish Disease", show = "active" },
        -- on that same unit, where Power Infusion would be wasted
        { healTargetBuffAny = "Bloodlust", show = "active", blocking = true },
        { healTargetBuffAny = "Heroism", show = "active", blocking = true },
        { healTargetBuffAny = "Arcane Power", show = "active", blocking = true },
    },

    utility = {
        -- the pet is included so the slot shows the Shadowfiend as active (green) while it is out,
        -- and the summon's cooldown the rest of the time
        { spell = "Shadowfiend", pet = "Shadowfiend",
          recommend = function(c) return c.mana < 20 and c.ready("Shadowfiend") end },
        { spell = "Hymn of Hope" },
        { spell = "Divine Hymn" },
        -- the buff is included so the slot shows the aura (green, with its remaining time) while the
        -- ward is on you, whoever cast it, and the cooldown the rest of the time
        { spell = "Fear Ward", buff = "Fear Ward" },
    },

    defensives = {
        -- the buff is included so one slot covers both casting it on others and receiving it
        { spell = "Pain Suppression", buff = "Pain Suppression" },
        { spell = "Fade", buff = "Fade" },
        { spell = "Psychic Scream" },
    },

    offensives = {
        -- Worth casting whenever it is ready, except on someone with a buff it does not stack with:
        -- grayed out and not recommended then.
        { spell = "Power Infusion", buff = "Power Infusion",
          recommend = function(c)
              return c.ready("Power Infusion") and not PowerInfusionBlocked(c)
          end,
          discourage = PowerInfusionBlocked },
    },
}
