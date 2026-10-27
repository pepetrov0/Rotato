local ADDON_NAME, ns = ...

-- Core: saved variables, shared text styling, the rotation mode and the slash command.
-- Everything else hangs off the `ns` table that the client hands to every file of the addon.

local defaults = {
    pos = { x = 0, y = -200 }, -- offset from the screen center
    centerSize = 70,           -- the small icons are derived from this, see ns.ApplySize

    font = nil,                -- nil follows the client's combat text font
    cooldownTextSize = 12,
    labelSize = 12,
    nameSize = 16,

    slotsPerRow = 5, -- how many entries each side row shows, 3 to 10
    dynamicWidth = true,  -- size each side to its longest row (slotsPerRow is then the maximum)
    symmetric = true,     -- with dynamicWidth, keep both sides as wide as the widest one
    backgroundTransparency = 50, -- percent; 0 is opaque, 100 is invisible
    chatLog = true,       -- report automatic changes (showing, hiding, mode...) in chat, see ns.Log

}

-- Text styling ---------------------------------------------------------
-- Every FontString registers here instead of calling SetFont itself, so changing the font or a
-- size in the menu restyles all of them at once.

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local SIZE_KEY = { label = "labelSize", name = "nameSize", time = "cooldownTextSize" }
local texts = {}

function ns.ApplyFonts()
    -- ElvUI replaces DAMAGE_TEXT_FONT with the font chosen in its options, so reading it at
    -- apply time (not load time) keeps us consistent with the rest of the user's UI.
    local font = RotatoDB.font or DAMAGE_TEXT_FONT or FALLBACK_FONT
    for _, text in ipairs(texts) do
        text[1]:SetFont(font, RotatoDB[SIZE_KEY[text[2]]], "OUTLINE")
    end
end

-- kind: "label", "name" or "time" (the cooldown numbers); it selects which saved size applies.
function ns.RegisterText(fontString, kind)
    texts[#texts + 1] = { fontString, kind }
    -- a FontString errors on SetText until it has a font, so style it immediately
    ns.ApplyFonts()
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Rotato|r: " .. tostring(msg))
end

-- For changes the addon makes on its own; these can be frequent, so the player can turn them off.
-- Replies to commands and errors use ns.Print and are always shown.
function ns.Log(msg)
    if RotatoDB.chatLog then ns.Print(msg) end
end

-- Rotation mode ----------------------------------------------------------
-- The order matters: when a cast belongs to several modes, the first one listed wins (Mode.lua).
-- The mode is deliberately not saved. It follows what the player is doing right now, and a stale
-- "aoe" from the previous session would just be wrong on login.

ns.MODES = { "single", "multi", "aoe" }
ns.mode = "single"

local MODE_LABEL = { single = "Single", multi = "Multi-target", aoe = "AoE" }

function ns.SetMode(mode, reason)
    if ns.mode == mode then return end -- stay quiet when nothing changes, this is called on every cast
    ns.mode = mode
    ns.Log(MODE_LABEL[mode] .. " rotation" .. (reason and (" (" .. reason .. ")") or ""))
end

-- Startup ----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        RotatoDB = RotatoDB or {}
        -- fill in only what is missing, so settings added in later versions get their defaults
        for key, value in pairs(defaults) do
            if RotatoDB[key] == nil then RotatoDB[key] = value end
        end
    elseif event == "PLAYER_LOGIN" then
        -- Build the UI at login, not at load: ElvUI loads after us, and skinning has to see it.
        -- The order below matters too, each step uses the frames of the ones before it.
        ns.CreateUI()
        ns.InitClass()
        ns.InitMode()
        ns.InitDisplay()
        ns.InitSlots()
        ns.InitTooltips()
        ns.Print("loaded. /rotato unlock to move or resize, /rotato lock when done.")
    end
end)

-- Slash command ------------------------------------------------------------

SLASH_ROTATO1 = "/rotato"
SLASH_ROTATO2 = "/rota"

SlashCmdList["ROTATO"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "unlock" then
        ns.SetLocked(false)
        ns.Print("unlocked. Left-drag to move, right-click for options. /rotato lock when done.")
    elseif msg == "lock" then
        ns.SetLocked(true)
        ns.Print("locked.")
    elseif msg == "spec" then
        ns.DumpSpec()
    elseif msg == "debug" then
        ns.DebugEvaluate()
    elseif msg == "log" then
        RotatoDB.chatLog = not RotatoDB.chatLog
        ns.Print("chat log " .. (RotatoDB.chatLog and "on." or "off."))
    elseif msg == "reset" then
        -- copy the table: assigning defaults.pos itself would let later drags edit the defaults
        RotatoDB.pos = { x = defaults.pos.x, y = defaults.pos.y }
        ns.ApplyPosition()
    else
        ns.Print("Usage: /rotato unlock | lock | reset | log | spec | debug")
    end
end
