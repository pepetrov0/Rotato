local ADDON_NAME, ns = ...

-- Registry of rotation definitions. Rotation files call ns.Rotation{ class=, spec=, reminders=, preparation=, highprio=, rotations={ single=, multi=, aoe= },
-- defensives=, utility=, trackers=, offensives= (see Slots.lua),
-- consumables={ raid flasks/elixirs to remind about, see Common.lua } };
-- omitting spec makes the rotation apply to every spec of that class.
ns.rotations = {}

function ns.Rotation(def)
    ns.rotations[def.class .. ":" .. (def.spec or "*")] = def
end

-- The rotation for the detected class and spec (see Class.lua), or nil.
function ns.GetRotation()
    if not ns.class then return end
    return ns.rotations[ns.class .. ":" .. tostring(ns.specIndex)] or ns.rotations[ns.class .. ":*"]
end

-- Entries name spells by name or by spell ID.
function ns.SpellName(spell)
    if type(spell) == "number" then return (GetSpellInfo(spell)) end
    return spell
end

-- Variants -------------------------------------------------------------
-- A rotation can declare named choices, e.g.
--   variants = { judgement = { default = "light", light = { "Judgement of Light" }, wisdom = { "Judgement of Wisdom" } } }
-- Casting a spell listed under an option makes that option the current one (not saved between sessions).
-- Entries then use { variant = "judgement" } in place of a spell name, and debuff = { variant = "judgement" }
-- (or buff / targetBuff) in side slots.

-- the current options, per "CLASS:spec"; kept in memory only, so every session starts on the defaults
local chosen = {}

local function VariantKey() return (ns.class or "") .. ":" .. tostring(ns.specIndex or 0) end

local function VariantDefinition(name)
    local rotation = ns.GetRotation()
    return rotation and rotation.variants and rotation.variants[name]
end

-- the current option of a variant ("light", "wisdom", ...), or nil if the rotation has no such variant
function ns.GetVariant(name)
    local definition = VariantDefinition(name)
    if not definition then return nil end
    local saved = chosen[VariantKey()]
    saved = saved and saved[name]
    if saved and type(definition[saved]) == "table" then return saved end
    return definition.default
end

function ns.SetVariant(name, option)
    if ns.GetVariant(name) == option then return end
    local key = VariantKey()
    chosen[key] = chosen[key] or {}
    chosen[key][name] = option
    ns.Print(format("%s: %s", name, option))
end

-- the spell the current option stands for (the first one listed under it)
function ns.VariantSpell(name)
    local definition = VariantDefinition(name)
    local option = definition and ns.GetVariant(name)
    local spells = option and definition[option]
    return spells and ns.SpellName(spells[1])
end

-- every spell of every option of a variant
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

-- Called for each spell the player casts: switches a variant to the option that lists the spell.
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

