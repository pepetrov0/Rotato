local ADDON_NAME, ns = ...

local defaults = {
    pos = { x = 0, y = -200 }, -- offset from the screen center
    cooldownTextSize = 12, -- font size of the countdown numbers on the side slots
    centerSize = 70, -- main icon size in pixels; the small icons derive from it
}

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Rotato|r: " .. tostring(msg))
end

-- Rotation modes in switch-priority order. Not saved: the mode always starts as single (see Mode.lua).
ns.MODES = { "single", "multi", "aoe" }
local MODE_LABEL = { single = "Single", multi = "Multi-target", aoe = "AoE" }
ns.mode = "single"

function ns.SetMode(mode, reason)
    if ns.mode == mode then return end
    ns.mode = mode
    ns.Print(MODE_LABEL[mode] .. " rotation" .. (reason and (" (" .. reason .. ")") or ""))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        RotatoDB = RotatoDB or {}
        for k, v in pairs(defaults) do
            if RotatoDB[k] == nil then RotatoDB[k] = v end
        end
    elseif event == "PLAYER_LOGIN" then
        -- everything else (ElvUI included) is loaded by now
        ns.CreateUI()
        ns.InitClass()
        ns.InitMode()
        ns.InitDisplay()
        ns.InitSlots()
        ns.Print("loaded. /rotato unlock to move or resize, /rotato lock when done.")
    end
end)

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
    elseif msg == "slots" then
        ns.DumpSlots()
    elseif msg == "debug" then
        ns.DebugEvaluate()
    elseif msg == "reset" then
        RotatoDB.pos = { x = defaults.pos.x, y = defaults.pos.y }
        ns.ApplyPosition()
    else
        ns.Print("Usage: /rotato unlock | lock | reset | spec | debug | slots")
    end
end
