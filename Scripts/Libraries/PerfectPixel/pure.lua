-- Pure Lua fallback for the rectangle decomposition library.
local re = {}

local function globalExpandRect(grid)
    local m, n = #grid, #grid[1]
    -- prefix sums, 0-based on both axes
    local prefix = {}
    for i = 0, m do
        prefix[i] = {}
        for j = 0, n do
            prefix[i][j] = 0
        end
    end

    for i = 1, m do
        for j = 1, n do
            local score = (grid[i][j] == 2) and 1 or 0
            prefix[i][j] = score + prefix[i-1][j] + prefix[i][j-1] - prefix[i-1][j-1]
        end
    end

    local max_score = 0
    local best_rect = nil
    local height = {}  -- filled rows above the current row, per column

    for j = 1, n do
        height[j] = 0
    end

    for i = 1, m do
        for j = 1, n do
            if grid[i][j] ~= 0 then
                height[j] = height[j] + 1
            else
                height[j] = 0
            end
        end

        local stack = {}  -- monotonic stack of column indices

        for j = 1, n do
            -- keep the stack monotonically increasing
            while #stack > 0 and height[j] < height[stack[#stack]] do
                local k = table.remove(stack)
                local left = (#stack > 0) and stack[#stack] or 0
                local rect_height = height[k]
                local x1 = i - rect_height + 1  -- all row/column bounds below are 1-based
                local x2 = i
                local y1 = left + 1
                local y2 = j - 1

                if y1 <= y2 then
                    local score_here = prefix[x2][y2]
                        - prefix[x1-1][y2]
                        - prefix[x2][y1-1]
                        + prefix[x1-1][y1-1]

                    if score_here > max_score then
                        max_score = score_here
                        best_rect = {
                            x1 - 1,     -- 0-based row
                            y1 - 1,     -- 0-based column
                            x2 - x1 + 1,-- rows
                            y2 - y1 + 1 -- columns
                        }
                    end
                end
            end
            table.insert(stack, j)
        end

        -- drain the remaining stack
        while #stack > 0 do
            local k = table.remove(stack)
            local left = (#stack > 0) and stack[#stack] or 0
            local rect_height = height[k]
            local x1 = i - rect_height + 1
            local x2 = i
            local y1 = left + 1
            local y2 = n

            if y1 <= y2 then
                local score_here = prefix[x2][y2]
                    - prefix[x1-1][y2]
                    - prefix[x2][y1-1]
                    + prefix[x1-1][y1-1]

                if score_here > max_score then
                    max_score = score_here
                    best_rect = {
                        x1 - 1,     -- 0-based row
                        y1 - 1,     -- 0-based column
                        x2 - x1 + 1,-- rows
                        y2 - y1 + 1 -- columns
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

return re