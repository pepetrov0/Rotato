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

local Report

-- Talent data can briefly read as empty (entering an instance, zoning). When that happens while we
-- already know the spec, keep the old one and look again for a few seconds before believing it.
local retry
local function Recheck()
    if retry then return end
    local waited = 0
    retry = CreateFrame("Frame")
    retry:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if DetectSpec() or waited >= 5 then
            self:SetScript("OnUpdate", nil)
            retry = nil
            Report(waited >= 5 and not DetectSpec())
        end
    end)
end

function Report(force)
    local className, classToken = UnitClass("player")
    local index, specName, group = DetectSpec()
    -- talent data arrives a moment after login; don't announce "No spec" before we've reported anything
    if not index and not force and not ns.class then return end
    if not index and not force and ns.specIndex then
        Recheck()
        return
    end
    if not force and ns.class == classToken and ns.specIndex == index and ns.specGroup == group then
        return
    end
    ns.class, ns.specIndex, ns.specName, ns.specGroup = classToken, index, specName, group

    local c = RAID_CLASS_COLORS[classToken]
    local colored = c and format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, className) or className
    ns.Print(format("%s - %s (talent group %d)", colored, specName, group))
end

-- Prints the raw talent API values, for when detection looks wrong.
function ns.DumpSpec()
    local group = GetActiveTalentGroup()
    ns.Print(format("tabs=%s activeGroup=%s groups=%s", tostring(GetNumTalentTabs()),
        tostring(group), tostring(GetNumTalentGroups())))
    for i = 1, GetNumTalentTabs() do
        local name, _, points = GetTalentTabInfo(i, false, false, group)
        ns.Print(format("  tab %d: %s, %s points", i, tostring(name), tostring(points)))
    end
end

function ns.InitClass()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:SetScript("OnEvent", function() Report(false) end)

    -- Talents may not be loaded at login: retry for a few seconds, then report whatever we have.
    if DetectSpec() then
        Report(true)
        return
    end
    local waited = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if DetectSpec() or waited >= 10 then
            self:SetScript("OnUpdate", nil)
            Report(true)
        end
    end)
end
