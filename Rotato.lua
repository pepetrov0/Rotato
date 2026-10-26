local ADDON_NAME, ns = ...

local defaults = {
    mode = "single", -- "single" | "aoe"
    pos = { x = 0, y = -200 }, -- offset from the screen center
    centerSize = 70, -- main icon size in pixels; the small icons derive from it
}

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Rotato|r: " .. tostring(msg))
end

-- Will be driven automatically by the addon later.
function ns.SetMode(mode)
    RotatoDB.mode = mode
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
    elseif msg == "reset" then
        RotatoDB.pos = { x = defaults.pos.x, y = defaults.pos.y }
        ns.ApplyPosition()
    else
        ns.Print("Usage: /rotato unlock | lock | reset")
    end
end
