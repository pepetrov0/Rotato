local ADDON_NAME, ns = ...

-- Condition API ("c") handed to rotation `when` functions. Everything is read live.

local GCD_MAX = 1.5      -- a cooldown this short or shorter is just the global cooldown
local LOOKAHEAD = 0.25   -- a spell this close to ready counts as ready

local NO_AURA = { up = false, remains = 0, stacks = 0, mine = false }

local function Aura(fn, unit, name, filter)
    local found, _, _, count, _, _, expires, caster = fn(unit, name, nil, filter)
    if not found then return NO_AURA end
    return {
        up = true,
        remains = (expires and expires > 0) and (expires - GetTime()) or math.huge,
        stacks = (count and count > 0) and count or 1,
        mine = caster == "player",
    }
end

local function Percent(cur, max)
    if not max or max == 0 then return 0 end
    return cur / max * 100
end

local target = setmetatable({}, {
    __index = function(_, k)
        if k == "exists" then return UnitExists("target") and true or false
        elseif k == "hostile" then
            return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") and true or false
        elseif k == "hp" then return Percent(UnitHealth("target"), UnitHealthMax("target"))
        elseif k == "boss" then return UnitClassification("target") == "worldboss" or UnitLevel("target") == -1
        elseif k == "casting" then return UnitCastingInfo("target") ~= nil
        end
    end,
})

-- true if the target has a buff whose dispel type is one of the given types
function target.hasBuffType(...)
    for i = 1, 40 do
        local name, _, _, _, buffType = UnitBuff("target", i)
        if not name then return false end
        for j = 1, select("#", ...) do
            if buffType == select(j, ...) then return true end
        end
    end
    return false
end

local c = setmetatable({ target = target }, {
    __index = function(_, k)
        if k == "combat" then return UnitAffectingCombat("player") and true or false
        elseif k == "mana" then return Percent(UnitPower("player", 0), UnitPowerMax("player", 0))
        elseif k == "hp" then return Percent(UnitHealth("player"), UnitHealthMax("player"))
        elseif k == "moving" then return GetUnitSpeed("player") > 0
        elseif k == "mode" then return ns.mode
        end
    end,
})

function c.buff(name) return Aura(UnitBuff, "player", name) end

-- debuffs on the target; only yours unless opts.any
function c.debuff(name, opts)
    return Aura(UnitDebuff, "target", name, not (opts and opts.any) and "PLAYER" or nil)
end

-- remaining cooldown, ignoring the global cooldown
function c.cd(name)
    local start, duration = GetSpellCooldown(name)
    if not start or duration <= GCD_MAX or start == 0 then return 0 end
    return math.max(0, start + duration - GetTime())
end

function c.usable(name) return (IsUsableSpell(name)) and true or false end

-- Evaluation ------------------------------------------------------------

local function Passes(entry, name)
    if not entry.when then return true end
    local ok, result = pcall(entry.when, c)
    if not ok then
        if not entry.errored then
            entry.errored = true
            ns.Print("rotation error in " .. name .. ": " .. tostring(result))
        end
        return false
    end
    return result and true or false
end

-- Returns spell, state ("ready" | "cd"), cooldown start, cooldown duration; nothing if there is no suggestion.
-- Out of combat: prep entries first; with a living hostile target (or in combat): common, then the mode's list.
function ns.Evaluate()
    local rotation = ns.GetRotation()
    if not rotation then return end

    local combat = UnitAffectingCombat("player")
    local lists = {}
    if not combat then lists[#lists + 1] = rotation.prep end
    if combat or target.hostile then
        lists[#lists + 1] = rotation.common
        lists[#lists + 1] = rotation[ns.mode] or rotation.single
    end

    for _, list in ipairs(lists) do
        for _, entry in ipairs(list) do
            local name = ns.SpellName(entry[1])
            local start, duration
            if name then start, duration = GetSpellCooldown(name) end
            if start and Passes(entry, name) then -- start is nil for spells we don't know
                local remaining = start > 0 and (start + duration - GetTime()) or 0
                if duration <= GCD_MAX or remaining <= LOOKAHEAD then
                    if IsUsableSpell(name) then return name, "ready", start, duration end
                elseif entry.wait then
                    return name, "cd", start, duration
                end
            end
        end
    end
end

-- Prints why the suggestion is what it is, for /rotato debug.
function ns.DebugEvaluate()
    local rotation = ns.GetRotation()
    ns.Print(format("class=%s spec=%s rotation=%s mode=%s combat=%s hostile=%s", tostring(ns.class),
        tostring(ns.specIndex), rotation and "found" or "NONE", ns.mode, tostring(c.combat), tostring(target.hostile)))
    if not rotation then return end
    for _, key in ipairs({ "prep", "common", ns.mode }) do
        for _, entry in ipairs(rotation[key] or {}) do
            local name = ns.SpellName(entry[1])
            local start, duration
            if name then start, duration = GetSpellCooldown(name) end
            ns.Print(format("  %s: %s known=%s when=%s usable=%s cd=%s", key, tostring(name), tostring(start ~= nil),
                tostring(start and Passes(entry, name)), tostring(name and (IsUsableSpell(name)) and true or false),
                tostring(start and format("%.1f/%.1f", start, duration))))
        end
    end
    ns.Print("suggestion: " .. tostring((ns.Evaluate())))
end

-- Whether a spell appears anywhere in the active rotation.
local inRotation = setmetatable({}, { __mode = "k" })
function ns.InRotation(spell)
    local rotation = ns.GetRotation()
    if not rotation then return false end
    local set = inRotation[rotation]
    if not set then
        set = {}
        for _, key in ipairs({ "prep", "common", "single", "multi", "aoe" }) do
            for _, entry in ipairs(rotation[key] or {}) do
                set[ns.SpellName(entry[1])] = true
            end
        end
        inRotation[rotation] = set
    end
    return set[spell] or false
end
