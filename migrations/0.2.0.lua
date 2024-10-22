
global.spiders = global.spiders or {}
global.spiderbots = global.spiderbots or {}
global.available_spiders = global.available_spiders or {}

global.tasks = global.tasks or {}
global.tasks.by_entity = global.tasks.by_entity or {}
global.tasks.by_spider = global.tasks.by_spider or {}
global.tasks.by_tile = global.tasks.by_tile or {}
global.tasks.nudges = global.tasks.nudges or {}

global.path_requested = global.path_requested or {}
global.spider_path_requests = global.spider_path_requests or {}
global.spider_path_to_position_requests = global.spider_path_to_position_requests or {}

global.previous_controller = global.previous_controller or {}
global.previous_player_entity = global.previous_player_entity or {}
global.previous_player_color = global.previous_player_color or {}

global.spiders_enabled = global.spiders_enabled or {}
global.spiderbots_enabled = global.spiderbots_enabled or {}
global.visualization_render_ids = global.visualization_render_ids or {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- -@class entity_task_data
-- -@field entity LuaEntity
-- -@field entity_id uuid
-- -@field spider LuaEntity
-- -@field spider_id uuid
-- -@field task_type string
-- -@field player LuaPlayer
-- -@field status string
-- -@field render_ids table<integer, boolean>
-- -@field path_request_id integer?

for player_index, old_spiders in pairs(global.spiders) do
    global.spiderbots[player_index] = global.spiderbots[player_index] or {}
    for spiderbot_uuid, spiderbot in pairs(old_spiders) do
        local player = game.get_player(player_index)
        if player and player.valid and spiderbot and spiderbot.valid then
            global.spiderbots[player_index][spiderbot_uuid] = {
                spiderbot = spiderbot,
                spiderbot_id = spiderbot_uuid,
                player = player,
                player_index = player_index,
                status = "idle",
                path_request_id = nil,
                task = nil
            }
            spiderbot.follow_target = player.character or player.vehicle or nil
        end
    end
end

for _, player in pairs(game.players) do
    local player_index = player.index
    global.spiderbots_enabled[player_index] = global.spiders_enabled[player_index] or false
    player.set_shortcut_toggled("toggle-spiderbots", global.spiderbots_enabled[player_index])
end

global.spiders = nil
global.available_spiders = nil
global.tasks = nil

global.path_requested = nil
global.spider_path_requests = nil
global.spider_path_to_position_requests = nil

global.previous_controller = global.previous_controller or {}
for player_index, controller in pairs(global.previous_controller) do
    global.previous_controller[player_index] = -500
end

global.previous_player_entity = global.previous_player_entity or {}
for player_index, entity in pairs(global.previous_player_entity) do
    global.previous_player_entity[player_index] = -500
end

global.previous_player_color = global.previous_player_color or {}
for player_index, color in pairs(global.previous_player_color) do
    global.previous_player_color[player_index] = { r = -500, g = -500, b = -500 }
end

global.spiders_enabled = nil
global.spiderbots_enabled = global.spiderbots_enabled or {}
global.visualization_render_ids = global.visualization_render_ids or {}

game.print("spiderbots migrated to v2.0")
