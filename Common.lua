local ADDON_NAME, ns = ...

-- Slots shown for every class and spec, after the rotation's own entries in each row.
-- All of them only appear while the aura is up. Same entry fields as in Slots.lua.
-- the flasks that count as "has a flask"
local FLASKS = {
    "Flask of the North", "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood", "Flask of the Frost Wyrm",
}
local function NeedsFlask(c) return not c.anyBuff(FLASKS).up end

ns.common = {
    -- suggested when it is in the bags and no flask is active
    reminders = {
        { item = "Flask of the North", when = NeedsFlask },
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
