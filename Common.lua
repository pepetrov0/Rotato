local ADDON_NAME, ns = ...

-- Entries shared by every class and spec, added after the rotation's own entries.
-- The side slot rows (defensives, offensives) only appear while the aura is up; same fields as in Slots.lua.
-- The reminders tier works like a rotation's reminders.

-- the flasks (and elixirs) that count as "has a flask"; the elixir buffs may be named with or without "Elixir of"
local FLASKS = {
    "Flask of the North", "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood", "Flask of the Frost Wyrm",
    "Elixir of Lightning Speed", "Lightning Speed", "Elixir of Mighty Thoughts", "Mighty Thoughts",
}
local function NeedsFlask(c) return not c.anyBuff(FLASKS).up end
-- the other flasks are expensive: only worth suggesting inside a raid instance
local function NeedsRaidFlask(c) return RotatoDB.remindRaidFlasks and c.inRaid and NeedsFlask(c) end

-- Raid-only consumables. Each rotation lists the ones its spec wants in a `consumables` field
-- (every one of them when the field is missing).
local RAID_CONSUMABLES = {
    "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood", "Flask of the Frost Wyrm",
    "Elixir of Lightning Speed", "Elixir of Mighty Thoughts",
}
ns.RAID_CONSUMABLES = RAID_CONSUMABLES

function ns.WantsConsumable(name)
    local rotation = ns.GetRotation()
    local wanted = rotation and rotation.consumables
    if not wanted then return true end
    for _, wantedName in ipairs(wanted) do
        if wantedName == name then return true end
    end
    return false
end

ns.common = {
    -- suggested when it is in the bags and no flask is active
    reminders = {
        { item = "Flask of the North", when = NeedsFlask }, -- endless and free for alchemists
        -- the raid consumables are added below, one per entry of RAID_CONSUMABLES
    },

    defensives = {
        { buff = "Pain Suppression", show = "active" },
        { buff = "Guardian Spirit", show = "active" },
        { buff = "Hand of Protection", show = "active" },
        { buff = "Hand of Sacrifice", show = "active" },
        { buff = "Stoneform", show = "active" },
        { buff = "Gift of the Naaru", show = "active" },
        { buff = "Divine Guardian", show = "active" },
        { buff = "Indestructible", show = "active" }, -- Indestructible Potion
    },
    offensives = {
        { buff = "Bloodlust", show = "active" },
        { buff = "Heroism", show = "active" },
        { buff = "Power Infusion", show = "active" },
        { buff = "Unholy Frenzy", show = "active" },
        { buff = "Hysteria", show = "active" },
        { buff = "Hyperspeed Acceleration", show = "active" }, -- engineering gloves
        { buff = "Blood Fury", show = "active" },
        { buff = "Berserking", show = "active" },
        { buff = "Speed", show = "active" },      -- Potion of Speed
        { buff = "Wild Magic", show = "active" }, -- Potion of Wild Magic
    },
}

for _, name in ipairs(RAID_CONSUMABLES) do
    table.insert(ns.common.reminders, {
        item = name,
        when = function(c) return NeedsRaidFlask(c) and ns.WantsConsumable(name) end,
    })
end
