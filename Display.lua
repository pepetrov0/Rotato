local ADDON_NAME, ns = ...

-- Draws the suggestion in the center icon, with a sweep for whatever is in progress:
--   * the global cooldown, or a cooldown we are waiting on (the default sweep)
--   * a cast (default sweep: the icon is revealed as the cast completes)
--   * a channel (reversed sweep: the icon darkens as the channel runs out)
-- Near the end of a cast or channel the icon switches to the next suggestion if it differs, so the
-- player can see what to queue and does not miss a spell that became ready mid-cast.
-- The last second of a channel also flashes a white border around the icon, to draw the eye when
-- the channel is about to end.

local TICK = 0.05       -- the rotation is re-evaluated at this rate; the animation itself runs every frame
local NEXT_WINDOW = 0.5 -- seconds before a cast or channel ends at which the next spell is shown
local CHANNEL_FLASH = 1 -- seconds of channel left at which the icon's border starts flashing

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

    -- Drawn over the skin's own border, as a frame of its own so the icon and the sweep stay under
    -- it. Same look and level as the borders of the small slots (Slots.lua).
    local border = CreateFrame("Frame", nil, center)
    border:SetAllPoints()
    border:SetFrameLevel(cooldown:GetFrameLevel() + 3)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    border:SetBackdropBorderColor(1, 1, 1, 1)
    border:Hide()

    -- The pulse runs every frame: one updated at the rotation tick would visibly stutter. The
    -- shown state is compared first, so a steady channel does not show and hide the frame constantly.
    local borderShown = false
    local function Flash(showing)
        if showing ~= borderShown then
            borderShown = showing
            if showing then border:Show() else border:Hide() end
        end
        if showing then border:SetAlpha(0.3 + 0.7 * math.abs(math.sin(GetTime() * 4))) end
    end

    local shown, shownStart, shownDuration, shownReverse

    -- Evaluating the rotation is the expensive part and it does not need to run at frame rate, so
    -- the last result is reused between ticks.
    -- Visibility.lua reads it too, so the rotation is not evaluated twice for the same moment.
    local evaluated, evaluatedAt = {}, 0
    local function Evaluate()
        local now = GetTime()
        if now - evaluatedAt >= TICK then
            evaluatedAt = now
            evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5] = ns.Evaluate()
        end
        return evaluated[1], evaluated[2], evaluated[3], evaluated[4], evaluated[5]
    end
    ns.EvaluateCached = Evaluate

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

        -- only a rotation channel takes the icon over, so only it can end in the icon's border; the
        -- next suggestion is already in it during the last moments, and the border keeps flashing there
        local now = GetTime() * 1000 -- the cast times come in milliseconds
        local remaining = name and (castEnd - now) / 1000 or math.huge
        local ours = name and ns.InRotation(name)
        Flash(channeling and ours and remaining <= CHANNEL_FLASH)

        if ours then
            if remaining <= NEXT_WINDOW then
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
