
--[[ factorio mod little spiders control script created by asher_sky --]]

local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid
local tile_uuid = general_util.tile_uuid
local new_task_id = general_util.new_task_id

local color_util = require("util/colors")
local color = color_util.color

local rendering_util = require("util/rendering")
local draw_line = rendering_util.draw_line
local draw_dotted_line = rendering_util.draw_dotted_line
local draw_circle = rendering_util.draw_circle
local debug_print = rendering_util.debug_print
local destroy_associated_renderings = rendering_util.destroy_associated_renderings

local math_util = require("util/math")
local maximum_length = math_util.maximum_length
local minimum_length = math_util.minimum_length
local rotate_around_target = math_util.rotate_around_target
local random_position_on_circumference = math_util.random_position_on_circumference
local distance = math_util.distance

local path_request_util = require("util/path_request")
local request_spider_path_to_entity = path_request_util.request_spider_path_to_entity
local request_spider_path_to_position = path_request_util.request_spider_path_to_position

local constants = require("util/constants")
local double_max_task_range = constants.double_max_task_range
local half_max_task_range = constants.half_max_task_range
local max_task_range = constants.max_task_range

local function toggle_debug()
  global.debug = not global.debug
  for _, player in pairs(game.connected_players) do
    local messaage = global.debug and { "messages.debug-mode-enabled" } or { "messages.debug-mode-disabled" }
    player.print(messaage)
  end
end

local function add_commands()
  commands.add_command("little-spider-debug", "- toggles debug mode for the little spiders, showing task targets and path request renderings", toggle_debug)
end

local function on_init()
  global.spiders = {} --[[@type table<integer, table<uuid, LuaEntity>>]]
  global.available_spiders = {} --[[@type table<integer, table<integer, LuaEntity[]>>]]
  global.tasks = {
    by_entity = {}, --[[@type table<uuid, entity_task_data>]]
    by_spider = {}, --[[@type table<uuid, entity_task_data>]]
    by_tile = {}, --[[@type table<uuid, entity_task_data>]]
    nudges = {}, --[[@type table<uuid, entity_task_data>]]
  }
  global.spider_path_requests = {} --[[@type table<integer, path_request_data>]]
  global.spider_path_to_position_requests = {} --[[@type table<integer, position_path_request_data>]]
  global.spider_leg_collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask
  global.previous_controller = {} --[[@type table<integer, defines.controllers>]]
  global.previous_player_entity = {} --[[@type table<integer, uuid>]]
  global.previous_player_color = {} --[[@type table<integer, Color>]]
  global.path_requested = {} --[[@type table<uuid, boolean>]]
  global.spiders_enabled = {} --[[@type table<integer, boolean>]]
  global.visualization_render_ids = {} --[[@type table<integer, table<integer, integer>>]]
  add_commands()
end

local function on_configuration_changed(event)
  global.spiders = global.spiders or {}
  global.available_spiders = global.available_spiders or {}
  global.tasks = global.tasks or {}
  global.tasks.by_entity = global.tasks.by_entity or {}
  global.tasks.by_spider = global.tasks.by_spider or {}
  global.tasks.by_tile = global.tasks.by_tile or {}
  global.tasks.nudges = global.tasks.nudges or {}
  global.spider_path_requests = global.spider_path_requests or {}
  global.spider_path_to_position_requests = global.spider_path_to_position_requests or {}
  global.spider_leg_collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask
  global.previous_controller = global.previous_controller or {}
  global.previous_player_entity = global.previous_player_entity or {}
  global.previous_player_color = global.previous_player_color or {}
  global.path_requested = global.path_requested or {}
  global.spiders_enabled = global.spiders_enabled or {}
  global.visualization_render_ids = global.visualization_render_ids or {}
end

script.on_init(on_init)
script.on_load(add_commands)
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

---@param event EventData.on_built_entity
local function on_spider_created(event)
  local spider = event.created_entity
  local player_index = event.player_index
  local surface_index = spider.surface_index
  local player = game.get_player(player_index)

  if player then
    local player_entity = get_player_entity(player)
    if player_entity then
      spider.color = player.color
      spider.follow_target = player_entity
      local uuid = entity_uuid(spider)
      global.spiders[player_index] = global.spiders[player_index] or {}
      global.spiders[player_index][uuid] = spider
      global.available_spiders[player_index] = global.available_spiders[player_index] or {}
      global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
      table.insert(global.available_spiders[player_index][surface_index], spider)
    end
  end

  local entity_label = spider.entity_label
  if (not entity_label) or (is_backer_name(entity_label)) then
    spider.entity_label = random_backer_name()
  end
end

local filter = { { filter = "name", name = "little-spidertron" } }
script.on_event(defines.events.on_built_entity, on_spider_created, filter)

---@param event EventData.on_entity_destroyed
local function on_spider_destroyed(event)
  local unit_number = event.unit_number
  if not unit_number then return end
  for player_index, spiders in pairs(global.spiders) do
    if spiders[unit_number] then
      spiders[unit_number] = nil
      break
    end
  end
  for player_index, spider_data in pairs(global.available_spiders) do
    for surface_index, spiders in pairs(spider_data) do
      for i, spider in pairs(spiders) do
        if not spider.valid then
          table.remove(spiders, i)
        end
      end
    end
  end
  destroy_associated_renderings(unit_number)
  local spider_task = global.tasks.by_spider[unit_number]
  if spider_task then
    local entity_id = spider_task.entity_id
    global.tasks.by_entity[entity_id] = nil
    global.tasks.by_spider[unit_number] = nil
  end
  global.tasks.nudges[unit_number] = nil
  global.spider_path_requests[unit_number] = nil
  global.spider_path_to_position_requests[unit_number] = nil
  global.path_requested[unit_number] = nil
end

script.on_event(defines.events.on_entity_destroyed, on_spider_destroyed)

---@param event EventData.on_pre_player_mined_item
local function on_player_mined_entity(event)
  local player = game.get_player(event.player_index)
  local entity = event.entity
  if is_backer_name(entity.entity_label) then
    entity.entity_label = ""
  end
  entity.color = player and player.color or entity.color
end

script.on_event(defines.events.on_pre_player_mined_item, on_player_mined_entity, filter)

-- ---@param spider_id uuid
-- ---@param entity_id uuid
-- ---@param spider LuaEntity
-- ---@param player LuaPlayer
-- ---@param player_entity LuaEntity?
-- local function abandon_task(spider_id, entity_id, spider, player, player_entity)
--   destroy_associated_renderings(spider_id)
--   local entity_path_request_id = global.tasks.by_entity[entity_id].path_request_id
--   local spider_path_request_id = global.tasks.by_spider[spider_id].path_request_id
--   if entity_path_request_id then
--     global.spider_path_requests[entity_path_request_id] = nil
--     global.spider_path_to_position_requests[entity_path_request_id] = nil
--   end
--   if spider_path_request_id then
--     global.spider_path_requests[spider_path_request_id] = nil
--     global.spider_path_to_position_requests[spider_path_request_id] = nil
--   end
--   global.path_requested[spider_id] = nil
--   global.tasks.by_entity[entity_id] = nil
--   global.tasks.by_spider[spider_id] = nil
--   local player_index = player.index
--   local surface_index = spider.surface_index
--   global.available_spiders[player_index] = global.available_spiders[player_index] or {}
--   global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
--   table.insert(global.available_spiders[player_index][surface_index], spider)
--   spider.color = player.color
--   spider.autopilot_destination = nil
--   if player.surface_index == spider.surface_index then
--     if player_entity and player_entity.valid then
--       spider.follow_target = player_entity
--     else
--       spider.follow_target = nil
--     end
--   end
-- end

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

---@param player LuaPlayer
local function relink_following_spiders(player)
  local player_index = player.index
  local spiders = global.spiders[player_index]
  if not spiders then return end
  local player_entity = get_player_entity(player)
  for index, spider in pairs(spiders) do
    if spider.valid then
      if spider.surface_index == player.surface_index then
        local spider_id = entity_uuid(spider)
        local task_data = global.tasks.by_spider[spider_id]
        if task_data then
          local entity_id = task_data.entity_id
          local entity = task_data.entity
          if not (entity and entity.valid) then
            abandon_task(spider, player, spider_id, entity_id, player_entity)
          --   global.tasks.by_entity[entity_id] = nil
          --   global.tasks.by_spider[spider_id] = nil
          --   -- table.insert(global.available_spiders[player_index][spider.surface_index], spider)
          end
        end
        local destinations = spider.autopilot_destinations
        if player_entity then
          spider.color = player.color
          spider.follow_target = player_entity
        else
          spider.color = color.white
          spider.follow_target = nil
        end
        local was_nudged = global.tasks.nudges[spider_id]
        -- re-add destinations to autopilot since they were cleared when updating the follow_target, unless the destinations were part of a "nudge" task (ok to abandon)
        if destinations and not was_nudged then
          for _, destination in pairs(destinations) do
            spider.add_autopilot_destination(destination)
          end
        end
      end
    else
      spiders[index] = nil
    end
  end
end

---@param event EventData.on_player_changed_surface
local function on_player_changed_surface(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  relink_following_spiders(player)
end

script.on_event(defines.events.on_player_changed_surface, on_player_changed_surface)

---@param event EventData.on_player_driving_changed_state
local function on_player_driving_changed_state(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  relink_following_spiders(player)
end

script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)

---@param spidertron LuaEntity
---@param spider_id string|integer
---@param player LuaPlayer
local function nudge_spidertron(spidertron, spider_id, player)
  local autopilot_destinations = spidertron.autopilot_destinations
  local destination_count = #autopilot_destinations
  local current_position = spidertron.position
  local surface = spidertron.surface
  local nearby_position = random_position_on_circumference(current_position, 20)
  -- local new_position = surface.find_tiles_filtered({
  --   position = nearby_position,
  --   radius = 10,
  --   collision_mask = { "water-tile" },
  --   invert = true,
  --   limit = 1,
  -- })
  -- new_position = new_position and new_position[1] and new_position[1].position --[[@as MapPosition]] or nil
  local new_position = surface.find_non_colliding_position("little-spidertron-leg-1", nearby_position, 10, 0.5)
  new_position = new_position or nearby_position
  if destination_count >= 1 then
    if not global.path_requested[spider_id] then
      local final_destination = autopilot_destinations[destination_count]
      if destination_count > 1 then
        autopilot_destinations[1] = new_position
      else
        table.insert(autopilot_destinations, 1, new_position)
      end
      spidertron.autopilot_destination = nil
      -- spidertron.follow_target = get_player_entity(player)
      for _, destination in pairs(autopilot_destinations) do
        spidertron.add_autopilot_destination(destination)
      end
      request_spider_path_to_position(surface, spider_id, spidertron, new_position, final_destination, player)
    end
  else
    if not global.path_requested[spider_id] then
      spidertron.add_autopilot_destination(new_position)
      request_spider_path_to_position(surface, spider_id, spidertron, new_position, player.position, player)
    end
  end
end

---@param event EventData.on_spider_command_completed
local function on_spider_command_completed(event)
  local spider = event.vehicle
  if not (spider.name == "little-spidertron") then return end
  local destinations = spider.autopilot_destinations
  local destination_count = #destinations
  local spider_id = entity_uuid(spider)
  if destination_count == 0 then
    local task_data = global.tasks.nudges[spider_id]
    if task_data then
      local player = task_data.player
      if player and player.valid and player.connected then
        if player.surface_index == spider.surface_index then
          local player_entity = get_player_entity(player)
          spider.color = player.color
          spider.follow_target = player_entity
          global.tasks.nudges[spider_id] = nil
          debug_print("nudge completed", player, spider, color.green)
        else
          global.tasks.nudges[spider_id] = nil
          debug_print("nudge abandoned: player not on same surface", player, spider, color.red)
        end
      else
        global.tasks.nudges[spider_id] = nil
        debug_print("nudge abandoned: no valid player", player, spider, color.red)
      end
    else
      task_data = global.tasks.by_spider[spider_id]
      if task_data then
        local entity = task_data.entity
        local entity_id = task_data.entity_id
        local player = task_data.player
        local task_type = task_data.task_type

        if not global.spiders_enabled[player.index] then
          abandon_task(spider, player, spider_id, entity_id)
          debug_print("task abandoned: player disabled little spiders", player, spider, color.red)
          return
        end

        if not player.valid then
          abandon_task(spider, player, spider_id, entity_id)
          debug_print("task abandoned: no valid player", player, spider, color.red)
          return
        end

        local player_entity = get_player_entity(player)

        if not (entity and entity.valid) then
          abandon_task(spider, player, spider_id, entity_id, player_entity)
          debug_print("task abandoned: no valid entity", player, spider, color.red)
          return
        end

        if not (player_entity and player_entity.valid) then
          abandon_task(spider, player, spider_id, entity_id, player_entity)
          debug_print("task abandoned: no valid player entity", player, spider, color.red)
          return
        end

        local inventory = player_entity.get_inventory(defines.inventory.character_main)

        if not (inventory and inventory.valid) then
          abandon_task(spider, player, spider_id, entity_id, player_entity)
          debug_print("task abandoned: no valid inventory", player, spider, color.red)
          return
        end

        local retry_task = false
        local length = 5

        if task_type == "deconstruct" then
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
                else break
                end
                if count > 4 then break end
              end
              draw_line(spider.surface, player_entity, spider, player.color, 20)
              global.tasks.by_entity[entity_id].status = "completed"
              global.tasks.by_spider[spider_id].status = "completed"
              complete_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("deconstruct task completed", player, spider, color.green)
            elseif (entity.type == "cliff") then
              if inventory and inventory.get_item_count("cliff-explosives") > 0 then
                ---@diagnostic disable:missing-fields
                spider.surface.create_entity {
                  name = "cliff-explosives",
                  position = spider.position,
                  target = entity_position,
                  force = player.force,
                  raise_built = true,
                  speed = 0.125,
                }
                ---@diagnostic enable:missing-fields
                inventory.remove({ name = "cliff-explosives", count = 1 })
                draw_line(spider.surface, player_entity, spider, player.color, 20)
                global.tasks.by_entity[entity_id].status = "completed"
                global.tasks.by_spider[spider_id].status = "completed"
                complete_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("deconstruct task completed", player, spider, color.green)
              else
                abandon_task(spider, player, spider_id, entity_id, player_entity)
                debug_print("task abandoned: no cliff explosives", player, spider, color.red)
              end
            else
              abandon_task(spider, player, spider_id, entity_id, player_entity)
              debug_print("task abandoned: no space in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider, player, spider_id, entity_id, player_entity)
            debug_print("task abandoned: entity no longer needs to be deconstructed", player, spider, color.red)
          end

        elseif task_type == "revive" then
          local items = entity.ghost_prototype.items_to_place_this
          local item_stack = items and items[1]
          if item_stack then
            local item_name = item_stack.name
            local item_count = item_stack.count or 1
            if inventory.get_item_count(item_name) >= item_count then
              local dictionary, revived_entity = entity.revive({ return_item_request_proxy = false, raise_revive = true})
              if revived_entity then
                inventory.remove(item_stack)
                draw_line(spider.surface, player_entity, spider, player.color, 20)
                global.tasks.by_entity[entity_id].status = "completed"
                global.tasks.by_spider[spider_id].status = "completed"
                complete_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("revive task completed", player, spider, color.green)
              else
                local ghost_position = entity.position
                local spider_position = spider.position
                local distance_to_player = distance(ghost_position, player.position)
                if distance_to_player > double_max_task_range then
                  abandon_task(spider, player, spider_id, entity_id, player_entity)
                  debug_print("task abandoned: player too far from ghost", player, spider, color.red)
                else
                  for i = 1, 90, 10 do
                    local rotatated_position = rotate_around_target(ghost_position, spider_position, i, length)
                    spider.add_autopilot_destination(rotatated_position)
                  end
                  retry_task = true
                  debug_print("revive task failed: retrying", player, spider, color.red)
                end
              end
            else
              abandon_task(spider, player, spider_id, entity_id, player_entity)
              debug_print("task abandoned: not enough items in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider, player, spider_id, entity_id, player_entity)
            debug_print("task abandoned: no items_to_place_this", player, spider, color.red)
          end

        elseif task_type == "upgrade" then
          if entity.to_be_upgraded() then
            local upgrade_target = entity.get_upgrade_target()
            local items = upgrade_target and upgrade_target.items_to_place_this
            local item_stack = items and items[1]
            if upgrade_target and item_stack then
              local item_name = item_stack.name
              local item_count = item_stack.count or 1
              if inventory.get_item_count(item_name) >= item_count then
                -- local current_direction = entity.direction
                local upgrade_direction = entity.get_upgrade_direction()
                -- local current_name = entity.name
                local upgrade_name = upgrade_target.name
                local type = entity.type
                local is_ug_belt = (type == "underground-belt")
                local is_loader = (type == "loader" or type == "loader-1x1")
                local underground_type = is_ug_belt and entity.belt_to_ground_type
                local loader_type = is_loader and entity.loader_type
                -- local opposite_types = { ["input"] = "output", ["output"] = "input" }
                -- if loader_type and (current_direction == upgrade_direction) and (current_name == upgrade_name) then
                --   loader_type = opposite_types[loader_type] or loader_type
                -- end
                local create_entity_type = underground_type or loader_type or nil
                ---@diagnostic disable:missing-fields
                local upgraded_entity = entity.surface.create_entity {
                  name = upgrade_name,
                  position = entity.position,
                  direction = upgrade_direction,
                  player = player,
                  fast_replace = true,
                  force = entity.force,
                  spill = true,
                  type = create_entity_type,
                  raise_built = true,
                }
                ---@diagnostic enable:missing-fields
                if upgraded_entity then
                  inventory.remove(item_stack)
                  draw_line(spider.surface, player_entity, spider, player.color, 20)
                  global.tasks.by_entity[entity_id].status = "completed"
                  global.tasks.by_spider[spider_id].status = "completed"
                  complete_task(spider_id, entity_id, spider, player, player_entity)
                  debug_print("upgrade task completed", player, spider, color.green)
                else
                  local upgrade_position = entity.position
                  local spider_position = spider.position
                  for i = 1, 90, 10 do
                    local rotatated_position = rotate_around_target(upgrade_position, spider_position, i, length)
                    spider.add_autopilot_destination(rotatated_position)
                  end
                  retry_task = true
                  debug_print("upgrade task failed: retrying", player, spider, color.red)
                end
              else
                abandon_task(spider, player, spider_id, entity_id, player_entity)
                debug_print("task abandoned: not enough items in inventory", player, spider, color.red)
              end
            else
              abandon_task(spider, player, spider_id, entity_id, player_entity)
              debug_print("task abandoned: no upgrade_target or item_stack", player, spider, color.red)
            end
          else
            abandon_task(spider, player, spider_id, entity_id, player_entity)
            debug_print("task abandoned: entity no longer needs to be upgraded", player, spider, color.red)
          end
        elseif task_type == "item_proxy" then
          local proxy_target = entity.proxy_target
          if proxy_target then
            local items = entity.item_requests
            local item_name, item_count = next(items)
            if inventory.get_item_count(item_name) >= item_count then
              local item_to_insert = { name = item_name, count = item_count }
              local request_fulfilled = false
              if proxy_target.can_insert(item_to_insert) then
                proxy_target.insert(item_to_insert)
                inventory.remove(item_to_insert)
                items[item_name] = nil
                entity.item_requests = items
                if not next(items) then
                  entity.destroy()
                end
                request_fulfilled = true
              end
              if request_fulfilled then
                complete_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("item_proxy task completed", player, spider, color.green)
              else
                abandon_task(spider, player, spider_id, entity_id, player_entity)
                debug_print("proxy task abandoned: could not insert", player, spider, color.red)
              end
            else
              abandon_task(spider, player, spider_id, entity_id, player_entity)
              debug_print("proxy task abandoned: not enough items in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider, player, spider_id, entity_id, player_entity)
            debug_print("proxy task abandoned: no proxy_target", player, spider, color.red)
          end
        end
      end
    end
  else
    local chance = math.random()
    if chance < 0.0625 then -- 1/16
      local nudge_task_data = global.tasks.nudges[spider_id]
      local active_task_data = global.tasks.by_spider[spider_id]
      local task_data = active_task_data or nudge_task_data or nil
      if not task_data then
        return
      end
      local final_destination = destinations[destination_count]
      local player = task_data.player

      -- if the player isn't valid anymore, clear any tasks associated with it
      if not (player and player.valid) then
        local entity_id = active_task_data and active_task_data.entity_id
        -- if entity_id then
        --   global.tasks.by_entity[entity_id] = nil
        -- end
        -- global.tasks.nudges[spider_id] = nil
        -- global.tasks.by_spider[spider_id] = nil
        if entity_id then
          abandon_task(spider, player, spider_id, entity_id)
        end
        return
      end

      -- if the player doesn't have a valid character, clear any tasks and return it to the player's available spiders table for when they do have a character again
      local player_entity = get_player_entity(player)
      if not (player_entity and player_entity.valid) then
        abandon_task(spider, player)
        global.tasks.nudges[spider_id] = nil
        return
      end

      -- if the player is too far away from the spider's final destination, abandon the current task or repath to the final destination (player entity)
      local distance_to_player = distance(player_entity.position, final_destination)
      local path_requested = global.path_requested[spider_id]
      if (distance_to_player > double_max_task_range) and (not path_requested) then
        if active_task_data then
          abandon_task(spider, player)
        else
          request_spider_path_to_position(spider.surface, spider_id, spider, spider.position, player.position, player)
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
  if global.spider_path_requests[path_request_id] then
    local spider = global.spider_path_requests[path_request_id].spider
    local entity = global.spider_path_requests[path_request_id].entity
    local player = global.spider_path_requests[path_request_id].player
    local spider_id = global.spider_path_requests[path_request_id].spider_id
    local entity_id = global.spider_path_requests[path_request_id].entity_id
    local player_entity = get_player_entity(player)
    if (spider and spider.valid and entity and entity.valid and player_entity and player_entity.valid) then
      if not global.spiders_enabled[player.index] then
        abandon_task(spider, player, spider_id, entity_id, player_entity)
        return
      end
      if spider.surface_index == player.surface_index then
        local distance_to_task = distance(player.position, entity.position)
        if distance_to_task < max_task_range then
          -- Set the spider's follow target to the player's entity
          spider.follow_target = player_entity

          if path then
            -- If a path was found, clear the spider's autopilot destination and update its color based on the task type
            spider.autopilot_destination = nil
            local task_type = global.tasks.by_entity[entity_id].task_type
            local task_color = (task_type == "deconstruct" and color.red) or (task_type == "revive" and color.blue) or (task_type == "upgrade" and color.green) or color.white
            spider.color = task_color or color.black

            -- Add each waypoint in the path as an autopilot destination for the spider
            local previous_position = spider.position
            for _, waypoint in pairs(path) do
              local waypoint_position = waypoint.position
              spider.add_autopilot_destination(waypoint_position)
              if global.debug then
                local surface = spider.surface
                local circle_id = draw_circle(surface, waypoint.position, task_color, 0.25)
                if circle_id then
                  global.tasks.by_entity[entity_id].render_ids[circle_id] = true
                  global.tasks.by_spider[spider_id].render_ids[circle_id] = true
                end
                if previous_position then
                  local line_id = draw_line(surface, previous_position, waypoint_position, task_color)
                  if line_id then
                    global.tasks.by_entity[entity_id].render_ids[line_id] = true
                    global.tasks.by_spider[spider_id].render_ids[line_id] = true
                  end
                end
                previous_position = waypoint_position
              end
            end

            -- Update the task status and draw a line between the spider and the entity
            global.tasks.by_entity[entity_id].status = "on_the_way"
            global.tasks.by_spider[spider_id].status = "on_the_way"
            local render_id = draw_line(spider.surface, entity, spider, task_color)
            if render_id then
              global.tasks.by_entity[entity_id].render_ids[render_id] = true
              global.tasks.by_spider[spider_id].render_ids[render_id] = true
            end

          else
            -- If no path was found, abandon the task and add a random nearby destination for the spider autopilot
            abandon_task(spider, player, spider_id, entity_id, player_entity)
            -- if math.random() < 0.125 then
            --   spider.add_autopilot_destination(random_position_on_circumference(spider.position, 3))
            -- end

            -- Draw dotted lines between the spider and the entity to indicate failure to find a path
            local surface = spider.surface
            draw_dotted_line(surface, spider, entity, color.white, 30)
            draw_dotted_line(surface, spider, entity, color.red, 30, true)
          end
        else
          abandon_task(spider, player, spider_id, entity_id, player_entity)
        end
      else
        abandon_task(spider, player, spider_id, entity_id, player_entity)
      end
    else
      abandon_task(spider, player, spider_id, entity_id, player_entity)
    end
    global.spider_path_requests[path_request_id] = nil
    global.path_requested[spider_id] = nil
  elseif global.spider_path_to_position_requests[path_request_id] then
    local spider = global.spider_path_to_position_requests[path_request_id].spider
    local final_position = global.spider_path_to_position_requests[path_request_id].final_position
    local start_position = global.spider_path_to_position_requests[path_request_id].start_position
    local player = global.spider_path_to_position_requests[path_request_id].player
    local spider_id = global.spider_path_to_position_requests[path_request_id].spider_id
    local player_entity = get_player_entity(player)
    if (spider and spider.valid and player_entity and player_entity.valid) then
      if spider.surface_index == player.surface_index then
        -- Set the spider's follow target to the player's entity
        spider.follow_target = player_entity
        local surface = spider.surface

        if path then
          -- If a path was found, set the spider's autopilot destination to nil and draw lines between the spider and each waypoint in the path
          spider.autopilot_destination = nil
          local previous_position = spider.position
          local spider_color = spider.color or color.white
          for _, waypoint in pairs(path) do
            local new_position = waypoint.position
            spider.add_autopilot_destination(new_position)
            if global.debug then
              draw_circle(surface, new_position, spider_color, 0.25, 180)
              if previous_position then
                draw_line(surface, previous_position, new_position, spider_color, 180)
              end
              previous_position = new_position
            end
          end

          -- Add the task to the nudges table and update its status
          local render_id = draw_line(spider.surface, final_position, spider, spider_color, 10)
          global.tasks.nudges[spider_id] = {
            spider = spider,
            spider_id = spider_id,
            task_type = "nudge",
            player = player,
            entity = player_entity,
            entity_id = entity_uuid(player_entity),
            status = "on_the_way",
            render_ids = {},
          }
        else
          -- If no path was found, add a random autopilot destination for the spider and update the available spiders table
          -- if math.random() < 0.125 then
          --   spider.add_autopilot_destination(random_position_on_circumference(spider.position, 20))
          -- end
          -- local player_index = player.index
          -- local surface_index = player.surface_index
          -- global.available_spiders[player_index] = global.available_spiders[player_index] or {}
          -- global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
          -- table.insert(global.available_spiders[player_index][surface_index], spider)
          spider.color = player.color

          -- Draw dotted lines between the spider and the start and final positions to indicate failure to find a path
          draw_dotted_line(surface, spider, start_position, color.white, 30)
          draw_dotted_line(surface, spider, start_position, color.red, 30, true)
          draw_dotted_line(surface, start_position, final_position, color.white, 30)
          draw_dotted_line(surface, start_position, final_position, color.red, 30, true)
        end
      end
    end
    global.spider_path_to_position_requests[path_request_id] = nil
    global.path_requested[spider_id] = nil
  end
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param player_index integer
local function clear_visualization_renderings(player_index)
  local render_ids = global.visualization_render_ids[player_index]
  if render_ids then
    for _, render_id in pairs(render_ids) do
      rendering.destroy(render_id)
    end
    global.visualization_render_ids[player_index] = {}
  end
end

---@param event EventData.on_player_cursor_stack_changed
local function on_player_cursor_stack_changed(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  if not player.character then return end
  if not global.spiders_enabled[player_index] then
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
    local render_id = rendering.draw_sprite {
      sprite = "utility/construction_radius_visualization",
      surface = player.surface,
      target = player.character,
      x_scale = max_task_range * 3.2, -- i don't really understand why this is the magic number, but it's what got the sprite to be the correct size
      y_scale = max_task_range * 3.2,
      render_layer = "radius-visualization",
      players = { player },
      only_in_alt_mode = true,
      tint = { r = 0.45, g = 0.4, b = 0.4, a = 0.5}, -- by trial and error, this is the closest i could match the vanilla construction radius visualization look
    }
    -- local render_id = rendering.draw_rectangle {
    --   color = render_color,
    --   filled = true,
    --   left_top = player.character,
    --   left_top_offset = { -half_max_task_range, -half_max_task_range },
    --   right_bottom = player.character,
    --   right_bottom_offset = { half_max_task_range, half_max_task_range },
    --   surface = player.surface,
    --   time_to_live = nil,
    --   players = { player },
    --   draw_on_ground = true,
    -- }
    if render_id then
      global.visualization_render_ids[player_index] = global.visualization_render_ids[player_index] or {}
      table.insert(global.visualization_render_ids[player_index], render_id)
    end
  else
    clear_visualization_renderings(player_index)
  end
end

script.on_event(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)

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

---@param event EventData.on_tick
local function on_tick(event)
  for _, player in pairs(game.connected_players) do
    local player_index = player.index
    local surface_index = player.surface_index
    global.available_spiders[player_index] = global.available_spiders[player_index] or {}
    global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
    if #global.available_spiders[player_index][surface_index] == 0 then goto next_player end

    local controller_type = player.controller_type
    global.previous_controller[player_index] = global.previous_controller[player_index] or controller_type
    if global.previous_controller[player_index] ~= controller_type then
      relink_following_spiders(player)
      global.previous_controller[player_index] = controller_type
      return
    end

    local player_entity = get_player_entity(player)

    if not (player_entity and player_entity.valid) then goto next_player end

    local player_entity_id = entity_uuid(player_entity)
    global.previous_player_entity[player_index] = global.previous_player_entity[player_index] or player_entity_id
    if global.previous_player_entity[player_index] ~= player_entity_id then
      relink_following_spiders(player)
      global.previous_player_entity[player_index] = player_entity_id
      return
    end

    global.previous_player_color[player_index] = global.previous_player_color[player_index] or player.color
    local current = player.color
    local previous = global.previous_player_color[player_index]
    if (previous.r ~= current.r) or (previous.g ~= current.g) or (previous.b ~= current.b) or (previous.a ~= current.a) then
      local available_spiders = global.available_spiders[player_index]
      local spiders = available_spiders and available_spiders[surface_index]
      if spiders then
        for spider_id, spider in pairs(spiders) do
          if spider.valid then
            spider.color = current
          else
            spiders[spider_id] = nil
          end
        end
      end
      global.previous_player_color[player_index] = current
    end

    local counter = 0
    for spider_id, spider in pairs(global.spiders[player_index]) do
      if spider.valid then
        local no_speed = spider.speed == 0
        local distance_to_player = distance(spider.position, player.position)
        local exceeds_distance_limit = distance_to_player > double_max_task_range
        local active_task = global.tasks.by_spider[spider_id]
        if (counter < 5) and no_speed then
          if not global.path_requested[spider_id] then
            if exceeds_distance_limit then
              if active_task then
                abandon_task(spider, player, spider_id, active_task.entity_id, player_entity)
              else
                nudge_spidertron(spider, spider_id, player)
              end
              counter = counter + 1
            else
              -- if not active_task then
              --   local chance = math.random()
              --   if chance < 0.0125 then
              --     nudge_spidertron(spider, spider_id, player)
              --     counter = counter + 1
              --   end
              -- end
            end
          end
        end
      else
        global.spiders[player_index][spider_id] = nil
      end
    end

    if not global.spiders_enabled[player_index] then goto next_player end

    local inventory = player.get_main_inventory()
    if not (inventory and inventory.valid) then goto next_player end

    local player_force = { player.force.name, "neutral" }
    local surface = player_entity.surface
    local character_position_x = player_entity.position.x
    local character_position_y = player_entity.position.y
    local area = {
      { character_position_x - half_max_task_range, character_position_y - half_max_task_range },
      { character_position_x + half_max_task_range, character_position_y + half_max_task_range },
    }
    local decon_entities = nil
    local revive_entities = nil
    local upgrade_entities = nil
    local item_proxy_entities = nil
    local decon_tiles = nil
    local revive_tiles = nil
    local decon_ordered = false
    local revive_ordered = false
    local upgrade_ordered = false
    local item_proxy_ordered = false
    local tile_decon_ordered = false
    local tile_reivive_ordered = false
    local spiders_dispatched = 0
    local max_spiders_dispatched = 9
    -- local max_distance_to_task = 100

    for spider_index, spider in pairs(global.available_spiders[player_index][surface_index]) do
      if not (spider and spider.valid) then
        table.remove(global.available_spiders[player_index][surface_index], spider_index)
        goto next_spider
      end

      decon_entities = decon_entities or surface.find_entities_filtered({
        area = area,
        to_be_deconstructed = true,
        force = player_force,
      })
      local decon_entity_count = #decon_entities
      for i = 1, decon_entity_count do
        local entity_index = math.random(1, decon_entity_count)
        local decon_entity = decon_entities[entity_index] ---@type LuaEntity
        if not (decon_entity and decon_entity.valid) then
          table.remove(decon_entities, entity_index)
          goto next_entity
        end
        if decon_entity.type == "fish" then
          table.remove(decon_entities, entity_index)
          goto next_entity
        end
        local entity_id = entity_uuid(decon_entity)
        if not global.tasks.by_entity[entity_id] then
          local prototype = decon_entity.prototype
          local products = prototype and prototype.mineable_properties.products
          local result_when_mined = (decon_entity.type == "item-entity" and decon_entity.stack) or (products and products[1] and products[1].name) or nil
          local space_for_result = result_when_mined and inventory.can_insert(result_when_mined)
          if space_for_result then
            local distance_to_task = distance(decon_entity.position, spider.position)
            if distance_to_task < double_max_task_range then
              new_entity_task("deconstruct", entity_id, decon_entity, spider, player, surface)
              table.remove(global.available_spiders[player_index][surface_index], spider_index)
              spiders_dispatched = spiders_dispatched + 1
              decon_ordered = true
              goto next_spider
            else
              goto next_spider
            end
          elseif (decon_entity.type == "cliff") then
            if inventory.get_item_count("cliff-explosives") > 0 then
              local distance_to_task = distance(decon_entity.position, spider.position)
              if distance_to_task < double_max_task_range then
                new_entity_task("deconstruct", entity_id, decon_entity, spider, player, surface)
                global.available_spiders[player_index][surface_index][spider_index] = nil
                spiders_dispatched = spiders_dispatched + 1
                decon_ordered = true
                goto next_spider
              else
                goto next_spider
              end
            else
              table.remove(decon_entities, entity_index)
            end
          else
            table.remove(decon_entities, entity_index)
          end
        else
          table.remove(decon_entities, entity_index)
        end
        ::next_entity::
      end

      if not decon_ordered then
        revive_entities = revive_entities or surface.find_entities_filtered({
          area = area,
          type = "entity-ghost",
          force = player_force,
        })
        local revive_entity_count = #revive_entities
        for i = 1, revive_entity_count do
          local entity_index = math.random(1, revive_entity_count)
          local revive_entity = revive_entities[entity_index] ---@type LuaEntity
          if not (revive_entity and revive_entity.valid) then
            table.remove(revive_entities, entity_index)
            goto next_entity
          end
          local entity_id = entity_uuid(revive_entity)
          if not global.tasks.by_entity[entity_id] then
            local items = revive_entity.ghost_prototype.items_to_place_this
            local item_stack = items and items[1]
            if item_stack then
              local item_name = item_stack.name
              local item_count = item_stack.count or 1
              if inventory.get_item_count(item_name) >= item_count then
                local distance_to_task = distance(revive_entity.position, spider.position)
                if distance_to_task < double_max_task_range then
                  new_entity_task("revive", entity_id, revive_entity, spider, player, surface)
                  table.remove(global.available_spiders[player_index][surface_index], spider_index)
                  spiders_dispatched = spiders_dispatched + 1
                  revive_ordered = true
                  goto next_spider
                else
                  goto next_spider
                end
              else
                table.remove(revive_entities, entity_index)
              end
            else
              table.remove(revive_entities, entity_index)
            end
          else
            table.remove(revive_entities, entity_index)
          end
          ::next_entity::
        end
      end

      if not revive_ordered then
        upgrade_entities = upgrade_entities or surface.find_entities_filtered({
          area = area,
          to_be_upgraded = true,
          force = player_force,
        })
        local upgrade_entity_count = #upgrade_entities
        for i = 1, upgrade_entity_count do
          local entity_index = math.random(1, upgrade_entity_count)
          local upgrade_entity = upgrade_entities[entity_index] ---@type LuaEntity
          if not (upgrade_entity and upgrade_entity.valid) then
            table.remove(upgrade_entities, entity_index)
            goto next_entity
          end
          local entity_id = entity_uuid(upgrade_entity)
          if not global.tasks.by_entity[entity_id] then
            local upgrade_target = upgrade_entity.get_upgrade_target()
            local items = upgrade_target and upgrade_target.items_to_place_this
            local item_stack = items and items[1]
            if upgrade_target and item_stack then
              local item_name = item_stack.name
              local item_count = item_stack.count or 1
              if inventory.get_item_count(item_name) >= item_count then
                local distance_to_task = distance(upgrade_entity.position, spider.position)
                if distance_to_task < double_max_task_range then
                  new_entity_task("upgrade", entity_id, upgrade_entity, spider, player, surface)
                  table.remove(global.available_spiders[player_index][surface_index], spider_index)
                  spiders_dispatched = spiders_dispatched + 1
                  upgrade_ordered = true
                  goto next_spider
                else
                  goto next_spider
                end
              else
                table.remove(upgrade_entities, entity_index)
              end
            else
              table.remove(upgrade_entities, entity_index)
            end
          else
            table.remove(upgrade_entities, entity_index)
          end
          ::next_entity::
        end
      end

      if not upgrade_ordered then
        item_proxy_entities = item_proxy_entities or surface.find_entities_filtered({
          area = area,
          type = "item-request-proxy",
          force = player_force,
        })
        local item_proxy_entity_count = #item_proxy_entities
        for i = 1, item_proxy_entity_count do
          local entity_index = math.random(1, item_proxy_entity_count)
          local item_proxy_entity = item_proxy_entities[entity_index] ---@type LuaEntity
          if not (item_proxy_entity and item_proxy_entity.valid) then
            table.remove(item_proxy_entities, entity_index)
            goto next_entity
          end
          local entity_id = entity_uuid(item_proxy_entity)
          if not global.tasks.by_entity[entity_id] then
            local proxy_target = item_proxy_entity.proxy_target
            if proxy_target then
              local items = item_proxy_entity.item_requests
              local item_name, item_count = next(items)
              if inventory.get_item_count(item_name) >= item_count then
                local distance_to_task = distance(item_proxy_entity.position, spider.position)
                if distance_to_task < double_max_task_range then
                  new_entity_task("item_proxy", entity_id, item_proxy_entity, spider, player, surface)
                  table.remove(global.available_spiders[player_index][surface_index], spider_index)
                  spiders_dispatched = spiders_dispatched + 1
                  item_proxy_ordered = true
                  goto next_spider
                else
                  goto next_spider
                end
              else
                table.remove(item_proxy_entities, entity_index)
              end
            else
              table.remove(item_proxy_entities, entity_index)
            end
          else
            table.remove(item_proxy_entities, entity_index)
          end
          ::next_entity::
        end
      end

      -- if not item_proxy_ordered then
      --   decon_tiles = decon_tiles or surface.find_tiles_filtered({
      --     area = area,
      --     to_be_deconstructed = true,
      --     force = player_force,
      --   })
      --   local decon_tiles_count = #decon_tiles
      --   for i = 1, decon_tiles_count do
      --     local entity_index = math.random(1, decon_tiles_count)
      --     local decon_tile = decon_tiles[entity_index] ---@type LuaTile
      --     if not (decon_tile and decon_tile.valid) then
      --       table.remove(decon_tiles, entity_index)
      --       goto next_tile
      --     end
      --     local tile_id = tile_uuid(decon_tile)
      --     if not global.tasks.by_tile[tile_id] then
      --       local minable_properties = decon_tile.prototype.mineable_properties
      --       local products = minable_properties and minable_properties.products
      --       local result_when_mined = (products and products[1] and products[1].name) or nil
      --       local space_for_result = result_when_mined and inventory.can_insert(result_when_mined)
      --       if space_for_result then
      --         local distance_to_task = distance(decon_tile.position, spider.position)
      --         if distance_to_task < max_distance_to_task then
      --           new_tile_task("deconstruct", tile_id, decon_tile, spider, player, surface)
      --           table.remove(global.available_spiders[player_index][surface_index], spider_index)
      --           spiders_dispatched = spiders_dispatched + 1
      --           tile_decon_ordered = true
      --           goto next_spider
      --         else
      --           goto next_spider
      --         end
      --       else
      --         table.remove(decon_tiles, entity_index)
      --       end
      --     else
      --       table.remove(decon_tiles, entity_index)
      --     end
      --     ::next_tile::
      --   end
      -- end

      ::next_spider::
    end

    ::next_player::
  end
end

script.on_nth_tick(15, on_tick)

--- turn selection highlighting on or off
---@param event EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_little_spiders(event)
	local name = event.prototype_name or event.input_name
	if name ~= "toggle-little-spiders" then return end
	local player_index = event.player_index
	global.spiders_enabled[player_index] = not global.spiders_enabled[player_index]
	game.get_player(player_index).set_shortcut_toggled("toggle-little-spiders", global.spiders_enabled[player_index])
end

script.on_event("toggle-little-spiders", toggle_little_spiders)
script.on_event(defines.events.on_lua_shortcut, toggle_little_spiders)
