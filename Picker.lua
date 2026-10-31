local ADDON_NAME, ns = ...

-- The window that asks which rotation to use when several are on offer, see Rotation.lua.
-- Escape closes it; the rotation already in use stays in that case.

local CELL_W, CELL_H, ICON, GAP, PADDING, COLUMNS = 100, 100, 40, 10, 14, 3
local HEADER_H = 78

local frame

-- ElvUI is looked up when the window is built, not at load: it loads after us. Without it the
-- default look is kept. Guarded on the methods, as in UI.lua, since ElvUI adds them at its own pace.
local function Skins()
    local E = ElvUI and ElvUI[1]
    local skins = E and E.GetModule and E:GetModule("Skins", true)
    return E, skins and skins.HandleButton and skins
end

local function Build()
    local E, skins = Skins()
    frame = CreateFrame("Frame", "RotatoPicker", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    if frame.SetTemplate and skins then
        frame:SetTemplate("Transparent")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
    end
    frame:EnableMouse(true)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -PADDING)
    frame.title:SetText("|cff33ff99Rotato|r")
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)
    frame.subtitle:SetText("Choose your playstyle and I will guide your rotation, or go your own way.")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -2, -2)
    if skins and skins.HandleCloseButton then skins:HandleCloseButton(frame.close) end

    -- drag it anywhere; the spot is remembered and then used instead of the automatic one
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        RotatoDB.pickerPos = { point, relPoint, x, y }
    end)

    frame.buttons = {}
    tinsert(UISpecialFrames, "RotatoPicker")
    frame:Hide()
end

-- One card per rotation: a button with the spec icon and the name under it.
local function BuildCell()
    local E, skins = Skins()
    local cell = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cell:SetSize(CELL_W, CELL_H)
    cell.icon = cell:CreateTexture(nil, "OVERLAY")
    cell.icon:SetSize(ICON, ICON)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.label:SetPoint("TOP", cell.icon, "BOTTOM", 0, -6)
    cell.label:SetWidth(CELL_W - 10)
    cell.label:SetJustifyH("CENTER")
    if skins then
        skins:HandleButton(cell)
        if E.TexCoords then cell.icon:SetTexCoord(unpack(E.TexCoords)) end
    end
    return cell
end

-- The lowest dialog-level frame overlapping ours. Full-screen containers are skipped by size.
local function FindBlocker()
    local top, bottom, left, right = frame:GetTop(), frame:GetBottom(), frame:GetLeft(), frame:GetRight()
    if not top then return end
    local found, foundBottom
    for _, f in ipairs({ UIParent:GetChildren() }) do
        local strata = f ~= frame and f:IsShown() and f:GetFrameStrata()
        if strata == "DIALOG" or strata == "FULLSCREEN_DIALOG" then
            local t, b, l, r = f:GetTop(), f:GetBottom(), f:GetLeft(), f:GetRight()
            if t and b and l and r and (r - l) < UIParent:GetWidth() / 2 and (t - b) < UIParent:GetHeight() / 2
                and l < right and r > left and b < top and t > bottom
                and (not foundBottom or b < foundBottom) then
                found, foundBottom = f, b
            end
        end
    end
    return found
end

-- selected is the rotation in use; it is not marked. onPick(def) runs for whichever is chosen.
function ns.ShowPicker(list, selected, onPick)
    if not frame then Build() end
    local columns = math.min(#list, COLUMNS)
    local rows = math.ceil(#list / columns)
    local width = columns * CELL_W + (columns - 1) * GAP
    for i, def in ipairs(list) do
        local cell = frame.buttons[i]
        if not cell then cell = BuildCell(); frame.buttons[i] = cell end
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + col * (CELL_W + GAP), -(HEADER_H + row * (CELL_H + GAP)))
        cell.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        cell.label:SetText(def.name)
        -- icon and name are centred together as one block, whatever the number of name lines
        local block = ICON + 6 + cell.label:GetStringHeight()
        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("TOP", cell, "TOP", 0, -(CELL_H - block) / 2)
        cell:SetScript("OnClick", function()
            onPick(def)
            frame:Hide()
        end)
        cell:Show()
    end
    for i = #list + 1, #frame.buttons do frame.buttons[i]:Hide() end
    local frameWidth = math.max(width, 240) + 2 * PADDING
    frame.subtitle:SetWidth(frameWidth - 2 * PADDING)
    frame:SetSize(frameWidth, HEADER_H + rows * CELL_H + (rows - 1) * GAP + PADDING)
    -- a single row narrower than the dialog is centred in it
    if width < frameWidth - 2 * PADDING then
        local shift = (frameWidth - 2 * PADDING - width) / 2
        for i = 1, #list do
            local cell = frame.buttons[i]
            local _, _, _, x, y = cell:GetPoint()
            cell:SetPoint("TOPLEFT", frame, "TOPLEFT", x + shift, y)
        end
    end
    -- Other addons open dialogs at this same spot (Sage's picker does): sit below any that overlap
    frame:ClearAllPoints()
    local saved = RotatoDB.pickerPos
    if saved then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
        frame:Show()
        return
    end
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    frame:Show() -- a hidden frame may not report its rectangle
    local blocker = FindBlocker()
    if blocker then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", blocker, "BOTTOM", 0, -10)
    end
end

function ns.HidePicker()
    if frame then frame:Hide() end
end
