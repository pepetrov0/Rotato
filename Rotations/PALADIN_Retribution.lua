local ADDON_NAME, ns = ...

-- Any of these counts as "a seal is up"; Vengeance is the Alliance seal, Corruption the Horde one.
local SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }

ns.Rotation{
    class = "PALADIN",
    spec = 3, -- Retribution

    highprio = {
        -- the first of these that you know
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
    },

    rotations = {
        single = {
            { "Divine Storm" },
            { "Crusader Strike" },
            { "Exorcism", when = function(c) return c.buff("The Art of War").up end },
            { "Judgement of Wisdom" },
            { "Holy Wrath", when = function(c)
                local creatureType = c.target.creatureType
                return creatureType == "Demon" or creatureType == "Undead"
            end },
            { "Consecration" },
        },
    },

    trackers = {
        { buff = SEALS },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
    },

    offensives = {
        { spell = "Avenging Wrath", buff = "Avenging Wrath" },
    },

    utility = {
        { spell = "Hammer of Justice", recommend = function(c)
            return c.target.hostile and c.target.casting and c.ready("Hammer of Justice")
        end },
        { spell = "Divine Plea", recommend = function(c) return c.mana < 50 and c.ready("Divine Plea") end },
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },
}
