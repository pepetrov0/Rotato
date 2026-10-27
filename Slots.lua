local ADDON_NAME, ns = ...

-- The four side rows of small slots. A rotation lists entries per row; they are shown outward from
-- the center icon, packed with no gaps:
--   utility    (left, top)     trackers   (right, top)
--   defensives (left, bottom)  offensives (right, bottom)
--
-- What an entry shows (give it one of spell / buff / debuff / targetBuff / ...):
--   spell        = "Name"   the cooldown of an ability
--   buff         = "Name"   an aura on the player, or { "Name", "Other" } for interchangeable ones
--                           (whichever is up is shown)
--   pet          = "Name"   a summoned guardian of that name is out (Shadowfiend)
--   playerDebuff = "Name"   a debuff on the player
--   debuff       = "Name"   an aura on the target (yours only, unless any = true)
--   targetBuff   = "Name"   a buff on the target
--   targetBuffType         = { "Magic", "Enrage" }   any buff of those dispel types on the target
--   healTargetBuff        = "Name"   your own buff (a hot) on whoever a heal would go to
--   healTargetBuffAny     = "Name"   any caster's buff on whoever a heal would go to
--   healTargetDebuff       = "Name"   a debuff on whoever a heal would go to (see c.healTarget)
--   healTargetDebuffType   = { "Disease", "Magic" } any debuff of those types on that same unit
--   Any of the aura fields can be { variant = "name" } to follow a rotation variant (Rotation.lua).
--   An ability and an aura can be combined (spell + buff): while the aura is up its remaining
--   time sweeps, otherwise the ability's cooldown does.
--
-- How it behaves:
--   show       = "always" (default) or "active": hide while the aura is not up
--   when       = function(c)  extra condition for showing the entry at all
--   always     = true: show a missing aura even when no spell of that name is in the spellbook
--   manaOnly   = true: only the mana cost decides if the spell is usable (spells cast on others)
--   discourage = function(c)  true while using it is pointless right now: the icon is grayed out and drawn at 50% opacity
--   recommend  = function(c)  true while using it is a good idea: flashing white border
--   lockout    = true: the aura is a restriction counting down (Weakened Soul): blue border
--
-- Borders:  red = you need to act,  flashing white = recommended,  green = active,  blue = lockout.
-- Any border also flashes while its aura has under FLASH_BELOW seconds left.
-- Outside the trackers an active aura is green when good for you (a buff on you, your debuff on the
-- target) and red when bad for you (a debuff on you, a buff on the target). Trackers differ, because
-- they exist to catch what is missing: only aura entries are shown there, a missing buff or debuff
-- is red, a healthy one has no border, and a dispellable aura (targetBuffType, healTargetDebuffType)
-- is red while present.

local TICK = 0.1 -- how often the slots are re-evaluated; sweeps animate on their own in between

local GREEN = { 0, 1, 0 }
local RED = { 1, 0, 0 }
local WHITE = { 1, 1, 1 }
local BLUE = { 0.25, 0.55, 1 }

local FLASH_BELOW = 5 -- seconds left at which a border starts flashing
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ROW_KEYS = { "defensives", "utility", "trackers", "offensives" }
local SIDE = { defensives = "LEFT", utility = "LEFT", trackers = "RIGHT", offensives = "RIGHT" }

local EMPTY = {} -- stands in for a missing list; never written to

-- Identifies what FormatTime would print, so a slot only builds a new string when the text changes
-- (each new string is garbage a moment later). The offsets keep the units apart.
local function TimeKey(seconds)
    if seconds >= 3600 then return 3e6 + math.floor(seconds / 3600)
    elseif seconds >= 60 then return 2e6 + math.floor(seconds / 60)
    elseif seconds >= 10 then return 1e6 + math.floor(seconds)
    end
    return math.floor(seconds * 10 + 0.5)
end

local function FormatTime(seconds)
    if seconds >= 3600 then return format("%dh", seconds / 3600)
    elseif seconds >= 60 then return format("%dm", seconds / 60)
    elseif seconds >= 10 then return format("%d", seconds)
    end
    return format("%.1f", seconds) -- the last seconds are what matters, so show tenths
end

-- Variants ---------------------------------------------------------------

local VARIANT_FIELDS = { "spell", "buff", "pet", "debuff", "targetBuff", "playerDebuff",
    "healTargetBuff", "healTargetBuffAny", "healTargetDebuff" }

-- Fields written as { variant = "name" } are replaced by the current spell of that variant. This is
-- done on a proxy that reads through to the real entry, instead of editing the entry, because the
-- entry belongs to the rotation file and the option can change again on the next cast. The proxy
-- forwards writes too, so per-entry flags (errored, lastIcon) still land on the real entry.
-- Each entry keeps its one proxy; only the resolved values are refreshed.
local proxies = setmetatable({}, { __mode = "k" })
local function ResolveVariants(entry)
    local proxy = proxies[entry]
    for _, field in ipairs(VARIANT_FIELDS) do
        local value = rawget(entry, field)
        if type(value) == "table" and value.variant then
            if not proxy then
                proxy = setmetatable({}, { __index = entry, __newindex = entry })
                proxies[entry] = proxy
            end
            rawset(proxy, field, ns.VariantSpell(value.variant))
        end
    end
    return proxy or entry
end

-- Tooltip cooldowns -----------------------------------------------------------

-- The client has no call for a spell's full cooldown, so it is read off its tooltip
-- ("8 sec cooldown", "1.5 min cooldown"). The patterns come from the client's own strings so they
-- match its language.
local scanTip
local COOLDOWN_PATTERNS = {
    { "^" .. SPELL_RECAST_TIME_SEC:gsub("%%%.3g", "([%%d%%.]+)") .. "$", 1 },
    { "^" .. SPELL_RECAST_TIME_MIN:gsub("%%%.3g", "([%%d%%.]+)") .. "$", 60 },
}
local tooltipCooldowns = {} -- spell name -> seconds, or false when the tooltip has none
local TOOLTIP_SIDES = { "Right", "Left" }

local function TooltipCooldown(spell)
    local cached = tooltipCooldowns[spell]
    if cached ~= nil then return cached or nil end

    local link = GetSpellLink(spell)
    if not link then return end -- not known yet; try again next time
    scanTip = scanTip or CreateFrame("GameTooltip", "RotatoScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE") -- a tooltip loses its owner when hidden, so every time
    scanTip:SetHyperlink(link)

    local seconds = false
    for i = 1, scanTip:NumLines() do
        for _, side in ipairs(TOOLTIP_SIDES) do
            local text = _G["RotatoScanTipText" .. side .. i]:GetText()
            for _, pattern in ipairs(text and COOLDOWN_PATTERNS or EMPTY) do
                local value = text:match(pattern[1])
                if value and tonumber(value) then seconds = tonumber(value) * pattern[2] end
            end
        end
    end
    tooltipCooldowns[spell] = seconds
    return seconds or nil
end

-- Resolving an entry ---------------------------------------------------------

-- Reads the aura an entry is about. Also returns the unit it was read from when that is a heal
-- target, because the tooltip needs to know where to look.
local function ReadAura(entry, buffList)
    local c = ns.c
    if buffList then return c.anyBuff(buffList)
    elseif entry.buff then return c.buff(entry.buff)
    elseif entry.pet then return c.pet.aura(entry.pet)
    elseif entry.playerDebuff then return c.selfDebuff(entry.playerDebuff)
    elseif entry.debuff then return entry.any and c.debuffAny(entry.debuff) or c.debuff(entry.debuff)
    elseif entry.targetBuff then return c.target.buff(entry.targetBuff)
    elseif entry.targetBuffType then return c.target.buffOfType(unpack(entry.targetBuffType))
    elseif entry.healTargetBuff then
        local unit = c.healTarget()
        return c.buffOn(unit, entry.healTargetBuff), unit
    elseif entry.healTargetBuffAny then
        local unit = c.healTarget()
        return c.buffOnAny(unit, entry.healTargetBuffAny), unit
    elseif entry.healTargetDebuff then
        local unit = c.healTarget()
        return c.debuffOn(unit, entry.healTargetDebuff), unit
    elseif entry.healTargetDebuffType then
        local unit = c.healTarget()
        return c.debuffOfType(unit, unpack(entry.healTargetDebuffType)), unit
    end
end

-- Works out what an entry should look like right now. Returns nothing when it should not be shown,
-- otherwise these values, in this order (the caller indexes them):
--   1 icon  2 sweepStart  3 sweepDuration  4 remaining  5 dimmed  6 fromAura  7 borderColor
--   8 flash  9 tip  10 coolingDown  11 discouraged  12 active  13 knownCooldown
local function Resolve(entry, rowKey)
    entry = ResolveVariants(entry)
    local c = ns.c
    local typeList = entry.targetBuffType
    local healTypeList = entry.healTargetDebuffType

    local buffList = type(entry.buff) == "table" and entry.buff or nil
    local auraName = buffList and buffList[1] or entry.buff or entry.pet or entry.playerDebuff
        or entry.debuff or entry.targetBuff or entry.healTargetBuff or entry.healTargetBuffAny
        or entry.healTargetDebuff

    local aura, healUnit = ReadAura(entry, buffList)
    local active = aura and aura.up

    -- Visibility rules, cheapest first.
    -- An entry that reads the target has nothing to show without one (playerDebuff reads the player).
    if (entry.debuff or entry.targetBuff or typeList) and not UnitExists("target") then return end
    -- the trackers only show auras: a bare cooldown there would just be noise next to the real trackers
    if rowKey == "trackers" and not (entry.buff or entry.debuff or typeList or healTypeList
        or entry.healTargetBuff or entry.healTargetBuffAny or entry.healTargetDebuff) then
        return
    end
    -- the type lists are "tell me when one is present", so absent means nothing to show
    if (entry.show == "active" or typeList or healTypeList) and not active then return end
    if entry.when and not ns.Passes(entry, auraName or entry.spell) then return end

    -- Abilities the character does not know are hidden, unless their aura happens to be up
    -- (a buff from someone else's cast). A bare aura is hidden when no spell of that name exists,
    -- which keeps trackers for abilities the character lacks off the screen; `always` opts out for
    -- talent passives, whose names are not in the spellbook.
    local cdStart, cdDuration = 0, 0
    if entry.spell then
        cdStart, cdDuration = GetSpellCooldown(entry.spell)
        if not cdStart and not active then return end
        cdStart, cdDuration = cdStart or 0, cdDuration or 0
    elseif auraName and not active and not entry.always and not GetSpellInfo(auraName) then
        return
    end

    -- An aura's own icon is the most reliable one (it is what the game shows), and it is remembered
    -- so the slot still has a picture while the aura is missing and the spell lookup comes up empty.
    if active and aura.icon then entry.lastIcon = aura.icon end
    local icon = (active and aura.icon)
        or ((entry.spell or auraName) and select(3, GetSpellInfo(entry.spell or auraName)))
        or entry.lastIcon or UNKNOWN_ICON

    -- What the sweep and the number show: the aura's remaining time while it is up, otherwise the
    -- ability's own cooldown. The global cooldown is not a real cooldown and is left out.
    local now = GetTime()
    local start, duration, remaining = 0, 0, nil
    local fromAura = false
    if active then
        if aura.duration > 0 then
            start, duration, remaining = aura.expires - aura.duration, aura.duration, aura.expires - now
            fromAura = true
        end
    elseif cdDuration > ns.GCD_MAX and cdStart > 0 and cdStart + cdDuration > now then
        start, duration, remaining = cdStart, cdDuration, cdStart + cdDuration - now
    end
    -- The full cooldown orders the ready abilities. What was seen on a real cooldown wins over the
    -- tooltip, because the tooltip shows the base value, without talents or glyphs.
    if cdDuration > ns.GCD_MAX and cdStart > 0 then entry.knownCooldown = cdDuration end
    local knownCooldown = entry.knownCooldown or (entry.spell and TooltipCooldown(entry.spell))

    -- Only a bare aura is dimmed while missing: that is how a tracker says "not up". An ability
    -- slot is not dimmed just because its buff is down, it is simply ready.
    local dimmed = auraName and not entry.spell and not active
    local discouraged = false
    -- an active aura is already in use, so discouraging it would only be confusing
    if entry.discourage and not dimmed and not active then
        local ok, result = pcall(entry.discourage, c)
        if ok then
            discouraged = result and true or false
            dimmed = discouraged
        elseif not entry.discourageErrored then
            entry.discourageErrored = true -- report once, this runs several times a second
            ns.Print("discourage error in " .. tostring(entry.spell or auraName) .. ": " .. tostring(result))
        end
    end

    local expiring = fromAura and remaining and remaining < FLASH_BELOW
    local borderColor
    if rowKey == "trackers" then
        -- a tracker only draws attention when something is missing, wrong, a lockout, or about to run out
        if entry.lockout and active then borderColor = BLUE
        elseif typeList or healTypeList or not active or expiring then borderColor = RED end
    elseif active then
        borderColor = entry.lockout and BLUE
            or ((entry.buff or entry.pet or entry.debuff or entry.healTargetBuff) and GREEN or RED)
    end

    -- A recommendation outranks the other aura borders: it is the thing the player should act on, and
    -- it flashes so it stands out from the steady red and blue ones. Green does not give way: the
    -- buff is already up, so there is nothing left to recommend.
    if entry.recommend and rowKey ~= "trackers" and borderColor ~= GREEN then
        local ok, recommended = pcall(entry.recommend, c)
        if not ok then
            if not entry.recommendErrored then
                entry.recommendErrored = true
                ns.Print("recommend error in " .. tostring(entry.spell or auraName) .. ": " .. tostring(recommended))
            end
        elseif recommended then
            borderColor, expiring = WHITE, true
        end
    end

    -- What the Alt tooltip should show: the aura while it is up (with its live timer), otherwise
    -- the ability. The unit says where to find the aura.
    -- the table is the entry's own and refilled every time, rather than a new one per update
    local tip = entry.tip
    if not tip then
        tip = {}
        entry.tip = tip
    end
    tip.spell, tip.aura, tip.unit, tip.helpful = entry.spell or auraName, nil, nil, nil
    -- A pet has no aura to show, so its tooltip stays the summon spell's.
    if active and aura.name and not entry.pet then
        tip.aura = aura.name
        if entry.buff then tip.unit, tip.helpful = "player", true
        elseif entry.playerDebuff then tip.unit, tip.helpful = "player", false
        elseif entry.debuff then tip.unit, tip.helpful = "target", false
        elseif entry.healTargetBuff then tip.unit, tip.helpful = healUnit, true
        elseif entry.healTargetBuffAny then tip.unit, tip.helpful = healUnit, true
        elseif entry.healTargetDebuff or healTypeList then tip.unit, tip.helpful = healUnit, false
        else tip.unit, tip.helpful = "target", true
        end
    end

    -- an ability only showing its cooldown, which decides where it is placed in the row
    local coolingDown = not active and duration > 0

    return icon, start, duration, remaining, dimmed, fromAura, borderColor,
        borderColor and expiring or false, tip, coolingDown, discouraged,
        active and true or false, knownCooldown
end

-- Slots on screen ------------------------------------------------------------

-- Adds the widgets a slot needs on top of the bare icon from UI.lua.
local function BuildSlot(slot)
    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown.noCooldownCount = true -- the game's own countdown text would fight ours (and ElvUI's)
    if not cooldown.SetReverse and not ns.warnedReverse then
        ns.warnedReverse = true
        ns.Print("this client has no Cooldown:SetReverse, the side slot sweep can't be reversed")
    end
    slot.cooldown = cooldown

    -- Regions of a frame draw under its child frames, so the number and the border each get a
    -- frame stacked above the sweep.
    local overlay = CreateFrame("Frame", nil, slot)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    slot.time = overlay:CreateFontString(nil, "OVERLAY")
    ns.RegisterText(slot.time, "time")
    slot.time:SetPoint("CENTER")

    local border = CreateFrame("Frame", nil, slot)
    border:SetAllPoints()
    border:SetFrameLevel(cooldown:GetFrameLevel() + 3)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    border:Hide()
    slot.border = border

    slot:Hide()
end

-- Applies a resolved entry to a slot. Everything is compared with what is already shown first,
-- because restarting a sweep or resetting a texture every tick would make them flicker.
local function Paint(slot, icon, start, duration, remaining, dimmed, fromAura, borderColor, flash, tip, discouraged)
    if slot.shownIcon ~= icon then
        slot.shownIcon = icon
        slot.icon:SetTexture(icon)
    end

    -- aura timers are reversed (the icon starts visible and darkens as it runs out); cooldowns use
    -- the default sweep (the icon is revealed as it comes back)
    if slot.shownStart ~= start or slot.shownDuration ~= duration or slot.shownAura ~= fromAura then
        slot.shownStart, slot.shownDuration, slot.shownAura = start, duration, fromAura
        if slot.cooldown.SetReverse then slot.cooldown:SetReverse(fromAura) end
        CooldownFrame_SetTimer(slot.cooldown, start, duration, duration > 0 and 1 or 0)
    end

    slot.icon:SetDesaturated(dimmed and true or false)
    local shade = dimmed and 0.5 or 1 -- desaturation alone can be unsupported on some setups
    slot.icon:SetVertexColor(shade, shade, shade)
    slot:SetAlpha(discouraged and 0.5 or 1) -- a discouraged slot also fades, not only grays

    local timeKey = remaining and TimeKey(remaining)
    if timeKey ~= slot.shownTimeKey then
        slot.shownTimeKey = timeKey
        slot.time:SetText(remaining and FormatTime(remaining) or "")
    end
    slot.flashing = flash
    slot.tip = tip

    if borderColor then
        slot.border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        slot.border:Show()
    else
        slot.border:Hide()
    end
    slot:Show()
end

-- What is drawn nearest the center icon, from most to least pressing:
--   1 needs action (red) or is recommended (white), the soonest to run out first
--   2 a lockout counting down (blue), the soonest over first
--   3 active (an aura up, with a green border or none), the soonest to expire first
--   4 ready, the shortest cooldown first (one with no cooldown at all goes last)
--   5 ready but discouraged
--   6 cooling down, the soonest back first
local function Group(result)
    local border = result[7]
    if border == RED or border == WHITE then return 1
    elseif border == BLUE then return 2
    elseif result[12] then return 3
    elseif result[10] then return 6
    elseif result[11] then return 5
    end
    return 4
end

-- Ties keep the rotation's order, since table.sort is not stable.
local function InnerFirst(a, b)
    local ga, gb = Group(a), Group(b)
    if ga ~= gb then return ga < gb end
    local ka, kb
    if ga == 4 then
        ka, kb = a[13] or math.huge, b[13] or math.huge
    else
        -- the time left; without one (no timer, or nothing up) it goes last
        ka, kb = a[4] or math.huge, b[4] or math.huge
    end
    if ka ~= kb then return ka < kb end
    return a.order < b.order
end

-- Everything below is reused from one update to the next instead of being built anew: per row,
-- the list of what is shown and a pool of result tables to fill.
local taken = {}
local shownByRow, poolByRow = {}, {}
for _, key in ipairs(ROW_KEYS) do
    shownByRow[key], poolByRow[key] = {}, {}
end

-- Resolves an entry into the next free result table of the row. Returns the count of results used.
local function Add(key, entry, count)
    local pool = poolByRow[key]
    local result = pool[count + 1]
    if not result then
        result = {}
        pool[count + 1] = result
    end
    result[1], result[2], result[3], result[4], result[5], result[6], result[7], result[8], result[9],
        result[10], result[11], result[12], result[13] = Resolve(entry, key)
    if not result[1] then return count end
    result.order = count + 1
    shownByRow[key][count + 1] = result
    return count + 1
end

-- Everything one row should show right now, already trimmed to the number of slots and sorted.
-- The list is only valid until the next call for the same row.
local function Collect(rotation, key, slotCount)
    local own = rotation and rotation[key] or EMPTY

    -- A shared entry is skipped when the rotation already has one for the same ability or buff in
    -- this row, otherwise the same thing would show twice (an ability slot, plus the shared buff
    -- slot that appears when the buff lands on you).
    wipe(taken)
    for _, entry in ipairs(own) do
        if entry.spell then taken[entry.spell] = true end
        if type(entry.buff) == "string" then taken[entry.buff] = true end
        if type(entry.pet) == "string" then taken[entry.pet] = true end
    end

    local count = 0
    for _, entry in ipairs(own) do count = Add(key, entry, count) end
    for _, entry in ipairs(ns.common[key] or EMPTY) do
        if type(entry.buff) ~= "string" or not taken[entry.buff] then count = Add(key, entry, count) end
    end

    local shown = shownByRow[key]
    for i = #shown, count + 1, -1 do shown[i] = nil end
    table.sort(shown, InnerFirst)
    -- more than fit: the ones farthest from the center go
    for i = #shown, slotCount + 1, -1 do shown[i] = nil end
    return shown
end

function ns.InitSlots()
    for _, key in ipairs(ROW_KEYS) do
        for _, slot in ipairs(ns[key]) do BuildSlot(slot) end
    end

    -- Flashing borders pulse on their own every frame: a pulse updated at the slot refresh rate
    -- (10 times a second) would look like stuttering.
    CreateFrame("Frame"):SetScript("OnUpdate", function()
        local alpha = 0.3 + 0.7 * math.abs(math.sin(GetTime() * 4))
        for _, key in ipairs(ROW_KEYS) do
            for _, slot in ipairs(ns[key]) do
                slot.border:SetAlpha(slot.flashing and alpha or 1)
            end
        end
    end)

    local elapsedTotal = 0
    CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < TICK then return end
        elapsedTotal = 0

        local rotation = ns.GetRotation()
        local left, right = 0, 0
        for _, key in ipairs(ROW_KEYS) do
            local row = ns[key]
            local limit = RotatoDB.slotsPerRow
            local shown = Collect(rotation, key, limit)
            if SIDE[key] == "LEFT" then left = math.max(left, #shown) else right = math.max(right, #shown) end
            for i, slot in ipairs(row) do
                local r = i <= limit and shown[i]
                if r then
                    Paint(slot, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[11])
                else
                    slot:Hide()
                end
            end
        end

        -- resizing only when a side's longest row changes, not every tick
        if left ~= ns.shownLeft or right ~= ns.shownRight then
            ns.shownLeft, ns.shownRight = left, right
            if RotatoDB.dynamicWidth then ns.ApplyWidth() end
        end
    end)
end
