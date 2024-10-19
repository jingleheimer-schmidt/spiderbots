
global.spiders = global.spiders or {}
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
global.visualization_render_ids = global.visualization_render_ids or {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

global.spiderbots = global.spiderbots or {}
for player_index, spiderbot_data in pairs(global.spiders) do
    global.spiderbots[player_index] = global.spiderbots[player_index] or {}
    for spiderbot_uuid, spiderbot in pairs(spiderbot_data) do
        global.spiderbots[player_index][spiderbot_uuid] = {
            spiderbot = spiderbot,
            status = "idle",
            task = {},
            render_ids = {},
            path_request_id = nil,
        }
    end
end
