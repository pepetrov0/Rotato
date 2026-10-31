local ADDON_NAME, ns = ...

-- Detects the player's class and talents and publishes them as ns.class (the class token),
-- ns.hasTalents (any point spent in the active group) and ns.talentGroup (dual spec).
-- Rotations are offered by ns.class and picked by the player; Rotation.lua keeps one pick per
-- talent group and watches ns.hasTalents for a talent reset. Which tree has the most points does
-- not matter to anything, so it is not detected.

-- Whether any point is spent in the active group, and that group.
local function DetectTalents()
    local group = GetActiveTalentGroup() or 1
    for i = 1, GetNumTalentTabs() do
        local _, _, points = GetTalentTabInfo(i, false, false, group)
        if points and points > 0 then return true, group end
    end
    return false, group
end

-- Talent metadata by name, for the active group. Looking a talent up by name means walking every
-- tab and every talent in it, which is far too slow for a condition the evaluator runs many times
-- a second, so the map is built once and dropped when the talents may have changed (Report runs on
-- every talent event). The active group is checked too, in case a switch slips past the events.
-- Every talent is kept, taken or not, so an untaken one reads as known = false rather than missing.
local talentInfo, talentGroup

local function Talents()
    local group = GetActiveTalentGroup() or 1
    if talentInfo and talentGroup == group then return talentInfo end
    local info = {}
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab, false, false) do
            local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, i, false, false, group)
            if name then
                rank = rank or 0
                info[name] = {
                    name = name, icon = icon, tab = tab, tier = tier, column = column,
                    rank = rank, maxRank = maxRank or 0, known = rank > 0,
                }
            end
        end
    end
    -- Empty means the talent data is not there yet (login, zoning): do not keep believing it.
    if next(info) then talentInfo, talentGroup = info, group end
    return info
end

-- Metadata for the talent of this name, nil when no talent has that name. The table is rebuilt only
-- on a talent change, so it is stable: unlike an aura, it can be kept across updates.
function ns.TalentInfo(name)
    return Talents()[name]
end

-- Drops the map; the next ns.TalentInfo rebuilds it.
function ns.InvalidateTalents()
    talentInfo = nil
end

-- A reset gives every point back, so the unspent points are all the character has earned (one per
-- level from 10). Empty talent data with that many unspent is a reset, not a loading glitch.
local function AllPointsUnspent()
    local level = UnitLevel("player")
    return level >= 10 and (UnitCharacterPoints("player") or 0) >= level - 9
end

local Report -- declared first because Recheck and Report call each other

-- Talent data can read as empty for a moment (entering an instance, zoning). Believing that would
-- count as a talent reset and drop the pick, so while we already know there are talents we keep that and
-- look again for a few seconds. Only a persistent empty read is treated as real, e.g. a talent reset.
local retry
local function Recheck()
    if retry then return end
    local waited = 0
    retry = CreateFrame("Frame")
    retry:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        local found = DetectTalents()
        local reset = not found and AllPointsUnspent()
        if found or reset or waited >= 5 then
            self:SetScript("OnUpdate", nil)
            retry = nil
            Report(reset or (waited >= 5 and not found))
        end
    end)
end

-- Publishes the class and talents and announces them, but only when something actually changed:
-- talent events fire constantly (every point spent) and would spam the chat otherwise.
function Report(force)
    ns.InvalidateTalents() -- a talent event is why this is called, so the map is stale
    local className, classToken = UnitClass("player")
    local hasTalents, group = DetectTalents()

    -- the talent data arrives a moment after login, so an empty first read is not worth announcing
    if not hasTalents and not force and not ns.class then return end
    if not hasTalents and not force and ns.hasTalents and not AllPointsUnspent() then
        Recheck()
        return
    end
    if not force and ns.class == classToken and ns.hasTalents == hasTalents and ns.talentGroup == group then
        return
    end

    ns.class, ns.hasTalents, ns.talentGroup = classToken, hasTalents, group

    local color = RAID_CLASS_COLORS[classToken]
    local colored = color and format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, className)
        or className
    ns.Log(format("%s - talent group %d%s", colored, group, hasTalents and "" or ", no talents"))
    ns.RefreshRotation() -- a reset asks for the rotation now, not at the next tick
end

function ns.InitClass()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:SetScript("OnEvent", function() Report(false) end)

    if DetectTalents() then
        Report(true)
        return
    end

    -- At login the talent data may not be loaded yet. Wait for it instead of announcing no talents,
    -- but give up after a while so a character with no talents still gets reported.
    local waited = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if DetectTalents() or waited >= 10 then
            self:SetScript("OnUpdate", nil)
            Report(true)
        end
    end)
end
