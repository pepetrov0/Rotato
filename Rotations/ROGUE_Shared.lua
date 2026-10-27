local ADDON_NAME, ns = ...

-- Pieces the three rogue specs have in common. This file loads before them (see the toc).

local Rogue = {}
ns.Rogue = Rogue

-- Poison is an item, used on a weapon, rather than an ability, so the reminder offers the item.
-- Only the highest rank of each kind is listed, which is what a level-80 rogue carries. An entry
-- whose item is not in the bags is skipped, so a poison the player does not use never shows.
-- Damage poisons lead because they are the usual kit; the others cover PvP.
Rogue.POISONS = {
    "Instant Poison IX",
    "Deadly Poison IX",
    "Wound Poison VII",
    "Crippling Poison",
    "Mind-numbing Poison",
    "Anesthetic Poison II",
}

local MAIN_HAND, OFF_HAND = 16, 17

-- Poison goes on a weapon, so only a hand that holds one counts (before Dual Wield the off hand
-- is empty and there is nothing there to poison).
local function HasWeapon(slot) return GetInventoryItemLink("player", slot) ~= nil end

-- True while a held weapon has no temporary enchant. The client only reports that a weapon is
-- enchanted, not which poison is on it (see c.mainHandEnchant), which is all a reminder needs.
local function MissingPoison(c)
    local main, off = HasWeapon(MAIN_HAND), HasWeapon(OFF_HAND)
    return (main and not c.mainHandEnchant().up) or (off and not c.offHandEnchant().up) or false
end

-- One entry per poison, so the one the player actually carries is the one shown; every entry shares
-- the condition above, and the evaluator skips an entry whose item is not in the bags. A fresh list
-- per call, because entries carry state of their own (see Rotations/PALADIN_Shared.lua).
function Rogue.PoisonReminders()
    local reminders = {}
    for i, poison in ipairs(Rogue.POISONS) do
        reminders[i] = { item = poison, when = MissingPoison }
    end
    return reminders
end
