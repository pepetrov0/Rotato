local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon, with a sweep for whatever is in progress:
--   * the global cooldown, or a cooldown we are waiting on (the default sweep)
--   * a cast (default sweep: the icon is revealed as the cast completes)
--   * a channel (reversed sweep: the icon darkens as the channel runs out)
-- Near the end of a cast or channel the icon switches to the next suggestion if it differs, so the
-- player can see what to queue and does not miss a spell that became ready mid-cast.

local TICK = 0.05       -- the rotation is re-evaluated at this rate; the animation itself runs every frame
local NEXT_WINDOW = 0.5 -- seconds before a cast or channel ends at which the next spell is shown

function ns.InitDisplay()
    local center = ns.center

    local cooldown = CreateFrame("Cooldown", nil, center, "CooldownFrameTemplate")
    cooldown:SetAllPoints()

    -- Regions of a frame draw under its child frames, so the label lives on a frame stacked above
    -- the sweep, otherwise the sweep would cover the text.
    local overlay = CreateFrame("Frame", nil, center)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    ns.RegisterText(label, "label")
    label:SetPoint("BOTTOM", 0, 3)

    -- The name sits on the panel (not the icon) so it fades with it and stays readable at any icon size.
    local nameText = ns.frame:CreateFontString(nil, "OVERLAY")
    ns.RegisterText(nameText, "name")
    nameText:SetPoint("BOTTOM", ns.frame, "TOP", 0, 1)

    local shown, shownStart, shownDuration, shownReverse

    -- Evaluating the rotation is the expensive part and it does not need to run at frame rate, so
    -- the last result is reused between ticks.
    local evaluated, evaluatedAt = {}, 0
    local function Evaluate()
        local now = GetTime()
        if now - evaluatedAt >= TICK then
            evaluatedAt = now
            evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5] = ns.Evaluate()
        end
        return evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5]
    end

    -- The spell last shown as "Next". It keeps the label after its cast ends, until the player
    -- starts casting something, so the hint does not vanish the moment it becomes the suggestion.
    local preview

    -- reverse: the sweep darkens the icon over time instead of revealing it.
    -- Everything is compared with what is already shown first: restarting a sweep or resetting a
    -- texture every frame would make them flicker.
    local function Render(spell, start, duration, text, reverse, gray)
        -- nothing to press: hide the box with its border instead of showing an empty frame
        if spell and not center:IsShown() then center:Show() end
        if not spell and center:IsShown() then center:Hide() end

        if spell ~= shown then
            shown = spell
            -- a spell, or an item when the name is not a spell
            local texture = spell and (select(3, GetSpellInfo(spell)) or select(10, GetItemInfo(spell))) or nil
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

        center.icon:SetDesaturated(gray and true or false)
        label:SetText(text or "")
    end

    local function Update()
        -- A cast or channel of a rotation spell takes over the icon. Spells outside the rotation
        -- (eating, a hearthstone) are ignored so they do not replace the suggestion.
        local name, _, _, _, castStart, castEnd = UnitCastingInfo("player")
        local text, channeling = "Casting", false
        if not name then
            name, _, _, _, castStart, castEnd = UnitChannelInfo("player")
            text, channeling = "Channeling", true
        end

        if name and ns.InRotation(name) then
            local now = GetTime() * 1000 -- the cast times come in milliseconds
            if (castEnd - now) / 1000 <= NEXT_WINDOW then
                local nextSpell, _, start, duration = Evaluate()
                if nextSpell and nextSpell ~= name then
                    preview = nextSpell
                    Render(nextSpell, start, duration, "Next")
                    return
                end
            end
            preview = nil
            Render(name, castStart / 1000, (castEnd - castStart) / 1000, text, channeling)
            return
        end

        local spell, state, start, duration, source = Evaluate()
        if spell ~= preview then preview = nil end

        -- While the global cooldown runs, the suggestion is what to press as soon as it ends.
        local gcdRunning = start and duration and start > 0 and duration <= ns.GCD_MAX
            and start + duration > GetTime()

        local text
        if spell then
            if source == "reminders" then text = "Reminder"
            elseif state == "cd" then text = "Cooldown"
            elseif state == "unusable" then text = "Waiting"
            elseif spell == preview or gcdRunning then text = "Next"
            end
        end
        Render(spell, start, duration, text, false, state == "unusable")
    end

    CreateFrame("Frame"):SetScript("OnUpdate", Update)
end
