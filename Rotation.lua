local ADDON_NAME, ns = ...

-- Registry of rotation definitions, and the "variants" a rotation can declare.
--
-- A rotation file calls ns.Rotation{ ... } with these fields (all optional but class):
--   class, spec          which character it is for; no spec means every spec of the class
--   minLevel             lowest character level it applies from (default 1), see ns.GetRotation
--   reminders            out of combat with no hostile target; keeps the panel up until done
--   preparation          out of combat setup
--   highprio             checked before the rotations, with or without a target
--   rotations            { single = {...}, multi = {...}, aoe = {...} }, see Mode.lua
--   defensives, utility, trackers, offensives    the side slots, see Slots.lua
--   variants             named choices that follow what the player casts, see below

ns.rotations = {}

-- A key can hold several rotations, each valid from its own level: a levelling rotation for the
-- baseline kit, then the full one once the spec has its abilities. They are kept in registration
-- order and both are tried, so the selection below can choose by level.
function ns.Rotation(def)
    local key = def.class .. ":" .. (def.spec or "*")
    local list = ns.rotations[key]
    if not list then list = {}; ns.rotations[key] = list end
    list[#list + 1] = def
end

-- The rotation in a list that applies at this level: the one with the highest minLevel that is
-- not above it. Two starting at the same level resolve to the later registered one, so a file
-- loaded afterwards can replace an earlier default.
local function AtLevel(list, level)
    local best, bestLevel
    for _, def in ipairs(list) do
        local min = tonumber(def.minLevel) or 1
        if min <= level and (not bestLevel or min >= bestLevel) then best, bestLevel = def, min end
    end
    return best
end

-- The spec-specific rotation wins over a class-wide one. A spec whose rotations all start above
-- the player's level falls through to the class-wide one, which is how a levelling character gets
-- a rotation instead of none. Returns nil until Class.lua has detected the character, which
-- callers rely on to do nothing early in the login.
local current

local function Describe(def)
    return format("%s %s (level %d+)", def.class, def.spec and ("spec " .. def.spec) or "class-wide",
        tonumber(def.minLevel) or 1)
end

local function Select()
    local level = UnitLevel("player")
    local spec = ns.rotations[ns.class .. ":" .. tostring(ns.specIndex)]
    local rotation = spec and AtLevel(spec, level)
    if rotation then return rotation end
    local class = ns.rotations[ns.class .. ":*"]
    return class and AtLevel(class, level)
end

function ns.GetRotation()
    if not ns.class then return end
    local rotation = Select()
    if rotation ~= current then
        current = rotation
        ns.Print("rotation in use: " .. (rotation and Describe(rotation) or "none"))
    end
    return rotation
end

-- Rotation files may use a spell ID instead of a name: names are locale-dependent, IDs are not.
function ns.SpellName(spell)
    if type(spell) == "number" then return (GetSpellInfo(spell)) end
    return spell
end

-- Variants ---------------------------------------------------------------
-- Some choices cannot be read from the game state, only from what the player does: a paladin
-- keeping up Judgement of Light or of Wisdom is the example. A rotation declares them:
--
--   variants = { judgement = { default = "light",
--                              light  = { "Judgement of Light" },
--                              wisdom = { "Judgement of Wisdom" } } }
--
-- Casting a spell listed under an option makes that option the current one. Entries then say
-- { variant = "judgement" } instead of a spell name (and debuff = { variant = ... } in side slots),
-- and everything that used the old option follows without being edited.

-- The current options, per "CLASS:spec". Kept in memory only, so each session starts from the
-- defaults: the choice reflects what the player is doing now, not what they did last week.
local chosen = {}

local function VariantKey() return (ns.class or "") .. ":" .. tostring(ns.specIndex or 0) end

local function VariantDefinition(name)
    local rotation = ns.GetRotation()
    return rotation and rotation.variants and rotation.variants[name]
end

-- The current option of a variant ("light", "wisdom", ...), or nil if the rotation has no such variant.
function ns.GetVariant(name)
    local definition = VariantDefinition(name)
    if not definition then return nil end
    local option = chosen[VariantKey()]
    option = option and option[name]
    -- the type check drops a stale choice, e.g. from before the option was renamed in the file
    if option and type(definition[option]) == "table" then return option end
    return definition.default
end

function ns.SetVariant(name, option)
    if ns.GetVariant(name) == option then return end -- called on every cast, only report real changes
    local key = VariantKey()
    chosen[key] = chosen[key] or {}
    chosen[key][name] = option
    ns.Log(format("%s: %s", name, option))
end

-- The spell the current option stands for: the first one listed under it.
function ns.VariantSpell(name)
    local definition = VariantDefinition(name)
    local option = definition and ns.GetVariant(name)
    local spells = option and definition[option]
    return spells and ns.SpellName(spells[1])
end

-- Every spell of every option. Caches elsewhere (which spells belong to a rotation) need all of
-- them, because the current option can change after the cache is built.
function ns.VariantAllSpells(name)
    local definition = VariantDefinition(name)
    local all = {}
    for option, spells in pairs(definition or {}) do
        if option ~= "default" and type(spells) == "table" then
            for _, spell in ipairs(spells) do all[#all + 1] = ns.SpellName(spell) end
        end
    end
    return all
end

-- Called for every spell the player casts: switches a variant to the option that lists the spell.
function ns.CheckVariants(rotation, spell)
    for name, definition in pairs(rotation.variants or {}) do
        for option, spells in pairs(definition) do
            if option ~= "default" and type(spells) == "table" then
                for _, listed in ipairs(spells) do
                    if ns.SpellName(listed) == spell then
                        ns.SetVariant(name, option)
                        return
                    end
                end
            end
        end
    end
end
