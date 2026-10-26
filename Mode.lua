local ADDON_NAME, ns = ...

-- Picks the active rotation (single / multi / aoe) from what the player casts.
-- Casting a spell the current rotation doesn't contain switches to the first rotation
-- (in ns.MODES order) that does; spells in no rotation (prep, common) change nothing.
-- This happens when a cast or channel starts (or an instant goes off), not when it ends.
-- Leaving combat goes back to single.

local function NameSet(list)
    local set = {}
    for _, entry in ipairs(list or {}) do
        set[ns.SpellName(entry[1])] = true
    end
    return set
end

local cache = setmetatable({}, { __mode = "k" })

local function ModeSpells(rotation)
    local sets = cache[rotation]
    if not sets then
        sets = {}
        for _, mode in ipairs(ns.MODES) do
            sets[mode] = NameSet(rotation[mode])
        end
        cache[rotation] = sets
    end
    return sets
end

function ns.InitMode()
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_SPELLCAST_START")          -- cast-time spells, as soon as the cast begins
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")  -- channels
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")      -- instants
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit, spell)
        if event == "PLAYER_REGEN_ENABLED" then
            ns.SetMode("single", "combat ended")
            return
        end
        if unit ~= "player" then return end
        local rotation = ns.GetRotation()
        if not rotation then return end
        local sets = ModeSpells(rotation)
        if sets[ns.mode][spell] then return end
        for _, mode in ipairs(ns.MODES) do
            if sets[mode][spell] then
                ns.SetMode(mode, "cast " .. spell)
                return
            end
        end
    end)
end
