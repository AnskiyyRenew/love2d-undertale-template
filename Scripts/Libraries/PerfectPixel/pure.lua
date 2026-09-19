-- Pure Lua implementation of the rectangle decomposition library
local re = {}

local function globalExpandRect(grid)
    local m, n = #grid, #grid[1]
    -- Build the prefix-sum array (rows 0..m, columns 0..n)
    local prefix = {}
    for i = 0, m do
        prefix[i] = {}
        for j = 0, n do
            prefix[i][j] = 0
        end
    end

    -- Fill
    for i = 1, m do
        for j = 1, n do
            local score = (grid[i][j] == 2) and 1 or 0
            prefix[i][j] = score + prefix[i-1][j] + prefix[i][j-1] - prefix[i-1][j-1]
        end
    end

    local max_score = 0
    local best_rect = nil
    local height = {}  -- Height array (1-based column index)

    -- Initialise
    for j = 1, n do
        height[j] = 0
    end

    -- Walk every row
    for i = 1, m do
        -- Update the height array
        for j = 1, n do
            if grid[i][j] ~= 0 then
                height[j] = height[j] + 1
            else
                height[j] = 0
            end
        end

        local stack = {}  -- Monotonic stack (holds column indices)

        -- Walk every column of the current row
        for j = 1, n do
            -- Keep the stack monotonically increasing
            while #stack > 0 and height[j] < height[stack[#stack]] do
                local k = table.remove(stack)  -- Pop the top of the stack
                local left = (#stack > 0) and stack[#stack] or 0
                local rect_height = height[k]
                local x1 = i - rect_height + 1  -- Start row (1-based)
                local x2 = i                     -- End row (1-based)
                local y1 = left + 1              -- Start column (1-based)
                local y2 = j - 1                 -- End column (1-based)

                -- Make sure the rectangle is valid
                if y1 <= y2 then
                    -- Score the rectangle
                    local score_here = prefix[x2][y2]
                        - prefix[x1-1][y2]
                        - prefix[x2][y1-1]
                        + prefix[x1-1][y1-1]

                    -- Update the best score
                    if score_here > max_score then
                        max_score = score_here
                        best_rect = {
                            x1 - 1,     -- Start row (0-based)
                            y1 - 1,     -- Start column (0-based)
                            x2 - x1 + 1,-- Height (number of rows)
                            y2 - y1 + 1 -- Width (number of columns)
                        }
                    end
                end
            end
            table.insert(stack, j)  -- Push the current column
        end

        -- Drain whatever is left on the stack
        while #stack > 0 do
            local k = table.remove(stack)
            local left = (#stack > 0) and stack[#stack] or 0
            local rect_height = height[k]
            local x1 = i - rect_height + 1
            local x2 = i
            local y1 = left + 1
            local y2 = n  -- Clamp the boundary to the last column

            if y1 <= y2 then
                local score_here = prefix[x2][y2]
                    - prefix[x1-1][y2]
                    - prefix[x2][y1-1]
                    + prefix[x1-1][y1-1]

                if score_here > max_score then
                    max_score = score_here
                    best_rect = {
                        x1 - 1,     -- Start row (0-based)
                        y1 - 1,     -- Start column (0-based)
                        x2 - x1 + 1,-- Height (number of rows)
                        y2 - y1 + 1 -- Width (number of columns)
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
            -- visited and grid are merged into one: 2 = unvisited, 1 = visited,
            -- 0 = obstacle
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