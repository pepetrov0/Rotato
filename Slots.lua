local ADDON_NAME, ns = ...

-- The four side rows. Each rotation lists entries per row, shown left to right outward from the
-- center, packed with no gaps:
--   utility    (left, top)    trackers   (right, top)
--   defensives (left, bottom) offensives (right, bottom)
--
-- Entry fields (all optional except one of spell / buff / debuff / targetBuff):
--   spell      = "Name"  cooldown of an ability
--   buff       = "Name"  aura on the player, or { "Name", "Other" } for interchangeable ones (the one that is up is shown)
--   debuff     = "Name"  aura on the target (yours only, unless any = true)
--   targetBuff = "Name"  buff on the target
--   show       = "always" (default) or "active": hide while the aura is not up
--   when       = function(c) extra condition for showing the entry at all
-- An entry can combine an ability with an aura (e.g. spell + buff): while the aura is up its
-- remaining time sweeps, otherwise the ability's cooldown does. A missing aura is shown dimmed.

local TICK = 0.1
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
-- otherwise: icon, sweepStart, sweepDuration, remaining, dimmed, fromAura, highlight
local function Resolve(entry)
    local c = ns.c
    -- buff may be a list of interchangeable buffs, the first one that is up is shown
    local buffList = type(entry.buff) == "table" and entry.buff or nil
    local auraName = buffList and buffList[1] or entry.buff or entry.debuff or entry.targetBuff
    local aura
    if buffList then aura = c.anyBuff(buffList)
    elseif entry.buff then aura = c.buff(entry.buff)
    elseif entry.debuff then aura = c.debuff(entry.debuff, { any = entry.any })
    elseif entry.targetBuff then aura = c.target.buff(entry.targetBuff)
    end
    local active = aura and aura.up

    -- entries that read the target have nothing to show without one
    if (entry.debuff or entry.targetBuff) and not UnitExists("target") then return end
    if entry.show == "active" and not active then return end
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
    local icon = (active and aura.icon) or select(3, GetSpellInfo(entry.spell or auraName)) or entry.lastIcon or UNKNOWN_ICON

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
    -- an ability whose own aura is up (Misdirection, Deterrence...) gets a border; bare auras do not
    local highlight = active and entry.spell ~= nil
    return icon, start, duration, remaining, dimmed, fromAura, highlight
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

            -- yellow border while the ability is active
            local border = CreateFrame("Frame", nil, slot)
            border:SetAllPoints()
            border:SetFrameLevel(cooldown:GetFrameLevel() + 3)
            border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
            border:SetBackdropBorderColor(1, 0.85, 0, 1)
            border:Hide()
            slot.border = border
            slot.time = overlay:CreateFontString(nil, "OVERLAY")
            ns.RegisterText(slot.time, "time")
            slot.time:SetPoint("CENTER")
            slot:Hide()
        end
    end

    local function Paint(slot, icon, start, duration, remaining, dimmed, fromAura, highlight)
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
        if highlight then slot.border:Show() else slot.border:Hide() end
        slot:Show()
    end

    local elapsedTotal = 0
    CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < TICK then return end
        elapsedTotal = 0

        local rotation = ns.GetRotation()
        for _, key in ipairs(ROW_KEYS) do
            local row = ns[key]
            local used = 0
            for _, entry in ipairs(rotation and rotation[key] or {}) do
                if used >= #row then break end
                local icon, start, duration, remaining, dimmed, fromAura, highlight = Resolve(entry)
                if icon then
                    used = used + 1
                    Paint(row[used], icon, start, duration, remaining, dimmed, fromAura, highlight)
                end
            end
            for i = used + 1, #row do row[i]:Hide() end
        end
    end)
end
