local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon. A sweep covers the global cooldown or a cooldown
-- we are waiting on, and also the cast or channel in progress: a cast uses the default sweep
-- (the icon is revealed as the cast completes), a channel the reversed one (the icon darkens as
-- it runs out). Just before a cast or channel ends, the icon switches to the next suggestion if
-- it differs, so it can be queued.

local TICK = 0.05
local NEXT_WINDOW = 0.5 -- seconds before a cast/channel ends at which the next spell is shown

function ns.InitDisplay()
    local center = ns.center

    local cooldown = CreateFrame("Cooldown", nil, center, "CooldownFrameTemplate")
    cooldown:SetAllPoints()

    -- regions of the center frame draw under its child frames, so the label gets a frame above the sweep
    local overlay = CreateFrame("Frame", nil, center)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    ns.RegisterText(label, "label")
    label:SetPoint("BOTTOM", 0, 3)

    -- name of the ability to press, right above the panel
    local nameText = ns.frame:CreateFontString(nil, "OVERLAY")
    ns.RegisterText(nameText, "name")
    nameText:SetPoint("BOTTOM", ns.frame, "TOP", 0, 4)

    local shown, shownStart, shownDuration, shownReverse

    -- rotation evaluation is throttled; the animation itself runs every frame
    local evaluated, evaluatedAt = {}, 0
    local function Evaluate()
        local now = GetTime()
        if now - evaluatedAt >= TICK then
            evaluatedAt = now
            evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5] = ns.Evaluate()
        end
        return evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5]
    end
    local preview -- spell last shown as "Next"; keeps its label until you start casting something

    -- reverse: the sweep darkens the icon over time instead of revealing it
    local function Render(spell, start, duration, text, reverse)
        -- nothing to press: hide the center box (and its label) altogether
        if spell and not center:IsShown() then center:Show() end
        if not spell and center:IsShown() then center:Hide() end
        if spell ~= shown then
            shown = spell
            local texture = spell and select(3, GetSpellInfo(spell)) or nil
            center.icon:SetTexture(texture)
            nameText:SetText(spell or "")
            center.tip = spell and { spell = spell } or nil
        end
        start, duration = start or 0, duration or 0
        reverse = reverse and true or false
        if start ~= shownStart or duration ~= shownDuration or reverse ~= shownReverse then
            shownStart, shownDuration, shownReverse = start, duration, reverse
            if cooldown.SetReverse then cooldown:SetReverse(reverse) end
            CooldownFrame_SetTimer(cooldown, start, duration, duration > 0 and 1 or 0)
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
                local next, state, start, duration = Evaluate()
                if next and next ~= name then
                    preview = next
                    Render(next, start, duration, "Next")
                    return
                end
            end
            preview = nil
            Render(name, castStart / 1000, (castEnd - castStart) / 1000, text, channeling)
            return
        end

        local spell, state, start, duration, source = Evaluate()
        if spell ~= preview then preview = nil end
        -- while the global cooldown runs, the suggestion is what to press next
        local gcdRunning = start and duration and start > 0 and duration <= ns.GCD_MAX and start + duration > GetTime()
        local text = spell and ((source == "reminders" and "Reminder") or (state == "cd" and "Cooldown") or ((spell == preview or gcdRunning) and "Next")) or nil
        Render(spell, start, duration, text)
    end

    CreateFrame("Frame"):SetScript("OnUpdate", Update)
end
