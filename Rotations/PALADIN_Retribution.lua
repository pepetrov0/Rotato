local ADDON_NAME, ns = ...

-- Any of these counts as "a seal is up"; Vengeance is the Alliance seal, Corruption the Horde one.
local SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }

ns.Rotation{
    class = "PALADIN",
    spec = 3, -- Retribution

    -- raid flasks/elixirs worth reminding about for this spec
    consumables = { "Flask of Endless Rage" },

    -- which Judgement you use: casting one of them makes it the current one (saved)
    variants = {
        judgement = {
            default = "wisdom",
            light = { "Judgement of Light" },
            wisdom = { "Judgement of Wisdom" },
        },
    },

    -- out of combat with no hostile target: the first seal you know, until one is up
    reminders = {
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
    },

    highprio = {
        -- the first of these that you know
        { "Seal of Command", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Vengeance", when = function(c) return not c.anyBuff(SEALS).up end },
        { "Seal of Corruption", when = function(c) return not c.anyBuff(SEALS).up end },
        -- keep the current Judgement on the target (from any paladin)
        { variant = "judgement", when = function(c)
            return c.target.hostile and not c.debuff(c.variantName("judgement"), { any = true }).up
        end },
        { "Hammer of Wrath", when = function(c) return c.target.hostile and c.target.hp < 20 end },
    },

    rotations = {
        single = {
            { "Divine Storm" },
            -- low on mana: Judgement of Wisdom moves up to right after Divine Storm
            { "Judgement of Wisdom", when = function(c) return c.variant.judgement == "wisdom" and c.mana < 50 end },
            { "Crusader Strike" },
            { "Exorcism", when = function(c) return c.buff("The Art of War").up end },
            { variant = "judgement" },
            { "Holy Wrath", when = function(c)
                local creatureType = c.target.creatureType
                return creatureType == "Demon" or creatureType == "Undead"
            end },
            { "Consecration" },
        },
    },

    trackers = {
        { buff = SEALS },
        { debuff = { variant = "judgement" }, any = true },
        -- something you can Cleanse on mouseover, else target, else yourself
        { healTargetDebuffType = { "Poison", "Disease", "Magic" } },
    },

    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection" },
        { spell = "Divine Shield", buff = "Divine Shield" },
        { spell = "Hand of Protection", buff = "Hand of Protection" },
    },

    offensives = {
        { spell = "Avenging Wrath", buff = "Avenging Wrath", recommend = function(c) return c.ready("Avenging Wrath") end },
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
