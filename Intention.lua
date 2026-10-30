local ADDON_NAME, ns = ...

-- Asks which direction (talent tree) the player is building toward while no talent points are
-- spent, because then the game cannot name a spec and Rotation.lua has nothing to look up. The
-- answer is kept per character and only selects the spec whose rotation is shown; the detected
-- spec takes over as soon as its rotation is unlocked. /rotato rotation reopens the question.

local FRAME_NAME = "RotatoIntention"
local WIDTH = 320
local PADDING = 16
local BUTTON_HEIGHT = 24
local BUTTON_GAP = 6
local TEXT_HEIGHT = 34
local HEADER_HEIGHT = 136 -- top padding, title, text and the gaps above the options

local frame
local asked, pending = false, false

local function Create()
    if frame then return frame end

    local f = CreateFrame("Frame", FRAME_NAME, UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetWidth(WIDTH)
    f:EnableMouse(true)
    f:Hide()
    ns.SkinPanel(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("|cff33ff99Rotato|r")

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", title, "BOTTOM", 0, -8)
    text:SetWidth(WIDTH - 2 * PADDING)
    text:SetHeight(TEXT_HEIGHT)
    text:SetJustifyH("CENTER")
    text:SetText("Your talents do not pick a spec yet. Which direction are you building toward?")
    f.text = text

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    local skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skip:SetSize(WIDTH - 2 * PADDING, BUTTON_HEIGHT)
    skip:SetText("Not now")
    skip:SetScript("OnClick", function() f:Hide() end)
    f.skip = skip

    f.buttons = {}
    tinsert(UISpecialFrames, FRAME_NAME) -- Escape closes it
    frame = f
    return f
end

local function Show()
    local f = Create()
    local options = ns.RotationOptions()
    -- mark the direction whose rotation is actually shown: the talents win once their pick is
    -- unlocked, and while they are ambiguous the picked direction is the one standing in
    local rotation = ns.GetRotation()
    local current = (rotation and rotation.spec) or ns.specIndex or ns.GetIntention()

    for i, option in ipairs(options) do
        local button = f.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            button:SetSize(WIDTH - 2 * PADDING, BUTTON_HEIGHT)
            f.buttons[i] = button
        end
        button:SetText(option.label .. (option.spec == current and " (current)" or ""))
        button:ClearAllPoints()
        if i == 1 then
            button:SetPoint("TOP", f.text, "BOTTOM", 0, -12)
        else
            button:SetPoint("TOP", f.buttons[i - 1], "BOTTOM", 0, -BUTTON_GAP)
        end
        button.spec = option.spec
        button:SetScript("OnClick", function(self)
            ns.SetIntention(self.spec)
            f:Hide()
            ns.Print("Direction set to " .. ns.SpecLabel(self.spec) .. ".")
            if ns.CheckVisibility then ns.CheckVisibility() end
        end)
        button:Show()
    end
    for i = #options + 1, #f.buttons do f.buttons[i]:Hide() end

    local last = #options > 0 and f.buttons[#options] or f.text
    f.skip:ClearAllPoints()
    f.skip:SetPoint("TOP", last, "BOTTOM", 0, -12)
    f:SetHeight(HEADER_HEIGHT + #options * BUTTON_HEIGHT + math.max(0, #options - 1) * BUTTON_GAP)

    f:Show()
    f:Raise()
end

-- Asks once per session, when the talents have no answer, no direction is picked and there is
-- actually a choice. A class with a single direction needs no question: Rotation.lua uses it.
function ns.PromptIntention()
    if asked or ns.specIndex or not ns.class then return end
    if ns.GetIntention() then return end
    if #ns.RotationOptions() < 2 then return end
    if UnitAffectingCombat("player") then pending = true; return end
    asked = true
    Show()
end

-- /rotato rotation: change the direction. It does nothing once the talents pick a spec whose
-- rotation is unlocked, so say so instead of showing a choice that cannot take effect.
function ns.OpenIntention()
    if not ns.class then ns.Print("Class not detected yet."); return end
    if #ns.RotationOptions() == 0 then ns.Print("No rotations for this class yet."); return end
    local rotation = ns.GetRotation()
    if ns.specIndex and rotation and rotation.spec == ns.specIndex then
        ns.Print("Your talents pick " .. ns.SpecLabel(ns.specIndex) .. ".")
        return
    end
    asked = true
    Show()
end

function ns.CloseIntention()
    if frame then frame:Hide() end
end

-- A question asked in combat would cover the screen at the worst moment; hold it until the fight
-- ends. A talent reset cannot happen in combat, but logging in during one fires the same report.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function()
    if pending then
        pending = false
        ns.PromptIntention()
    end
end)
