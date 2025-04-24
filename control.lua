
local constants = require("util/constants")
local max_task_range = constants.max_task_range
local half_max_task_range = constants.half_max_task_range
local double_max_task_range = constants.double_max_task_range
local allowed_controllers = constants.allowed_controllers

local color_util = require("util/colors")
local color = color_util.color

---@param player LuaPlayer
---@return LuaEntity?
local function get_player_entity(player)
    return player.physical_vehicle or player.character or nil
end

---@return string
local function get_random_backer_name()
    local backer_names = game.backer_names
    local index = math.random(#backer_names)
    return backer_names[index]
end

---@param name string
---@return boolean
local function is_backer_name(name)
    if not storage.backer_name_lookup then
        storage.backer_name_lookup = {}
        for _, backer_name in pairs(game.backer_names) do
            storage.backer_name_lookup[backer_name] = true
        end
    end
    return storage.backer_name_lookup[name]
end

---@param pos_1 MapPosition|TilePosition
---@param pos_2 MapPosition|TilePosition
---@return number
local function get_distance(pos_1, pos_2)
    local x = pos_1.x - pos_2.x
    local y = pos_1.y - pos_2.y
    return math.sqrt(x * x + y * y)
end

---@param entity LuaEntity
---@return integer
local function get_entity_uuid(entity)
    local registration_number, useful_id, type = script.register_on_object_destroyed(entity)
    if useful_id == 0 then
        if entity.type == "cliff" then
            return useful_id
        else
            return registration_number
        end
    else
        return registration_number
    end
end

-- register a spiderbot. saves spiderbot data to storage. updates the color, label, and follow target
---@param spiderbot LuaEntity
---@param player LuaPlayer
---@param player_index player_index
local function register_new_spiderbot(spiderbot, player, player_index)
    local uuid = get_entity_uuid(spiderbot)
    storage.spiderbots[player_index] = storage.spiderbots[player_index] or {}
    storage.spiderbots[player_index][uuid] = {
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
        spiderbot.entity_label = get_random_backer_name()
    end
    if table_size(storage.spiderbots[player_index]) == 1 then
        storage.spiderbots_enabled[player_index] = true
        player.set_shortcut_toggled("toggle-spiderbots", true)
    end
end

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

-- create a projectile that spawns a spiderbot where it lands
---@param origin MapPosition
---@param destination MapPosition
---@param player LuaPlayer
---@param speed_multiplier number?
---@param speed_override number?
local function create_spiderbot_projectile(origin, destination, player, speed_multiplier, speed_override)
    local character = player.character
    if not (character and character.valid) then return end
    character.surface.create_entity {
        name = "spiderbot-trigger",
        position = origin,
        force = player.force,
        player = player,
        source = character,
        target = destination,
        speed = speed_override or math.random() * (speed_multiplier or 1),
        raise_built = true,
    }
end

-- create the spiderbot projectile when a player uses a spiderbot capsule
---@param event EventData.on_player_used_capsule
local function on_player_used_capsule(event)
    if event.item.name ~= "spiderbot" then return end
    local position = event.position
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    -- try to find a valid position for the spiderbot to land. if a non_colliding_position is found then the spiderbot can scramble to it from the original position once spawned
    local non_colliding_position = player.surface.find_non_colliding_position("spiderbot-leg-1", position, 3.75, 0.5)
    -- refund the spiderbot item if there is no valid position
    local max_followers = storage.spiderbot_follower_count[player.force.name]
    local follower_count = storage.spiderbots[player.index] and table_size(storage.spiderbots[player.index]) or 0
    if non_colliding_position and (follower_count < max_followers) then
        create_spiderbot_projectile(player.position, position, player, 1, 0.25) -- use the actual position, because that's what the player wanted, and since a non_colliding position is known to exist that means the spiderbot can scramble around to it
    else
        local inventory = player.get_main_inventory()
        if inventory and inventory.valid then
            local item_stack = { name = "spiderbot", count = 1 }
            local cursor_stack = player.cursor_stack
            if cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "spiderbot" then
                item_stack.count = item_stack.count + cursor_stack.count
                player.cursor_stack.set_stack(item_stack)
            else
                player.cursor_stack.set_stack(item_stack)
            end
        end
    end
end

script.on_event(defines.events.on_player_used_capsule, on_player_used_capsule)

-- remove the spiderbot data when a spiderbot is destroyed
---@param event EventData.on_object_destroyed
local function on_spider_destroyed(event)
    local unit_number = event.useful_id
    if not unit_number then return end
    for player_index, spiderbot_data in pairs(storage.spiderbots) do
        for spider_id, data in pairs(spiderbot_data) do
            if data.spiderbot_id == unit_number then
                storage.spiderbots[player_index][spider_id] = nil
                return
            end
        end
    end
end

script.on_event(defines.events.on_object_destroyed, on_spider_destroyed)

-- abandon the current task, set state to idle, and follow the player
---@param spiderbot_id uuid
---@param player_index player_index
local function reset_task_data(spiderbot_id, player_index)
    local spiderbots = storage.spiderbots[player_index]
    local spiderbot_data = spiderbots[spiderbot_id]
    if spiderbot_data then
        spiderbot_data.task = nil
        spiderbot_data.status = "idle"
        spiderbot_data.path_request_id = nil
        local player = spiderbot_data.player
        local spiderbot = spiderbot_data.spiderbot
        if player.valid and spiderbot.valid then
            spiderbot.color = player.color
            local target = get_player_entity(player)
            if target and target.valid then
                spiderbot.follow_target = target
            end
        else
            spiderbots[spiderbot_id] = nil
        end
    end
end

---@param position MapPosition
---@param radius number
---@return MapPosition
local function get_random_position_in_radius(position, radius)
    local angle = math.random() * 2 * math.pi
    local length = radius * math.random() ^ 0.25
    local x = position.x + length * math.cos(angle)
    local y = position.y + length * math.sin(angle)
    return { x = x, y = y }
end

---@param position MapPosition
---@return MapPosition
local function get_random_position_on_tile(position)
    local radius = math.sqrt(math.random()) * 0.5
    local angle = math.random() * 2 * math.pi
    local x = position.x + radius * math.cos(angle)
    local y = position.y + radius * math.sin(angle)
    return { x = x, y = y }
end

---@param player LuaPlayer
local function relink_following_spiderbots(player)
    if not (player and player.valid) then return end
    local player_index = player.index
    local spiderbots = storage.spiderbots[player_index]
    if not spiderbots then return end
    local character_controller = player.controller_type == defines.controllers.character
    if not character_controller then return end
    local player_entity = get_player_entity(player)
    if not (player_entity and player_entity.valid) then return end
    for spider_id, spiderbot_data in pairs(spiderbots) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot.valid then
            if spiderbot.surface_index == player_entity.surface_index then
                if spiderbot_data.status == "idle" then
                    spiderbot.follow_target = player_entity
                elseif spiderbot_data.status == "path_requested" then
                    spiderbot.follow_target = player_entity
                elseif spiderbot_data.status == "task_assigned" then
                    local task = spiderbot_data.task
                    if not (task and task.entity.valid) then
                        reset_task_data(spider_id, player_index)
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
            else
                local position_in_radius = get_random_position_in_radius(player_entity.position, 50)
                local non_colliding_position = player_entity.surface.find_non_colliding_position("spiderbot-leg-1", position_in_radius, 50, 0.5)
                local position = non_colliding_position or player_entity.position
                spiderbot.teleport(position, player_entity.surface, true)
                reset_task_data(spider_id, player_index)
            end
        else
            spiderbots[spider_id] = nil
        end
    end
end

---@param player LuaPlayer
---@param player_index player_index
---@param player_entity LuaEntity
local function redeploy_active_spiderbots(player, player_index, player_entity)
    local spiderbots = storage.spiderbots[player_index]
    if not spiderbots then return end
    local surface = player_entity.surface
    local surface_index = player_entity.surface_index
    for spider_id, spiderbot_data in pairs(spiderbots) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot.valid then
            local position_in_radius = get_random_position_in_radius(player_entity.position, 15)
            local non_colliding_position = surface.find_non_colliding_position("character", position_in_radius, 50, 0.5)
            local position = non_colliding_position or player_entity.position
            spiderbot.destroy({ raise_destroy = true })
            reset_task_data(spider_id, player_index)
            create_spiderbot_projectile(player_entity.position, position, player, 1, 0.25)
        end
    end
    relink_following_spiderbots(player)
end

---@param event EventData.on_player_changed_surface
local function on_player_changed_surface(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    if not allowed_controllers[player.controller_type] then return end
    local player_entity = get_player_entity(player)
    if not (player_entity and player_entity.valid) then return end
    local planet = player.surface.planet
    if planet and planet.valid and planet.name == "factory-travel-surface" then return end
    redeploy_active_spiderbots(player, player_index, player_entity)
end

script.on_event(defines.events.on_player_changed_surface, on_player_changed_surface)

---@param event EventData.script_raised_teleported
local function on_script_raised_teleport(event)
    local entity = event.entity
    if entity.type ~= "character" then return end
    local player = entity.player
    if not (player and player.valid) then return end
    local spiderbots = storage.spiderbots[player.index]
    if not spiderbots then return end
    if not allowed_controllers[player.controller_type] then return end
    redeploy_active_spiderbots(player, player.index, entity)
end

script.on_event(defines.events.script_raised_teleported, on_script_raised_teleport)

---@param event EventData.on_player_changed_position
local function on_player_changed_position(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    local character = get_player_entity(player)
    if not (character and character.valid) then return end
    local planet = player.surface.planet
    if planet and planet.valid and planet.name == "factory-travel-surface" then return end
    local position = character.position
    local surface_index = character.surface_index
    storage.previous_player_position = storage.previous_player_position or {}
    local previous_position = storage.previous_player_position[player_index] or position
    storage.previous_player_surface_index = storage.previous_player_surface_index or {}
    local previous_surface_index = storage.previous_player_surface_index[player_index] or surface_index
    local same_surface = previous_surface_index == surface_index
    local distance_moved = get_distance(previous_position, position)
    if same_surface and (distance_moved > 50) then
        redeploy_active_spiderbots(player, player_index, character)
    end
    storage.previous_player_position[player_index] = position
    storage.previous_player_surface_index[player_index] = surface_index
end

script.on_event(defines.events.on_player_changed_position, on_player_changed_position)

---@param event EventData.on_player_driving_changed_state
local function on_player_driving_changed_state(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    relink_following_spiderbots(player)
end

script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)

---@param event EventData.on_player_controller_changed
local function on_player_controller_changed(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    relink_following_spiderbots(player)
end

script.on_event(defines.events.on_player_controller_changed, on_player_controller_changed)

---@param spiderbot_id uuid?
---@param path_request_id integer?
---@return spiderbot_data?
local function get_spiderbot_data(spiderbot_id, path_request_id)
    for player_index, spiderbots in pairs(storage.spiderbots) do
        for spider_id, spiderbot_data in pairs(spiderbots) do
            if spiderbot_id and spiderbot_data.spiderbot_id == spiderbot_id then
                return spiderbot_data
            elseif path_request_id and spiderbot_data.path_request_id == path_request_id then
                return spiderbot_data
            end
        end
    end
end

---@param spiderbot LuaEntity
---@param entity LuaEntity
---@return integer
local function request_path(spiderbot, entity)
    local spider_leg_bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } }
    -- just use the player collision layer, so the spiderbots can path through anything the player can walk through. even though they can't walk through ghosts, they can still path through them and try to fit their legs around them
    local spider_leg_collision_mask = {
        layers = {
            -- ground_tile = true,
            water_tile = true,
            -- resource = true,
            -- doodad = true,
            -- floor = true,
            -- rail = true,
            -- transport_belt = true,
            -- item = true,
            -- ghost = true,
            object = true,
            -- player = true,
            -- car = true,
            -- train = true,
            -- elevated_rail = true,
            -- elevated_train = true,
            empty_space = true,
            lava_tile = true,
            -- meltable = true,
            rail_support = true,
            -- trigger_target = true,
            -- cliff = true,
            -- is_lower_object = true,
            -- is_object = true
            spiderbot_leg = true,
        },
        not_colliding_with_itself = true,
        consider_tile_transitions = false,
        colliding_with_tiles_only = false,
    }
    local path_to_entity_flags = { cache = false, low_priority = true }
    local bounding_box = entity.bounding_box
    local right_bottom = bounding_box.right_bottom
    local left_top = bounding_box.left_top
    local x = math.abs(right_bottom.x - left_top.x)
    local y = math.abs(right_bottom.y - left_top.y)
    local non_colliding_position = spiderbot.surface.find_non_colliding_position("spiderbot-leg-1", entity.position, 25, 0.5)
    local goal = non_colliding_position or entity.position
    local request_parameters = {
        bounding_box = spider_leg_bounding_box,
        collision_mask = spider_leg_collision_mask,
        start = spiderbot.position,
        goal = goal,
        force = spiderbot.force,
        radius = math.min(x, y) / 3,
        can_open_gates = true,
        path_resolution_modifier = 0,
        pathfind_flags = path_to_entity_flags,
        max_gap_size = 1,
    }
    local path_request_id = spiderbot.surface.request_path(request_parameters)
    return path_request_id
end

---@param inventory LuaInventory
---@param item ItemIDAndQualityIDPair|LuaItemStack|string
---@return boolean
local function inventory_has_item(inventory, item)
    return inventory.get_item_count(item) >= 1 and true or false
end

---@param inventory LuaInventory
---@param item ItemStackDefinition|LuaItemStack|string
---@return boolean
local function inventory_has_space(inventory, item)
    return inventory.can_insert(item) and true or false
end

---@param entity LuaEntity
---@return LuaInventory?
local function get_entity_inventory(entity)
    local entity_type = entity.type
    if entity_type == "character" then
        return entity.get_inventory(defines.inventory.character_main)
    elseif entity_type == "car" then
        return entity.get_inventory(defines.inventory.car_trunk)
    elseif entity_type == "spider-vehicle" then
        return entity.get_inventory(defines.inventory.spider_trunk)
    elseif entity_type == "cargo-wagon" then
        return entity.get_inventory(defines.inventory.cargo_wagon)
    end
end

---@param spiderbot LuaEntity
---@param player LuaPlayer
local function perform_directional_jump(spiderbot, player)
    local surface = spiderbot.surface
    local orientation = (0.25 - spiderbot.torso_orientation) * 2 * math.pi -- convert to radians, account for factorio RealOrientation 0 = North (sin/cos assume 0 = East)
    local spiderbot_position = spiderbot.position
    local target_position = spiderbot.position
    local cos_orientation = math.cos(orientation)
    local sin_orientation = math.sin(orientation)
    for step_distance = 2, 50 do
        local x = target_position.x + step_distance * cos_orientation
        local y = target_position.y - step_distance * sin_orientation
        local jump_position = surface.find_non_colliding_position("spiderbot-leg-1", { x = x, y = y }, 0.5, 0.1)
        if jump_position then
            target_position = jump_position
            break
        end
    end
    local jump_position = surface.find_non_colliding_position("spiderbot-leg-1", target_position, 100, 0.5)
    if not jump_position then jump_position = get_random_position_in_radius(spiderbot_position, 25) end
    create_spiderbot_projectile(spiderbot_position, jump_position, player, 1)
    spiderbot.destroy({ raise_destroy = true })
end

---@param entity LuaEntity
local function free_stuck_spiderbots(entity)
    if not (entity and entity.valid) then return end
    local colliding_spider_legs = entity.surface.find_entities_filtered {
        type = "spider-leg",
        area = entity.bounding_box
    }
    for _, colliding_leg in pairs(colliding_spider_legs) do
        if colliding_leg.valid then
            for _, player_data in pairs(storage.spiderbots) do
                for _, spiderbot_data in pairs(player_data) do
                    local spiderbot = spiderbot_data.spiderbot
                    if spiderbot.valid then
                        local legs = spiderbot.get_spider_legs()
                        for _, leg in pairs(legs) do
                            if leg.valid and colliding_leg.valid and (leg.unit_number == colliding_leg.unit_number) then
                                reset_task_data(spiderbot_data.spiderbot_id, spiderbot_data.player_index)
                                perform_directional_jump(spiderbot, spiderbot_data.player)
                                goto next_leg
                            end
                        end
                    end
                end
            end
        end
        ::next_leg::
    end
end

---@param origin MapPosition|LuaEntity
---@param destination MapPosition|LuaEntity
---@param item string
---@param player LuaPlayer
---@param speed_modifier number?
local function create_item_projectile(origin, destination, item, player, speed_modifier)
    local origin_position = origin.position or origin
    local destination_position = destination.position or destination
    local dist = get_distance(origin_position, destination_position)
    local max_time = 20
    local min_speed = 0.3
    player.surface.create_entity {
        name = item .. "-spiderbot-projectile",
        position = get_random_position_on_tile(origin_position),
        target = destination,
        force = player.force,
        speed = math.max(min_speed, (dist / max_time)) / (speed_modifier or 1),
    }
end

---@param item ItemIDAndQualityIDPair|LuaItemStack
---@return ItemStackDefinition
local function get_item_stack_definition(item)
    local item_name = type(item.name) == "string" and item.name or item.name.name --[[@as string]]
    local quality_name = type(item.quality) == "string" and item.quality or item.quality and item.quality.name or "normal" --[[@as string]]
    local item_stack = { name = item_name, quality = quality_name }
    return item_stack
end

---@param spiderbot_data spiderbot_data
local function build_ghost(spiderbot_data)
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local entity = spiderbot_data.task.entity
    if player and player.valid and entity and entity.valid then
        local items = entity.ghost_prototype.items_to_place_this
        local item_stack = items and items[1]
        if item_stack then
            local item_quality_pair = { name = item_stack.name, quality = entity.quality }
            local player_entity = get_player_entity(player)
            if player_entity and player_entity.valid then
                local inventory = get_entity_inventory(player_entity)
                if inventory and inventory.valid and inventory_has_item(inventory, item_quality_pair) then
                    local dictionary, revived_entity, request_proxy = entity.revive({ return_item_request_proxy = false, raise_revive = true })
                    if revived_entity then
                        inventory.remove(item_stack)
                        local spiderbot = spiderbot_data.spiderbot
                        create_item_projectile(player_entity, spiderbot, item_stack.name, player)
                        free_stuck_spiderbots(revived_entity)
                    else
                        free_stuck_spiderbots(entity)
                    end
                end
            end
        end
    end
    reset_task_data(spiderbot_id, player_index)
end

---@param inventory LuaInventory
---@return boolean, LuaQualityPrototype?
local function inventory_has_cliff_explosives(inventory)
    local quality_prototypes = prototypes.quality
    for name, quality_prototype in pairs(quality_prototypes) do
        local item = { name = "cliff-explosives", quality = quality_prototype }
        if inventory_has_item(inventory, item) then
            return true, quality_prototype
        end
    end
    return false, nil
end

---@param spiderbot_data spiderbot_data
local function find_nearby_cliff_to_deconstruct(spiderbot_data)
    local surface = spiderbot_data.spiderbot.surface
    local spiderbot_position = spiderbot_data.spiderbot.position
    local cliff = surface.find_entities_filtered {
        type = "cliff",
        position = spiderbot_position,
        radius = 32,
        limit = 1,
        to_be_deconstructed = true,
    }[1]
    if cliff then
        local data = storage.spiderbots[spiderbot_data.player_index][spiderbot_data.spiderbot_id]
        data.task = {
            task_type = "deconstruct_entity",
            entity_id = get_entity_uuid(cliff),
            entity = cliff,
        }
        data.status = "path_requested"
        data.path_request_id = request_path(spiderbot_data.spiderbot, cliff)
    end
end

---@param entity LuaEntity
---@return "small"|"medium"|"large"|"huge" string
local function get_entity_size_category(entity)
    local bounding_box = entity.bounding_box
    local right_bottom = bounding_box.right_bottom
    local left_top = bounding_box.left_top
    local x = math.abs(right_bottom.x - left_top.x)
    local y = math.abs(right_bottom.y - left_top.y)
    local size = x * y
    if size <= 1 then
        return "small"
    elseif size <= 4 then
        return "medium"
    elseif size <= 9 then
        return "large"
    else
        return "huge"
    end
end

---@param entity LuaEntity
---@return table<string, integer>
local function get_inventory_contents(entity)
    local entity_inventory_contents = {}
    for i = 1, 11 do
        local inventory_contents = entity.get_inventory(i)
        if inventory_contents and inventory_contents.valid then
            for _, item in pairs(inventory_contents.get_contents()) do
                local item_name = item.name
                local item_count = item.count
                entity_inventory_contents[item_name] = (entity_inventory_contents[item_name] or 0) + item_count
            end
        end
    end
    local belt_types = {
        ["lane-splitter"] = true,
        ["linked-belt"] = true,
        ["loader-1x1"] = true,
        ["loader"] = true,
        ["splitter"] = true,
        ["transport-belt"] = true,
        ["underground-belt"] = true
    }
    if belt_types[entity.type] then
        for i = 1, entity.get_max_transport_line_index() do
            local transport_line = entity.get_transport_line(i)
            if transport_line and transport_line.valid then
                local transport_line_contents = transport_line.get_contents()
                for _, item in pairs(transport_line_contents) do
                    local item_name = item.name
                    local item_count = item.count
                    entity_inventory_contents[item_name] = (entity_inventory_contents[item_name] or 0) + item_count
                end
            end
        end
    end
    return entity_inventory_contents
end

---@param entity LuaEntity
---@return ItemStackDefinition|LuaItemStack?
local function get_result_when_mined(entity)
    if entity.type == "item-entity" then
        return entity.stack
    end
    local prototype = entity.prototype
    local products = prototype.mineable_properties.products
    if not products then return end
    for _, product in pairs(products) do
        if product.type == "item" then
            local amount = product.amount or product.amount_max
            ---@type ItemStackDefinition
            local result = {
                name = product.name,
                count = amount,
                quality = entity.quality.name,
            }
            return result
        end
    end
end

---@param path SoundPath
---@param fallback SoundPath
---@return SoundPath
local function get_valid_sound_path(path, fallback)
    if helpers.is_valid_sound_path(path) then
        return path
    else
        return fallback
    end
end

---@param spiderbot_data spiderbot_data
local function deconstruct_entity(spiderbot_data)
    local spiderbot = spiderbot_data.spiderbot
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local entity = spiderbot_data.task.entity
    if player and player.valid then
        if entity and entity.valid then
            if entity.to_be_deconstructed() then
                local mining_result = get_result_when_mined(entity)
                local player_entity = get_player_entity(player)
                if player_entity and player_entity.valid then
                    local inventory = get_entity_inventory(player_entity)
                    if inventory and inventory.valid then
                        local entity_position = entity.position
                        if mining_result and inventory_has_space(inventory, mining_result) then
                            local count = 0
                            local size = get_entity_size_category(entity)
                            local entity_name = entity.name
                            local entity_type = entity.type
                            local mining_result_name = mining_result.name
                            local entity_inventory_contents = get_inventory_contents(entity)
                            while entity.valid do
                                if inventory.can_insert(mining_result) then
                                    local result = entity.mine {
                                        inventory = inventory,
                                        force = false,
                                        ignore_minable = false,
                                        raise_destroyed = true
                                    }
                                    count = count + 1
                                    if not result then break end
                                else
                                    break
                                end
                                if count > 4 then break end
                                create_item_projectile(spiderbot, player_entity, mining_result_name, player)
                                for item_name, item_count in pairs(entity_inventory_contents) do
                                    for i = 1, math.max(math.ceil(item_count * 0.75), 1) do
                                        create_item_projectile(spiderbot, player_entity, item_name, player, math.random(5, 10) / 5)
                                    end
                                end
                            end
                            local mined_sound_path = get_valid_sound_path(entity_name .. "-mined_sound", "utility/deconstruct_" .. size)
                            spiderbot.surface.play_sound {
                                path = mined_sound_path,
                                position = entity_position,
                            }
                            local mining_sound_path = get_valid_sound_path(entity_name .. "-mining_sound", "utility/mining_wood")
                            if entity_type == "tree" then
                                if math.random() < 0.5 then
                                    spiderbot.surface.play_sound {
                                        path = mining_sound_path,
                                        position = entity_position,
                                    }
                                end
                            else spiderbot.surface.play_sound {
                                    path = mining_sound_path,
                                    position = entity_position,
                                }
                            end
                        elseif entity.type == "cliff" then
                            local has_cliff_explosives, quality = inventory_has_cliff_explosives(inventory)
                            if has_cliff_explosives then
                                spiderbot.surface.create_entity {
                                    name = "cliff-explosives",
                                    quality = quality,
                                    position = spiderbot.position,
                                    target = entity_position,
                                    force = player.force,
                                    raise_built = true,
                                    speed = 0.0125,
                                }
                                inventory.remove({ name = "cliff-explosives", count = 1, quality = quality })
                                create_item_projectile(player_entity, spiderbot, "cliff-explosives", player)
                            end
                        end
                    end
                end
            end
        elseif spiderbot_data.task.entity_id == 0 then
            find_nearby_cliff_to_deconstruct(spiderbot_data)
            return
        end
    end
    reset_task_data(spiderbot_id, player_index)
end

---@param spiderbot_data spiderbot_data
local function upgrade_entity(spiderbot_data)
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local entity = spiderbot_data.task.entity
    if player and player.valid and entity and entity.valid and entity.to_be_upgraded() then
        local player_entity = get_player_entity(player)
        if player_entity and player_entity.valid then
            local inventory = get_entity_inventory(player_entity)
            if inventory and inventory.valid then
                local entity_prototype, quality_prototype = entity.get_upgrade_target()
                local items = entity_prototype and entity_prototype.items_to_place_this
                local item_stack = items and items[1]
                if entity_prototype and item_stack then
                    local item_with_quality = { name = item_stack.name, quality = quality_prototype }
                    if inventory_has_item(inventory, item_with_quality) then
                        local upgrade_name = entity_prototype.name
                        local type = entity.type
                        local is_underground_belt = (type == "underground-belt")
                        local is_loader = (type == "loader" or type == "loader-1x1")
                        local underground_type = is_underground_belt and entity.belt_to_ground_type
                        local loader_type = is_loader and entity.loader_type
                        local create_entity_type = underground_type or loader_type or nil
                        local result_item = get_result_when_mined(entity)
                        local upgraded_entity = entity.surface.create_entity {
                            name = upgrade_name,
                            position = entity.position,
                            direction = entity.direction,
                            quality = quality_prototype,
                            player = player,
                            fast_replace = true,
                            force = entity.force,
                            spill = true,
                            type = create_entity_type,
                            raise_built = true,
                        }
                        if upgraded_entity then
                            inventory.remove(item_stack)
                            if (player.controller_type ~= defines.controllers.character) and result_item then
                                inventory.insert(result_item)
                            end
                            local spiderbot = spiderbot_data.spiderbot
                            create_item_projectile(player_entity, spiderbot, item_with_quality.name, player)
                            if result_item then
                                create_item_projectile(spiderbot, player_entity, result_item.name, player)
                            end
                            local build_sound_path = get_valid_sound_path(upgrade_name .. "-build_sound", "utility/build_" .. get_entity_size_category(upgraded_entity))
                            upgraded_entity.surface.play_sound {
                                path = build_sound_path,
                                position = upgraded_entity.position,
                            }
                        end
                    end
                end
            end
        end
    end
    reset_task_data(spiderbot_id, player_index)
end

---@param spiderbot_data spiderbot_data
local function insert_items(spiderbot_data)
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    local proxy = spiderbot_data.task.entity
    if player and player.valid and proxy and proxy.valid then
        local player_entity = get_player_entity(player)
        local target_entity = proxy.proxy_target
        if player_entity and player_entity.valid and target_entity and target_entity.valid then
            local player_inventory = get_entity_inventory(player_entity)
            if player_inventory and player_inventory.valid then
                local insert_plan = proxy.insert_plan
                local removal_plan = proxy.removal_plan
                if removal_plan and removal_plan[1] then
                    for index, item_to_remove in pairs(removal_plan) do
                        local item_stack = get_item_stack_definition(item_to_remove.id)
                        if inventory_has_space(player_inventory, item_stack) then
                            local removal_inventories = item_to_remove.items.in_inventory
                            local removal_data = removal_inventories and removal_inventories[1]
                            local removal_inventory_id = removal_data and removal_data.inventory
                            local removal_inventory = removal_inventory_id and target_entity.get_inventory(removal_inventory_id)
                            if removal_data and removal_inventory and removal_inventory.valid then
                                local stack = removal_inventory[removal_data.stack + 1]
                                if stack and stack.valid and stack.valid_for_read then
                                    stack.count = stack.count - 1
                                    if stack.count <= 0 then
                                        stack.clear()
                                    end
                                end
                                player_inventory.insert(item_stack)
                                removal_data.count = removal_data.count or 1
                                removal_data.count = removal_data.count - 1
                                if removal_inventories and removal_data.count <= 0 then
                                    table.remove(removal_inventories, 1)
                                end
                                if not (item_to_remove and item_to_remove.items.in_inventory and item_to_remove.items.in_inventory[1]) then
                                    table.remove(removal_plan, index)
                                end
                                local sound_path = item_to_remove.id.name .. "-inventory_move_sound"
                                if helpers.is_valid_sound_path(sound_path) then
                                    target_entity.surface.play_sound {
                                        path = sound_path,
                                        position = target_entity.position,
                                    }
                                end
                                local spiderbot = spiderbot_data.spiderbot
                                create_item_projectile(spiderbot, player_entity, item_stack.name, player)
                                break
                            end
                        end
                    end
                    proxy.removal_plan = removal_plan
                elseif insert_plan and insert_plan[1] then
                    for index, item_to_insert in pairs(insert_plan) do
                        local item_stack = get_item_stack_definition(item_to_insert.id)
                        if inventory_has_item(player_inventory, item_stack) then
                            local insert_inventories = item_to_insert.items.in_inventory
                            local insert_data = insert_inventories and insert_inventories[1]
                            local insert_inventory_id = insert_data and insert_data.inventory
                            local insert_inventory = insert_inventory_id and target_entity.get_inventory(insert_inventory_id)
                            if insert_data and insert_inventory and insert_inventory.valid then
                                local stack = insert_inventory[insert_data.stack + 1]
                                if stack and stack.valid then
                                    if stack.valid_for_read then
                                        stack.count = stack.count + 1
                                    else
                                        stack.set_stack(item_stack)
                                    end
                                end
                                player_inventory.remove(item_stack)
                                insert_data.count = insert_data.count or 1
                                insert_data.count = insert_data.count - 1
                                if insert_inventories and insert_data.count <= 0 then
                                    table.remove(insert_inventories, 1)
                                end
                                if not (item_to_insert and item_to_insert.items.in_inventory and item_to_insert.items.in_inventory[1]) then
                                    table.remove(insert_plan, index)
                                end
                                local sound_path = item_to_insert.id.name .. "-inventory_move_sound"
                                if helpers.is_valid_sound_path(sound_path) then
                                    target_entity.surface.play_sound {
                                        path = sound_path,
                                        position = target_entity.position,
                                    }
                                end
                                local spiderbot = spiderbot_data.spiderbot
                                create_item_projectile(player_entity, spiderbot, item_stack.name, player)
                                break
                            end
                        end
                    end
                    proxy.insert_plan = insert_plan
                end
            end
        end
    end
    reset_task_data(spiderbot_id, player_index)
end

---@param spiderbot_data spiderbot_data
local function complete_task(spiderbot_data)
    local type = spiderbot_data.task.task_type
    if type == "build_ghost" then
        build_ghost(spiderbot_data)
    elseif type == "deconstruct_entity" then
        deconstruct_entity(spiderbot_data)
    elseif type == "upgrade_entity" then
        upgrade_entity(spiderbot_data)
    elseif type == "insert_items" then
        insert_items(spiderbot_data)
    elseif type == "repair_entity" then
    end
end

---@param event EventData.on_spider_command_completed
local function on_spider_command_completed(event)
    local spiderbot = event.vehicle
    if not (spiderbot and spiderbot.valid) then return end
    if not (spiderbot.name == "spiderbot") then return end
    local destinations = spiderbot.autopilot_destinations
    local destination_count = destinations and #destinations or 0
    if destination_count == 0 then
        local spiderbot_id = get_entity_uuid(spiderbot)
        local spiderbot_data = get_spiderbot_data(spiderbot_id)
        if spiderbot_data then
            local status = spiderbot_data.status
            if status == "task_assigned" then
                complete_task(spiderbot_data)
            end
        end
    else
        local chance = math.random()
        if chance < 0.0625 then -- 1/16
            local spiderbot_id = get_entity_uuid(spiderbot)
            local spiderbot_data = get_spiderbot_data(spiderbot_id)
            if spiderbot_data then
                local player = spiderbot_data.player
                local player_index = spiderbot_data.player_index
                if player.valid then
                    -- if the player doesn't have a valid character anymore, reset the task data and attempt to follow the player
                    local player_entity = get_player_entity(player)
                    if not (player_entity and player_entity.valid) then reset_task_data(spiderbot_id, player_index) return end
                    -- if the player is too far away from the task position, abandon the task and follow the player
                    local task = spiderbot_data.task
                    if task and task.entity then
                        local task_entity = task.entity
                        local task_position = task_entity.valid and task_entity.position
                        if task_position then
                            local distance_from_task = get_distance(task_position, player_entity.position)
                            if distance_from_task > (double_max_task_range) then
                                reset_task_data(spiderbot_id, player_index)
                            end
                        end
                    end
                end
            end
        end
    end
end

script.on_event(defines.events.on_spider_command_completed, on_spider_command_completed)

---@param event EventData.on_script_path_request_finished
local function on_script_path_request_finished(event)
    local path_request_id = event.id
    local path = event.path
    local spiderbot_data = get_spiderbot_data(nil, path_request_id)
    if not spiderbot_data then return end
    local spiderbot = spiderbot_data.spiderbot
    local spiderbot_id = spiderbot_data.spiderbot_id
    local player = spiderbot_data.player
    local player_index = spiderbot_data.player_index
    if not path then reset_task_data(spiderbot_id, player_index) return end
    if not (spiderbot and spiderbot.valid) then reset_task_data(spiderbot_id, player_index) return end
    if not (player and player.valid) then reset_task_data(spiderbot_id, player_index) return end
    if not storage.spiderbots_enabled[player_index] then reset_task_data(spiderbot_id, player_index) return end
    local status = spiderbot_data.status
    if status == "path_requested" then
        local task = spiderbot_data.task
        if not (task and task.entity and task.entity.valid) then reset_task_data(spiderbot_id, player_index) return end
        if not (task.entity.surface_index == spiderbot.surface_index) then reset_task_data(spiderbot_id, player_index) return end
        local task_position = task.entity.position
        local distance_from_task = get_distance(task_position, spiderbot.position)
        if distance_from_task > max_task_range then reset_task_data(spiderbot_id, player_index) return end
        spiderbot.autopilot_destination = nil
        local task_colors = {
            deconstruct_entity = color.red,
            build_ghost = color.blue,
            upgrade_entity = color.green,
            insert_items = color.yellow,
            repair_entity = color.white,
        }
        spiderbot.color = task_colors[task.task_type] or color.white
        -- local previous_position = spiderbot.position
        for _, waypoint in pairs(path) do
            local waypoint_position = waypoint.position
            spiderbot.add_autopilot_destination(waypoint_position)
            -- previous_position = waypoint_position
        end
        spiderbot_data.status = "task_assigned"
        spiderbot_data.path_request_id = nil
    end
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param player_index player_index
local function clear_visualization_renderings(player_index)
    local render_objects = storage.render_objects[player_index]
    if not render_objects then return end
    for _, render_object in pairs(render_objects) do
        render_object.destroy()
    end
    storage.render_objects[player_index] = nil
end

---@param event EventData.on_player_cursor_stack_changed
local function on_player_cursor_stack_changed(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    local player_entity = get_player_entity(player)
    if not (player_entity and player_entity.valid) then return end
    if not storage.spiderbots_enabled[player_index] then
        clear_visualization_renderings(player_index)
        return
    end
    local show_visualization = player.is_cursor_blueprint()
    if not show_visualization then
        local cursor_stack = player.cursor_stack
        show_visualization = cursor_stack and (cursor_stack.is_deconstruction_item or cursor_stack.is_upgrade_item or cursor_stack.is_blueprint or cursor_stack.is_blueprint_book) or false
    end
    if show_visualization then
        clear_visualization_renderings(player_index)
        local render_object = rendering.draw_sprite {
            sprite = "utility/construction_radius_visualization",
            surface = player_entity.surface,
            target = player.character,
            x_scale = max_task_range * 3.2, -- i don't really understand why this is the magic number, but it's what got the sprite to be the correct size
            y_scale = max_task_range * 3.2,
            render_layer = "radius-visualization",
            players = { player },
            only_in_alt_mode = true,
            tint = { r = 0.45, g = 0.4, b = 0.4, a = 0.5 }, -- by trial and error, this is the closest i could match the vanilla construction radius visualization look
        }
        if render_object then
            storage.render_objects[player_index] = storage.render_objects[player_index] or {}
            table.insert(storage.render_objects[player_index], render_object)
        end
    else
        clear_visualization_renderings(player_index)
    end
end

script.on_event(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)

---@param entity_id uuid
---@return boolean
local function is_task_assigned(entity_id)
    for player_index, spiderbots in pairs(storage.spiderbots) do
        for spider_id, spiderbot_data in pairs(spiderbots) do
            local task = spiderbot_data.task
            if task and (task.entity_id == entity_id) then
                return true
            end
        end
    end
    return false
end

---@param spiderbot LuaEntity
---@param player LuaPlayer
local function return_spiderbot_to_inventory(spiderbot, player)
    local spiderbot_id = get_entity_uuid(spiderbot)
    local player_index = player.index
    reset_task_data(spiderbot_id, player_index)
    local player_entity = get_player_entity(player)
    if not (player_entity and player_entity.valid) then return end
    player_entity.surface.create_entity {
        name = "spiderbot-no-trigger",
        position = spiderbot.position,
        force = player.force,
        -- player = player,
        source = spiderbot,
        target = player_entity,
        speed = math.random(),
        -- raise_built = true,
    }
    local inventory = get_entity_inventory(player_entity)
    if inventory and inventory.valid and inventory_has_space(inventory, "spiderbot") then
        inventory.insert { name = "spiderbot", count = 1 }
    else
        player_entity.surface.spill_item_stack {
            position = spiderbot.position,
            stack = { name = "spiderbot", count = 1 },
            enable_looted = true,
            force = player_entity.force,
            allow_belts = false,
        }
    end
    spiderbot.destroy()
end

---@param tbl table
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

---@generic K, V
---@param tbl table<K, V>
---@return fun():K, V
local function random_pairs(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    shuffle(keys)
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], tbl[keys[i]]
        end
    end
end

---@param event NthTickEventData
local function on_tick(event)
    for _, player in pairs(game.connected_players) do
        local player_index = player.index
        storage.spiderbots[player_index] = storage.spiderbots[player_index] or {}
        local spiderbots = storage.spiderbots[player_index]
        -- goto next player if the player has no spiderbots deployed
        if table_size(spiderbots) == 0 then goto next_player end
        local player_entity = get_player_entity(player)
        -- relink spiderbots if the player changes character
        if not (player_entity and player_entity.valid) then
            relink_following_spiderbots(player)
            goto next_player
        end
        local player_uuid = get_entity_uuid(player_entity)
        storage.previous_player_entity[player_index] = storage.previous_player_entity[player_index] or player_uuid
        -- relink spiderbots if the player changes character
        if storage.previous_player_entity[player_index] ~= player_uuid then
            relink_following_spiderbots(player)
            storage.previous_player_entity[player_index] = player_uuid
            goto next_player
        end
        local player_color = player.color
        storage.previous_player_color[player_index] = storage.previous_player_color[player_index] or player_color
        local previous_color = storage.previous_player_color[player_index]
        -- update spiderbots if the player changes color
        if not (previous_color.r == player_color.r and previous_color.g == player_color.g and previous_color.b == player_color.b) then
            for spider_id, spiderbot_data in pairs(spiderbots) do
                local spiderbot = spiderbot_data.spiderbot
                if spiderbot.valid then
                    if not (spiderbot_data.status == "task_assigned") then
                        spiderbot.color = player_color
                    end
                end
            end
            storage.previous_player_color[player_index] = player_color
        end
        -- goto next player if player is not in an allowed controller type
        if not allowed_controllers[player.controller_type] then goto next_player end
        local inventory = get_entity_inventory(player_entity)
        if not (inventory and inventory.valid) then goto next_player end
        -- setup local data
        local player_force = { player.force.name, "neutral" }
        local surface = player_entity.surface
        local character_position_x = player_entity.position.x
        local character_position_y = player_entity.position.y
        local area = {
            { character_position_x - half_max_task_range, character_position_y - half_max_task_range },
            { character_position_x + half_max_task_range, character_position_y + half_max_task_range },
        }
        local decon_entities = nil --[[@type LuaEntity[]?]]
        local revive_entities = nil --[[@type LuaEntity[]?]]
        local upgrade_entities = nil --[[@type LuaEntity[]?]]
        local item_proxy_entities = nil --[[@type LuaEntity[]?]]
        local decon_tiles = nil --[[@type LuaTile[]?]]
        local revive_tiles = nil --[[@type LuaTile[]?]]
        local decon_ordered = false
        local revive_ordered = false
        local upgrade_ordered = false
        local item_proxy_ordered = false
        local max_spiders_dispatched = 9
        local spiders_dispatched = 0
        for spiderbot_id, spiderbot_data in random_pairs(spiderbots) do
            local spiderbot = spiderbot_data.spiderbot
            if not (spiderbot and spiderbot.valid) then
                storage.spiderbots[player_index][spiderbot_id] = nil
                goto next_spiderbot
            end
            local status = spiderbot_data.status
            local no_speed = (spiderbot.speed == 0)
            local distance_to_player = get_distance(spiderbot.position, player_entity.position)
            local exceeds_range = distance_to_player > max_task_range
            local greatly_exceeds_range = distance_to_player > double_max_task_range
            -- if the spider is stuck, try to free it
            if (spiders_dispatched < max_spiders_dispatched) then
                -- if the spider is assigned a task but has no speed, abandon the task so a new spider can be dispatched
                if (status ~= "idle") and no_speed then
                    reset_task_data(spiderbot_id, player_index)
                    perform_directional_jump(spiderbot, player)
                    spiders_dispatched = spiders_dispatched + 1
                    goto next_spiderbot
                end
                if (status == "idle") and (spiders_dispatched < 2) then
                    -- if the spider is idle and far away from the player, or is moving but is very far, move it closer
                    if ((no_speed and exceeds_range) or greatly_exceeds_range) then
                        local position_in_radius = get_random_position_in_radius(player_entity.position, 50)
                        local non_colliding_position = player.surface.find_non_colliding_position("spiderbot-leg-1", position_in_radius, 100, 0.5)
                        if non_colliding_position then
                            create_spiderbot_projectile(spiderbot.position, non_colliding_position, player, 5)
                            spiderbot.destroy({ raise_destroy = true })
                            spiders_dispatched = spiders_dispatched + 1
                            goto next_spiderbot
                        end
                    else
                        -- abandon_task(spiderbot_id, player_index)
                        -- spiders_dispatched = spiders_dispatched + 1
                        -- goto next_spiderbot
                    end
                end
            end
            -- if spiderbots are disabled for the player, go to the next spiderbot
            if not storage.spiderbots_enabled[player_index] then
                return_spiderbot_to_inventory(spiderbot, player)
                goto next_spiderbot
            end
            -- if the spiderbot is not idle, go to the next spiderbot
            if not (status == "idle") then goto next_spiderbot end
            -- if the max number of spiders have been dispatched, go to the next player
            if spiders_dispatched > max_spiders_dispatched then goto next_player end
            decon_entities = decon_entities or surface.find_entities_filtered {
                area = area,
                force = player_force,
                to_be_deconstructed = true,
            }
            -- process the deconstruction tasks and assign available spiderbots to them
            while (#decon_entities > 0 and spiders_dispatched < max_spiders_dispatched) do
                local entity = table.remove(decon_entities, math.random(1, #decon_entities)) --[[@type LuaEntity]]
                if not (entity and entity.valid) then goto next_entity end
                if entity.type == "fish" then goto next_entity end
                local entity_id = get_entity_uuid(entity)
                if is_task_assigned(entity_id) then goto next_entity end
                local mining_result = get_result_when_mined(entity)
                local inventory_contents = get_inventory_contents(entity)
                local inventory_has_space_for_all_contents = mining_result and inventory_has_space(inventory, mining_result)
                for item_name, item_count in pairs(inventory_contents) do
                    local item_stack = { name = item_name, count = item_count }
                    if not inventory_has_space(inventory, item_stack) then
                        inventory_has_space_for_all_contents = false
                        break
                    end
                end
                if inventory_has_space_for_all_contents then
                    local distance_to_task = get_distance(entity.position, spiderbot.position)
                    if distance_to_task < double_max_task_range then
                        spiderbot_data.task = {
                            task_type = "deconstruct_entity",
                            entity_id = entity_id,
                            entity = entity,
                        }
                        spiderbot_data.status = "path_requested"
                        spiderbot_data.path_request_id = request_path(spiderbot, entity)
                        spiders_dispatched = spiders_dispatched + 1
                        decon_ordered = true
                        goto next_spiderbot
                    else
                        goto next_spiderbot
                    end
                elseif (entity.type == "cliff") and inventory_has_cliff_explosives(inventory) then
                    local distance_to_task = get_distance(entity.position, spiderbot.position)
                    if distance_to_task < double_max_task_range then
                        spiderbot_data.task = {
                            task_type = "deconstruct_entity",
                            entity_id = entity_id,
                            entity = entity,
                        }
                        spiderbot_data.status = "path_requested"
                        spiderbot_data.path_request_id = request_path(spiderbot, entity)
                        spiders_dispatched = spiders_dispatched + 1
                        decon_ordered = true
                        goto next_spiderbot
                    else
                        goto next_spiderbot
                    end
                else -- if player has no space for the result or no cliff explosives, remove all entities of the same name from the table
                    for index, found_entity in pairs(decon_entities) do
                        if found_entity.name == entity.name then
                            table.remove(decon_entities, index)
                        end
                    end
                end
                ::next_entity::
            end
            if decon_ordered then goto next_spiderbot end
            revive_entities = revive_entities or surface.find_entities_filtered {
                area = area,
                force = player_force,
                type = "entity-ghost",
            }
            -- process the revive tasks and assign available spiderbots to them
            while (#revive_entities > 0 and spiders_dispatched < max_spiders_dispatched) do
                local entity = table.remove(revive_entities, math.random(1, #revive_entities)) --[[@type LuaEntity]]
                if not (entity and entity.valid) then goto next_entity end
                local entity_id = get_entity_uuid(entity)
                if is_task_assigned(entity_id) then goto next_entity end
                local items = entity.ghost_prototype.items_to_place_this
                local item_stack = items and items[1]
                if item_stack then
                    local item_with_quality = { name = item_stack.name, quality = entity.quality }
                    if inventory_has_item(inventory, item_with_quality) then
                        local distance_to_task = get_distance(entity.position, spiderbot.position)
                        if distance_to_task < double_max_task_range then
                            spiderbot_data.task = {
                                task_type = "build_ghost",
                                entity_id = entity_id,
                                entity = entity,
                            }
                            spiderbot_data.status = "path_requested"
                            spiderbot_data.path_request_id = request_path(spiderbot, entity)
                            spiders_dispatched = spiders_dispatched + 1
                            revive_ordered = true
                            goto next_spiderbot
                        else
                            goto next_spiderbot
                        end
                    else
                        for index, found_entity in pairs(revive_entities) do
                            if found_entity.name == entity.name then
                                table.remove(revive_entities, index)
                            end
                        end
                    end
                else for index, found_entity in pairs(revive_entities) do
                        if found_entity.name == entity.name then
                            table.remove(revive_entities, index)
                        end
                    end
                end
                ::next_entity::
            end
            if revive_ordered then goto next_spiderbot end
            upgrade_entities = upgrade_entities or surface.find_entities_filtered {
                area = area,
                force = player_force,
                to_be_upgraded = true,
            }
            -- process the upgrade tasks and assign available spiderbots to them
            while (#upgrade_entities > 0 and spiders_dispatched < max_spiders_dispatched) do
                local entity = table.remove(upgrade_entities, math.random(1, #upgrade_entities)) --[[@type LuaEntity]]
                if not (entity and entity.valid) then goto next_entity end
                local entity_id = get_entity_uuid(entity)
                if is_task_assigned(entity_id) then goto next_entity end
                local upgrade_target, quality_prototype = entity.get_upgrade_target()
                local items = upgrade_target and upgrade_target.items_to_place_this
                local item_stack = items and items[1]
                if upgrade_target and item_stack then
                    local item_with_quality = { name = item_stack.name, quality = quality_prototype }
                    if inventory_has_item(inventory, item_with_quality) then
                        local distance_to_task = get_distance(entity.position, spiderbot.position)
                        if distance_to_task < double_max_task_range then
                            spiderbot_data.task = {
                                task_type = "upgrade_entity",
                                entity_id = entity_id,
                                entity = entity,
                            }
                            spiderbot_data.status = "path_requested"
                            spiderbot_data.path_request_id = request_path(spiderbot, entity)
                            spiders_dispatched = spiders_dispatched + 1
                            upgrade_ordered = true
                            goto next_spiderbot
                        else
                            goto next_spiderbot
                        end
                    else
                        for index, found_entity in pairs(upgrade_entities) do
                            if found_entity.name == entity.name then
                                table.remove(upgrade_entities, index)
                            end
                        end
                    end
                end
                ::next_entity::
            end
            if upgrade_ordered then goto next_spiderbot end
            item_proxy_entities = item_proxy_entities or surface.find_entities_filtered {
                area = area,
                force = player_force,
                type = "item-request-proxy",
            }
            -- process the item proxy tasks and assign available spiderbots to them
            while (#item_proxy_entities > 0 and spiders_dispatched < max_spiders_dispatched) do
                local entity = table.remove(item_proxy_entities, math.random(1, #item_proxy_entities)) --[[@type LuaEntity]]
                if not (entity and entity.valid) then goto next_entity end
                local entity_id = get_entity_uuid(entity)
                if is_task_assigned(entity_id) then goto next_entity end
                local proxy_target = entity.proxy_target
                if proxy_target then
                    local insert_plan = entity.insert_plan
                    local removal_plan = entity.removal_plan
                    local plan_type = (removal_plan[1] and "remove") or (insert_plan[1] and "insert") or nil
                    local plans = removal_plan[1] and removal_plan or insert_plan[1] and insert_plan or nil
                    if not plans then goto next_entity end
                    for index, plan in pairs(plans) do
                        local item_quality_pair = (plan and plan.id) or nil
                        local has_item_or_space = plan_type == "insert" and inventory_has_item(inventory, item_quality_pair) or plan_type == "remove" and inventory_has_space(inventory, item_quality_pair) or nil
                        if has_item_or_space then
                            local distance_to_task = get_distance(entity.position, spiderbot.position)
                            if distance_to_task < double_max_task_range then
                                spiderbot_data.task = {
                                    task_type = "insert_items",
                                    entity_id = entity_id,
                                    entity = entity,
                                }
                                spiderbot_data.status = "path_requested"
                                spiderbot_data.path_request_id = request_path(spiderbot, entity)
                                spiders_dispatched = spiders_dispatched + 1
                                item_proxy_ordered = true
                                goto next_spiderbot
                            else
                                goto next_spiderbot
                            end
                        end
                    end
                end
                ::next_entity::
            end
            if item_proxy_ordered then goto next_spiderbot end
            ::next_spiderbot::
        end
        ::next_player::
    end
end

script.on_nth_tick(15, on_tick)

-- toggle the spiderbots on/off for the player
---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_spiderbots(event)
    local name = event.prototype_name or event.input_name
    if name ~= "toggle-spiderbots" then return end
    local player_index = event.player_index
    storage.spiderbots_enabled = storage.spiderbots_enabled or {}
    storage.spiderbots_enabled[player_index] = not storage.spiderbots_enabled[player_index]
    if storage.spiderbots_enabled[player_index] then
        local player = game.get_player(player_index)
        if player and player.valid then
            local entity = get_player_entity(player)
            if entity and entity.valid then
                local inventory = get_entity_inventory(entity)
                local count = inventory and inventory.get_item_count("spiderbot") or 0
                local position = entity.position
                if inventory and (count > 0) then
                    local max_followers = storage.spiderbot_follower_count[player.force.name] or 10
                    for i = 1, math.min(count, max_followers) do
                        local destination = get_random_position_in_radius(position, 25)
                        destination = entity.surface.find_non_colliding_position("spiderbot-leg-1", destination, 100, 0.5) or destination
                        create_spiderbot_projectile(position, destination, player)
                        inventory.remove({ name = "spiderbot", count = 1 })
                    end
                end
            end
        end
    end
    game.get_player(player_index).set_shortcut_toggled("toggle-spiderbots", storage.spiderbots_enabled[player_index])
end

script.on_event("toggle-spiderbots", toggle_spiderbots)
script.on_event(defines.events.on_lua_shortcut, toggle_spiderbots)

---@param event EventData.on_research_finished
local function on_research_finished(event)
    local research = event.research
    local name = research.name
    if string.find(name, "spiderbot-follower-count", 1, true) then
        local level = tonumber(string.match(name, "%d+$"))
        local force = research.force.name
        storage.spiderbot_follower_count = storage.spiderbot_follower_count or {}
        storage.spiderbot_follower_count[force] = level * 10 + 10
    end
end

script.on_event(defines.events.on_research_finished, on_research_finished)

local function setup_storage()
    -- spiderbot data
    --[[@type table<player_index, table<uuid, spiderbot_data>>]]
    storage.spiderbots = storage.spiderbots or {}
    --[[@type table<player_index, boolean>]]
    storage.spiderbots_enabled = storage.spiderbots_enabled or {}
    --[[@type table<string, integer>]]
    storage.spiderbot_follower_count = storage.spiderbot_follower_count or {}

    -- player data
    --[[@type table<player_index, defines.controllers>]]
    storage.previous_controller = storage.previous_controller or {}
    --[[@type table<player_index, uuid>]]
    storage.previous_player_entity = storage.previous_player_entity or {}
    --[[@type table<player_index, Color>]]
    storage.previous_player_color = storage.previous_player_color or {}

    -- misc data
    storage.spider_leg_collision_mask = prototypes.entity["spiderbot-leg-1"].collision_mask
    --[[@type table<player_index, LuaRenderObject[]>]]
    storage.render_objects = storage.render_objects or {}
end

local function reset_follower_count()
    for _, force in pairs(game.forces) do
        storage.spiderbot_follower_count = storage.spiderbot_follower_count or {}
        storage.spiderbot_follower_count[force.name] = 10
        for _, technology in pairs(force.technologies) do
            if string.find(technology.name, "spiderbot-follower-count", 1, true) then
                if technology.researched then
                    local level = tonumber(string.match(technology.name, "%d+$"))
                    local count = level * 10 + 10
                    local previous_count = storage.spiderbot_follower_count[force.name] or 0
                    if count > previous_count then
                        storage.spiderbot_follower_count[force.name] = count
                    end
                end
            end
        end
    end
end

script.on_event(defines.events.on_technology_effects_reset, reset_follower_count)

local function on_init()
    setup_storage()
    reset_follower_count()
end

script.on_init(on_init)

local function on_configuration_changed(event)
    setup_storage()
    reset_follower_count()
    for _, player in pairs(game.players) do
        relink_following_spiderbots(player)
    end
end

script.on_configuration_changed(on_configuration_changed)
