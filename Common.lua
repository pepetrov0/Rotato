local ADDON_NAME, ns = ...

-- Entries shared by every class and spec, added after the rotation's own entries.
-- The side slot rows (defensives, offensives) only appear while the aura is up; same fields as in Slots.lua.
-- The reminders tier works like a rotation's reminders.

-- the flasks that count as "has a flask"
local FLASKS = {
    "Flask of the North", "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood", "Flask of the Frost Wyrm",
}
local function NeedsFlask(c) return not c.anyBuff(FLASKS).up end
-- the other flasks are expensive: only worth suggesting inside a raid instance
local function NeedsRaidFlask(c) return c.inRaid and NeedsFlask(c) end

ns.common = {
    -- suggested when it is in the bags and no flask is active
    reminders = {
        { item = "Flask of the North", when = NeedsFlask }, -- endless and free for alchemists
        { item = "Flask of Endless Rage", when = NeedsRaidFlask },
        { item = "Flask of Pure Mojo", when = NeedsRaidFlask },
        { item = "Flask of Stoneblood", when = NeedsRaidFlask },
        { item = "Flask of the Frost Wyrm", when = NeedsRaidFlask },
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
