
---@param bounding_box BoundingBox
---@return number
local function maximum_length(bounding_box)
    -- Extract coordinates from the bounding box
    local leftTop = bounding_box.left_top
    local rightBottom = bounding_box.right_bottom

    -- Calculate the lengths of the sides
    local xLength = math.abs(rightBottom.x - leftTop.x)
    local yLength = math.abs(rightBottom.y - leftTop.y)

    -- Return the longest side length
    return math.max(xLength, yLength)
end

---@param bounding_box BoundingBox
---@return number
local function minimum_length(bounding_box)
    -- Extract coordinates from the bounding box
    local leftTop = bounding_box.left_top
    local rightBottom = bounding_box.right_bottom

    -- Calculate the lengths of the sides
    local xLength = math.abs(rightBottom.x - leftTop.x)
    local yLength = math.abs(rightBottom.y - leftTop.y)

    -- Return the longest side length
    return math.min(xLength, yLength)
end

---@param target_position MapPosition
---@param entity_position MapPosition
---@param degrees number
---@param minimum_distance number
---@return MapPosition
local function rotate_around_target(target_position, entity_position, degrees, minimum_distance)
    -- Calculate the vector from the target_position to the entity_position
    local dx = entity_position.x - target_position.x
    local dy = entity_position.y - target_position.y

    -- Calculate the current angle in radians
    local angle = math.atan2(dy, dx)

    -- Convert the degrees to radians for the new angle
    local radians = math.rad(degrees)

    -- Calculate the new angle by adding the desired rotation
    local new_angle = angle + radians

    -- Calculate the new position
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Ensure the new position is at least minimum_distance away from the target
    if distance < minimum_distance then
        distance = minimum_distance
    end

    -- Calculate the new position
    local new_x = target_position.x + distance * math.cos(new_angle)
    local new_y = target_position.y + distance * math.sin(new_angle)

    -- Create a new MapPosition for the entity's new position
    local new_entity_position = {x = new_x, y = new_y}

    return new_entity_position
end

local function random_position_on_circumference(center, radius)
    local angle = math.random() * 2 * math.pi
    local x = center.x + radius * math.cos(angle)
    local y = center.y + radius * math.sin(angle)
    return {x = x, y = y}
end

---@param pos_1 MapPosition | TilePosition
---@param pos_2 MapPosition | TilePosition
---@return number
local function distance(pos_1, pos_2)
    local x_1 = pos_1.x
    local y_1 = pos_1.y
    local x_2 = pos_2.x
    local y_2 = pos_2.y
    local x = x_1 - x_2
    local y = y_1 - y_2
    return math.sqrt(x * x + y * y)
end

return {
    maximum_length = maximum_length,
    minimum_length = minimum_length,
    rotate_around_target = rotate_around_target,
    random_position_on_circumference = random_position_on_circumference,
    distance = distance,
}
