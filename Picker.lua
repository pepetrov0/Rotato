local ADDON_NAME, ns = ...

-- The window that asks which rotation to use when several are on offer, see Rotation.lua.
-- Escape closes it; the rotation already in use stays in that case.

local ROW_HEIGHT, PADDING, WIDTH = 26, 24, 260

local frame

local function Build()
    frame = CreateFrame("Frame", "RotatoPicker", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(WIDTH)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:EnableMouse(true)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -PADDING)
    frame.title:SetText("Rotato: choose a rotation")
    frame.buttons = {}
    tinsert(UISpecialFrames, "RotatoPicker")
    frame:Hide()
end

-- selected is the rotation in use, its button is disabled; onPick(def) runs when another is chosen.
function ns.ShowPicker(list, selected, onPick)
    if not frame then Build() end
    for i, def in ipairs(list) do
        local button = frame.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            button:SetSize(WIDTH - 2 * PADDING, ROW_HEIGHT - 2)
            button:SetPoint("TOP", frame.title, "BOTTOM", 0, -8 - (i - 1) * ROW_HEIGHT)
            frame.buttons[i] = button
        end
        button:SetText(def.name)
        if def == selected then button:Disable() else button:Enable() end
        button:SetScript("OnClick", function()
            onPick(def)
            frame:Hide()
        end)
        button:Show()
    end
    for i = #list + 1, #frame.buttons do frame.buttons[i]:Hide() end
    frame:SetHeight(2 * PADDING + 16 + #list * ROW_HEIGHT)
    frame:Show()
end

function ns.HidePicker()
    if frame then frame:Hide() end
end
