local ADDON_NAME, ns = ...

-- The window that asks which rotation to use when several are on offer, see Rotation.lua.
-- Escape closes it; the rotation already in use stays in that case.

local CELL_W, CELL_H, ICON, GAP, PADDING, COLUMNS = 90, 92, 48, 8, 20, 3
local TITLE_H = 24

local frame

-- ElvUI is looked up when the window is built, not at load: it loads after us. Without it the
-- default dialog look is kept. Guarded on the methods, as in UI.lua, since ElvUI adds them at its own pace.
local function Skins()
    local E = ElvUI and ElvUI[1]
    local skins = E and E.GetModule and E:GetModule("Skins", true)
    return E, skins and skins.HandleButton and skins
end

local function Build()
    frame = CreateFrame("Frame", "RotatoPicker", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    if frame.SetTemplate and Skins() then
        frame:SetTemplate("Transparent")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    frame:EnableMouse(true)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -PADDING + 4)
    frame.title:SetText("Rotato: choose a rotation")
    frame.buttons = {}
    tinsert(UISpecialFrames, "RotatoPicker")
    frame:Hide()
end

local function BuildCell()
    local cell = CreateFrame("Button", nil, frame)
    cell:SetSize(CELL_W, CELL_H)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON, ICON)
    cell.icon:SetPoint("TOP", 0, -6)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.border = cell:CreateTexture(nil, "OVERLAY")
    cell.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    cell.border:SetBlendMode("ADD")
    cell.border:SetSize(ICON * 1.9, ICON * 1.9)
    cell.border:SetPoint("CENTER", cell.icon, "CENTER")
    cell.border:SetVertexColor(1, 0.82, 0)
    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.label:SetPoint("TOP", cell.icon, "BOTTOM", 0, -6)
    cell.label:SetWidth(CELL_W - 6)
    cell.label:SetHeight(26)
    cell.label:SetJustifyV("TOP")
    cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cell:GetHighlightTexture():SetAllPoints(cell.icon)
    return cell
end

-- selected is the rotation in use, marked with a gold ring; onPick(def) runs for whichever is chosen.
function ns.ShowPicker(list, selected, onPick)
    if not frame then Build() end
    local columns = math.min(#list, COLUMNS)
    local rows = math.ceil(#list / columns)
    for i, def in ipairs(list) do
        local cell = frame.buttons[i]
        if not cell then cell = BuildCell(); frame.buttons[i] = cell end
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + col * (CELL_W + GAP), -(PADDING + TITLE_H + row * (CELL_H + GAP)))
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
    frame:SetWidth(2 * PADDING + columns * CELL_W + (columns - 1) * GAP)
    frame:SetHeight(2 * PADDING + TITLE_H + rows * CELL_H + (rows - 1) * GAP)
    frame:Show()
end

function ns.HidePicker()
    if frame then frame:Hide() end
end
