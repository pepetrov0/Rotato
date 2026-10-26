local ADDON_NAME, ns = ...

ns.Rotation{
    class = "PRIEST",
    spec = 1, -- Discipline

    -- raid flasks/elixirs worth reminding about for this spec
    consumables = { "Flask of the Frost Wyrm" },

    -- out of combat with no hostile target
    reminders = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
    },

    highprio = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
        { "Shadowfiend", when = function(c) return c.mana < 20 end },
    },

    trackers = {
        { buff = "Inner Fire" },
        -- Weakened Soul on whoever the next Shield would go to; hides itself when it is not there
        { healTargetDebuff = "Weakened Soul", show = "active", lockout = true },
        -- something you can dispel (Dispel Magic / Abolish Disease) on that same unit
        { healTargetDebuffType = { "Disease", "Magic" } },
    },

    rotations = {
        single = {
            { "Penance" },
            { "Prayer of Mending" },
            -- on whoever the heal would go to: mouseover, else target, else yourself
            { "Power Word: Shield", manaOnly = true, when = function(c)
                return not c.debuffOn(c.healTarget(), "Weakened Soul").up
            end },
            { "Flash Heal" },
        },
    },

    utility = {
        { spell = "Shadowfiend", recommend = function(c) return c.mana < 20 and c.ready("Shadowfiend") end },
        { spell = "Hymn of Hope" },
        { spell = "Divine Hymn" },
        { spell = "Fear Ward" },
    },

    defensives = {
        { spell = "Pain Suppression", buff = "Pain Suppression" },
        { spell = "Fade", buff = "Fade" },
        { spell = "Psychic Scream" },
    },

    offensives = {
        { spell = "Power Infusion", buff = "Power Infusion" },
    },
}
