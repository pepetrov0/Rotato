local ADDON_NAME, ns = ...

-- Registry of rotation definitions, and the "variants" a rotation can declare.
--
-- A rotation file calls ns.Rotation{ ... } with these fields (all optional but name):
--   name                 unique; what the player sees in the picker and what is remembered
--   filter               function(c) -> truthy when the rotation is offered (default: always); c has
--                        .class, .spec (talent tree index, nil with no points) and .level
--   reminders            out of combat with no hostile target; keeps the panel up until done
--   preparation          out of combat setup
--   highprio             checked before the rotations, with or without a target
--   rotations            { single = {...}, multi = {...}, aoe = {...} }, see Mode.lua
--   defensives, utility, trackers, offensives    the side slots, see Slots.lua
--   variants             named choices that follow what the player casts, see below

ns.rotations = {}

-- Rotations are kept in registration order, which is the order the picker lists them in.
function ns.Rotation(def)
    ns.rotations[#ns.rotations + 1] = def
end

-- Choosing --------------------------------------------------------------
-- The rotations whose filter passes are the ones on offer. With one it is used without asking;
-- with several the player picks (Picker.lua) and the pick is remembered per character. The offer
-- is re-read every second, which catches a level up, a learned spell or talent, a respec or
-- whatever else a filter looks at, without listing events. The player is asked again when the
-- offered list changes in any way, or when the one they picked is gone; until
-- they answer, no rotation is used.
-- ns.GetRotation returns nil until Class.lua has detected the character, which callers rely on to
-- do nothing early in the login.
local current, offered, asked

local function CharacterState()
    RotatoDB.rotation = RotatoDB.rotation or {}
    local key = UnitName("player") .. "-" .. GetRealmName()
    RotatoDB.rotation[key] = RotatoDB.rotation[key] or {}
    return RotatoDB.rotation[key]
end

local function Available()
    local list = {}
    for _, def in ipairs(ns.rotations) do
        if not def.filter or def.filter(ns.c) then list[#list + 1] = def end
    end
    return list
end

local function Use(rotation)
    if rotation == current then return end
    current = rotation
    ns.Print("rotation in use: " .. (rotation and rotation.name or "none"))
end

local function Pick(def)
    CharacterState().pick = def.name
    Use(def)
end

local function Refresh()
    if not ns.class then return end
    local list, state = Available(), CharacterState()
    offered = list

    local picked
    for _, def in ipairs(list) do
        if def.name == state.pick then picked = def end
    end

    -- any change to the offered list counts, even to a rotation the player has seen before
    local names = {}
    for _, def in ipairs(list) do names[#names + 1] = def.name end
    local signature = table.concat(names, "\n")
    local fresh = state.offer ~= signature
    state.offer = signature

    -- With several on offer and no valid pick, no rotation is used until the player answers. The
    -- picker is shown once per session for that (closing it does not bring it back every second),
    -- and again whenever the offered list changes. A lone rotation needs no pick.
    local gone = not picked
    if gone and #list == 1 then picked = list[1]; gone = false end
    state.pick = picked and picked.name
    Use(picked)

    if #list > 1 and (fresh or (gone and not asked)) then
        asked = true
        ns.ShowPicker(list, picked, Pick)
    elseif #list <= 1 then
        ns.HidePicker()
    end
end

-- /rotato rotation: the picker again, to change the choice.
function ns.OpenPicker()
    if offered and #offered > 1 then
        ns.ShowPicker(offered, current, Pick)
    else
        ns.Print("only one rotation is available" .. (current and (": " .. current.name) or "."))
    end
end

-- /rotato rotation reset: forget the pick and what was offered, so the picker asks again. A
-- character reset keeps its name, so its saved choice survives it.
function ns.ResetRotationChoice()
    RotatoDB.rotation[UnitName("player") .. "-" .. GetRealmName()] = nil
    ns.Print("rotation choice cleared.")
    Refresh()
end

function ns.InitRotation()
    local elapsed = 0
    CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 1 then return end
        elapsed = 0
        Refresh()
    end)
end

function ns.GetRotation()
    return current
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
