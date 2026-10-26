local ADDON_NAME, ns = ...

-- The four side rows. Each rotation lists entries per row, shown left to right outward from the
-- center, packed with no gaps:
--   utility    (left, top)    trackers   (right, top)
--   defensives (left, bottom) offensives (right, bottom)
--
-- Entry fields (all optional except one of spell / buff / debuff / targetBuff):
--   spell      = "Name"  cooldown of an ability
--   buff       = "Name"  aura on the player, or { "Name", "Other" } for interchangeable ones (the one that is up is shown)
--   playerDebuff = "Name" debuff on the player
--   debuff     = "Name"  aura on the target (yours only, unless any = true)
--   targetBuff = "Name"  buff on the target
--   targetBuffType = { "Magic", "Enrage" }  any buff of those dispel types on the target (shown only while present)
--   show       = "always" (default) or "active": hide while the aura is not up
--   when       = function(c) extra condition for showing the entry at all
-- An entry can combine an ability with an aura (e.g. spell + buff): while the aura is up its
-- remaining time sweeps, otherwise the ability's cooldown does. A missing aura is shown dimmed.
--
-- Borders: an active aura is green when good for you (a buff on you, your debuff on the target) and
-- red when bad for you (a debuff on you, a buff on the target). Trackers differ: only buff/debuff
-- entries (and targetBuffType) are shown there; a missing buff or debuff gets a red border, a present one
-- none, and a targetBuffType buff is red. Any border flashes while its aura is about to expire.

local TICK = 0.1
local GREEN = { 0, 1, 0 }
local RED = { 1, 0, 0 }
local FLASH_BELOW = 5 -- seconds left at which a border starts flashing
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ROW_KEYS = { "defensives", "utility", "trackers", "offensives" }

local function FormatTime(seconds)
    if seconds >= 3600 then return format("%dh", seconds / 3600)
    elseif seconds >= 60 then return format("%dm", seconds / 60)
    elseif seconds >= 10 then return format("%d", seconds)
    end
    return format("%.1f", seconds)
end

-- Works out what an entry should look like right now. Returns nil when it should not be shown,
-- otherwise: icon, sweepStart, sweepDuration, remaining, dimmed, fromAura, borderColor, flash, tip
local function Resolve(entry, rowKey)
    local c = ns.c
    local typeList = entry.targetBuffType
    -- buff may be a list of interchangeable buffs, the first one that is up is shown
    local buffList = type(entry.buff) == "table" and entry.buff or nil
    local auraName = buffList and buffList[1] or entry.buff or entry.playerDebuff or entry.debuff or entry.targetBuff
    local aura
    if buffList then aura = c.anyBuff(buffList)
    elseif entry.buff then aura = c.buff(entry.buff)
    elseif entry.playerDebuff then aura = c.selfDebuff(entry.playerDebuff)
    elseif entry.debuff then aura = c.debuff(entry.debuff, { any = entry.any })
    elseif entry.targetBuff then aura = c.target.buff(entry.targetBuff)
    elseif typeList then aura = c.target.buffOfType(unpack(typeList))
    end
    local active = aura and aura.up

    -- entries that read the target have nothing to show without one
    if (entry.debuff or entry.targetBuff or typeList) and not UnitExists("target") then return end -- playerDebuff reads the player
    if rowKey == "trackers" and not (entry.buff or entry.debuff or typeList) then return end
    if (entry.show == "active" or typeList) and not active then return end
    if entry.when and not ns.Passes(entry, auraName or entry.spell) then return end

    -- unknown abilities are hidden, unless their aura happens to be up
    local cdStart, cdDuration = 0, 0
    if entry.spell then
        cdStart, cdDuration = GetSpellCooldown(entry.spell)
        if not cdStart and not active then return end
        cdStart, cdDuration = cdStart or 0, cdDuration or 0
    elseif auraName and not active and not GetSpellInfo(auraName) then
        return
    end

    if active and aura.icon then entry.lastIcon = aura.icon end
    local icon = (active and aura.icon) or ((entry.spell or auraName) and select(3, GetSpellInfo(entry.spell or auraName))) or entry.lastIcon or UNKNOWN_ICON

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

    -- only a bare aura (no ability) is dimmed while missing; an ability that is ready is normal
    local dimmed = auraName and not entry.spell and not active
    -- an active aura gets a border: green when it is good for you (a buff on you, your debuff on the
    -- target), red when it is bad for you (a debuff on you, a buff on the target)
    local expiring = fromAura and remaining and remaining < FLASH_BELOW
    local borderColor
    if rowKey == "trackers" then
        -- a tracker only draws attention when something is missing, wrong, or about to run out
        if typeList or not active or expiring then borderColor = RED end
    elseif active then
        borderColor = (entry.buff or entry.debuff) and GREEN or RED
    end

    -- what the Alt tooltip shows: the aura while it is up, otherwise the ability
    local tip = { spell = entry.spell or auraName }
    if active and aura.name then
        tip.aura = aura.name
        if entry.buff then tip.unit, tip.helpful = "player", true
        elseif entry.playerDebuff then tip.unit, tip.helpful = "player", false
        elseif entry.debuff then tip.unit, tip.helpful = "target", false
        else tip.unit, tip.helpful = "target", true
        end
    end
    return icon, start, duration, remaining, dimmed, fromAura, borderColor, borderColor and expiring or false, tip
end

function ns.InitSlots()
    for _, key in ipairs(ROW_KEYS) do
        for _, slot in ipairs(ns[key]) do
            local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            cooldown.noCooldownCount = true -- we draw our own numbers
            -- aura timers are reversed (icon starts visible and darkens), cooldowns use the default sweep
            if not cooldown.SetReverse and not ns.warnedReverse then
                ns.warnedReverse = true
                ns.Print("this client has no Cooldown:SetReverse, the side slot sweep can't be reversed")
            end

            local overlay = CreateFrame("Frame", nil, slot)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

            slot.cooldown = cooldown

            -- colored border while an aura is active
            local border = CreateFrame("Frame", nil, slot)
            border:SetAllPoints()
            border:SetFrameLevel(cooldown:GetFrameLevel() + 3)
            border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
            border:Hide()
            slot.border = border
            slot.time = overlay:CreateFontString(nil, "OVERLAY")
            ns.RegisterText(slot.time, "time")
            slot.time:SetPoint("CENTER")
            slot:Hide()
        end
    end

    local function Paint(slot, icon, start, duration, remaining, dimmed, fromAura, borderColor, flash, tip)
        if slot.shownIcon ~= icon then
            slot.shownIcon = icon
            slot.icon:SetTexture(icon)
        end
        if slot.shownStart ~= start or slot.shownDuration ~= duration or slot.shownAura ~= fromAura then
            slot.shownStart, slot.shownDuration, slot.shownAura = start, duration, fromAura
            if slot.cooldown.SetReverse then slot.cooldown:SetReverse(fromAura) end
            CooldownFrame_SetTimer(slot.cooldown, start, duration, duration > 0 and 1 or 0)
        end
        slot.icon:SetDesaturated(dimmed and true or false)
        local shade = dimmed and 0.5 or 1
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

    -- flashing borders pulse every frame
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
            local used = 0
            -- the rotation's own entries first, then the common ones
            for _, list in ipairs({ rotation and rotation[key] or {}, ns.common[key] or {} }) do
                for _, entry in ipairs(list) do
                    if used >= #row then break end
                    local icon, start, duration, remaining, dimmed, fromAura, borderColor, flash, tip = Resolve(entry, key)
                    if icon then
                        used = used + 1
                        Paint(row[used], icon, start, duration, remaining, dimmed, fromAura, borderColor, flash, tip)
                    end
                end
            end
            for i = used + 1, #row do row[i]:Hide() end
        end
    end)
end
