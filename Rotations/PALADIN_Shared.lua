local ADDON_NAME, ns = ...

-- Pieces the three paladin specs have in common. This file loads before them (see the toc). Entries
-- carry state of their own (error flags, the last icon seen), so every function here builds fresh
-- tables instead of handing one table to several rotations.

local Paladin = {}
ns.Paladin = Paladin

-- Any seal will do for upkeep. Vengeance is the Alliance seal and Corruption the Horde one, and
-- Command is a talent, so each character only knows some of them; the entries below are tried in
-- order and the first one that is known wins. Righteousness is the one a low level character has:
-- it is only a seal worth keeping up while none of those three is known. Once one is, Righteousness
-- no longer counts, so a leftover Righteousness is corrected to the better seal.
local BETTER_SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption" }
local ALL_SEALS = { "Seal of Command", "Seal of Vengeance", "Seal of Corruption", "Seal of Righteousness" }

local function BetterSealKnown(c)
    for _, seal in ipairs(BETTER_SEALS) do
        if c.spell(seal).known then return true end
    end
    return false
end

-- One entry per seal. Put it in a list wrapped by Paladin.List, which flattens it in.
function Paladin.SealUpkeep()
    local entries = {}
    for i, seal in ipairs(BETTER_SEALS) do
        entries[i] = { seal, when = function(c) return not c.anyBuff(BETTER_SEALS).up end }
    end
    entries[#entries + 1] = { "Seal of Righteousness", when = function(c)
        return not BetterSealKnown(c) and not c.anyBuff(ALL_SEALS).up
    end }
    return entries
end

-- The seal slot for the trackers, following the same rule: Righteousness is only a seal while no
-- better one is known. Exactly one of the two entries can show.
function Paladin.SealTrackers()
    return {
        { buff = BETTER_SEALS, when = BetterSealKnown },
        { buff = ALL_SEALS, when = function(c) return not BetterSealKnown(c) end },
    }
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
    local trackers = Paladin.SealTrackers()
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
