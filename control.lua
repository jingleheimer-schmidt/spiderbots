
local function toggle_debug()
    global.debug = not global.debug
    for _, player in pairs(game.connected_players) do
        local messaage = global.debug and { "spiderbot-messages.debug-mode-enabled" } or { "spiderbot-messages.debug-mode-disabled" }
        player.print(messaage)
    end
end

local function add_commands()
    commands.add_command("spiderbots-debug", "- toggles debug mode for the spiderbots, showing task targets and path request renderings", toggle_debug)
end

local function on_init()
    -- spiderbot data
    global.spiderbots = {} --[[@type table<integer, table<uuid, LuaEntity>>]]
    global.spiderbots_enabled = {} --[[@type table<integer, boolean>]]

    -- pathfinding data
    global.spider_path_requests = {} --[[@type table<integer, path_request_data>]]
    global.spider_path_to_position_requests = {} --[[@type table<integer, position_path_request_data>]]
    global.path_requested = {} --[[@type table<uuid, boolean>]]

    -- player data
    global.previous_controller = {} --[[@type table<integer, defines.controllers>]]
    global.previous_player_entity = {} --[[@type table<integer, uuid>]]
    global.previous_player_color = {} --[[@type table<integer, Color>]]

    -- misc data
    global.spider_leg_collision_mask = game.entity_prototypes["spiderbot-leg-1"].collision_mask
    global.visualization_render_ids = {} --[[@type table<integer, table<integer, integer>>]]

    add_commands()
end

script.on_init(on_init)

-- toggle the spiderbots on/off for the player
---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_spiderbots(event)
    local name = event.prototype_name or event.input_name
    if name ~= "toggle-spiderbots" then return end
    local player_index = event.player_index
    global.spiderbots_enabled = global.spiderbots_enabled or {}
    global.spiderbots_enabled[player_index] = not global.spiderbots_enabled[player_index]
    if not global.spiderbots_enabled[player_index] then
        local player = game.get_player(player_index)
        global.spiderbots = global.spiderbots or {}
        local player_spiders = global.spiderbots[player_index]
        if player and player.valid and player_spiders then
            for spider_id, spider in pairs(player_spiders) do
                if spider.valid then
                    abandon_task(spider, player)
                end
            end
        end
    end
    game.get_player(player_index).set_shortcut_toggled("toggle-spiderbots", global.spiderbots_enabled[player_index])
end

script.on_event("toggle-spiderbots", toggle_spiderbots)
script.on_event(defines.events.on_lua_shortcut, toggle_spiderbots)
