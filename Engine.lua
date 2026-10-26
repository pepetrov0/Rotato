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
        elseif k == "creatureType" then return UnitCreatureType("target") -- localized, e.g. "Undead"
        end
    end,
})

-- the first aura on a unit whose dispel type is one of the given types (NO_AURA if none);
-- fn is UnitBuff or UnitDebuff
local function AuraOfType(fn, unit, ...)
    for i = 1, 40 do
        local name, _, icon, count, auraType, duration, expires, caster = fn(unit, i)
        if not name then break end
        for j = 1, select("#", ...) do
            if auraType == select(j, ...) then
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

function target.buffOfType(...) return AuraOfType(UnitBuff, "target", ...) end

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

-- the player's pet; "exists" is false for a dead pet, "missing" means no pet at all, "dead" a dead one, "hungry" a hunter pet that is not fully happy
local pet = setmetatable({}, {
    __index = function(_, k)
        if k == "exists" then return UnitExists("pet") and not UnitIsDead("pet") and true or false
        elseif k == "hp" then return Percent(UnitHealth("pet"), UnitHealthMax("pet"))
        elseif k == "hungry" then
            -- hunter pet happiness: 1 unhappy, 2 content, 3 happy; below happy counts as hungry
            local happiness = UnitExists("pet") and not UnitIsDead("pet") and GetPetHappiness()
            return happiness and happiness < 3 or false
        elseif k == "missing" then return not UnitExists("pet")
        elseif k == "dead" then return UnitExists("pet") and UnitIsDead("pet") and true or false
        end
    end,
})

function pet.buff(name) return Aura(UnitBuff, "pet", name) end

-- c.variant.judgement -> the current option of the rotation's "judgement" variant
local variant = setmetatable({}, { __index = function(_, name) return ns.GetVariant(name) end })

local c = setmetatable({ target = target, pet = pet, variant = variant }, {
    __index = function(_, k)
        if k == "combat" then return UnitAffectingCombat("player") and true or false
        elseif k == "mana" then return Percent(UnitPower("player", 0), UnitPowerMax("player", 0))
        elseif k == "hp" then return Percent(UnitHealth("player"), UnitHealthMax("player"))
        elseif k == "moving" then return GetUnitSpeed("player") > 0
        elseif k == "mode" then return ns.mode
        elseif k == "inRaid" then
            local _, instanceType = IsInInstance()
            return instanceType == "raid"
        end
    end,
})

-- the spell name the current option of a variant stands for, e.g. "Judgement of Light"
function c.variantName(name) return ns.VariantSpell(name) end

function c.buff(name) return Aura(UnitBuff, "player", name) end

-- your own buff on the player or any party/raid member: the one with the most time left, or NO_AURA
-- if nobody has it (for single-target buffs such as Beacon of Light)
function c.groupBuff(name)
    local units = { "player" }
    local raid = GetNumRaidMembers()
    if raid > 0 then
        for i = 1, raid do units[#units + 1] = "raid" .. i end
    else
        for i = 1, GetNumPartyMembers() do units[#units + 1] = "party" .. i end
    end
    local best = NO_AURA
    for _, unit in ipairs(units) do
        local aura = Aura(UnitBuff, unit, name, "PLAYER")
        if aura.up and (not best.up or aura.remains > best.remains) then best = aura end
    end
    return best
end

-- debuffs on the player
function c.selfDebuff(name) return Aura(UnitDebuff, "player", name) end

-- the first debuff on a unit whose dispel type is one of the given types ("Magic", "Disease", ...)
function c.debuffOfType(unit, ...) return AuraOfType(UnitDebuff, unit, ...) end

-- debuffs on any unit, from any caster (e.g. Weakened Soul on an ally)
function c.debuffOn(unit, name) return Aura(UnitDebuff, unit, name) end

-- Who a heal would go to, as a mouseover/target/self macro would pick: the mouseover if it is a
-- living friend, else the target if it is, else the player.
function c.healTarget()
    for _, unit in ipairs({ "mouseover", "target" }) do
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            return unit
        end
    end
    return "player"
end

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

-- known, off cooldown (ignoring the global cooldown) and usable right now
function c.ready(name)
    local start, duration = GetSpellCooldown(name)
    if not start then return false end
    local remaining = start > 0 and (start + duration - GetTime()) or 0
    return (duration <= GCD_MAX or remaining <= LOOKAHEAD) and (IsUsableSpell(name)) and true or false
end

function c.usable(name) return (IsUsableSpell(name)) and true or false end

ns.c = c

-- Evaluation ------------------------------------------------------------

-- IsUsableSpell also looks at the current target, which is wrong for spells cast on someone else
-- (a Power Word: Shield with an enemy targeted). Entries with manaOnly = true only check the cost.
local function Usable(entry, name)
    if entry.item then return (IsUsableItem(name)) and true or false end
    if not entry.manaOnly then return (IsUsableSpell(name)) and true or false end
    local _, _, _, cost, _, powerType = GetSpellInfo(name)
    return not cost or cost == 0 or UnitPower("player", powerType or 0) >= cost
end

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

-- Entries are spells ({ "Name" }) or items ({ item = "Name" }, only when it is in the bags).
local function EntryName(entry)
    if entry.variant then return ns.VariantSpell(entry.variant) end
    return entry.item or ns.SpellName(entry[1])
end

local function EntryCooldown(entry, name)
    if not entry.item then return GetSpellCooldown(name) end
    if GetItemCount(name) == 0 then return nil end
    local _, link = GetItemInfo(name)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return nil end
    return GetItemCooldown(id)
end

-- A tier of the rotation plus the shared entries of the same tier (ns.common), cached.
local tiers = setmetatable({}, { __mode = "k" })
local function Tier(rotation, key)
    local cache = tiers[rotation]
    if not cache then cache = {}; tiers[rotation] = cache end
    if not cache[key] then
        local list = {}
        for _, entry in ipairs(rotation[key] or {}) do list[#list + 1] = entry end
        for _, entry in ipairs(ns.common and ns.common[key] or {}) do list[#list + 1] = entry end
        cache[key] = list
    end
    return cache[key]
end

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
    if not combat and not hostile then lists[#lists + 1] = { "reminders", Tier(rotation, "reminders") } end
    if not combat then lists[#lists + 1] = { "preparation", rotation.preparation } end
    if combat or hostile then
        local rotations = rotation.rotations or {}
        lists[#lists + 1] = { "highprio", Tier(rotation, "highprio") }
        lists[#lists + 1] = { ns.mode, rotations[ns.mode] or rotations.single }
    end

    -- when nothing is ready, the fallback is the combat spell that comes off cooldown first
    local soonest, soonestRemaining, soonestStart, soonestDuration, soonestSource
    for _, source in ipairs(lists) do
        local combatList = source[1] ~= "reminders" and source[1] ~= "preparation"
        for _, entry in ipairs(source[2] or {}) do
            local name = EntryName(entry)
            local start, duration
            if name then start, duration = EntryCooldown(entry, name) end
            if start and Passes(entry, name) then -- start is nil for spells we don't know
                local remaining = start > 0 and (start + duration - GetTime()) or 0
                if duration <= GCD_MAX or remaining <= LOOKAHEAD then
                    if Usable(entry, name) then return name, "ready", start, duration, source[1] end
                elseif entry.wait then
                    return name, "cd", start, duration, source[1]
                elseif combatList and (not soonestRemaining or remaining < soonestRemaining) then
                    soonest, soonestRemaining, soonestStart, soonestDuration, soonestSource = name, remaining, start, duration, source[1]
                end
            end
        end
    end
    if soonest then return soonest, "cd", soonestStart, soonestDuration, soonestSource end
end

-- Prints why the suggestion is what it is, for /rotato debug.
function ns.DebugEvaluate()
    local rotation = ns.GetRotation()
    ns.Print(format("class=%s spec=%s rotation=%s mode=%s combat=%s hostile=%s", tostring(ns.class),
        tostring(ns.specIndex), rotation and "found" or "NONE", ns.mode, tostring(c.combat), tostring(target.hostile)))
    if not rotation then return end
    local rotations = rotation.rotations or {}
    for _, source in ipairs({ { "reminders", Tier(rotation, "reminders") }, { "preparation", rotation.preparation },
                              { "highprio", Tier(rotation, "highprio") }, { ns.mode, rotations[ns.mode] } }) do
        local key = source[1]
        for _, entry in ipairs(source[2] or {}) do
            local name = EntryName(entry)
            local start, duration
            if name then start, duration = EntryCooldown(entry, name) end
            ns.Print(format("  %s: %s known=%s when=%s usable=%s cd=%s", key, tostring(name), tostring(start ~= nil),
                tostring(start and Passes(entry, name)), tostring(name and Usable(entry, name)),
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
                if entry.variant then
                    for _, spell in ipairs(ns.VariantAllSpells(entry.variant)) do set[spell] = true end
                else
                    set[EntryName(entry)] = true
                end
            end
        end
        inRotation[rotation] = set
    end
    return set[spell] or false
end
