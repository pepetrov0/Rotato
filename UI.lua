local ADDON_NAME, ns = ...

local SPACING = 2
local PADDING = 6
local PER_ROW = 5
local SNAP = 20 -- pixels from a screen center line at which we snap

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

local function SetSlotSize(f, size)
    f:SetWidth(size)
    f:SetHeight(size)
end

-- boxed slots get the bordered skin (the center action box); the rest are bare icons.
local function CreateSlot(parent, boxed)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    if boxed then
        SkinSlot(f)
    else
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
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
        local slot = CreateSlot(parent)
        if i == 1 then
            slot:SetPoint(vertical .. inner, center, vertical .. outer, sign * SPACING, 0)
        else
            slot:SetPoint(inner, row[i - 1], outer, sign * SPACING, 0)
        end
        row[i] = slot
    end
    return row
end

-- Sizing -----------------------------------------------------------------

-- The center icon is the one setting; the small icons are half of it (minus spacing).
function ns.ApplySize()
    local c = RotatoDB.centerSize
    local s = (c - SPACING) / 2
    SetSlotSize(ns.center, c)
    for _, row in ipairs({ ns.defensives, ns.utility, ns.trackers, ns.offensives }) do
        for _, slot in ipairs(row) do SetSlotSize(slot, s) end
    end
    ns.frame:SetWidth(c + 2 * PER_ROW * (s + SPACING) + 2 * PADDING)
    ns.frame:SetHeight(c + 2 * PADDING)
end

-- Context menu ----------------------------------------------------------

local SIZE_PRESETS = {
    { "Tiny", 50 },
    { "Small", 70 },
    { "Medium", 90 },
    { "Large", 110 },
    { "Extra large", 130 },
    { "Huge", 150 },
}

local TEXT_SIZES = { 8, 10, 12, 14, 16, 18, 20, 24, 28, 32 }
local BUILTIN_FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Skurri", "Fonts\\skurri.ttf" },
    { "Morpheus", "Fonts\\MORPHEUS.ttf" },
}

local function FontMenu()
    local list = { { "Combat text (default)", nil } }
    for _, font in ipairs(BUILTIN_FONTS) do list[#list + 1] = font end
    -- ElvUI and many addons ship LibSharedMedia; offer its fonts too
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media then
        for _, name in ipairs(media:List("font")) do
            list[#list + 1] = { name, media:Fetch("font", name) }
        end
    end
    local menu = {}
    for _, font in ipairs(list) do
        local name, path = font[1], font[2]
        tinsert(menu, {
            text = name,
            checked = RotatoDB.font == path,
            func = function()
                RotatoDB.font = path
                ns.ApplyFonts()
                CloseDropDownMenus()
            end,
        })
    end
    return menu
end

local function SizeMenu(key)
    local menu = {}
    for _, size in ipairs(TEXT_SIZES) do
        tinsert(menu, {
            text = tostring(size),
            checked = RotatoDB[key] == size,
            func = function()
                RotatoDB[key] = size
                ns.ApplyFonts()
                CloseDropDownMenus()
            end,
        })
    end
    return menu
end

function ns.OpenMenu()
    ns.menuFrame = ns.menuFrame or CreateFrame("Frame", "RotatoMenu", UIParent, "UIDropDownMenuTemplate")
    local menu = { { text = "Rotato", isTitle = true, notCheckable = true } }

    local cardSizes = {}
    for _, preset in ipairs(SIZE_PRESETS) do
        local name, size = preset[1], preset[2]
        tinsert(cardSizes, {
            text = name .. " (" .. size .. ")",
            checked = RotatoDB.centerSize == size,
            func = function()
                RotatoDB.centerSize = size
                ns.ApplySize()
                CloseDropDownMenus()
            end,
        })
    end
    tinsert(menu, { text = "Card size", hasArrow = true, notCheckable = true, menuList = cardSizes })
    tinsert(menu, { text = "Font", hasArrow = true, notCheckable = true, menuList = FontMenu() })
    tinsert(menu, { text = "Cooldown text size", hasArrow = true, notCheckable = true, menuList = SizeMenu("cooldownTextSize") })
    tinsert(menu, { text = "Label text size", hasArrow = true, notCheckable = true, menuList = SizeMenu("labelSize") })
    tinsert(menu, { text = "Spell name size", hasArrow = true, notCheckable = true, menuList = SizeMenu("nameSize") })

    EasyMenu(menu, ns.menuFrame, "cursor", 0, 0, "MENU")
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
end

-- Locked: click-through, so targets behind the frame stay selectable.
-- Unlocked: the frame takes the mouse; left-drag moves it, right-click opens the menu.
function ns.SetLocked(locked)
    ns.unlocked = not locked
    ns.frame:EnableMouse(not locked)
    if locked then CloseDropDownMenus() end
    if ns.CheckVisibility then ns.CheckVisibility() end
end

-- Main -------------------------------------------------------------------

function ns.CreateUI()
    local f = CreateFrame("Frame", "RotatoFrame", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(false) -- locked by default, see ns.SetLocked
    f:RegisterForDrag("LeftButton")
    SkinPanel(f)
    ns.frame = f
    ns.guideV, ns.guideH = CreateGuides()

    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and ns.unlocked then ns.OpenMenu() end
    end)

    -- big "next spell" icon, spanning both rows
    local center = CreateSlot(f, true)
    center:SetPoint("CENTER", f, "CENTER")
    ns.center = center

    ns.defensives = BuildRow(f, center, "LEFT", "BOTTOM")
    ns.utility    = BuildRow(f, center, "LEFT", "TOP")
    ns.trackers   = BuildRow(f, center, "RIGHT", "TOP")
    ns.offensives = BuildRow(f, center, "RIGHT", "BOTTOM")

    ns.ApplySize()
    ns.ApplyPosition()
    ns.InitVisibility()
end
