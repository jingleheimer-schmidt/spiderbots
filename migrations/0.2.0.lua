
storage.spiders = storage.spiders or {}
storage.spiderbots = storage.spiderbots or {}
storage.available_spiders = storage.available_spiders or {}

storage.tasks = storage.tasks or {}
storage.tasks.by_entity = storage.tasks.by_entity or {}
storage.tasks.by_spider = storage.tasks.by_spider or {}
storage.tasks.by_tile = storage.tasks.by_tile or {}
storage.tasks.nudges = storage.tasks.nudges or {}

storage.path_requested = storage.path_requested or {}
storage.spider_path_requests = storage.spider_path_requests or {}
storage.spider_path_to_position_requests = storage.spider_path_to_position_requests or {}

storage.previous_controller = storage.previous_controller or {}
storage.previous_player_entity = storage.previous_player_entity or {}
storage.previous_player_color = storage.previous_player_color or {}

storage.spiders_enabled = storage.spiders_enabled or {}
storage.spiderbots_enabled = storage.spiderbots_enabled or {}
storage.render_objects = storage.render_objects or {}

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

for player_index, old_spiders in pairs(storage.spiders) do
    storage.spiderbots[player_index] = storage.spiderbots[player_index] or {}
    for spiderbot_uuid, spiderbot in pairs(old_spiders) do
        local player = game.get_player(player_index)
        if player and player.valid and spiderbot and spiderbot.valid then
            storage.spiderbots[player_index][spiderbot_uuid] = {
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
    storage.spiderbots_enabled[player_index] = storage.spiders_enabled[player_index] or false
    player.set_shortcut_toggled("toggle-spiderbots", storage.spiderbots_enabled[player_index])
end

storage.spiders = nil
storage.available_spiders = nil
storage.tasks = nil

storage.path_requested = nil
storage.spider_path_requests = nil
storage.spider_path_to_position_requests = nil

storage.previous_controller = storage.previous_controller or {}
for player_index, controller in pairs(storage.previous_controller) do
    storage.previous_controller[player_index] = -500
end

storage.previous_player_entity = storage.previous_player_entity or {}
for player_index, entity in pairs(storage.previous_player_entity) do
    storage.previous_player_entity[player_index] = -500
end

storage.previous_player_color = storage.previous_player_color or {}
for player_index, color in pairs(storage.previous_player_color) do
    storage.previous_player_color[player_index] = { r = -500, g = -500, b = -500 }
end

storage.spiders_enabled = nil
storage.spiderbots_enabled = storage.spiderbots_enabled or {}
storage.render_objects = storage.render_objects or {}

-- game.print({ "spiderbot-messages.2.0-migration" })
