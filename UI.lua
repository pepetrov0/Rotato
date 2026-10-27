local ADDON_NAME, ns = ...

-- The frame itself: skinning, layout, sizing, dragging and the right-click menu.
--
-- Layout (the big icon is the suggestion, each side has two rows of up to MAX_PER_ROW small slots):
--   utility    (left, top)    | center | trackers   (right, top)
--   defensives (left, bottom) | center | offensives (right, bottom)
-- The left block grows right to left and the right block left to right, so slot 1 of every row
-- is always the one touching the center icon.

local SPACING = 2
local PADDING = 6
-- All the slots are built once and the setting only decides how many of them are used, so changing
-- it needs no rebuild. The panel width follows the setting, not this maximum.
local MAX_PER_ROW = 10
local SNAP = 20 -- distance in pixels from a screen center line at which dragging locks onto it

-- The tooltip look is the fallback when ElvUI is not installed, so the panel still matches the
-- default UI instead of looking like a bare rectangle.
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

-- ElvUI's engine table; nil when it is not loaded
local E = ElvUI and ElvUI[1]

-- Skinning ---------------------------------------------------------------
-- Both paths are guarded on SetTemplate rather than on E alone: ElvUI adds it to frames at its own
-- pace, and a missing method would otherwise error at login.

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
        f.icon:SetTexCoord(unpack(E.TexCoords)) -- crop the icon border ElvUI hides under its own
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

-- The fill is the only part made see-through; the border stays so the panel is still findable
-- at 100%. The base color is read back from whatever skin was applied (ElvUI's own, or ours) and
-- only its alpha is replaced, so the tint still follows the user's theme.
function ns.ApplyBackground()
    local r, g, b = unpack(ns.panelColor)
    ns.frame:SetBackdropColor(r, g, b, 1 - RotatoDB.backgroundTransparency / 100)
end

-- Slots --------------------------------------------------------------------

local function SetSlotSize(f, size)
    f:SetWidth(size)
    f:SetHeight(size)
end

-- Only the center box is skinned. The small slots are bare icons because an empty bordered square
-- in every unused position looked cluttered; the borders they get are meaningful (Slots.lua).
local function CreateSlot(parent, boxed)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    if boxed then
        SkinSlot(f)
    else
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trims the border baked into spell icons
    end
    return f
end

-- Each slot is anchored to the previous one (not to the frame), so resizing only needs the slot
-- sizes to change and the row follows by itself.
-- side: "LEFT" grows right to left, "RIGHT" grows left to right.
-- vertical: "TOP" or "BOTTOM".
local function BuildRow(parent, center, side, vertical)
    local row = {}
    local inner = side == "LEFT" and "RIGHT" or "LEFT" -- the slot edge facing the center
    local outer = side == "LEFT" and "LEFT" or "RIGHT" -- the slot edge facing away
    local sign = side == "LEFT" and -1 or 1
    for i = 1, MAX_PER_ROW do
        local slot = CreateSlot(parent)
        if i == 1 then
            -- the first slot lines up with the matching corner of the center icon
            slot:SetPoint(vertical .. inner, center, vertical .. outer, sign * SPACING, 0)
        else
            slot:SetPoint(inner, row[i - 1], outer, sign * SPACING, 0)
        end
        row[i] = slot
    end
    return row
end

-- Sizing -----------------------------------------------------------------

-- The center size is the only size setting. Two small icons plus the gap between them stack to
-- exactly the center's height, which is what keeps the two rows aligned with it.
function ns.ApplySize()
    local center = RotatoDB.centerSize
    local small = (center - SPACING) / 2
    SetSlotSize(ns.center, center)
    for _, row in ipairs({ ns.defensives, ns.utility, ns.trackers, ns.offensives }) do
        for _, slot in ipairs(row) do SetSlotSize(slot, small) end
    end
    ns.frame:SetWidth(center + 2 * RotatoDB.slotsPerRow * (small + SPACING) + 2 * PADDING)
    ns.frame:SetHeight(center + 2 * PADDING)
end

-- Context menu -------------------------------------------------------------

-- Even sizes only: the small icons are half of this minus the gap, so odd values would give
-- fractional pixels and a blurry edge.
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

-- The menus are rebuilt on every open so the checkmarks always reflect the saved state.
local function FontMenu()
    -- a nil path means "follow the client's combat text font", see ns.ApplyFonts
    local list = { { "Combat text (default)", nil } }
    for _, font in ipairs(BUILTIN_FONTS) do list[#list + 1] = font end
    -- ElvUI and most addon packs ship LibSharedMedia, which is where users' extra fonts live
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

local SLOT_COUNTS = { 3, 4, 5, 6, 7, 8, 9, 10 }

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
    tinsert(menu, { text = "Size", hasArrow = true, notCheckable = true, menuList = cardSizes })

    local counts = {}
    for _, count in ipairs(SLOT_COUNTS) do
        tinsert(counts, {
            text = tostring(count),
            checked = RotatoDB.slotsPerRow == count,
            func = function()
                RotatoDB.slotsPerRow = count
                ns.ApplySize()
                CloseDropDownMenus()
            end,
        })
    end
    tinsert(menu, { text = "Buffs shown per row", hasArrow = true, notCheckable = true, menuList = counts })

    local transparencies = {}
    for percent = 0, 100, 10 do
        tinsert(transparencies, {
            text = percent .. "%",
            checked = RotatoDB.backgroundTransparency == percent,
            func = function()
                RotatoDB.backgroundTransparency = percent
                ns.ApplyBackground()
                CloseDropDownMenus()
            end,
        })
    end
    tinsert(menu, { text = "Background transparency", hasArrow = true, notCheckable = true,
        menuList = transparencies })
    tinsert(menu, { text = "Font", hasArrow = true, notCheckable = true, menuList = FontMenu() })
    tinsert(menu, { text = "Cooldown text size", hasArrow = true, notCheckable = true,
        menuList = SizeMenu("cooldownTextSize") })
    tinsert(menu, { text = "Label text size", hasArrow = true, notCheckable = true,
        menuList = SizeMenu("labelSize") })
    tinsert(menu, { text = "Spell name size", hasArrow = true, notCheckable = true,
        menuList = SizeMenu("nameSize") })

    tinsert(menu, { text = "Lock", notCheckable = true, func = function()
        ns.SetLocked(true)
        ns.Print("locked.")
    end })

    EasyMenu(menu, ns.menuFrame, "cursor", 0, 0, "MENU")
end

-- Positioning ------------------------------------------------------------

-- The position is stored as an offset from the screen center, not from a corner, so it survives
-- a change of resolution or UI scale and the center snap stays meaningful.
function ns.ApplyPosition()
    local p = RotatoDB.pos
    ns.frame:ClearAllPoints()
    ns.frame:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
end

-- Dragging is done by hand instead of with StartMoving: the built-in version follows the cursor
-- with no hook to snap while moving, and we want the frame to lock onto the center lines live.
-- The guide lines show where those lines are and turn green when locked on.
local function CreateGuides()
    local vertical = UIParent:CreateTexture(nil, "OVERLAY")
    vertical:SetTexture(1, 1, 1, 0.5)
    vertical:SetWidth(1)
    vertical:SetPoint("TOP", UIParent, "TOP")
    vertical:SetPoint("BOTTOM", UIParent, "BOTTOM")
    vertical:Hide()

    local horizontal = UIParent:CreateTexture(nil, "OVERLAY")
    horizontal:SetTexture(1, 1, 1, 0.5)
    horizontal:SetHeight(1)
    horizontal:SetPoint("LEFT", UIParent, "LEFT")
    horizontal:SetPoint("RIGHT", UIParent, "RIGHT")
    horizontal:Hide()

    return vertical, horizontal
end

local function DragUpdate(f)
    -- the cursor position is in screen pixels; dividing by UIParent's scale converts it to the
    -- same units GetCenter uses
    local ux, uy = UIParent:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local x = mx / scale - ux + f.dragOffX
    local y = my / scale - uy + f.dragOffY

    local snapX, snapY = math.abs(x) < SNAP, math.abs(y) < SNAP
    if snapX then x = 0 end
    if snapY then y = 0 end

    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    f.pos = { x = x, y = y } -- saved on release, not on every frame

    ns.guideV:SetTexture(snapX and 0 or 1, 1, snapX and 0 or 1, snapX and 0.9 or 0.5)
    ns.guideH:SetTexture(snapY and 0 or 1, 1, snapY and 0 or 1, snapY and 0.9 or 0.5)
end

local function DragStart(f)
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    -- remember where inside the frame it was grabbed, so it does not jump to center on the cursor
    f.dragOffX = (cx - ux) - (mx / scale - ux)
    f.dragOffY = (cy - uy) - (my / scale - uy)
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

-- Locked means click-through: the frame sits over the playfield, and a mouse-enabled frame would
-- swallow clicks and camera turns meant for the world behind it. Only unlocking takes the mouse.
function ns.SetLocked(locked)
    ns.unlocked = not locked
    ns.frame:EnableMouse(not locked)
    if locked then CloseDropDownMenus() end
    if ns.CheckVisibility then ns.CheckVisibility() end -- an unlocked frame must be visible
end

-- Frame creation ----------------------------------------------------------

function ns.CreateUI()
    local f = CreateFrame("Frame", "RotatoFrame", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true) -- so a bad saved position can never lose the frame off screen
    f:EnableMouse(false)       -- starts locked, see ns.SetLocked
    f:RegisterForDrag("LeftButton")
    SkinPanel(f)
    ns.frame = f
    ns.panelColor = { f:GetBackdropColor() }
    if #ns.panelColor < 3 then ns.panelColor = { 0, 0, 0 } end -- a skin that sets no backdrop color
    ns.guideV, ns.guideH = CreateGuides()

    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and ns.unlocked then ns.OpenMenu() end
    end)

    -- the suggestion, spanning both side rows
    local center = CreateSlot(f, true)
    center:SetPoint("CENTER", f, "CENTER")
    ns.center = center

    ns.defensives = BuildRow(f, center, "LEFT", "BOTTOM")
    ns.utility    = BuildRow(f, center, "LEFT", "TOP")
    ns.trackers   = BuildRow(f, center, "RIGHT", "TOP")
    ns.offensives = BuildRow(f, center, "RIGHT", "BOTTOM")

    ns.ApplySize()
    ns.ApplyPosition()
    ns.ApplyBackground()
    ns.InitVisibility()
end
