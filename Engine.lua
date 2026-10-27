local ADDON_NAME, ns = ...

-- The condition API ("c") that rotation `when` functions read, and the evaluator that turns a
-- rotation into a single suggestion.
--
-- Everything on `c` is read live from the game when asked, there is no cached snapshot. That keeps
-- each condition correct on its own and costs little: the API calls are cheap and the evaluator
-- runs a few times a second.

local GCD_MAX = 1.5 -- a cooldown this short is just the global cooldown (haste can shrink it to 1.0)
ns.GCD_MAX = GCD_MAX
local LOOKAHEAD = 0.25 -- a spell this close to ready counts as ready, so the icon does not flicker at the edge

-- Returned for every missing aura. It is shared and must not be modified, which is what lets
-- conditions write `c.buff("X").up` without a nil check or an allocation on the miss path.
local NO_AURA = { up = false, remains = 0, stacks = 0, mine = false, duration = 0, expires = 0 }

-- Auras are looked up hundreds of times a second, so the tables are taken in turn from a fixed ring
-- instead of being created each time, which would leave all of them as garbage. The price is that
-- an aura is only valid for a short while: read it right away, never keep it across updates. The
-- ring is far larger than the number of auras any one check holds at once (a raid scan is 40).
local RING_SIZE = 128
local ring, ringNext = {}, 0
for i = 1, RING_SIZE do ring[i] = { up = true } end

local function NextAura()
    ringNext = ringNext % RING_SIZE + 1
    return ring[ringNext]
end

local function MakeAura(name, icon, count, duration, expires, caster)
    local aura = NextAura()
    aura.name = name
    aura.icon = icon
    aura.duration = duration or 0
    aura.expires = expires or 0
    -- an expiry of 0 means the aura never runs out; huge keeps `remains < 30` style checks false
    aura.remains = (expires and expires > 0) and (expires - GetTime()) or math.huge
    aura.stacks = (count and count > 0) and count or 1 -- the game reports 0 for "no stacks", which is 1 for us
    aura.mine = caster == "player"
    return aura
end

-- Unit names built once, so scanning the group does not concatenate strings every time.
local RAID_UNITS, PARTY_UNITS = {}, {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end
for i = 1, 4 do PARTY_UNITS[i] = "party" .. i end

local function GroupUnits()
    local raid = GetNumRaidMembers()
    if raid > 0 then return RAID_UNITS, raid end
    return PARTY_UNITS, GetNumPartyMembers()
end

local EMPTY = {} -- stands in for a missing list; never written to

-- fn is UnitBuff or UnitDebuff. A filter of "PLAYER" restricts it to auras cast by the player.
local function Aura(fn, unit, name, filter)
    local found, _, icon, count, _, duration, expires, caster = fn(unit, name, nil, filter)
    if not found then return NO_AURA end
    return MakeAura(found, icon, count, duration, expires, caster)
end

-- The first aura on a unit whose dispel type is one of the given types ("Magic", "Disease", ...).
-- It has to scan by index because the type is only known after looking at each aura.
local function AuraOfType(fn, unit, ...)
    for i = 1, 40 do
        local name, _, icon, count, auraType, duration, expires, caster = fn(unit, i)
        if not name then break end
        for j = 1, select("#", ...) do
            if auraType == select(j, ...) then
                return MakeAura(name, icon, count, duration, expires, caster)
            end
        end
    end
    return NO_AURA
end

local function Percent(current, max)
    if not max or max == 0 then return 0 end -- a unit that does not exist reports 0 max health
    return current / max * 100
end

-- The target, the pet and the variants are tables with computed fields, so a condition reads
-- `c.target.hp` like a plain value while the lookup happens only when it is actually used.

local target = setmetatable({}, {
    __index = function(_, key)
        if key == "exists" then return UnitExists("target") and true or false
        elseif key == "hostile" then
            -- a dead hostile is not worth reacting to, so "hostile" means attackable and alive
            return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
                and true or false
        elseif key == "hp" then return Percent(UnitHealth("target"), UnitHealthMax("target"))
        elseif key == "boss" then return UnitClassification("target") == "worldboss" or UnitLevel("target") == -1
        elseif key == "casting" then return UnitCastingInfo("target") ~= nil
        elseif key == "creatureType" then return UnitCreatureType("target") -- localized, "Undead" on an English client
        end
    end,
})

function target.buff(name) return Aura(UnitBuff, "target", name) end

function target.buffOfType(...) return AuraOfType(UnitBuff, "target", ...) end

-- The cheap yes/no version of buffOfType, for conditions that do not need the aura itself.
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

-- "exists" is false for a dead pet on purpose: most rules (Mend Pet) only make sense for a living one,
-- and the dead case has its own field. "missing" and "dead" are separate because they need different
-- spells (Call Pet / Revive Pet).
local pet = setmetatable({}, {
    __index = function(_, key)
        if key == "exists" then return UnitExists("pet") and not UnitIsDead("pet") and true or false
        elseif key == "hp" then return Percent(UnitHealth("pet"), UnitHealthMax("pet"))
        elseif key == "missing" then return not UnitExists("pet")
        elseif key == "dead" then return UnitExists("pet") and UnitIsDead("pet") and true or false
        elseif key == "hungry" then
            -- hunter pet happiness is 1 unhappy, 2 content, 3 happy; anything below happy is worth feeding.
            -- GetPetHappiness is nil for pets that have no happiness, which must not count as hungry.
            local happiness = UnitExists("pet") and not UnitIsDead("pet") and GetPetHappiness()
            return happiness and happiness < 3 or false
        end
    end,
})

function pet.buff(name) return Aura(UnitBuff, "pet", name) end

-- Is a living pet of this name out? A summoned guardian (the Shadowfiend) takes the pet slot while
-- it lasts and carries the creature's name, which is the summon spell's. A hunter's or warlock's
-- pet has a name of its own, so it cannot pass for one.
function pet.named(name)
    return UnitExists("pet") and not UnitIsDead("pet") and UnitName("pet") == name and true or false
end

-- That guardian shaped like an aura, so a side slot can read it like any other. Its time left is
-- not known to the client, so it has no duration and gets no sweep.
function pet.aura(name)
    if not pet.named(name) then return NO_AURA end
    local aura = NextAura()
    aura.name, aura.icon = name, select(3, GetSpellInfo(name))
    aura.duration, aura.expires, aura.remains = 0, 0, math.huge
    aura.stacks, aura.mine = 1, true
    return aura
end

-- Ready runes by their current type: c.runes.blood, .unholy, .frost and .death. A rune converted
-- to a death rune counts as death only, whichever slot it sits in.
local RUNE_TYPES = { "blood", "unholy", "frost", "death" } -- the order GetRuneType numbers them in
local runes = setmetatable({}, {
    __index = function(_, key)
        local wanted
        for type, name in ipairs(RUNE_TYPES) do
            if name == key then wanted = type end
        end
        if not wanted then return end
        local count = 0
        for rune = 1, 6 do
            local _, _, ready = GetRuneCooldown(rune)
            if ready and GetRuneType(rune) == wanted then count = count + 1 end
        end
        return count
    end,
})

-- c.variant.judgement is the current option of the rotation's "judgement" variant (see Rotation.lua)
local variant = setmetatable({}, { __index = function(_, name) return ns.GetVariant(name) end })

local c = setmetatable({ target = target, pet = pet, variant = variant, runes = runes }, {
    __index = function(_, key)
        if key == "combat" then return UnitAffectingCombat("player") and true or false
        elseif key == "mana" then return Percent(UnitPower("player", 0), UnitPowerMax("player", 0))
        elseif key == "hp" then return Percent(UnitHealth("player"), UnitHealthMax("player"))
        elseif key == "moving" then return GetUnitSpeed("player") > 0
        elseif key == "inGroup" then return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
        elseif key == "mode" then return ns.mode
        end
    end,
})
ns.c = c

-- The spell name the current option of a variant stands for, e.g. "Judgement of Light".
function c.variantName(name) return ns.VariantSpell(name) end

-- Auras ---------------------------------------------------------------------

function c.buff(name) return Aura(UnitBuff, "player", name) end

-- The first of several interchangeable buffs that is up (aspects...), so a rule does not
-- have to care which of them the player chose.
function c.anyBuff(names)
    for _, name in ipairs(names) do
        local aura = c.buff(name)
        if aura.up then return aura end
    end
    return NO_AURA
end

-- The player's own copy of a buff on any unit. Another druid's Rejuvenation does not stop yours from
-- stacking with it, so only the caster counts for hots.
function c.buffOn(unit, name) return Aura(UnitBuff, unit, name, "PLAYER") end

-- A buff on any unit from any caster, for effects that count no matter who cast them.
function c.buffOnAny(unit, name) return Aura(UnitBuff, unit, name) end

function c.selfDebuff(name) return Aura(UnitDebuff, "player", name) end

-- Debuffs on the target are only the player's own by default: another player's Serpent Sting says
-- nothing about whether yours is up. Pass { any = true } for debuffs that count from anyone.
function c.debuff(name, opts)
    return Aura(UnitDebuff, "target", name, not (opts and opts.any) and "PLAYER" or nil)
end

-- c.debuff(name, { any = true }) without building the options table on every check.
function c.debuffAny(name) return Aura(UnitDebuff, "target", name) end

-- A debuff on any unit from any caster, for restrictions like Weakened Soul that apply no matter
-- which priest cast it.
function c.debuffOn(unit, name) return Aura(UnitDebuff, unit, name) end

function c.debuffOfType(unit, ...) return AuraOfType(UnitDebuff, unit, ...) end

-- The player's own copy of a single-target buff (Beacon of Light) on anyone in the group. Only
-- the player's copies count, and the one with the most time left wins, because that is the one
-- that decides when a refresh is due.
function c.groupBuff(name)
    local best = Aura(UnitBuff, "player", name, "PLAYER")
    local units, count = GroupUnits()
    for i = 1, count do
        local aura = Aura(UnitBuff, units[i], name, "PLAYER")
        if aura.up and (not best.up or aura.remains > best.remains) then best = aura end
    end
    return best
end

-- True when any other group member satisfies test(unit). Only party members who are really there
-- count (they exist and are connected).
function c.anyOtherMember(test)
    local units, count = GroupUnits()
    for i = 1, count do
        local unit = units[i]
        if not UnitIsUnit(unit, "player") and UnitExists(unit) and UnitIsConnected(unit) and test(unit) then
            return true
        end
    end
    return false
end

-- The temporary enchant on the main hand (shaman weapon imbues), shaped like an aura so a rule reads
-- `.up` and `.remains`. The game only says that there is one, not which, so the name is not known.
function c.mainHandEnchant()
    local has, expiration = GetWeaponEnchantInfo()
    if not has then return NO_AURA end
    local aura = NextAura()
    aura.name, aura.icon = nil, nil
    aura.remains = expiration / 1000
    aura.stacks, aura.mine, aura.duration = 0, true, 0
    aura.expires = GetTime() + aura.remains
    return aura
end

-- Who a heal would go to, the way a mouseover/target/self macro picks: the mouseover if it is a
-- living friend, else the target if it is, else the player. Used so Weakened Soul and dispel
-- checks look at the unit the next spell would actually land on.
local HEAL_CANDIDATES = { "mouseover", "target" }
function c.healTarget()
    for _, unit in ipairs(HEAL_CANDIDATES) do
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            return unit
        end
    end
    return "player"
end

-- Spells -------------------------------------------------------------------

-- Remaining cooldown ignoring the global cooldown: GetSpellCooldown reports the GCD for any spell
-- while it runs, which would make every spell look like it had a cooldown after each cast.
function c.cd(name)
    local start, duration = GetSpellCooldown(name)
    if not start or duration <= GCD_MAX or start == 0 then return 0 end
    return math.max(0, start + duration - GetTime())
end

function c.ready(name)
    local start, duration = GetSpellCooldown(name) -- start is nil for a spell the player does not know
    if not start then return false end
    local remaining = start > 0 and (start + duration - GetTime()) or 0
    return (duration <= GCD_MAX or remaining <= LOOKAHEAD) and (IsUsableSpell(name)) and true or false
end

-- Seconds since the player last cast a spell successfully, for abilities that are paced by us
-- rather than by a cooldown (Pestilence). Huge if it has not been cast this session.
local lastCast = {}
local castWatcher = CreateFrame("Frame")
castWatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castWatcher:SetScript("OnEvent", function(_, _, unit, spell)
    if unit == "player" then lastCast[spell] = GetTime() end
end)

function c.sinceCast(name)
    return lastCast[name] and (GetTime() - lastCast[name]) or math.huge
end

function c.usable(name) return (IsUsableSpell(name)) and true or false end

-- Evaluation ---------------------------------------------------------------

-- IsUsableSpell also looks at the current target, which is wrong for a spell cast on someone else
-- (a Power Word: Shield with an enemy targeted reads as unusable). Entries marked manaOnly skip
-- that and only check that the player can pay for it.
local function Usable(entry, name)
    if entry.item then return (IsUsableItem(name)) and true or false end
    if not entry.manaOnly then return (IsUsableSpell(name)) and true or false end
    local _, _, _, cost, _, powerType = GetSpellInfo(name)
    return not cost or cost == 0 or UnitPower("player", powerType or 0) >= cost
end

-- Runs an entry's `when`. An error is caught and reported once per entry: this runs many times a
-- second, and one broken line in a rotation file should neither take the addon down nor flood the chat.
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

-- An entry is a spell ({ "Name" }, or a variant), or an item ({ item = "Name" }) that is only offered while it is in the bags.
local function EntryName(entry)
    if entry.variant then return ns.VariantSpell(entry.variant) end
    return entry.item or ns.SpellName(entry[1])
end

-- Returns nil for a spell or item the player does not have, which is how unknown entries drop out.
local function EntryCooldown(entry, name)
    if not entry.item then return GetSpellCooldown(name) end
    if GetItemCount(name) == 0 then return nil end
    local _, link = GetItemInfo(name)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return nil end -- the item is not cached yet, the next evaluation will have it
    return GetItemCooldown(id)
end

-- A tier of the rotation followed by the same tier of the shared entries (Common.lua). Cached
-- because the evaluator asks for it several times a second.
local tiers = setmetatable({}, { __mode = "k" })
local function Tier(rotation, key)
    local cache = tiers[rotation]
    if not cache then cache = {}; tiers[rotation] = cache end
    if not cache[key] then
        local list = {}
        for _, entry in ipairs(rotation[key] or EMPTY) do list[#list + 1] = entry end
        for _, entry in ipairs(ns.common and ns.common[key] or EMPTY) do list[#list + 1] = entry end
        cache[key] = list
    end
    return cache[key]
end
ns.Tier = Tier

-- Returns the suggestion: spell, state ("ready" | "cd"), cooldown start, cooldown duration and the
-- tier it came from ("reminders", "preparation", "highprio", or the mode). Nothing when there is none.
--
-- Which tiers are looked at depends on the situation:
--   out of combat, no hostile target:  reminders, preparation, highprio, the mode's rotation
--   out of combat, hostile target:     preparation, highprio, the mode's rotation
--   in combat:                         highprio, the mode's rotation
-- Highprio and the rotation never need a target; entries that do (a debuff on the target) read as
-- not applicable without one. What decides whether the frame is on screen is Visibility.lua.
-- Reminders are skipped once a hostile target is up: a pull is about to happen, and a reminder
-- that contradicts it (swap to Viper) would be wrong.
-- The tiers to look at, as parallel arrays refilled on every call rather than built anew.
local sourceNames, sourceLists, sourceCount = {}, {}, 0
local function AddSource(name, list)
    sourceCount = sourceCount + 1
    sourceNames[sourceCount], sourceLists[sourceCount] = name, list or EMPTY
end

function ns.Evaluate()
    local rotation = ns.GetRotation()
    if not rotation then return end

    local combat = UnitAffectingCombat("player")
    local hostile = target.hostile
    sourceCount = 0
    if not combat and not hostile then AddSource("reminders", Tier(rotation, "reminders")) end
    if not combat then AddSource("preparation", rotation.preparation) end
    local rotations = rotation.rotations or EMPTY
    AddSource("highprio", Tier(rotation, "highprio"))
    AddSource(ns.mode, rotations[ns.mode] or rotations.single)

    -- If nothing is ready, show the combat spell that comes off cooldown first rather than an
    -- empty icon: it tells the player what to expect next. Reminders and preparation are excluded
    -- since a reminder you cannot act on yet is not useful.
    local soonest, soonestRemaining, soonestStart, soonestDuration, soonestSource

    for i = 1, sourceCount do
        local sourceName = sourceNames[i]
        local combatList = sourceName ~= "reminders" and sourceName ~= "preparation"
        for _, entry in ipairs(sourceLists[i]) do
            local name = EntryName(entry)
            local start, duration
            if name then start, duration = EntryCooldown(entry, name) end

            if start and Passes(entry, name) then
                local remaining = start > 0 and (start + duration - GetTime()) or 0
                if duration <= GCD_MAX or remaining <= LOOKAHEAD then
                    if Usable(entry, name) then return name, "ready", start, duration, sourceName end
                elseif entry.wait then
                    -- `wait` means "hold here rather than fall through to lower priorities"
                    return name, "cd", start, duration, sourceName
                elseif combatList and (not soonestRemaining or remaining < soonestRemaining) then
                    soonest, soonestRemaining, soonestStart, soonestDuration, soonestSource =
                        name, remaining, start, duration, sourceName
                end
            end
        end
    end

    if soonest then return soonest, "cd", soonestStart, soonestDuration, soonestSource end

    -- Resource gated spells (runes, mana) have no cooldown to count down, they are just unusable
    -- until the resource is back. The last entry of a rotation is its filler, so show it grayed out.
    local list = sourceLists[sourceCount]
    local name = list[#list] and EntryName(list[#list])
    if name and EntryCooldown(list[#list], name) then return name, "unusable", 0, 0, ns.mode end
end

-- Prints why the suggestion is what it is, entry by entry (/rotato debug).
function ns.DebugEvaluate()
    local rotation = ns.GetRotation()
    ns.Print(format("class=%s spec=%s rotation=%s mode=%s combat=%s hostile=%s", tostring(ns.class),
        tostring(ns.specIndex), rotation and "found" or "NONE", ns.mode, tostring(c.combat), tostring(target.hostile)))
    if not rotation then return end

    local rotations = rotation.rotations or {}
    local sources = {
        { "reminders", Tier(rotation, "reminders") },
        { "preparation", rotation.preparation },
        { "highprio", Tier(rotation, "highprio") },
        { ns.mode, rotations[ns.mode] },
    }
    for _, source in ipairs(sources) do
        for _, entry in ipairs(source[2] or {}) do
            local name = EntryName(entry)
            local start, duration
            if name then start, duration = EntryCooldown(entry, name) end
            ns.Print(format("  %s: %s known=%s when=%s usable=%s cd=%s", source[1], tostring(name),
                tostring(start ~= nil), tostring(start and Passes(entry, name)),
                tostring(name and Usable(entry, name)),
                tostring(start and format("%.1f/%.1f", start, duration))))
        end
    end
    ns.Print("suggestion: " .. tostring((ns.Evaluate())))
end

-- Whether a spell appears anywhere in the active rotation, used to decide if a cast in progress
-- is part of the rotation (and so worth showing) or something unrelated like eating. The shared
-- reminders are left out because they are items, never casts.
local inRotation = setmetatable({}, { __mode = "k" })
function ns.InRotation(spell)
    local rotation = ns.GetRotation()
    if not rotation then return false end

    local set = inRotation[rotation]
    if not set then
        set = {}
        -- built with an explicit count: a rotation without one of these tiers would leave a nil
        -- hole in a table constructor, and ipairs would stop there
        local lists = {}
        for _, tier in ipairs({ "reminders", "preparation", "highprio" }) do
            if rotation[tier] then lists[#lists + 1] = rotation[tier] end
        end
        for _, list in pairs(rotation.rotations or {}) do lists[#lists + 1] = list end
        for _, list in ipairs(lists) do
            for _, entry in ipairs(list) do
                if entry.variant then
                    -- the set is cached, so it must hold every option, not just the current one
                    for _, variantSpell in ipairs(ns.VariantAllSpells(entry.variant)) do set[variantSpell] = true end
                else
                    set[EntryName(entry)] = true
                end
            end
        end
        inRotation[rotation] = set
    end
    return set[spell] or false
end
