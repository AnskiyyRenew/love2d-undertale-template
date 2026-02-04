-- 纯 Lua 实现的矩形分解库
local re = {}

local function globalExpandRect(grid)
    local m, n = #grid, #grid[1]
    -- 创建前缀和数组 (行0..m, 列0..n)
    local prefix = {}
    for i = 0, m do
        prefix[i] = {}
        for j = 0, n do
            prefix[i][j] = 0
        end
    end

    -- 填充
    for i = 1, m do
        for j = 1, n do
            local score = (grid[i][j] == 2) and 1 or 0
            prefix[i][j] = score + prefix[i-1][j] + prefix[i][j-1] - prefix[i-1][j-1]
        end
    end

    local max_score = 0
    local best_rect = nil
    local height = {}  -- 高度数组（基于1的列索引）

    -- 初始化
    for j = 1, n do
        height[j] = 0
    end

    -- 遍历每一行
    for i = 1, m do
        -- 更新高度数组
        for j = 1, n do
            if grid[i][j] ~= 0 then
                height[j] = height[j] + 1
            else
                height[j] = 0
            end
        end

        local stack = {}  -- 单调栈（存储列索引）

        -- 遍历当前行的每一列
        for j = 1, n do
            -- 维护单调递增栈
            while #stack > 0 and height[j] < height[stack[#stack]] do
                local k = table.remove(stack)  -- 弹出栈顶元素
                local left = (#stack > 0) and stack[#stack] or 0
                local rect_height = height[k]
                local x1 = i - rect_height + 1  -- 起始行（基于1）
                local x2 = i                     -- 结束行（基于1）
                local y1 = left + 1              -- 起始列（基于1）
                local y2 = j - 1                 -- 结束列（基于1）

                -- 确保矩形有效
                if y1 <= y2 then
                    -- 计算矩形得分
                    local score_here = prefix[x2][y2]
                        - prefix[x1-1][y2]
                        - prefix[x2][y1-1]
                        + prefix[x1-1][y1-1]

                    -- 更新最大得分
                    if score_here > max_score then
                        max_score = score_here
                        best_rect = {
                            x1 - 1,     -- 起始行(基于0)
                            y1 - 1,     -- 起始列(基于0)
                            x2 - x1 + 1,-- 高度（行数）
                            y2 - y1 + 1 -- 宽度（列数）
                        }
                    end
                end
            end
            table.insert(stack, j)  -- 当前列入栈
        end

        -- 处理栈中剩余元素
        while #stack > 0 do
            local k = table.remove(stack)
            local left = (#stack > 0) and stack[#stack] or 0
            local rect_height = height[k]
            local x1 = i - rect_height + 1
            local x2 = i
            local y1 = left + 1
            local y2 = n  -- 边界设为最后一列

            if y1 <= y2 then
                local score_here = prefix[x2][y2]
                    - prefix[x1-1][y2]
                    - prefix[x2][y1-1]
                    + prefix[x1-1][y1-1]

                if score_here > max_score then
                    max_score = score_here
                    best_rect = {
                        x1 - 1,     -- 起始行(基于0)
                        y1 - 1,     -- 起始列(基于0)
                        x2 - x1 + 1,-- 高度（行数）
                        y2 - y1 + 1 -- 宽度（列数）
                    }
                end
            end
        end
    end

    return max_score, best_rect
end

function re.rectangulate_grid(grid)
    local new_grid = {}
    for i = 1, #grid do
        new_grid[i] = {}
        for j = 1, #grid[i] do
            -- visited 和 grid 一体化, 2: 未访问, 1: 访问过, 0: 障碍
            new_grid[i][j] = grid[i][j] == 1 and 2 or 0
        end
    end
    local rects = {}
    while true do
        local score, rect = globalExpandRect(new_grid)
        if score == 0 or rect == nil then
            return rects
        end
        table.insert(rects, rect)
        for i = rect[1] + 1, rect[1] + rect[3] do
            for j = rect[2] + 1, rect[2] + rect[4] do
                new_grid[i][j] = 1
            end
        end
    end
end

function re.rectangulate(imageData)
    local width, height = imageData:getDimensions()
    local new_grid = {}
    for i = 1, width do
        new_grid[i] = {}
        for j = 1, height do
            local r, g, b, a = imageData:getPixel(i - 1, j - 1)
            new_grid[i][j] = a > 0.5 and 2 or 0
        end
    end
    local rects = {}
    while true do
        local score, rect = globalExpandRect(new_grid)
        if score == 0 or rect == nil then
            return rects
        end
        table.insert(rects, rect)
        for i = rect[1] + 1, rect[1] + rect[3] do
            for j = rect[2] + 1, rect[2] + rect[4] do
                new_grid[i][j] = 1
            end
        end
    end
end

--[[

local function print_grid(grid)
    for y = 1, #grid[1] do
        for x = 1, #grid do
            io.write(grid[x][y])
            io.write(" ")
        end
        io.write("\n")
    end
end

local function test_grid(grid)
    local new_grid = {}
    for i = 1, #grid do
        new_grid[i] = {}
        for j = 1, #grid[i] do
            new_grid[i][j] = grid[i][j] == 1 and 2 or 0
        end
    end
    print_grid(new_grid)
    local score, rect = globalExpandRect(new_grid)
    if rect == nil then
        print("score="..score..", rect=无解")
        return
    end
    print("score="..score..", rect={"..table.concat(rect, ", ").."}")
end

local grid = {
    {0, 0, 0, 0, 0, 0, 0},
    {0, 1, 0, 1, 0, 1, 0},
    {0, 0, 1, 1, 1, 0, 0},
    {0, 1, 1, 1, 1, 1, 0},
    {0, 1, 0, 1, 0, 1, 0},
    {0, 1, 1, 1, 1, 1, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0},
}

test_grid(grid)

--]]

return re