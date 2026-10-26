local ADDON_NAME, ns = ...

-- Detects the player's class and talent spec (the tree with the most points spent).
-- Sets ns.class (token), ns.specIndex (1-3, nil if untalented) and ns.specName.
local function DetectSpec()
    local group = GetActiveTalentGroup() or 1
    local bestIndex, bestPoints
    for i = 1, GetNumTalentTabs() do
        local _, _, points = GetTalentTabInfo(i, false, false, group)
        if points and points > 0 and (not bestPoints or points > bestPoints) then
            bestIndex, bestPoints = i, points
        end
    end
    if bestIndex then
        return bestIndex, (GetTalentTabInfo(bestIndex, false, false, group)), group
    end
    return nil, "No spec", group
end

local function Report(force)
    local className, classToken = UnitClass("player")
    local index, specName, group = DetectSpec()
    if not force and ns.class == classToken and ns.specIndex == index and ns.specGroup == group then
        return
    end
    ns.class, ns.specIndex, ns.specName, ns.specGroup = classToken, index, specName, group

    local c = RAID_CLASS_COLORS[classToken]
    local colored = c and format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, className) or className
    ns.Print(format("%s - %s (talent group %d)", colored, specName, group))
end

function ns.InitClass()
    Report(true)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:SetScript("OnEvent", function() Report(false) end)
end
