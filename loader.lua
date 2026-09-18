local LOADER_NAME    = "Main Loader"
local LOADER_VERSION = "1.0.0"

local GAMES = {
    [124216119978534] = {
        name = "Ride A Pet",
        url  = "https://raw.githubusercontent.com/doitdiscord-rgb/main/refs/heads/main/rideapet.luau",
    },
    [113290951185459] = {
        name = "Anime Dice",
        url  = "https://lua.services/api/scripts/900a77b1dcbe354b5ab7aef9862abf57/loader",
    },
}

local PERSIST_ON_TELEPORT = true
local LOADER_URL = nil
local FETCH_ATTEMPTS = 3
local RETRY_DELAY    = 1
local Players       = game:GetService("Players")
local StarterGui    = game:GetService("StarterGui")
local HttpService   = game:GetService("HttpService")

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = duration or 5,
        })
    end)
    print(("[%s] %s: %s"):format(LOADER_NAME, title, text))
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end

    local request = (syn and syn.request) or (http and http.request) or http_request or request
    if request then
        local ok2, res = pcall(request, { Url = url, Method = "GET" })
        if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
            return res.Body
        end
    end

    return nil, tostring(body)
end

local function fetchWithRetry(url)
    local lastErr
    for attempt = 1, FETCH_ATTEMPTS do
        local body, err = httpGet(url)
        if body then
            return body
        end
        lastErr = err
        if attempt < FETCH_ATTEMPTS then
            warn(("[%s] Download failed (attempt %d/%d): %s")
                :format(LOADER_NAME, attempt, FETCH_ATTEMPTS, tostring(err)))
            task.wait(RETRY_DELAY)
        end
    end
    return nil, lastErr
end

if getgenv then
    if getgenv().__MAIN_LOADER_RUNNING then
        notify(LOADER_NAME, "Already running in this session.", 4)
        return
    end
    getgenv().__MAIN_LOADER_RUNNING = true
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

repeat task.wait() until Players.LocalPlayer

if PERSIST_ON_TELEPORT and LOADER_URL and queue_on_teleport then
    pcall(function()
        queue_on_teleport(([[
            loadstring(game:HttpGet("%s"))()
        ]]):format(LOADER_URL))
    end)
end

local placeId = game.PlaceId
local entry   = GAMES[placeId]

if not entry then
    local supported = {}
    for id, g in pairs(GAMES) do
        table.insert(supported, ("  - %s (%d)"):format(g.name, id))
    end
    table.sort(supported)

    notify(LOADER_NAME, ("Unsupported game. PlaceId: %d"):format(placeId), 8)
    warn(("[%s] This game is not supported.\nCurrent PlaceId: %d\nSupported games:\n%s")
        :format(LOADER_NAME, placeId, table.concat(supported, "\n")))

    if setclipboard then
        pcall(setclipboard, tostring(placeId))
        print(("[%s] PlaceId copied to clipboard."):format(LOADER_NAME))
    end

    if getgenv then
        getgenv().__MAIN_LOADER_RUNNING = nil
    end
    return
end

notify(LOADER_NAME, ("Loading %s..."):format(entry.name), 4)

local source, fetchErr = fetchWithRetry(entry.url)
if not source then
    notify(LOADER_NAME, ("Failed to download %s."):format(entry.name), 8)
    warn(("[%s] Download error: %s"):format(LOADER_NAME, tostring(fetchErr)))
    if getgenv then
        getgenv().__MAIN_LOADER_RUNNING = nil
    end
    return
end

local chunk, compileErr = loadstring(source, "=" .. entry.name)
if not chunk then
    notify(LOADER_NAME, ("Failed to compile %s."):format(entry.name), 8)
    warn(("[%s] Compile error: %s"):format(LOADER_NAME, tostring(compileErr)))
    if getgenv then
        getgenv().__MAIN_LOADER_RUNNING = nil
    end
    return
end

local ok, runErr = pcall(chunk)
if not ok then
    notify(LOADER_NAME, ("%s errored while running."):format(entry.name), 8)
    warn(("[%s] Runtime error: %s"):format(LOADER_NAME, tostring(runErr)))
    if getgenv then
        getgenv().__MAIN_LOADER_RUNNING = nil
    end
    return
end

notify(LOADER_NAME, ("%s loaded. (v%s)"):format(entry.name, LOADER_VERSION), 4)
