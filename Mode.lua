local ADDON_NAME, ns = ...

-- Picks the active rotation (single / multi / aoe) from what the player casts.
--
-- There is no reliable way to count enemies in 3.3.5, but the player's own spell choice is a good
-- signal: a spell that only exists in the aoe list means they are doing aoe. So a cast of a spell
-- the current rotation lacks switches to the first rotation (in ns.MODES order) that has it.
-- Spells that are in no rotation (reminders, preparation, highprio) never change the mode, and
-- neither does a spell that a highprio entry is asking for right now: it was cast for the upkeep,
-- not as a choice of rotation.
--
-- It reacts when a cast or channel starts, not when it lands, so the suggestion follows the
-- player immediately instead of one spell late. Leaving combat goes back to single.

-- Variant entries stand for different spells over time, so every option is included: the sets
-- below are cached and must stay valid when the current option changes.
local function NameSet(list)
    local set = {}
    for _, entry in ipairs(list or {}) do
        if entry.variant then
            for _, spell in ipairs(ns.VariantAllSpells(entry.variant)) do set[spell] = true end
        else
            set[ns.SpellName(entry[1])] = true
        end
    end
    return set
end

-- weak keys so a rotation that is reloaded does not leave its sets behind
local cache = setmetatable({}, { __mode = "k" })

local function ModeSpells(rotation)
    local sets = cache[rotation]
    if not sets then
        sets = {}
        for _, mode in ipairs(ns.MODES) do
            sets[mode] = NameSet(rotation.rotations and rotation.rotations[mode])
        end
        cache[rotation] = sets
    end
    return sets
end

-- True when a highprio entry for this spell currently passes its condition
local function AskedForByHighprio(rotation, spell)
    for _, entry in ipairs(ns.Tier(rotation, "highprio")) do
        local spells = entry.variant and ns.VariantAllSpells(entry.variant) or { entry[1] }
        for _, name in ipairs(spells) do
            if ns.SpellName(name) == spell and ns.Passes(entry, spell) then return true end
        end
    end
    return false
end

function ns.InitMode()
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_SPELLCAST_START")         -- cast-time spells, the moment the cast begins
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START") -- channels
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")     -- instants never fire START
    f:RegisterEvent("PLAYER_REGEN_ENABLED")

    f:SetScript("OnEvent", function(_, event, unit, spell)
        if event == "PLAYER_REGEN_ENABLED" then
            ns.SetMode("single", "combat ended")
            return
        end
        if unit ~= "player" then return end

        local rotation = ns.GetRotation()
        if not rotation then return end

        -- variants switch on SUCCEEDED only, so a cast that gets interrupted does not flip them
        if event == "UNIT_SPELLCAST_SUCCEEDED" then ns.CheckVariants(rotation, spell) end

        local sets = ModeSpells(rotation)
        if AskedForByHighprio(rotation, spell) then return end
        if sets[ns.mode][spell] then return end -- the current rotation has it, nothing to switch
        for _, mode in ipairs(ns.MODES) do
            if sets[mode][spell] then
                ns.SetMode(mode, "cast " .. spell)
                return
            end
        end
    end)
end
