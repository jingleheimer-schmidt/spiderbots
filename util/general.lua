
local floor = math.floor

---@param entity LuaEntity
---@return string|integer
local function entity_uuid(entity)
    local unit_number = entity.unit_number
    if unit_number then
        return unit_number
    else
        local uuid = script.register_on_entity_destroyed(entity)
        return uuid
    end
end

---@param tile LuaTile
---@param surface_index integer?
---@param position TilePosition?
---@return string
local function tile_uuid(tile, surface_index, position)
    surface_index = surface_index or tile.surface.index
    position = position or tile.position
    local x = position.x
    local y = position.y
    local uuid = surface_index .. "," .. x .. "," .. y
    return uuid
end

---@param sorted_table table
---@return table
local function randomize_table(sorted_table)
    local randomized = {}
    for _, value in pairs(sorted_table) do
        local index = math.random(1, #randomized + 1)
        table.insert(randomized, index, value)
    end
    return randomized
end

local function random_pairs(t)
    -- Create a table of keys
    local keys = {}
    for key = 1, #t do
        keys[key] = key
    end

    -- Shuffle the keys
    for i = #t, 2, -1 do
        local j = math.random(i)
        keys[i], keys[j] = keys[j], keys[i]
    end

    -- Iterator function
    local index = 0
    return function()
        index = index + 1
        if keys[index] then
            return keys[index], t[keys[index]]
        end
    end
end

local function shuffle_array(array)
    local length = #array
    for i = length, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end
end

---@return integer
local function new_task_id()
    global.task_id = (global.task_id or 0) + 1
    return global.task_id
end

return {
    entity_uuid = entity_uuid,
    tile_uuid = tile_uuid,
    randomize_table = randomize_table,
    random_pairs = random_pairs,
    shuffle_array = shuffle_array,
    new_task_id = new_task_id,
}
