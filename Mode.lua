local ADDON_NAME, ns = ...

-- Picks the single/aoe rotation automatically: casting a spell that only appears in one
-- rotation switches to it, and leaving combat goes back to single.

local function NameSet(list)
    local set = {}
    for _, entry in ipairs(list or {}) do
        set[ns.SpellName(entry[1])] = true
    end
    return set
end

local cache = setmetatable({}, { __mode = "k" })

-- Spells that appear in only one of the two rotations, per rotation definition.
local function UniqueSpells(rotation)
    local u = cache[rotation]
    if not u then
        local single, aoe = NameSet(rotation.single), NameSet(rotation.aoe)
        u = { single = {}, aoe = {} }
        for name in pairs(single) do if not aoe[name] then u.single[name] = true end end
        for name in pairs(aoe) do if not single[name] then u.aoe[name] = true end end
        cache[rotation] = u
    end
    return u
end

function ns.InitMode()
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit, spell)
        if event == "PLAYER_REGEN_ENABLED" then
            ns.SetMode("single", "combat ended")
            return
        end
        if unit ~= "player" then return end
        local rotation = ns.GetRotation()
        if not rotation then return end
        local unique = UniqueSpells(rotation)
        if unique.aoe[spell] then
            ns.SetMode("aoe", "cast " .. spell)
        elseif unique.single[spell] then
            ns.SetMode("single", "cast " .. spell)
        end
    end)
end
