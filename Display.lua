local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon. A sweep covers the global cooldown or a cooldown
-- we are waiting on; a cast fills the icon up and a channel drains it. Just before a cast or
-- channel ends, the icon switches to the next suggestion if it differs, so it can be queued.

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

    local fill = overlay:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(1, 1, 1, 0.4)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:Hide()

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", 0, 3)

    local shown, shownStart, shownDuration

    -- fraction: nil for no fill, otherwise 0..1 of the icon height
    local function Render(spell, start, duration, text, fraction)
        if spell ~= shown then
            shown = spell
            center.icon:SetTexture(spell and select(3, GetSpellInfo(spell)) or nil)
        end
        start, duration = start or 0, duration or 0
        if start ~= shownStart or duration ~= shownDuration then
            shownStart, shownDuration = start, duration
            CooldownFrame_SetTimer(cooldown, start, duration, duration > 0 and 1 or 0)
        end
        if fraction and fraction > 0 then
            fill:SetHeight(math.max(0.001, math.min(fraction, 1) * (overlay:GetHeight() - 2)))
            fill:Show()
        else
            fill:Hide()
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
            Render(name, 0, 0, text, channeling and 1 - progress or progress)
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
