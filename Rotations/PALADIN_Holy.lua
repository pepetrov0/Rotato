local ADDON_NAME, ns = ...

-- Any of these counts as "a seal is up"; Vengeance is the Alliance seal, Corruption the Horde one.
local SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }

ns.Rotation{
    class = "PALADIN",
    spec = 1, -- Holy

    highprio = {
        -- the first of these that you know
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
    },

    rotations = {
        single = {
            -- single-target buffs of yours: refresh when nobody in the group has it or it is running out
            { "Beacon of Light", when = function(c)
                local beacon = c.groupBuff("Beacon of Light")
                return not beacon.up or beacon.remains < 30
            end },
            { "Sacred Shield", when = function(c)
                local shield = c.groupBuff("Sacred Shield")
                return not shield.up or shield.remains < 30
            end },
            { "Holy Light" },
        },
    },

    trackers = {
        { buff = SEALS },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
        { spell = "Divine Sacrifice", buff = "Divine Sacrifice" },
    },

    offensives = {
        { spell = "Avenging Wrath", buff = "Avenging Wrath" },
        { spell = "Divine Illumination", buff = "Divine Illumination" },
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
