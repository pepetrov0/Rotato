local ADDON_NAME, ns = ...

-- The four side rows. Each rotation lists entries per row, shown left to right outward from the
-- center, packed with no gaps:
--   defensives (left, top)   trackers   (right, top)
--   utility    (left, bottom) offensives (right, bottom)
--
-- Entry fields (all optional except one of spell / buff / debuff / targetBuff):
--   spell      = "Name"  cooldown of an ability
--   buff       = "Name"  aura on the player
--   debuff     = "Name"  aura on the target (yours only, unless any = true)
--   targetBuff = "Name"  buff on the target
--   show       = "always" (default) or "active": hide while the aura is not up
--   when       = function(c) extra condition for showing the entry at all
-- An entry can combine an ability with an aura (e.g. spell + buff): while the aura is up its
-- remaining time sweeps, otherwise the ability's cooldown does. A missing aura is shown dimmed.

local TICK = 0.1
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local ROW_KEYS = { "defensives", "utility", "trackers", "offensives" }

local function FormatTime(seconds)
    if seconds >= 3600 then return format("%dh", seconds / 3600)
    elseif seconds >= 60 then return format("%dm", seconds / 60)
    elseif seconds >= 10 then return format("%d", seconds)
    end
    return format("%.1f", seconds)
end

-- Works out what an entry should look like right now. Returns nil when it should not be shown,
-- otherwise: icon, sweepStart, sweepDuration, remaining, dimmed
local function Resolve(entry)
    local c = ns.c
    local auraName = entry.buff or entry.debuff or entry.targetBuff
    local aura
    if entry.buff then aura = c.buff(entry.buff)
    elseif entry.debuff then aura = c.debuff(entry.debuff, { any = entry.any })
    elseif entry.targetBuff then aura = c.target.buff(entry.targetBuff)
    end
    local active = aura and aura.up

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
    if active then
        if aura.duration > 0 then
            start, duration, remaining = aura.expires - aura.duration, aura.duration, aura.expires - now
        end
    elseif cdDuration > ns.GCD_MAX and cdStart > 0 and cdStart + cdDuration > now then
        start, duration, remaining = cdStart, cdDuration, cdStart + cdDuration - now
    end

    local dimmed = auraName and not active and duration == 0
    return icon, start, duration, remaining, dimmed
end

function ns.InitSlots()
    local font = DAMAGE_TEXT_FONT or FALLBACK_FONT

    for _, key in ipairs(ROW_KEYS) do
        for _, slot in ipairs(ns[key]) do
            local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            cooldown.noCooldownCount = true -- we draw our own numbers

            local overlay = CreateFrame("Frame", nil, slot)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

            slot.cooldown = cooldown

            -- trackers count down by graying out from the top instead of the cooldown sweep
            if key == "trackers" then
                slot.gray = slot:CreateTexture(nil, "ARTWORK")
                slot.gray:SetDesaturated(true)
                slot.gray:SetVertexColor(0.45, 0.45, 0.45)
                slot.gray:SetPoint("TOPLEFT", slot.icon, "TOPLEFT")
                slot.gray:SetPoint("TOPRIGHT", slot.icon, "TOPRIGHT")
                slot.gray:Hide()
            end
            slot.time = overlay:CreateFontString(nil, "OVERLAY")
            slot.time:SetFont(font, 12, "OUTLINE")
            slot.time:SetPoint("CENTER")
            slot:Hide()
        end
    end

    -- size of one screen pixel in UI units at scale 1 (UI height is 768 units)
    local _, screenHeight = strmatch(GetCVar("gxResolution") or "", "(%d+)x(%d+)")
    local pixelBase = screenHeight and 768 / screenHeight or 1

    -- Grays the top of a tracker in proportion to the time elapsed. The strip is snapped to whole
    -- screen pixels, with its texture crop derived from the same height, so it lines up with the icon.
    local function Swipe(slot)
        local gray = slot.gray
        local duration = slot.sweepDuration or 0
        if duration <= 0 or not slot:IsShown() then gray:Hide() return end
        local fraction = math.max(0, math.min((GetTime() - slot.sweepStart) / duration, 1))
        local height = slot.icon:GetHeight()
        local pixel = pixelBase / slot:GetEffectiveScale()
        local pixels = math.floor(fraction * height / pixel + 0.5)
        if pixels <= 0 then gray:Hide() return end
        local shown = pixels * pixel
        local left, top, _, bottom, right = slot.icon:GetTexCoord()
        gray:SetTexCoord(left, right, top, top + (shown / height) * (bottom - top))
        gray:SetHeight(shown)
        gray:Show()
    end

    local function Paint(slot, icon, start, duration, remaining, dimmed)
        if slot.shownIcon ~= icon then
            slot.shownIcon = icon
            slot.icon:SetTexture(icon)
            if slot.gray then slot.gray:SetTexture(icon) end
        end
        slot.sweepStart, slot.sweepDuration = start, duration
        local cdStart, cdDuration = start, duration
        if slot.gray then cdStart, cdDuration = 0, 0 end -- trackers use the gray swipe instead
        if slot.shownStart ~= cdStart or slot.shownDuration ~= cdDuration then
            slot.shownStart, slot.shownDuration = cdStart, cdDuration
            CooldownFrame_SetTimer(slot.cooldown, cdStart, cdDuration, cdDuration > 0 and 1 or 0)
        end
        slot.icon:SetDesaturated(dimmed and true or false)
        local shade = dimmed and 0.5 or 1
        slot.icon:SetVertexColor(shade, shade, shade)
        slot.time:SetText(remaining and FormatTime(remaining) or "")
        slot:Show()
    end

    -- the swipe runs every frame; everything else is throttled
    CreateFrame("Frame"):SetScript("OnUpdate", function()
        for _, slot in ipairs(ns.trackers) do Swipe(slot) end
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
            for _, entry in ipairs(rotation and rotation[key] or {}) do
                if used >= #row then break end
                local icon, start, duration, remaining, dimmed = Resolve(entry)
                if icon then
                    used = used + 1
                    Paint(row[used], icon, start, duration, remaining, dimmed)
                end
            end
            for i = used + 1, #row do row[i]:Hide() end
        end
    end)
end
