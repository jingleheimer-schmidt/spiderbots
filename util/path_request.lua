
local math_util = require("util/math")
local maximum_length = math_util.maximum_length
local spider_leg_bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } }
local collision_mask = { "water-tile", "colliding-with-tiles-only", "consider-tile-transitions" }
local path_to_entity_flags = { cache = false, low_priority = true }
local path_to_position_flags = { cache = true, low_priority = true }

---@param surface LuaSurface
---@param spider_id string|integer
---@param spider LuaEntity
---@param entity_id string|integer
---@param entity LuaEntity
---@param player LuaPlayer
local function request_spider_path_to_entity(surface, spider_id, spider, entity_id, entity, player)
    local bounding_box = entity.bounding_box
    local right_bottom = bounding_box.right_bottom
    local left_top = bounding_box.left_top
    local x = (right_bottom.x - left_top.x) / 2
    local y = (right_bottom.y - left_top.y) / 2
    local request_parameters = {
        bounding_box = spider_leg_bounding_box,
        collision_mask = collision_mask,
        start = spider.position,
        goal = entity.position,
        force = spider.force,
        radius = math.max(x, y),
        can_open_gates = true,
        path_resolution_modifier = -1,
        pathfind_flags = path_to_entity_flags,
    }
    local path_request_id = surface.request_path(request_parameters)
    global.spider_path_requests[path_request_id] = {
        spider = spider,
        spider_id = spider_id,
        entity = entity,
        entity_id = entity_id,
        player = player,
        path_request_id = path_request_id,
    }
    global.path_requested[spider_id] = true
end

---@param surface LuaSurface
---@param spider_id string|integer
---@param spider LuaEntity
---@param starting_position MapPosition
---@param position MapPosition
---@param player LuaPlayer
local function request_spider_path_to_position(surface, spider_id, spider, starting_position, position, player)
    local request_parameters = {
        bounding_box = spider_leg_bounding_box,
        collision_mask = collision_mask,
        start = starting_position,
        goal = position,
        force = spider.force,
        radius = 3,
        can_open_gates = true,
        path_resolution_modifier = -1,
        pathfind_flags = path_to_position_flags,
    }
    local path_request_id = surface.request_path(request_parameters)
    global.spider_path_to_position_requests[path_request_id] = {
        spider = spider,
        spider_id = spider_id,
        start_position = starting_position,
        final_position = position,
        player = player,
        path_request_id = path_request_id,
    }
    global.path_requested[spider_id] = true
end

return {
    request_spider_path_to_entity = request_spider_path_to_entity,
    request_spider_path_to_position = request_spider_path_to_position,
}
