
local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid
local get_player_entity = general_util.get_player_entity

local rendering_util = require("util/rendering")
local destroy_associated_renderings = rendering_util.destroy_associated_renderings

---@param spider LuaEntity
---@param player LuaPlayer
---@param spider_id uuid?
---@param entity_id uuid?
---@param player_entity LuaEntity?
local function abandon_task(spider, player, spider_id, entity_id, player_entity)
    spider_id = spider_id or entity_uuid(spider)
    local task_data = global.tasks.by_spider[spider_id]
    entity_id = entity_id or task_data and task_data.entity_id
    player_entity = player_entity or get_player_entity(player)

    destroy_associated_renderings(spider_id)

    if spider_id then
        local spider_task_data = global.tasks.by_spider[spider_id]
        local spider_path_request_id = spider_task_data and spider_task_data.path_request_id
        if spider_path_request_id then
            global.spider_path_requests[spider_path_request_id] = nil
            global.spider_path_to_position_requests[spider_path_request_id] = nil
        end
        global.path_requested[spider_id] = nil
        global.tasks.by_spider[spider_id] = nil
    end

    if entity_id then
        local entity_task_data = global.tasks.by_entity[entity_id]
        local entity_path_request_id = entity_task_data and entity_task_data.path_request_id
        if entity_path_request_id then
            global.spider_path_requests[entity_path_request_id] = nil
            global.spider_path_to_position_requests[entity_path_request_id] = nil
        end
        global.tasks.by_entity[entity_id] = nil
    end

    local player_index = player.index
    local surface_index = spider.surface_index
    global.available_spiders[player_index] = global.available_spiders[player_index] or {}
    global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
    table.insert(global.available_spiders[player_index][surface_index], spider)

    spider.color = player.color

    spider.autopilot_destination = nil
    if player.surface_index == spider.surface_index then
        if player_entity and player_entity.valid then
            spider.follow_target = player_entity
        else
            spider.follow_target = nil
        end
    end
end

---@param spider_id uuid
---@param entity_id uuid
---@param spider LuaEntity
---@param player LuaPlayer
---@param player_entity LuaEntity?
local function complete_task(spider_id, entity_id, spider, player, player_entity)
    -- destroy_associated_renderings(spider_id)
    -- global.tasks.by_entity[entity_id] = nil
    -- global.tasks.by_spider[spider_id] = nil
    -- local player_index = player.index
    -- local surface_index = spider.surface_index
    -- global.available_spiders[player_index] = global.available_spiders[player_index] or {}
    -- global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
    -- table.insert(global.available_spiders[player_index][surface_index], spider)
    -- spider.color = player.color
    -- spider.autopilot_destination = nil
    -- if player.surface_index == spider.surface_index then
    --   spider.follow_target = player_entity
    -- end
    abandon_task(spider, player, spider_id, entity_id, player_entity)
end

---@param type string
---@param entity_id uuid
---@param entity LuaEntity
---@param spider LuaEntity
---@param player LuaPlayer
---@param surface LuaSurface
local function new_entity_task(type, entity_id, entity, spider, player, surface)
    local spider_id = entity_uuid(spider)
    spider.color = color.white
    request_spider_path_to_entity(surface, spider_id, spider, entity_id, entity, player)
    local task_data = {
        entity = entity,
        entity_id = entity_id,
        spider = spider,
        spider_id = spider_id,
        task_type = type,
        player = player,
        status = "path_requested",
        render_ids = {},
    }
    global.tasks.by_entity[entity_id] = task_data
    global.tasks.by_spider[spider_id] = task_data
    global.tasks.nudges[spider_id] = nil
end

-- ---@param type string
-- ---@param tile_id uuid
-- ---@param tile LuaTile
-- ---@param spider LuaEntity
-- ---@param player LuaPlayer
-- ---@param surface LuaSurface
-- local function new_tile_task(type, tile_id, tile, spider, player, surface)
--   local spider_id = entity_uuid(spider)
--   spider.color = color.white
--   request_spider_path_to_tile(surface, spider_id, spider, tile_id, tile, player)
--   local task_data = {
--     tile = tile,
--     tile_id = tile_id,
--     spider = spider,
--     spider_id = spider_id,
--     task_type = type,
--     player = player,
--     status = "path_requested",
--     render_ids = {},
--   }
--   global.tasks.by_tile[tile_id] = task_data
--   global.tasks.by_spider[spider_id] = task_data
--   global.tasks.nudges[spider_id] = nil
-- end

return {
    abandon_task = abandon_task,
    complete_task = complete_task,
    new_entity_task = new_entity_task,
    -- new_tile_task = new_tile_task,
}
