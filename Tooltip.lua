local ADDON_NAME, ns = ...

-- Holding Alt while the cursor is over the center icon or a side slot shows its tooltip.
--
-- The frame is click-through (see ns.SetLocked), so it never receives mouse events. Hover is
-- therefore detected by position every frame, and Alt is the trigger so that it does not pop up
-- tooltips while the player is just moving the mouse across the screen mid-fight.

-- Shows what the slot is about: the live buff/debuff when one is up, since that tooltip carries
-- the real timer and values, otherwise the ability itself.
local function ShowTip(slot)
    local tip = slot.tip
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")

    if tip.aura then
        -- A tooltip for an aura has to be asked for by its index on the unit, which is why the
        -- aura is looked up by name each time (the index changes as auras come and go).
        local scan = tip.helpful and UnitBuff or UnitDebuff
        for i = 1, 40 do
            local name = scan(tip.unit, i)
            if not name then break end
            if name == tip.aura then
                if tip.helpful then GameTooltip:SetUnitBuff(tip.unit, i) else GameTooltip:SetUnitDebuff(tip.unit, i) end
                GameTooltip:Show()
                return
            end
        end
    end

    -- Entries only know a name. GetSpellLink resolves it for spells the player knows, and
    -- GetItemInfo does the same for items such as flasks.
    local link = tip.spell and GetSpellLink(tip.spell)
    local id = link and link:match("spell:(%d+)")
    local _, itemLink = GetItemInfo(tip.spell or "")
    if id then
        GameTooltip:SetHyperlink("spell:" .. id)
        GameTooltip:Show()
    elseif itemLink then
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    else
        GameTooltip:Hide()
    end
end

function ns.InitTooltips()
    local slots = { ns.center }
    for _, key in ipairs({ "defensives", "utility", "trackers", "offensives" }) do
        for _, slot in ipairs(ns[key]) do slots[#slots + 1] = slot end
    end

    local current, currentKey
    CreateFrame("Frame"):SetScript("OnUpdate", function()
        local hovered
        -- A faded-out frame is invisible but still occupies its place; without the alpha check the
        -- tooltip of an invisible slot would appear.
        if IsAltKeyDown() and ns.frame:GetAlpha() > 0.5 then
            for _, slot in ipairs(slots) do
                if slot.tip and slot:IsShown() and MouseIsOver(slot) then
                    hovered = slot
                    break
                end
            end
        end

        if not hovered then
            if current then
                -- only hide a tooltip that is still ours: another addon may have taken GameTooltip since
                if GameTooltip:GetOwner() == current then GameTooltip:Hide() end
                current, currentKey = nil, nil
            end
            return
        end

        -- Redraw only when the hovered slot changes or starts showing something else (the aura
        -- expired, the suggestion moved on). Re-setting the tooltip every frame would flicker it.
        local tip = hovered.tip
        local key = (tip.aura or "") .. "|" .. (tip.spell or "")
        if hovered ~= current or key ~= currentKey then
            current, currentKey = hovered, key
            ShowTip(hovered)
        end
    end)
end
