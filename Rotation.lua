local ADDON_NAME, ns = ...

-- Registry of rotation definitions, and the "variants" a rotation can declare.
--
-- A rotation file calls ns.Rotation{ ... } with these fields (all optional but name):
--   name                 unique; what the player sees in the picker and what is remembered
--   class                class token the rotation is offered to ("PALADIN"); a playstyle of that class
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
-- The rotations of the player's class are its playstyles. The player picks (Picker.lua), even when
-- there is only one, since "my own way" is always on offer; the pick is remembered per character and talent group
-- (dual spec): switching groups uses that group's pick, or asks if it has none. The player is
-- asked again after a talent reset, which is seen as the points invested dropping to zero; until
-- they answer, no rotation is used. "I'm playing my own way" is a pick too: it uses no rotation.
-- Below level 10 there is no rotation and no picker; from 10 the player is asked until they answer:
-- the picker never shows in combat (it hides when combat starts and comes back after it), and closed
-- without a choice it comes back after REASK seconds.
-- ns.GetRotation returns nil until Class.lua has detected the character, which callers rely on to
-- do nothing early in the login.
local PICKER_LEVEL = 10
local REASK = 60
local current, offered, shownGroup
local nextAsk = {} -- per talent group: GetTime() from which the picker may show again

local function CharacterKey() return UnitName("player") .. "-" .. GetRealmName() end

-- Follows ns.talentGroup, published together with ns.hasTalents, so the reset check below compares
-- the talents and the pick of the same group.
local function Group() return ns.talentGroup or GetActiveTalentGroup() or 1 end

-- { pick, invested } for the active talent group, in RotatoDB.rotation[character].groups[group].
local function CharacterState()
    RotatoDB.rotation = RotatoDB.rotation or {}
    local key = CharacterKey()
    local char = RotatoDB.rotation[key] or {}
    RotatoDB.rotation[key] = char
    if not char.groups then
        -- before 0.1.2 one pick was kept per character: it goes to the group active now
        char.groups = { [Group()] = { pick = char.pick, invested = char.invested } }
        char.pick, char.invested = nil, nil
    end
    local group = Group()
    char.groups[group] = char.groups[group] or {}
    return char.groups[group]
end

local function Available()
    local list = {}
    for _, def in ipairs(ns.rotations) do
        if def.class == ns.class then list[#list + 1] = def end
    end
    return list
end

-- The last card of the picker: no rotation at all. Remembered as the pick like any rotation name.
local OWN = "own way"
local ownWay = { name = "I'm playing my own way", icon = "Interface\\Icons\\INV_Misc_Map_01", own = true }

local function Choices(list)
    local choices = { unpack(list) }
    choices[#choices + 1] = ownWay
    return choices
end

local function Use(rotation)
    if rotation == current then return end
    current = rotation
    ns.Print("rotation in use: " .. (rotation and rotation.name or "none"))
end

local function Pick(def)
    CharacterState().pick = def.own and OWN or def.name
    Use(not def.own and def or nil)
end

local function Refresh()
    if not ns.class then return end
    local list, state, group = Available(), CharacterState(), Group()
    offered = list

    -- a picker left open from the other talent group would save its answer to this one
    if shownGroup and shownGroup ~= group then
        ns.HidePicker()
        shownGroup = nil
    end

    -- Having had points and now having none is a reset.
    if ns.hasTalents then
        state.invested = true
    elseif state.invested then
        state.invested, state.pick, nextAsk[group] = nil, nil, nil
    end

    local picked
    local own = state.pick == OWN
    for _, def in ipairs(list) do
        if def.name == state.pick then picked = def end
    end
    state.pick = own and OWN or picked and picked.name
    Use(UnitLevel("player") >= PICKER_LEVEL and picked or nil)

    local inCombat = UnitAffectingCombat("player")
    if #list == 0 or inCombat then
        ns.HidePicker()
    elseif not picked and not own and not ns.PickerShown() and UnitLevel("player") >= PICKER_LEVEL
        and GetTime() >= (nextAsk[group] or 0) then
        shownGroup = group
        ns.ShowPicker(Choices(list), nil, Pick, function() nextAsk[group] = GetTime() + REASK end)
    end
end

ns.RefreshRotation = Refresh

-- /rotato rotation: the picker again, to change the choice.
function ns.OpenPicker()
    if UnitLevel("player") < PICKER_LEVEL then
        ns.Print("the rotation picker is available from level " .. PICKER_LEVEL .. ".")
    elseif UnitAffectingCombat("player") then
        ns.Print("the rotation picker is not available in combat.")
    elseif offered and #offered > 0 then
        shownGroup = Group()
        ns.ShowPicker(Choices(offered), current, Pick)
    else
        ns.Print("no rotation is available for this class.")
    end
end

-- /rotato rotation reset: forget the active talent group's pick, so the picker asks again. A
-- character reset keeps its name, so its saved choice survives it.
function ns.ResetRotationChoice()
    local state = CharacterState()
    state.pick, state.invested = nil, nil
    nextAsk[Group()] = nil
    ns.Print("rotation choice cleared.")
    Refresh()
end

function ns.InitRotation()
    local elapsed = 0
    local f = CreateFrame("Frame")
    -- the tick would leave the picker up for up to a second of the fight
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", ns.HidePicker)
    f:SetScript("OnUpdate", function(_, dt)
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

-- The current options, per rotation. Kept in memory only, so each session starts from the
-- defaults: the choice reflects what the player is doing now, not what they did last week.
local chosen = {}

local function VariantKey()
    local rotation = ns.GetRotation()
    return rotation and rotation.name or ""
end

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
