local ADDON_NAME, ns = ...

-- Discipline priest. Conditions are functions of `c`, the condition API in Engine.lua; c.mana is a
-- percentage. The entry fields for the side slots are described in Slots.lua.

ns.Rotation{
    class = "PRIEST",
    spec = 1, -- Discipline

    consumables = { "Flask of the Frost Wyrm" },

    reminders = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
    },

    highprio = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
        -- below 20% mana the Shadowfiend is worth more than any heal, it is the mana source
        { "Shadowfiend", when = function(c) return c.mana < 20 end },
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
        -- A lockout, not a problem: it ending means the Shield is available again, so it gets the
        -- blue lockout border instead of the red one. It hides itself when absent.
        { healTargetDebuff = "Weakened Soul", show = "active", lockout = true },
        -- something you can dispel (Dispel Magic / Abolish Disease) on that same unit
        { healTargetDebuffType = { "Disease", "Magic" } },
    },

    utility = {
        { spell = "Shadowfiend", recommend = function(c) return c.mana < 20 and c.ready("Shadowfiend") end },
        { spell = "Hymn of Hope" },
        { spell = "Divine Hymn" },
        { spell = "Fear Ward" },
    },

    defensives = {
        -- the buff is included so one slot covers both casting it on others and receiving it
        { spell = "Pain Suppression", buff = "Pain Suppression" },
        { spell = "Fade", buff = "Fade" },
        { spell = "Psychic Scream" },
    },

    offensives = {
        -- Worth casting whenever it is ready, except under Bloodlust/Heroism, where it is not worth
        -- it: grayed out and not recommended then.
        { spell = "Power Infusion", buff = "Power Infusion",
          recommend = function(c)
              return c.ready("Power Infusion") and not c.anyBuff({ "Bloodlust", "Heroism" }).up
          end,
          discourage = function(c) return c.anyBuff({ "Bloodlust", "Heroism" }).up end },
    },
}
