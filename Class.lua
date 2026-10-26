local ADDON_NAME, ns = ...

-- Detects the player's class and talent spec and publishes it as ns.class (the class token),
-- ns.specIndex (1-3, nil when no points are spent), ns.specName and ns.specGroup (dual spec).
-- Rotation files are looked up with these, see ns.GetRotation.

-- The spec is the talent tree with the most points. There is no direct "current spec" API in
-- 3.3.5, and the active talent group matters because a dual-spec character has two sets.
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

local Report -- declared first because Recheck and Report call each other

-- Talent data can read as empty for a moment (entering an instance, zoning). Believing that would
-- drop the rotation until the next talent event, so while we already know the spec we keep it and
-- look again for a few seconds. Only a persistent empty read is treated as real, e.g. a talent reset.
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

-- Publishes the detected spec and announces it, but only when something actually changed:
-- talent events fire constantly (every point spent) and would spam the chat otherwise.
function Report(force)
    local className, classToken = UnitClass("player")
    local index, specName, group = DetectSpec()

    -- the talent data arrives a moment after login, so an empty first read is not worth announcing
    if not index and not force and not ns.class then return end
    if not index and not force and ns.specIndex then
        Recheck()
        return
    end
    if not force and ns.class == classToken and ns.specIndex == index and ns.specGroup == group then
        return
    end

    ns.class, ns.specIndex, ns.specName, ns.specGroup = classToken, index, specName, group

    local color = RAID_CLASS_COLORS[classToken]
    local colored = color and format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, className)
        or className
    ns.Print(format("%s - %s (talent group %d)", colored, specName, group))
end

-- Prints the raw talent values, for when detection looks wrong (/rotato spec).
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

    if DetectSpec() then
        Report(true)
        return
    end

    -- At login the talent data may not be loaded yet. Wait for it instead of announcing "No spec",
    -- but give up after a while so a character with no talents still gets reported.
    local waited = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if DetectSpec() or waited >= 10 then
            self:SetScript("OnUpdate", nil)
            Report(true)
        end
    end)
end
