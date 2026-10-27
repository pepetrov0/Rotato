local ADDON_NAME, ns = ...

-- Pieces the three rogue specs have in common. This file loads before them (see the toc).

local Rogue = {}
ns.Rogue = Rogue

-- Poison is an item, used on a weapon, rather than an ability, so the reminder offers the item.
-- Every rank is listed, highest first, so a levelling rogue's poison counts too. An entry whose
-- item is not in the bags is skipped, so a poison the player does not use never shows. Damage
-- poisons lead because they are the usual kit; the others cover PvP.
local NUMERALS = { "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX" }

-- "Instant Poison IX" down to "Instant Poison" (rank 1 has no numeral).
local function Ranks(list, name, top)
    for rank = top, 1, -1 do list[#list + 1] = name .. NUMERALS[rank] end
end

Rogue.POISONS = {}
Ranks(Rogue.POISONS, "Instant Poison", 9)
Ranks(Rogue.POISONS, "Deadly Poison", 9)
Ranks(Rogue.POISONS, "Wound Poison", 7)
Ranks(Rogue.POISONS, "Crippling Poison", 1)
Ranks(Rogue.POISONS, "Mind-numbing Poison", 1)
Ranks(Rogue.POISONS, "Anesthetic Poison", 2)

local MAIN_HAND, OFF_HAND = 16, 17

-- Poison goes on a weapon, so only a hand that holds one counts (before Dual Wield the off hand
-- is empty and there is nothing there to poison).
local function HasWeapon(slot) return GetInventoryItemLink("player", slot) ~= nil end

-- Whether each held weapon still needs poison. The client only reports that a weapon is
-- enchanted, not which poison is on it (see c.mainHandEnchant), which is all a reminder needs.
local function MainMissing(c) return HasWeapon(MAIN_HAND) and not c.mainHandEnchant().up end
local function OffMissing(c) return HasWeapon(OFF_HAND) and not c.offHandEnchant().up end
local function MissingPoison(c) return MainMissing(c) or OffMissing(c) end

-- The poison each hand should get: Instant on the main hand, Deadly on the off hand.
local MAIN_POISONS, OFF_POISONS = {}, {}
Ranks(MAIN_POISONS, "Instant Poison", 9)
Ranks(OFF_POISONS, "Deadly Poison", 9)

-- The preferred poison for each bare hand, main hand first, so after poisoning the main hand the
-- reminder moves on to Deadly instead of offering Instant again. Then any poison in POISONS, so a
-- rogue who carries neither (or only one of them) is still reminded. One entry per rank, so the one
-- the player actually carries is the one shown; the evaluator skips an entry whose item is not in
-- the bags. A fresh list per call, because entries carry state of their own (see
-- Rotations/PALADIN_Shared.lua).
function Rogue.PoisonReminders()
    local reminders = {}
    local function Add(poisons, when)
        for _, poison in ipairs(poisons) do reminders[#reminders + 1] = { item = poison, when = when } end
    end
    Add(MAIN_POISONS, MainMissing)
    Add(OFF_POISONS, OffMissing)
    Add(Rogue.POISONS, MissingPoison)
    return reminders
end
