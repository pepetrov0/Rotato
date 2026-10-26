local ADDON_NAME, ns = ...

ns.Rotation{
    class = "PRIEST",
    spec = 1, -- Discipline

    rotations = {
        single = {
            { "Penance" },
            { "Prayer of Mending" },
            -- on whoever the heal would go to: mouseover, else target, else yourself
            { "Power Word: Shield", when = function(c)
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
