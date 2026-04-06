local collisions = {}

function collisions.FollowShape(sprite)
    local data_tab = {}

    local x, y = sprite.x, sprite.y
    local w, h = sprite.width * sprite.xscale, sprite.height * sprite.yscale
    local angle = sprite.rotation
    local xpivot, ypivot = sprite.xpivot, sprite.ypivot

    local screenX, screenY = love.graphics.transformPoint(x, y)
    data_tab = {
        x = screenX + w * (0.5 - xpivot) * math.cos(math.rad(angle)) - h * (0.5 - ypivot) * math.sin(math.rad(angle)),
        y = screenY + h * (0.5 - ypivot) * math.cos(math.rad(angle)) + w * (0.5 - xpivot) * math.sin(math.rad(angle)),
        w = math.abs(w),
        h = math.abs(h),
        angle = angle
    }

    return data_tab
end

function collisions.RectangleWithPoint(rectangle, point)
    local is_colliding = false
    local rect = rectangle
    local p = point

    local dx, dy = p.x - rect.x, p.y - rect.y
    local w, h = rect.w, rect.h
    local angle = math.rad(rect.angle)
    local cos, sin = math.cos(angle), math.sin(angle)

    if (dx * cos + dy * sin <= w / 2 and dx * cos + dy * sin >= -w / 2 and dy * cos - dx * sin <= h / 2 and dy * cos - dx * sin >= -h / 2) then
        is_colliding = true
    end

    return is_colliding
end

function collisions.CircleWithPoint(circle, point)
    local is_colliding = false
    local circ = circle
    local p = point

    local dx, dy = p.x - circ.x, p.y - circ.y
    local a, b = circ.w, circ.h
    local angle = math.rad(circ.angle)
    local cos, sin = math.cos(angle), math.sin(angle)
    local X, Y = dx * cos + dy * sin, dy * cos - dx * sin

    if (X ^ 2 / a ^ 2 + Y ^ 2 / b ^ 2 <= 1) then
        is_colliding = true
    end

    return is_colliding
end

function collisions.RectangleWithRectangle(rectangle1, rectangle2)
    local rect1 = rectangle1
    local rect2 = rectangle2

    local function getRotatedVertices(rect)
        local angle = math.rad(rect.angle)
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)

        local halfW = rect.w / 2
        local halfH = rect.h / 2

        local vertices = {
            {x = -halfW, y = -halfH},
            {x = halfW,  y = -halfH},
            {x = -halfW, y = halfH},
            {x = halfW,  y = halfH}
        }

        for _, vertex in ipairs(vertices)
        do
            local x = vertex.x * cosA - vertex.y * sinA + rect.x
            local y = vertex.x * sinA + vertex.y * cosA + rect.y
            vertex.x, vertex.y = x, y
        end

        return vertices
    end

    local function projectRectangle(vertices, axis)
        local min = math.huge
        local max = -math.huge

        for _, vertex in ipairs(vertices)
        do
            local dot = vertex.x * axis.x + vertex.y * axis.y
            if (dot < min) then min = dot end
            if (dot > max) then max = dot end
        end

        return min, max
    end

    local function getAxes(rect)
        local angle = math.rad(rect.angle)
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)

        return {
            {x = cosA, y = sinA},
            {x = -sinA, y = cosA}
        }
    end

    local vertices1 = getRotatedVertices(rect1)
    local vertices2 = getRotatedVertices(rect2)

    local axes = {}
    for _, axis in ipairs(getAxes(rect1))
    do
        table.insert(axes, axis)
    end
    for _, axis in ipairs(getAxes(rect2))
    do
        table.insert(axes, axis)
    end

    for _, axis in ipairs(axes)
    do
        local min1, max1 = projectRectangle(vertices1, axis)
        local min2, max2 = projectRectangle(vertices2, axis)
        if (max1 < min2 or max2 < min1) then
            return false
        end
    end

    return true
end

function collisions.RectangleWithCircle(rectangle, circle)

    local rHalfDiag = math.sqrt(rectangle.w^2 + rectangle.h^2) / 2
    local cHalfDiag = math.sqrt(circle.w^2 + circle.h^2) / 2  -- circle.w/h 是直径
    local dx = rectangle.x - circle.x
    local dy = rectangle.y - circle.y
    if dx*dx + dy*dy > (rHalfDiag + cHalfDiag)^2 then
        return false  -- 连包围圆都不碰，直接跳过
    end

    -- 检测点是否在矩形内（矩形以原点为中心，方向为 (cos,sin)）
    local function p2r(w, h, cos, sin, dx, dy)
        return math.abs(dx*cos + dy*sin)*2 <= w and math.abs(-dx*sin + dy*cos)*2 <= h
    end

    -- 求椭圆 x²/a² + y²/b² = 1 与过原点直线 p*x + q*y = 0 的交点（取 x≥0 的一侧）
    -- 即椭圆在矩形某条轴方向上的极值点
    local function solve(a, b, p, q)
        if q == 0 then
            return 0, b
        elseif p == 0 then
            return a, 0
        else
            local x = a*b*math.abs(q)/math.sqrt(b*b*q*q + a*a*p*p)
            return x, -x*p/q
        end
    end

    -- 检测点是否在椭圆内
    local function p2e(a, b, x, y)
        return (x*x)/(a*a) + (y*y)/(b*b) <= 1
    end

    -- 【新增】检测线段 P→Q 是否与椭圆 x²/a² + y²/b² = 1 的边界相交
    -- 将线段参数化为 P + t*(Q-P)，代入椭圆方程得关于 t 的二次方程，
    -- 判断是否存在 t ∈ [0,1] 的实数根
    local function segmentIntersectsEllipse(a, b, px, py, qx, qy)
        local dx, dy = qx - px, qy - py
        local A = dx*dx/(a*a) + dy*dy/(b*b)
        if A == 0 then return false end
        local B = 2*(px*dx/(a*a) + py*dy/(b*b))
        local C = px*px/(a*a) + py*py/(b*b) - 1
        local disc = B*B - 4*A*C
        if disc < 0 then return false end
        local sqrtD = math.sqrt(disc)
        local t1 = (-B - sqrtD) / (2*A)
        local t2 = (-B + sqrtD) / (2*A)
        return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
    end

    -- 椭圆（原点，半轴 a/b，轴对齐）与矩形（中心 (x,y)，宽 w 高 h，方向 (cos,sin)）的碰撞检测
    local function ellipseToRectangle(a, b, x, y, w, h, cos, sin)
        -- 椭圆在矩形两条轴方向上的极值点（各取正负两侧，共4点）
        local x1, y1 = solve(a, b, -sin/(a*a), cos/(b*b))
        local x2, y2 = solve(a, b, cos/(a*a), sin/(b*b))

        -- 矩形的宽/高方向向量（全长）
        local wx, wy = w*cos, w*sin
        local hx, hy = -h*sin, h*cos

        -- 检测1：椭圆极值点是否在矩形内
        if p2r(w,h, cos,sin, x-x1,y-y1) then return true end
        if p2r(w,h, cos,sin, x-x2,y-y2) then return true end
        if p2r(w,h, cos,sin, x+x1,y+y1) then return true end
        if p2r(w,h, cos,sin, x+x2,y+y2) then return true end

        -- 检测2：矩形4个顶点是否在椭圆内
        if p2e(a,b, x-(wx+hx)/2, y-(wy+hy)/2) then return true end
        if p2e(a,b, x-(-wx+hx)/2, y-(-wy+hy)/2) then return true end
        if p2e(a,b, x-(-wx-hx)/2, y-(-wy-hy)/2) then return true end
        if p2e(a,b, x-(wx-hx)/2, y-(wy-hy)/2) then return true end

        -- 检测3：矩形4条边是否与椭圆边界相交
        -- （修复漏检：椭圆边缘穿过矩形边，但极值点不在矩形内、顶点也不在椭圆内的情况）
        -- 4个顶点坐标
        local c1x, c1y = x + wx/2 + hx/2, y + wy/2 + hy/2
        local c2x, c2y = x - wx/2 + hx/2, y - wy/2 + hy/2
        local c3x, c3y = x - wx/2 - hx/2, y - wy/2 - hy/2
        local c4x, c4y = x + wx/2 - hx/2, y + wy/2 - hy/2

        if segmentIntersectsEllipse(a, b, c1x, c1y, c2x, c2y) then return true end
        if segmentIntersectsEllipse(a, b, c2x, c2y, c3x, c3y) then return true end
        if segmentIntersectsEllipse(a, b, c3x, c3y, c4x, c4y) then return true end
        if segmentIntersectsEllipse(a, b, c4x, c4y, c1x, c1y) then return true end

        return false
    end

    local rec_x = rectangle.x - circle.x
    local rec_y = rectangle.y - circle.y
    local rad = math.rad(circle.angle)
    local rec_angle = rectangle.angle - circle.angle
    local rec_rad = math.rad(rec_angle)
    rec_x, rec_y = rec_x*math.cos(rad) + rec_y*math.sin(rad), -rec_x*math.sin(rad) + rec_y*math.cos(rad)
    return ellipseToRectangle(circle.w/2, circle.h/2, rec_x, rec_y, rectangle.w, rectangle.h, math.cos(rec_rad), math.sin(rec_rad))
end

function collisions.CircleWithCircle(circle1, circle2)
    local function get_axes(angle)
        local cosA, sinA = math.cos(angle), math.sin(angle)
        return { {cosA, sinA}, {-sinA, cosA} }
    end

    local function get_projection_length(a, b, angle, ax, ay)
        local cosA, sinA = math.cos(angle), math.sin(angle)
        local projX = a * math.abs(ax * cosA + ay * sinA)
        local projY = b * math.abs(-ax * sinA + ay * cosA)
        return math.sqrt(projX^2 + projY^2)
    end

    local x1, y1 = circle1.x, circle1.y
    local a1, b1 = circle1.w / 2, circle1.h / 2
    local angle1 = math.rad(circle1.angle)

    local x2, y2 = circle2.x, circle2.y
    local a2, b2 = circle2.w / 2, circle2.h / 2
    local angle2 = math.rad(circle2.angle)

    if (a1 == b1 and a2 == b2) then
        local r1, r2 = a1, a2
        local dx, dy = x2 - x1, y2 - y1
        local distance = math.sqrt(dx * dx + dy * dy)
        return distance <= (r1 + r2)
    end

    local axes = {}
    for _, axis in ipairs(get_axes(angle1)) do table.insert(axes, axis) end
    for _, axis in ipairs(get_axes(angle2)) do table.insert(axes, axis) end

    local dx, dy = x2 - x1, y2 - y1
    local center_dist = math.sqrt(dx * dx + dy * dy)
    if (center_dist > 0) then
        table.insert(axes, {dx / center_dist, dy / center_dist})
    end

    for _, axis in ipairs(axes)
    do
        local ax, ay = axis[1], axis[2]

        local proj1 = get_projection_length(a1, b1, angle1, ax, ay)
        local proj2 = get_projection_length(a2, b2, angle2, ax, ay)

        local center_proj = math.abs(dx * ax + dy * ay)
        if (center_proj > (proj1 + proj2)) then
            return false
        end
    end

    return true
end

return collisions