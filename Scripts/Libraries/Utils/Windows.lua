-- Windows.lua (cross-platform)
-- Native window / OS helper library for LOVE 12 (SDL3 based).
--
-- Everything that can be routed through SDL3 works on Windows, macOS and Linux and is
-- loaded through the LuaJIT FFI on every platform. The Win32 code paths are kept as
-- Windows-native fast paths only (message pump, layered-window transparency, GDI window
-- capture, CreateWindowEx fallback) and are skipped elsewhere.
--
-- Provides: getHandle, processMessages, setTransparency, setBackgroundTransparent,
--           saveScreenshot, showDialog, CreateWindow + the SDL child-window helpers
--           (render / present canvas / keyboard+mouse callbacks / close detection).
--
-- Platform support per function:
--   CreateWindow / CreateWindowSDL   Windows / macOS / Linux   (Android & iOS: unsupported)
--   CreateWindowWin32                Windows only
--   DestroyWindow / DestroyWindowSDL all
--   getHandle                        all (HWND / NSWindow* / XID / wl_surface* / jobject)
--   processMessages                  Windows only (SDL/LÖVE pumps its own queue elsewhere)
--   setTransparency                  all (SDL_SetWindowOpacity; Win32 layered on Windows)
--   setBackgroundTransparent         all (colour key only on Windows, alpha elsewhere)
--   saveScreenshot                   Windows (GDI) / macOS (screencapture) / Linux (grim, ...)
--   showDialog                       all
--
-- The module keeps its historical name because Scripts/Libraries/Engine/2_0.lua exposes it
-- as the global `SE.windows` and Scripts/Libraries/Engine/DevTool.lua requires it by path.

---@class WindowsLib
---Cross-platform native window utility library for LÖVE 12 (SDL3 + optional Win32 fast paths).
local window = {}


-- 1. Platform detection & FFI bootstrap


---Host OS name as reported by the engine ("Windows" / "OS X" / "Linux" / "Android" / "iOS").
local os_name = "Unknown"
do
    local ok, v = pcall(function()
        if SE and SE.system and SE.system.getOS then return SE.system.getOS() end
        if love and love.system and love.system.getOS then return love.system.getOS() end
        return "Unknown"
    end)
    if ok and type(v) == "string" then os_name = v end
end

local is_windows = os_name == "Windows"
local is_macos   = os_name == "OS X"
local is_linux   = os_name == "Linux"
local is_android = os_name == "Android"
local is_ios     = os_name == "iOS"
local is_desktop = is_windows or is_macos or is_linux
local is_mobile  = is_android or is_ios

---Host OS name (read-only).
window.platform = os_name

---LuaJIT FFI handle, or nil on builds without FFI (e.g. a pure-Lua iOS build).
local ffi = nil
do
    local ok, m = pcall(require, "ffi")
    if ok and type(m) == "table" then ffi = m end
end

---LuaJIT `bit` handle, or nil (bit is optional; a pure-Lua fallback is used below).
local bit = nil
do
    local ok, m = pcall(require, "bit")
    if ok and type(m) == "table" then bit = m end
end

---Bitwise OR that also works without LuaJIT's `bit` library (flags used here are small).
---@param a integer
---@param b integer
---@return integer
local function pure_bor(a, b)
    a, b = a % 0x100000000, b % 0x100000000
    local res, p = 0, 1
    for _ = 1, 32 do
        if (a % 2 == 1) or (b % 2 == 1) then res = res + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p + p
    end
    return res
end
local bor = bit and function(a, b) return bit.bor(a, b) end or pure_bor

---True when the FFI is usable (required by every native helper in this module).
---@return boolean available
function window.hasFFI()
    return ffi ~= nil
end


-- 2. Win32 shared libraries (Windows only)


local user32, gdi32, kernel32
if is_windows and ffi then
    local function loadLib(name)
        local ok, lib = pcall(ffi.load, name)
        if ok and lib then return lib end
        print("[Windows] ffi.load(" .. name .. ") failed: " .. tostring(lib))
        return nil
    end
    user32 = loadLib("user32")
    gdi32 = loadLib("gdi32")
    -- GetModuleHandle / GetLastError / GetCurrentProcessId live in kernel32, not user32
    kernel32 = loadLib("kernel32")
end


-- 3. C declarations


-- SDL3 is bundled with LOVE 12 on every platform, so it is declared unconditionally.
-- (On Win32 the extra structs below are declared separately.)
if ffi then
    ffi.cdef[[
        typedef struct SDL_Window SDL_Window;
        typedef struct SDL_Renderer SDL_Renderer;
        typedef struct SDL_Texture SDL_Texture;
        typedef struct { int x; int y; int w; int h; } SDL_Rect;

        int SDL_Init(unsigned int flags);
        int SDL_GetVersion(void);
        int SDL_QuitSubSystem(unsigned int flags);

        SDL_Window* SDL_CreateWindow(const char* title, int w, int h, unsigned int flags);
        void SDL_DestroyWindow(SDL_Window* window);
        void SDL_SetWindowPosition(SDL_Window* window, int x, int y);
        SDL_Window** SDL_GetWindows(int* count);
        SDL_Window* SDL_GetWindowFromID(unsigned int id);
        unsigned long long SDL_GetWindowFlags(SDL_Window* window);
        unsigned int SDL_GetWindowID(SDL_Window* window);
        int SDL_RaiseWindow(SDL_Window* window);
        int SDL_SetWindowInputFocus(SDL_Window* window);
        int SDL_SetWindowKeyboardFocus(SDL_Window* window);
        int SDL_SetWindowOpacity(SDL_Window* window, float opacity);
        float SDL_GetWindowOpacity(SDL_Window* window);

        void* SDL_GetWindowProperties(SDL_Window* window);
        void* SDL_GetPointerProperty(void* props, const char* name, void* default_value);
        long long SDL_GetNumberProperty(void* props, const char* name, long long default_value);

        SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
        void SDL_DestroyRenderer(SDL_Renderer* renderer);
        int SDL_RenderClear(SDL_Renderer* renderer);
        int SDL_RenderPresent(SDL_Renderer* renderer);
        int SDL_SetRenderDrawColor(SDL_Renderer* renderer, unsigned char r, unsigned char g, unsigned char b, unsigned char a);

        SDL_Texture* SDL_CreateTexture(SDL_Renderer* renderer, unsigned int format, int access, int w, int h);
        void SDL_DestroyTexture(SDL_Texture* texture);
        int SDL_UpdateTexture(SDL_Texture* texture, const SDL_Rect* rect, const void* pixels, int pitch);
        int SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture* texture, const SDL_Rect* srcrect, const SDL_Rect* dstrect);

        // SDL3 event watch: detect close-requested (X) for child windows
        typedef int (*SDL_EventFilter)(void* userdata, void* event);

        int SDL_AddEventWatch(SDL_EventFilter filter, void* userdata);
        void SDL_DelEventWatch(SDL_EventFilter filter, void* userdata);
        int SDL_PushEvent(const void* event);
        const char* SDL_GetKeyName(int key);
        unsigned int SDL_GetModState(void);

        static const int SDL_EVENT_WINDOW_CLOSE_REQUESTED = 0x20F;
        static const int SDL_EVENT_WINDOW_FOCUS_GAINED = 0x20D;
        static const int SDL_EVENT_WINDOW_FOCUS_LOST = 0x20E;
        static const int SDL_EVENT_KEY_DOWN = 0x301;
        static const int SDL_EVENT_KEY_UP = 0x302;

        // SDL3 mouse events (for child-window mouse capture in the DevTool)
        static const int SDL_EVENT_MOUSE_MOTION = 0x400;
        static const int SDL_EVENT_MOUSE_BUTTON_DOWN = 0x401;
        static const int SDL_EVENT_MOUSE_BUTTON_UP = 0x402;
        static const int SDL_EVENT_MOUSE_WHEEL = 0x403;

        // Note: these structs intentionally use plain "unsigned int" placeholders for
        // the common {type, reserved, timestamp} head so that the field offsets match
        // the real SDL3 layout (timestamp@8 is 8 bytes, windowID@16, ...).
        typedef struct SDL_MouseMotionEvent {
            unsigned int type;
            unsigned int reserved;
            unsigned int ts0;
            unsigned int ts1;
            unsigned int windowID;
            unsigned int which;
            unsigned int state;
            float x;
            float y;
            float xrel;
            float yrel;
        } SDL_MouseMotionEvent;

        typedef struct SDL_MouseButtonEvent {
            unsigned int type;
            unsigned int reserved;
            unsigned int ts0;
            unsigned int ts1;
            unsigned int windowID;
            unsigned int which;
            unsigned char button;
            unsigned char down;
            unsigned char clicks;
            unsigned char padding;
            float x;
            float y;
        } SDL_MouseButtonEvent;

        typedef struct SDL_MouseWheelEvent {
            unsigned int type;
            unsigned int reserved;
            unsigned int ts0;
            unsigned int ts1;
            unsigned int windowID;
            unsigned int which;
            float x;
            float y;
            unsigned int direction;
            float mouseX;
            float mouseY;
        } SDL_MouseWheelEvent;

        // SDL3 keyboard events (parsed via struct to guarantee correct field offsets)
        typedef struct SDL_KeyboardEvent {
            unsigned int type;
            unsigned int reserved;
            unsigned int ts0;
            unsigned int ts1;
            unsigned int windowID;
            unsigned int which;
            unsigned int scancode;
            int key;
            unsigned int mod;
            unsigned short raw;
            unsigned char down;
            unsigned char repeat_;
        } SDL_KeyboardEvent;

        // SDL3 window event (used to build a synthetic close-request; "unsigned int" head
        // placeholders keep the offsets identical to the real struct: windowID@16, data@24)
        typedef struct SDL_WindowEvent {
            unsigned int type;
            unsigned int reserved;
            unsigned int ts0;
            unsigned int ts1;
            unsigned int windowID;
            int data1;
            int data2;
        } SDL_WindowEvent;
    ]]
end

if ffi and is_windows then
    ffi.cdef[[
        typedef void* HWND;
        typedef const char* LPCSTR;
        typedef const wchar_t* LPCWSTR;
        typedef unsigned long DWORD;
        typedef long LONG;
        typedef unsigned char BYTE;
        typedef unsigned int UINT;
        typedef int BOOL;
        typedef void* HDC;
        typedef void* HBITMAP;
        typedef void* HCURSOR;
        typedef void* HINSTANCE;
        typedef uintptr_t UINT_PTR;
        typedef intptr_t LONG_PTR;
        typedef UINT_PTR WPARAM;
        typedef LONG_PTR LPARAM;
        typedef intptr_t LRESULT;
        // LRESULT is 64-bit on x64; the callback must return intptr_t, otherwise
        // WM_NCCREATE is misjudged as failed (error 183).
        typedef LRESULT (__stdcall *WNDPROC)(void* hwnd, unsigned int msg, WPARAM wParam, LPARAM lParam);

        typedef struct {
            LONG left;
            LONG top;
            LONG right;
            LONG bottom;
        } RECT;

        typedef struct { HWND hwnd; UINT message; WPARAM wParam; LPARAM lParam; DWORD time; struct { LONG x; LONG y; } pt; } MSG;

        typedef struct {
            DWORD   biSize;
            long    biWidth;
            long    biHeight;
            unsigned short biPlanes;
            unsigned short biBitCount;
            DWORD   biCompression;
            DWORD   biSizeImage;
            long    biXPelsPerMeter;
            long    biYPelsPerMeter;
            DWORD   biClrUsed;
            DWORD   biClrImportant;
        } BITMAPINFOHEADER;

        typedef struct {
            BITMAPINFOHEADER bmiHeader;
            unsigned int bmiColors[3];
        } BITMAPINFO;

        typedef struct {
            UINT    cbSize;
            UINT    style;
            WNDPROC lpfnWndProc;
            int     cbClsExtra;
            int     cbWndExtra;
            HINSTANCE hInstance;
            void*   hIcon;
            HCURSOR hCursor;
            void*   hbrBackground;
            const char* lpszMenuName;
            const char* lpszClassName;
            void*   hIconSm;
        } WNDCLASSEXA;

        typedef struct {
            UINT    cbSize;
            UINT    style;
            WNDPROC lpfnWndProc;
            int     cbClsExtra;
            int     cbWndExtra;
            HINSTANCE hInstance;
            void*   hIcon;
            HCURSOR hCursor;
            void*   hbrBackground;
            const wchar_t* lpszMenuName;
            const wchar_t* lpszClassName;
            void*   hIconSm;
        } WNDCLASSEXW;

        HWND FindWindowA(LPCSTR lpClassName, LPCSTR lpWindowName);
        HWND FindWindowExA(HWND hWndParent, HWND hWndChildAfter, LPCSTR lpszClass, LPCSTR lpszWindow);
        DWORD GetCurrentProcessId();
        DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);

        LONG GetWindowLongA(HWND hWnd, int nIndex);
        LONG SetWindowLongA(HWND hWnd, int nIndex, LONG dwNewLong);
        int SetLayeredWindowAttributes(HWND hwnd, BYTE crKey, BYTE bAlpha, DWORD dwFlags);
        int SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags);

        HDC GetDC(HWND hWnd);
        int ReleaseDC(HWND hWnd, HDC hdc);
        HDC CreateCompatibleDC(HDC hdc);
        HBITMAP CreateCompatibleBitmap(HDC hdc, int cx, int cy);
        HBITMAP SelectObject(HDC hdc, HBITMAP h);
        int BitBlt(HDC hdcDest, int xDest, int yDest, int wDest, int hDest, HDC hdcSrc, int xSrc, int ySrc, DWORD rop);
        int GetDIBits(HDC hdc, HBITMAP hbmp, UINT uStartScan, UINT cScanLines, void* lpvBits, BITMAPINFO* lpbmi, UINT uUsage);
        int DeleteObject(HBITMAP hObject);
        int DeleteDC(HDC hdc);

        void* GetModuleHandleA(const char* lpModuleName);
        unsigned short RegisterClassExA(const WNDCLASSEXA* lpwcx);
        unsigned short RegisterClassExW(const WNDCLASSEXW* lpwcx);
        void* CreateWindowExA(unsigned long dwExStyle, const char* lpClassName, const char* lpWindowName, unsigned long dwStyle, int x, int y, int nWidth, int nHeight, void* hWndParent, void* hMenu, void* hInstance, void* lpParam);
        void* CreateWindowExW(unsigned long dwExStyle, const wchar_t* lpClassName, const wchar_t* lpWindowName, unsigned long dwStyle, int x, int y, int nWidth, int nHeight, void* hWndParent, void* hMenu, void* hInstance, void* lpParam);
        LRESULT DefWindowProcA(void* hWnd, unsigned int Msg, WPARAM wParam, LPARAM lParam);
        LRESULT DefWindowProcW(void* hWnd, unsigned int Msg, WPARAM wParam, LPARAM lParam);

        void* BeginPaint(void* hwnd, void* lpPaint);
        int EndPaint(void* hwnd, const void* lpPaint);
        void* GetStockObject(int fnObject);
        int Rectangle(void* hdc, int left, int top, int right, int bottom);
        BOOL PeekMessageA(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
        BOOL PeekMessageW(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
        int TranslateMessage(const void* lpMsg);
        LRESULT DispatchMessageA(const MSG* lpMsg);
        LRESULT DispatchMessageW(const MSG* lpMsg);
        void PostQuitMessage(int nExitCode);
        DWORD GetLastError(void);

        HCURSOR LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);
        intptr_t SendMessageW(void* hWnd, unsigned int Msg, uintptr_t wParam, intptr_t lParam);

        static const int IDC_ARROW = 32512;

        static const int GWL_EXSTYLE = -20;
        static const int WS_EX_LAYERED = 0x00080000;
        static const int LWA_COLORKEY = 0x00000001;
        static const int LWA_ALPHA = 0x00000002;
        static const int HWND_TOP = 0;
        static const int SWP_FRAMECHANGED = 0x0020;
        static const int SWP_NOMOVE = 0x0002;
        static const int SWP_NOSIZE = 0x0001;
        static const int SRCCOPY = 0x00CC0020;
        static const int BI_RGB = 0;
        static const int BLACK_BRUSH = 4;
        static const int WHITE_BRUSH = 0;
        static const int TRANSPARENT = 1;
        static const int SW_SHOW = 5;

        static const int WM_CLOSE = 0x0010;
        static const int WM_DESTROY = 0x0002;
        static const int WM_PAINT = 0x000F;
        static const int WM_NCCREATE = 0x0081;
        static const int WM_CREATE = 0x0001;

        static const int WS_OVERLAPPED = 0x00000000;
        static const int WS_CAPTION = 0x00C00000;
        static const int WS_SYSMENU = 0x00080000;
        static const int WS_THICKFRAME = 0x00040000;
        static const int WS_MINIMIZEBOX = 0x00020000;
        static const int WS_MAXIMIZEBOX = 0x00010000;
        static const int WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
        static const int CS_HREDRAW = 0x0002;
        static const int CS_VREDRAW = 0x0001;

        int ShowWindow(HWND hWnd, int nCmdShow);
        BOOL UpdateWindow(HWND hWnd);
        BOOL DestroyWindow(HWND hWnd);
        BOOL GetClientRect(HWND hWnd, RECT* lpRect);
        int FillRect(HDC hdc, const RECT* lprc, void* hbr);
        DWORD SetTextColor(HDC hdc, DWORD color);
        int SetBkMode(HDC hdc, int iBkMode);
        BOOL TextOutA(HDC hdc, int x, int y, const char* lpString, int c);
        BOOL TextOutW(HDC hdc, int x, int y, const wchar_t* lpString, int c);
    ]]
end


-- 4. SDL3 shared library (every platform)


---Candidate SDL3 library names/paths, tried in order.
---Windows: SDL3.dll ships next to love.exe. Linux/macOS: the soname/dylib name, including
---the usual Homebrew prefixes. A statically linked LOVE is covered by the "current process"
---fallback in loadSDL() below.
local SDL_CANDIDATES = {
    "SDL3",
    "SDL3.dll",
    "libSDL3.so.0",
    "libSDL3.so",
    "libSDL3.dylib",
    "/usr/lib/libSDL3.so.0",
    "/usr/lib/x86_64-linux-gnu/libSDL3.so.0",
    "/usr/lib/aarch64-linux-gnu/libSDL3.so.0",
    "/usr/local/lib/libSDL3.dylib",
    "/opt/homebrew/lib/libSDL3.dylib",
    "/opt/local/lib/libSDL3.dylib",
}

local sdl = nil       -- loaded SDL3 library object, or nil
local sdl_name = nil  -- human readable name of the loaded library (for diagnostics)

---Try to load one SDL3 library path.
---@param path string
---@return userdata|nil lib
local function tryLoadSDL(path)
    if not ffi then return nil end
    local ok, lib = pcall(ffi.load, path)
    if ok and lib then return lib end
    return nil
end

---Load SDL3, auto-detecting the library on the current platform.
---Called once at require time; call it again (e.g. with an explicit path) if SDL was not
---found automatically, then reload whatever feature needs it.
---@param path? string Explicit library path/name; auto-detect when omitted
---@return boolean ok
---@return string|nil errMsg
function window.LoadSDL(path)
    if sdl and (path == nil or path == sdl_name) then return true end
    if not ffi then return false, "FFI unavailable on this build" end

    if path then
        local lib = tryLoadSDL(path)
        if not lib then return false, "cannot load SDL3 library: " .. tostring(path) end
        sdl, sdl_name = lib, path
        return true
    end

    for _, candidate in ipairs(SDL_CANDIDATES) do
        local lib = tryLoadSDL(candidate)
        if lib then
            sdl, sdl_name = lib, candidate
            return true
        end
    end

    -- Last resort: some builds link SDL3 straight into the executable, so its symbols are
    -- only reachable through the current process (dlopen(NULL) / GetModuleHandle(NULL)).
    local ok, lib = pcall(ffi.load)
    if ok and lib then
        sdl, sdl_name = lib, "<current process>"
        return true
    end

    return false, "SDL3 not found (tried " .. table.concat(SDL_CANDIDATES, ", ") .. ")"
end

do
    local ok, err = window.LoadSDL()
    if not ok then
        sdl, sdl_name = nil, nil
        print("[Windows] SDL3 unavailable, native child windows disabled: " .. tostring(err))
    end
end

---@return boolean available true when SDL3 was loaded
function window.hasSDL()
    return sdl ~= nil
end

---@return string|nil name Name/path of the loaded SDL3 library
function window.SDLLibraryName()
    return sdl_name
end

---@return integer|nil version SDL version number (major<<24 | minor<<16 | patch), or nil
function window.SDLVersion()
    if not sdl then return nil end
    local ok, v = pcall(function() return sdl.SDL_GetVersion() end)
    if ok and v ~= nil then return tonumber(v) end
    return nil
end


-- 5. Module state


-- Module-level persistent objects (critical: keep them alive to avoid GC)
local wndProcRef = nil        -- WNDPROC callback (Win32 path), kept alive
window.windowClassRegistered = false
window._created = {}          -- hwnd -> { unicode=bool, className, title, titleW, titleLenW }
window._sdlWindows = {}       -- SDL_Window* -> { renderer, title, color, canvasTex, ... }
window._sdlClosePending = {}  -- SDL_Window* -> true (child window requested close, pending destroy)
window._sdlKeyCallbacks = {}   -- SDL_Window* -> fun(key, scancode, isDown, isRepeat) (fires only when that window has focus)
window._sdlMouseCallbacks = {} -- SDL_Window* -> { motion=fun(x,y,xrel,yrel), button=fun(button,x,y,down,clicks), wheel=fun(x,y) }
window._sdlHover = nil         -- the managed child window the mouse is hovering over (key-forwarding fallback)
local sdlEventWatchRef = nil  -- event-watch callback, kept alive to avoid GC

---Whether a handle belongs to a window created by this module's SDL path.
---@param handle userdata
---@return boolean ours
local function isOurSDLWindow(handle)
    return handle ~= nil and window._sdlWindows[handle] ~= nil
end

---True when a cdata pointer is non-null.
---@param p userdata
---@return boolean valid
local function ptrOK(p)
    if p == nil then return false end
    if not ffi then return false end
    local ok, v = pcall(function() return tonumber(ffi.cast("intptr_t", p)) end)
    return ok and v ~= nil and v ~= 0
end


-- 6. Screen / colour helpers


---Get the LÖVE window handle.
---Windows: tries several class names and process enumeration and returns the HWND.
---macOS / Linux: returns the engine hook value when available, otherwise derives the
---native handle of the main LÖVE window from SDL3 (NSWindow* / XID / wl_surface*).
---@return userdata|nil handle Platform native handle, or nil if not found
function window.getHandle()
    if is_windows and user32 and kernel32 and ffi then
        local classNames = {"SDL_app", "Love2D", "LÖVE", "GLFW30", "SDL_WindowClass"}
        for _, className in ipairs(classNames) do
            local hwnd = user32.FindWindowA(className, nil)
            if ptrOK(hwnd) then
                return hwnd
            end
        end

        -- Fallback: enumerate the current process's windows
        local pid = kernel32.GetCurrentProcessId()
        local hwnd = ffi.cast("HWND", 0)
        while true do
            hwnd = user32.FindWindowExA(nil, hwnd, nil, nil)
            if not ptrOK(hwnd) then break end
            local foundPid = ffi.new("DWORD[1]")
            user32.GetWindowThreadProcessId(hwnd, foundPid)
            if foundPid[0] == pid then
                return hwnd
            end
        end
        return nil
    end

    if SE and SE.window and SE.window.getHandle then
        local ok, h = pcall(SE.window.getHandle)
        if ok and h ~= nil then return h end
    end

    -- SDL fallback: the main LÖVE window is the first SDL window we did not create ourselves
    local mainWin = window.getMainWindowSDL()
    if mainWin then
        local handle = window.SDLGetNativeHandle(mainWin)
        if handle ~= nil then return handle end
        return mainWin
    end

    return nil
end

---Process the Win32 message queue (call regularly on the main thread).
---Windows only: the Win32 fallback windows created by CreateWindowWin32 need an explicit
---pump. On macOS/Linux (and for pure SDL windows) SDL3 drives its own queue, so this is a
---no-op there.
---@param hwnd? userdata If provided, only processes messages for this window (recommended to avoid interfering with the LÖVE main window); nil processes all messages for the current thread.
function window.processMessages(hwnd)
    if not (is_windows and user32) then return end
    local msg = ffi.new("MSG")
    -- Choose W (Unicode) or A (ANSI) message functions based on how the window was created
    local created = hwnd and window._created[hwnd]
    local isW = created and created.unicode
    local peekMsg = (isW and user32.PeekMessageW) or user32.PeekMessageA
    local dispatch = (isW and user32.DispatchMessageW) or user32.DispatchMessageA
    -- PM_REMOVE = 1
    while peekMsg(msg, hwnd, 0, 0, 1) ~= 0 do
        user32.TranslateMessage(msg)
        dispatch(msg)
    end
end

---Convert a UTF-8 Lua string to UTF-16 (wchar_t*), fully supporting non-ASCII characters such as Chinese; returns buf, len (number of code units).
---@param str string UTF-8 string
---@return userdata buf wchar_t buffer (NUL-terminated)
---@return integer len Number of UTF-16 code units
local function utf8_to_wchar_utf16(str)
    local out = {}
    local i, n = 1, #str
    while i <= n do
        local b1 = string.byte(str, i)
        local cp
        if b1 < 0x80 then
            cp = b1
            i = i + 1
        elseif b1 < 0xE0 then
            cp = (b1 - 0xC0) * 0x40 + ((string.byte(str, i + 1) or 0x80) - 0x80)
            i = i + 2
        elseif b1 < 0xF0 then
            cp = (b1 - 0xE0) * 0x1000 + ((string.byte(str, i + 1) or 0x80) - 0x80) * 0x40 + ((string.byte(str, i + 2) or 0x80) - 0x80)
            i = i + 3
        else
            cp = (b1 - 0xF0) * 0x40000 + ((string.byte(str, i + 1) or 0x80) - 0x80) * 0x1000 + ((string.byte(str, i + 2) or 0x80) - 0x80) * 0x40 + ((string.byte(str, i + 3) or 0x80) - 0x80)
            i = i + 4
        end
        if cp >= 0x10000 then
            -- Needs a surrogate pair
            cp = cp - 0x10000
            out[#out + 1] = 0xD800 + math.floor(cp / 0x400)
            out[#out + 1] = 0xDC00 + (cp % 0x400)
        else
            out[#out + 1] = cp
        end
    end
    local buf = ffi.new("wchar_t[?]", #out + 1)
    for k = 1, #out do
        buf[k - 1] = out[k]
    end
    buf[#out] = 0
    return buf, #out
end

-- Default window procedure (Win32): white background + title text; cleans up records on WM_DESTROY.
-- Wrapped in pcall: a Lua error thrown inside an ffi callback crashes the process directly
-- (0xC000041D); here we catch and log it, then return 0 so the system continues.
local function nativeWndProc(hwnd, msg, wParam, lParam)
    local ok, res = pcall(function()
        if msg == ffi.C.WM_DESTROY then
            window._created[hwnd] = nil
            return 0
        end
        if msg == ffi.C.WM_PAINT then
            -- PAINTSTRUCT is 72 bytes on 64-bit; use a 128-byte buffer to avoid overflow
            local ps = ffi.new("uint8_t[128]")
            local hdc = user32.BeginPaint(hwnd, ps)
            if hdc ~= nil then
                local rc = ffi.new("RECT")
                user32.GetClientRect(hwnd, rc)
                -- FillRect lives in user32.dll (not gdi32)
                user32.FillRect(hdc, rc, gdi32.GetStockObject(ffi.C.WHITE_BRUSH))
                local info = window._created[hwnd]
                if info then
                    gdi32.SetBkMode(hdc, ffi.C.TRANSPARENT)
                    gdi32.SetTextColor(hdc, 0x000000) -- black text
                    if info.unicode and info.titleW then
                        gdi32.TextOutW(hdc, 12, 10, info.titleW, info.titleLenW)
                    elseif info.title and not info.title:match("[^\x00-\x7F]") then
                        gdi32.TextOutA(hdc, 12, 10, info.title, #info.title)
                    end
                end
            end
            user32.EndPaint(hwnd, ps)
            return 0
        end
        local info = window._created[hwnd]
        if info and info.unicode then
            return user32.DefWindowProcW(hwnd, msg, wParam, lParam)
        end
        return user32.DefWindowProcA(hwnd, msg, wParam, lParam)
    end)
    if not ok then
        print("[Windows] WNDPROC msg=" .. tostring(msg) .. " error: " .. tostring(res))
        return 0
    end
    return res
end


-- 7. Window creation


---@class CreateWindowOptions
---Options for creating a native window.
---@field title? string Window title (default: class name or "SDL Window")
---@field x? integer X position (default: 0 for Win32, centered for SDL)
---@field y? integer Y position (default: 0 for Win32, centered for SDL)
---@field width? integer Window width (default: 480)
---@field height? integer Window height (default: 320)
---@field className? string Win32 window class name (ASCII recommended, CreateWindowWin32 only)
---@field style? integer Win32 window style DWORD (default WS_OVERLAPPEDWINDOW, CreateWindowWin32 only)
---@field unicode? boolean Use the Unicode (W) Win32 API (CreateWindowWin32 only, default true)
---@field resizable? boolean Make the window resizable (SDL only)
---@field borderless? boolean Create a borderless window (SDL only)
---@field color? integer[] Initial fill color {r,g,b} (SDL only)

---Create a native window (recommended entry point).
---Prefers SDL3 (bundled with LÖVE 12 on every platform, SDL handles the event/message loop
---internally, most stable); falls back to the Win32 CreateWindowEx implementation on Windows
---when SDL is unavailable. macOS/Linux have no non-SDL fallback.
---@param opts? CreateWindowOptions Options (see CreateWindowSDL / CreateWindowWin32)
---@return userdata|nil handle The native window handle (SDL_Window* or HWND), or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindow(opts)
    if sdl then
        return window.CreateWindowSDL(opts)
    end
    if is_windows then
        return window.CreateWindowWin32(opts)
    end
    return nil, "SDL3 unavailable and " .. tostring(os_name) .. " has no native window fallback."
end

---Create a native window (low-level Win32 implementation, independent of the LÖVE main window).
---Windows only; prefer CreateWindow / CreateWindowSDL.
---@param opts? CreateWindowOptions
---@return userdata|nil hwnd The Win32 window handle, or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindowWin32(opts)
    opts = opts or {}
    if not is_windows then
        return nil, "CreateWindowWin32 only supported on Windows."
    end
    if not (ffi and user32 and gdi32 and kernel32) then
        return nil, "Win32 libraries unavailable."
    end

    local className = opts.className or "LOVE_NativeWindow"
    local title     = opts.title or className
    local x, y      = opts.x or 0, opts.y or 0
    local width     = opts.width or 480
    local height    = opts.height or 320
    local style     = opts.style or ffi.C.WS_OVERLAPPEDWINDOW
    local unicode   = (opts.unicode ~= false)

    -- Current process instance handle (must use GetModuleHandle(NULL), otherwise class registration fails)
    local hInstance = kernel32.GetModuleHandleA(nil)
    if hInstance == nil then
        return nil, "GetModuleHandleA(NULL) failed, lastError=" .. tostring(kernel32.GetLastError())
    end

    -- Create the callback once and keep it alive (GC-ing it causes registration failure or crashes)
    if wndProcRef == nil then
        local ok, err = pcall(function()
            wndProcRef = ffi.cast("WNDPROC", nativeWndProc)
        end)
        if not ok then
            return nil, "ffi.cast(WNDPROC) failed: " .. tostring(err)
        end
    end

    local info = { unicode = unicode, className = className, title = title }
    local hwnd

    if unicode then
        local classBuf = utf8_to_wchar_utf16(className)
        local titleW, titleLenW = utf8_to_wchar_utf16(title)
        info.titleW = titleW
        info.titleLenW = titleLenW

        local wc = ffi.new("WNDCLASSEXW")
        wc.cbSize = ffi.sizeof("WNDCLASSEXW")
        wc.style = 3 -- CS_HREDRAW | CS_VREDRAW
        wc.lpfnWndProc = wndProcRef
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = hInstance
        wc.hIcon = nil
        wc.hCursor = user32.LoadCursorA(nil, ffi.cast("LPCSTR", ffi.C.IDC_ARROW))
        wc.hbrBackground = gdi32.GetStockObject(ffi.C.WHITE_BRUSH)
        wc.lpszMenuName = nil
        wc.lpszClassName = classBuf
        wc.hIconSm = nil

        local atom = user32.RegisterClassExW(wc)
        if atom == 0 then
            local err = tonumber(kernel32.GetLastError())
            -- ERROR_CLASS_ALREADY_EXISTS = 1410: class already registered, can continue
            if err ~= 1410 then
                return nil, "RegisterClassExW failed, lastError=" .. tostring(err)
            end
        end

        hwnd = user32.CreateWindowExW(0, classBuf, titleW, style,
            x, y, width, height, nil, nil, hInstance, nil)
    else
        local classBuf = ffi.new("char[?]", #className + 1, className)
        local titleBuf = ffi.new("char[?]", #title + 1, title)

        local wc = ffi.new("WNDCLASSEXA")
        wc.cbSize = ffi.sizeof("WNDCLASSEXA")
        wc.style = 3
        wc.lpfnWndProc = wndProcRef
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = hInstance
        wc.hIcon = nil
        wc.hCursor = user32.LoadCursorA(nil, ffi.cast("LPCSTR", ffi.C.IDC_ARROW))
        wc.hbrBackground = gdi32.GetStockObject(ffi.C.WHITE_BRUSH)
        wc.lpszMenuName = nil
        wc.lpszClassName = classBuf
        wc.hIconSm = nil

        local atom = user32.RegisterClassExA(wc)
        if atom == 0 then
            local err = tonumber(kernel32.GetLastError())
            -- ERROR_CLASS_ALREADY_EXISTS = 1410: class already registered, can continue
            if err ~= 1410 then
                return nil, "RegisterClassExA failed, lastError=" .. tostring(err)
            end
        end

        hwnd = user32.CreateWindowExA(0, classBuf, titleBuf, style,
            x, y, width, height, nil, nil, hInstance, nil)
    end

    if not ptrOK(hwnd) then
        return nil, "CreateWindowEx failed, lastError=" .. tostring(kernel32.GetLastError())
    end

    -- Record window info (needed by processMessages / WM_PAINT)
    window._created[hwnd] = info

    user32.ShowWindow(hwnd, ffi.C.SW_SHOW)
    user32.UpdateWindow(hwnd)

    return hwnd
end

---Destroy a window created by this module (Win32 or SDL).
---@param handle userdata The window handle returned by CreateWindow / CreateWindowSDL
---@return boolean ok true on success
function window.DestroyWindow(handle)
    if not handle then return false end
    if isOurSDLWindow(handle) then
        return window.DestroyWindowSDL(handle)
    end
    if is_windows and user32 and ffi then
        local ok = user32.DestroyWindow(handle)
        window._created[handle] = nil
        return ok ~= 0
    end
    return false
end

-- SDL constants (matching the SDL3 headers)
local SDL_INIT_VIDEO          = 0x00000020
local SDL_WINDOW_BORDERLESS   = 0x00000010
local SDL_WINDOW_RESIZABLE    = 0x00000020
local SDL_WINDOWPOS_CENTERED  = 0x2FFF0000
local SDL_PIXELFORMAT_RGBA32       = 0x16762004 -- little-endian = ABGR8888, memory byte order R,G,B,A (matches LÖVE rgba8)
local SDL_TEXTUREACCESS_STREAMING  = 1

-- SDL event-watch callback: detects a close request for a child window (X button).
-- Only marks it as pending; does NOT destroy the window inside the SDL event context to avoid re-entrancy issues.
-- Close-request grace period (seconds): LÖVE 12 sends a spurious close-request shortly after
-- a foreign window is created; ignore close requests within this window of creation time.
local SDL_CLOSE_GRACE = 2.0

local function sdlEventWatch(userdata, event)
    local ok, res = pcall(function()
        if event == nil then return end
        local u = ffi.cast("uint32_t*", event)
        local etype = u[0]
        if etype == ffi.C.SDL_EVENT_WINDOW_CLOSE_REQUESTED then
            -- SDL_WindowEvent layout (uint32 indices): [0]=type [4]=windowID(off16) [5]=data1 [6]=data2
            local wid = u[4]
            for win, info in pairs(window._sdlWindows) do
                if sdl.SDL_GetWindowID(win) == wid then
                    -- Skip the spurious early close-request so the child does not self-close;
                    -- an explicit SDLSimulateClose() sets forceClose to bypass the grace period.
                    if info.forceClose or (os.clock() - (info.createdAt or 0) >= SDL_CLOSE_GRACE) then
                        window._sdlClosePending[win] = true
                    end
                    break
                end
            end
        elseif etype == ffi.C.SDL_EVENT_WINDOW_FOCUS_GAINED or etype == ffi.C.SDL_EVENT_WINDOW_FOCUS_LOST then
            -- SDL_WindowEvent layout: windowID at offset 16 (u[4])
            local wid = u[4]
            for win, info in pairs(window._sdlWindows) do
                if sdl.SDL_GetWindowID(win) == wid then
                    info.focused = (etype == ffi.C.SDL_EVENT_WINDOW_FOCUS_GAINED)
                    break
                end
            end
        elseif etype == ffi.C.SDL_EVENT_KEY_DOWN or etype == ffi.C.SDL_EVENT_KEY_UP then
            -- Parse with the real SDL_KeyboardEvent struct so field offsets are always correct
            local kev = ffi.cast("SDL_KeyboardEvent*", event)
            local wid = kev.windowID
            local key = kev.key
            local scancode = kev.scancode
            local down = kev.down ~= 0
            local repeat_ = kev.repeat_ ~= 0
            -- Forward keys when: ① the child window has keyboard focus, OR
            -- ② the mouse is hovering this child window (fallback if OS focus was never granted).
            local hoverWin = window._sdlHover
            for win, cb in pairs(window._sdlKeyCallbacks) do
                if sdl.SDL_GetWindowID(win) == wid or (hoverWin ~= nil and win == hoverWin) then
                    cb(key, scancode, down, repeat_)
                end
            end
        elseif etype == ffi.C.SDL_EVENT_MOUSE_MOTION then
            local mev = ffi.cast("SDL_MouseMotionEvent*", event)
            local hovered = false
            for win, cb2 in pairs(window._sdlMouseCallbacks) do
                if cb2.motion and sdl.SDL_GetWindowID(win) == mev.windowID then
                    pcall(cb2.motion, mev.x, mev.y, mev.xrel, mev.yrel)
                    window._sdlHover = win
                    hovered = true
                    break
                end
            end
            -- Clear hover when the cursor leaves the managed windows (e.g. back over the main window)
            if not hovered then
                window._sdlHover = nil
            end
        elseif etype == ffi.C.SDL_EVENT_MOUSE_BUTTON_DOWN or etype == ffi.C.SDL_EVENT_MOUSE_BUTTON_UP then
            local bev = ffi.cast("SDL_MouseButtonEvent*", event)
            for win, cb2 in pairs(window._sdlMouseCallbacks) do
                if cb2.button and sdl.SDL_GetWindowID(win) == bev.windowID then
                    pcall(cb2.button, bev.button, bev.x, bev.y, bev.down ~= 0, bev.clicks)
                end
            end
        elseif etype == ffi.C.SDL_EVENT_MOUSE_WHEEL then
            local wev = ffi.cast("SDL_MouseWheelEvent*", event)
            for win, cb2 in pairs(window._sdlMouseCallbacks) do
                if cb2.wheel and sdl.SDL_GetWindowID(win) == wev.windowID then
                    pcall(cb2.wheel, wev.x, wev.y)
                end
            end
        end
    end)
    if not ok then
        print("[Windows] EventWatch error: " .. tostring(res))
    end
    return 1 -- 1 = keep the event; 0 = remove it from the queue
end

-- Ensure the event watch is registered (idempotent)
local function ensureSdlEventWatch()
    if not sdl then return end
    if sdlEventWatchRef == nil then
        local ok, err = pcall(function()
            sdlEventWatchRef = ffi.cast("SDL_EventFilter", sdlEventWatch)
            sdl.SDL_AddEventWatch(sdlEventWatchRef, nil)
        end)
        if not ok then
            sdlEventWatchRef = nil
            print("[Windows] SDL_AddEventWatch failed: " .. tostring(err))
        end
    end
end

---Create a native window using SDL3 (recommended: LÖVE 12 bundles SDL3 on every platform,
---SDL handles the event/message loop internally). Works on Windows, macOS and Linux.
---@param opts? CreateWindowOptions
---@return userdata|nil win The SDL_Window* handle, or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindowSDL(opts)
    opts = opts or {}
    if not sdl then
        return nil, "SDL3 not found (requires LÖVE 12)."
    end
    if is_mobile then
        -- SDL can create a "window" on Android/iOS but there is no window manager to host a
        -- second top-level window, and no second GL context to render into.
        return nil, "native child windows are not supported on " .. tostring(os_name) .. "."
    end

    sdl.SDL_Init(SDL_INIT_VIDEO) -- already initialized by LÖVE; repeated calls are safe
    ensureSdlEventWatch()        -- register the event watch (detect child-window X close)

    local title = opts.title or "SDL Window"
    local w = opts.width or 480
    local h = opts.height or 320

    -- SDL3 windows are shown by default; flags start at 0 and can add resizable/borderless
    local flags = 0
    if opts.resizable then flags = bor(flags, SDL_WINDOW_RESIZABLE) end
    if opts.borderless then flags = bor(flags, SDL_WINDOW_BORDERLESS) end

    local win = sdl.SDL_CreateWindow(title, w, h, flags)
    if not ptrOK(win) then
        return nil, "SDL_CreateWindow failed"
    end

    -- In SDL3, SDL_CreateWindow no longer takes x/y; the position is set separately.
    -- SDL_WINDOWPOS_CENTERED is the SDL sentinel and resolves per platform (macOS/Linux too).
    local x = opts.x or SDL_WINDOWPOS_CENTERED
    local y = opts.y or SDL_WINDOWPOS_CENTERED
    sdl.SDL_SetWindowPosition(win, x, y)
    -- Note: SDL_RaiseWindow is intentionally NOT called here; in this LÖVE 12 build
    -- raising the child window triggered a spurious close-request. Set the position
    -- away from the main window instead (or call SDL_RaiseWindow manually if needed).

    -- Create a renderer (SDL3: passing NULL for the name uses the default renderer)
    local renderer = sdl.SDL_CreateRenderer(win, nil)
    if not ptrOK(renderer) then
        renderer = nil
    end

    window._sdlWindows[win] = {
        renderer = renderer,
        title = title,
        color = opts.color or { 60, 120, 200 },
        createdAt = os.clock(), -- used to ignore spurious early close-requests
    }

    return win
end

---Refresh the SDL native window content with a solid color (call once per frame).
---@param win userdata The SDL_Window* handle
---@param color? integer[] Fill color {r,g,b} (default stored at creation)
---@return boolean ok true on success
function window.SDLRender(win, color)
    local info = window._sdlWindows and window._sdlWindows[win]
    if not info or not info.renderer then return false end
    color = color or info.color
    local r, g, b = color[1] or 60, color[2] or 120, color[3] or 200
    sdl.SDL_SetRenderDrawColor(info.renderer, r, g, b, 255)
    sdl.SDL_RenderClear(info.renderer)
    sdl.SDL_RenderPresent(info.renderer)
    return true
end

---Draw the contents of a LÖVE Canvas into the SDL native window (the core method for drawing content in the second window).
---Pipeline: LÖVE Canvas -> ImageData(RGBA8) -> SDL texture (SDL_UpdateTexture) -> SDL_RenderTexture.
---Usage: draw content with love.graphics onto a canvas, then call this function.
---@param win userdata The SDL_Window* handle
---@param canvas userdata A readable LÖVE Canvas. The SDL texture is reused and only rebuilt when the size changes.
---@return boolean ok true on success
---@note Every-frame calls incur a GPU->CPU readback cost; suitable for UI/preview. Reduce frequency for very large frames.
---@note LÖVE 12 canvases are NOT readable by default: create the canvas with { readable = true } (see DevTool).
function window.SDLPresentCanvas(win, canvas)
    local info = window._sdlWindows and window._sdlWindows[win]
    if not info or not info.renderer then return false end
    if not canvas then return false end

    local w, h = canvas:getDimensions()
    if w <= 0 or h <= 0 then return false end

    -- Reuse the texture; rebuild it only when the size changes
    if not info.canvasTex or info.canvasTexW ~= w or info.canvasTexH ~= h then
        if info.canvasTex then
            sdl.SDL_DestroyTexture(info.canvasTex)
        end
        info.canvasTex = sdl.SDL_CreateTexture(info.renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, w, h)
        info.canvasTexW, info.canvasTexH = w, h
        if not ptrOK(info.canvasTex) then
            info.canvasTex = nil
            return false
        end
    end

    -- LÖVE 12 uses love.graphics.readbackTexture (Canvas:newImageData is deprecated); LÖVE 11 uses newImageData
    local ok, imgdata = pcall(function()
        if love.graphics.readbackTexture then
            return love.graphics.readbackTexture(canvas)
        end
        return canvas:newImageData(0, 0, w, h)
    end)
    if not ok or not imgdata or type(imgdata.getString) ~= "function" then
        -- Fall back to the older API (LÖVE 11)
        ok, imgdata = pcall(function()
            return canvas:newImageData(0, 0, w, h)
        end)
        if not ok or not imgdata then return false end
    end

    local raw = imgdata:getString() -- RGBA8 byte order (matches SDL_PIXELFORMAT_RGBA32)
    local pitch = w * 4
    sdl.SDL_UpdateTexture(info.canvasTex, nil, raw, pitch)
    sdl.SDL_RenderTexture(info.renderer, info.canvasTex, nil, nil)
    sdl.SDL_RenderPresent(info.renderer)
    return true
end

---Destroy an SDL native window (also cleans up its renderer and textures).
---@param win userdata The SDL_Window* handle
---@return boolean ok true on success
function window.DestroyWindowSDL(win)
    if not win then return false end
    if not sdl then return false end
    local info = window._sdlWindows and window._sdlWindows[win]
    if info and info.renderer then
        sdl.SDL_DestroyRenderer(info.renderer)
    end
    if info and info.canvasTex then
        sdl.SDL_DestroyTexture(info.canvasTex)
    end
    sdl.SDL_DestroyWindow(win)
    if window._sdlWindows then window._sdlWindows[win] = nil end
    if window._sdlClosePending then window._sdlClosePending[win] = nil end
    if window._sdlKeyCallbacks then window._sdlKeyCallbacks[win] = nil end
    if window._sdlMouseCallbacks then window._sdlMouseCallbacks[win] = nil end
    if window._sdlHover == win then window._sdlHover = nil end
    return true
end

---Get the SDL window ID (for debugging / event handling).
---@param win userdata The SDL_Window* handle
---@return integer|nil id The SDL window ID, or nil
function window.SDLGetWindowID(win)
    if not sdl or not win then return nil end
    return sdl.SDL_GetWindowID(win)
end

---Find the SDL_Window* of the main LÖVE window (the first SDL window this module did not create).
---@return userdata|nil win The SDL_Window* handle, or nil
function window.getMainWindowSDL()
    if not sdl then return nil end
    local ok, res = pcall(function()
        local count = ffi.new("int[1]")
        local arr = sdl.SDL_GetWindows(count)
        if not ptrOK(arr) then return nil end
        for i = 0, tonumber(count[0]) - 1 do
            local w = arr[i]
            if ptrOK(w) and window._sdlWindows[w] == nil then
                return w
            end
        end
        return nil
    end)
    if ok then return res end
    return nil
end

-- Native handle properties, in the preferred order per platform. SDL3 exposes the OS-level
-- window object through window properties; the exact key differs per video backend, so every
-- known key is probed (the platform-native one first) and the first hit wins.
local NATIVE_HANDLE_KEYS = {
    win32   = "SDL.window.win32.hwnd",
    cocoa   = "SDL.window.cocoa.window",
    x11     = "SDL.window.x11.window",
    wayland = "SDL.window.wayland.surface",
    android = "SDL.window.android.window",
}

local NATIVE_HANDLE_ORDER
if is_macos then
    NATIVE_HANDLE_ORDER = { "cocoa", "x11", "wayland", "win32", "android" }
elseif is_linux then
    NATIVE_HANDLE_ORDER = { "x11", "wayland", "win32", "cocoa", "android" }
elseif is_android then
    NATIVE_HANDLE_ORDER = { "android", "wayland", "x11", "cocoa", "win32" }
else
    NATIVE_HANDLE_ORDER = { "win32", "cocoa", "x11", "wayland", "android" }
end

---Get the OS-level window handle behind an SDL window.
---Windows -> HWND, macOS -> NSWindow*, Linux/X11 -> XID (a number), Wayland -> wl_surface*,
---Android -> ANativeWindow*. Note that on X11/Wayland this is the SDL *client* window: the
---handle belongs to the current process and must not be sent to another process.
---@param win userdata The SDL_Window* handle
---@param backend? string Force a specific backend ("win32" / "cocoa" / "x11" / "wayland" / "android")
---@return userdata|integer|nil handle The native handle, or nil if the backend exposes none
---@return string|nil kind Which backend the handle came from
function window.SDLGetNativeHandle(win, backend)
    if not (sdl and win and ffi) then return nil end
    local props = sdl.SDL_GetWindowProperties(win)
    if not ptrOK(props) then return nil end

    for _, kind in ipairs(NATIVE_HANDLE_ORDER) do
        if backend == nil or backend == kind then
            local key = NATIVE_HANDLE_KEYS[kind]
            -- X11 stores a number, the others a pointer; try both so a backend change does
            -- not silently break the lookup.
            local num = sdl.SDL_GetNumberProperty(props, key, 0)
            if num ~= nil and tonumber(num) ~= nil and tonumber(num) ~= 0 then
                return tonumber(num), kind
            end
            local ptr = sdl.SDL_GetPointerProperty(props, key, nil)
            if ptrOK(ptr) then
                return ptr, kind
            end
        end
    end
    return nil
end

---Simulate a real close request for a child window (equivalent to clicking the X button).
---Windows: sends WM_CLOSE to the native HWND, so it goes through the exact same path as a real
---X click (SDL converts WM_CLOSE to SDL_EVENT_WINDOW_CLOSE_REQUESTED, which the event watch
---detects). Other platforms have no portable "send WM_CLOSE", and this LÖVE build is known to
---be fragile about synthetic events injected into a foreign window's queue, so the default
---marks the window close-pending directly — which is exactly what the polling caller observes.
---Pass method = "event" to force the synthetic SDL event route instead.
---@param win userdata The SDL_Window* handle
---@param method? string "auto" (default) / "native" (WM_CLOSE, Windows only) / "event" (synthetic SDL event) / "flag" (mark pending directly)
---@return boolean ok true when a close was requested
---@return string|nil used Which route was taken ("native" / "event" / "flag"), nil on failure
function window.SDLSimulateClose(win, method)
    if not win then return false, nil end
    ensureSdlEventWatch()
    method = method or "auto"

    if method == "auto" or method == "native" then
        if is_windows and ffi and user32 then
            local hwnd = window.SDLGetNativeHandle(win, "win32")
            if ptrOK(hwnd) then
                local info = window._sdlWindows[win]
                if info then info.forceClose = true end -- bypass the creation-time grace period
                user32.SendMessageW(hwnd, ffi.C.WM_CLOSE, 0, 0)
                return true, "native"
            end
        end
        if method == "native" then return false, nil end
    end

    if method == "event" then
        -- Build the {type, reserved, timestamp, windowID, data1, data2} head of an SDL_Event.
        -- The buffer is over-sized (SDL's SDL_Event size varies between builds) and zero-filled,
        -- so SDL never reads uninitialised memory.
        local ok = pcall(function()
            local buf = ffi.new("uint8_t[256]")
            local ev = ffi.cast("SDL_WindowEvent*", buf)
            ev.type = ffi.C.SDL_EVENT_WINDOW_CLOSE_REQUESTED
            ev.windowID = sdl.SDL_GetWindowID(win)
            sdl.SDL_PushEvent(ffi.cast("void*", buf))
        end)
        if ok then return true, "event" end
        return false, nil
    end

    -- Portable fallback: mark it as close-pending; the caller destroys the window in its update.
    local info = window._sdlWindows[win]
    if info then info.forceClose = true end
    window._sdlClosePending[win] = true
    return true, "flag"
end

---Register a keyboard callback for a specific SDL child window.
---The callback fires only for keys pressed while THAT window has keyboard focus
---(this is per-window, NOT global; LÖVE's love.keypressed only sees the main window).
---@param win userdata The SDL_Window* handle
---@param callback? fun(key: integer, scancode: integer, isDown: boolean, isRepeat: boolean) Callback for key events; pass nil to remove.
---@return boolean ok true if registered (or removed)
function window.SDLSetKeyCallback(win, callback)
    if not sdl or not win then return false end
    ensureSdlEventWatch()
    if callback then
        window._sdlKeyCallbacks[win] = callback
    else
        window._sdlKeyCallbacks[win] = nil
    end
    return true
end

---Register mouse / wheel callbacks for a specific SDL child window.
---Callbacks only fire while that window is hovered / focused (like keys, this is
---per-window, NOT global). Coordinates are in the window's client (pixel) space,
---which maps 1:1 to the LÖVE canvas passed to SDLPresentCanvas when sizes match.
---@param win userdata The SDL_Window* handle
---@param callbacks? table|nil Callbacks table { motion, button, wheel } or nil to remove:
---  motion: fun(x:number, y:number, xrel:number, yrel:number)
---  button: fun(button:integer, x:number, y:number, down:boolean, clicks:integer)
---  wheel:  fun(x:number, y:number)  (y>0 = scroll up)
---@return boolean ok true if registered (or removed)
function window.SDLSetMouseCallback(win, callbacks)
    if not sdl or not win then return false end
    ensureSdlEventWatch()
    if callbacks == nil then
        window._sdlMouseCallbacks[win] = nil
    else
        window._sdlMouseCallbacks[win] = callbacks
    end
    return true
end

---Whether the child window has requested to close (X clicked). The DevTool polls
---this in its update; when true it should destroy the window (no auto-destroy here,
---to avoid re-entrancy inside the SDL event context).
---@param win userdata The SDL_Window* handle
---@return boolean pending true if a close request is pending
function window.SDLIsClosePending(win)
    if not sdl or not win then return false end
    return window._sdlClosePending[win] == true
end

---Get the current SDL keyboard modifier state (for shift-aware text input in child windows).
---@return integer modState SDL key modifier bitmask (0x0001=LSHIFT, 0x0002=RSHIFT)
function window.SDLGetModState()
    if not sdl then return 0 end
    local ok, mods = pcall(sdl.SDL_GetModState)
    if ok and mods then return tonumber(mods) or 0 end
    return 0
end

---Whether a child window currently has keyboard focus (tracked from SDL focus events).
---@param win userdata The SDL_Window* handle
---@return boolean focused true if this window has keyboard focus
function window.SDLIsWindowFocused(win)
    if not sdl or not win then return false end
    local info = window._sdlWindows and window._sdlWindows[win]
    return (info and info.focused) or false
end

---Request OS keyboard focus for a child window (called when the user clicks inside it).
---SDL3's entry point for this is SDL_RaiseWindow ("raise ... and gain the input focus",
---emits SDL_EVENT_WINDOW_FOCUS_GAINED on success). The two older names below do not exist
---in current SDL3 builds and are only kept as harmless fallbacks.
---@param win userdata The SDL_Window* handle
---@return boolean ok true if the call was made
function window.SDLSetKeyboardFocus(win)
    if not sdl or not win then return false end
    local function try(name)
        local ok, res = pcall(function() return sdl[name](win) end)
        return ok and res ~= nil and res ~= false and res ~= 0
    end
    for _, name in ipairs({ "SDL_RaiseWindow", "SDL_SetWindowInputFocus", "SDL_SetWindowKeyboardFocus" }) do
        if try(name) then
            window._lastFocusCall = name
            return true
        end
    end
    return false
end

---Name of the SDL entry point that SDLSetKeyboardFocus used last (diagnostics).
---@return string|nil name
function window.SDLFocusCallName()
    return window._lastFocusCall
end

---Which managed child window the mouse is currently hovering over (used to decide
---whether main-window key presses should be forwarded to that child as a fallback).
---@return userdata|nil win The hovered SDL_Window* handle, or nil
function window.SDLHoveredWin()
    if not sdl then return nil end
    return window._sdlHover
end

---Get the readable name of an SDL keycode (e.g. "C", "Escape", "Space").
---@param key integer SDL keycode (e.g. string.byte("c"))
---@return string|nil name Key name, or nil
function window.SDLKeyName(key)
    if not sdl then return nil end
    local p = sdl.SDL_GetKeyName(key)
    if not ptrOK(p) then return nil end
    return ffi.string(p)
end

-- (No synthetic key-event helper: pushing synthetic key events via SDL_PushEvent can crash
--  this LÖVE 12 / SDL3 build when LÖVE processes events for a foreign window. Real key
--  presses in the focused child window work fine through window.SDLSetKeyCallback.)


-- 8. Transparency


---Set the opacity of a window through SDL (Windows / macOS / Linux).
---Wayland has no compositor-independent way to do this: the call fails there and the
---function reports false.
---@param win userdata The SDL_Window* handle
---@param alpha integer Alpha 0-255 (0 = fully transparent, 255 = opaque)
---@return boolean ok true on success
---@return string|nil errMsg Error message on failure
function window.setWindowOpacity(win, alpha)
    if not sdl or not win then return false, "SDL3 window required" end
    if not isOurSDLWindow(win) then return false, "not a window created by this library" end
    alpha = math.max(0, math.min(255, math.floor((alpha or 255) + 0.5)))
    local ok, res = pcall(function() return sdl.SDL_SetWindowOpacity(win, alpha / 255) end)
    if not ok then return false, "SDL_SetWindowOpacity failed: " .. tostring(res) end
    -- SDL3 returns bool; Wayland (and some drivers) report false for unsupported opacity.
    if res == nil or res == false or res == 0 then
        return false, "SDL_SetWindowOpacity not supported by this video backend"
    end
    return true
end

---Set window transparency (alpha 0-255).
---Accepts either a window created by this module (SDL path on every platform, via
---SDL_SetWindowOpacity) or a Win32 HWND (layered-window API, Windows only).
---@param handle userdata The window handle (SDL_Window* from this module, or an HWND on Windows)
---@param alpha integer Alpha value 0-255
---@return boolean ok true on success
function window.setTransparency(handle, alpha)
    if not handle then return false end
    alpha = math.max(0, math.min(255, math.floor((alpha or 255) + 0.5)))

    if isOurSDLWindow(handle) then
        local ok, err = window.setWindowOpacity(handle, alpha)
        if not ok then print("[Windows] setTransparency: " .. tostring(err)) end
        return ok
    end

    if is_windows and user32 and ffi then
        local exStyle = user32.GetWindowLongA(handle, ffi.C.GWL_EXSTYLE)
        user32.SetWindowLongA(handle, ffi.C.GWL_EXSTYLE, bor(exStyle, ffi.C.WS_EX_LAYERED))
        user32.SetLayeredWindowAttributes(handle, 0, alpha, ffi.C.LWA_ALPHA)
        user32.SetWindowPos(handle, ffi.cast("HWND", ffi.C.HWND_TOP), 0, 0, 0, 0,
            bor(bor(ffi.C.SWP_FRAMECHANGED, ffi.C.SWP_NOMOVE), ffi.C.SWP_NOSIZE))
        return true
    end

    if sdl then
        -- Non-Windows: the only sensible interpretation of a non-SDL handle is an SDL_Window*
        local ok, err = window.setWindowOpacity(handle, alpha)
        if not ok then print("[Windows] setTransparency: " .. tostring(err)) end
        return ok
    end

    print("[Windows] setTransparency: no usable backend on " .. tostring(os_name) .. ".")
    return false
end

---Set the background transparent, or use a colour key on Windows.
---@param handle userdata The window handle (SDL_Window* from this module, or an HWND on Windows)
---@param colorKey? integer Color key (RGB) or nil for alpha-based transparency
---@param alpha? integer Alpha value 0-255
---@return boolean ok true on success
---@note The colour key is a Win32 layered-window feature; on macOS/Linux the call degrades to
---      plain alpha (the colour key is ignored and warned about once).
function window.setBackgroundTransparent(handle, colorKey, alpha)
    if not handle then return false end

    if is_windows and not isOurSDLWindow(handle) and user32 and ffi then
        local exStyle = user32.GetWindowLongA(handle, ffi.C.GWL_EXSTYLE)
        user32.SetWindowLongA(handle, ffi.C.GWL_EXSTYLE, bor(exStyle, ffi.C.WS_EX_LAYERED))

        if colorKey then
            user32.SetLayeredWindowAttributes(handle, colorKey, alpha or 0, ffi.C.LWA_COLORKEY)
        else
            user32.SetLayeredWindowAttributes(handle, 0, alpha or 0, ffi.C.LWA_ALPHA)
        end

        user32.SetWindowPos(handle, ffi.cast("HWND", ffi.C.HWND_TOP), 0, 0, 0, 0,
            bor(bor(ffi.C.SWP_FRAMECHANGED, ffi.C.SWP_NOMOVE), ffi.C.SWP_NOSIZE))
        return true
    end

    if colorKey and not window._colorKeyWarned then
        window._colorKeyWarned = true
        print("[Windows] setBackgroundTransparent: colour keys are Windows-only; using alpha on " .. tostring(os_name) .. ".")
    end
    return window.setTransparency(handle, alpha or 0)
end


-- 9. Screenshot


local function pack_u16_le(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end

local function pack_u32_le(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

---@return integer|nil size Byte size of the file, or nil when it does not exist
local function fileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

---Run a shell command and report whether it succeeded.
---Handles both os.execute conventions (5.1 returns the exit code, 5.2+ returns true/nil).
---@param cmd string
---@return boolean ok
local function runCommand(cmd)
    local ok = os.execute(cmd .. ' >/dev/null 2>&1')
    return ok == 0 or ok == true
end

---@param bin string
---@return boolean exists
local function commandExists(bin)
    if not bin or bin == "" then return false end
    return runCommand("command -v " .. bin)
end

---Windows implementation: GDI Blit from a window/screen DC into a bottom-up 24bpp BMP.
local function saveScreenshotWin32(x, y, w, h, path, throughWindow)
    if not (ffi and user32 and gdi32) then
        return false, "Win32 GDI libraries unavailable"
    end

    local owner = nil
    local hdcSrc
    if throughWindow then
        local hwnd = window.getHandle()
        if not hwnd then return false, "window handle not found" end
        owner = hwnd
        hdcSrc = user32.GetDC(hwnd)
        if not ptrOK(hdcSrc) then return false, "GetDC(hwnd) failed" end
    else
        hdcSrc = user32.GetDC(nil)
        if not ptrOK(hdcSrc) then return false, "GetDC(NULL) failed" end
    end

    local hdcMem, hBitmap
    local function cleanup()
        if hBitmap then gdi32.DeleteObject(hBitmap) end
        if hdcMem then gdi32.DeleteDC(hdcMem) end
        if hdcSrc then user32.ReleaseDC(owner, hdcSrc) end
    end

    hdcMem = gdi32.CreateCompatibleDC(hdcSrc)
    if not ptrOK(hdcMem) then cleanup(); return false, "CreateCompatibleDC failed" end

    hBitmap = gdi32.CreateCompatibleBitmap(hdcSrc, w, h)
    if not ptrOK(hBitmap) then cleanup(); return false, "CreateCompatibleBitmap failed" end

    gdi32.SelectObject(hdcMem, hBitmap)
    gdi32.BitBlt(hdcMem, 0, 0, w, h, hdcSrc, x, y, ffi.C.SRCCOPY)

    local bmi = ffi.new("BITMAPINFO")
    bmi.bmiHeader.biSize = ffi.sizeof("BITMAPINFOHEADER")
    bmi.bmiHeader.biWidth = w
    bmi.bmiHeader.biHeight = h
    bmi.bmiHeader.biPlanes = 1
    bmi.bmiHeader.biBitCount = 24
    bmi.bmiHeader.biCompression = ffi.C.BI_RGB

    -- BMP rows are padded to a 4-byte boundary
    local rowSize = math.floor((24 * w + 31) / 32) * 4
    local imageSize = rowSize * h
    bmi.bmiHeader.biSizeImage = imageSize

    local pixelData = ffi.new("uint8_t[?]", imageSize)
    local ret = gdi32.GetDIBits(hdcMem, hBitmap, 0, h, pixelData, bmi, 0)
    if ret == 0 then
        cleanup()
        return false, "GetDIBits failed"
    end

    local file, openErr = io.open(path, "wb")
    if not file then
        cleanup()
        return false, "cannot open output file: " .. tostring(openErr)
    end
    file:write("BM")
    file:write(pack_u32_le(54 + imageSize))  -- bfSize
    file:write(pack_u32_le(0))               -- bfReserved
    file:write(pack_u32_le(54))              -- bfOffBits

    file:write(pack_u32_le(40))              -- biSize
    file:write(pack_u32_le(w))
    file:write(pack_u32_le(h))
    file:write(pack_u16_le(1))
    file:write(pack_u16_le(24))
    file:write(pack_u32_le(ffi.C.BI_RGB))
    file:write(pack_u32_le(imageSize))
    file:write(pack_u32_le(0))
    file:write(pack_u32_le(0))
    file:write(pack_u32_le(0))
    file:write(pack_u32_le(0))

    file:write(ffi.string(pixelData, imageSize))
    file:close()

    cleanup()
    return true
end

---Linux/macOS screen grabbers, tried in order until one exists and writes the file.
---@type table[] { bin = <executable>, fmt = <string.format template: x, y, w, h, path> }
local UNIX_GRABBERS = is_macos and {
    { bin = "screencapture", fmt = 'screencapture -x -R"%d,%d,%d,%d" "%s"' }, -- -x: no shutter sound
} or {
    { bin = "grim",      fmt = 'grim -g "%d,%d %dx%d" "%s"' },                      -- Wayland (sway / Hyprland)
    { bin = "spectacle", fmt = 'spectacle --background --nonotify --region %d,%d,%d,%d --output "%s"' }, -- KDE
    { bin = "scrot",     fmt = 'scrot -a %d,%d,%d,%d "%s"' },                       -- X11
    { bin = "maim",      fmt = 'maim -g %dx%d+%d+%d "%s"' },                        -- X11
    { bin = "import",    fmt = 'import -window root -crop %dx%d+%d+%d "%s"' },      -- ImageMagick (X11)
}

---Unix implementation: shell out to a screen grabber.
---There is no portable "grab this window's pixels even when occluded" call (macOS has
---`screencapture -l<windowid>` but the SDL handle is not a window ID), so `throughWindow`
---is ignored here and a screen-region grab is performed instead.
local function saveScreenshotUnix(x, y, w, h, path)
    local tried = {}
    for _, grabber in ipairs(UNIX_GRABBERS) do
        if commandExists(grabber.bin) then
            local before = fileSize(path)
            local cmd = string.format(grabber.fmt, x, y, w, h, path)
            local ok = runCommand(cmd)
            local size = fileSize(path)
            if size and size > 0 and (ok or size ~= before) then
                return true
            end
            tried[#tried + 1] = grabber.bin .. (ok and " (wrote no data)" or " (failed)")
        else
            tried[#tried + 1] = grabber.bin .. " (not installed)"
        end
    end

    local suffix = is_macos and " (macOS also needs Screen Recording permission)" or ""
    return false, "no usable screen grabber" .. suffix .. ": " .. table.concat(tried, "; ")
end

---Save a screenshot of a region.
---@param x integer X coordinate (screen coordinates)
---@param y integer Y coordinate (screen coordinates)
---@param w integer Width
---@param h integer Height
---@param path string Output file path (BMP on Windows, whatever the system tool writes elsewhere — usually PNG)
---@param throughWindow? boolean Windows: true = capture the window (works even if occluded), false = capture the screen region. Other platforms: always a screen-region grab (no portable equivalent).
---@return boolean ok true on success
---@return string|nil errMsg Error message on failure
function window.saveScreenshot(x, y, w, h, path, throughWindow)
    if type(path) ~= "string" or path == "" then
        return false, "output path required"
    end

    if is_windows then
        return saveScreenshotWin32(x, y, w, h, path, throughWindow)
    end
    if is_macos or is_linux then
        return saveScreenshotUnix(x, y, w, h, path)
    end
    return false, "Unsupported platform for screenshots: " .. tostring(os_name)
end


-- 10. Dialogs & platform queries


---Show a dialog (cross-platform, uses LÖVE's showMessageBox).
---@param message string The message text
---@param buttons? string[] Button labels (default {"OK"})
---@param title? string Dialog title (default "Notice")
---@return integer|nil pressed Index of the pressed button
function window.showDialog(message, buttons, title)
    title = title or "Notice"
    if type(buttons) ~= "table" or #buttons == 0 then
        buttons = {"OK"}
    end
    local showMessageBox
    if SE and SE.window and SE.window.showMessageBox then
        showMessageBox = SE.window.showMessageBox
    elseif love and love.window and love.window.showMessageBox then
        showMessageBox = love.window.showMessageBox
    else
        print("[Windows] showDialog: no message box backend available.")
        return nil
    end
    local ok, pressed = pcall(showMessageBox, title, message, buttons, "info", true)
    if not ok then
        print("[Windows] showDialog failed: " .. tostring(pressed))
        return nil
    end
    return pressed
end

---Whether the current OS is Windows.
---@return boolean isWindows true on Windows
function window.isWindows()
    return is_windows
end

---Whether the current OS is macOS.
---@return boolean isMacOS true on macOS
function window.isMacOS()
    return is_macos
end

---Whether the current OS is Linux.
---@return boolean isLinux true on Linux
function window.isLinux()
    return is_linux
end

---Whether the current OS is a mobile platform (Android / iOS).
---@return boolean isMobile true on Android or iOS
function window.isMobile()
    return is_mobile
end

---Whether the current OS is a desktop platform (Windows / macOS / Linux).
---@return boolean isDesktop true on Windows, macOS or Linux
function window.isDesktop()
    return is_desktop
end

return window
