-- GameJolt Game API v1.2 client. https://gamejolt.com/game-api/doc

local gamejolt = {}

local md5 = ImportFile("Utils.MD5")
local json = ImportFile("Utils.dkjson")
local https_ok, https_module = pcall(require, "https")
local https = https_ok and https_module or nil
local https_error = https_ok and nil or tostring(https_module)

gamejolt._session_auto = {
    enabled = false,
    interval = 30,
    status = "active",
    elapsed = 0,
    last_error = nil
}

-- Flipped to true only once the API has accepted a pair of credentials.
gamejolt._verified = false

local function nonEmpty(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

-- Tokens pasted out of a browser carry whitespace and the API rejects them verbatim.
local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

-- Unencoded spaces, "&" or "=" corrupt the URL and change what the server hashes.
local function urlencode(value)
    local text = tostring(value)
    return (text:gsub("\n", "\r\n"):gsub("([^%w%-%._~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

-- Shared credential fragment appended to every user-scoped endpoint.
local function userParams()
    return "&username=" .. urlencode(gamejolt.username) ..
           "&user_token=" .. urlencode(gamejolt.user_token)
end

local function requireConfig()
    if (gamejolt.app_id == nil or gamejolt.private_key == nil or gamejolt.base_url == nil) then
        return false, "GameJolt: call gamejolt.init(app_id, private_key) first"
    end
    return true
end

-- Without this, user-scoped endpoints raise while concatenating nil.
local function requireLogin()
    if (not gamejolt.isLoggedIn()) then
        return false, "GameJolt: not authenticated, call gamejolt.authUser(username, user_token) first"
    end
    return true
end

local function generateSignature(request_path)
    local input = gamejolt.base_url .. request_path .. gamejolt.private_key
    return md5.sumhexa(input)
end

-- Returns payload, or false, message, kind: "transport" (unreachable, bad HTTP
-- status, unparseable body) or "api" (the server explicitly refused).
local function apiRequest(path)
    if (not https or type(https.request) ~= "function") then
        local platform = (SE and SE.system and SE.system.getOS and SE.system.getOS()) or "Unknown"
        local reason = https_error or "missing native https module"
        return false, "GameJolt API unavailable on "..tostring(platform)..": "..reason, "transport"
    end

    local url = gamejolt.base_url .. path .. "&signature=" .. generateSignature(path)

    -- lua-https: returns code, body, headers; DNS / TLS failures may raise.
    local raised, code, body = pcall(https.request, url)
    if (not raised) then
        return false, "HTTPS request failed: "..tostring(code), "transport"
    end
    if (not code) then
        return false, "HTTPS request failed: "..tostring(body), "transport"
    end

    if (code ~= 200) then
        return false, "HTTP error: "..tostring(code), "transport"
    end

    local data, pos, err = json.decode(body)
    if (type(data) ~= "table") then
        return false, "JSON decode error: "..tostring(err).."\nResponse: "..tostring(body), "transport"
    end

    local payload = data.response
    if (type(payload) ~= "table") then
        return false, "Malformed response: missing response envelope", "transport"
    end

    -- GameJolt reports success as the string "true"/"false", not a boolean.
    if (payload.success == false or payload.success == "false") then
        return false, payload.message or "API error", "api"
    end

    return payload
end

local function sessionAutoTick(dt)
    local state = gamejolt._session_auto
    if (not state.enabled) then
        return
    end

    state.elapsed = state.elapsed + (tonumber(dt) or 0)
    if (state.elapsed < state.interval) then
        return
    end

    state.elapsed = 0
    local result, err, kind = gamejolt.sessionPing(state.status)
    if (result == nil or result == false) then
        state.last_error = err
        -- A refusal means the credentials stopped working: stop the heartbeat.
        if (kind == "api") then
            state.enabled = false
            gamejolt._verified = false
        end
    else
        state.last_error = nil
    end
end


---Initializes the GameJolt API with the provided app ID and private key.
---@param app_id number|string
---@param private_key string
function gamejolt.init(app_id, private_key)
    gamejolt.app_id = tonumber(app_id)
    gamejolt.private_key = private_key
    gamejolt.base_url = "https://api.gamejolt.com/api/game/v1_2"
    -- Pointing at another game must not keep the previous player logged in.
    gamejolt.logout()
    return (gamejolt.app_id ~= nil and gamejolt.private_key ~= nil)
end

---Returns whether the native HTTPS dependency required by the GameJolt API is available.
---@return boolean, string|nil
function gamejolt.isAvailable()
    if (https and type(https.request) == "function") then
        return true
    end

    local platform = (SE and SE.system and SE.system.getOS and SE.system.getOS()) or "Unknown"
    return false, "GameJolt API native HTTPS module is unavailable on "..tostring(platform)..": "..tostring(https_error or "missing native https module")
end

---Discards the stored credentials locally; call sessionClose() first if a
---session is still open on GameJolt.
function gamejolt.logout()
    gamejolt.username = nil
    gamejolt.user_token = nil
    gamejolt._verified = false
    gamejolt._session_auto.enabled = false
    gamejolt._session_auto.elapsed = 0
    gamejolt._session_auto.last_error = nil
end

---Returns whether a pair of credentials is stored locally and was accepted by the API.
---@return boolean
function gamejolt.isLoggedIn()
    return nonEmpty(gamejolt.username)
       and nonEmpty(gamejolt.user_token)
       and gamejolt._verified == true
end

---Fetches user data from the GameJolt API using either user ID or username.
---@param user_id number|string|nil
---@param username string|nil
---@return table|false, string|nil, string|nil
function gamejolt.fetchUser(user_id, username)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local path = "/users/?game_id=" .. gamejolt.app_id ..
                 (user_id and "&user_id=" .. urlencode(user_id) or "") ..
                 (username and "&username=" .. urlencode(username) or "")

    return apiRequest(path)
end

---Authenticates a user against the API. Credentials are stored only after the
---server accepts them, and a failed attempt clears the previous login.
---@param username string
---@param user_token string
---@return boolean, string|nil
function gamejolt.authUser(username, user_token)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local clean_user = type(username) == "string" and trim(username) or nil
    local clean_token = type(user_token) == "string" and trim(user_token) or nil
    if (not nonEmpty(clean_user) or not nonEmpty(clean_token)) then
        gamejolt.logout()
        return false, "GameJolt auth requires a non-empty username and user_token"
    end

    local path = "/users/auth/?game_id=" .. gamejolt.app_id ..
                 "&username=" .. urlencode(clean_user) ..
                 "&user_token=" .. urlencode(clean_token)

    local result, message = apiRequest(path)
    if (result == nil or result == false) then
        gamejolt.logout()
        return false, message
    end

    gamejolt.username = clean_user
    gamejolt.user_token = clean_token
    gamejolt._verified = true
    return true
end

---Fetches achievements (trophies). With achieved_only only achieved ones are returned.
---@param achieved_only boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.fetchAchievements(achieved_only)
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/trophies/?game_id=" .. gamejolt.app_id .. userParams() ..
                 (achieved_only and "&achieved=true" or "")

    return apiRequest(path)
end

---Unlocks a trophy by its trophy ID.
---@param trophy_id number|string
---@return boolean|false, string|nil, string|nil
function gamejolt.unlockAchievement(trophy_id)
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/trophies/add-achieved/?game_id=" .. gamejolt.app_id .. userParams() ..
                 "&trophy_id=" .. urlencode(trophy_id)

    local result, message = apiRequest(path)
    if (result) then
        return true
    end

    return false, message
end

---Opens a session for the authenticated user.
---@return table|false, string|nil, string|nil
function gamejolt.sessionOpen()
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/sessions/open/?game_id=" .. gamejolt.app_id .. userParams()
    return apiRequest(path)
end

---Opens a session and pings it every `interval` seconds. Call once.
---@param interval number|nil
---@param status string|nil
---@return boolean|false, string|nil, string|nil
function gamejolt.sessionUpdate(interval, status)
    local state = gamejolt._session_auto
    state.interval = math.max(1, tonumber(interval) or state.interval or 30)
    state.status = status or "active"
    state.elapsed = 0
    state.last_error = nil

    local result, err = gamejolt.sessionOpen()
    if (result == nil or result == false) then
        state.enabled = false
        return false, err
    end

    state.enabled = true
    return true
end

---Ticks the session heartbeat. Call from love.update(dt).
---@param dt number
function gamejolt.update(dt)
    sessionAutoTick(dt)
end

---Pings the current session to keep it active or update its status.
---@param status string|nil
---@return table|false, string|nil, string|nil
function gamejolt.sessionPing(status)
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/sessions/ping/?game_id=" .. gamejolt.app_id .. userParams() ..
                 "&status=" .. urlencode(status or "active")
    return apiRequest(path)
end

---Closes the session. Stops the heartbeat but keeps the credentials; use
---logout() to drop them.
---@return table|false, string|nil, string|nil
function gamejolt.sessionClose()
    gamejolt._session_auto.enabled = false
    gamejolt._session_auto.elapsed = 0

    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/sessions/close/?game_id=" .. gamejolt.app_id .. userParams()
    return apiRequest(path)
end

---Credential fragment for a data-store call; validates the login when user_data is set.
---@param user_data boolean|nil
---@return string|nil, string|nil
local function userDataParams(user_data)
    if (not user_data) then
        return ""
    end

    local ok, err = requireLogin()
    if (not ok) then return nil, err end
    return userParams()
end

---Stores data in the Data Store under `key`.
---@param key string
---@param data string
---@param user_data boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.dataStore(key, data, user_data)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local credentials
    credentials, err = userDataParams(user_data)
    if (not credentials) then return false, err end

    local path = "/data-store/set/?game_id=" .. gamejolt.app_id ..
                 "&key=" .. urlencode(key) .. "&data=" .. urlencode(data) .. credentials
    return apiRequest(path)
end

---Fetches the value stored under `key`.
---@param key string
---@param user_data boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.dataFetch(key, user_data)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local credentials
    credentials, err = userDataParams(user_data)
    if (not credentials) then return false, err end

    local path = "/data-store/?game_id=" .. gamejolt.app_id ..
                 "&key=" .. urlencode(key) .. credentials
    return apiRequest(path)
end

---Fetches all Data Store entries for the authenticated user.
---@param user_data boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.dataFetchAll(user_data)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local credentials
    credentials, err = userDataParams(user_data)
    if (not credentials) then return false, err end

    local path = "/data-store/?game_id=" .. gamejolt.app_id .. credentials
    return apiRequest(path)
end

---Deletes the entry stored under `key`.
---@param key string
---@param user_data boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.dataDelete(key, user_data)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local credentials
    credentials, err = userDataParams(user_data)
    if (not credentials) then return false, err end

    local path = "/data-store/delete/?game_id=" .. gamejolt.app_id ..
                 "&key=" .. urlencode(key) .. credentials
    return apiRequest(path)
end

---Fetches the Data Store keys of the authenticated user.
---@param user_data boolean|nil
---@return table|false, string|nil, string|nil
function gamejolt.dataGetKeys(user_data)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local credentials
    credentials, err = userDataParams(user_data)
    if (not credentials) then return false, err end

    local path = "/data-store/get-keys/?game_id=" .. gamejolt.app_id .. credentials
    return apiRequest(path)
end

---Fetches scores for a table, without user credentials.
---@param table_id number|string|nil
---@return table|false, string|nil, string|nil
function gamejolt.fetchScoresLocal(table_id)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local path = "/scores/?game_id=" .. gamejolt.app_id ..
                 (table_id and "&table_id=" .. urlencode(table_id) or "")
    return apiRequest(path)
end

---Fetches scores for a table, scoped to the logged-in user.
---@param table_id number|string|nil
---@return table|false, string|nil, string|nil
function gamejolt.fetchScoresGlobal(table_id)
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/scores/?game_id=" .. gamejolt.app_id ..
                 (table_id and "&table_id=" .. urlencode(table_id) or "") .. userParams()
    return apiRequest(path)
end

---Submits a score. Credentials are appended while logged in, so the score is
---filed under that account; otherwise it is a guest score (as_guest forces that).
---@param score number|string
---@param table_id number|string|nil
---@param sort string|nil
---@param extra_data string|nil
---@param as_guest boolean|nil
---@return boolean|false, string|nil, string|nil
function gamejolt.submitScore(score, table_id, sort, extra_data, as_guest)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    if (score == nil) then
        return false, "GameJolt: score is required"
    end

    local credentials = ""
    if (not as_guest and gamejolt.isLoggedIn()) then
        credentials = userParams()
    end

    local path = "/scores/add/?game_id=" .. gamejolt.app_id ..
                 "&score=" .. urlencode(score) ..
                 (table_id and "&table_id=" .. urlencode(table_id) or "") ..
                 (sort and "&sort=" .. urlencode(sort) or "") ..
                 (extra_data and "&extra_data=" .. urlencode(extra_data) or "") ..
                 credentials

    local result, message = apiRequest(path)
    if (result) then
        return true
    end

    return false, message
end

return gamejolt
