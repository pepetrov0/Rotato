local ADDON_NAME, ns = ...

-- Paladin below level 10, before any talents: no spec, so this is the rotation a new character
-- gets (see Rotation.lua). Seal of Righteousness is the only seal until the later ones, and the
-- Judgement is the only attack besides the auto attack.

local Paladin = ns.Paladin

local SEAL = "Seal of Righteousness"

local function SealUpkeep()
    return { SEAL, when = function(c) return not c.buff(SEAL).up end }
end

-- Cleanse replaces Purify later and also removes Magic; Purify only does these two.
local function Purify()
    return { "Purify", when = function(c)
        return c.debuffOfType(c.healTarget(), "Poison", "Disease").up
    end }
end

ns.Rotation{
    class = "PALADIN",

    variants = { judgement = Paladin.JudgementVariant("light") },

    reminders = { SealUpkeep() },

    highprio = { SealUpkeep(), Purify() },

    rotations = {
        single = {
            { "Holy Light", when = function(c) return c.hpOn(c.healTarget()) < 80 end },
            { variant = "judgement" },
            -- no Art of War proc at this level, but it always crits undead and demons
            { "Exorcism", when = function(c)
                local creatureType = c.target.creatureType
                return creatureType == "Demon" or creatureType == "Undead"
            end },
            { "Consecration" },
        },
    },

    trackers = {
        { buff = SEAL },
        { debuff = { variant = "judgement" }, any = true },
        { healTargetDebuffType = { "Poison", "Disease" } },
    },

    -- Forbearance refuses these, so they gray out while it runs
    defensives = {
        { spell = "Hand of Sacrifice", buff = "Hand of Sacrifice" },
        { spell = "Divine Protection", buff = "Divine Protection", discourage = Paladin.ShieldsBlocked },
        { spell = "Hand of Protection", buff = "Hand of Protection",
          discourage = Paladin.HandOfProtectionBlocked },
    },

    utility = {
        Paladin.HammerOfJustice(),
        { spell = "Hand of Salvation", buff = "Hand of Salvation" },
        { spell = "Hand of Freedom", buff = "Hand of Freedom" },
    },
}
