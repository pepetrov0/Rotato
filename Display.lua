local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon. A sweep covers the global cooldown or a cooldown
-- we are waiting on. A cast starts gray and turns to color left to right; a channel starts in
-- color and turns gray the same way. Just before a cast or channel ends, the icon switches to
-- the next suggestion if it differs, so it can be queued.

local TICK = 0.05
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local NEXT_WINDOW = 0.5 -- seconds before a cast/channel ends at which the next spell is shown

function ns.InitDisplay()
    local center = ns.center

    local cooldown = CreateFrame("Cooldown", nil, center, "CooldownFrameTemplate")
    cooldown:SetAllPoints()

    -- regions of the center frame draw under its child frames, so the fill and label get a frame above the sweep
    local overlay = CreateFrame("Frame", nil, center)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

    -- desaturated copy of the icon, covering the right-hand part that has not turned to color yet
    local gray = overlay:CreateTexture(nil, "ARTWORK")
    gray:SetDesaturated(true)
    gray:SetVertexColor(0.45, 0.45, 0.45) -- dark enough to contrast even if desaturation is unsupported
    gray:SetPoint("TOPRIGHT", center.icon, "TOPRIGHT")
    gray:SetPoint("BOTTOMRIGHT", center.icon, "BOTTOMRIGHT")
    gray:Hide()

    -- bright edge on the boundary, so the movement is easy to follow
    local edge = overlay:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(1, 1, 1, 0.9)
    edge:SetWidth(2)
    edge:SetPoint("TOPRIGHT", gray, "TOPLEFT")
    edge:SetPoint("BOTTOMRIGHT", gray, "BOTTOMLEFT")
    edge:Hide()

    -- text uses the combat text font (ElvUI sets DAMAGE_TEXT_FONT to its own choice)
    local font = DAMAGE_TEXT_FONT or FALLBACK_FONT

    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont(font, 12, "OUTLINE")
    label:SetPoint("BOTTOM", 0, 3)

    -- name of the ability to press, right above the panel
    local nameText = ns.frame:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(font, 16, "OUTLINE")
    nameText:SetPoint("BOTTOM", ns.frame, "TOP", 0, 4)

    local shown, shownStart, shownDuration
    local preview -- spell last shown as "Next"; keeps its label until you start casting something

    -- grayFraction: nil for none, otherwise 0..1 of the icon width, measured from the right edge
    local function Render(spell, start, duration, text, grayFraction)
        if spell ~= shown then
            shown = spell
            local texture = spell and select(3, GetSpellInfo(spell)) or nil
            center.icon:SetTexture(texture)
            gray:SetTexture(texture)
            nameText:SetText(spell or "")
        end
        start, duration = start or 0, duration or 0
        if start ~= shownStart or duration ~= shownDuration then
            shownStart, shownDuration = start, duration
            CooldownFrame_SetTimer(cooldown, start, duration, duration > 0 and 1 or 0)
        end
        if grayFraction and grayFraction > 0 and shown then
            grayFraction = math.min(grayFraction, 1)
            -- crop the texture to the same right-hand slice the width shows
            local left, top, _, _, right, _, _, bottom = center.icon:GetTexCoord()
            gray:SetTexCoord(left + (1 - grayFraction) * (right - left), right, top, bottom)
            gray:SetWidth(math.max(0.001, grayFraction * center.icon:GetWidth()))
            gray:Show()
            edge:Show()
        else
            gray:Hide()
            edge:Hide()
        end
        label:SetText(text or "")
    end

    local function Update()
        -- a cast or channel of a rotation spell takes over the icon
        local name, _, _, _, castStart, castEnd = UnitCastingInfo("player")
        local text, channeling = "Casting", false
        if not name then
            name, _, _, _, castStart, castEnd = UnitChannelInfo("player")
            text, channeling = "Channeling", true
        end
        if name and ns.InRotation(name) then
            local now = GetTime() * 1000
            if (castEnd - now) / 1000 <= NEXT_WINDOW then
                local next, state, start, duration = ns.Evaluate()
                if next and next ~= name then
                    preview = next
                    Render(next, start, duration, "Next")
                    return
                end
            end
            preview = nil
            local progress = (now - castStart) / (castEnd - castStart)
            Render(name, 0, 0, text, channeling and progress or 1 - progress)
            return
        end

        local spell, state, start, duration = ns.Evaluate()
        if spell ~= preview then preview = nil end
        -- while the global cooldown runs, the suggestion is what to press next
        local gcdRunning = start and duration and start > 0 and duration <= ns.GCD_MAX and start + duration > GetTime()
        local text = (state == "cd" and "Cooldown") or ((spell == preview or gcdRunning) and "Next") or nil
        Render(spell, start, duration, text)
    end

    local elapsedTotal = 0
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < TICK then return end
        elapsedTotal = 0
        Update()
    end)
end
