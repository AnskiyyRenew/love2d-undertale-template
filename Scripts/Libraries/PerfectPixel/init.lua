local lib_path = package.searchpath(....."/cpp", package.cpath)
--lib_path = nil
if lib_path == nil then
    --error("Cannot find dynamic link library for your os.")
    -- 警告并启用纯 Lua 版本
    print("[Warning]rectangulation: Cannot find dynamic link library for your os. Using pure Lua version.")
    return require(.....".pure")
end

local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        int x, y, w, h;
    } Rect;
    
    typedef struct {
        int num_rects;
        Rect* rects;
    } RectList;
    
    RectList* rectangulate_grid(const uint8_t* grid, int width, int height);
    RectList* rectangulate(const uint8_t* image_data, int width, int height);
    void free_rect_list(RectList* list);
]]

local lib = ffi.load(lib_path)

local re = {}

function re.rectangulate_grid(grid)
    local width, height = #grid, #grid[1]
    local grid_data = ffi.new("uint8_t[?]", width * height)
    for y = 1, height do
        for x = 1, width do
            grid_data[(y-1)*width+x-1] = grid[x][y] == 1 and 2 or 0
        end
    end
    local c_rects = lib.rectangulate_grid(grid_data, width, height)
    local lua_rects = {}
    for i = 0, c_rects.num_rects - 1 do
        local rect = c_rects.rects[i]
        table.insert(lua_rects, {
            rect.x,
            rect.y,
            rect.w,
            rect.h,
        })
    end
    -- 释放 C 层内存
    lib.free_rect_list(c_rects)
    return lua_rects
end

function re.rectangulate(imageData)
    local c_rects = lib.rectangulate(imageData:getFFIPointer(), imageData:getDimensions())
    local lua_rects = {}
    for i = 0, c_rects.num_rects - 1 do
        local rect = c_rects.rects[i]
        table.insert(lua_rects, {
            rect.x,
            rect.y,
            rect.w,
            rect.h,
        })
    end
    -- 释放 * 2
    lib.free_rect_list(c_rects)
    return lua_rects
end

return re
