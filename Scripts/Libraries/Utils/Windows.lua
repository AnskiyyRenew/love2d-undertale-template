-- window.lua (merged & fixed)
-- Provides: getHandle, processMessages, setTransparency, setBackgroundTransparent,
-- saveScreenshot, showDialog, CreateWindow (Win32 + SDL3 based implementation)

---@class WindowsLib
---Windows utility library: Win32 + SDL3 native window helpers for LÖVE.
local window = {}

local ffi, bit, user32, gdi32, kernel32, sdl
local os_name = SE.system.getOS()
local is_windows = os_name == "Windows"
local is_linux = os_name == "Linux"
local is_macos = os_name == "OS X"

if is_windows then
    ffi = require("ffi")
    bit = require("bit")
    user32 = ffi.load("user32")
    gdi32 = ffi.load("gdi32")
    -- GetModuleHandle/GetLastError/GetCurrentProcessId live in kernel32, not user32
    kernel32 = ffi.load("kernel32")

    -- LÖVE 12 bundles SDL3.dll; using SDL to create native windows is more stable
    -- (no manual Win32 message loop required)
    local ok_sdl, sdl_or_err = pcall(ffi.load, "SDL3")
    if ok_sdl then
        sdl = sdl_or_err
    end

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
        void* GetModuleHandleW(const wchar_t* lpModuleName);
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
        void* LoadCursorW(HINSTANCE hInstance, const wchar_t* lpCursorName);
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

        // CreateWindow support
        static const int CS_HREDRAW = 0x0002;
        static const int CS_VREDRAW = 0x0001;
        static const int WHITE_BRUSH = 0;
        static const int SW_SHOW = 5;
        static const int TRANSPARENT = 1;

        int ShowWindow(HWND hWnd, int nCmdShow);
        BOOL UpdateWindow(HWND hWnd);
        BOOL DestroyWindow(HWND hWnd);
        BOOL GetClientRect(HWND hWnd, RECT* lpRect);
        int FillRect(HDC hdc, const RECT* lprc, void* hbr);
        DWORD SetTextColor(HDC hdc, DWORD color);
        int SetBkMode(HDC hdc, int iBkMode);
        BOOL TextOutA(HDC hdc, int x, int y, const char* lpString, int c);
        BOOL TextOutW(HDC hdc, int x, int y, const wchar_t* lpString, int c);

        // SDL3 (bundled with LÖVE 12): create native windows without a manual Win32 message loop
        typedef struct SDL_Window SDL_Window;
        typedef struct SDL_Renderer SDL_Renderer;

        int SDL_Init(unsigned int flags);
        SDL_Window* SDL_CreateWindow(const char* title, int w, int h, unsigned int flags);
        void SDL_SetWindowPosition(SDL_Window* window, int x, int y);
        void SDL_DestroyWindow(SDL_Window* window);
        SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, const char* name);
        void SDL_DestroyRenderer(SDL_Renderer* renderer);
        int SDL_RenderClear(SDL_Renderer* renderer);
        int SDL_RenderPresent(SDL_Renderer* renderer);
        int SDL_SetRenderDrawColor(SDL_Renderer* renderer, unsigned char r, unsigned char g, unsigned char b, unsigned char a);
        unsigned int SDL_GetWindowFlags(SDL_Window* window);

        // SDL3 textures (for uploading LÖVE Canvas content to the second window)
        typedef struct SDL_Texture SDL_Texture;
        typedef struct { int x; int y; int w; int h; } SDL_Rect;

        SDL_Texture* SDL_CreateTexture(SDL_Renderer* renderer, unsigned int format, int access, int w, int h);
        void SDL_DestroyTexture(SDL_Texture* texture);
        int SDL_UpdateTexture(SDL_Texture* texture, const SDL_Rect* rect, const void* pixels, int pitch);
        int SDL_RenderTexture(SDL_Renderer* renderer, SDL_Texture* texture, const SDL_Rect* srcrect, const SDL_Rect* dstrect);
        void SDL_RaiseWindow(SDL_Window* window);

        // SDL3 event watch: detect close-requested (X) for child windows
        typedef unsigned int SDL_WindowID;
        typedef int (*SDL_EventFilter)(void* userdata, void* event);

        SDL_WindowID SDL_GetWindowID(SDL_Window* window);
        int SDL_AddEventWatch(SDL_EventFilter filter, void* userdata);
        void SDL_DelEventWatch(SDL_EventFilter filter, void* userdata);
        int SDL_PushEvent(const void* event);
        const char* SDL_GetKeyName(int key);
        unsigned int SDL_GetModState(void);
        int SDL_SetWindowKeyboardFocus(SDL_Window* window);
        void* SDL_GetWindowProperties(SDL_Window* window);
        void* SDL_GetPointerProperty(void* props, const char* name, void* default_value);

        // Win32: send WM_CLOSE to the native HWND to trigger a real close request
        intptr_t SendMessageW(void* hWnd, unsigned int Msg, uintptr_t wParam, intptr_t lParam);

        static const int SDL_EVENT_WINDOW_CLOSE_REQUESTED = 0x20F;
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

        // Window keyboard-focus events (SDL3 numbering: FOCUS_GAINED=0x20D, FOCUS_LOST=0x20E)
        static const int SDL_EVENT_WINDOW_FOCUS_GAINED = 0x20D;
        static const int SDL_EVENT_WINDOW_FOCUS_LOST = 0x20E;
    ]]
end

-- Module-level persistent objects (critical: keep them alive to avoid GC)
local wndProcRef = nil
local classNameW_ref = nil
window.windowClassRegistered = false
window._created = {}          -- hwnd -> { unicode=bool, className, title, titleW, titleLenW }
window._sdlWindows = {}       -- SDL_Window* -> { renderer, title, color, canvasTex, ... }
window._sdlClosePending = {}  -- SDL_Window* -> true (child window requested close, pending destroy)
window._sdlKeyCallbacks = {}   -- SDL_Window* -> fun(key, scancode, isDown, isRepeat) (fires only when that window has focus)
window._sdlMouseCallbacks = {} -- SDL_Window* -> { motion=fun(x,y,xrel,yrel), button=fun(button,x,y,down,clicks), wheel=fun(x,y) }
window._sdlHover = nil         -- the managed child window the mouse is hovering over (key-forwarding fallback)
local sdlEventWatchRef = nil  -- event-watch callback, kept alive to avoid GC

-- helper: convert a UTF-8 Lua string to a wchar_t buffer (caller must keep the returned buffer alive if needed)
local function utf8_to_wchar(str)
    -- Simple: maps each byte to a wchar (works for ASCII / common Latin)
    local len = #str
    local buf = ffi.new("wchar_t[?]", len + 1)
    for i = 1, len do
        buf[i-1] = string.byte(str, i)
    end
    buf[len] = 0
    return buf
end

---Get the LÖVE window handle (Windows: tries several class names and process enumeration).
---@return userdata|nil hwnd The window handle, or nil if not found
function window.getHandle()
    if is_windows then
        local classNames = {"SDL_app", "Love2D", "LÖVE", "GLFW30", "SDL_WindowClass"}
        for _, className in ipairs(classNames) do
            local hwnd = user32.FindWindowA(className, nil)
            if hwnd ~= nil and tonumber(ffi.cast("intptr_t", hwnd)) ~= 0 then
                return hwnd
            end
        end

        -- Fallback: enumerate the current process's windows
        local pid = kernel32.GetCurrentProcessId()
        local hwnd = ffi.cast("HWND", 0)
        while true do
            hwnd = user32.FindWindowExA(nil, hwnd, nil, nil)
            if hwnd == nil or tonumber(ffi.cast("intptr_t", hwnd)) == 0 then break end
            local foundPid = ffi.new("DWORD[1]")
            user32.GetWindowThreadProcessId(hwnd, foundPid)
            if foundPid[0] == pid then
                return hwnd
            end
        end

        return nil
    else
        if SE.window and SE.window.getHandle then
            return SE.window.getHandle()
        end
        return nil
    end
end

---Process the Windows message queue (call regularly on the main thread).
---@param hwnd? userdata If provided, only processes messages for this window (recommended to avoid interfering with the LÖVE main window); nil processes all messages for the current thread.
function window.processMessages(hwnd)
    if not is_windows then return end
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

-- Default window procedure: white background + title text; cleans up records on WM_DESTROY.
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
---Prefer SDL3 (bundled with LÖVE 12, SDL handles the event/message loop internally, most stable);
---falls back to the Win32 CreateWindowEx implementation when SDL is unavailable.
---@param opts? CreateWindowOptions Options (see CreateWindowSDL / CreateWindowWin32)
---@return userdata|nil handle The native window handle (SDL_Window* or HWND), or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindow(opts)
    if sdl then
        return window.CreateWindowSDL(opts)
    end
    return window.CreateWindowWin32(opts)
end

---Create a native window (low-level Win32 implementation, independent of the LÖVE main window).
---@param opts? CreateWindowOptions
---@return userdata|nil hwnd The Win32 window handle, or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindowWin32(opts)
    opts = opts or {}
    if not is_windows then
        return nil, "CreateWindow only supported on Windows."
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
            if err ~= 1410 then
                return nil, "RegisterClassExA failed, lastError=" .. tostring(err)
            end
        end

        hwnd = user32.CreateWindowExA(0, classBuf, titleBuf, style,
            x, y, width, height, nil, nil, hInstance, nil)
    end

    if hwnd == nil or tonumber(ffi.cast("intptr_t", hwnd)) == 0 then
        return nil, "CreateWindowEx failed, lastError=" .. tostring(kernel32.GetLastError())
    end

    -- Record window info (needed by processMessages / WM_PAINT)
    window._created[hwnd] = info

    user32.ShowWindow(hwnd, ffi.C.SW_SHOW)
    user32.UpdateWindow(hwnd)

    return hwnd
end

---Destroy a window created by CreateWindow (Win32 path).
---@param hwnd userdata The Win32 window handle
---@return boolean ok true on success
function window.DestroyWindow(hwnd)
    if not is_windows or not hwnd then return false end
    local ok = user32.DestroyWindow(hwnd)
    window._created[hwnd] = nil
    return ok ~= 0
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
                    -- Skip the spurious early close-request so the child does not self-close
                    if os.clock() - (info.createdAt or 0) >= SDL_CLOSE_GRACE then
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

---Create a native window using SDL3 (recommended: LÖVE 12 bundles SDL3, SDL handles the event/message loop internally).
---@param opts? CreateWindowOptions
---@return userdata|nil win The SDL_Window* handle, or nil on failure
---@return string|nil errMsg Error message when creation fails
function window.CreateWindowSDL(opts)
    opts = opts or {}
    if not is_windows then
        return nil, "CreateWindowSDL only supported on Windows."
    end
    if not sdl then
        return nil, "SDL3.dll not found (requires LÖVE 12)."
    end

    sdl.SDL_Init(SDL_INIT_VIDEO) -- already initialized by LÖVE; repeated calls are safe
    ensureSdlEventWatch()        -- register the event watch (detect child-window X close)

    local title = opts.title or "SDL Window"
    local w = opts.width or 480
    local h = opts.height or 320

    -- SDL3 windows are shown by default; flags start at 0 and can add resizable/borderless
    local flags = 0
    if opts.resizable then flags = bit.bor(flags, SDL_WINDOW_RESIZABLE) end
    if opts.borderless then flags = bit.bor(flags, SDL_WINDOW_BORDERLESS) end

    local win = sdl.SDL_CreateWindow(title, w, h, flags)
    if win == nil or tonumber(ffi.cast("intptr_t", win)) == 0 then
        return nil, "SDL_CreateWindow failed"
    end

    -- In SDL3, SDL_CreateWindow no longer takes x/y; the position is set separately
    local x = opts.x or SDL_WINDOWPOS_CENTERED
    local y = opts.y or SDL_WINDOWPOS_CENTERED
    sdl.SDL_SetWindowPosition(win, x, y)
    -- Note: SDL_RaiseWindow is intentionally NOT called here; in this LÖVE 12 build
    -- raising the child window triggered a spurious close-request. Set the position
    -- away from the main window instead (or call SDL_RaiseWindow manually if needed).

    -- Create a renderer (SDL3: passing NULL for the name uses the default renderer)
    local renderer = sdl.SDL_CreateRenderer(win, nil)
    if renderer == nil or tonumber(ffi.cast("intptr_t", renderer)) == 0 then
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
        if info.canvasTex == nil or tonumber(ffi.cast("intptr_t", info.canvasTex)) == 0 then
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
    return true
end

---Get the SDL window ID (for debugging / event handling).
---@param win userdata The SDL_Window* handle
---@return integer|nil id The SDL window ID, or nil
function window.SDLGetWindowID(win)
    if not sdl or not win then return nil end
    return sdl.SDL_GetWindowID(win)
end

---Get the native Win32 HWND of an SDL window (via SDL3 window properties).
---@param win userdata The SDL_Window* handle
---@return userdata|nil hwnd The native HWND, or nil
function window.SDLGetNativeHandle(win)
    if not sdl or not win then return nil end
    local props = sdl.SDL_GetWindowProperties(win)
    if props == nil or tonumber(ffi.cast("intptr_t", props)) == 0 then return nil end
    return sdl.SDL_GetPointerProperty(props, "SDL.window.win32.hwnd", nil)
end

---Simulate a real close request for a child window (equivalent to clicking the X button).
---Sends WM_CLOSE to the native HWND, so it goes through the exact same path as a real X click
---(SDL converts WM_CLOSE to SDL_EVENT_WINDOW_CLOSE_REQUESTED, which the event watch detects).
---@param win userdata The SDL_Window* handle
---@return boolean ok true if WM_CLOSE was sent
function window.SDLSimulateClose(win)
    if not sdl or not win then return false end
    ensureSdlEventWatch()
    local hwnd = window.SDLGetNativeHandle(win)
    if hwnd == nil or tonumber(ffi.cast("intptr_t", hwnd)) == 0 then
        return false
    end
    user32.SendMessageW(hwnd, 0x0010, 0, 0) -- WM_CLOSE
    return true
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
---@param win userdata The SDL_Window* handle
---@return boolean ok true if the call was made
function window.SDLSetKeyboardFocus(win)
    if not sdl or not win then return false end
    local ok, res = pcall(sdl.SDL_SetWindowKeyboardFocus, win)
    return (ok and res ~= nil and res ~= false)
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
    if p == nil or tonumber(ffi.cast("intptr_t", p)) == 0 then return nil end
    return ffi.string(p)
end

-- (No synthetic key-event helper: pushing synthetic key events via SDL_PushEvent can crash
--  this LÖVE 12 / SDL3 build when LÖVE processes events for a foreign window. Real key
--  presses in the focused child window work fine through window.SDLSetKeyCallback.)

---Set window transparency on Windows (alpha: 0-255).
---@param hwnd userdata The window handle
---@param alpha integer Alpha value 0-255
---@return boolean ok true on success
function window.setTransparency(hwnd, alpha)
    if not is_windows then
        print("setTransparency only supported on Windows.")
        return false
    end
    if not hwnd then return false end
    local exStyle = user32.GetWindowLongA(hwnd, ffi.C.GWL_EXSTYLE)
    user32.SetWindowLongA(hwnd, ffi.C.GWL_EXSTYLE, bit.bor(exStyle, ffi.C.WS_EX_LAYERED))
    user32.SetLayeredWindowAttributes(hwnd, 0, alpha, ffi.C.LWA_ALPHA)
    user32.SetWindowPos(hwnd, ffi.cast("HWND", ffi.C.HWND_TOP), 0, 0, 0, 0,
        bit.bor(ffi.C.SWP_FRAMECHANGED, ffi.C.SWP_NOMOVE, ffi.C.SWP_NOSIZE))
    return true
end

---Set the background transparent or use a color key on Windows.
---@param hwnd userdata The window handle
---@param colorKey? integer Color key (RGB) or nil for alpha-based transparency
---@param alpha? integer Alpha value 0-255
---@return boolean ok true on success
function window.setBackgroundTransparent(hwnd, colorKey, alpha)
    if not is_windows then
        print("setBackgroundTransparent only supported on Windows.")
        return false
    end
    if not hwnd then return false end
    local exStyle = user32.GetWindowLongA(hwnd, ffi.C.GWL_EXSTYLE)
    user32.SetWindowLongA(hwnd, ffi.C.GWL_EXSTYLE, bit.bor(exStyle, ffi.C.WS_EX_LAYERED))

    if colorKey then
        user32.SetLayeredWindowAttributes(hwnd, colorKey, alpha or 0, ffi.C.LWA_COLORKEY)
    else
        user32.SetLayeredWindowAttributes(hwnd, 0, alpha or 0, ffi.C.LWA_ALPHA)
    end

    user32.SetWindowPos(hwnd, ffi.cast("HWND", ffi.C.HWND_TOP), 0, 0, 0, 0,
        bit.bor(ffi.C.SWP_FRAMECHANGED, ffi.C.SWP_NOMOVE, ffi.C.SWP_NOSIZE))
    return true
end

---Save a screenshot of a region.
---@param x integer X coordinate
---@param y integer Y coordinate
---@param w integer Width
---@param h integer Height
---@param path string Output file path
---@param throughWindow? boolean true = capture the window (Windows only, otherwise fails); false = capture the screen region (macOS/Linux use system tools)
---@return boolean ok true on success
---@return string|nil errMsg Error message on failure
function window.saveScreenshot(x, y, w, h, path, throughWindow)
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

    if is_windows then
        local hdcSrc
        if throughWindow then
            local hwnd = window.getHandle()
            if not hwnd then return false, "window handle not found" end
            hdcSrc = user32.GetDC(hwnd)
            if hdcSrc == nil then return false, "GetDC(hwnd) failed" end
        else
            hdcSrc = user32.GetDC(nil)
            if hdcSrc == nil then return false, "GetDC(NULL) failed" end
        end

        local hdcMem = gdi32.CreateCompatibleDC(hdcSrc)
        if hdcMem == nil then
            user32.ReleaseDC(nil, hdcSrc)
            return false, "CreateCompatibleDC failed"
        end

        local hBitmap = gdi32.CreateCompatibleBitmap(hdcSrc, w, h)
        if hBitmap == nil then
            gdi32.DeleteDC(hdcMem)
            user32.ReleaseDC(nil, hdcSrc)
            return false, "CreateCompatibleBitmap failed"
        end

        gdi32.SelectObject(hdcMem, hBitmap)
        gdi32.BitBlt(hdcMem, 0, 0, w, h, hdcSrc, x, y, ffi.C.SRCCOPY)

        local bmi = ffi.new("BITMAPINFO")
        bmi.bmiHeader.biSize = ffi.sizeof("BITMAPINFOHEADER")
        bmi.bmiHeader.biWidth = w
        bmi.bmiHeader.biHeight = h
        bmi.bmiHeader.biPlanes = 1
        bmi.bmiHeader.biBitCount = 24
        bmi.bmiHeader.biCompression = ffi.C.BI_RGB

        local rowSize = math.floor((bmi.bmiHeader.biBitCount * w + 31) / 32) * 4
        local imageSize = rowSize * h
        bmi.bmiHeader.biSizeImage = imageSize

        local pixelData = ffi.new("uint8_t[?]", imageSize)
        local ret = gdi32.GetDIBits(hdcMem, hBitmap, 0, h, pixelData, bmi, 0)
        if ret == 0 then
            gdi32.DeleteObject(hBitmap)
            gdi32.DeleteDC(hdcMem)
            user32.ReleaseDC(nil, hdcSrc)
            return false, "GetDIBits failed"
        end

        local file = assert(io.open(path, "wb"))
        file:write("BM")
        file:write(pack_u32_le(54 + imageSize))
        file:write(pack_u32_le(0))
        file:write(pack_u32_le(54))

        file:write(pack_u32_le(40))
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

        gdi32.DeleteObject(hBitmap)
        gdi32.DeleteDC(hdcMem)
        if throughWindow and window.getHandle() then
            user32.ReleaseDC(window.getHandle(), hdcSrc)
        else
            user32.ReleaseDC(nil, hdcSrc)
        end
        return true
    else
        if is_macos then
            local cmd = string.format('screencapture -R%d,%d,%d,%d "%s"', x, y, w, h, path)
            local ok = os.execute(cmd)
            return ok == 0 or ok == true
        elseif is_linux then
            local cmd = string.format('import -window root -crop %dx%d+%d+%d "%s"', w, h, x, y, path)
            local ok = os.execute(cmd)
            return ok == 0 or ok == true
        else
            return false, "Unsupported platform for screenshots"
        end
    end
end

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
    local pressed = SE.window.showMessageBox(title, message, buttons, "info", true)
    return pressed
end

---Whether the current OS is Windows.
---@return boolean isWindows true on Windows
function window.isWindows()
    return is_windows
end

return window
