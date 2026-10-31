local ADDON_NAME, ns = ...

-- Paladin below level 10, before any talents: no spec, so this is the rotation a new character
-- gets (see Rotation.lua). Seal of Righteousness is the only seal until the later ones, and the
-- Judgement is the only attack besides the auto attack.

local Paladin = ns.Paladin

local SEAL = "Seal of Righteousness"

local function SealUpkeep()
    return { SEAL, when = function(c) return not c.buff(SEAL).up end }
end

ns.Rotation{
    class = "PALADIN",

    variants = { judgement = Paladin.JudgementVariant("light") },

    reminders = { SealUpkeep() },

    highprio = { SealUpkeep() },

    rotations = {
        single = {
            { variant = "judgement" }
        },
    },

    trackers = {
        { buff = SEAL },
        { debuff = { variant = "judgement" }, any = true },
    },

    -- Forbearance refuses it, so it grays out while it runs
    defensives = {
        { spell = "Divine Protection", buff = "Divine Protection", discourage = Paladin.ShieldsBlocked },
    },

    utility = {
        Paladin.HammerOfJustice(),
    },
}
