local ADDON_NAME, ns = ...

ns.Rotation{
    class = "PRIEST",
    spec = 1, -- Discipline

    -- out of combat with no hostile target
    reminders = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
    },

    highprio = {
        { "Inner Fire", when = function(c) return not c.buff("Inner Fire").up end },
    },

    trackers = {
        { buff = "Inner Fire" },
        -- Weakened Soul on whoever the next Shield would go to; hides itself when it is not there
        { healTargetDebuff = "Weakened Soul", show = "active" },
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
        { spell = "Shadowfiend" },
        { spell = "Hymn of Hope" },
        { spell = "Divine Hymn" },
        { spell = "Fear Ward" },
    },

    defensives = {
        { spell = "Pain Suppression" },
        { spell = "Fade", buff = "Fade" },
        { spell = "Psychic Scream" },
    },

    offensives = {
        { spell = "Power Infusion" },
    },
}
