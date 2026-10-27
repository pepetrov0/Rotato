local ADDON_NAME, ns = ...

-- Entries shared by every class and spec. They are appended after the rotation's own entries, so
-- a rotation can always override or precede them. The side rows (defensives, offensives) use the
-- fields from Slots.lua. Evaluate also appends a `reminders` or `highprio` tier from here if one is added.

-- The shared entries -----------------------------------------------------------

-- Everything in the side rows is show = "active": these are buffs from other players, potions and
-- racials, so a slot for them is only worth the space while they are actually on you.
ns.common = {
    defensives = {
        { buff = "Pain Suppression", show = "active" },
        { buff = "Guardian Spirit", show = "active" },
        { buff = "Hand of Protection", show = "active" },
        { buff = "Hand of Sacrifice", show = "active" },
        { buff = "Stoneform", show = "active" },
        { buff = "Gift of the Naaru", show = "active" },
        { buff = "Divine Guardian", show = "active" },
        { buff = "Indestructible", show = "active" }, -- Indestructible Potion
        { buff = "Aegis of Dalaran", show = "active" }, -- trinket proc
    },

    utility = {
        { buff = "Hand of Salvation", show = "active" },
        { buff = "Hand of Freedom", show = "active" },
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
