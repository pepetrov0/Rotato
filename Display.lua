local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon. A sweep covers the global cooldown or a cooldown
-- we are waiting on. A cast starts gray and turns to color left to right; a channel starts in
-- color and turns gray the same way. Just before a cast or channel ends, the icon switches to
-- the next suggestion if it differs, so it can be queued.

local TICK = 0.05
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
    gray:SetVertexColor(0.8, 0.8, 0.8)
    gray:SetPoint("TOPRIGHT", center.icon, "TOPRIGHT")
    gray:SetPoint("BOTTOMRIGHT", center.icon, "BOTTOMRIGHT")
    gray:Hide()

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", 0, 3)

    local shown, shownStart, shownDuration

    -- grayFraction: nil for none, otherwise 0..1 of the icon width, measured from the right edge
    local function Render(spell, start, duration, text, grayFraction)
        if spell ~= shown then
            shown = spell
            local texture = spell and select(3, GetSpellInfo(spell)) or nil
            center.icon:SetTexture(texture)
            gray:SetTexture(texture)
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
        else
            gray:Hide()
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
                    Render(next, start, duration, "Next")
                    return
                end
            end
            local progress = (now - castStart) / (castEnd - castStart)
            Render(name, 0, 0, text, channeling and progress or 1 - progress)
            return
        end

        local spell, state, start, duration = ns.Evaluate()
        Render(spell, start, duration, state == "cd" and "Cooldown" or nil)
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
