--// Example: load Cosmetic Changer, hotkey toggle, API calls
--// Run after your library (so getgenv().Library exists), or alone (falls back to preset theme).

local UIS = game:GetService("UserInputService")

-- load: always fresh from github (cache-bust), local readfile only as offline fallback
local CC
do
    local src
    local okHttp, fetched = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/beluvgawa-358/library/main/.github/workflows/cosmetic_changer.lua?cb=" .. os.time())
    end)
    if okHttp and fetched and #fetched > 100 then
        src = fetched
    else
        local okFile, content = pcall(readfile, "cosmetic_changer.lua")
        if okFile and content then src = content end
    end
    if not src then
        warn("[Example] could not load cosmetic_changer.lua")
        return
    end
    local chunk, err = loadstring(src)
    if not chunk then
        -- show the bad line if we can
        local line = err and err:match(":(%d+):")
        if line then
            local n = tonumber(line)
            local lines = src:gsub("\r\n", "\n"):split("\n")
            warn("[Example] syntax error line ", line, ": ", (lines[n] or "?"):sub(1, 200))
        end
        warn("[Example] syntax error: ", err)
        return
    end
    CC = chunk()
end

if not CC then
    warn("[Example] CosmeticChanger not returned")
    return
end

-- ---------------------------------------------------------------
-- API
-- ---------------------------------------------------------------
-- CC:SetOpen(true|false)  show/hide
-- CC:Refresh()            re-scan weapons/skins/emotes
-- CC:Destroy()            teardown

-- backend helpers (same getgenv contract as UnlockSuite)
local function applySwordSkin(name)
    getgenv().skinChanger = true
    getgenv().swordModel = name
    getgenv().swordAnimations = name
    getgenv().swordFX = name
    if getgenv().updateSword then getgenv().updateSword() end
    if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(true) end
end

local function applyExplosion(name)
    getgenv().explosionChanger = true
    getgenv().explosionFX = name
    if getgenv().setExplosionChanger then
        getgenv().setExplosionChanger(name)
    elseif getgenv().updateExplosion then
        getgenv().updateExplosion()
    end
    if getgenv().setExplosionChangerToggleUI then
        getgenv().setExplosionChangerToggleUI(true)
    end
end

local function playEmote(name)
    getgenv().selectedEmote = name
    if getgenv().playEmote then
        pcall(getgenv().playEmote, name)
    end
end

local function resetAll()
    getgenv().skinChanger = false
    getgenv().explosionChanger = false
    getgenv().swordModel = ""
    getgenv().swordAnimations = ""
    getgenv().swordFX = ""
    getgenv().explosionFX = ""
    if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(false) end
    if getgenv().setExplosionChangerToggleUI then getgenv().setExplosionChangerToggleUI(false) end
end

-- uncomment to test:
-- applySwordSkin("Default")
-- applyExplosion("Default")
-- playEmote("Dance")
-- resetAll()

-- ---------------------------------------------------------------
-- hotkey: RightShift toggles the window
-- ---------------------------------------------------------------
local open = true
CC:SetOpen(true)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        open = not open
        CC:SetOpen(open)
    end
end)

print("[Example] CosmeticChanger ready — RShift toggles, right-click weapons in UI to toggle skinchanger")
