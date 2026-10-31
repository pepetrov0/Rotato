local ADDON_NAME, ns = ...

-- The window that asks which rotation to use when several are on offer, see Rotation.lua.
-- Escape closes it; the rotation already in use stays in that case.

local CELL_W, CELL_H, ICON, GAP, PADDING, COLUMNS = 110, 100, 40, 10, 14, 3
local HEADER_H = 62

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
    frame.subtitle:SetText("Choose the rotation to follow.")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -2, -2)
    if skins and skins.HandleCloseButton then skins:HandleCloseButton(frame.close) end

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
    cell.icon:SetPoint("TOP", 0, -10)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.border = cell:CreateTexture(nil, "OVERLAY", nil, 1)
    cell.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    cell.border:SetBlendMode("ADD")
    cell.border:SetSize(ICON * 1.9, ICON * 1.9)
    cell.border:SetPoint("CENTER", cell.icon, "CENTER")
    cell.border:SetVertexColor(1, 0.82, 0)
    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.label:SetPoint("TOP", cell.icon, "BOTTOM", 0, -8)
    cell.label:SetWidth(CELL_W - 10)
    cell.label:SetHeight(28)
    cell.label:SetJustifyV("TOP")
    if skins then
        skins:HandleButton(cell)
        if E.TexCoords then cell.icon:SetTexCoord(unpack(E.TexCoords)) end
    end
    return cell
end

-- selected is the rotation in use, marked with a gold ring; onPick(def) runs for whichever is chosen.
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
        if def == selected then cell.border:Show() else cell.border:Hide() end
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
    frame:Show()
end

function ns.HidePicker()
    if frame then frame:Hide() end
end
