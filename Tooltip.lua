local ADDON_NAME, ns = ...

-- Holding Alt while the cursor is over the center icon or a side slot shows its tooltip: the
-- buff/debuff while it is up, otherwise the ability. The frame is click-through, so hover is
-- detected by position instead of by mouse events.

local function ShowTip(slot)
    local tip = slot.tip
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    if tip.aura then
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
                if GameTooltip:GetOwner() == current then GameTooltip:Hide() end
                current, currentKey = nil, nil
            end
            return
        end

        -- redraw when the hovered slot changes or starts showing something else (aura expires, ...)
        local tip = hovered.tip
        local key = (tip.aura or "") .. "|" .. (tip.spell or "")
        if hovered ~= current or key ~= currentKey then
            current, currentKey = hovered, key
            ShowTip(hovered)
        end
    end)
end
