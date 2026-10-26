local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon, with a sweep for the global cooldown,
-- a cooldown we are waiting on, or the cast/channel in progress.

local TICK = 0.05

function ns.InitDisplay()
    local center = ns.center

    local cooldown = CreateFrame("Cooldown", nil, center, "CooldownFrameTemplate")
    cooldown:SetAllPoints()

    -- regions of the center frame draw under its child frames, so the label gets a frame above the sweep
    local overlay = CreateFrame("Frame", nil, center)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", 0, 3)

    local shown, shownStart, shownDuration

    local function Render(spell, start, duration, text)
        if spell ~= shown then
            shown = spell
            center.icon:SetTexture(spell and select(3, GetSpellInfo(spell)) or nil)
        end
        start, duration = start or 0, duration or 0
        if start ~= shownStart or duration ~= shownDuration then
            shownStart, shownDuration = start, duration
            CooldownFrame_SetTimer(cooldown, start, duration, duration > 0 and 1 or 0)
        end
        label:SetText(text or "")
    end

    local function Update()
        -- a cast or channel of a rotation spell takes over the icon
        local cast, _, _, _, castStart, castEnd = UnitCastingInfo("player")
        if cast and ns.InRotation(cast) then
            Render(cast, castStart / 1000, (castEnd - castStart) / 1000, "Casting")
            return
        end
        local channel, _, _, _, chStart, chEnd = UnitChannelInfo("player")
        if channel and ns.InRotation(channel) then
            Render(channel, chStart / 1000, (chEnd - chStart) / 1000, "Channeling")
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
