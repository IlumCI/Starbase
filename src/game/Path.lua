-- Path: enemy movement waypoints
local C = require("consts")

local Path = {}

function Path.getWaypoints()
    local pts = {}
    for _, wp in ipairs(C.PATH_WAYPOINTS) do
        table.insert(pts, {
            x = wp.x * C.WIDTH,
            y = wp.y * C.HEIGHT,
        })
    end
    return pts
end

-- Get position on path at normalized progress (0-1)
function Path.getPositionAtProgress(progress, waypoints)
    if not waypoints then waypoints = Path.getWaypoints() end
    local totalLen = 0
    local segLengths = {}
    for i = 1, #waypoints - 1 do
        local dx = waypoints[i + 1].x - waypoints[i].x
        local dy = waypoints[i + 1].y - waypoints[i].y
        local len = math.sqrt(dx * dx + dy * dy)
        segLengths[i] = len
        totalLen = totalLen + len
    end
    local target = progress * totalLen
    local acc = 0
    for i = 1, #waypoints - 1 do
        if acc + segLengths[i] >= target then
            local t = (target - acc) / segLengths[i]
            return {
                x = waypoints[i].x + (waypoints[i + 1].x - waypoints[i].x) * t,
                y = waypoints[i].y + (waypoints[i + 1].y - waypoints[i].y) * t,
            }
        end
        acc = acc + segLengths[i]
    end
    return waypoints[#waypoints]
end

-- Total path length
function Path.getTotalLength(waypoints)
    if not waypoints then waypoints = Path.getWaypoints() end
    local total = 0
    for i = 1, #waypoints - 1 do
        local dx = waypoints[i + 1].x - waypoints[i].x
        local dy = waypoints[i + 1].y - waypoints[i].y
        total = total + math.sqrt(dx * dx + dy * dy)
    end
    return total
end

return Path