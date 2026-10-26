local ADDON_NAME, ns = ...

-- Entries shared by every class and spec. They are appended after the rotation's own entries, so
-- a rotation can always override or precede them. The side rows (defensives, offensives) use the
-- fields from Slots.lua; the reminders tier works like a rotation's own reminders.

-- Consumables ---------------------------------------------------------------

-- Anything that counts as "already has a flask". The elixirs are included so someone running
-- elixirs is not told to drink a flask; their buffs are listed with and without the "Elixir of"
-- prefix because the aura name does not always match the item name.
local FLASKS = {
    "Flask of the North", "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood",
    "Flask of the Frost Wyrm",
    "Elixir of Lightning Speed", "Lightning Speed", "Elixir of Mighty Thoughts", "Mighty Thoughts",
}

local function NeedsFlask(c) return not c.anyBuff(FLASKS).up end

-- These are expensive and only pay off in raids, so they are suggested only inside a raid
-- instance and can be switched off entirely (menu, or /rotato flask).
local function NeedsRaidFlask(c) return RotatoDB.remindRaidFlasks and c.inRaid and NeedsFlask(c) end

-- The raid consumables a rotation may want. Which ones apply to a spec is that rotation's choice
-- (its `consumables` list): a character usually carries several, and each spec only wants the
-- one that suits it.
local RAID_CONSUMABLES = {
    "Flask of Endless Rage", "Flask of Pure Mojo", "Flask of Stoneblood", "Flask of the Frost Wyrm",
    "Elixir of Lightning Speed", "Elixir of Mighty Thoughts",
}
ns.RAID_CONSUMABLES = RAID_CONSUMABLES

-- A rotation without a `consumables` list wants all of them, so a spec that has not been
-- configured yet still gets reminded rather than silently nothing.
function ns.WantsConsumable(name)
    local rotation = ns.GetRotation()
    local wanted = rotation and rotation.consumables
    if not wanted then return true end
    for _, wantedName in ipairs(wanted) do
        if wantedName == name then return true end
    end
    return false
end

-- The shared entries -----------------------------------------------------------

-- Everything in the side rows is show = "active": these are buffs from other players, potions and
-- racials, so a slot for them is only worth the space while they are actually on you.
ns.common = {
    reminders = {
        -- Flask of the North is endless and free for alchemists, so it is suggested anywhere.
        -- The raid consumables are appended below from RAID_CONSUMABLES.
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

-- Built in a loop so each entry's `when` closes over its own item name.
for _, name in ipairs(RAID_CONSUMABLES) do
    table.insert(ns.common.reminders, {
        item = name,
        when = function(c) return NeedsRaidFlask(c) and ns.WantsConsumable(name) end,
    })
end
