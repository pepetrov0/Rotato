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
--   playerDebuff = "Name"   a debuff on the player
--   debuff       = "Name"   an aura on the target (yours only, unless any = true)
--   targetBuff   = "Name"   a buff on the target
--   targetBuffType         = { "Magic", "Enrage" }   any buff of those dispel types on the target
--   healTargetBuff        = "Name"   your own buff (a hot) on whoever a heal would go to
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
--   discourage = function(c)  true while using it is pointless right now: the icon is grayed out
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

local function FormatTime(seconds)
    if seconds >= 3600 then return format("%dh", seconds / 3600)
    elseif seconds >= 60 then return format("%dm", seconds / 60)
    elseif seconds >= 10 then return format("%d", seconds)
    end
    return format("%.1f", seconds) -- the last seconds are what matters, so show tenths
end

-- Variants ---------------------------------------------------------------

local VARIANT_FIELDS = { "spell", "buff", "debuff", "targetBuff", "playerDebuff", "healTargetBuff", "healTargetDebuff" }

-- Fields written as { variant = "name" } are replaced by the current spell of that variant. This is
-- done on a proxy that reads through to the real entry, instead of editing the entry, because the
-- entry belongs to the rotation file and the option can change again on the next cast. The proxy
-- forwards writes too, so per-entry flags (errored, lastIcon) still land on the real entry.
local function ResolveVariants(entry)
    local proxy
    for _, field in ipairs(VARIANT_FIELDS) do
        local value = rawget(entry, field)
        if type(value) == "table" and value.variant then
            proxy = proxy or setmetatable({}, { __index = entry, __newindex = entry })
            rawset(proxy, field, ns.VariantSpell(value.variant))
        end
    end
    return proxy or entry
end

-- Resolving an entry ---------------------------------------------------------

-- Reads the aura an entry is about. Also returns the unit it was read from when that is a heal
-- target, because the tooltip needs to know where to look.
local function ReadAura(entry, buffList)
    local c = ns.c
    if buffList then return c.anyBuff(buffList)
    elseif entry.buff then return c.buff(entry.buff)
    elseif entry.playerDebuff then return c.selfDebuff(entry.playerDebuff)
    elseif entry.debuff then return c.debuff(entry.debuff, { any = entry.any })
    elseif entry.targetBuff then return c.target.buff(entry.targetBuff)
    elseif entry.targetBuffType then return c.target.buffOfType(unpack(entry.targetBuffType))
    elseif entry.healTargetBuff then
        local unit = c.healTarget()
        return c.buffOn(unit, entry.healTargetBuff), unit
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
--   8 flash  9 tip  10 coolingDown  11 idleReady
local function Resolve(entry, rowKey)
    entry = ResolveVariants(entry)
    local c = ns.c
    local typeList = entry.targetBuffType
    local healTypeList = entry.healTargetDebuffType

    local buffList = type(entry.buff) == "table" and entry.buff or nil
    local auraName = buffList and buffList[1] or entry.buff or entry.playerDebuff or entry.debuff
        or entry.targetBuff or entry.healTargetBuff or entry.healTargetDebuff

    local aura, healUnit = ReadAura(entry, buffList)
    local active = aura and aura.up

    -- Visibility rules, cheapest first.
    -- An entry that reads the target has nothing to show without one (playerDebuff reads the player).
    if (entry.debuff or entry.targetBuff or typeList) and not UnitExists("target") then return end
    -- the trackers only show auras: a bare cooldown there would just be noise next to the real trackers
    if rowKey == "trackers" and not (entry.buff or entry.debuff or typeList or healTypeList
        or entry.healTargetBuff or entry.healTargetDebuff) then
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

    -- Only a bare aura is dimmed while missing: that is how a tracker says "not up". An ability
    -- slot is not dimmed just because its buff is down, it is simply ready.
    local dimmed = auraName and not entry.spell and not active
    if entry.discourage and not dimmed then
        local ok, discouraged = pcall(entry.discourage, c)
        if ok then
            dimmed = discouraged and true or false
        elseif not entry.discourageErrored then
            entry.discourageErrored = true -- report once, this runs several times a second
            ns.Print("discourage error in " .. tostring(entry.spell or auraName) .. ": " .. tostring(discouraged))
        end
    end

    local expiring = fromAura and remaining and remaining < FLASH_BELOW
    local borderColor
    if rowKey == "trackers" then
        -- a tracker only draws attention when something is missing, wrong, a lockout, or about to run out
        if entry.lockout and active then borderColor = BLUE
        elseif typeList or healTypeList or not active or expiring then borderColor = RED end
    elseif active then
        borderColor = entry.lockout and BLUE or ((entry.buff or entry.debuff or entry.healTargetBuff) and GREEN or RED)
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
    local tip = { spell = entry.spell or auraName }
    if active and aura.name then
        tip.aura = aura.name
        if entry.buff then tip.unit, tip.helpful = "player", true
        elseif entry.playerDebuff then tip.unit, tip.helpful = "player", false
        elseif entry.debuff then tip.unit, tip.helpful = "target", false
        elseif entry.healTargetBuff then tip.unit, tip.helpful = healUnit, true
        elseif entry.healTargetDebuff or healTypeList then tip.unit, tip.helpful = healUnit, false
        else tip.unit, tip.helpful = "target", true
        end
    end

    -- Overflow hints: when a row has more entries than slots, these decide what goes first.
    -- An ability that is only showing its cooldown carries the least information...
    local coolingDown = not active and duration > 0
    -- ...then an ability that is simply ready with nothing to say about it (no aura, no recommendation).
    local idleReady = entry.spell ~= nil and not active and not coolingDown and borderColor == nil

    return icon, start, duration, remaining, dimmed, fromAura, borderColor,
        borderColor and expiring or false, tip, coolingDown, idleReady
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
local function Paint(slot, icon, start, duration, remaining, dimmed, fromAura, borderColor, flash, tip)
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

    slot.time:SetText(remaining and FormatTime(remaining) or "")
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

-- Everything one row should show right now, already trimmed to the number of slots.
local function Collect(rotation, key, slotCount)
    local own = rotation and rotation[key] or {}

    -- A shared entry is skipped when the rotation already has one for the same ability or buff in
    -- this row, otherwise the same thing would show twice (an ability slot, plus the shared buff
    -- slot that appears when the buff lands on you).
    local taken = {}
    for _, entry in ipairs(own) do
        if entry.spell then taken[entry.spell] = true end
        if type(entry.buff) == "string" then taken[entry.buff] = true end
    end

    local shown = {}
    for _, list in ipairs({ own, ns.common[key] or {} }) do
        for _, entry in ipairs(list) do
            if list == own or type(entry.buff) ~= "string" or not taken[entry.buff] then
                local result = { Resolve(entry, key) }
                if result[1] then shown[#shown + 1] = result end
            end
        end
    end

    -- More than fit: make room by dropping what says the least, one class of entry at a time, the
    -- last entries first. The order, from least to most worth keeping:
    --   1 an ability only showing its cooldown (10th value of Resolve)
    --   2 an ability that is merely ready, no aura and no recommendation (11th)
    --   3 something active and fine: a green border, or none (a healthy tracker)
    --   4 a lockout counting down (blue), which at least says why a spell cannot be used
    --   5 whatever is left needs action (red) or is recommended (white)
    local DROP_ORDER = {
        function(result) return result[10] end,
        function(result) return result[11] end,
        function(result) return not result[7] or result[7] == GREEN end,
        function(result) return result[7] == BLUE end,
        function(result) return true end,
    }
    local excess = #shown - slotCount
    for _, droppable in ipairs(DROP_ORDER) do
        for i = #shown, 1, -1 do
            if excess <= 0 then break end
            if droppable(shown[i]) then
                table.remove(shown, i)
                excess = excess - 1
            end
        end
    end
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
        for _, key in ipairs(ROW_KEYS) do
            local row = ns[key]
            local shown = Collect(rotation, key, #row)
            for i, slot in ipairs(row) do
                local r = shown[i]
                if r then
                    Paint(slot, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
                else
                    slot:Hide()
                end
            end
        end
    end)
end
