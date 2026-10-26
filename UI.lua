local ADDON_NAME, ns = ...

local ICON_SIZE = 36
local SPACING = 2
local PADDING = 6
local PER_ROW = 5
local CENTER_SIZE = ICON_SIZE * 2 + SPACING
local SNAP = 20 -- pixels from a screen center line at which we snap
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local PIXEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local E = ElvUI and ElvUI[1]

-- Skinning ---------------------------------------------------------------

local function SkinPanel(f)
    if E and f.SetTemplate then
        f:SetTemplate("Transparent")
    else
        f:SetBackdrop(TOOLTIP_BACKDROP)
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
end

local function SkinSlot(f)
    if E and f.SetTemplate then
        f:SetTemplate("Default")
        f.icon:SetTexCoord(unpack(E.TexCoords))
        if f.icon.SetInside then
            f.icon:SetInside()
        else
            f.icon:SetPoint("TOPLEFT", 2, -2)
            f.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        end
    else
        f:SetBackdrop(PIXEL_BACKDROP)
        f:SetBackdropColor(0, 0, 0, 0.6)
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.icon:SetPoint("TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
end

-- Widgets ----------------------------------------------------------------

local function CreateSlot(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(size)
    f:SetHeight(size)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexture(PLACEHOLDER)
    SkinSlot(f)
    return f
end

-- Builds one row of slots next to the center icon.
-- side: "LEFT" grows right-to-left, "RIGHT" grows left-to-right.
-- vertical: "TOP" or "BOTTOM" row.
local function BuildRow(parent, center, side, vertical)
    local row = {}
    local inner = side == "LEFT" and "RIGHT" or "LEFT"   -- slot edge that faces the center
    local outer = side == "LEFT" and "LEFT" or "RIGHT"   -- slot edge that faces away
    local sign = side == "LEFT" and -1 or 1
    for i = 1, PER_ROW do
        local slot = CreateSlot(parent, ICON_SIZE)
        if i == 1 then
            slot:SetPoint(vertical .. inner, center, vertical .. outer, sign * SPACING, 0)
        else
            slot:SetPoint(inner, row[i - 1], outer, sign * SPACING, 0)
        end
        row[i] = slot
    end
    return row
end

-- Positioning ------------------------------------------------------------

function ns.ApplyPosition()
    local p = RotatoDB.pos
    ns.frame:ClearAllPoints()
    ns.frame:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
end

-- Center guide lines, shown while dragging; they turn green when snapped.
local function CreateGuides()
    local v = UIParent:CreateTexture(nil, "OVERLAY")
    v:SetTexture(1, 1, 1, 0.5)
    v:SetWidth(1)
    v:SetPoint("TOP", UIParent, "TOP")
    v:SetPoint("BOTTOM", UIParent, "BOTTOM")
    v:Hide()
    local h = UIParent:CreateTexture(nil, "OVERLAY")
    h:SetTexture(1, 1, 1, 0.5)
    h:SetHeight(1)
    h:SetPoint("LEFT", UIParent, "LEFT")
    h:SetPoint("RIGHT", UIParent, "RIGHT")
    h:Hide()
    return v, h
end

-- Manual drag so the frame can snap live instead of only on release.
local function DragUpdate(f)
    local ux, uy = UIParent:GetCenter()
    local s = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local x = mx / s - ux + f.dragOffX
    local y = my / s - uy + f.dragOffY
    local snapX, snapY = math.abs(x) < SNAP, math.abs(y) < SNAP
    if snapX then x = 0 end
    if snapY then y = 0 end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    f.pos = { x = x, y = y }
    ns.guideV:SetTexture(snapX and 0 or 1, 1, snapX and 0 or 1, snapX and 0.9 or 0.5)
    ns.guideH:SetTexture(snapY and 0 or 1, 1, snapY and 0 or 1, snapY and 0.9 or 0.5)
end

local function DragStart(f)
    if not IsShiftKeyDown() then return end
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local s = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    f.dragOffX = (cx - ux) - (mx / s - ux)
    f.dragOffY = (cy - uy) - (my / s - uy)
    f.pos = nil
    f.dragging = true
    f:SetScript("OnUpdate", DragUpdate)
    ns.guideV:Show()
    ns.guideH:Show()
end

local function DragStop(f)
    f:SetScript("OnUpdate", nil)
    f.dragging = false
    ns.guideV:Hide()
    ns.guideH:Hide()
    if f.pos then
        RotatoDB.pos = f.pos
        f.pos = nil
    end
    f:EnableMouse(IsShiftKeyDown())
end

-- Main -------------------------------------------------------------------

function ns.CreateUI()
    local width = CENTER_SIZE + 2 * (PER_ROW * (ICON_SIZE + SPACING)) + 2 * PADDING
    local height = CENTER_SIZE + 2 * PADDING

    local f = CreateFrame("Frame", "RotatoFrame", UIParent)
    f:SetWidth(width)
    f:SetHeight(height)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    -- Click-through unless shift is held (needed to drag), so targets behind it stay selectable.
    f:EnableMouse(false)
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function(self)
        if not self.dragging then self:EnableMouse(IsShiftKeyDown()) end
    end)
    f:RegisterForDrag("LeftButton")
    SkinPanel(f)
    ns.frame = f
    ns.guideV, ns.guideH = CreateGuides()

    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)

    -- big "next spell" icon, spanning both rows
    local center = CreateSlot(f, CENTER_SIZE)
    center:SetPoint("CENTER", f, "CENTER")
    ns.center = center

    ns.defensives = BuildRow(f, center, "LEFT", "TOP")
    ns.utility    = BuildRow(f, center, "LEFT", "BOTTOM")
    ns.trackers   = BuildRow(f, center, "RIGHT", "TOP")
    ns.offensives = BuildRow(f, center, "RIGHT", "BOTTOM")

    ns.ApplyPosition()
end
