-- u should try in roblox studio :D

local HttpService: HttpService = game:GetService("HttpService")
local DISCORD_API_BASE: string = "https://discord.com/api/v9" 
local DISCORD_RPC_BASE: string = "http://127.0.0.1:6463/rpc?v=1"

export type DiscordInfoOptions = {
    isMemberCount: boolean,
    isGuild: boolean,
}

export type DiscordInviteResult = {
    code: string,
    onlineMemberCount: number?,
    totalMemberCount: number?,
    guild: {
        id: string,
        name: string,
        description: string?,
        icon: string?,
        banner: string?,
    }?
}

type HttpRequestOptions = {
    Url: string,
    Method: "GET" | "POST" | "PUT" | "DELETE" | "PATCH",
    Headers: {[string]: string}?,
    Body: string?,
    Compress: Enum.HttpCompression,
    Timeout: number?
}

type HttpResponse = {
    Success: boolean,
    StatusCode: number,
    StatusMessage: string,
    Headers: {[string]: string},
    Body: string
}

-- request, http_request function is only support rolox exploits
local _request = request or http_request or (http and http.request) or function(options: HttpRequestOptions)
    return HttpService:RequestAsync(options)
end

local DiscordModule = {}

local function makeHttpRequest(url: string, method: string, headers: {[string]: string}?, body: string?): HttpResponse?
    local success, response = pcall(function()
        return _request({
            Url = url,
            Method = method,
            Headers = headers or {
                ["Content-Type"] = "application/json"
            },
            Body = body
        })
    end)

    if not success then
        warn(`[DiscordModule] HTTP request failed to execute: {tostring(response)}`)
        return nil
    end

    return response :: HttpResponse
end

local function fetchInviteData(url: string)
    local inviteCode = url:match("[^/]+$") or url

    local response = makeHttpRequest(`{DISCORD_API_BASE}/invites/{inviteCode}?with_counts=true`, "GET")
    
    if not response then return nil end
    if not response.Success then
        warn(`[DiscordModule] Failed to fetch invite. Status: {response.StatusCode} - {response.StatusMessage}`)
        return nil
    end

    local decodeSuccess, decodedData = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if not decodeSuccess then
        warn("[DiscordModule] Failed to decode API response JSON.")
        return nil
    end

    return decodedData
end

local function fetchDiscordRPC(url: string)
	local inviteCode = url:match("[^/]+$") or url

	local response = makeHttpRequest(`{DISCORD_RPC_BASE}`, "POST", {
        ["Content-Type"] = "application/json",
        ["Origin"] = "https://discord.com"
    }, HttpService:JSONEncode({
        cmd = "INVITE_BROWSER",
        args = {
            code = inviteCode
        },
        nonce = HttpService:GenerateGUID(false)
    }))

    if not response then return false end
    if not response.Success then
        warn(`[DiscordModule] Failed to send RPC invite. Status: {response.StatusCode} - {response.StatusMessage}`)
        return false
    end

    return true
end

function DiscordModule.getInviteData(url: string, options: DiscordInfoOptions): DiscordInviteResult?
    assert(type(url) == "string", "Expected a string for 'url'")
    assert(type(options) == "table", "Expected a table for 'options'")

    local rawData = fetchInviteData(url)
    if not rawData or not rawData.code then 
        return nil 
    end

    local result: DiscordInviteResult = {
        code = rawData.code
    }

    if options.isMemberCount then
        result.onlineMemberCount = rawData.approximate_presence_count
        result.totalMemberCount = rawData.approximate_member_count
    end

    if options.isGuild and rawData.guild then
        result.guild = {
            id = rawData.guild.id,
            name = rawData.guild.name,
            description = rawData.guild.description,
            icon = rawData.guild.icon,
            banner = rawData.guild.banner
        }
    end

    return result
end

function DiscordModule.joinDiscordRPC(url: string)
    assert(type(url) == "string", "Expected a string for 'url'")

    return fetchDiscordRPC(url)
end

return DiscordModule
