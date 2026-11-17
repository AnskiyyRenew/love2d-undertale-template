-- Discord Rich Presence over the discord-rpc C library, via LuaJIT FFI.
-- Needs Resources/Libs/DiscordRPC/discord-rpc-<arch>.dll (.so / .dylib).
-- main.lua: set discord.application_id (string), Discord.init() in love.load,
-- Discord.update(dt) every frame, Discord.setActivity{}, Discord.shutdown() on quit.

local discord = {}

discord.VERSION = "2.1.0"

-- Must be a STRING: 19-digit ids exceed 2^53, so a Lua number literal would
-- lose precision and Discord would reject the connection.
discord.application_id = nil

discord.available = false
discord.last_error = nil

discord.JoinReply = { No = 0, Yes = 1, Ignore = 2 }

-- Current unix timestamp, optionally shifted by `seconds` (activity start / finish).
function discord.timestamp(seconds)
    return os.time() + (tonumber(seconds) or 0)
end
local ffi_ok, ffi = pcall(require, "ffi")

if (ffi_ok) then
    ffi.cdef[[
        typedef struct DiscordRichPresence {
            const char* state;   /* max 128 bytes */
            const char* details; /* max 128 bytes */
            int64_t startTimestamp;
            int64_t endTimestamp;
            const char* largeImageKey;  /* max 32 bytes */
            const char* largeImageText; /* max 128 bytes */
            const char* smallImageKey;  /* max 32 bytes */
            const char* smallImageText; /* max 128 bytes */
            const char* partyId;        /* max 128 bytes */
            int partySize;
            int partyMax;
            const char* matchSecret;    /* max 128 bytes */
            const char* joinSecret;     /* max 128 bytes */
            const char* spectateSecret; /* max 128 bytes */
            int8_t instance;
        } DiscordRichPresence;

        typedef struct DiscordUser {
            const char* userId;
            const char* username;
            const char* discriminator;
            const char* avatar;
        } DiscordUser;

        typedef void (*DiscordReadyPtr)(const DiscordUser* request);
        typedef void (*DiscordDisconnectedPtr)(int errorCode, const char* message);
        typedef void (*DiscordErroredPtr)(int errorCode, const char* message);
        typedef void (*DiscordJoinGamePtr)(const char* joinSecret);
        typedef void (*DiscordSpectateGamePtr)(const char* spectateSecret);
        typedef void (*DiscordJoinRequestPtr)(const DiscordUser* request);

        typedef struct DiscordEventHandlers {
            DiscordReadyPtr ready;
            DiscordDisconnectedPtr disconnected;
            DiscordErroredPtr errored;
            DiscordJoinGamePtr joinGame;
            DiscordSpectateGamePtr spectateGame;
            DiscordJoinRequestPtr joinRequest;
        } DiscordEventHandlers;

        void Discord_Initialize(const char* applicationId,
                                DiscordEventHandlers* handlers,
                                int autoRegister,
                                const char* optionalSteamId);
        void Discord_Shutdown(void);
        void Discord_RunCallbacks(void);
        void Discord_UpdatePresence(const DiscordRichPresence* presence);
        void Discord_ClearPresence(void);
        void Discord_Respond(const char* userid, int reply);
        void Discord_UpdateHandlers(DiscordEventHandlers* handlers);
    ]]

    -- Holds every FFI callback trampoline so the GC never collects them.
    local callbacks = {}
    local function keepCallback(cb)
        callbacks[#callbacks + 1] = cb
        return cb
    end

    -- Builds the ordered list of candidate DLL paths for the current platform.
    local function buildDllCandidates()
        local candidates = {}

        -- ffi.load uses the OS loader, not LÖVE's VFS, so paths must be real;
        -- getSourceBaseDirectory() is the PARENT of the source folder, hence the
        -- getSource() append.
        local source_dir = nil
        local ok_s, s = pcall(function() return SE.filesystem.getSource() end)
        local ok_b, b = pcall(function() return SE.filesystem.getSourceBaseDirectory() end)
        if (ok_s and type(s) == "string" and s ~= "") then
            s = s:gsub("\\", "/"):gsub("/+$", "")
            -- getSource() may be a bare folder name or a full path: a drive
            -- letter or leading slash means absolute, otherwise prepend the base.
            if (s:match("^%a:") or s:match("^/")) then
                source_dir = s
            elseif (ok_b and type(b) == "string" and b ~= "") then
                source_dir = b:gsub("\\", "/"):gsub("/+$", "") .. "/" .. s
            end
        elseif (ok_b and type(b) == "string" and b ~= "") then
            -- No getSource(): fall back to the base directory.
            source_dir = b:gsub("\\", "/"):gsub("/+$", "")
        end

        local os_name = SE.system.getOS()
        local arch = ffi.arch -- e.g. "x64" / "x86"

        local names = {}
        if (os_name == "Windows") then
            names[#names + 1] = "discord-rpc-" .. arch .. ".dll"
            names[#names + 1] = "discord-rpc.dll"
            if (arch == "x64") then names[#names + 1] = "discord-rpc-x86_64.dll" end
        elseif (os_name == "Linux" or os_name == "Android") then
            names[#names + 1] = "libdiscord-rpc.so"
            names[#names + 1] = "discord-rpc.so"
        elseif (os_name == "macOS" or os_name == "iOS") then
            names[#names + 1] = "libdiscord-rpc.dylib"
            names[#names + 1] = "discord-rpc.dylib"
        else
            return candidates -- unsupported OS
        end

        local dirs = {}
        -- Absolute paths into the real source folder are the only reliable ones.
        if (source_dir) then
            dirs[#dirs + 1] = source_dir .. "/Resources/Libs/DiscordRPC/"
            dirs[#dirs + 1] = source_dir .. "/Resources/Libs/"
        end
        -- Relative fallbacks: only resolve when CWD == source folder.
        dirs[#dirs + 1] = "Resources/Libs/DiscordRPC/"
        dirs[#dirs + 1] = "Resources/Libs/"
        dirs[#dirs + 1] = ""

        for _, d in ipairs(dirs) do
            for _, n in ipairs(names) do
                candidates[#candidates + 1] = d .. n
            end
        end
        return candidates, source_dir
    end

    local function loadDiscordRpc()
        if (discord._lib and discord._lib_loaded) then
            return true
        end
        local candidates, source_dir = buildDllCandidates()
        -- Keep every candidate's error so the report names the failing path.
        local errors = {}
        for _, path in ipairs(candidates) do
            local ok_load, lib = pcall(ffi.load, path)
            if (ok_load and lib) then
                local ok_fn, fn = pcall(function() return lib.Discord_Initialize end)
                if (ok_fn and fn) then
                    discord._lib = lib
                    discord._lib_loaded = true
                    print("[DiscordRPC] loaded native library: " .. path)
                    return true
                else
                    errors[#errors + 1] = path .. " (loaded, but Discord_Initialize missing)"
                end
            else
                errors[#errors + 1] = path .. " -> " .. tostring(lib)
            end
        end
        return false, "discord-rpc library not found / could not be loaded.\n" ..
            "  source_dir = " .. tostring(source_dir) .. "\n" ..
            "  tried " .. #candidates .. " candidates:\n    - " ..
            table.concat(errors, "\n    - ")
    end

    -- User event callbacks (set via onJoin / onSpectate / onJoinRequest).
    local events = {
        ready = nil, disconnected = nil, errored = nil,
        joinGame = nil, spectateGame = nil, joinRequest = nil,
    }
    discord._events = events

    -- Safely reads a C string, nil for NULL pointers.
    local function cstr(p)
        if (p == nil or p == ffi.NULL) then
            return nil
        end
        return ffi.string(p)
    end

    local function unpackDiscordUser(request)
        if (request == nil or request == ffi.NULL) then
            return nil
        end
        return {
            userId = cstr(request.userId),
            username = cstr(request.username),
            discriminator = cstr(request.discriminator),
            avatar = cstr(request.avatar),
        }
    end

    -- Called from C, so a Lua error here escapes the caller's pcall and shows up
    -- as "unprotected error in call to Lua API": wrap every user callback.
    local function safeCallback(cb, ...)
        if (not cb) then return end
        local ok, err = pcall(cb, ...)
        if (not ok) then
            print("[DiscordRPC] callback error: " .. tostring(err))
        end
        return ok
    end
    local ready_proxy = keepCallback(ffi.cast("DiscordReadyPtr", function(request)
        safeCallback(events.ready, unpackDiscordUser(request))
    end))
    local disconnected_proxy = keepCallback(ffi.cast("DiscordDisconnectedPtr", function(errorCode, message)
        safeCallback(events.disconnected, errorCode, cstr(message))
    end))
    local errored_proxy = keepCallback(ffi.cast("DiscordErroredPtr", function(errorCode, message)
        safeCallback(events.errored, errorCode, cstr(message))
    end))
    local join_game_proxy = keepCallback(ffi.cast("DiscordJoinGamePtr", function(joinSecret)
        safeCallback(events.joinGame, cstr(joinSecret))
    end))
    local spectate_game_proxy = keepCallback(ffi.cast("DiscordSpectateGamePtr", function(spectateSecret)
        safeCallback(events.spectateGame, cstr(spectateSecret))
    end))
    local join_request_proxy = keepCallback(ffi.cast("DiscordJoinRequestPtr", function(request)
        safeCallback(events.joinRequest, unpackDiscordUser(request))
    end))

    local function buildHandlers()
        local h = ffi.new("DiscordEventHandlers")
        h.ready = ready_proxy
        h.disconnected = disconnected_proxy
        h.errored = errored_proxy
        h.joinGame = join_game_proxy
        h.spectateGame = spectate_game_proxy
        h.joinRequest = join_request_proxy
        return h
    end

    -- Accepts Game-SDK style names (state / details / large_image / start) and
    -- discord-rpc style names (largeImageKey / startTimestamp) alike.
    local function presenceFromTable(t)
        local p = ffi.new("DiscordRichPresence")
        p.state = t.state or nil
        p.details = t.details or nil
        p.startTimestamp = math.floor(tonumber(t.start) or tonumber(t.startTimestamp) or 0)
        p.endTimestamp = math.floor(tonumber(t.finish) or tonumber(t["end"]) or tonumber(t.endTimestamp) or 0)
        p.largeImageKey = t.large_image or t.largeImageKey or nil
        p.largeImageText = t.large_text or t.largeImageText or nil
        p.smallImageKey = t.small_image or t.smallImageKey or nil
        p.smallImageText = t.small_text or t.smallImageText or nil
        p.partyId = t.party_id or t.partyId or nil
        if (t.party_size) then
            local ps = t.party_size
            p.partySize = math.floor(tonumber(ps[1]) or tonumber(ps.current) or 0)
            p.partyMax = math.floor(tonumber(ps[2]) or tonumber(ps.max) or 0)
        else
            p.partySize = math.floor(tonumber(t.partySize) or 0)
            p.partyMax = math.floor(tonumber(t.partyMax) or 0)
        end
        p.matchSecret = t.match_secret or t.matchSecret or nil
        p.joinSecret = t.join_secret or t.joinSecret or nil
        p.spectateSecret = t.spectate_secret or t.spectateSecret or nil
        p.instance = (t.instance ~= false) and 1 or 0
        return p
    end

    ---Initializes Discord. Pass your app id (string!), or set discord.application_id.
    ---@param client_id? string|number
    ---@param options? table  { auto_register = boolean, steam_id = string }
    ---@return boolean, string?
    function discord.init(client_id, options)
        options = options or {}
        if (discord.available) then
            discord.shutdown()
        end

        client_id = client_id or discord.application_id
        if (not client_id) then
            discord.last_error = "Discord.application_id is not set - set it to your Discord application ID first."
            return false, discord.last_error
        end

        local ok_load, err_load = loadDiscordRpc()
        if (not ok_load) then
            discord.last_error = err_load
            return false, err_load
        end

        local appid = tostring(client_id)
        local handlers = buildHandlers()
        local ok_init = pcall(discord._lib.Discord_Initialize,
            appid, handlers,
            (options.auto_register == true) and 1 or 0,
            options.steam_id or nil)
        if (not ok_init) then
            discord.last_error = "Discord_Initialize failed."
            return false, discord.last_error
        end

        discord.client_id = appid
        discord.available = true
        discord.last_error = nil
        return true
    end

    ---Pumps the SDK. Required every frame: presence syncs and callbacks fire there.
    function discord.update(dt)
        if (discord.available and discord._lib) then
            discord._lib.Discord_RunCallbacks()
        end
    end
    -- jit.off: Discord_RunCallbacks re-enters Lua from JIT-ed code, which raises
    -- "unprotected error in call to Lua API" once the ready event fires. `jit`
    -- must be required explicitly, it is not a global.
    local ok_jit, jit = pcall(require, "jit")
    if (ok_jit and jit and jit.off) then
        jit.off(discord.update)
    end

    ---Releases the Discord connection. Call from love.quit().
    function discord.shutdown()
        if (discord.available and discord._lib) then
            pcall(discord._lib.Discord_Shutdown)
        end
        discord.available = false
        discord.client_id = nil
    end

    ---Returns whether Discord has been initialized.
    function discord.isAvailable()
        return discord.available and discord._lib ~= nil
    end

    ---Sets the Rich Presence activity.
    ---@param activity table
    ---@return boolean, string?
    function discord.setActivity(activity)
        if (not discord.isAvailable()) then
            return false, discord.last_error or "Discord not initialized"
        end
        if (type(activity) ~= "table") then
            return false, "setActivity expects a table"
        end
        discord._lib.Discord_UpdatePresence(presenceFromTable(activity))
        return true
    end

    ---Clears the current Rich Presence activity.
    ---@return boolean, string?
    function discord.clearActivity()
        if (not discord.isAvailable()) then
            return false, discord.last_error or "Discord not initialized"
        end
        discord._lib.Discord_ClearPresence()
        return true
    end

    ---Registers a callback fired when the user joins via a join secret.
    ---@param callback function  function(joinSecret)
    function discord.onJoin(callback)
        events.joinGame = callback
        return true
    end

    ---Registers a callback fired when the user spectates via a spectate secret.
    ---@param callback function  function(spectateSecret)
    function discord.onSpectate(callback)
        events.spectateGame = callback
        return true
    end

    ---Registers a callback fired when another user requests to join.
    ---@param callback function  function(user_table)
    function discord.onJoinRequest(callback)
        events.joinRequest = callback
        return true
    end

    ---Registers a callback fired once Discord accepts the connection.
    ---@param callback function  function(user_table|nil)
    function discord.onReady(callback)
        events.ready = callback
        return true
    end

    ---Registers a callback fired when Discord disconnects.
    ---@param callback function  function(errorCode, message)
    function discord.onDisconnected(callback)
        events.disconnected = callback
        return true
    end

    ---Registers a callback fired when Discord reports an error.
    ---An invalid or mismatched App ID normally shows up here.
    ---@param callback function  function(errorCode, message)
    function discord.onError(callback)
        events.errored = callback
        return true
    end

    ---Replies to a join request.
    ---@param user_id string
    ---@param reply number  discord.JoinReply.No / Yes / Ignore
    ---@return boolean, string?
    function discord.respond(user_id, reply)
        if (not discord.isAvailable()) then
            return false, discord.last_error or "Discord not initialized"
        end
        discord._lib.Discord_Respond(tostring(user_id), reply or discord.JoinReply.No)
        return true
    end

    -- Shut down cleanly if the module is ever garbage collected.
    if (newproxy) then
        discord.gc_dummy = newproxy(true)
        getmetatable(discord.gc_dummy).__gc = function()
            if (discord.available) then
                pcall(function() discord.shutdown() end)
            end
        end
    end

else
    -- No LuaJIT FFI available (e.g. a Lua 5.4 build of LÖVE): graceful no-ops.
    local function unavailable()
        return false, "DiscordRPC: LuaJIT FFI is unavailable in this LÖVE build (Rich Presence disabled)."
    end

    discord.init = unavailable
    discord.update = function() end
    discord.shutdown = function() end
    discord.isAvailable = function() return false end
    discord.setActivity = unavailable
    discord.clearActivity = unavailable
    discord.onJoin = unavailable
    discord.onSpectate = unavailable
    discord.onJoinRequest = unavailable
    discord.onReady = unavailable
    discord.onDisconnected = unavailable
    discord.onError = unavailable
    discord.respond = unavailable
end

return discord
