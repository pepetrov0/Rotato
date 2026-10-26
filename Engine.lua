local ADDON_NAME, ns = ...

-- Condition API ("c") handed to rotation `when` functions. Everything is read live.

local GCD_MAX = 1.5      -- a cooldown this short or shorter is just the global cooldown
ns.GCD_MAX = GCD_MAX
local LOOKAHEAD = 0.25   -- a spell this close to ready counts as ready

local NO_AURA = { up = false, remains = 0, stacks = 0, mine = false, duration = 0, expires = 0 }

local function Aura(fn, unit, name, filter)
    local found, _, icon, count, _, duration, expires, caster = fn(unit, name, nil, filter)
    if not found then return NO_AURA end
    return {
        up = true,
        name = found,
        icon = icon,
        duration = duration or 0,
        expires = expires or 0,
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

-- the first buff on the target whose dispel type is one of the given types (NO_AURA if none)
function target.buffOfType(...)
    for i = 1, 40 do
        local name, _, icon, count, buffType, duration, expires, caster = UnitBuff("target", i)
        if not name then break end
        for j = 1, select("#", ...) do
            if buffType == select(j, ...) then
                return {
                    up = true,
                    name = name,
                    icon = icon,
                    duration = duration or 0,
                    expires = expires or 0,
                    remains = (expires and expires > 0) and (expires - GetTime()) or math.huge,
                    stacks = (count and count > 0) and count or 1,
                    mine = caster == "player",
                }
            end
        end
    end
    return NO_AURA
end

function target.buff(name) return Aura(UnitBuff, "target", name) end

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

-- the player's pet; "exists" is false for a dead pet
local pet = setmetatable({}, {
    __index = function(_, k)
        if k == "exists" then return UnitExists("pet") and not UnitIsDead("pet") and true or false
        elseif k == "hp" then return Percent(UnitHealth("pet"), UnitHealthMax("pet"))
        end
    end,
})

function pet.buff(name) return Aura(UnitBuff, "pet", name) end

local c = setmetatable({ target = target, pet = pet }, {
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

-- debuffs on the player
function c.selfDebuff(name) return Aura(UnitDebuff, "player", name) end

-- the first of several interchangeable buffs that is up (NO_AURA if none)
function c.anyBuff(names)
    for _, name in ipairs(names) do
        local aura = c.buff(name)
        if aura.up then return aura end
    end
    return NO_AURA
end

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

ns.c = c

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

ns.Passes = Passes

-- Returns spell, state ("ready" | "cd"), cooldown start, cooldown duration and the list it came from
-- ("reminders", "preparation", "highprio", or the mode); nothing if there is no suggestion.
-- Out of combat, no hostile target: reminders, then preparation.
-- Out of combat, hostile target: preparation, then high priority, then the mode's rotation.
-- In combat: high priority, then the mode's rotation.
function ns.Evaluate()
    local rotation = ns.GetRotation()
    if not rotation then return end

    local combat = UnitAffectingCombat("player")
    local hostile = target.hostile
    local lists = {}
    if not combat and not hostile then lists[#lists + 1] = { "reminders", rotation.reminders } end
    if not combat then lists[#lists + 1] = { "preparation", rotation.preparation } end
    if combat or hostile then
        local rotations = rotation.rotations or {}
        lists[#lists + 1] = { "highprio", rotation.highprio }
        lists[#lists + 1] = { ns.mode, rotations[ns.mode] or rotations.single }
    end

    for _, source in ipairs(lists) do
        for _, entry in ipairs(source[2] or {}) do
            local name = ns.SpellName(entry[1])
            local start, duration
            if name then start, duration = GetSpellCooldown(name) end
            if start and Passes(entry, name) then -- start is nil for spells we don't know
                local remaining = start > 0 and (start + duration - GetTime()) or 0
                if duration <= GCD_MAX or remaining <= LOOKAHEAD then
                    if IsUsableSpell(name) then return name, "ready", start, duration, source[1] end
                elseif entry.wait then
                    return name, "cd", start, duration, source[1]
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
    local rotations = rotation.rotations or {}
    for _, source in ipairs({ { "reminders", rotation.reminders }, { "preparation", rotation.preparation },
                              { "highprio", rotation.highprio }, { ns.mode, rotations[ns.mode] } }) do
        local key = source[1]
        for _, entry in ipairs(source[2] or {}) do
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
        local lists = { rotation.reminders, rotation.preparation, rotation.highprio }
        for _, list in pairs(rotation.rotations or {}) do lists[#lists + 1] = list end
        for _, list in ipairs(lists) do
            for _, entry in ipairs(list) do
                set[ns.SpellName(entry[1])] = true
            end
        end
        inRotation[rotation] = set
    end
    return set[spell] or false
end
