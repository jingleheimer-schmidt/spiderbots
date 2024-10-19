
local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid

local math_util = require("util/math")
local distance = math_util.distance

local constants = require("util/constants")
local max_task_range = constants.max_task_range

local color_util = require("util/colors")
local color = color_util.color

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

script.on_load(add_commands)

local function on_init()
    -- spiderbot data
    global.spiderbots = {} --[[@type table<player_index, table<uuid, spiderbot_data>>]]
    global.spiderbots_enabled = {} --[[@type table<player_index, boolean>]]

    -- player data
    global.previous_controller = {} --[[@type table<player_index, defines.controllers>]]
    global.previous_player_entity = {} --[[@type table<player_index, uuid>]]
    global.previous_player_color = {} --[[@type table<player_index, Color>]]

    -- misc data
    global.spider_leg_collision_mask = game.entity_prototypes["spiderbot-leg-1"].collision_mask
    global.visualization_render_ids = {} --[[@type table<integer, table<integer, integer>>]]

    add_commands()
end

script.on_init(on_init)

local function on_configuration_changed(event)
    -- spiderbot data
    global.spiderbots = global.spiderbots or {}
    global.spiderbots_enabled = global.spiderbots_enabled or {}

    -- player data
    global.previous_controller = global.previous_controller or {}
    global.previous_player_entity = global.previous_player_entity or {}
    global.previous_player_color = global.previous_player_color or {}

    -- misc data
    global.spider_leg_collision_mask = game.entity_prototypes["spiderbot-leg-1"].collision_mask
    global.visualization_render_ids = global.visualization_render_ids or {}

end

script.on_configuration_changed(on_configuration_changed)

---@param player LuaPlayer
---@return LuaEntity?
local function get_player_entity(player)
    return player.character or player.vehicle or nil
end

---@return string
local function random_backer_name()
    local backer_names = game.backer_names
    local index = math.random(#backer_names)
    return backer_names[index]
end

---@param name string
---@return boolean
local function is_backer_name(name)
    if not global.backer_name_lookup then
        global.backer_name_lookup = {}
        for _, backer_name in pairs(game.backer_names) do
            global.backer_name_lookup[backer_name] = true
        end
    end
    return global.backer_name_lookup[name]
end

-- register a spiderbot. saves spiderbot data to global. updates the color, label, and follow target
---@param spiderbot LuaEntity
---@param player LuaPlayer
---@param player_index player_index
local function register_new_spiderbot(spiderbot, player, player_index)
    local uuid = entity_uuid(spiderbot)
    global.spiderbots[player_index] = global.spiderbots[player_index] or {}
    global.spiderbots[player_index][uuid] = {
        spiderbot = spiderbot,
        spiderbot_id = uuid,
        player = player,
        player_index = player_index,
        status = "idle"
    }
    spiderbot.color = player.color
    local player_entity = get_player_entity(player)
    if player_entity and player_entity.valid then
        spiderbot.follow_target = player_entity
    end
    local entity_label = spiderbot.entity_label
    if (not entity_label) or (is_backer_name(entity_label)) then
        spiderbot.entity_label = random_backer_name()
    end
end

-- register spiderbots when created by the player
---@param event EventData.on_built_entity
local function on_spiderbot_created(event)
    local spiderbot = event.created_entity
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if player and player.valid then
        register_new_spiderbot(spiderbot, player, player_index)
    end
end

local filter = { { filter = "name", name = "spiderbot" } }
script.on_event(defines.events.on_built_entity, on_spiderbot_created, filter)

-- register spiderbots when created by script triggers (thrown capsules)
---@param event EventData.on_trigger_created_entity
local function on_trigger_created_entity(event)
    local entity = event.entity
    local source = event.source
    if entity.name == "spiderbot" then
        if source and source.valid then
            local player = source.type == "character" and source.player
            if player and player.valid then
                local player_index = player.index
                register_new_spiderbot(entity, player, player_index)
            end
        end
    end
end

script.on_event(defines.events.on_trigger_created_entity, on_trigger_created_entity)

-- create the spiderbot projectile when a player uses a spiderbot capsule
---@param event EventData.on_player_used_capsule
local function on_player_used_capsule(event)
    local position = event.position
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    -- try to find a valid position for the spiderbot to land. if a non_colliding_position is found then the spiderbot can scramble to it from the original position once spawned
    local non_colliding_position = player.surface.find_non_colliding_position("spiderbot-leg-1", position, 3.75, 0.5)
    -- refund the spiderbot item if there is no valid position
    if not non_colliding_position then
        local inventory = player.get_main_inventory()
        if inventory and inventory.valid then
            local item_stack = { name = "spiderbot-item", count = 1 }
            local cursor_stack = player.cursor_stack
            if cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "spiderbot-item" then
                item_stack.count = item_stack.count + cursor_stack.count
                player.cursor_stack.set_stack(item_stack)
            else
                player.cursor_stack.set_stack(item_stack)
            end
        end
        return
    end
    local player_entity = get_player_entity(player)
    player.surface.create_entity {
        name = "spiderbot-projectile",
        position = player.position,
        force = player.force,
        player = player,
        source = player_entity,
        target = position,
        speed = 0.33,
        raise_built = true,
    }
end

script.on_event(defines.events.on_player_used_capsule, on_player_used_capsule)

-- remove the spiderbot data when a spiderbot is destroyed
---@param event EventData.on_entity_destroyed
local function on_spider_destroyed(event)
    local unit_number = event.unit_number
    if not unit_number then return end
    for player_index, spiderbot_data in pairs(global.spiderbots) do
        for spider_id, data in pairs(spiderbot_data) do
            if data.spiderbot_id == unit_number then
                global.spiderbots[player_index][spider_id] = nil
                return
            end
        end
    end
end

script.on_event(defines.events.on_entity_destroyed, on_spider_destroyed)

-- abandon the current task, set state to idle, and follow the player
---@param spiderbot_id uuid
---@param player_index player_index
local function abandon_task(spiderbot_id, player_index)
    local spiderbots = global.spiderbots[player_index]
    local spiderbot_data = spiderbots[spiderbot_id]
    if spiderbot_data then
        spiderbot_data.status = "idle"
        spiderbot_data.path_request_id = nil
        local player = spiderbot_data.player
        local spiderbot = spiderbot_data.spiderbot
        if player.valid and spiderbot.valid then
            local target = get_player_entity(player)
            if target and target.valid then
                spiderbot.follow_target = target
            end
        else
            spiderbots[spiderbot_id] = nil
        end
    end
end

---@param player LuaPlayer
local function relink_following_spiderbots(player)
    local player_index = player.index
    if not (player and player.valid) then return end
    local player_entity = get_player_entity(player)
    local spiderbots = global.spiderbots[player_index]
    if not spiderbots then return end
    for spider_id, spiderbot_data in pairs(spiderbots) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot.valid then
            if spiderbot.surface_index == player.surface_index then
                if spiderbot_data.status == "idle" then
                    spiderbot.follow_target = player_entity
                elseif spiderbot_data.status == "path_requested" then
                    spiderbot.follow_target = player_entity
                elseif spiderbot_data.status == "task_assigned" then
                    local task = spiderbot_data.task
                    if not (task and task.entity.valid) then
                        abandon_task(spider_id, player_index)
                    else
                        local destinations = spiderbot.autopilot_destinations
                        spiderbot.follow_target = player_entity
                        if destinations then
                            for _, destination in pairs(destinations) do
                                spiderbot.add_autopilot_destination(destination)
                            end
                        end
                    end
                end
            end
        else
            spiderbots[spider_id] = nil
        end
    end
end

---@param event EventData.on_player_changed_surface
local function on_player_changed_surface(event)
    local player_index = event.player_index
    local surface_index = event.surface_index
    local player = game.get_player(player_index)
    local surface = game.get_surface(surface_index)
    if player and player.valid and surface and surface.valid then
        local spiderbots = global.spiderbots[player_index]
        if not spiderbots then return end
        for spider_id, spiderbot_data in pairs(spiderbots) do
            local spiderbot = spiderbot_data.spiderbot
            if spiderbot.valid then
                local non_colliding_position = surface.find_non_colliding_position("spiderbot-leg-1", player.position, 25, 0.5)
                local position = non_colliding_position or player.position
                spiderbot.teleport(position, surface, true)
                abandon_task(spider_id, player_index)
            end
        end
        relink_following_spiderbots(player)
    end
end

script.on_event(defines.events.on_player_changed_surface, on_player_changed_surface)

---@param event EventData.on_player_driving_changed_state
local function on_player_driving_changed_state(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    relink_following_spiderbots(player)
end

script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)


---@param spiderbot_id uuid?
---@param path_request_id integer?
---@return spiderbot_data?
local function get_spiderbot_data(spiderbot_id, path_request_id)
    for player_index, spiderbots in pairs(global.spiderbots) do
        for spider_id, spiderbot_data in pairs(spiderbots) do
            if spiderbot_data.spiderbot_id == spiderbot_id then
                return spiderbot_data
            elseif spiderbot_data.path_request_id == path_request_id then
                return spiderbot_data
            end
        end
    end
end

---@param spiderbot_data spiderbot_data
local function build_ghost(spiderbot_data)
    local spiderbot = spiderbot_data.spiderbot
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local entity = spiderbot_data.task.entity
    if not (player and player.valid and entity and entity.valid) then
        abandon_task(spiderbot_id, player_index)
        return
    end
    local items = entity.ghost_prototype.items_to_place_this
    local item_stack = items and items[1]
    if item_stack then
        local item_name = item_stack.name
        local item_count = item_stack.count or 1
        local inventory = player.get_main_inventory()
        if not (inventory and inventory.valid) then
            abandon_task(spiderbot_id, player_index) -- no inventory to get items from
            return
        end
        if inventory.get_item_count(item_name) >= item_count then
            local dictionary, revived_entity = entity.revive({ return_item_request_proxy = false, raise_revive = true })
            if revived_entity then
                inventory.remove(item_stack)
                abandon_task(spiderbot_id, player_index) -- successfully revived entity, task complete. reset task data and follow player
            else
                abandon_task(spiderbot_id, player_index) -- failed to revive entity
            end
        else
            abandon_task(spiderbot_id, player_index) -- not enough items to revive entity
        end
    else
        abandon_task(spiderbot_id, player_index) -- no item to place this
    end
end

---@param spiderbot_data spiderbot_data
local function deconstruct_entity(spiderbot_data)
    local spiderbot = spiderbot_data.spiderbot
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local entity = spiderbot_data.task.entity
    if not (player and player.valid and entity and entity.valid) then
        abandon_task(spiderbot_id, player_index)
        return
    end
    local inventory = player.get_main_inventory()
    if not (inventory and inventory.valid) then
        abandon_task(spiderbot_id, player_index) -- no inventory to get items from
        return
    end
    local entity_position = entity.position
    if entity.to_be_deconstructed() then
        local prototype = entity.prototype
        local products = prototype and prototype.mineable_properties.products
        local result_when_mined = (entity.type == "item-entity" and entity.stack) or (products and products[1] and products[1].name) or nil
        local space_in_stack = result_when_mined and inventory.can_insert(result_when_mined)
        if result_when_mined and space_in_stack then
            while entity.valid do
                local count = 0
                if inventory.can_insert(result_when_mined) then
                    local result = entity.mine { inventory = inventory, force = false, ignore_minable = false, raise_destroyed = true }
                    count = count + 1
                    if not result then break end
                else
                    break
                end
                if count > 9 then break end
            end
            abandon_task(spiderbot_id, player_index) -- successfully deconstructed entity or transferred 10 items to player inventory. task complete. reset task data and follow player
        elseif (entity.type == "cliff") then
            if inventory and inventory.get_item_count("cliff-explosives") > 0 then
                spiderbot.surface.create_entity {
                    name = "cliff-explosives",
                    position = spiderbot.position,
                    target = entity_position,
                    force = player.force,
                    raise_built = true,
                    speed = 0.125,
                }
                inventory.remove({ name = "cliff-explosives", count = 1 })
                abandon_task(spiderbot_id, player_index) -- successfully spawned cliff explosives. task complete. reset task data and follow player
            else
                abandon_task(spiderbot_id, player_index) -- no cliff explosives in inventory
            end
        else
            abandon_task(spiderbot_id, player_index) -- no space in inventory
        end
    else
        abandon_task(spiderbot_id, player_index) -- entity no longer needs to be deconstructed
    end
end

-- toggle the spiderbots on/off for the player
---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_spiderbots(event)
    local name = event.prototype_name or event.input_name
    if name ~= "toggle-spiderbots" then return end
    local player_index = event.player_index
    global.spiderbots_enabled = global.spiderbots_enabled or {}
    global.spiderbots_enabled[player_index] = not global.spiderbots_enabled[player_index]
    -- if not global.spiderbots_enabled[player_index] then
    --     local player = game.get_player(player_index)
    --     global.spiderbots = global.spiderbots or {}
    --     local player_spiders = global.spiderbots[player_index]
    --     if player and player.valid and player_spiders then
    --         for spider_id, spider in pairs(player_spiders) do
    --             if spider.valid then
    --                 abandon_task(spider, player)
    --             end
    --         end
    --     end
    -- end
    game.get_player(player_index).set_shortcut_toggled("toggle-spiderbots", global.spiderbots_enabled[player_index])
end

script.on_event("toggle-spiderbots", toggle_spiderbots)
script.on_event(defines.events.on_lua_shortcut, toggle_spiderbots)
