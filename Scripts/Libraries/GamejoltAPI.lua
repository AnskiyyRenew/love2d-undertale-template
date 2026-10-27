-- Documentation: https://gamejolt.com/game-api/doc
-- Naming convention: functions are camelCase, variables are snake_case.

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

-- Returns true for strings holding at least one non-whitespace character.
local function nonEmpty(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

-- Strips surrounding whitespace. Tokens pasted out of a browser often carry it and
-- the API rejects them verbatim.
local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

-- Percent-encodes a query value. Unencoded spaces, "&" or "=" both corrupt the URL
-- and change what the server hashes, so every signed request comes back rejected.
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

-- Guards against building a URL out of a nil app_id or private key.
local function requireConfig()
    if (gamejolt.app_id == nil or gamejolt.private_key == nil or gamejolt.base_url == nil) then
        return false, "GameJolt: call gamejolt.init(app_id, private_key) first"
    end
    return true
end

-- Guards user-scoped endpoints; without it they raise while concatenating nil.
local function requireLogin()
    if (not gamejolt.isLoggedIn()) then
        return false, "GameJolt: not authenticated, call gamejolt.authUser(username, user_token) first"
    end
    return true
end

-- Generates a signature for the GameJolt API request by hashing the input with MD5.
local function generateSignature(request_path)
    local input = gamejolt.base_url .. request_path .. gamejolt.private_key
    return md5.sumhexa(input)
end

-- Sends an HTTPS request to the GameJolt API and returns the response or error message.
-- On failure returns false, message, kind, where kind is "transport" (unreachable, bad
-- HTTP status, unparseable body) or "api" (the server explicitly refused).
local function apiRequest(path)
    if (not https or type(https.request) ~= "function") then
        local platform = (SE and SE.system and SE.system.getOS and SE.system.getOS()) or "Unknown"
        local reason = https_error or "missing native https module"
        return false, "GameJolt API unavailable on "..tostring(platform)..": "..reason, "transport"
    end

    local url = gamejolt.base_url .. path .. "&signature=" .. generateSignature(path)

    -- lua-https (https.dll) API: returns code, body, headers. DNS and TLS failures raise
    -- instead of returning a code in some builds, hence the pcall.
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

    -- A body that parses but carries no response envelope is not a valid success.
    local payload = data.response
    if (type(payload) ~= "table") then
        return false, "Malformed response: missing response envelope", "transport"
    end

    -- GameJolt reports success as the string "true"/"false", but tolerate a bare boolean
    -- so neither shape slips past the check.
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
        -- A server-side refusal means the credentials stopped working. Stop beating a dead
        -- session instead of retrying every interval for the rest of the run.
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

---Discards the stored credentials locally. This does not talk to GameJolt, so call
---sessionClose() first when a session is still open there.
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

--------------------------------------------USERS--------------------------------------------
---Fetches user data from the GameJolt API using either user ID or username.
-- Syntax: /users/?game_id=xxxxx&user_id=12345
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

---Authenticates a user with their username and token against the GameJolt API.
-- The credentials are stored only after the API accepts them, so isLoggedIn() cannot
-- report a login the server rejected. A failed attempt also clears the previous login.
-- Syntax: /users/auth/?game_id=xxxxx&username=test&user_token=test
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

------------------------------------------------ACHIEVEMENTS (TROPHIES)---------------------------------------------
---Fetches achievements (trophies) from the GameJolt API. If achieved_only is true, only achieved trophies are returned.
-- Syntax: /trophies/?game_id=xxxxx&username=test&user_token=test&achieved=true
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

---Unlocks an achievement (trophy) in the GameJolt API using the trophy ID.
-- Syntax: /trophies/add-achieved/?game_id=xxxxx&username=myusername&user_token=mytoken&trophy_id=1047
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

---------------------------------------------SESSIONS--------------------------------------------
---Opens a session for the authenticated user in the GameJolt API.
-- Syntax: /sessions/open/?game_id=xxxxx&username=myusername&user_token=mytoken
---@return table|false, string|nil, string|nil
function gamejolt.sessionOpen()
    local ok, err = requireConfig()
    if (not ok) then return false, err end
    ok, err = requireLogin()
    if (not ok) then return false, err end

    local path = "/sessions/open/?game_id=" .. gamejolt.app_id .. userParams()
    return apiRequest(path)
end

---Automatically opens a session and periodically pings GameJolt to keep it alive.
-- Only needs to be called once; the library will handle subsequent heartbeats for you.
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

---Manually ticks the session auto-ping mechanism.
---Call this from your own love.update(dt) to keep the GameJolt session alive.
---@param dt number
function gamejolt.update(dt)
    sessionAutoTick(dt)
end

---Pings the current session to keep it active or update its status.
-- Syntax: /sessions/ping/?game_id=xxxxx&username=myusername&user_token=mytoken&status=active
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

---Closes the current session for the authenticated user in the GameJolt API.
-- Stops the heartbeat but keeps the credentials, so the player stays logged in.
-- Use logout() to drop them.
-- Syntax: /sessions/close/?game_id=xxxxx&username=myusername&user_token=mytoken
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

---------------------------------------------DATA STORE--------------------------------------------
---Resolves the credential fragment for a data-store call, validating the login first.
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

---Stores data in the GameJolt Data Store under the specified key.
-- Syntax: /data-store/set/?game_id=xxxxx&key=test&data=test&username=myusername&user_token=mytoken
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

---Fetches data from the GameJolt Data Store using the specified key.
-- Syntax: /data-store/?game_id=xxxxx&key=test&username=myusername&user_token=mytoken
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

---Fetches all data from the GameJolt Data Store for the authenticated user.
-- Syntax: /data-store/?game_id=xxxxx&username=myusername&user_token=mytoken
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

---Deletes data from the GameJolt Data Store using the specified key.
-- Syntax: /data-store/delete/?game_id=xxxxx&key=test&username=myusername&user_token=mytoken
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

---Fetches the keys from the GameJolt Data Store for the authenticated user.
-- Syntax: /data-store/get-keys/?game_id=xxxxx&username=myusername&user_token=mytoken
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

------------------------------------------SCORES--------------------------------------------
---Fetches scores from the GameJolt API using the specified table ID.
-- Syntax: /scores/?game_id=xxxxx&table_id=12345
---@param table_id number|string|nil
---@return table|false, string|nil, string|nil
function gamejolt.fetchScoresLocal(table_id)
    local ok, err = requireConfig()
    if (not ok) then return false, err end

    local path = "/scores/?game_id=" .. gamejolt.app_id ..
                 (table_id and "&table_id=" .. urlencode(table_id) or "")
    return apiRequest(path)
end

---Fetches scores from the GameJolt API using the specified table ID and user data.
-- Syntax: /scores/?game_id=xxxxx&table_id=12345&username=myusername&user_token=mytoken
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

---Submits a score to the GameJolt API using the specified table ID and score value.
-- Credentials are appended whenever someone is logged in, which files the score under that
-- account. With nobody logged in the score is submitted as a guest, and passing as_guest
-- forces that even while authenticated.
-- Syntax: /scores/add/?game_id=xxxxx&score=12345&table_id=12345
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
