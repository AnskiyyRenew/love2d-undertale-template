-- window.lua (合并与修复版)
-- 支持: getHandle, processMessages, setTransparency, setBackgroundTransparent,
-- saveScreenshot, showDialog, CreateWindow (Windows 安全实现)
local window = {}
local ffi, bit, user32, gdi32
local os_name = love.system.getOS()
local is_windows = os_name == "Windows"
local is_linux = os_name == "Linux"
local is_macos = os_name == "OS X"

if is_windows then
    ffi = require("ffi")
    bit = require("bit")
    user32 = ffi.load("user32")
    gdi32 = ffi.load("gdi32")

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
        typedef long (__stdcall *WNDPROC)(void* hwnd, unsigned int msg, WPARAM wParam, LPARAM lParam);

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
        long DefWindowProcA(void* hWnd, unsigned int Msg, unsigned long wParam, long lParam);
        long DefWindowProcW(void* hWnd, unsigned int Msg, unsigned long wParam, long lParam);

        void* BeginPaint(void* hwnd, void* lpPaint);
        int EndPaint(void* hwnd, const void* lpPaint);
        void* GetStockObject(int fnObject);
        int Rectangle(void* hdc, int left, int top, int right, int bottom);
        BOOL PeekMessageA(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
        BOOL PeekMessageW(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
        int TranslateMessage(const void* lpMsg);
        long DispatchMessageA(const MSG* lpMsg);
        long DispatchMessageW(const MSG* lpMsg);
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
    ]]
end

-- 模块级持久对象，防止被 GC（非常重要）
local wndProcRef = nil
local classNameW_ref = nil
window.windowClassRegistered = false

-- helper: convert utf-8 Lua string -> wchar_t buffer (persist returned buffer by caller if needed)
local function utf8_to_wchar(str)
    -- 简单实现：把每个 byte 转为 wchar（对 ASCII/常见 Latin 兼容）
    local len = #str
    local buf = ffi.new("wchar_t[?]", len + 1)
    for i = 1, len do
        buf[i-1] = string.byte(str, i)
    end
    buf[len] = 0
    return buf
end

--- 获取 LÖVE 窗口句柄（Windows 尝试多种 class 名称与进程枚举）
function window.getHandle()
    if is_windows then
        local classNames = {"SDL_app", "Love2D", "LÖVE", "GLFW30", "SDL_WindowClass"}
        for _, className in ipairs(classNames) do
            local hwnd = user32.FindWindowA(className, nil)
            if hwnd ~= nil and tonumber(ffi.cast("intptr_t", hwnd)) ~= 0 then
                return hwnd
            end
        end

        -- 枚举当前进程窗口作为后备
        local pid = ffi.C.GetCurrentProcessId()
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
        if love.window and love.window.getHandle then
            return love.window.getHandle()
        end
        return nil
    end
end

--- 处理 Windows 消息队列（需要在主线程定期调用）
function window.processMessages()
    if not is_windows then return end
    local msg = ffi.new("MSG")
    -- PM_REMOVE = 1
    while user32.PeekMessageA(msg, nil, 0, 0, 1) ~= 0 do
        user32.TranslateMessage(msg)
        user32.DispatchMessageA(msg)
    end
end

--- Windows: 设置窗口透明度（alpha: 0-255）
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

--- Windows: 设置背景透明或色键
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

--- 保存指定区域截图
-- throughWindow = true  -> 使用窗口（若 Windows 可用），否则失败
-- throughWindow = false -> 捕获屏幕区域（在 macOS / Linux 使用系统工具）
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

--- 展示对话框（跨平台，使用 LÖVE 的 showMessageBox）
function window.showDialog(message, buttons, title)
    title = title or "提示"
    if type(buttons) ~= "table" or #buttons == 0 then
        buttons = {"OK"}
    end
    local pressed = love.window.showMessageBox(title, message, buttons, "info", true)
    return pressed
end

-- Default WndProc（简单响应 WM_PAINT/WM_DESTROY）
local function DefaultWndProc(hwnd, msg, wParam, lParam)
    if msg == ffi.C.WM_NCCREATE then
        return 1
    elseif msg == ffi.C.WM_CREATE then
        return 0
    elseif msg == ffi.C.WM_PAINT then
        -- 简单示例：不做复杂绘制（BeginPaint/EndPaint 需要 PAINTSTRUCT）
        return 0
    elseif msg == ffi.C.WM_DESTROY then
        user32.PostQuitMessage(0)
        return 0
    end
    return ffi.C.DefWindowProcA(hwnd, msg, wParam, lParam)
end

--- 安全的 CreateWindow（Windows）
-- 注意：尽量避免在 LÖVE 程序里创建额外窗口（与 SDL/OpenGL 可能冲突）。
-- 本函数使用 ANSI/Wide 两套注册/创建；优先使用 Unicode (W) 实现。
function window.CreateWindow(x, y, w, h, title)
    if not is_windows then
        error("CreateWindow: only supported on Windows in this module")
    end
    -- 注册窗口类（只注册一次）
    if not window.windowClassRegistered then
        -- 保存 wndproc 引用以防 GC
        wndProcRef = ffi.cast("WNDPROC", DefaultWndProc)

        -- 保存 class 名称（wchar），避免临时变量被释放
        classNameW_ref = utf8_to_wchar("LuaLoveWindowClass")

        -- 注册 Unicode 类
        local wcw = ffi.new("WNDCLASSEXW")
        wcw.cbSize = ffi.sizeof(wcw)
        wcw.style = 0
        wcw.lpfnWndProc = wndProcRef
        wcw.cbClsExtra = 0
        wcw.cbWndExtra = 0
        wcw.hInstance = ffi.C.GetModuleHandleW(nil)
        wcw.hIcon = nil
        wcw.hCursor = user32.LoadCursorA(nil, ffi.cast("LPCSTR", ffi.C.IDC_ARROW)) -- LoadCursorA works
        wcw.hbrBackground = ffi.cast("void*", ffi.C.BLACK_BRUSH)
        wcw.lpszMenuName = nil
        wcw.lpszClassName = classNameW_ref
        wcw.hIconSm = nil

        local res = ffi.C.RegisterClassExW(wcw)
        if res == 0 then
            -- 可能已经用 ANSI 注册过，尝试 RegisterClassExA 作为回退
            local wca = ffi.new("WNDCLASSEXA")
            wca.cbSize = ffi.sizeof(wca)
            wca.style = 0
            wca.lpfnWndProc = wndProcRef
            wca.cbClsExtra = 0
            wca.cbWndExtra = 0
            wca.hInstance = ffi.C.GetModuleHandleA(nil)
            wca.hIcon = nil
            wca.hCursor = user32.LoadCursorA(nil, ffi.cast("LPCSTR", ffi.C.IDC_ARROW))
            wca.hbrBackground = ffi.cast("void*", ffi.C.BLACK_BRUSH)
            wca.lpszMenuName = nil
            wca.lpszClassName = "LuaLoveWindowClass"
            wca.hIconSm = nil
            local res2 = ffi.C.RegisterClassExA(wca)
            if res2 == 0 then
                local err = ffi.C.GetLastError()
                error("RegisterClassEx failed: " .. tostring(err))
            end
        end

        window.windowClassRegistered = true
    end

    title = title or "Lua Window"
    local titleW = utf8_to_wchar(title)
    -- CreateWindowExW
    local hwnd = ffi.C.CreateWindowExW(
        0,
        classNameW_ref,
        titleW,
        bit.bor(ffi.C.WS_OVERLAPPEDWINDOW, ffi.C.WS_VISIBLE),
        x, y, w, h,
        nil, nil, ffi.C.GetModuleHandleW(nil), nil
    )
    if hwnd == nil or tonumber(ffi.cast("intptr_t", hwnd)) == 0 then
        local err = ffi.C.GetLastError()
        error("CreateWindowExW failed: " .. tostring(err))
    end
    return hwnd
end

-- 兼容调用（如果调用者传入 nil，会返回 false）
function window.isWindows()
    return is_windows
end

return window