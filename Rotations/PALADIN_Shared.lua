local ADDON_NAME, ns = ...

-- Pieces the three paladin specs have in common. This file loads before them (see the toc). Entries
-- carry state of their own (error flags, the last icon seen), so every function here builds fresh
-- tables instead of handing one table to several rotations.

local Paladin = {}
ns.Paladin = Paladin

-- Any seal the player has up counts, weak or not: if they chose it, it is their call. Only when no
-- seal at all is up is one offered: the first known of `preferred`, else Righteousness, the seal a
-- low level character has. Vengeance is the Alliance seal and Corruption the Horde one, and Command
-- is a talent, so each character only knows some of the damage seals.
local DAMAGE_SEALS = { "Seal of Command", "Seal of Corruption", "Seal of Vengeance" }
local EVERY_SEAL = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption", "Seal of Righteousness",
    "Seal of Wisdom", "Seal of Light", "Seal of Justice", "Seal of Blood", "Seal of the Martyr" }

local function NoSeal(c) return not c.anyBuff(EVERY_SEAL).up end

local function AnyKnown(c, names)
    for _, name in ipairs(names) do
        if c.spell(name).known then return true end
    end
    return false
end

-- One entry per seal. Put it in a list wrapped by Paladin.List, which flattens it in. `preferred`
-- defaults to the damage seals.
function Paladin.SealUpkeep(preferred)
    preferred = preferred or DAMAGE_SEALS
    local entries = {}
    for i, seal in ipairs(preferred) do
        entries[i] = { seal, when = NoSeal }
    end
    entries[#entries + 1] = { "Seal of Righteousness", when = function(c)
        return not AnyKnown(c, preferred) and NoSeal(c)
    end }
    return entries
end

-- The seal slot for the trackers: whichever seal is up, red while none is. The preferred seals go
-- first, so the slot shows the one SealUpkeep would offer while it is missing.
function Paladin.SealTracker(preferred)
    local seals = {}
    for _, seal in ipairs(preferred or DAMAGE_SEALS) do seals[#seals + 1] = seal end
    for _, seal in ipairs(EVERY_SEAL) do
        local listed = false
        for _, have in ipairs(seals) do if have == seal then listed = true end end
        if not listed then seals[#seals + 1] = seal end
    end
    return { buff = seals }
end

-- A list of entries in which a nested list (an array of entries, like SealUpkeep returns) is
-- expanded in place. An entry never has a table as its first element, a nested list always does.
function Paladin.List(items)
    local flat = {}
    for _, item in ipairs(items) do
        if type(item[1]) == "table" then
            for _, entry in ipairs(item) do flat[#flat + 1] = entry end
        else
            flat[#flat + 1] = item
        end
    end
    return flat
end

-- Which Judgement is in use cannot be read from the game, only from what the player casts, so
-- casting one makes it the current one (see Rotation.lua). `default` is "light" or "wisdom".
function Paladin.JudgementVariant(default)
    return {
        default = default,
        light = { "Judgement of Light" },
        wisdom = { "Judgement of Wisdom" },
    }
end

-- Dispelling a friend outranks keeping debuffs and shields up. The unit is the one a heal would
-- land on (mouseover, else target, else yourself).
function Paladin.Cleanse()
    return { "Cleanse", when = function(c)
        return c.debuffOfType(c.healTarget(), "Poison", "Disease", "Magic").up
    end }
end

-- Before Cleanse is learned, Purify is the dispel: poison and disease only. Cleanse replaces it in
-- the spellbook, so after that this entry is skipped. Put it right after Paladin.Cleanse().
function Paladin.Purify()
    return { "Purify", when = function(c)
        return c.debuffOfType(c.healTarget(), "Poison", "Disease").up
    end }
end

-- Whether the current Judgement debuff is missing or about to run out. Any paladin's counts, so a
-- friend's Judgement is not overwritten, and it is refreshed under 5 seconds so it never drops.
-- Needs a hostile target: without one the debuff cannot be read and would look missing.
function Paladin.JudgementDue(c)
    if not c.target.hostile then return false end
    local judgement = c.debuffAny(c.variantName("judgement"))
    return not judgement.up or judgement.remains < 5
end

-- Something you can Cleanse on the unit the next heal would go to
function Paladin.CleanseTracker()
    return { healTargetDebuffType = { "Poison", "Disease", "Magic" } }
end

-- The tracker for a character that may not have Cleanse yet: Purify only takes poison and disease,
-- so Magic counts once Cleanse is in the spellbook. Exactly one of the two entries can show.
function Paladin.CleanseTrackers()
    return {
        { healTargetDebuffType = { "Poison", "Disease" }, when = function(c) return not c.spell("Cleanse").known end },
        { healTargetDebuffType = { "Poison", "Disease", "Magic" }, when = function(c) return c.spell("Cleanse").known end },
    }
end

-- Forbearance on the paladin refuses Divine Shield and Divine Protection, so their slots are
-- grayed out instead of inviting a cast that cannot happen.
function Paladin.ShieldsBlocked(c)
    return c.selfDebuff("Forbearance").up
end

-- Hand of Protection goes to whoever a heal would go to, so that is whose Forbearance decides
-- whether it can be used; the paladin's own counts when it would be cast on themselves.
function Paladin.HandOfProtectionBlocked(c)
    return c.debuffOn(c.healTarget(), "Forbearance").up
end

-- The trackers the paladin specs have in common: the seal in use, the current Judgement, and
-- something to Cleanse. `extra` adds spec-specific entries ahead of the Cleanse one, so the dispel
-- stays last. Fresh tables every call (see the file comment).
function Paladin.CommonTrackers(extra)
    local trackers = { Paladin.SealTracker() }
    trackers[#trackers + 1] = { debuff = { variant = "judgement" }, any = true }
    for _, entry in ipairs(extra or {}) do trackers[#trackers + 1] = entry end
    for _, entry in ipairs(Paladin.CleanseTrackers()) do trackers[#trackers + 1] = entry end
    return trackers
end

function Paladin.HammerOfJustice()
    return { spell = "Hammer of Justice", recommend = function(c)
        return c.target.hostile and c.target.interruptible and c.ready("Hammer of Justice")
    end }
end
