-- Spiderbots runtime smoke harness
-- /c game.reload_script(); remote.call("spiderbots_tests", "start", game.player.index)

local migrate_0_2_0 = require("util/migrate_0_2_0")

local TEST_SURFACE_NAME = "spiderbots-test"
local TRANSITION_SURFACE_NAME = "spiderbots-transition-test"
local ACTIVE_TASK_SURFACE_CHANGE_TEST_SURFACE_NAME = "spiderbots-active-task-surface-change-test"
local CROSS_SURFACE_REGISTRATION_TEST_SURFACE_NAME = "spiderbots-cross-surface-registration-test"
local FACTORY_TRAVEL_TEST_SURFACE_NAME = "spiderbots-factory-travel-test"
local TEST_AREA = { { -128, -128 }, { 128, 128 } }
local START_POSITION = { x = 0, y = 0 }

local capabilities = {
    "capsule deploy and registration",
    "player follow target and color ownership",
    "task color preservation while player color changes",
    "entity ghost construction",
    "entity upgrade",
    "entity deconstruction and inventory return",
    "tree deconstruction and mining return",
    "rock deconstruction and mining return",
    "vehicle inventory contents deconstruction",
    "spider-vehicle inventory contents deconstruction",
    "cargo-wagon inventory contents deconstruction",
    "item request proxy insertion",
    "non-module inventory item request proxy",
    "tile ghost construction",
    "tile deconstruction",
    "recall to inventory",
    "range/stuck redeploy and jump recovery",
    "idle far-range redeploy",
    "collision-based stuck freeing",
    "surface/teleport/vehicle relinking",
    "destroyed followed vehicle relinking",
    "remote-view deploy and work",
    "remote-view deconstruction item and tile work",
    "remote-view tile deconstruction work",
    "cliff explosive deconstruction",
    "cliff explosive retarget after destroyed target",
    "blueprint/deconstruction cursor visualization",
    "follower limit research",
    "empty-inventory toggle no-op",
    "quality variants",
    "all available quality deploy and recall",
    "quality-aware capsule refund",
    "quality cliff explosive deconstruction",
    "quality inventory contents deconstruction",
    "quality transport-line contents deconstruction",
    "quality item removal request proxy",
    "combined character and vehicle deploy limit",
    "vehicle inventory work sourcing and return preference",
    "vehicle inventory deconstruction return fallback",
    "spider-vehicle inventory work sourcing",
    "cargo-wagon inventory work sourcing",
    "refund/no-space paths",
    "toggle shortcut spam with in-flight projectiles",
    "multi-spiderbot task contention",
    "single-target duplicate assignment suppression",
    "mixed simultaneous task dispatch",
    "dispatch cap under load",
    "projectile lifecycle cleanup",
    "projectile ownership isolation",
    "cross-surface projectile registration relink",
    "stale projectile owner cleanup",
    "generated item projectile prototype coverage",
    "all generated item projectile prototype coverage",
    "representative generated sound prototype coverage",
    "shortcut UI state verification",
    "surface and controller relinking",
    "active-task surface-change redeploy",
    "character replacement relinking",
    "surface-mismatch relink reset",
    "invalid assigned-target relink reset",
    "disallowed controller surface-change ignore",
    "disallowed controller work ignore",
    "disallowed controller matrix ignore",
    "cutscene controller work ignore and restore",
    "factory-travel surface redeploy exception when planet is available",
    "small same-surface movement no redeploy",
    "combo task dependencies",
    "foundation tile priority under mixed work",
    "stacked tile ghost dependencies",
    "tile ghost after tile deconstruction order",
    "technology reset recalculation",
    "in-flight task reset and cancellation",
    "destroyed assigned tile and item proxy reset",
    "failed completion preserves inventory",
    "assigned item removal no-space reset",
    "mid-task distance abandonment",
    "mid-task user order cancellation",
    "mid-task item request changes",
    "changed item request proxy fulfillment",
    "empty and invalid item request proxies",
    "damaged repair target ignore",
    "repair task no-op reset branch",
    "missing player entity task reset",
    "wrong event no-op robustness",
    "invalid-player event no-op robustness",
    "offline-player storage ignore",
    "stale-player assigned task cleanup",
    "connected-player shared task isolation when a second player is available",
    "stale and empty path response handling",
    "unknown path response no-op",
    "cleared path-request task reset",
    "force isolation",
    "neutral-force task acceptance",
    "environmental ignore cases",
    "ignored work resumes after inventory changes",
    "quality content space gating",
    "terrain-invalid ghost inventory preservation",
    "registration label handling",
    "loader upgrade type preservation when available",
    "transport-line and dropped-item deconstruction",
    "splitter transport-line contents deconstruction",
    "underground-belt transport-line contents deconstruction",
    "loader transport-line contents deconstruction",
    "multi-step item request proxies",
    "later satisfiable item request plans",
    "multi-step item removal proxies",
    "bidirectional item request proxy",
    "tile batch construction and force-filtered tile work",
    "assigned tile deconstruction no-space completion",
    "custom input deploy and recall",
    "manual tracked spiderbot mining cleanup",
    "reservation cleanup",
    "storage bootstrap and foundation cache sanity",
    "0.2.0 migration contract",
    "distant task search follows player movement",
    "distant non-entity task search follows player movement",
    "obstacle-corridor pathfinding",
    "gate pathfinding",
    "friendly-force isolation",
    "friendly-force upgrade item and tile deconstruction isolation",
    "disallowed-controller toggle recall stability",
    "assigned-task destroyed spiderbot requeue",
}

local steps = {}
local sections = {}
local section_order = {}
local current_section_id = nil
local harness = {}
local global_env = _ENV
local _ENV = setmetatable({}, {
    __index = function(_, key)
        local value = harness[key]
        if value ~= nil then return value end
        return global_env[key]
    end,
    __newindex = harness,
})

local section_prefixes = {
    setup = {
        "prepare isolated test surface",
    },
    deploy = {
        "prepare isolated test surface",
        "use spiderbot capsule",
        "capsule deploy registered one following spiderbot",
    },
}

function close_section()
    if not current_section_id then return end
    sections[current_section_id].end_step = #steps
    current_section_id = nil
end

function add_section(id, name, options)
    if sections[id] then
        error("duplicate spiderbots test section " .. tostring(id))
    end
    close_section()
    local section = {
        id = id,
        name = name,
        start_step = #steps + 1,
        prefix = options and options.prefix or nil,
    }
    sections[id] = section
    table.insert(section_order, section)
    current_section_id = id
end

function add_action(name, fn, delay_after)
    table.insert(steps, {
        type = "action",
        name = name,
        fn = fn,
        delay_after = delay_after or 1,
        section_id = current_section_id,
    })
end

function add_wait(name, predicate, timeout, delay_after)
    table.insert(steps, {
        type = "wait",
        name = name,
        predicate = predicate,
        timeout = timeout or (60 * 20),
        delay_after = delay_after or 1,
        section_id = current_section_id,
    })
end

function step_index_by_name(name)
    for index, step in ipairs(steps) do
        if step.name == name then
            return index
        end
    end
    error("missing spiderbots test step " .. tostring(name))
end

function append_sequence_step(sequence, seen_steps, step_index)
    if not steps[step_index] then
        error("invalid spiderbots test step " .. tostring(step_index))
    end
    if seen_steps[step_index] then return end
    table.insert(sequence, step_index)
    seen_steps[step_index] = true
end

function build_section_sequence(section)
    local sequence = {}
    local seen_steps = {}
    local prefix = section_prefixes[section.prefix]
    if section.prefix and not prefix then
        error("unknown spiderbots test section prefix " .. tostring(section.prefix))
    end
    if prefix then
        for _, step_name in ipairs(prefix) do
            append_sequence_step(sequence, seen_steps, step_index_by_name(step_name))
        end
    end
    for step_index = section.start_step, section.end_step do
        append_sequence_step(sequence, seen_steps, step_index)
    end
    return sequence
end

function list_sections()
    local summaries = {}
    for index, section in ipairs(section_order) do
        local step_count = section.end_step - section.start_step + 1
        local run_step_count = #build_section_sequence(section)
        table.insert(summaries, {
            index = index,
            id = section.id,
            name = section.name,
            start_step = section.start_step,
            end_step = section.end_step,
            step_count = step_count,
            run_step_count = run_step_count,
            prefix = section.prefix or "none",
        })
    end
    return summaries
end

function resolve_section(section_id)
    local section = sections[tostring(section_id)]
    if section then return section end
    local section_index = tonumber(section_id)
    if section_index then
        section = section_order[math.floor(section_index)]
        if section then return section end
    end
    error("unknown spiderbots test section " .. tostring(section_id))
end

local failure_sound_path = nil

function failure_print_settings()
    if failure_sound_path == false then return nil end
    if failure_sound_path then return { sound_path = failure_sound_path } end
    for _, sound_path in pairs({
        "medium-explosion",
        "grenade-explosion",
        "big-explosion",
        "massive-explosion",
        "explosion",
        "utility/alert_destroyed",
    }) do
        if helpers.is_valid_sound_path(sound_path) then
            failure_sound_path = sound_path
            return { sound_path = sound_path }
        end
    end
    failure_sound_path = false
end

function print_to_player(run, message, print_settings)
    log("[spiderbots-test] " .. message)
    local player = game.get_player(run.player_index)
    if player and player.valid then
        player.print("[spiderbots-test] " .. message, print_settings)
    else
        game.print("[spiderbots-test] " .. message, print_settings)
    end
end

local cleanup_failed_run = nil

function fail(run, message)
    if cleanup_failed_run then
        pcall(cleanup_failed_run, run)
    end
    run.status = "failed"
    run.finished_tick = game.tick
    run.error = message
    print_to_player(run, "FAILED: " .. message, failure_print_settings())
end

function pass_step(run, step)
    local passed_step = run.step_index
    print_to_player(run, "PASS " .. passed_step .. "/" .. #steps .. ": " .. step.name)
    run.wait_started_tick = nil
    if run.step_sequence then
        local next_sequence_index = (run.step_sequence_index or 1) + 1
        if next_sequence_index > #run.step_sequence then
            finish(run)
            return
        end
        run.step_sequence_index = next_sequence_index
        run.step_index = run.step_sequence[next_sequence_index]
    else
        run.step_index = passed_step + 1
        if run.stop_after_step and passed_step >= run.stop_after_step then
            finish(run)
            return
        end
    end
    run.due_tick = game.tick + (step.delay_after or 1)
end

function finish(run)
    run.status = "passed"
    run.finished_tick = game.tick
    print_to_player(run, "PASSED in " .. (run.finished_tick - run.started_tick) .. " ticks")
end

function start_sequence(player_index, sequence, label, section)
    if not sequence[1] then
        error("empty spiderbots test sequence")
    end
    local index = player_index or (game.player and game.player.index) or 1
    storage.spiderbots_test = {
        status = "running",
        player_index = index,
        started_tick = game.tick,
        due_tick = game.tick + 1,
        step_index = sequence[1],
        step_sequence = sequence,
        step_sequence_index = 1,
        section_id = section and section.id or nil,
        section_name = section and section.name or nil,
        context = {},
    }
    print_to_player(storage.spiderbots_test, label)
end

function start_section(player_index, section_id)
    local section = resolve_section(section_id)
    local sequence = build_section_sequence(section)
    start_sequence(
        player_index,
        sequence,
        "starting section " .. section.id .. " (" .. #sequence .. " steps): " .. section.name,
        section
    )
end

function require_player(run)
    local player = game.get_player(run.player_index)
    if not (player and player.valid) then
        error("missing player " .. tostring(run.player_index))
    end
    return player
end

function require_character(player)
    local character = player.character
    if not (character and character.valid) then
        error("test needs a valid character controller")
    end
    return character
end

function require_inventory(player)
    local inventory = player.get_main_inventory()
    if not (inventory and inventory.valid) then
        error("test needs a valid character main inventory")
    end
    return inventory
end

function p(x, y)
    return { x = x, y = y }
end

function distance(a, b)
    local x = a.x - b.x
    local y = a.y - b.y
    return math.sqrt(x * x + y * y)
end

function test_surface()
    local surface = game.surfaces[TEST_SURFACE_NAME]
    if not surface then
        surface = game.create_surface(TEST_SURFACE_NAME)
    end
    surface.generate_with_lab_tiles = true
    surface.request_to_generate_chunks(START_POSITION, 5)
    surface.force_generate_chunk_requests()
    surface.build_checkerboard(TEST_AREA)
    surface.always_day = true
    return surface
end

function destroy_test_entities(surface, player)
    local character = player.character
    for _, entity in pairs(surface.find_entities_filtered { area = TEST_AREA }) do
        if entity.valid and entity ~= character then
            entity.destroy({ raise_destroy = true })
        end
    end
end

function clear_tracked_spiderbots(player_index)
    storage.spiderbots = storage.spiderbots or {}
    if storage.spiderbots[player_index] then
        for _, spiderbot_data in pairs(storage.spiderbots[player_index]) do
            local spiderbot = spiderbot_data.spiderbot
            if spiderbot and spiderbot.valid then
                spiderbot.destroy({ raise_destroy = true })
            end
        end
    end
    storage.spiderbots[player_index] = {}
end

function clear_spiderbot_trigger_projectiles()
    for _, surface in pairs(game.surfaces) do
        local ok, projectiles = pcall(function()
            return surface.find_entities_filtered { name = "spiderbot-trigger" }
        end)
        if ok and projectiles then
            for _, projectile in pairs(projectiles) do
                if projectile.valid then
                    pcall(function()
                        projectile.destroy({ raise_destroy = true })
                    end)
                end
            end
        end
    end
end

function tracked_spiderbots(player_index)
    storage.spiderbots = storage.spiderbots or {}
    storage.spiderbots[player_index] = storage.spiderbots[player_index] or {}
    return storage.spiderbots[player_index]
end

function spiderbot_count(player_index)
    local count = 0
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid then
            count = count + 1
        end
    end
    return count
end

function first_spiderbot_data(player_index)
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid then
            return spiderbot_data
        end
    end
end

function first_spiderbot(player_index)
    local spiderbot_data = first_spiderbot_data(player_index)
    return spiderbot_data and spiderbot_data.spiderbot
end

function all_spiderbots_idle(player_index)
    local found = false
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid then
            found = true
            if spiderbot_data.status ~= "idle" then
                return false
            end
        end
    end
    return found
end

function active_spiderbot_task_count(player_index)
    local count = 0
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid and spiderbot_data.task then
            count = count + 1
        end
    end
    return count
end

function active_task_target_count(player_index, target)
    local count = 0
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        local task = spiderbot_data.task
        if spiderbot and spiderbot.valid and task then
            local task_target = task.entity or task.tile
            if task_target == target then
                count = count + 1
            end
        end
    end
    return count
end

function same_valid_surface_position(a, b)
    if not (a and b and a.valid and b.valid) then return false end
    local ok, matches = pcall(function()
        return a.surface.index == b.surface.index
            and a.position.x == b.position.x
            and a.position.y == b.position.y
    end)
    return ok and matches
end

function entity_matches(a, b)
    return a == b or same_valid_surface_position(a, b)
end

function task_target_matches(task, target)
    local task_target = task and (task.entity or task.tile)
    return entity_matches(task_target, target)
end

function assigned_task_for_target(run, task_type, target)
    if not (target and target.valid) then return nil end
    for spiderbot_id, spiderbot_data in pairs(tracked_spiderbots(run.player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        local task = spiderbot_data.task
        if spiderbot
            and spiderbot.valid
            and spiderbot_data.status == "task_assigned"
            and task
            and task.task_type == task_type
            and task_target_matches(task, target)
        then
            return spiderbot_data, spiderbot_id
        end
    end
end

function complete_assigned_task_now(spiderbot_data)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot and spiderbot.valid) then return false end
    spiderbot.autopilot_destination = nil
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = spiderbot,
    })
    return true
end

function active_task_id_count(player_index, task_id)
    local count = 0
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        local task = spiderbot_data.task
        if spiderbot and spiderbot.valid and task and task.task_id == task_id then
            count = count + 1
        end
    end
    return count
end

function first_spiderbot_idle_without_task(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    return spiderbot_data_idle_without_task(spiderbot_data)
end

function spiderbot_data_idle_without_task(spiderbot_data)
    return spiderbot_data
        and spiderbot_data.spiderbot
        and spiderbot_data.spiderbot.valid
        and spiderbot_data.status == "idle"
        and spiderbot_data.task == nil
        and spiderbot_data.path_request_id == nil
end

function spiderbot_id_idle_without_task(run, spiderbot_id)
    local spiderbot_data = spiderbot_id and tracked_spiderbots(run.player_index)[spiderbot_id]
    return spiderbot_data_idle_without_task(spiderbot_data)
end

function observe_tasks(run)
    run.context.seen_tasks = run.context.seen_tasks or {}
    for _, spiderbot_data in pairs(tracked_spiderbots(run.player_index)) do
        local task = spiderbot_data.task
        if task and task.task_type then
            run.context.first_seen_task = run.context.first_seen_task or task.task_type
            run.context.seen_tasks[task.task_type] = true
        end
    end
end

function mark_expected_task(run, task_type)
    run.context.expected_task = task_type
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function expected_task_was_seen(run)
    local task_type = run.context.expected_task
    return task_type and run.context.seen_tasks and run.context.seen_tasks[task_type]
end

function mark_expected_tasks(run, task_types)
    run.context.expected_task = nil
    run.context.expected_tasks = {}
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
    for _, task_type in pairs(task_types) do
        run.context.expected_tasks[task_type] = true
    end
end

function expected_tasks_were_seen(run)
    if not (run.context.expected_tasks and run.context.seen_tasks) then return false end
    for task_type, _ in pairs(run.context.expected_tasks) do
        if not run.context.seen_tasks[task_type] then
            return false
        end
    end
    return true
end

function colors_match(a, b)
    return a and b
        and math.abs((a.r or 0) - (b.r or 0)) < 0.01
        and math.abs((a.g or 0) - (b.g or 0)) < 0.01
        and math.abs((a.b or 0) - (b.b or 0)) < 0.01
end

function insert(player, stack)
    local inventory = require_inventory(player)
    local inserted = inventory.insert(stack)
    if inserted < (stack.count or 1) then
        error("could not insert enough " .. stack.name .. " into player inventory")
    end
end

function insert_into_inventory(inventory, stack)
    if not (inventory and inventory.valid) then
        error("missing inventory for " .. stack.name)
    end
    local inserted = inventory.insert(stack)
    if inserted < (stack.count or 1) then
        error("could not insert enough " .. stack.name .. " into inventory")
    end
end

function remove_from_main_inventory(player, stack)
    local inventory = require_inventory(player)
    local remove_stack = {
        name = stack.name,
        count = stack.count or 1000,
        quality = stack.quality or "normal",
    }
    inventory.remove(remove_stack)
end

function remove_all_qualities_from_main_inventory(player, item_name)
    local inventory = require_inventory(player)
    for quality, _ in pairs(prototypes.quality or {}) do
        inventory.remove({ name = item_name, count = 1000, quality = quality })
    end
    inventory.remove({ name = item_name, count = 1000 })
end

function cleanup_test_inventory(player)
    clear_player_cursor_stack(player)
    local item_names = {
        "spiderbot",
        "small-electric-pole",
        "transport-belt",
        "fast-transport-belt",
        "underground-belt",
        "fast-underground-belt",
        "splitter",
        "fast-splitter",
        "loader",
        "fast-loader",
        "wooden-chest",
        "assembling-machine-2",
        "assembling-machine-3",
        "speed-module",
        "efficiency-module",
        "stone-brick",
        "landfill",
        "cliff-explosives",
        "iron-plate",
        "copper-plate",
        "car",
        "spidertron",
        "cargo-wagon",
        "locomotive",
        "rail",
        "repair-pack",
        "deconstruction-planner",
        "upgrade-planner",
        "blueprint",
        "blueprint-book",
    }
    for _, item_name in pairs(item_names) do
        if prototypes.item[item_name] then
            remove_all_qualities_from_main_inventory(player, item_name)
        end
    end
end

function fill_inventory_until_cannot_insert(inventory, filler_stack, blocked_stack)
    local attempts = 0
    while inventory.can_insert(blocked_stack) and attempts < 2000 do
        local inserted = inventory.insert(filler_stack)
        if inserted <= 0 then break end
        attempts = attempts + 1
    end
    if inventory.can_insert(blocked_stack) then
        error("failed to fill inventory enough to block " .. blocked_stack.name)
    end
end

function require_quality(name)
    if not (prototypes.quality and prototypes.quality[name]) then
        error("test requires quality prototype " .. name)
    end
    return name
end

function quality_under_test(run)
    run.context.quality_name = run.context.quality_name or require_quality("uncommon")
    return run.context.quality_name
end

function position_near_player(run, x_offset, y_offset)
    local player = require_player(run)
    local target = player.physical_vehicle or require_character(player)
    return p(target.position.x + x_offset, target.position.y + y_offset)
end

function ensure_surface(name, position)
    local surface = game.surfaces[name]
    if not surface then
        surface = game.create_surface(name)
    end
    surface.generate_with_lab_tiles = true
    surface.request_to_generate_chunks(position or START_POSITION, 4)
    surface.force_generate_chunk_requests()
    local center = position or START_POSITION
    surface.build_checkerboard({
        { center.x - 64, center.y - 64 },
        { center.x + 64, center.y + 64 },
    })
    surface.always_day = true
    return surface
end

function set_square_tiles(surface, center, radius, tile_name)
    local tiles = {}
    for x = center.x - radius, center.x + radius do
        for y = center.y - radius, center.y + radius do
            table.insert(tiles, { name = tile_name, position = { x = x, y = y } })
        end
    end
    surface.set_tiles(tiles)
end

function set_rectangle_tiles(surface, left_top, right_bottom, tile_name)
    local tiles = {}
    for x = left_top.x, right_bottom.x do
        for y = left_top.y, right_bottom.y do
            table.insert(tiles, { name = tile_name, position = { x = x, y = y } })
        end
    end
    surface.set_tiles(tiles)
end

function square_area(center, radius)
    local x = math.floor(center.x)
    local y = math.floor(center.y)
    return {
        { x - radius, y - radius },
        { x + radius, y + radius },
    }
end

function natural_ground_tile_name()
    local candidates = { "grass-1", "dry-dirt", "dirt-1", "landfill", "foundation", "lab-dark-1" }
    for _, tile_name in pairs(candidates) do
        if prototypes.tile[tile_name] then
            return tile_name
        end
    end
    error("test could not find a natural ground tile")
end

function prepare_buildable_ground(surface, position, radius)
    surface.build_checkerboard(square_area(position, radius or 2))
end

function require_item_prototype(name)
    if not prototypes.item[name] then
        error("test requires item prototype " .. name)
    end
    return name
end

function require_entity_prototype(name)
    if not prototypes.entity[name] then
        error("test requires entity prototype " .. name)
    end
    return name
end

function require_tile_prototype(name)
    if not prototypes.tile[name] then
        error("test requires tile prototype " .. name)
    end
    return name
end

function shortcut_toggled(player)
    local ok, value = pcall(function()
        return player.is_shortcut_toggled("toggle-spiderbots")
    end)
    if not ok then
        error("LuaPlayer.is_shortcut_toggled failed: " .. tostring(value))
    end
    return value
end

function available_quality_names()
    local names = {}
    for name, _ in pairs(prototypes.quality or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function find_generated_sound(sound_type, prototype_names)
    for _, prototype_name in pairs(prototype_names) do
        local sound_path = prototype_name .. "-" .. sound_type
        if helpers.is_valid_sound_path(sound_path) then
            return sound_path
        end
    end
end

function validate_generated_projectile_prototypes()
    for _, entity_name in pairs({ "spiderbot-trigger", "spiderbot-no-trigger" }) do
        if not prototypes.entity[entity_name] then
            error("missing spiderbot projectile prototype " .. entity_name)
        end
    end
    local item_names = {
        "small-electric-pole",
        "transport-belt",
        "fast-transport-belt",
        "stone-brick",
        "landfill",
        "speed-module",
        "cliff-explosives",
        "spiderbot",
    }
    for _, item_name in pairs(item_names) do
        require_item_prototype(item_name)
        local projectile_name = item_name .. "-spiderbot-projectile"
        if not prototypes.entity[projectile_name] then
            error("missing generated item projectile prototype " .. projectile_name)
        end
    end
    for item_name, _ in pairs(prototypes.item) do
        local projectile_name = item_name .. "-spiderbot-projectile"
        if not prototypes.entity[projectile_name] then
            error("missing generated item projectile prototype " .. projectile_name)
        end
    end
    local generated_sound_candidates = {
        build_sound = {
            "small-electric-pole",
            "wooden-chest",
            "transport-belt",
            "assembling-machine-2",
            "stone-furnace",
            "pipe",
        },
        mined_sound = {
            "small-electric-pole",
            "wooden-chest",
            "transport-belt",
            "assembling-machine-2",
            "stone-furnace",
            "pipe",
        },
        mining_sound = {
            "iron-ore",
            "copper-ore",
            "coal",
            "stone",
            "tree-01",
            "rock-huge",
        },
        inventory_move_sound = {
            "iron-plate",
            "copper-plate",
            "wooden-chest",
            "transport-belt",
            "speed-module",
            "landfill",
        },
    }
    local generated_sound_matches = {}
    for sound_type, prototype_names in pairs(generated_sound_candidates) do
        local sound_path = find_generated_sound(sound_type, prototype_names)
        if sound_path then
            generated_sound_matches[sound_type] = sound_path
        end
    end
    if next(generated_sound_matches) == nil then
        error("missing all representative generated sound prototypes")
    end
end

function validate_storage_bootstrap(run)
    local player = require_player(run)
    for _, key in pairs({
        "spiderbots",
        "spiderbots_enabled",
        "spiderbot_follower_count",
        "previous_controller",
        "previous_player_entity",
        "previous_player_color",
        "render_objects",
        "foundation_tile_names",
        "foundation_tile_names_array",
    }) do
        if type(storage[key]) ~= "table" then
            error("storage bootstrap missing table " .. key)
        end
    end
    if type(storage.spiderbots[player.index]) ~= "table" then
        error("storage bootstrap missing player spiderbot table")
    end
    if storage.spiderbots_enabled[player.index] ~= true then
        error("storage bootstrap did not preserve enabled state")
    end
    if (storage.spiderbot_follower_count[player.force.name] or 0) < 10 then
        error("storage bootstrap missing follower count for force " .. player.force.name)
    end
    if not storage.spider_leg_collision_mask then
        error("storage bootstrap missing spider leg collision mask")
    end
    local foundation_count = 0
    for name, tile in pairs(prototypes.tile) do
        if tile.is_foundation then
            foundation_count = foundation_count + 1
            if not storage.foundation_tile_names[name] then
                error("storage bootstrap missing foundation tile " .. name)
            end
        end
    end
    if foundation_count ~= #storage.foundation_tile_names_array then
        error("storage bootstrap foundation array mismatch")
    end
end

function validate_0_2_0_migration_contract()
    local shortcut_state = {}
    local fake_character = { valid = true, name = "fake-character" }
    local fake_vehicle = { valid = true, name = "fake-vehicle" }
    local fake_vehicle_only = { valid = true, name = "fake-vehicle-only" }
    local fake_player = {
        valid = true,
        index = 7,
        character = fake_character,
        vehicle = fake_vehicle,
        set_shortcut_toggled = function(shortcut_name, toggled)
            if shortcut_name == "toggle-spiderbots" then
                shortcut_state[7] = toggled
            end
        end,
    }
    local fake_vehicle_player = {
        valid = true,
        index = 8,
        character = nil,
        vehicle = fake_vehicle_only,
        set_shortcut_toggled = function(shortcut_name, toggled)
            if shortcut_name == "toggle-spiderbots" then
                shortcut_state[8] = toggled
            end
        end,
    }
    local fake_spiderbot = { valid = true }
    local fake_vehicle_spiderbot = { valid = true }
    local fake_invalid_spiderbot = { valid = false }
    local fake_missing_player_spiderbot = { valid = true }
    local fake_storage = {
        spiders = {
            [7] = {
                legacy_spiderbot = fake_spiderbot,
                invalid_spiderbot = fake_invalid_spiderbot,
            },
            [8] = {
                vehicle_spiderbot = fake_vehicle_spiderbot,
            },
            [9] = {
                missing_player_spiderbot = fake_missing_player_spiderbot,
            },
        },
        spiders_enabled = {
            [7] = true,
            [8] = false,
        },
        available_spiders = {
            legacy_spiderbot = true,
        },
        tasks = {
            by_entity = { old = true },
            by_spider = { old = true },
            by_tile = { old = true },
            nudges = { old = true },
        },
        path_requested = { old = true },
        spider_path_requests = { old = true },
        spider_path_to_position_requests = { old = true },
        previous_controller = { [7] = 1 },
        previous_player_entity = { [7] = 2 },
        previous_player_color = { [7] = { r = 1, g = 1, b = 1 } },
    }
    local fake_game = {
        players = { fake_player, fake_vehicle_player },
        get_player = function(player_index)
            if player_index == 7 then return fake_player end
            if player_index == 8 then return fake_vehicle_player end
            return nil
        end,
    }

    migrate_0_2_0(fake_storage, fake_game)

    local migrated = fake_storage.spiderbots
        and fake_storage.spiderbots[7]
        and fake_storage.spiderbots[7].legacy_spiderbot
    if not migrated then
        error("0.2.0 migration did not create spiderbots storage")
    end
    if migrated.spiderbot ~= fake_spiderbot then
        error("0.2.0 migration did not preserve spiderbot reference")
    end
    if fake_storage.spiderbots[7].invalid_spiderbot ~= nil then
        error("0.2.0 migration preserved invalid spiderbot")
    end
    if fake_storage.spiderbots[9] and fake_storage.spiderbots[9].missing_player_spiderbot ~= nil then
        error("0.2.0 migration preserved missing-player spiderbot")
    end
    if migrated.player ~= fake_player or migrated.player_index ~= 7 then
        error("0.2.0 migration did not preserve player ownership")
    end
    if migrated.status ~= "idle" or migrated.path_request_id ~= nil or migrated.task ~= nil then
        error("0.2.0 migration did not reset migrated task state")
    end
    if fake_spiderbot.follow_target ~= fake_character then
        error("0.2.0 migration did not relink spiderbot follow target")
    end
    local vehicle_migrated = fake_storage.spiderbots
        and fake_storage.spiderbots[8]
        and fake_storage.spiderbots[8].vehicle_spiderbot
    if not vehicle_migrated then
        error("0.2.0 migration did not migrate vehicle-only player spiderbot")
    end
    if vehicle_migrated.player ~= fake_vehicle_player or vehicle_migrated.player_index ~= 8 then
        error("0.2.0 migration did not preserve vehicle-only player ownership")
    end
    if fake_vehicle_spiderbot.follow_target ~= fake_vehicle_only then
        error("0.2.0 migration did not relink vehicle-only spiderbot follow target")
    end
    if fake_storage.spiders ~= nil or fake_storage.available_spiders ~= nil or fake_storage.tasks ~= nil then
        error("0.2.0 migration did not remove legacy task/spider tables")
    end
    if fake_storage.path_requested ~= nil or fake_storage.spider_path_requests ~= nil or fake_storage.spider_path_to_position_requests ~= nil then
        error("0.2.0 migration did not remove legacy path tables")
    end
    if fake_storage.spiders_enabled ~= nil then
        error("0.2.0 migration did not remove legacy enabled table")
    end
    if fake_storage.spiderbots_enabled[7] ~= true or shortcut_state[7] ~= true then
        error("0.2.0 migration did not preserve enabled shortcut state")
    end
    if fake_storage.spiderbots_enabled[8] ~= false or shortcut_state[8] ~= false then
        error("0.2.0 migration did not preserve disabled shortcut state")
    end
    if fake_storage.previous_controller[7] ~= -500
        or fake_storage.previous_player_entity[7] ~= -500
        or fake_storage.previous_player_color[7].r ~= -500
    then
        error("0.2.0 migration did not invalidate previous player caches")
    end
end

function tree_prototype_name()
    if prototypes.entity["tree-01"] then
        return "tree-01"
    end
    for name, prototype in pairs(prototypes.entity) do
        if prototype.type == "tree" then
            return name
        end
    end
    error("test requires a tree prototype")
end

function first_item_product_for_entity_prototype(entity_name)
    local prototype = prototypes.entity[entity_name]
    local products = prototype and prototype.mineable_properties and prototype.mineable_properties.products
    if not products then return nil end
    for _, product in pairs(products) do
        if product.type == "item" then
            return {
                name = product.name,
                count = product.amount or product.amount_max or product.amount_min or 1,
                quality = "normal",
            }
        end
    end
end

function tree_prototype_with_item_product()
    local preferred_tree = tree_prototype_name()
    if first_item_product_for_entity_prototype(preferred_tree) then
        return preferred_tree
    end
    for name, prototype in pairs(prototypes.entity) do
        if prototype.type == "tree" and first_item_product_for_entity_prototype(name) then
            return name
        end
    end
    error("test requires a tree prototype with an item mining product")
end

function rock_prototype_with_item_product()
    local candidates = { "rock-huge", "huge-rock", "big-rock", "big-sand-rock", "sand-rock-big" }
    for _, name in pairs(candidates) do
        if prototypes.entity[name] and first_item_product_for_entity_prototype(name) then
            return name
        end
    end
    for name, prototype in pairs(prototypes.entity) do
        if prototype.type == "simple-entity"
            and string.find(name, "rock", 1, true)
            and first_item_product_for_entity_prototype(name)
        then
            return name
        end
    end
    error("test requires a rock prototype with an item mining product")
end

function create_small_pole_ghost(surface, player, position, quality)
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = quality or "normal",
    }
    if not ghost then error("failed to create small-electric-pole ghost") end
    return ghost
end

function cliff_blocked_small_pole_position(surface, cliff, force)
    local box = cliff.bounding_box
    for x = math.floor(box.left_top.x) - 1, math.ceil(box.right_bottom.x) + 1 do
        for y = math.floor(box.left_top.y) - 1, math.ceil(box.right_bottom.y) + 1 do
            local position = p(x + 0.5, y + 0.5)
            local nearby_cliffs = surface.find_entities_filtered { type = "cliff", position = position, radius = 1.5 }
            local tile_entities = surface.find_entities_filtered {
                area = {
                    { position.x - 0.49, position.y - 0.49 },
                    { position.x + 0.49, position.y + 0.49 },
                },
            }
            local has_non_cliff_blocker = false
            for _, entity in pairs(tile_entities) do
                if entity.type ~= "cliff" then
                    has_non_cliff_blocker = true
                    break
                end
            end
            if nearby_cliffs[1]
                and not has_non_cliff_blocker
                and not surface.can_place_entity { name = "small-electric-pole", position = position, force = force }
            then
                return position
            end
        end
    end
    return p(math.floor(cliff.position.x) + 0.5, math.floor(cliff.position.y) + 0.5)
end

function capture_square_tiles(surface, center, radius)
    local tiles = {}
    for x = center.x - radius, center.x + radius do
        for y = center.y - radius, center.y + radius do
            local tile = surface.get_tile(x, y)
            if tile and tile.valid then
                table.insert(tiles, { name = tile.name, position = { x = x, y = y } })
            end
        end
    end
    return tiles
end

function require_inventory_from_entity(entity, inventory_id)
    local inventory = entity and entity.valid and entity.get_inventory(inventory_id)
    if not (inventory and inventory.valid) then
        error("missing entity inventory " .. tostring(inventory_id))
    end
    return inventory
end

function require_character_inventory(player)
    local character = require_character(player)
    return require_inventory_from_entity(character, defines.inventory.character_main)
end

function spiderbot_data_by_quality(player_index, quality)
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid and spiderbot.quality.name == quality then
            return spiderbot_data
        end
    end
end

function spiderbot_by_quality(player_index, quality)
    local spiderbot_data = spiderbot_data_by_quality(player_index, quality)
    return spiderbot_data and spiderbot_data.spiderbot
end

function spiderbot_count_by_quality(player_index, quality)
    local count = 0
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid and spiderbot.quality.name == quality then
            count = count + 1
        end
    end
    return count
end

function all_spiderbots_idle_with_quality(player_index, quality)
    local found = false
    for _, spiderbot_data in pairs(tracked_spiderbots(player_index)) do
        local spiderbot = spiderbot_data.spiderbot
        if spiderbot and spiderbot.valid and spiderbot.quality.name == quality then
            found = true
            if spiderbot_data.status ~= "idle" then
                return false
            end
        end
    end
    return found
end

function reset_active_spiderbots(run)
    clear_spiderbot_trigger_projectiles()
    clear_tracked_spiderbots(run.player_index)
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[run.player_index] = {}
    storage.spiderbots_enabled[run.player_index] = true
end

function clear_player_cursor_stack(player)
    local cleared = player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid_for_read then
        cursor_stack.clear()
    end
    pcall(function()
        player.cursor_ghost = nil
    end)
    return cleared
end

function find_entity_near(name, position, radius, surface_name)
    local surface = game.surfaces[surface_name or TEST_SURFACE_NAME]
    radius = radius or 1.5
    if not surface then return nil end
    local entities = surface.find_entities_filtered {
        name = name,
        area = {
            { position.x - radius, position.y - radius },
            { position.x + radius, position.y + radius },
        },
    }
    return entities[1]
end

function find_entities_near(filter, position, radius, surface_name)
    local surface = game.surfaces[surface_name or TEST_SURFACE_NAME]
    radius = radius or 1.5
    if not surface then return {} end
    filter.area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
    }
    return surface.find_entities_filtered(filter)
end

function find_item_on_ground_near(item_name, position, radius, surface_name)
    local surface = game.surfaces[surface_name or TEST_SURFACE_NAME]
    radius = radius or 2
    if not surface then return nil end
    local entities = surface.find_entities_filtered {
        type = "item-entity",
        area = {
            { position.x - radius, position.y - radius },
            { position.x + radius, position.y + radius },
        },
    }
    for _, entity in pairs(entities) do
        if entity.valid and entity.stack and entity.stack.valid_for_read and entity.stack.name == item_name then
            return entity
        end
    end
end

function call_registered_handler(event_name, event)
    local handler = script.get_event_handler(event_name)
    if not handler then
        error("missing registered handler for event " .. tostring(event_name))
    end
    event.name = event.name or event_name
    event.tick = event.tick or game.tick
    handler(event)
end

function task_id_for_entity(entity)
    if not (entity and entity.valid) then
        error("cannot register invalid entity task")
    end
    local registration_number = script.register_on_object_destroyed(entity)
    return registration_number
end

function task_id_for_tile(tile)
    if not (tile and tile.valid) then
        error("cannot register invalid tile task")
    end
    local position = tile.position
    return string.format("tile_%s_%d_%d", tile.surface.name, position.x, position.y)
end

function next_synthetic_path_request_id(run)
    run.context.synthetic_path_request_id = (run.context.synthetic_path_request_id or 900000) + 1
    return run.context.synthetic_path_request_id
end

function assign_synthetic_build_ghost_path_task(run, key, x_offset, y_offset)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot_data = first_spiderbot_data(run.player_index)
    if not (spiderbot_data and spiderbot_data.spiderbot and spiderbot_data.spiderbot.valid) then
        error("missing spiderbot for synthetic path task")
    end
    local position = position_near_player(run, x_offset, y_offset)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    local path_request_id = next_synthetic_path_request_id(run)
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id_for_entity(ghost),
        entity = ghost,
        projectile_item = "small-electric-pole",
    }
    spiderbot_data.status = "path_requested"
    spiderbot_data.path_request_id = path_request_id
    run.context[key .. "_ghost"] = ghost
    run.context[key .. "_path_request_id"] = path_request_id
    return spiderbot_data, ghost, path_request_id
end

function synthetic_path_to(position)
    return {
        { position = position },
    }
end

function cleanup_context_entity(run, key)
    local entity = run.context[key]
    if entity and entity.valid then
        entity.destroy({ raise_destroy = true })
    end
    run.context[key] = nil
end

function set_researched(force, technology_name)
    local technology = force.technologies[technology_name]
    if technology then
        technology.researched = true
    end
end

function follower_count_from_technology(technology)
    local level = tonumber(string.match(technology.name, "%d+$"))
    if not level then return nil end
    local prototype = technology.prototype
    if prototype and prototype.max_level > prototype.level then
        level = math.max(level, (technology.level or level) - 1)
    end
    return level * 10 + 10
end

function research_follower_count_technology(technology)
    technology.researched = true
    local prototype = technology.prototype
    if prototype and prototype.max_level > prototype.level then
        local level = tonumber(string.match(technology.name, "%d+$")) or prototype.level
        technology.level = math.max(technology.level or level, level + 1)
    end
end

function clear_follower_count_research(force)
    for level = 7, 1, -1 do
        local technology = force.technologies["spiderbot-follower-count-" .. level]
        if technology then
            local prototype = technology.prototype
            if prototype and prototype.max_level > prototype.level then
                technology.level = tonumber(string.match(technology.name, "%d+$")) or prototype.level
            end
            technology.saved_progress = 0
            technology.researched = false
        end
    end
end

function set_recipe_enabled(force, recipe_name)
    local recipe = force.recipes[recipe_name]
    if recipe then
        recipe.enabled = true
    end
end

function exit_player_vehicle(player)
    local vehicle = player.physical_vehicle
    if vehicle and vehicle.valid then
        pcall(function()
            vehicle.set_driver(nil)
        end)
    end
end

function setup_run(run)
    local player = require_player(run)
    exit_player_vehicle(player)
    local character = require_character(player)
    local surface = test_surface()
    clear_tracked_spiderbots(player.index)
    storage.spiderbots_enabled = storage.spiderbots_enabled or {}
    storage.spiderbots_enabled[player.index] = true
    storage.spiderbot_follower_count = storage.spiderbot_follower_count or {}
    storage.spiderbot_follower_count[player.force.name] = 10
    storage.cliffs_to_be_exploded = {}
    destroy_test_entities(surface, player)
    surface.build_checkerboard(TEST_AREA)
    if not player.teleport(START_POSITION, surface) then
        error("failed to teleport player to test surface")
    end
    character = require_character(player)
    player.cheat_mode = true
    cleanup_test_inventory(player)
    set_researched(player.force, "spiderbots")
    set_researched(player.force, "logistics-2")
    set_researched(player.force, "cliff-explosives")
    set_recipe_enabled(player.force, "spiderbot")
    set_recipe_enabled(player.force, "fast-transport-belt")
    local inventory = require_inventory(player)
    run.context.initial_spiderbot_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 4, quality = "normal" })
    insert(player, { name = "transport-belt", count = 4, quality = "normal" })
    insert(player, { name = "fast-transport-belt", count = 2, quality = "normal" })
    insert(player, { name = "wooden-chest", count = 2, quality = "normal" })
    insert(player, { name = "assembling-machine-2", count = 1, quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    insert(player, { name = "stone-brick", count = 16, quality = "normal" })
    run.context.surface_name = surface.name
end

function use_spiderbot_capsule(run)
    local player = require_player(run)
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    local position = position_near_player(run, 3, 0)
    prepare_buildable_ground(player.surface, position, 4)
    player.use_from_cursor(position)
end

function deploy_complete(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    if not spiderbot_data then return false end
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = spiderbot_data.spiderbot
    return spiderbot.valid
        and spiderbot.follow_target == character
        and spiderbot_data.status == "idle"
        and spiderbot.quality.name == "normal"
        and shortcut_toggled(player) == true
end

function change_player_color(run)
    local player = require_player(run)
    run.context.original_player_color = player.color
    run.context.expected_player_color = { r = 0.2, g = 0.8, b = 0.35 }
    player.color = run.context.expected_player_color
end

function player_color_sync_complete(run)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot
        and spiderbot.valid
        and colors_match(spiderbot.color, run.context.expected_player_color)
        and all_spiderbots_idle(run.player_index)
end

function create_assigned_task_color_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 22, 22)
    prepare_buildable_ground(surface, position, 3)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.assigned_color_ghost = ghost
    run.context.assigned_task_color = { r = 0.5, g = 0.5, b = 1, a = 1 }
    run.context.assigned_new_player_color = { r = 0.95, g = 0.15, b = 0.2, a = 1 }
    mark_expected_task(run, "build_ghost")
end

function assigned_task_color_task_started(run)
    local player = require_player(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    local ghost = run.context.assigned_color_ghost
    local assigned = spiderbot
        and spiderbot.valid
        and ghost
        and ghost.valid
        and spiderbot_data.status == "task_assigned"
        and spiderbot_data.task
        and spiderbot_data.task.task_type == "build_ghost"
        and spiderbot_data.task.entity == ghost
        and colors_match(spiderbot.color, run.context.assigned_task_color)
    if not assigned then return false end
    storage.previous_player_color = storage.previous_player_color or {}
    storage.previous_player_color[player.index] = player.color
    player.color = run.context.assigned_new_player_color
    run.context.assigned_color_started_tick = game.tick
    return true
end

function assigned_task_color_preserved(run)
    if game.tick - run.context.assigned_color_started_tick < 20 then return false end
    local player = require_player(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    local ghost = run.context.assigned_color_ghost
    local preserved = spiderbot
        and spiderbot.valid
        and colors_match(spiderbot.color, run.context.assigned_task_color)
        and colors_match(player.color, run.context.assigned_new_player_color)
        and spiderbot_data.status == "task_assigned"
        and spiderbot_data.task
        and spiderbot_data.task.entity == ghost
    if preserved then
        if ghost and ghost.valid then
            ghost.destroy({ raise_destroy = true })
        end
        spiderbot_data.task = nil
        spiderbot_data.status = "idle"
        spiderbot_data.path_request_id = nil
        spiderbot.autopilot_destination = nil
        spiderbot.color = player.color
        spiderbot.follow_target = require_character(player)
        run.context.assigned_color_ghost = nil
    end
    return preserved
end

function show_cursor_visualization_for_item(run, item_name)
    local player = require_player(run)
    storage.spiderbots_enabled[run.player_index] = true
    clear_player_cursor_stack(player)
    run.context.previous_show_entity_info = player.game_view_settings.show_entity_info
    player.game_view_settings.show_entity_info = true
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = item_name })
    call_registered_handler(defines.events.on_player_cursor_stack_changed, { player_index = player.index })
end

function show_cursor_visualization(run)
    show_cursor_visualization_for_item(run, "deconstruction-planner")
end

function show_upgrade_cursor_visualization(run)
    show_cursor_visualization_for_item(run, "upgrade-planner")
end

function show_blueprint_cursor_visualization(run)
    show_cursor_visualization_for_item(run, "blueprint")
end

function show_blueprint_book_cursor_visualization(run)
    show_cursor_visualization_for_item(run, "blueprint-book")
end

function cursor_visualization_complete(run)
    local player = require_player(run)
    local render_objects = storage.render_objects and storage.render_objects[run.player_index]
    if not render_objects then return false end
    for _, render_object in pairs(render_objects) do
        if render_object.valid and player.game_view_settings.show_entity_info == true then
            return true
        end
    end
    return false
end

function disable_cursor_visualization(run)
    local player = require_player(run)
    storage.spiderbots_enabled[run.player_index] = false
    call_registered_handler(defines.events.on_player_cursor_stack_changed, { player_index = player.index })
end

function clear_cursor_visualization(run)
    local player = require_player(run)
    run.context.cursor_visualization_clear_result = clear_player_cursor_stack(player)
    call_registered_handler(defines.events.on_player_cursor_stack_changed, { player_index = player.index })
    storage.spiderbots_enabled[run.player_index] = true
    if run.context.previous_show_entity_info ~= nil then
        player.game_view_settings.show_entity_info = run.context.previous_show_entity_info
    end
end

function cursor_visualization_cleared(run)
    local player = require_player(run)
    local render_objects = storage.render_objects and storage.render_objects[run.player_index]
    local valid_count = 0
    local cursor_stack = player.cursor_stack
    if not render_objects then
        run.context.cursor_visualization_state = {
            enabled = storage.spiderbots_enabled and storage.spiderbots_enabled[run.player_index] or false,
            cursor_name = cursor_stack and cursor_stack.valid_for_read and cursor_stack.name or nil,
            render_object_count = 0,
        }
        return true
    end
    for _, render_object in pairs(render_objects) do
        if render_object.valid then
            valid_count = valid_count + 1
        end
    end
    run.context.cursor_visualization_state = {
        enabled = storage.spiderbots_enabled and storage.spiderbots_enabled[run.player_index] or false,
        cursor_name = cursor_stack and cursor_stack.valid_for_read and cursor_stack.name or nil,
        render_object_count = valid_count,
    }
    return valid_count == 0
end

function enter_test_vehicle(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 2, 6)
    prepare_buildable_ground(surface, position, 3)
    local car = surface.create_entity {
        name = "car",
        position = position,
        force = player.force,
    }
    if not car then error("failed to create car") end
    run.context.vehicle = car
    car.set_driver(player)
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = car,
    })
end

function vehicle_follow_complete(run)
    local car = run.context.vehicle
    local spiderbot = first_spiderbot(run.player_index)
    return car
        and car.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == car
        and all_spiderbots_idle(run.player_index)
end

function destroy_followed_vehicle(run)
    local player = require_player(run)
    local character = require_character(player)
    local car = run.context.vehicle
    local spiderbot = first_spiderbot(run.player_index)
    if not (car and car.valid and spiderbot and spiderbot.valid) then
        error("missing followed vehicle for destruction relink")
    end
    run.context.destroyed_vehicle_character = character
    run.context.destroyed_vehicle_spiderbot_unit_number = spiderbot.unit_number
    local ok = pcall(function()
        car.destroy({ raise_destroy = true })
    end)
    if not ok and car.valid then
        car.set_driver(nil)
        car.destroy({ raise_destroy = true })
    end
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = car,
    })
end

function destroyed_followed_vehicle_relinked(run)
    local player = require_player(run)
    local character = run.context.destroyed_vehicle_character
    local car = run.context.vehicle
    local spiderbot = first_spiderbot(run.player_index)
    return character
        and character.valid
        and (not car or not car.valid)
        and player.physical_vehicle == nil
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.destroyed_vehicle_spiderbot_unit_number
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function exit_test_vehicle(run)
    local player = require_player(run)
    local car = run.context.vehicle
    if car and car.valid then
        car.set_driver(nil)
    end
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = car,
    })
    if car and car.valid then
        car.destroy({ raise_destroy = true })
    end
end

function character_follow_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function create_build_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 6, 0)
    run.context.build_ghost_position = position
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not ghost then error("failed to create small-electric-pole ghost") end
    mark_expected_task(run, "build_ghost")
end

function build_ghost_complete(run)
    return expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.build_ghost_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_upgrade_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 9, 0)
    run.context.upgrade_position = position
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create transport-belt") end
    local ok = belt.order_upgrade {
        target = { name = "fast-transport-belt", quality = "normal" },
        force = player.force,
        player = player,
    }
    if not ok then error("failed to order transport-belt upgrade") end
    mark_expected_task(run, "upgrade_entity")
end

function upgrade_complete(run)
    return expected_task_was_seen(run)
        and find_entity_near("fast-transport-belt", run.context.upgrade_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_underground_belt_upgrade_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("underground-belt")
    require_entity_prototype("fast-underground-belt")
    require_item_prototype("fast-underground-belt")
    insert(player, { name = "fast-underground-belt", count = 1, quality = "normal" })
    local position = position_near_player(run, 9, 3)
    run.context.underground_upgrade_position = position
    prepare_buildable_ground(surface, position, 3)
    local belt = surface.create_entity {
        name = "underground-belt",
        position = position,
        direction = defines.direction.east,
        type = "output",
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create underground-belt") end
    local ok = belt.order_upgrade {
        target = { name = "fast-underground-belt", quality = "normal" },
        force = player.force,
        player = player,
    }
    if not ok then error("failed to order underground-belt upgrade") end
    mark_expected_task(run, "upgrade_entity")
end

function underground_belt_upgrade_complete(run)
    local entity = find_entity_near("fast-underground-belt", run.context.underground_upgrade_position, nil, run.context.surface_name)
    return expected_task_was_seen(run)
        and entity
        and entity.valid
        and entity.type == "underground-belt"
        and entity.belt_to_ground_type == "output"
        and all_spiderbots_idle(run.player_index)
end

function create_loader_upgrade_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("loader")
    local position = position_near_player(run, 11, 3)
    run.context.loader_upgrade_position = position
    run.context.loader_upgrade_skipped = nil
    run.context.loader_upgrade_target_name = nil
    prepare_buildable_ground(surface, position, 3)
    local loader = surface.create_entity {
        name = "loader",
        position = position,
        direction = defines.direction.east,
        type = "output",
        force = player.force,
        quality = "normal",
    }
    if not loader then error("failed to create loader") end
    local upgrade_target = loader.prototype and loader.prototype.next_upgrade
    local target_items = upgrade_target and upgrade_target.items_to_place_this
    local target_item = target_items and target_items[1]
    if not (upgrade_target and target_item) then
        run.context.loader_upgrade_skipped = true
        loader.destroy({ raise_destroy = true })
        return
    end
    insert(player, { name = target_item.name, count = target_item.count or 1, quality = "normal" })
    run.context.loader_upgrade_target_name = upgrade_target.name
    run.context.loader_upgrade_type = loader.loader_type
    local ok = loader.order_upgrade {
        target = { name = upgrade_target.name, quality = "normal" },
        force = player.force,
        player = player,
    }
    if not ok then error("failed to order loader upgrade") end
    mark_expected_task(run, "upgrade_entity")
end

function loader_upgrade_complete(run)
    if run.context.loader_upgrade_skipped then
        run.context.loader_upgrade_skipped = nil
        return true
    end
    local entity = find_entity_near(run.context.loader_upgrade_target_name, run.context.loader_upgrade_position, nil, run.context.surface_name)
    return expected_task_was_seen(run)
        and entity
        and entity.valid
        and entity.type == "loader"
        and entity.loader_type == run.context.loader_upgrade_type
        and all_spiderbots_idle(run.player_index)
end

function create_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 12, 0)
    local player_inventory = require_inventory(player)
    run.context.deconstruct_position = position
    run.context.deconstruct_chest_start_count = player_inventory.get_item_count({ name = "wooden-chest", quality = "normal" })
    run.context.deconstruct_content_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create wooden-chest") end
    local inventory = chest.get_inventory(defines.inventory.chest)
    if inventory and inventory.valid then
        inventory.insert({ name = "iron-plate", count = 1, quality = "normal" })
    end
    local ok = chest.order_deconstruction(player.force, player)
    if not ok then error("failed to order wooden-chest deconstruction") end
    mark_expected_task(run, "deconstruct_entity")
end

function deconstruction_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("wooden-chest", run.context.deconstruct_position, nil, run.context.surface_name) == nil
        and player_inventory.get_item_count({ name = "wooden-chest", quality = "normal" }) > run.context.deconstruct_chest_start_count
        and player_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) > run.context.deconstruct_content_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_tree_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local position = position_near_player(run, 6, -4)
    local tree_name = tree_prototype_with_item_product()
    local product = first_item_product_for_entity_prototype(tree_name)
    if not product then error("tree product disappeared for " .. tree_name) end
    run.context.tree_deconstruct_position = position
    run.context.tree_deconstruct_name = tree_name
    run.context.tree_deconstruct_product_name = product.name
    run.context.tree_deconstruct_product_start_count = inventory.get_item_count({
        name = product.name,
        quality = "normal",
    })
    set_square_tiles(surface, position, 2, natural_ground_tile_name())
    local tree = surface.create_entity {
        name = tree_name,
        position = position,
        force = game.forces.neutral,
    }
    if not tree then error("failed to create tree for deconstruction") end
    if not tree.order_deconstruction(player.force, player) then
        error("failed to order tree deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function tree_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local product_name = run.context.tree_deconstruct_product_name
    return expected_task_was_seen(run)
        and find_entity_near(run.context.tree_deconstruct_name, run.context.tree_deconstruct_position, nil, run.context.surface_name) == nil
        and product_name
        and inventory.get_item_count({ name = product_name, quality = "normal" }) > run.context.tree_deconstruct_product_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_rock_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local position = position_near_player(run, 9, -4)
    local rock_name = rock_prototype_with_item_product()
    local product = first_item_product_for_entity_prototype(rock_name)
    if not product then error("rock product disappeared for " .. rock_name) end
    run.context.rock_deconstruct_position = position
    run.context.rock_deconstruct_name = rock_name
    run.context.rock_deconstruct_product_name = product.name
    run.context.rock_deconstruct_product_start_count = inventory.get_item_count({
        name = product.name,
        quality = "normal",
    })
    set_square_tiles(surface, position, 3, natural_ground_tile_name())
    local rock = surface.create_entity {
        name = rock_name,
        position = position,
        force = game.forces.neutral,
    }
    if not rock then error("failed to create rock for deconstruction") end
    if not rock.order_deconstruction(player.force, player) then
        error("failed to order rock deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function rock_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local product_name = run.context.rock_deconstruct_product_name
    return expected_task_was_seen(run)
        and find_entity_near(run.context.rock_deconstruct_name, run.context.rock_deconstruct_position, 3, run.context.surface_name) == nil
        and product_name
        and inventory.get_item_count({ name = product_name, quality = "normal" }) > run.context.rock_deconstruct_product_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_vehicle_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local player_inventory = require_inventory(player)
    require_entity_prototype("car")
    require_item_prototype("car")
    local position = position_near_player(run, 12, -3)
    run.context.vehicle_contents_deconstruct_position = position
    run.context.vehicle_contents_deconstruct_car_start_count = player_inventory.get_item_count({ name = "car", quality = "normal" })
    run.context.vehicle_contents_deconstruct_content_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 3)
    local car = surface.create_entity {
        name = "car",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not car then error("failed to create car with trunk contents") end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local inserted = trunk.insert({ name = "iron-plate", count = 2, quality = "normal" })
    if inserted < 2 then error("failed to seed car trunk contents") end
    run.context.vehicle_contents_deconstruct_inserted_count = inserted
    if not car.order_deconstruction(player.force, player) then
        error("failed to order car with trunk contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function vehicle_contents_deconstruction_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("car", run.context.vehicle_contents_deconstruct_position, 2, run.context.surface_name) == nil
        and player_inventory.get_item_count({ name = "car", quality = "normal" }) > run.context.vehicle_contents_deconstruct_car_start_count
        and player_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.vehicle_contents_deconstruct_content_start_count + run.context.vehicle_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_spider_vehicle_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local player_inventory = require_inventory(player)
    require_entity_prototype("spidertron")
    require_item_prototype("spidertron")
    local position = position_near_player(run, 12, -6)
    run.context.spider_vehicle_contents_deconstruct_position = position
    run.context.spider_vehicle_contents_deconstruct_vehicle_start_count = player_inventory.get_item_count({ name = "spidertron", quality = "normal" })
    run.context.spider_vehicle_contents_deconstruct_content_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 5)
    local spidertron = surface.create_entity {
        name = "spidertron",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not spidertron then error("failed to create spidertron with trunk contents") end
    local trunk = require_inventory_from_entity(spidertron, defines.inventory.spider_trunk)
    local inserted = trunk.insert({ name = "iron-plate", count = 2, quality = "normal" })
    if inserted < 2 then error("failed to seed spidertron trunk contents") end
    run.context.spider_vehicle_contents_deconstruct_inserted_count = inserted
    if not spidertron.order_deconstruction(player.force, player) then
        error("failed to order spidertron with trunk contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function spider_vehicle_contents_deconstruction_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("spidertron", run.context.spider_vehicle_contents_deconstruct_position, 4, run.context.surface_name) == nil
        and player_inventory.get_item_count({ name = "spidertron", quality = "normal" }) > run.context.spider_vehicle_contents_deconstruct_vehicle_start_count
        and player_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.spider_vehicle_contents_deconstruct_content_start_count + run.context.spider_vehicle_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_item_entity_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local position = position_near_player(run, 13, 2)
    run.context.item_entity_deconstruct_position = position
    run.context.item_entity_deconstruct_start_count = inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local item = surface.create_entity {
        name = "item-on-ground",
        position = position,
        stack = { name = "iron-plate", count = 1, quality = "normal" },
    }
    if not item then error("failed to create item-on-ground for deconstruction") end
    if not item.order_deconstruction(player.force, player) then
        error("failed to order item-on-ground deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function item_entity_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_item_on_ground_near("iron-plate", run.context.item_entity_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "iron-plate", quality = "normal" }) > run.context.item_entity_deconstruct_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_belt_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local position = position_near_player(run, 16, 2)
    run.context.belt_contents_deconstruct_position = position
    run.context.belt_contents_deconstruct_start_count = inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create transport-belt with contents") end
    local inserted = 0
    for i = 1, belt.get_max_transport_line_index() do
        local line = belt.get_transport_line(i)
        if line and line.valid then
            line.force_insert_at(0.1, { name = "iron-plate", count = 1, quality = "normal" })
            inserted = inserted + 1
        end
    end
    if inserted == 0 then error("failed to seed transport-belt line contents") end
    run.context.belt_contents_deconstruct_inserted_count = inserted
    if not belt.order_deconstruction(player.force, player) then
        error("failed to order transport-belt with contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function belt_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("transport-belt", run.context.belt_contents_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.belt_contents_deconstruct_start_count + run.context.belt_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_splitter_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    require_entity_prototype("splitter")
    local position = position_near_player(run, 16, 2)
    run.context.splitter_contents_deconstruct_position = position
    run.context.splitter_contents_deconstruct_start_count = inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 3)
    local splitter = surface.create_entity {
        name = "splitter",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not splitter then error("failed to create splitter with contents") end
    local inserted = 0
    for i = 1, splitter.get_max_transport_line_index() do
        local line = splitter.get_transport_line(i)
        if line and line.valid then
            line.force_insert_at(0.1, { name = "iron-plate", count = 1, quality = "normal" })
            inserted = inserted + 1
        end
    end
    if inserted == 0 then error("failed to seed splitter line contents") end
    run.context.splitter_contents_deconstruct_inserted_count = inserted
    if not splitter.order_deconstruction(player.force, player) then
        error("failed to order splitter with contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function splitter_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("splitter", run.context.splitter_contents_deconstruct_position, 2, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.splitter_contents_deconstruct_start_count + run.context.splitter_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_underground_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    require_entity_prototype("underground-belt")
    local position = position_near_player(run, 16, 2)
    run.context.underground_contents_deconstruct_position = position
    run.context.underground_contents_deconstruct_start_count = inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "underground-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
        type = "input",
    }
    if not belt then error("failed to create underground-belt with contents") end
    local inserted = 0
    for i = 1, belt.get_max_transport_line_index() do
        local line = belt.get_transport_line(i)
        if line and line.valid then
            line.force_insert_at(0.1, { name = "iron-plate", count = 1, quality = "normal" })
            inserted = inserted + 1
        end
    end
    if inserted == 0 then error("failed to seed underground-belt line contents") end
    run.context.underground_contents_deconstruct_inserted_count = inserted
    if not belt.order_deconstruction(player.force, player) then
        error("failed to order underground-belt with contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function underground_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("underground-belt", run.context.underground_contents_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.underground_contents_deconstruct_start_count + run.context.underground_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_loader_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    require_entity_prototype("loader")
    local position = position_near_player(run, 16, 2)
    run.context.loader_contents_deconstruct_position = position
    run.context.loader_contents_deconstruct_start_count = inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local loader = surface.create_entity {
        name = "loader",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
        type = "output",
    }
    if not loader then error("failed to create loader with contents") end
    local inserted = 0
    for i = 1, loader.get_max_transport_line_index() do
        local line = loader.get_transport_line(i)
        if line and line.valid then
            line.force_insert_at(0.1, { name = "iron-plate", count = 1, quality = "normal" })
            inserted = inserted + 1
        end
    end
    if inserted == 0 then error("failed to seed loader line contents") end
    run.context.loader_contents_deconstruct_inserted_count = inserted
    if not loader.order_deconstruction(player.force, player) then
        error("failed to order loader with contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function loader_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return expected_task_was_seen(run)
        and find_entity_near("loader", run.context.loader_contents_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.loader_contents_deconstruct_start_count + run.context.loader_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
end

function create_item_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 15, 0)
    run.context.item_request_position = position
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create assembling-machine-2") end
    run.context.item_request_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create item-request-proxy") end
    mark_expected_task(run, "insert_items")
end

function item_request_complete(run)
    local assembler = run.context.item_request_target
    if not (assembler and assembler.valid) then return false end
    local inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    return expected_task_was_seen(run)
        and inventory
        and inventory.valid
        and inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
end

function create_chest_inventory_insertion_proxy(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 17, 0)
    remove_from_main_inventory(player, { name = "copper-plate", quality = "normal" })
    insert(player, { name = "copper-plate", count = 1, quality = "normal" })
    run.context.chest_inventory_insertion_start_count = player_inventory.get_item_count({ name = "copper-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create chest inventory insertion target") end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    if not (chest_inventory and chest_inventory.valid) then
        error("missing chest inventory for non-module insertion proxy")
    end
    local occupied_stack = chest_inventory[1]
    local requested_stack = chest_inventory[2]
    if not (occupied_stack and occupied_stack.valid and requested_stack and requested_stack.valid) then
        error("chest inventory insertion proxy requires two chest slots")
    end
    occupied_stack.set_stack({ name = "iron-plate", count = 1, quality = "normal" })
    run.context.chest_inventory_insertion_target = chest
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = chest,
        modules = {
            {
                id = { name = "copper-plate", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.chest,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create chest inventory insertion proxy") end
    run.context.chest_inventory_insertion_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function chest_inventory_insertion_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local chest = run.context.chest_inventory_insertion_target
    if not (chest and chest.valid) then return false end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    local completed = expected_task_was_seen(run)
        and chest_inventory
        and chest_inventory.valid
        and chest_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) == 1
        and chest_inventory.get_item_count({ name = "copper-plate", quality = "normal" }) == 1
        and player_inventory.get_item_count({ name = "copper-plate", quality = "normal" }) < run.context.chest_inventory_insertion_start_count
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.chest_inventory_insertion_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        chest.destroy({ raise_destroy = true })
        remove_from_main_inventory(player, { name = "copper-plate", quality = "normal" })
        run.context.chest_inventory_insertion_proxy = nil
        run.context.chest_inventory_insertion_target = nil
    end
    return completed
end

function create_item_removal_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local player_inventory = require_inventory(player)
    local position = position_near_player(run, 15, 3)
    run.context.item_removal_position = position
    run.context.item_removal_start_count = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create assembling-machine-2 for item removal proxy") end
    run.context.item_removal_target = assembler
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing assembler module inventory for item removal proxy")
    end
    if module_inventory.insert({ name = "speed-module", count = 1, quality = "normal" }) < 1 then
        error("failed to seed assembler module inventory for item removal proxy")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create item-removal proxy") end
    mark_expected_task(run, "insert_items")
end

function item_removal_request_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.item_removal_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    return expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) > run.context.item_removal_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_chest_inventory_removal_proxy(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 16, 0)
    run.context.chest_inventory_removal_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create chest inventory removal target") end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    if not (chest_inventory and chest_inventory.valid) then
        error("missing chest inventory for non-module removal proxy")
    end
    if chest_inventory.insert({ name = "iron-plate", count = 1, quality = "normal" }) < 1 then
        error("failed to seed chest inventory removal item")
    end
    run.context.chest_inventory_removal_target = chest
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = chest,
        modules = {},
        removal_plan = {
            {
                id = { name = "iron-plate", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.chest,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create chest inventory removal proxy") end
    run.context.chest_inventory_removal_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function chest_inventory_removal_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local chest = run.context.chest_inventory_removal_target
    if not (chest and chest.valid) then return false end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    local completed = expected_task_was_seen(run)
        and chest_inventory
        and chest_inventory.valid
        and chest_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) > run.context.chest_inventory_removal_start_count
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.chest_inventory_removal_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        chest.destroy({ raise_destroy = true })
        run.context.chest_inventory_removal_proxy = nil
        run.context.chest_inventory_removal_target = nil
    end
    return completed
end

function create_bidirectional_item_request_proxy(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("efficiency-module")
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
    insert(player, { name = "efficiency-module", count = 1, quality = "normal" })
    run.context.bidirectional_item_proxy_start_speed = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    run.context.bidirectional_item_proxy_start_efficiency = player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" })
    local position = position_near_player(run, 19, 0)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create bidirectional item proxy assembler") end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing module inventory for bidirectional item proxy")
    end
    if module_inventory.insert({ name = "speed-module", count = 1, quality = "normal" }) < 1 then
        error("failed to seed bidirectional item proxy removal module")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "efficiency-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create bidirectional item-request-proxy") end
    run.context.bidirectional_item_proxy_target = assembler
    run.context.bidirectional_item_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function bidirectional_item_request_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.bidirectional_item_proxy_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local completed = expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and module_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == 1
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) > run.context.bidirectional_item_proxy_start_speed
        and player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) < run.context.bidirectional_item_proxy_start_efficiency
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.bidirectional_item_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
        remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
        run.context.bidirectional_item_proxy = nil
        run.context.bidirectional_item_proxy_target = nil
    end
    return completed
end

function create_multi_item_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 18, 3)
    run.context.multi_item_request_position = position
    insert(player, { name = "speed-module", count = 2, quality = "normal" })
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create multi-item request assembler") end
    run.context.multi_item_request_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create multi-item request proxy") end
    mark_expected_task(run, "insert_items")
end

function multi_item_request_complete(run)
    local assembler = run.context.multi_item_request_target
    if not (assembler and assembler.valid) then return false end
    local inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    return expected_task_was_seen(run)
        and inventory
        and inventory.valid
        and inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 2
        and all_spiderbots_idle(run.player_index)
end

function create_later_item_request_plan_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("efficiency-module")
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
    insert(player, { name = "efficiency-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 12, 8)
    run.context.later_item_request_plan_position = position
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create later-plan request assembler") end
    run.context.later_item_request_plan_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
            {
                id = { name = "efficiency-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create later-plan item request proxy") end
    run.context.later_item_request_plan_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function later_item_request_plan_complete(run)
    local assembler = run.context.later_item_request_plan_target
    if not (assembler and assembler.valid) then return false end
    local inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local completed = expected_task_was_seen(run)
        and inventory
        and inventory.valid
        and inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.later_item_request_plan_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        run.context.later_item_request_plan_proxy = nil
        run.context.later_item_request_plan_target = nil
    end
    return completed
end

function create_multi_item_removal_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local player_inventory = require_inventory(player)
    local position = position_near_player(run, 21, 3)
    run.context.multi_item_removal_position = position
    run.context.multi_item_removal_start_count = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create multi-item removal assembler") end
    run.context.multi_item_removal_target = assembler
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing assembler module inventory for multi-item removal proxy")
    end
    local first_module_stack = module_inventory[1]
    local second_module_stack = module_inventory[2]
    if not (first_module_stack and first_module_stack.valid and second_module_stack and second_module_stack.valid) then
        error("multi-item removal proxy requires two module slots")
    end
    first_module_stack.set_stack({ name = "speed-module", count = 1, quality = "normal" })
    second_module_stack.set_stack({ name = "speed-module", count = 1, quality = "normal" })
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create multi-item removal proxy") end
    mark_expected_task(run, "insert_items")
end

function multi_item_removal_request_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.multi_item_removal_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    return expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= run.context.multi_item_removal_start_count + 2
        and all_spiderbots_idle(run.player_index)
end

function create_later_item_removal_plan_proxy(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("efficiency-module")
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
    local efficiency_stack_size = prototypes.item["efficiency-module"].stack_size or 50
    if efficiency_stack_size < 2 then
        error("later-plan removal test requires stackable efficiency modules")
    end
    run.context.later_removal_filler_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    insert(player, { name = "efficiency-module", count = efficiency_stack_size - 1, quality = "normal" })
    run.context.later_removal_start_efficiency = player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" })
    fill_inventory_until_cannot_insert(
        player_inventory,
        { name = "iron-plate", count = 100, quality = "normal" },
        { name = "speed-module", count = 1, quality = "normal" }
    )
    local position = position_near_player(run, 16, 8)
    run.context.later_item_removal_plan_position = position
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create later-plan removal assembler") end
    run.context.later_item_removal_plan_target = assembler
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing assembler module inventory for later-plan removal proxy")
    end
    local first_module_stack = module_inventory[1]
    local second_module_stack = module_inventory[2]
    if not (first_module_stack and first_module_stack.valid and second_module_stack and second_module_stack.valid) then
        error("later-plan removal proxy requires two module slots")
    end
    first_module_stack.set_stack({ name = "speed-module", count = 1, quality = "normal" })
    second_module_stack.set_stack({ name = "efficiency-module", count = 1, quality = "normal" })
    if player_inventory.can_insert({ name = "speed-module", count = 1, quality = "normal" }) then
        error("later-plan removal test failed to block speed-module inventory space")
    end
    if not player_inventory.can_insert({ name = "efficiency-module", count = 1, quality = "normal" }) then
        error("later-plan removal test failed to free efficiency-module inventory space")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
            {
                id = { name = "efficiency-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 1,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create later-plan item removal proxy") end
    run.context.later_item_removal_plan_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function later_item_removal_plan_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.later_item_removal_plan_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local completed = expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 1
        and module_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) > run.context.later_removal_start_efficiency
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.later_item_removal_plan_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        local filler_start_count = run.context.later_removal_filler_start_count or 0
        local filler_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
        if filler_count > filler_start_count then
            player_inventory.remove({ name = "iron-plate", count = filler_count - filler_start_count, quality = "normal" })
        end
        remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
        run.context.later_item_removal_plan_proxy = nil
        run.context.later_item_removal_plan_target = nil
    end
    return completed
end

function create_tile_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 18, 0)
    run.context.tile_position = position
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not ghost then error("failed to create stone-path tile ghost") end
    mark_expected_task(run, "build_tile")
end

function tile_build_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local tile = surface.get_tile(run.context.tile_position.x, run.context.tile_position.y)
    return expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name == "stone-path"
        and all_spiderbots_idle(run.player_index)
end

function create_tile_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    run.context.tile_deconstruction_start_count = inventory.get_item_count({ name = "stone-brick", quality = "normal" })
    local tile = surface.get_tile(run.context.tile_position.x, run.context.tile_position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("stone-path tile was not available for deconstruction")
    end
    local proxy = tile.order_deconstruction(player.force, player)
    if not proxy then error("failed to order tile deconstruction") end
    mark_expected_task(run, "deconstruct_tile")
end

function tile_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local tile = surface.get_tile(run.context.tile_position.x, run.context.tile_position.y)
    return expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and inventory.get_item_count({ name = "stone-brick", quality = "normal" }) > run.context.tile_deconstruction_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_multiple_tile_ghosts(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local base = position_near_player(run, 18, 2)
    run.context.multi_tile_positions = {
        p(base.x, base.y),
        p(base.x + 1, base.y),
        p(base.x + 2, base.y),
    }
    prepare_buildable_ground(surface, p(base.x + 1, base.y), 3)
    insert(player, { name = "stone-brick", count = 3, quality = "normal" })
    for _, position in pairs(run.context.multi_tile_positions) do
        local ghost = surface.create_entity {
            name = "tile-ghost",
            inner_name = "stone-path",
            position = position,
            force = player.force,
        }
        if not ghost then error("failed to create multi tile ghost") end
    end
    mark_expected_task(run, "build_tile")
end

function multiple_tile_ghosts_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    if not expected_task_was_seen(run) then return false end
    for _, position in pairs(run.context.multi_tile_positions or {}) do
        local tile = surface.get_tile(position.x, position.y)
        if not (tile and tile.valid and tile.name == "stone-path") then
            return false
        end
    end
    return all_spiderbots_idle(run.player_index)
end

function create_assigned_tile_deconstruction_no_space_order(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.multi_tile_positions and run.context.multi_tile_positions[1]
    if not position then error("missing multi-tile position for assigned tile no-space test") end
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("assigned tile no-space test requires built stone-path")
    end
    if not tile.hidden_tile then
        error("assigned tile no-space test requires a hidden tile")
    end
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    run.context.assigned_tile_no_space_filler_item_name = "iron-plate"
    run.context.assigned_tile_no_space_filler_start_count = inventory.get_item_count({ name = run.context.assigned_tile_no_space_filler_item_name, quality = "normal" })
    run.context.assigned_tile_no_space_stone_start_count = inventory.get_item_count({ name = "stone-brick", quality = "normal" })
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order assigned tile no-space deconstruction")
    end
    run.context.assigned_tile_no_space_position = position
    mark_expected_task(run, "deconstruct_tile")
end

function trigger_full_inventory_assigned_tile_deconstruction_noop(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.assigned_tile_no_space_position
    local tile = position and surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("missing assigned tile no-space target")
    end
    local spiderbot_data = assigned_task_for_target(run, "deconstruct_tile", tile)
    if not spiderbot_data then return false end
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.assigned_tile_no_space_filler_item_name, count = 100, quality = "normal" },
        { name = "stone-brick", count = 1, quality = "normal" }
    )
    return complete_assigned_task_now(spiderbot_data)
end

function full_inventory_assigned_tile_deconstruction_noop_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.assigned_tile_no_space_position
    local tile = position and surface.get_tile(position.x, position.y)
    local item = position and find_item_on_ground_near("stone-brick", position, 2, run.context.surface_name)
    local complete = tile
        and tile.valid
        and tile.name == "stone-path"
        and inventory.get_item_count({ name = "stone-brick", quality = "normal" }) == run.context.assigned_tile_no_space_stone_start_count
        and item == nil
        and first_spiderbot_idle_without_task(run)
    if complete then
        if tile.to_be_deconstructed() then
            tile.cancel_deconstruction(player.force, player)
        end
        local filler_item_name = run.context.assigned_tile_no_space_filler_item_name or "iron-plate"
        local start_count = run.context.assigned_tile_no_space_filler_start_count or 0
        local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
        if current_count > start_count then
            inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
        end
        run.context.assigned_tile_no_space_position = nil
    end
    return complete
end

function create_stacked_tile_ghosts(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 21, 2)
    run.context.stacked_tile_position = position
    require_tile_prototype("water")
    require_tile_prototype("landfill")
    require_tile_prototype("stone-path")
    require_item_prototype("landfill")
    require_item_prototype("stone-brick")
    prepare_buildable_ground(surface, position, 3)
    set_square_tiles(surface, position, 0, "water")
    insert(player, { name = "landfill", count = 1, quality = "normal" })
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    local foundation_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "landfill",
        position = position,
        force = player.force,
    }
    if not foundation_ghost then error("failed to create stacked landfill tile ghost") end
    local top_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not top_ghost then error("failed to create stacked stone-path tile ghost") end
    mark_expected_task(run, "build_tile")
end

function stacked_tile_ghosts_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.stacked_tile_position
    local tile = surface.get_tile(position.x, position.y)
    local ghosts = tile and tile.valid and tile.get_tile_ghosts()
    return expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name == "stone-path"
        and (not ghosts or #ghosts == 0)
        and all_spiderbots_idle(run.player_index)
end

function create_tile_ghost_on_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 20, 6)
    run.context.tile_deconstruction_ghost_position = position
    require_tile_prototype("stone-path")
    require_tile_prototype("concrete")
    require_item_prototype("concrete")
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to prepare tile deconstruction plus ghost target")
    end
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order tile deconstruction before tile ghost")
    end
    insert(player, { name = "concrete", count = 1, quality = "normal" })
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "concrete",
        position = position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create tile ghost over deconstruction order") end
    mark_expected_tasks(run, { "deconstruct_tile", "build_tile" })
end

function tile_ghost_on_deconstruction_order_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.tile_deconstruction_ghost_position
    local tile = surface.get_tile(position.x, position.y)
    local ghosts = tile and tile.valid and tile.get_tile_ghosts()
    return expected_tasks_were_seen(run)
        and tile
        and tile.valid
        and tile.name == "concrete"
        and (not ghosts or #ghosts == 0)
        and all_spiderbots_idle(run.player_index)
end

function create_entity_ghost_on_landfill_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 6, 5)
    run.context.combo_landfill_position = position
    require_tile_prototype("water")
    require_tile_prototype("landfill")
    require_item_prototype("landfill")
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "water")
    insert(player, { name = "landfill", count = 1, quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "landfill",
        position = position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create landfill tile ghost") end
    create_small_pole_ghost(surface, player, position)
    mark_expected_tasks(run, { "build_tile", "build_ghost" })
end

function entity_ghost_on_landfill_ghost_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.combo_landfill_position
    local tile = surface.get_tile(position.x, position.y)
    return expected_tasks_were_seen(run)
        and tile
        and tile.valid
        and tile.name == "landfill"
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_entity_ghost_on_tile_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 9, 5)
    run.context.combo_tile_position = position
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create stone-path tile ghost under entity ghost") end
    create_small_pole_ghost(surface, player, position)
    mark_expected_tasks(run, { "build_ghost", "build_tile" })
end

function entity_ghost_on_tile_ghost_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.combo_tile_position
    local tile = surface.get_tile(position.x, position.y)
    return expected_tasks_were_seen(run)
        and tile
        and tile.valid
        and tile.name == "stone-path"
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_entity_ghost_on_deconstruction_target(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 12, 5)
    run.context.combo_deconstruct_position = position
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create wooden-chest deconstruction blocker") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order wooden-chest blocker deconstruction")
    end
    create_small_pole_ghost(surface, player, position)
    mark_expected_tasks(run, { "deconstruct_entity", "build_ghost" })
end

function entity_ghost_on_deconstruction_target_complete(run)
    local position = run.context.combo_deconstruct_position
    return expected_tasks_were_seen(run)
        and find_entity_near("wooden-chest", position, nil, run.context.surface_name) == nil
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_entity_ghost_on_tree_deconstruction(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 15, 5)
    local tree_name = tree_prototype_name()
    run.context.combo_tree_position = position
    run.context.combo_tree_name = tree_name
    set_square_tiles(surface, position, 2, natural_ground_tile_name())
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local tree = surface.create_entity {
        name = tree_name,
        position = position,
        force = game.forces.neutral,
    }
    if not tree then error("failed to create tree deconstruction blocker") end
    if not tree.order_deconstruction(player.force, player) then
        error("failed to order tree blocker deconstruction")
    end
    create_small_pole_ghost(surface, player, position)
    mark_expected_tasks(run, { "deconstruct_entity", "build_ghost" })
end

function entity_ghost_on_tree_deconstruction_complete(run)
    local position = run.context.combo_tree_position
    return expected_tasks_were_seen(run)
        and find_entity_near(run.context.combo_tree_name, position, nil, run.context.surface_name) == nil
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_entity_ghost_on_cliff_deconstruction(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 18, 5)
    run.context.combo_cliff_position = position
    storage.cliffs_to_be_exploded = {}
    set_square_tiles(surface, position, 4, natural_ground_tile_name())
    insert(player, { name = "cliff-explosives", count = 2, quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local cliff = surface.create_entity {
        name = "cliff",
        position = position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not cliff then error("failed to create cliff deconstruction blocker") end
    run.context.combo_cliff_position = cliff.position
    local ghost_position = cliff_blocked_small_pole_position(surface, cliff, player.force)
    if not cliff.order_deconstruction(player.force, player) then
        error("failed to order cliff blocker deconstruction")
    end
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    run.context.combo_cliff_ghost_position = ghost.position
    mark_expected_tasks(run, { "deconstruct_entity", "build_ghost" })
end

function entity_ghost_on_cliff_deconstruction_complete(run)
    local cliff_position = run.context.combo_cliff_position
    local ghost_position = run.context.combo_cliff_ghost_position or cliff_position
    return expected_tasks_were_seen(run)
        and #find_entities_near({ type = "cliff" }, cliff_position, 4, run.context.surface_name) == 0
        and find_entity_near("small-electric-pole", ghost_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_foundation_priority_tasks(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("water")
    require_tile_prototype("landfill")
    require_item_prototype("landfill")
    run.context.foundation_priority_positions = {}
    local foundation_priority_offsets = {
        p(-8, -8),
        p(0, -8),
        p(8, -8),
        p(-8, 0),
        p(1, 0),
        p(8, 0),
        p(-8, 8),
        p(0, 8),
        p(8, 8),
    }
    for _, offset in ipairs(foundation_priority_offsets) do
        table.insert(run.context.foundation_priority_positions, position_near_player(run, offset.x, offset.y))
    end
    run.context.foundation_priority_deconstruct_position = position_near_player(run, 20, 0)
    prepare_buildable_ground(surface, run.context.foundation_priority_deconstruct_position, 2)
    insert(player, { name = "landfill", count = #run.context.foundation_priority_positions, quality = "normal" })
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = run.context.foundation_priority_deconstruct_position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create foundation-priority deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order foundation-priority chest deconstruction")
    end
    for _, position in pairs(run.context.foundation_priority_positions) do
        set_square_tiles(surface, position, 0, "water")
        local ghost = surface.create_entity {
            name = "tile-ghost",
            inner_name = "landfill",
            position = position,
            force = player.force,
        }
        if not ghost then error("failed to create foundation-priority landfill ghost") end
    end
    mark_expected_tasks(run, { "build_tile", "deconstruct_entity" })
end

function foundation_priority_tasks_complete(run)
    if run.context.first_seen_task and run.context.first_seen_task ~= "build_tile" then
        error("foundation tile task did not win priority; first task was " .. tostring(run.context.first_seen_task))
    end
    if not expected_tasks_were_seen(run) then return false end
    local surface = game.surfaces[run.context.surface_name]
    for _, position in pairs(run.context.foundation_priority_positions or {}) do
        local tile = surface.get_tile(position.x, position.y)
        if not (tile and tile.valid and tile.name == "landfill") then
            return false
        end
    end
    return find_entity_near("wooden-chest", run.context.foundation_priority_deconstruct_position, nil, run.context.surface_name) == nil
        and all_spiderbots_idle(run.player_index)
end

function trigger_teleport_redeploy(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for teleport redeploy")
    end
    run.context.teleport_old_unit_number = spiderbot.unit_number
    run.context.teleport_target = p(30, 8)
    local old_position = character.position
    local old_surface_index = character.surface.index
    if not player.teleport(run.context.teleport_target, surface) then
        error("failed to teleport player for redeploy test")
    end
    character = require_character(player)
    call_registered_handler(defines.events.script_raised_teleported, {
        entity = character,
        old_position = old_position,
        old_surface_index = old_surface_index,
    })
end

function teleport_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.teleport_old_unit_number
        and spiderbot.follow_target == character
        and spiderbot.surface == character.surface
        and distance(spiderbot.position, character.position) < 75
        and all_spiderbots_idle(run.player_index)
end

function trigger_idle_far_range_redeploy(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for idle far-range redeploy")
    end
    local surface = character.surface
    local far_position = p(character.position.x + 70, character.position.y)
    surface.request_to_generate_chunks(far_position, 4)
    surface.force_generate_chunk_requests()
    prepare_buildable_ground(surface, far_position, 8)
    run.context.idle_far_range_old_unit_number = spiderbot.unit_number
    spiderbot_data.task = nil
    spiderbot_data.status = "idle"
    spiderbot_data.path_request_id = nil
    spiderbot.autopilot_destination = nil
    if not spiderbot.teleport(far_position, surface, true) then
        error("failed to move spiderbot for idle far-range redeploy")
    end
end

function idle_far_range_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.idle_far_range_old_unit_number
        and spiderbot.follow_target == character
        and spiderbot.surface == character.surface
        and distance(spiderbot.position, character.position) < 160
        and all_spiderbots_idle(run.player_index)
end

function trigger_stuck_jump(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for stuck jump test")
    end
    run.context.stuck_old_unit_number = spiderbot.unit_number
    spiderbot.autopilot_destination = nil
    spiderbot.teleport({ x = character.position.x + 2, y = character.position.y }, character.surface)
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = nil
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = "synthetic-stuck-task",
    }
end

function stuck_jump_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.stuck_old_unit_number
        and spiderbot.follow_target == character
        and spiderbot.quality.name == "normal"
        and all_spiderbots_idle(run.player_index)
end

function create_spider_leg_collision_ghost(surface, player, spiderbot, inner_name)
    local legs = spiderbot.get_spider_legs()
    for _, leg in pairs(legs or {}) do
        if leg and leg.valid then
            local candidates = {
                spiderbot.position,
                leg.position,
                p(leg.position.x - 0.25, leg.position.y),
                p(leg.position.x + 0.25, leg.position.y),
                p(leg.position.x, leg.position.y - 0.25),
                p(leg.position.x, leg.position.y + 0.25),
            }
            for _, position in pairs(candidates) do
                prepare_buildable_ground(surface, position, 5)
                local ghost = surface.create_entity {
                    name = "entity-ghost",
                    inner_name = inner_name,
                    position = position,
                    force = player.force,
                    quality = "normal",
                }
                if ghost then
                    local colliding_legs = surface.find_entities_filtered {
                        type = "spider-leg",
                        area = ghost.bounding_box,
                    }
                    if #colliding_legs > 0 then
                        return ghost, position, #colliding_legs
                    end
                    ghost.destroy({ raise_destroy = true })
                end
            end
        end
    end
    error("failed to create " .. inner_name .. " ghost overlapping a spiderbot leg")
end

function trigger_build_collision_free_stuck(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for collision stuck-free test")
    end
    local surface = character.surface
    spiderbot.teleport(p(character.position.x + 3, character.position.y), surface)
    local ghost_name = "assembling-machine-2"
    require_entity_prototype(ghost_name)
    require_item_prototype(ghost_name)
    local ghost, ghost_position, colliding_leg_count = create_spider_leg_collision_ghost(surface, player, spiderbot, ghost_name)
    run.context.collision_stuck_old_unit_number = spiderbot.unit_number
    run.context.collision_stuck_entity_name = ghost_name
    run.context.collision_stuck_ghost_position = ghost_position
    run.context.collision_stuck_initial_leg_count = colliding_leg_count
    insert(player, { name = ghost_name, count = 1, quality = "normal" })
    run.context.collision_stuck_ghost = ghost
    spiderbot.autopilot_destination = nil
    pcall(function()
        spiderbot.autopilot_destinations = {}
    end)
    run.context.collision_stuck_destination_count = #(spiderbot.autopilot_destinations or {})
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id_for_entity(ghost),
        entity = ghost,
        projectile_item = ghost_name,
    }
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = nil
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = spiderbot,
    })
end

function build_collision_free_stuck_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    run.context.collision_stuck_state = {
        spiderbot_count = spiderbot_count(run.player_index),
        old_unit_number = run.context.collision_stuck_old_unit_number,
        current_unit_number = spiderbot and spiderbot.valid and spiderbot.unit_number or nil,
        follow_target_is_character = spiderbot and spiderbot.valid and spiderbot.follow_target == character or false,
        status = spiderbot_data and spiderbot_data.status,
        projectile_count = projectiles and #projectiles or 0,
        initial_leg_count = run.context.collision_stuck_initial_leg_count,
    }
    local freed = spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.collision_stuck_old_unit_number
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
    if freed then
        cleanup_context_entity(run, "collision_stuck_ghost")
        local built_entity = find_entity_near(run.context.collision_stuck_entity_name, run.context.collision_stuck_ghost_position, 3, run.context.surface_name)
        if built_entity and built_entity.valid then
            built_entity.destroy({ raise_destroy = true })
        end
        remove_from_main_inventory(player, { name = run.context.collision_stuck_entity_name, quality = "normal" })
        run.context.collision_stuck_entity_name = nil
        run.context.collision_stuck_ghost_position = nil
    end
    return freed
end

function create_cliff_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "cliff-explosives", count = 2, quality = "normal" })
    local position = position_near_player(run, 6, 0)
    prepare_buildable_ground(surface, position, 4)
    local cliff = surface.create_entity {
        name = "cliff",
        position = position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not cliff then error("failed to create cliff") end
    run.context.cliff_position = cliff.position
    if not cliff.order_deconstruction(player.force, player) then
        error("failed to order cliff deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function cliff_deconstruction_complete(run)
    return expected_task_was_seen(run)
        and #find_entities_near({ type = "cliff" }, run.context.cliff_position, 4, run.context.surface_name) == 0
        and all_spiderbots_idle(run.player_index)
end

function create_quality_cliff_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    remove_all_qualities_from_main_inventory(player, "cliff-explosives")
    insert(player, { name = "cliff-explosives", count = 1, quality = quality })
    run.context.quality_cliff_explosive_start_count = inventory.get_item_count({ name = "cliff-explosives", quality = quality })
    local position = position_near_player(run, 8, 0)
    set_square_tiles(surface, position, 4, natural_ground_tile_name())
    local cliff = surface.create_entity {
        name = "cliff",
        position = position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not cliff then error("failed to create quality cliff") end
    run.context.quality_cliff_position = cliff.position
    if not cliff.order_deconstruction(player.force, player) then
        error("failed to order quality cliff deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function quality_cliff_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    return expected_task_was_seen(run)
        and #find_entities_near({ type = "cliff" }, run.context.quality_cliff_position, 4, run.context.surface_name) == 0
        and inventory.get_item_count({ name = "cliff-explosives", quality = quality }) < run.context.quality_cliff_explosive_start_count
        and all_spiderbots_idle(run.player_index)
end

function seed_cliff_reservations_for_cleanup(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local expired_position = position_near_player(run, 9, 2)
    local invalid_position = position_near_player(run, 11, 2)
    set_square_tiles(surface, expired_position, 4, natural_ground_tile_name())
    set_square_tiles(surface, invalid_position, 4, natural_ground_tile_name())
    local expired_cliff = surface.create_entity {
        name = "cliff",
        position = expired_position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not expired_cliff then error("failed to create expired cliff reservation target") end
    local invalid_cliff = surface.create_entity {
        name = "cliff",
        position = invalid_position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not invalid_cliff then error("failed to create invalid cliff reservation target") end
    run.context.cliff_cleanup_expired_cliff = expired_cliff
    storage.cliffs_to_be_exploded = {
        expired_test = {
            cliff = expired_cliff,
            tick = game.tick - (60 * 5) - 1,
        },
        invalid_test = {
            cliff = invalid_cliff,
            tick = game.tick,
        },
    }
    invalid_cliff.destroy({ raise_destroy = true })
end

function cliff_reservations_cleaned_up(run)
    local reservations = storage.cliffs_to_be_exploded or {}
    local expired_cliff = run.context.cliff_cleanup_expired_cliff
    local cleaned = reservations.expired_test == nil
        and reservations.invalid_test == nil
        and all_spiderbots_idle(run.player_index)
    if cleaned and expired_cliff and expired_cliff.valid then
        expired_cliff.destroy({ raise_destroy = true })
        run.context.cliff_cleanup_expired_cliff = nil
    end
    return cleaned
end

function recall_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
end

function recall_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) > (run.context.initial_spiderbot_inventory or 0)
end

function raise_follower_count_research(run)
    local player = require_player(run)
    clear_follower_count_research(player.force)
    local technology = player.force.technologies["spiderbot-follower-count-1"]
    if not technology then error("missing spiderbot-follower-count-1 technology") end
    storage.spiderbot_follower_count[player.force.name] = 10
    run.context.expected_research_follower_count = 20
    call_registered_handler(defines.events.on_research_finished, { research = technology })
end

function follower_count_research_complete(run)
    local player = require_player(run)
    run.context.actual_research_follower_count = storage.spiderbot_follower_count[player.force.name]
    return run.context.actual_research_follower_count == run.context.expected_research_follower_count
end

function raise_technology_effects_reset(run)
    local player = require_player(run)
    clear_follower_count_research(player.force)
    local technology = player.force.technologies["spiderbot-follower-count-1"]
    if not technology then error("missing spiderbot-follower-count-1 technology") end
    technology.researched = true
    storage.spiderbot_follower_count[player.force.name] = 10
    run.context.expected_reset_follower_count = 20
    call_registered_handler(defines.events.on_technology_effects_reset, {})
end

function technology_effects_reset_complete(run)
    local player = require_player(run)
    run.context.actual_reset_follower_count = storage.spiderbot_follower_count[player.force.name]
    return run.context.actual_reset_follower_count == run.context.expected_reset_follower_count
end

function raise_highest_follower_count_reset(run)
    local player = require_player(run)
    clear_follower_count_research(player.force)
    local highest_count = 0
    for level = 1, 7 do
        local technology = player.force.technologies["spiderbot-follower-count-" .. level]
        if technology then
            research_follower_count_technology(technology)
            if technology.researched then
                highest_count = math.max(highest_count, follower_count_from_technology(technology) or 0)
            end
        end
    end
    if highest_count == 0 then
        error("missing spiderbot follower count technologies")
    end
    storage.spiderbot_follower_count[player.force.name] = 10
    run.context.expected_highest_reset_follower_count = highest_count
    call_registered_handler(defines.events.on_technology_effects_reset, {})
end

function highest_follower_count_reset_complete(run)
    local player = require_player(run)
    run.context.actual_highest_reset_follower_count = storage.spiderbot_follower_count[player.force.name]
    return run.context.actual_highest_reset_follower_count == run.context.expected_highest_reset_follower_count
end

function toggle_with_no_spiderbot_inventory(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    player.clear_cursor()
    run.context.empty_toggle_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function empty_inventory_toggle_noop_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local complete = storage.spiderbots_enabled[run.player_index] == true
        and shortcut_toggled(player) == true
        and spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) == run.context.empty_toggle_start_inventory
    if complete then
        storage.spiderbots_enabled[run.player_index] = false
        player.set_shortcut_toggled("toggle-spiderbots", false)
    end
    return complete
end

function toggle_deploy_respects_follower_limit(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    player.clear_cursor()
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 2
    run.context.toggle_start_spiderbot_count = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    insert(player, { name = "spiderbot", count = 4, quality = "normal" })
    run.context.toggle_expected_inventory = run.context.toggle_start_spiderbot_count + 2
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function toggle_deploy_limit_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 2
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) == run.context.toggle_expected_inventory
        and shortcut_toggled(player) == true
end

function toggle_deploy_limit_combines_character_and_vehicle(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 3
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 2, quality = "normal" })
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 3, 7)
    prepare_buildable_ground(surface, position, 4)
    local car = surface.create_entity {
        name = "car",
        position = position,
        force = player.force,
    }
    if not car then error("failed to create combined deploy-limit car") end
    run.context.combined_deploy_car = car
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    trunk.insert({ name = "spiderbot", count = 2, quality = "normal" })
    run.context.combined_deploy_character_start = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    run.context.combined_deploy_trunk_start = trunk.get_item_count({ name = "spiderbot", quality = "normal" })
    car.set_driver(player)
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = car,
    })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function combined_character_vehicle_deploy_limit_complete(run)
    local player = require_player(run)
    local car = run.context.combined_deploy_car
    if not (car and car.valid) then return false end
    local inventory = require_inventory(player)
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 3
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) == 0
        and trunk.get_item_count({ name = "spiderbot", quality = "normal" }) == 1
        and run.context.combined_deploy_character_start == 2
        and run.context.combined_deploy_trunk_start == 2
        and shortcut_toggled(player) == true
        and all_spiderbots_idle(run.player_index)
end

function combined_character_vehicle_deploy_recalled(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) >= 3
end

function cleanup_combined_character_vehicle_deploy_limit(run)
    local player = require_player(run)
    local car = run.context.combined_deploy_car
    if car and car.valid then
        local trunk = car.get_inventory(defines.inventory.car_trunk)
        if trunk and trunk.valid then
            local trunk_spiderbot_count = trunk.get_item_count({ name = "spiderbot", quality = "normal" })
            if trunk_spiderbot_count > 0 then
                trunk.remove({ name = "spiderbot", count = trunk_spiderbot_count, quality = "normal" })
            end
        end
        car.set_driver(nil)
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = car,
        })
        car.destroy({ raise_destroy = true })
    end
    run.context.combined_deploy_car = nil
    storage.spiderbots_enabled[run.player_index] = true
end

function toggle_deploys_mixed_quality_spiderbots(run)
    local player = require_player(run)
    local quality = quality_under_test(run)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 2
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    insert(player, { name = "spiderbot", count = 1, quality = quality })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function mixed_quality_toggle_deploy_complete(run)
    local quality = quality_under_test(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 2
        and spiderbot_count_by_quality(run.player_index, "normal") == 1
        and spiderbot_count_by_quality(run.player_index, quality) == 1
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = quality }) == 0
        and shortcut_toggled(player) == true
        and all_spiderbots_idle(run.player_index)
end

function recall_mixed_quality_toggle_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
end

function mixed_quality_toggle_recall_complete(run)
    local quality = quality_under_test(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) >= 1
        and inventory.get_item_count({ name = "spiderbot", quality = quality }) >= 1
end

function use_quality_spiderbot_capsule(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    local quality = quality_under_test(run)
    local inventory = require_inventory(player)
    run.context.quality_spiderbot_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = quality })
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = quality })
    local position = position_near_player(run, 3, 0)
    prepare_buildable_ground(player.surface, position, 4)
    player.use_from_cursor(position)
end

function quality_deploy_complete(run)
    local quality = quality_under_test(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = spiderbot_data_by_quality(run.player_index, quality)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and spiderbot_data.status == "idle"
end

function create_quality_build_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    local position = position_near_player(run, 5, 2)
    run.context.quality_build_ghost_position = position
    insert(player, { name = "small-electric-pole", count = 1, quality = quality })
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = quality,
    }
    if not ghost then error("failed to create uncommon small-electric-pole ghost") end
    mark_expected_task(run, "build_ghost")
end

function quality_build_ghost_complete(run)
    local quality = quality_under_test(run)
    local entity = find_entity_near("small-electric-pole", run.context.quality_build_ghost_position, nil, run.context.surface_name)
    return expected_task_was_seen(run)
        and entity
        and entity.valid
        and entity.quality.name == quality
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function create_quality_upgrade_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    local position = position_near_player(run, 8, 2)
    run.context.quality_upgrade_position = position
    insert(player, { name = "fast-transport-belt", count = 1, quality = quality })
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create transport-belt for quality upgrade") end
    local ok = belt.order_upgrade {
        target = { name = "fast-transport-belt", quality = quality },
        force = player.force,
        player = player,
    }
    if not ok then error("failed to order uncommon transport-belt upgrade") end
    mark_expected_task(run, "upgrade_entity")
end

function quality_upgrade_complete(run)
    local quality = quality_under_test(run)
    local entity = find_entity_near("fast-transport-belt", run.context.quality_upgrade_position, nil, run.context.surface_name)
    return expected_task_was_seen(run)
        and entity
        and entity.valid
        and entity.quality.name == quality
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function create_quality_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    local position = position_near_player(run, 11, 2)
    local inventory = require_inventory(player)
    run.context.quality_deconstruct_position = position
    run.context.quality_deconstruct_start_count = inventory.get_item_count({ name = "wooden-chest", quality = quality })
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = quality,
    }
    if not chest then error("failed to create uncommon wooden-chest") end
    local ok = chest.order_deconstruction(player.force, player)
    if not ok then error("failed to order uncommon wooden-chest deconstruction") end
    mark_expected_task(run, "deconstruct_entity")
end

function quality_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    return expected_task_was_seen(run)
        and find_entity_near("wooden-chest", run.context.quality_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "wooden-chest", quality = quality }) > run.context.quality_deconstruct_start_count
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function create_quality_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    require_item_prototype("speed-module")
    local position = position_near_player(run, 13, 2)
    run.context.quality_contents_deconstruct_position = position
    run.context.quality_contents_start_count = inventory.get_item_count({ name = "speed-module", quality = quality })
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create quality-content wooden-chest") end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    if not (chest_inventory and chest_inventory.valid) then
        error("missing quality-content chest inventory")
    end
    if chest_inventory.insert({ name = "speed-module", count = 1, quality = quality }) < 1 then
        error("failed to seed quality-content chest inventory")
    end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order quality-content chest deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function quality_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    local chest = find_entity_near("wooden-chest", run.context.quality_contents_deconstruct_position, nil, run.context.surface_name)
    local current_count = inventory.get_item_count({ name = "speed-module", quality = quality })
    run.context.quality_contents_state = {
        expected_task_seen = expected_task_was_seen(run) and true or false,
        first_seen_task = run.context.first_seen_task,
        seen_tasks = run.context.seen_tasks,
        chest_exists = chest and chest.valid or false,
        start_count = run.context.quality_contents_start_count,
        current_count = current_count,
        quality_spiderbot_idle = all_spiderbots_idle_with_quality(run.player_index, quality),
        spiderbot_count = spiderbot_count(run.player_index),
        quality_spiderbot_count = spiderbot_count_by_quality(run.player_index, quality),
    }
    return run.context.quality_contents_state.expected_task_seen
        and chest == nil
        and current_count > run.context.quality_contents_start_count
        and run.context.quality_contents_state.quality_spiderbot_idle
end

function create_quality_belt_contents_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    require_item_prototype("speed-module")
    local position = position_near_player(run, 20, 2)
    run.context.quality_belt_contents_deconstruct_position = position
    run.context.quality_belt_contents_start_count = inventory.get_item_count({ name = "speed-module", quality = quality })
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create quality-content transport-belt") end
    local inserted = 0
    for i = 1, belt.get_max_transport_line_index() do
        local line = belt.get_transport_line(i)
        if line and line.valid then
            line.force_insert_at(0.1, { name = "speed-module", count = 1, quality = quality })
            inserted = inserted + 1
        end
    end
    if inserted == 0 then error("failed to seed quality-content transport lines") end
    run.context.quality_belt_contents_inserted_count = inserted
    if not belt.order_deconstruction(player.force, player) then
        error("failed to order quality-content belt deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function quality_belt_contents_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    return expected_task_was_seen(run)
        and find_entity_near("transport-belt", run.context.quality_belt_contents_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "speed-module", quality = quality }) >= run.context.quality_belt_contents_start_count + run.context.quality_belt_contents_inserted_count
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function create_quality_item_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    local position = position_near_player(run, 14, 2)
    run.context.quality_item_request_position = position
    insert(player, { name = "speed-module", count = 1, quality = quality })
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create assembling-machine-2 for quality proxy") end
    run.context.quality_item_request_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = quality },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create uncommon item-request-proxy") end
    mark_expected_task(run, "insert_items")
end

function quality_item_request_complete(run)
    local assembler = run.context.quality_item_request_target
    if not (assembler and assembler.valid) then return false end
    local inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local quality = quality_under_test(run)
    return expected_task_was_seen(run)
        and inventory
        and inventory.valid
        and inventory.get_item_count({ name = "speed-module", quality = quality }) >= 1
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function create_quality_item_removal_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    local player_inventory = require_inventory(player)
    local position = position_near_player(run, 17, 2)
    run.context.quality_item_removal_position = position
    run.context.quality_item_removal_start_count = player_inventory.get_item_count({ name = "speed-module", quality = quality })
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create assembling-machine-2 for quality removal proxy") end
    run.context.quality_item_removal_target = assembler
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing assembler module inventory for quality removal proxy")
    end
    local module_stack = module_inventory[1]
    if not (module_stack and module_stack.valid) then
        error("quality removal proxy requires a module slot")
    end
    module_stack.set_stack({ name = "speed-module", count = 1, quality = quality })
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = quality },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create uncommon item-removal proxy") end
    mark_expected_task(run, "insert_items")
end

function quality_item_removal_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.quality_item_removal_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local quality = quality_under_test(run)
    return expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = quality }) == 0
        and player_inventory.get_item_count({ name = "speed-module", quality = quality }) > run.context.quality_item_removal_start_count
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function trigger_quality_teleport_redeploy(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = spiderbot_by_quality(run.player_index, quality_under_test(run))
    if not (spiderbot and spiderbot.valid) then
        error("missing quality spiderbot for teleport redeploy")
    end
    run.context.quality_teleport_old_unit_number = spiderbot.unit_number
    local target = position_near_player(run, 0, 16)
    local old_position = character.position
    local old_surface_index = character.surface.index
    if not player.teleport(target, character.surface) then
        error("failed to teleport player for quality redeploy test")
    end
    character = require_character(player)
    call_registered_handler(defines.events.script_raised_teleported, {
        entity = character,
        old_position = old_position,
        old_surface_index = old_surface_index,
    })
end

function quality_teleport_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local quality = quality_under_test(run)
    local spiderbot = spiderbot_by_quality(run.player_index, quality)
    return spiderbot_count_by_quality(run.player_index, quality) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.quality_teleport_old_unit_number
        and spiderbot.follow_target == character
        and spiderbot.surface == character.surface
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function trigger_quality_stuck_jump(run)
    local player = require_player(run)
    local character = require_character(player)
    local quality = quality_under_test(run)
    local spiderbot_data = spiderbot_data_by_quality(run.player_index, quality)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot and spiderbot.valid) then
        error("missing quality spiderbot for stuck jump test")
    end
    run.context.quality_stuck_old_unit_number = spiderbot.unit_number
    spiderbot.autopilot_destination = nil
    spiderbot.teleport({ x = character.position.x + 2, y = character.position.y }, character.surface)
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = nil
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = "synthetic-quality-stuck-task",
    }
end

function quality_stuck_jump_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local quality = quality_under_test(run)
    local spiderbot = spiderbot_by_quality(run.player_index, quality)
    return spiderbot_count_by_quality(run.player_index, quality) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.quality_stuck_old_unit_number
        and spiderbot.follow_target == character
        and all_spiderbots_idle_with_quality(run.player_index, quality)
end

function recall_quality_spiderbots(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    run.context.quality_recall_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = quality })
    storage.spiderbots_enabled[run.player_index] = false
end

function quality_recall_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality = quality_under_test(run)
    return spiderbot_count_by_quality(run.player_index, quality) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = quality }) > run.context.quality_recall_start_inventory
end

function toggle_deploys_all_available_quality_spiderbots(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    local quality_names = available_quality_names()
    if #quality_names == 0 then
        error("test requires at least one quality prototype")
    end
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = #quality_names
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    for _, quality in pairs(quality_names) do
        insert(player, { name = "spiderbot", count = 1, quality = quality })
    end
    run.context.all_quality_names = quality_names
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function all_quality_toggle_deploy_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality_names = run.context.all_quality_names or {}
    if storage.spiderbots_enabled[run.player_index] ~= true then return false end
    if spiderbot_count(run.player_index) ~= #quality_names then return false end
    if shortcut_toggled(player) ~= true then return false end
    for _, quality in pairs(quality_names) do
        if spiderbot_count_by_quality(run.player_index, quality) ~= 1 then
            return false
        end
        if inventory.get_item_count({ name = "spiderbot", quality = quality }) ~= 0 then
            return false
        end
    end
    return all_spiderbots_idle(run.player_index)
end

function recall_all_available_quality_spiderbots(run)
    local player = require_player(run)
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function all_quality_toggle_recall_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality_names = run.context.all_quality_names or {}
    if storage.spiderbots_enabled[run.player_index] ~= false then return false end
    if spiderbot_count(run.player_index) ~= 0 then return false end
    if shortcut_toggled(player) ~= false then return false end
    for _, quality in pairs(quality_names) do
        if inventory.get_item_count({ name = "spiderbot", quality = quality }) < 1 then
            return false
        end
    end
    return true
end

function deploy_search_window_spiderbot(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 1
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function search_window_spiderbot_deployed(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function create_distant_search_ghost(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = p(character.position.x + 35, character.position.y)
    run.context.distant_search_position = position
    prepare_buildable_ground(surface, position, 3)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    create_small_pole_ghost(surface, player, position)
    run.context.distant_search_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function distant_search_ghost_ignored_before_move(run)
    if game.tick - run.context.distant_search_started_tick < 75 then return false end
    local built = find_entity_near("small-electric-pole", run.context.distant_search_position, nil, run.context.surface_name)
    local ghosts = find_entities_near({ name = "entity-ghost" }, run.context.distant_search_position, nil, run.context.surface_name)
    run.context.distant_search_built_before_move = built and built.valid or false
    run.context.distant_search_ghost_count_before_move = #ghosts
    run.context.distant_search_seen_tasks_before_move = run.context.seen_tasks
    run.context.distant_search_idle_without_task_before_move = first_spiderbot_idle_without_task(run) and true or false
    return built == nil
        and #ghosts > 0
        and next(run.context.seen_tasks or {}) == nil
end

function move_player_near_distant_search_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.distant_search_position
    local target = p(position.x - 5, position.y)
    prepare_buildable_ground(surface, target, 3)
    if not player.teleport(target, surface) then
        error("failed to move player near distant search ghost")
    end
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = player.index,
    })
    mark_expected_task(run, "build_ghost")
end

function distant_search_ghost_built_after_move(run)
    return expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.distant_search_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_distant_non_entity_search_tasks(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    local base = p(character.position.x + 35, character.position.y)
    local tile_position = p(base.x, base.y - 3)
    local upgrade_position = p(base.x, base.y)
    local deconstruct_position = p(base.x, base.y + 3)
    local proxy_position = p(base.x, base.y + 6)
    run.context.distant_non_entity_base = base
    run.context.distant_non_entity_tile_position = tile_position
    run.context.distant_non_entity_upgrade_position = upgrade_position
    run.context.distant_non_entity_deconstruct_position = deconstruct_position
    run.context.distant_non_entity_proxy_position = proxy_position
    prepare_buildable_ground(surface, tile_position, 2)
    prepare_buildable_ground(surface, upgrade_position, 2)
    prepare_buildable_ground(surface, deconstruct_position, 2)
    prepare_buildable_ground(surface, proxy_position, 3)
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = tile_position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create distant-search tile ghost") end
    local belt = surface.create_entity {
        name = "transport-belt",
        position = upgrade_position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create distant-search upgrade belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order distant-search upgrade")
    end
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = deconstruct_position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create distant-search deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order distant-search deconstruction")
    end
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = proxy_position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create distant-search item proxy assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = proxy_position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create distant-search item request proxy") end
    run.context.distant_non_entity_assembler = assembler
    run.context.distant_non_entity_proxy = proxy
    run.context.distant_non_entity_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function distant_non_entity_search_tasks_ignored_before_move(run)
    if game.tick - run.context.distant_non_entity_started_tick < 75 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local tile = surface.get_tile(run.context.distant_non_entity_tile_position.x, run.context.distant_non_entity_tile_position.y)
    local upgraded = find_entity_near("fast-transport-belt", run.context.distant_non_entity_upgrade_position, nil, run.context.surface_name)
    local chest = find_entity_near("wooden-chest", run.context.distant_non_entity_deconstruct_position, nil, run.context.surface_name)
    local assembler = run.context.distant_non_entity_assembler
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    run.context.distant_non_entity_seen_tasks_before_move = run.context.seen_tasks
    run.context.distant_non_entity_idle_without_task_before_move = first_spiderbot_idle_without_task(run) and true or false
    return tile
        and tile.valid
        and tile.name ~= "stone-path"
        and upgraded == nil
        and chest
        and chest.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and next(run.context.seen_tasks or {}) == nil
end

function move_player_near_distant_non_entity_search_tasks(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local base = run.context.distant_non_entity_base
    local target = p(base.x - 5, base.y)
    prepare_buildable_ground(surface, target, 3)
    if not player.teleport(target, surface) then
        error("failed to move player near distant non-entity search tasks")
    end
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = player.index,
    })
    mark_expected_tasks(run, { "build_tile", "upgrade_entity", "deconstruct_entity", "insert_items" })
end

function distant_non_entity_search_tasks_completed_after_move(run)
    local surface = game.surfaces[run.context.surface_name]
    local tile = surface.get_tile(run.context.distant_non_entity_tile_position.x, run.context.distant_non_entity_tile_position.y)
    local upgraded = find_entity_near("fast-transport-belt", run.context.distant_non_entity_upgrade_position, nil, run.context.surface_name)
    local chest = find_entity_near("wooden-chest", run.context.distant_non_entity_deconstruct_position, nil, run.context.surface_name)
    local assembler = run.context.distant_non_entity_assembler
    local proxy = run.context.distant_non_entity_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local complete = expected_tasks_were_seen(run)
        and tile
        and tile.valid
        and tile.name == "stone-path"
        and upgraded
        and upgraded.valid
        and chest == nil
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
    if complete then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        if assembler and assembler.valid then
            assembler.destroy({ raise_destroy = true })
        end
        run.context.distant_non_entity_assembler = nil
        run.context.distant_non_entity_proxy = nil
    end
    return complete
end

function create_obstacle_corridor_build_ghost(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("water")
    local ground = natural_ground_tile_name()
    local base = p(math.floor(character.position.x), math.floor(character.position.y))
    local barrier_left_top = p(base.x - 8, base.y + 6)
    local barrier_right_bottom = p(base.x + 8, base.y + 10)
    set_rectangle_tiles(surface, barrier_left_top, barrier_right_bottom, "water")
    set_rectangle_tiles(surface, p(base.x - 1, base.y + 6), p(base.x + 1, base.y + 10), ground)
    local ghost_position = p(base.x, base.y + 16)
    run.context.obstacle_corridor_position = ghost_position
    prepare_buildable_ground(surface, ghost_position, 3)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    create_small_pole_ghost(surface, player, ghost_position)
    mark_expected_task(run, "build_ghost")
end

function obstacle_corridor_build_complete(run)
    return expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.obstacle_corridor_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_gate_corridor_build_ghost(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("stone-wall")
    require_entity_prototype("gate")
    require_tile_prototype("water")
    local ground = natural_ground_tile_name()
    local base = p(math.floor(character.position.x), math.floor(character.position.y))
    local barrier_left_top = p(base.x - 8, base.y + 7)
    local barrier_right_bottom = p(base.x + 8, base.y + 11)
    set_rectangle_tiles(surface, barrier_left_top, barrier_right_bottom, "water")
    set_rectangle_tiles(surface, p(base.x - 1, base.y + 7), p(base.x + 1, base.y + 11), ground)
    run.context.gate_corridor_entities = {}
    for x = -8, 8 do
        if x ~= 0 then
            local wall = surface.create_entity {
                name = "stone-wall",
                position = p(base.x + x, base.y + 9),
                force = player.force,
            }
            if wall then
                table.insert(run.context.gate_corridor_entities, wall)
            end
        end
    end
    local gate = surface.create_entity {
        name = "gate",
        position = p(base.x, base.y + 9),
        force = player.force,
        direction = defines.direction.east,
    } or surface.create_entity {
        name = "gate",
        position = p(base.x, base.y + 9),
        force = player.force,
        direction = defines.direction.north,
    }
    if not gate then error("failed to create gate corridor gate") end
    table.insert(run.context.gate_corridor_entities, gate)
    local ghost_position = p(base.x, base.y + 16)
    run.context.gate_corridor_position = ghost_position
    prepare_buildable_ground(surface, ghost_position, 3)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    create_small_pole_ghost(surface, player, ghost_position)
    mark_expected_task(run, "build_ghost")
end

function gate_corridor_build_complete(run)
    local built = find_entity_near("small-electric-pole", run.context.gate_corridor_position, nil, run.context.surface_name)
    local complete = expected_task_was_seen(run)
        and built
        and built.valid
        and all_spiderbots_idle(run.player_index)
    if complete then
        for _, entity in pairs(run.context.gate_corridor_entities or {}) do
            if entity and entity.valid then
                entity.destroy({ raise_destroy = true })
            end
        end
        run.context.gate_corridor_entities = nil
    end
    return complete
end

function deploy_from_vehicle_inventory(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 1
    storage.spiderbots_enabled[run.player_index] = false
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    local surface = game.surfaces[run.context.surface_name]
    prepare_buildable_ground(surface, position_near_player(run, 2, 5), 4)
    local car = surface.create_entity {
        name = "car",
        position = position_near_player(run, 2, 5),
        force = player.force,
    }
    if not car then error("failed to create vehicle inventory test car") end
    run.context.vehicle_inventory_car = car
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    trunk.insert({ name = "spiderbot", count = 1, quality = "normal" })
    trunk.insert({ name = "small-electric-pole", count = 1, quality = "normal" })
    car.set_driver(player)
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = car,
    })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function vehicle_inventory_deploy_complete(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == car
        and trunk.get_item_count({ name = "spiderbot", quality = "normal" }) == 0
        and all_spiderbots_idle(run.player_index)
end

function create_vehicle_inventory_build_ghost(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then error("missing vehicle inventory test car") end
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    run.context.vehicle_pole_start_count = trunk.get_item_count({ name = "small-electric-pole", quality = "normal" })
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 5, 5)
    run.context.vehicle_build_ghost_position = position
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not ghost then error("failed to create vehicle-sourced small-electric-pole ghost") end
    mark_expected_task(run, "build_ghost")
end

function vehicle_inventory_build_complete(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    return expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.vehicle_build_ghost_position, nil, run.context.surface_name) ~= nil
        and trunk.get_item_count({ name = "small-electric-pole", quality = "normal" }) < run.context.vehicle_pole_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_vehicle_inventory_deconstruction_order(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then error("missing vehicle inventory test car") end
    local character_inventory = require_inventory(player)
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    remove_from_main_inventory(player, { name = "wooden-chest", quality = "normal" })
    run.context.vehicle_deconstruct_filler_item_name = "iron-plate"
    run.context.vehicle_deconstruct_filler_start_count = character_inventory.get_item_count({ name = run.context.vehicle_deconstruct_filler_item_name, quality = "normal" })
    fill_inventory_until_cannot_insert(
        character_inventory,
        { name = run.context.vehicle_deconstruct_filler_item_name, count = 100, quality = "normal" },
        { name = "wooden-chest", count = 1, quality = "normal" }
    )
    if not trunk.can_insert({ name = "wooden-chest", count = 1, quality = "normal" }) then
        error("vehicle deconstruction fallback test needs trunk room for chest")
    end
    if not trunk.can_insert({ name = "iron-plate", count = 2, quality = "normal" }) then
        error("vehicle deconstruction fallback test needs trunk room for contents")
    end
    run.context.vehicle_deconstruct_trunk_chest_start = trunk.get_item_count({ name = "wooden-chest", quality = "normal" })
    run.context.vehicle_deconstruct_trunk_content_start = trunk.get_item_count({ name = "iron-plate", quality = "normal" })
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 8, 5)
    run.context.vehicle_deconstruct_position = position
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create vehicle-return deconstruction chest") end
    local chest_inventory = require_inventory_from_entity(chest, defines.inventory.chest)
    if chest_inventory.insert({ name = "iron-plate", count = 2, quality = "normal" }) < 2 then
        error("failed to seed vehicle-return deconstruction contents")
    end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order vehicle-return chest deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function vehicle_inventory_deconstruction_returned_to_trunk(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local character_inventory = require_inventory(player)
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local completed = expected_task_was_seen(run)
        and find_entity_near("wooden-chest", run.context.vehicle_deconstruct_position, nil, run.context.surface_name) == nil
        and trunk.get_item_count({ name = "wooden-chest", quality = "normal" }) > run.context.vehicle_deconstruct_trunk_chest_start
        and trunk.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.vehicle_deconstruct_trunk_content_start + 2
        and all_spiderbots_idle(run.player_index)
    if completed then
        local filler_item_name = run.context.vehicle_deconstruct_filler_item_name or "iron-plate"
        local start_count = run.context.vehicle_deconstruct_filler_start_count or 0
        local current_count = character_inventory.get_item_count({ name = filler_item_name, quality = "normal" })
        if current_count > start_count then
            character_inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
        end
    end
    return completed
end

function recall_vehicle_inventory_spiderbot(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then error("missing vehicle inventory test car") end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local inventory = require_inventory(player)
    run.context.vehicle_recall_character_start = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    run.context.vehicle_recall_trunk_start = trunk.get_item_count({ name = "spiderbot", quality = "normal" })
    storage.spiderbots_enabled[run.player_index] = false
end

function vehicle_recall_prefers_character_inventory(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local inventory = require_inventory(player)
    return spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) > run.context.vehicle_recall_character_start
        and trunk.get_item_count({ name = "spiderbot", quality = "normal" }) == run.context.vehicle_recall_trunk_start
end

function deploy_vehicle_recall_fallback_spiderbot(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then error("missing vehicle inventory test car") end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    storage.spiderbot_follower_count[player.force.name] = 1
    storage.spiderbots_enabled[run.player_index] = false
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    local inserted = trunk.insert({ name = "spiderbot", count = 1, quality = "normal" })
    if inserted < 1 then error("failed to insert spiderbot into vehicle trunk") end
    run.context.vehicle_fallback_deploy_trunk_start = trunk.get_item_count({ name = "spiderbot", quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function vehicle_recall_fallback_spiderbot_deployed(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local spiderbot = first_spiderbot(run.player_index)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == car
        and trunk.get_item_count({ name = "spiderbot", quality = "normal" }) < run.context.vehicle_fallback_deploy_trunk_start
        and all_spiderbots_idle(run.player_index)
end

function recall_vehicle_fallback_with_full_character(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then error("missing vehicle inventory test car") end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    local inventory = require_inventory(player)
    run.context.vehicle_fallback_filler_item_name = "iron-plate"
    run.context.vehicle_fallback_filler_start_count = inventory.get_item_count({ name = run.context.vehicle_fallback_filler_item_name, quality = "normal" })
    run.context.vehicle_fallback_trunk_start = trunk.get_item_count({ name = "spiderbot", quality = "normal" })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.vehicle_fallback_filler_item_name, count = 100, quality = "normal" },
        { name = "spiderbot", count = 1, quality = "normal" }
    )
    storage.spiderbots_enabled[run.player_index] = false
end

function vehicle_recall_fell_back_to_trunk(run)
    local car = run.context.vehicle_inventory_car
    if not (car and car.valid) then return false end
    local trunk = require_inventory_from_entity(car, defines.inventory.car_trunk)
    return spiderbot_count(run.player_index) == 0
        and trunk.get_item_count({ name = "spiderbot", quality = "normal" }) > run.context.vehicle_fallback_trunk_start
end

function cleanup_vehicle_recall_fallback(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local filler_item_name = run.context.vehicle_fallback_filler_item_name or "iron-plate"
    local start_count = run.context.vehicle_fallback_filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    storage.spiderbots_enabled[run.player_index] = true
end

function cleanup_vehicle_inventory_test(run)
    local player = require_player(run)
    local car = run.context.vehicle_inventory_car
    if car and car.valid then
        car.set_driver(nil)
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = car,
        })
        car.destroy({ raise_destroy = true })
    end
    run.context.vehicle_inventory_car = nil
    storage.spiderbots_enabled[run.player_index] = true
end

function deploy_spider_vehicle_inventory_spiderbot(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 1
    storage.spiderbots_enabled[run.player_index] = false
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function spider_vehicle_inventory_spiderbot_deployed(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function enter_spider_vehicle_and_create_inventory_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("spidertron")
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    local vehicle_position = position_near_player(run, 2, 8)
    prepare_buildable_ground(surface, vehicle_position, 8)
    local spidertron = surface.create_entity {
        name = "spidertron",
        position = vehicle_position,
        force = player.force,
        quality = "normal",
    }
    if not spidertron then error("failed to create spider-vehicle inventory test spidertron") end
    run.context.spider_vehicle_inventory_spidertron = spidertron
    local trunk = require_inventory_from_entity(spidertron, defines.inventory.spider_trunk)
    trunk.insert({ name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.spider_vehicle_pole_start_count = trunk.get_item_count({ name = "small-electric-pole", quality = "normal" })
    spidertron.set_driver(player)
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = spidertron,
    })
    local ghost_position = p(spidertron.position.x + 5, spidertron.position.y)
    run.context.spider_vehicle_build_ghost_position = ghost_position
    prepare_buildable_ground(surface, ghost_position, 2)
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    if not ghost then error("failed to create spider-vehicle-sourced pole ghost") end
    mark_expected_task(run, "build_ghost")
end

function spider_vehicle_inventory_build_complete(run)
    local spidertron = run.context.spider_vehicle_inventory_spidertron
    if not (spidertron and spidertron.valid) then return false end
    local trunk = require_inventory_from_entity(spidertron, defines.inventory.spider_trunk)
    local spiderbot = first_spiderbot(run.player_index)
    return expected_task_was_seen(run)
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == spidertron
        and find_entity_near("small-electric-pole", run.context.spider_vehicle_build_ghost_position, nil, run.context.surface_name) ~= nil
        and trunk.get_item_count({ name = "small-electric-pole", quality = "normal" }) < run.context.spider_vehicle_pole_start_count
        and all_spiderbots_idle(run.player_index)
end

function cleanup_spider_vehicle_inventory_test(run)
    local player = require_player(run)
    local spidertron = run.context.spider_vehicle_inventory_spidertron
    if spidertron and spidertron.valid then
        spidertron.set_driver(nil)
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = spidertron,
        })
        spidertron.destroy({ raise_destroy = true })
    end
    run.context.spider_vehicle_inventory_spidertron = nil
    reset_active_spiderbots(run)
end

function deploy_cargo_wagon_inventory_spiderbot(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 1
    storage.spiderbots_enabled[run.player_index] = false
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function cargo_wagon_inventory_spiderbot_deployed(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function create_cargo_wagon_with_track(surface, player, center)
    require_entity_prototype("straight-rail")
    require_entity_prototype("cargo-wagon")
    local attempts = {
        { direction = defines.direction.east, offsets = { p(-8, 0), p(-6, 0), p(-4, 0), p(-2, 0), p(0, 0), p(2, 0), p(4, 0), p(6, 0), p(8, 0) } },
        { direction = defines.direction.north, offsets = { p(0, -8), p(0, -6), p(0, -4), p(0, -2), p(0, 0), p(0, 2), p(0, 4), p(0, 6), p(0, 8) } },
    }
    for _, attempt in pairs(attempts) do
        local rails = {}
        for _, offset in pairs(attempt.offsets) do
            local rail = surface.create_entity {
                name = "straight-rail",
                position = p(center.x + offset.x, center.y + offset.y),
                direction = attempt.direction,
                force = player.force,
            }
            if rail then
                table.insert(rails, rail)
            end
        end
        local wagon = surface.create_entity {
            name = "cargo-wagon",
            position = center,
            direction = attempt.direction,
            force = player.force,
            quality = "normal",
        }
        if wagon then
            return wagon, rails
        end
        for _, rail in pairs(rails) do
            if rail and rail.valid then
                rail.destroy({ raise_destroy = true })
            end
        end
    end
    error("failed to create cargo wagon on test rails")
end

function find_cargo_wagon_pole_ghost_position(surface, player, wagon)
    local offsets = {
        p(0, -8),
        p(0, 8),
        p(-8, 0),
        p(8, 0),
        p(-10, -6),
        p(10, -6),
        p(-10, 6),
        p(10, 6),
        p(-6, -10),
        p(6, -10),
        p(-6, 10),
        p(6, 10),
    }
    for _, offset in pairs(offsets) do
        local position = p(wagon.position.x + offset.x, wagon.position.y + offset.y)
        prepare_buildable_ground(surface, position, 2)
        if surface.can_place_entity { name = "small-electric-pole", position = position, force = player.force } then
            return position
        end
    end
    error("failed to find cargo-wagon pole ghost position clear of rails")
end

function enter_cargo_wagon_and_create_inventory_ghost(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    local wagon_position = p(character.position.x + 2, character.position.y + 10)
    prepare_buildable_ground(surface, wagon_position, 12)
    local wagon, rails = create_cargo_wagon_with_track(surface, player, wagon_position)
    run.context.cargo_wagon_inventory_wagon = wagon
    run.context.cargo_wagon_inventory_rails = rails
    local trunk = require_inventory_from_entity(wagon, defines.inventory.cargo_wagon)
    trunk.insert({ name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.cargo_wagon_pole_start_count = trunk.get_item_count({ name = "small-electric-pole", quality = "normal" })
    wagon.set_driver(player)
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = player.index,
        entity = wagon,
    })
    local ghost_position = find_cargo_wagon_pole_ghost_position(surface, player, wagon)
    run.context.cargo_wagon_build_ghost_position = ghost_position
    run.context.cargo_wagon_ghost_can_place = surface.can_place_entity { name = "small-electric-pole", position = ghost_position, force = player.force }
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    if not ghost then error("failed to create cargo-wagon-sourced pole ghost") end
    mark_expected_task(run, "build_ghost")
end

function cargo_wagon_inventory_build_complete(run)
    local player = require_player(run)
    local wagon = run.context.cargo_wagon_inventory_wagon
    if not (wagon and wagon.valid) then return false end
    local surface = game.surfaces[run.context.surface_name]
    local trunk = require_inventory_from_entity(wagon, defines.inventory.cargo_wagon)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    local built = find_entity_near("small-electric-pole", run.context.cargo_wagon_build_ghost_position, nil, run.context.surface_name)
    local ghosts = find_entities_near({ name = "entity-ghost" }, run.context.cargo_wagon_build_ghost_position, nil, run.context.surface_name)
    local trunk_count = trunk.get_item_count({ name = "small-electric-pole", quality = "normal" })
    run.context.cargo_wagon_build_state = {
        expected_task_seen = expected_task_was_seen(run) and true or false,
        first_seen_task = run.context.first_seen_task,
        seen_tasks = run.context.seen_tasks,
        spiderbot_status = spiderbot_data and spiderbot_data.status,
        follow_target_is_wagon = spiderbot and spiderbot.valid and spiderbot.follow_target == wagon or false,
        player_vehicle_is_wagon = player.physical_vehicle == wagon,
        built = built and built.valid or false,
        ghost_count = #ghosts,
        trunk_start = run.context.cargo_wagon_pole_start_count,
        trunk_count = trunk_count,
        can_place_pole = surface.can_place_entity { name = "small-electric-pole", position = run.context.cargo_wagon_build_ghost_position, force = player.force },
    }
    return run.context.cargo_wagon_build_state.expected_task_seen
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == wagon
        and built ~= nil
        and trunk_count < run.context.cargo_wagon_pole_start_count
        and all_spiderbots_idle(run.player_index)
end

function cleanup_cargo_wagon_inventory_test(run)
    local player = require_player(run)
    local wagon = run.context.cargo_wagon_inventory_wagon
    if wagon and wagon.valid then
        wagon.set_driver(nil)
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = wagon,
        })
        wagon.destroy({ raise_destroy = true })
    end
    for _, rail in pairs(run.context.cargo_wagon_inventory_rails or {}) do
        if rail and rail.valid then
            rail.destroy({ raise_destroy = true })
        end
    end
    run.context.cargo_wagon_inventory_wagon = nil
    run.context.cargo_wagon_inventory_rails = nil
    reset_active_spiderbots(run)
end

function create_cargo_wagon_contents_deconstruction_order(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    local player_inventory = require_inventory(player)
    require_item_prototype("cargo-wagon")
    local position = p(character.position.x + 12, character.position.y - 10)
    run.context.cargo_wagon_contents_deconstruct_position = position
    run.context.cargo_wagon_contents_deconstruct_wagon_start_count = player_inventory.get_item_count({ name = "cargo-wagon", quality = "normal" })
    run.context.cargo_wagon_contents_deconstruct_content_start_count = player_inventory.get_item_count({ name = "iron-plate", quality = "normal" })
    prepare_buildable_ground(surface, position, 12)
    local wagon, rails = create_cargo_wagon_with_track(surface, player, position)
    run.context.cargo_wagon_contents_deconstruct_rails = rails
    local inventory = require_inventory_from_entity(wagon, defines.inventory.cargo_wagon)
    local inserted = inventory.insert({ name = "iron-plate", count = 2, quality = "normal" })
    if inserted < 2 then error("failed to seed cargo-wagon contents") end
    run.context.cargo_wagon_contents_deconstruct_inserted_count = inserted
    if not wagon.order_deconstruction(player.force, player) then
        error("failed to order cargo-wagon with contents deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function cargo_wagon_contents_deconstruction_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local completed = expected_task_was_seen(run)
        and find_entity_near("cargo-wagon", run.context.cargo_wagon_contents_deconstruct_position, 3, run.context.surface_name) == nil
        and player_inventory.get_item_count({ name = "cargo-wagon", quality = "normal" }) > run.context.cargo_wagon_contents_deconstruct_wagon_start_count
        and player_inventory.get_item_count({ name = "iron-plate", quality = "normal" }) >= run.context.cargo_wagon_contents_deconstruct_content_start_count + run.context.cargo_wagon_contents_deconstruct_inserted_count
        and all_spiderbots_idle(run.player_index)
    if completed then
        for _, rail in pairs(run.context.cargo_wagon_contents_deconstruct_rails or {}) do
            if rail and rail.valid then
                rail.destroy({ raise_destroy = true })
            end
        end
        run.context.cargo_wagon_contents_deconstruct_rails = nil
    end
    return completed
end

function use_capsule_over_follower_limit(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    reset_active_spiderbots(run)
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    storage.spiderbot_follower_count[player.force.name] = 0
    storage.spiderbots_enabled[run.player_index] = true
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    run.context.follower_limit_refund_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    local position = position_near_player(run, 3, 0)
    prepare_buildable_ground(player.surface, position, 4)
    run.context.follower_limit_use_from_cursor_result = player.use_from_cursor(position)
end

function follower_limit_capsule_refunded(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local cursor_stack = player.cursor_stack
    local cursor_count = cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "spiderbot" and cursor_stack.count or 0
    local inventory_count = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    run.context.follower_limit_refund_state = {
        spiderbot_count = spiderbot_count(run.player_index),
        cursor_count = cursor_count,
        inventory_start = run.context.follower_limit_refund_start_inventory,
        inventory_count = inventory_count,
    }
    return run.context.follower_limit_refund_state.spiderbot_count == 0
        and (cursor_count >= 1 or inventory_count > run.context.follower_limit_refund_start_inventory)
end

function clear_refunded_capsule_cursor(run)
    local player = require_player(run)
    player.clear_cursor()
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    storage.spiderbot_follower_count[player.force.name] = 10
end

function use_capsule_with_no_landing_position(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = require_inventory(player)
    reset_active_spiderbots(run)
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    storage.spiderbot_follower_count[player.force.name] = 10
    storage.spiderbots_enabled[run.player_index] = true
    local target = position_near_player(run, 0, -8)
    target = { x = math.floor(target.x), y = math.floor(target.y) }
    run.context.no_landing_position = target
    run.context.no_landing_radius = 6
    run.context.no_landing_refund_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    run.context.no_landing_original_tiles = capture_square_tiles(surface, target, run.context.no_landing_radius)
    set_square_tiles(surface, target, run.context.no_landing_radius, "water")
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    run.context.no_landing_use_from_cursor_result = player.use_from_cursor(target)
end

function no_landing_capsule_refunded(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local cursor_stack = player.cursor_stack
    local cursor_count = cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "spiderbot" and cursor_stack.count or 0
    local inventory_count = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    run.context.no_landing_refund_state = {
        spiderbot_count = spiderbot_count(run.player_index),
        cursor_count = cursor_count,
        inventory_start = run.context.no_landing_refund_start_inventory,
        inventory_count = inventory_count,
    }
    return run.context.no_landing_refund_state.spiderbot_count == 0
        and (cursor_count >= 1 or inventory_count > run.context.no_landing_refund_start_inventory)
end

function cleanup_no_landing_position(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    player.clear_cursor()
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    if surface and run.context.no_landing_original_tiles then
        surface.set_tiles(run.context.no_landing_original_tiles)
    end
    run.context.no_landing_original_tiles = nil
end

function trigger_quality_refund_with_conflicting_cursor(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local quality_name = quality_under_test(run)
    reset_active_spiderbots(run)
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    storage.spiderbot_follower_count[player.force.name] = 0
    storage.spiderbots_enabled[run.player_index] = true
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    run.context.quality_refund_start_normal_cursor_count = cursor_stack.count
    run.context.quality_refund_start_quality_inventory = inventory.get_item_count({ name = "spiderbot", quality = quality_name })
    call_registered_handler(defines.events.on_player_used_capsule, {
        item = { name = "spiderbot" },
        player_index = player.index,
        position = position_near_player(run, 4, -8),
        quality = prototypes.quality[quality_name],
    })
    storage.spiderbot_follower_count[player.force.name] = 10
end

function quality_refund_with_conflicting_cursor_restored_quality_to_cursor(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local cursor_stack = player.cursor_stack
    local quality_name = quality_under_test(run)
    local restored = spiderbot_count(run.player_index) == 0
        and cursor_stack
        and cursor_stack.valid_for_read
        and cursor_stack.name == "spiderbot"
        and cursor_stack.quality.name == quality_name
        and cursor_stack.count == 1
        and inventory.get_item_count({ name = "spiderbot", quality = quality_name }) == run.context.quality_refund_start_quality_inventory
    if restored then
        player.clear_cursor()
        remove_all_qualities_from_main_inventory(player, "spiderbot")
        storage.spiderbots_enabled[run.player_index] = true
    end
    return restored
end

function deploy_no_space_recall_spiderbot(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 1
    storage.spiderbots_enabled[run.player_index] = true
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    local position = position_near_player(run, 3, 0)
    prepare_buildable_ground(player.surface, position, 4)
    player.use_from_cursor(position)
end

function no_space_recall_spiderbot_deployed(run)
    return spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
end

function recall_with_full_character_inventory(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for full-inventory recall")
    end
    run.context.no_space_recall_position = spiderbot.position
    run.context.filler_item_name = "iron-plate"
    run.context.filler_start_count = inventory.get_item_count({ name = run.context.filler_item_name, quality = "normal" })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.filler_item_name, count = 100, quality = "normal" },
        { name = "spiderbot", count = 1, quality = "normal" }
    )
    storage.spiderbots_enabled[run.player_index] = false
end

function full_inventory_recall_spilled(run)
    return spiderbot_count(run.player_index) == 0
        and find_item_on_ground_near("spiderbot", run.context.no_space_recall_position, 6, run.context.surface_name) ~= nil
end

function cleanup_full_inventory_recall(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local filler_item_name = run.context.filler_item_name or "iron-plate"
    local start_count = run.context.filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    local item = find_item_on_ground_near("spiderbot", run.context.no_space_recall_position, 6, run.context.surface_name)
    if item and item.valid then
        item.destroy()
    end
    storage.spiderbots_enabled[run.player_index] = true
end

function trigger_toggle_spam_with_in_flight_projectile(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 10
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function toggle_spam_spiderbot_settled(run)
    local player = require_player(run)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not projectiles or #projectiles == 0)
        and shortcut_toggled(player) == true
end

function recall_toggle_spam_spiderbot(run)
    local player = require_player(run)
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function toggle_spam_spiderbot_recalled(run)
    local player = require_player(run)
    return storage.spiderbots_enabled[run.player_index] == false
        and spiderbot_count(run.player_index) == 0
        and shortcut_toggled(player) == false
end

function deploy_multiple_spiderbots(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 3
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 3, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function multiple_spiderbots_deployed(run)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 3
        and all_spiderbots_idle(run.player_index)
end

function create_single_upgrade_for_duplicate_suppression(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 13, -7)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create duplicate-suppression upgrade target") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order duplicate-suppression upgrade")
    end
    run.context.duplicate_upgrade_target = belt
    run.context.duplicate_upgrade_position = position
    mark_expected_task(run, "upgrade_entity")
end

function single_upgrade_duplicate_suppression_complete(run)
    local target = run.context.duplicate_upgrade_target
    if target and target.valid then
        local assigned_count = active_task_target_count(run.player_index, target)
        if assigned_count > 1 then
            error("single upgrade target assigned to " .. assigned_count .. " spiderbots")
        end
    end
    local upgraded = find_entity_near("fast-transport-belt", run.context.duplicate_upgrade_position, nil, run.context.surface_name)
    local completed = expected_task_was_seen(run)
        and upgraded
        and upgraded.valid
        and all_spiderbots_idle(run.player_index)
    if completed then
        upgraded.destroy({ raise_destroy = true })
        run.context.duplicate_upgrade_target = nil
    end
    return completed
end

function create_single_tile_deconstruction_for_duplicate_suppression(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 16, -7)
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to create duplicate-suppression tile target")
    end
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order duplicate-suppression tile deconstruction")
    end
    run.context.duplicate_tile_deconstruction_position = position
    run.context.duplicate_tile_deconstruction_task_id = task_id_for_tile(tile)
    mark_expected_task(run, "deconstruct_tile")
end

function single_tile_deconstruction_duplicate_suppression_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.duplicate_tile_deconstruction_position
    local tile = surface.get_tile(position.x, position.y)
    local assigned_count = active_task_id_count(run.player_index, run.context.duplicate_tile_deconstruction_task_id)
    if assigned_count > 1 then
        error("single tile deconstruction target assigned to " .. assigned_count .. " spiderbots")
    end
    return expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and all_spiderbots_idle(run.player_index)
end

function create_multiple_build_ghosts(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    run.context.multi_build_positions = {
        position_near_player(run, 4, -4),
        position_near_player(run, 7, -4),
        position_near_player(run, 10, -4),
    }
    insert(player, { name = "small-electric-pole", count = 3, quality = "normal" })
    for _, position in pairs(run.context.multi_build_positions) do
        prepare_buildable_ground(surface, position, 2)
        local ghost = surface.create_entity {
            name = "entity-ghost",
            inner_name = "small-electric-pole",
            position = position,
            force = player.force,
            quality = "normal",
        }
        if not ghost then error("failed to create multi-spiderbot build ghost") end
    end
    mark_expected_task(run, "build_ghost")
end

function multiple_build_ghosts_complete(run)
    if not expected_task_was_seen(run) then return false end
    for _, position in pairs(run.context.multi_build_positions or {}) do
        if not find_entity_near("small-electric-pole", position, nil, run.context.surface_name) then
            return false
        end
    end
    return all_spiderbots_idle(run.player_index)
end

function create_mixed_simultaneous_tasks(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local base = position_near_player(run, -12, -8)
    run.context.mixed_deconstruct_position = p(base.x, base.y)
    run.context.mixed_build_position = p(base.x + 3, base.y)
    run.context.mixed_upgrade_position = p(base.x + 6, base.y)
    run.context.mixed_item_request_position = p(base.x + 9, base.y)
    run.context.mixed_tile_deconstruct_position = p(base.x + 12, base.y)
    run.context.mixed_tile_build_position = p(base.x + 15, base.y)
    prepare_buildable_ground(surface, p(base.x + 7, base.y), 10)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })

    local chest = surface.create_entity {
        name = "wooden-chest",
        position = run.context.mixed_deconstruct_position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create mixed deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order mixed chest deconstruction")
    end

    create_small_pole_ghost(surface, player, run.context.mixed_build_position)

    local belt = surface.create_entity {
        name = "transport-belt",
        position = run.context.mixed_upgrade_position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create mixed upgrade belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order mixed transport-belt upgrade")
    end

    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = run.context.mixed_item_request_position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create mixed item request assembler") end
    run.context.mixed_item_request_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = run.context.mixed_item_request_position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create mixed item request proxy") end

    set_square_tiles(surface, run.context.mixed_tile_deconstruct_position, 0, natural_ground_tile_name())
    local built_tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = run.context.mixed_tile_deconstruct_position,
        force = player.force,
    }
    if not built_tile_ghost then error("failed to create mixed seed tile ghost") end
    built_tile_ghost.revive({ raise_revive = true })
    local tile = surface.get_tile(run.context.mixed_tile_deconstruct_position.x, run.context.mixed_tile_deconstruct_position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to seed mixed tile deconstruction target")
    end
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order mixed tile deconstruction")
    end

    set_square_tiles(surface, run.context.mixed_tile_build_position, 0, natural_ground_tile_name())
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = run.context.mixed_tile_build_position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create mixed tile build ghost") end
    mark_expected_tasks(run, {
        "deconstruct_entity",
        "build_ghost",
        "upgrade_entity",
        "insert_items",
        "deconstruct_tile",
        "build_tile",
    })
end

function mixed_simultaneous_tasks_complete(run)
    if not expected_tasks_were_seen(run) then return false end
    local surface = game.surfaces[run.context.surface_name]
    local assembler = run.context.mixed_item_request_target
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local deconstructed_tile = surface.get_tile(run.context.mixed_tile_deconstruct_position.x, run.context.mixed_tile_deconstruct_position.y)
    local built_tile = surface.get_tile(run.context.mixed_tile_build_position.x, run.context.mixed_tile_build_position.y)
    return find_entity_near("wooden-chest", run.context.mixed_deconstruct_position, nil, run.context.surface_name) == nil
        and find_entity_near("small-electric-pole", run.context.mixed_build_position, nil, run.context.surface_name) ~= nil
        and find_entity_near("fast-transport-belt", run.context.mixed_upgrade_position, nil, run.context.surface_name) ~= nil
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and deconstructed_tile
        and deconstructed_tile.valid
        and deconstructed_tile.name ~= "stone-path"
        and built_tile
        and built_tile.valid
        and built_tile.name == "stone-path"
        and all_spiderbots_idle(run.player_index)
end

function recall_multiple_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
end

function multiple_spiderbots_recalled(run)
    return spiderbot_count(run.player_index) == 0
end

function deploy_max_dispatch_spiderbots(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 10
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 10, quality = "normal" })
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function max_dispatch_spiderbots_deployed(run)
    return storage.spiderbots_enabled[run.player_index] == true
        and spiderbot_count(run.player_index) == 10
        and all_spiderbots_idle(run.player_index)
end

function create_max_dispatch_build_ghosts(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local base = position_near_player(run, -20, -14)
    run.context.max_dispatch_build_positions = {}
    run.context.max_dispatch_high_water = 0
    prepare_buildable_ground(surface, p(base.x + 13.5, base.y), 18)
    insert(player, { name = "small-electric-pole", count = 10, quality = "normal" })
    for i = 0, 9 do
        local position = p(base.x + (i * 3), base.y)
        table.insert(run.context.max_dispatch_build_positions, position)
        local ghost = surface.create_entity {
            name = "entity-ghost",
            inner_name = "small-electric-pole",
            position = position,
            force = player.force,
            quality = "normal",
        }
        if not ghost then error("failed to create max-dispatch build ghost") end
    end
    mark_expected_task(run, "build_ghost")
end

function max_dispatch_builds_complete(run)
    local active_count = active_spiderbot_task_count(run.player_index)
    run.context.max_dispatch_high_water = math.max(run.context.max_dispatch_high_water or 0, active_count)
    run.context.max_dispatch_active_count = active_count
    if not expected_task_was_seen(run) then return false end
    if (run.context.max_dispatch_high_water or 0) < 9 then return false end
    for _, position in pairs(run.context.max_dispatch_build_positions or {}) do
        if not find_entity_near("small-electric-pole", position, nil, run.context.surface_name) then
            return false
        end
    end
    return all_spiderbots_idle(run.player_index)
end

function enter_remote_view_and_deploy_spiderbot(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 10
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.remote_view_character = character
    run.context.remote_view_inventory = require_inventory(player)
    run.context.remote_view_build_position = position_near_player(run, -16, -18)
    prepare_buildable_ground(surface, run.context.remote_view_build_position, 2)
    player.set_controller {
        type = defines.controllers.remote,
        surface = surface,
        position = character.position,
    }
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function remote_view_spiderbot_deployed(run)
    local player = require_player(run)
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.remote
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == run.context.remote_view_character
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_build_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    create_small_pole_ghost(surface, player, run.context.remote_view_build_position)
    mark_expected_task(run, "build_ghost")
end

function remote_view_build_complete(run)
    local player = require_player(run)
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.remote_view_build_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_upgrade_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    run.context.remote_view_upgrade_position = position_near_player(run, -13, -18)
    run.context.remote_view_upgrade_result_start_count = inventory.get_item_count({ name = "transport-belt", quality = "normal" })
    prepare_buildable_ground(surface, run.context.remote_view_upgrade_position, 2)
    insert_into_inventory(inventory, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local belt = surface.create_entity {
        name = "transport-belt",
        position = run.context.remote_view_upgrade_position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create remote-view upgrade belt") end
    local ok = belt.order_upgrade {
        target = { name = "fast-transport-belt", quality = "normal" },
        force = player.force,
        player = player,
    }
    if not ok then error("failed to order remote-view belt upgrade") end
    mark_expected_task(run, "upgrade_entity")
end

function remote_view_upgrade_complete(run)
    local player = require_player(run)
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and find_entity_near("fast-transport-belt", run.context.remote_view_upgrade_position, nil, run.context.surface_name) ~= nil
        and inventory.get_item_count({ name = "transport-belt", quality = "normal" }) > run.context.remote_view_upgrade_result_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    run.context.remote_view_deconstruct_position = position_near_player(run, -10, -18)
    run.context.remote_view_deconstruct_start_count = inventory.get_item_count({ name = "wooden-chest", quality = "normal" })
    prepare_buildable_ground(surface, run.context.remote_view_deconstruct_position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = run.context.remote_view_deconstruct_position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create remote-view deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order remote-view chest deconstruction")
    end
    mark_expected_task(run, "deconstruct_entity")
end

function remote_view_deconstruction_complete(run)
    local player = require_player(run)
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and find_entity_near("wooden-chest", run.context.remote_view_deconstruct_position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "wooden-chest", quality = "normal" }) > run.context.remote_view_deconstruct_start_count
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_item_request_proxy(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    run.context.remote_view_item_request_position = position_near_player(run, -7, -18)
    prepare_buildable_ground(surface, run.context.remote_view_item_request_position, 2)
    insert_into_inventory(inventory, { name = "speed-module", count = 1, quality = "normal" })
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = run.context.remote_view_item_request_position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create remote-view item request assembler") end
    run.context.remote_view_item_request_target = assembler
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = run.context.remote_view_item_request_position,
        force = player.force,
        target = assembler,
        modules = {
            { id = { name = "speed-module", quality = "normal" }, items = { in_inventory = { { inventory = defines.inventory.crafter_modules, stack = 0, count = 1 } } } },
        },
    }
    if not proxy then error("failed to create remote-view item request proxy") end
    mark_expected_task(run, "insert_items")
end

function remote_view_item_request_complete(run)
    local player = require_player(run)
    local assembler = run.context.remote_view_item_request_target
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_tile_ghost(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    run.context.remote_view_tile_position = position_near_player(run, -4, -18)
    prepare_buildable_ground(surface, run.context.remote_view_tile_position, 2)
    insert_into_inventory(inventory, { name = "stone-brick", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = run.context.remote_view_tile_position,
        force = player.force,
    }
    if not ghost then error("failed to create remote-view stone-path tile ghost") end
    mark_expected_task(run, "build_tile")
end

function remote_view_tile_build_complete(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.remote_view_tile_position
    local tile = surface.get_tile(position.x, position.y)
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name == "stone-path"
        and all_spiderbots_idle(run.player_index)
end

function create_remote_view_tile_deconstruction_order(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view")
    end
    local position = run.context.remote_view_tile_position
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("remote-view stone-path tile was not available for deconstruction")
    end
    run.context.remote_view_tile_deconstruct_start_count = inventory.get_item_count({ name = "stone-brick", quality = "normal" })
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order remote-view tile deconstruction")
    end
    mark_expected_task(run, "deconstruct_tile")
end

function remote_view_tile_deconstruction_complete(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local inventory = run.context.remote_view_inventory
    local position = run.context.remote_view_tile_position
    local tile = surface.get_tile(position.x, position.y)
    if not (inventory and inventory.valid) then
        error("missing remote-view character inventory")
    end
    return player.controller_type == defines.controllers.remote
        and expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and inventory.get_item_count({ name = "stone-brick", quality = "normal" }) > run.context.remote_view_tile_deconstruct_start_count
        and all_spiderbots_idle(run.player_index)
end

function recall_remote_view_spiderbot(run)
    local player = require_player(run)
    if player.controller_type ~= defines.controllers.remote then
        error("player is not in remote view for recall")
    end
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "toggle-spiderbots",
    })
end

function remote_view_spiderbot_recalled(run)
    local player = require_player(run)
    return player.controller_type == defines.controllers.remote
        and storage.spiderbots_enabled[run.player_index] == false
        and spiderbot_count(run.player_index) == 0
end

function restore_character_controller_after_remote_view(run)
    local player = require_player(run)
    local character = run.context.remote_view_character
    if not (character and character.valid) then
        error("missing character to restore after remote view")
    end
    player.set_controller {
        type = defines.controllers.character,
        character = character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function character_controller_restored(run)
    local player = require_player(run)
    return player.controller_type == defines.controllers.character
end

function trigger_source_known_projectile_registration(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 0)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create source-known projectile spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function source_known_projectile_registered(run)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    return spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not projectiles or #projectiles == 0)
end

function trigger_cross_surface_projectile_registration(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local source_surface = character.surface
    local target_surface = ensure_surface(CROSS_SURFACE_REGISTRATION_TEST_SURFACE_NAME, START_POSITION)
    prepare_buildable_ground(target_surface, START_POSITION, 12)
    local spawn_position = p(0, 0)
    local spiderbot = target_surface.create_entity {
        name = "spiderbot",
        position = spawn_position,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create cross-surface registration spiderbot") end
    run.context.cross_surface_registration_source_surface_index = source_surface.index
    run.context.cross_surface_registration_unit_number = spiderbot.unit_number
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function cross_surface_projectile_registered_and_relinked(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.cross_surface_registration_unit_number
        and spiderbot.surface_index == run.context.cross_surface_registration_source_surface_index
        and spiderbot.surface == character.surface
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function trigger_source_known_projectile_owner_isolation(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 0.5)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    local other_player_index = 870000 + player.index
    run.context.projectile_owner_isolation_other_player_index = other_player_index
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    storage.spiderbot_projectiles[other_player_index] = {
        {
            origin = p(character.position.x + 1, character.position.y),
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create owner-isolation projectile spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function source_known_projectile_owner_isolated(run)
    local player_projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    local other_player_index = run.context.projectile_owner_isolation_other_player_index
    local other_projectiles = other_player_index and storage.spiderbot_projectiles and storage.spiderbot_projectiles[other_player_index]
    local isolated = spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not player_projectiles or #player_projectiles == 0)
        and other_projectiles
        and #other_projectiles == 1
    if isolated then
        storage.spiderbot_projectiles[other_player_index] = nil
        run.context.projectile_owner_isolation_other_player_index = nil
    end
    return isolated
end

function trigger_custom_label_registration(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 1)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    run.context.custom_spiderbot_label = "Codex test spiderbot"
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create custom-label spiderbot") end
    spiderbot.entity_label = run.context.custom_spiderbot_label
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function custom_label_registration_preserved(run)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.entity_label == run.context.custom_spiderbot_label
        and all_spiderbots_idle(run.player_index)
end

function trigger_default_label_registration(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 1)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    local initial_label = game.backer_names and game.backer_names[1]
    if not initial_label then error("test requires at least one backer name") end
    run.context.default_spiderbot_initial_label = initial_label
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create default-label spiderbot") end
    spiderbot.entity_label = initial_label
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function default_label_registration_assigned(run)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.entity_label
        and spiderbot.entity_label ~= ""
        and all_spiderbots_idle(run.player_index)
end

function trigger_source_missing_projectile_registration(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 2)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create source-missing projectile spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
    })
end

function source_missing_projectile_registered(run)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    return spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not projectiles or #projectiles == 0)
end

function trigger_source_missing_projectile_stale_owner_cleanup(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, 2.5)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    local stale_player_index
    for candidate = 65536, 1, -1 do
        if candidate ~= player.index and not game.get_player(candidate) then
            stale_player_index = candidate
            break
        end
    end
    if not stale_player_index then
        error("failed to find an unused in-range player index")
    end
    run.context.projectile_stale_owner_index = stale_player_index
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    storage.spiderbot_projectiles[stale_player_index] = {
        {
            origin = p(character.position.x - 1, character.position.y),
            destination = destination,
            surface = surface,
            tick = game.tick,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create stale-owner source-missing projectile spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
    })
end

function source_missing_projectile_stale_owner_cleaned_up(run)
    local player_projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    local stale_player_index = run.context.projectile_stale_owner_index
    local stale_projectiles = stale_player_index and storage.spiderbot_projectiles and storage.spiderbot_projectiles[stale_player_index]
    local cleaned = spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not player_projectiles or #player_projectiles == 0)
        and (not stale_projectiles or #stale_projectiles == 0)
    if cleaned then
        if stale_player_index then
            storage.spiderbot_projectiles[stale_player_index] = nil
        end
        run.context.projectile_stale_owner_index = nil
    end
    return cleaned
end

function trigger_expired_projectile_cleanup(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 6, 0)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    storage.spiderbot_projectiles = storage.spiderbot_projectiles or {}
    storage.spiderbot_projectiles[player.index] = {
        {
            origin = character.position,
            destination = position_near_player(run, -6, 0),
            surface = surface,
            tick = game.tick - 60 * 61,
        },
    }
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create expired-cleanup projectile spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
end

function expired_projectile_cleaned_up(run)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    return spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
        and (not projectiles or #projectiles == 0)
end

function create_neutral_force_tasks(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local build_position = position_near_player(run, -9, -10)
    run.context.neutral_build_position = build_position
    prepare_buildable_ground(surface, build_position, 3)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = build_position,
        force = game.forces.neutral,
        quality = "normal",
    }
    if not ghost then error("failed to create neutral-force ghost") end
    mark_expected_task(run, "build_ghost")
end

function neutral_force_tasks_complete(run)
    if not expected_task_was_seen(run) then return false end
    local built = find_entity_near("small-electric-pole", run.context.neutral_build_position, nil, run.context.surface_name)
    return built
        and built.valid
        and built.force.name == "neutral"
        and all_spiderbots_idle(run.player_index)
end

function friendly_test_force(player)
    local force_name = "spiderbots-friendly-test"
    local friendly_force = game.forces[force_name] or game.create_force(force_name)
    player.force.set_friend(friendly_force.name, true)
    friendly_force.set_friend(player.force.name, true)
    player.force.set_cease_fire(friendly_force.name, true)
    friendly_force.set_cease_fire(player.force.name, true)
    return friendly_force
end

function create_friendly_force_ghost_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -6, -12)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = friendly_force,
        quality = "normal",
    }
    if not ghost then error("failed to create friendly-force ghost") end
    run.context.friendly_force_ghost = ghost
    run.context.friendly_force_ghost_position = position
    run.context.friendly_force_ghost_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_ghost_was_ignored(run)
    if game.tick - run.context.friendly_force_ghost_started_tick < 60 then return false end
    local ghost = run.context.friendly_force_ghost
    local position = run.context.friendly_force_ghost_position
    local built = find_entity_near("small-electric-pole", position, nil, run.context.surface_name)
    local ignored = ghost
        and ghost.valid
        and built == nil
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        run.context.friendly_force_ghost = nil
    end
    return ignored
end

function create_friendly_force_deconstruction_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -8, -12)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = friendly_force,
        quality = "normal",
    }
    if not chest then error("failed to create friendly-force deconstruction chest") end
    if not chest.order_deconstruction(friendly_force) then
        error("failed to order friendly-force chest deconstruction")
    end
    run.context.friendly_force_deconstruct_chest = chest
    run.context.friendly_force_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_deconstruction_was_ignored(run)
    if game.tick - run.context.friendly_force_deconstruct_started_tick < 60 then return false end
    local chest = run.context.friendly_force_deconstruct_chest
    local ignored = chest
        and chest.valid
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        chest.destroy({ raise_destroy = true })
        run.context.friendly_force_deconstruct_chest = nil
    end
    return ignored
end

function create_friendly_force_tile_ghost_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -10, -12)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = friendly_force,
    }
    if not ghost then error("failed to create friendly-force tile ghost") end
    run.context.friendly_force_tile_ghost = ghost
    run.context.friendly_force_tile_position = position
    run.context.friendly_force_tile_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_tile_ghost_was_ignored(run)
    if game.tick - run.context.friendly_force_tile_started_tick < 60 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.friendly_force_tile_position
    local tile = surface.get_tile(position.x, position.y)
    local ghost = run.context.friendly_force_tile_ghost
    local ignored = ghost
        and ghost.valid
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        run.context.friendly_force_tile_ghost = nil
    end
    return ignored
end

function create_friendly_force_upgrade_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -12, -12)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = friendly_force,
        quality = "normal",
    }
    if not belt then error("failed to create friendly-force upgrade belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = friendly_force,
        } then
        error("failed to order friendly-force belt upgrade")
    end
    run.context.friendly_force_upgrade_belt = belt
    run.context.friendly_force_upgrade_position = position
    run.context.friendly_force_upgrade_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_upgrade_was_ignored(run)
    if game.tick - run.context.friendly_force_upgrade_started_tick < 60 then return false end
    local belt = run.context.friendly_force_upgrade_belt
    local upgraded = find_entity_near("fast-transport-belt", run.context.friendly_force_upgrade_position, nil, run.context.surface_name)
    local ignored = belt
        and belt.valid
        and upgraded == nil
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        belt.destroy({ raise_destroy = true })
        run.context.friendly_force_upgrade_belt = nil
    end
    return ignored
end

function create_friendly_force_item_request_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -14, -12)
    prepare_buildable_ground(surface, position, 3)
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = friendly_force,
        quality = "normal",
    }
    if not assembler then error("failed to create friendly-force item request assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = friendly_force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create friendly-force item request proxy") end
    run.context.friendly_force_item_request_assembler = assembler
    run.context.friendly_force_item_request_proxy = proxy
    run.context.friendly_force_item_request_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_item_request_was_ignored(run)
    if game.tick - run.context.friendly_force_item_request_started_tick < 60 then return false end
    local assembler = run.context.friendly_force_item_request_assembler
    local proxy = run.context.friendly_force_item_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local ignored = assembler
        and assembler.valid
        and proxy
        and proxy.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        proxy.destroy({ raise_destroy = true })
        assembler.destroy({ raise_destroy = true })
        run.context.friendly_force_item_request_proxy = nil
        run.context.friendly_force_item_request_assembler = nil
    end
    return ignored
end

function create_friendly_force_tile_deconstruction_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local friendly_force = friendly_test_force(player)
    local position = position_near_player(run, -16, -12)
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to prepare friendly-force tile deconstruction target")
    end
    if not tile.order_deconstruction(friendly_force) then
        error("failed to order friendly-force tile deconstruction")
    end
    run.context.friendly_force_tile_deconstruct_position = position
    run.context.friendly_force_tile_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function friendly_force_tile_deconstruction_was_ignored(run)
    if game.tick - run.context.friendly_force_tile_deconstruct_started_tick < 60 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.friendly_force_tile_deconstruct_position
    local tile = surface.get_tile(position.x, position.y)
    local ignored = tile
        and tile.valid
        and tile.name == "stone-path"
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        set_square_tiles(surface, position, 0, natural_ground_tile_name())
    end
    return ignored
end

function create_fish_deconstruction_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("fish")
    require_tile_prototype("water")
    local position = position_near_player(run, -14, -12)
    set_square_tiles(surface, position, 0, "water")
    local fish = surface.create_entity {
        name = "fish",
        position = position,
    }
    if not fish then error("failed to create fish deconstruction target") end
    if not fish.order_deconstruction(player.force, player) then
        error("failed to order fish deconstruction")
    end
    run.context.fish_deconstruction_target = fish
    run.context.fish_deconstruction_position = position
    run.context.fish_deconstruction_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function fish_deconstruction_was_ignored(run)
    if game.tick - run.context.fish_deconstruction_started_tick < 60 then return false end
    local fish = run.context.fish_deconstruction_target
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = fish
        and fish.valid
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        fish.destroy({ raise_destroy = true })
        run.context.fish_deconstruction_target = nil
        local surface = game.surfaces[run.context.surface_name]
        set_square_tiles(surface, run.context.fish_deconstruction_position, 0, natural_ground_tile_name())
    end
    return ignored
end

function create_other_force_ghost_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 4, -10)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = game.forces.enemy,
        quality = "normal",
    }
    if not ghost then error("failed to create other-force ghost") end
    run.context.other_force_ghost = ghost
    run.context.other_force_ghost_position = position
    run.context.other_force_ghost_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_ghost_was_ignored(run)
    if game.tick - run.context.other_force_ghost_started_tick < 60 then return false end
    local ghost = run.context.other_force_ghost
    local position = run.context.other_force_ghost_position
    local built = find_entity_near("small-electric-pole", position, nil, run.context.surface_name)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = ghost
        and ghost.valid
        and not built
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        run.context.other_force_ghost = nil
    end
    return ignored
end

function create_other_force_deconstruction_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 6, -10)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = game.forces.enemy,
        quality = "normal",
    }
    if not chest then error("failed to create other-force deconstruction chest") end
    if not chest.order_deconstruction(game.forces.enemy) then
        error("failed to order other-force chest deconstruction")
    end
    run.context.other_force_deconstruct_chest = chest
    run.context.other_force_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_deconstruction_was_ignored(run)
    if game.tick - run.context.other_force_deconstruct_started_tick < 60 then return false end
    local chest = run.context.other_force_deconstruct_chest
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = chest
        and chest.valid
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        chest.destroy({ raise_destroy = true })
        run.context.other_force_deconstruct_chest = nil
    end
    return ignored
end

function create_other_force_upgrade_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 8, -10)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = game.forces.enemy,
        quality = "normal",
    }
    if not belt then error("failed to create other-force upgrade belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = game.forces.enemy,
        } then
        error("failed to order other-force belt upgrade")
    end
    run.context.other_force_upgrade_belt = belt
    run.context.other_force_upgrade_position = position
    run.context.other_force_upgrade_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_upgrade_was_ignored(run)
    if game.tick - run.context.other_force_upgrade_started_tick < 60 then return false end
    local belt = run.context.other_force_upgrade_belt
    local upgraded = find_entity_near("fast-transport-belt", run.context.other_force_upgrade_position, nil, run.context.surface_name)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = belt
        and belt.valid
        and not upgraded
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        belt.destroy({ raise_destroy = true })
        run.context.other_force_upgrade_belt = nil
    end
    return ignored
end

function create_other_force_item_request_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 10, -10)
    prepare_buildable_ground(surface, position, 3)
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = game.forces.enemy,
        quality = "normal",
    }
    if not assembler then error("failed to create other-force item request assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = game.forces.enemy,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create other-force item request proxy") end
    run.context.other_force_item_request_assembler = assembler
    run.context.other_force_item_request_proxy = proxy
    run.context.other_force_item_request_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_item_request_was_ignored(run)
    if game.tick - run.context.other_force_item_request_started_tick < 60 then return false end
    local assembler = run.context.other_force_item_request_assembler
    local proxy = run.context.other_force_item_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = assembler
        and assembler.valid
        and proxy
        and proxy.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        proxy.destroy({ raise_destroy = true })
        assembler.destroy({ raise_destroy = true })
        run.context.other_force_item_request_proxy = nil
        run.context.other_force_item_request_assembler = nil
    end
    return ignored
end

function create_other_force_tile_ghost_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 12, -10)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = game.forces.enemy,
    }
    if not ghost then error("failed to create other-force tile ghost") end
    run.context.other_force_tile_ghost = ghost
    run.context.other_force_tile_ghost_position = position
    run.context.other_force_tile_ghost_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_tile_ghost_was_ignored(run)
    if game.tick - run.context.other_force_tile_ghost_started_tick < 60 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local ghost = run.context.other_force_tile_ghost
    local position = run.context.other_force_tile_ghost_position
    local tile = surface.get_tile(position.x, position.y)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = ghost
        and ghost.valid
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        run.context.other_force_tile_ghost = nil
    end
    return ignored
end

function create_other_force_tile_deconstruction_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 14, -10)
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to prepare other-force tile deconstruction target")
    end
    if not tile.order_deconstruction(game.forces.enemy) then
        error("failed to order other-force tile deconstruction")
    end
    run.context.other_force_tile_deconstruct_position = position
    run.context.other_force_tile_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function other_force_tile_deconstruction_was_ignored(run)
    if game.tick - run.context.other_force_tile_deconstruct_started_tick < 60 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.other_force_tile_deconstruct_position
    local tile = surface.get_tile(position.x, position.y)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = tile
        and tile.valid
        and tile.name == "stone-path"
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        set_square_tiles(surface, position, 0, natural_ground_tile_name())
    end
    return ignored
end

function create_unbuildable_ghosts_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    local entity_position = position_near_player(run, 10, -10)
    local tile_position = position_near_player(run, 12, -10)
    prepare_buildable_ground(surface, entity_position, 2)
    prepare_buildable_ground(surface, tile_position, 2)
    local entity_ghost = create_small_pole_ghost(surface, player, entity_position)
    local tile_ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = tile_position,
        force = player.force,
    }
    if not tile_ghost then error("failed to create unbuildable tile ghost") end
    run.context.unbuildable_entity_ghost = entity_ghost
    run.context.unbuildable_entity_position = entity_position
    run.context.unbuildable_tile_ghost = tile_ghost
    run.context.unbuildable_tile_position = tile_position
    run.context.unbuildable_ghosts_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function unbuildable_ghosts_were_ignored(run)
    if game.tick - run.context.unbuildable_ghosts_started_tick < 60 then return false end
    local entity_ghost = run.context.unbuildable_entity_ghost
    local tile_ghost = run.context.unbuildable_tile_ghost
    local built_entity = find_entity_near("small-electric-pole", run.context.unbuildable_entity_position, nil, run.context.surface_name)
    local surface = game.surfaces[run.context.surface_name]
    local tile = surface.get_tile(run.context.unbuildable_tile_position.x, run.context.unbuildable_tile_position.y)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = entity_ghost
        and entity_ghost.valid
        and tile_ghost
        and tile_ghost.valid
        and not built_entity
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        entity_ghost.destroy({ raise_destroy = true })
        tile_ghost.destroy({ raise_destroy = true })
        run.context.unbuildable_entity_ghost = nil
        run.context.unbuildable_tile_ghost = nil
    end
    return ignored
end

function create_terrain_invalid_entity_ghost(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("water")
    require_item_prototype("small-electric-pole")
    local position = position_near_player(run, 14, -10)
    run.context.terrain_invalid_ghost_position = position
    run.context.terrain_invalid_ghost_original_tiles = capture_square_tiles(surface, position, 1)
    set_square_tiles(surface, position, 1, "water")
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.terrain_invalid_ghost_start_poles = inventory.get_item_count({ name = "small-electric-pole", quality = "normal" })
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not ghost then error("failed to create terrain-invalid entity ghost") end
    run.context.terrain_invalid_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function terrain_invalid_entity_ghost_preserved_inventory(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.terrain_invalid_ghost_position
    local ghost = run.context.terrain_invalid_ghost
    local tile = position and surface.get_tile(position.x, position.y)
    local preserved = expected_task_was_seen(run)
        and ghost
        and ghost.valid
        and position
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "small-electric-pole", quality = "normal" }) >= run.context.terrain_invalid_ghost_start_poles
        and tile
        and tile.valid
        and tile.name == "water"
        and first_spiderbot_idle_without_task(run)
    if preserved then
        ghost.destroy({ raise_destroy = true })
        if run.context.terrain_invalid_ghost_original_tiles then
            surface.set_tiles(run.context.terrain_invalid_ghost_original_tiles)
        else
            set_square_tiles(surface, position, 1, natural_ground_tile_name())
        end
        run.context.terrain_invalid_ghost = nil
        run.context.terrain_invalid_ghost_original_tiles = nil
    end
    return preserved
end

function create_missing_upgrade_item_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "fast-transport-belt", quality = "normal" })
    local position = position_near_player(run, 16, -10)
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create missing-upgrade-item belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order missing-upgrade-item belt upgrade")
    end
    run.context.missing_upgrade_item_belt = belt
    run.context.missing_upgrade_item_position = position
    run.context.missing_upgrade_item_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function missing_upgrade_item_was_ignored(run)
    if game.tick - run.context.missing_upgrade_item_started_tick < 60 then return false end
    local belt = run.context.missing_upgrade_item_belt
    local upgraded = find_entity_near("fast-transport-belt", run.context.missing_upgrade_item_position, nil, run.context.surface_name)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = belt
        and belt.valid
        and not upgraded
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    return ignored
end

function supply_missing_upgrade_item(run)
    local player = require_player(run)
    local belt = run.context.missing_upgrade_item_belt
    if not (belt and belt.valid) then
        error("missing upgrade target before supplying item")
    end
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    mark_expected_task(run, "upgrade_entity")
end

function missing_upgrade_item_completed_after_supply(run)
    local upgraded = find_entity_near("fast-transport-belt", run.context.missing_upgrade_item_position, nil, run.context.surface_name)
    local completed = expected_task_was_seen(run)
        and upgraded
        and upgraded.valid
        and all_spiderbots_idle(run.player_index)
    if completed then
        upgraded.destroy({ raise_destroy = true })
        run.context.missing_upgrade_item_belt = nil
    end
    return completed
end

function create_full_inventory_deconstruction_to_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "wooden-chest", quality = "normal" })
    run.context.full_inventory_deconstruct_filler_item_name = "iron-plate"
    run.context.full_inventory_deconstruct_filler_start_count = inventory.get_item_count({ name = run.context.full_inventory_deconstruct_filler_item_name, quality = "normal" })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.full_inventory_deconstruct_filler_item_name, count = 100, quality = "normal" },
        { name = "wooden-chest", count = 1, quality = "normal" }
    )
    local position = position_near_player(run, 14, -10)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create full-inventory deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order full-inventory deconstruction chest")
    end
    run.context.full_inventory_deconstruct_chest = chest
    run.context.full_inventory_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function full_inventory_deconstruction_was_ignored(run)
    if game.tick - run.context.full_inventory_deconstruct_started_tick < 60 then return false end
    local chest = run.context.full_inventory_deconstruct_chest
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    return chest
        and chest.valid
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
end

function free_inventory_for_deconstruction(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.full_inventory_deconstruct_chest
    if not (chest and chest.valid) then
        error("missing deconstruction target before freeing inventory")
    end
    local filler_item_name = run.context.full_inventory_deconstruct_filler_item_name or "iron-plate"
    inventory.remove({ name = filler_item_name, count = 100, quality = "normal" })
    mark_expected_task(run, "deconstruct_entity")
end

function full_inventory_deconstruction_completed_after_space(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.full_inventory_deconstruct_chest
    local completed = expected_task_was_seen(run)
        and (not chest or not chest.valid)
        and inventory.get_item_count({ name = "wooden-chest", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
    if completed then
        run.context.full_inventory_deconstruct_chest = nil
    end
    return completed
end

function cleanup_full_inventory_deconstruction_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.full_inventory_deconstruct_chest
    if chest and chest.valid then
        chest.destroy({ raise_destroy = true })
    end
    local filler_item_name = run.context.full_inventory_deconstruct_filler_item_name or "iron-plate"
    local start_count = run.context.full_inventory_deconstruct_filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    run.context.full_inventory_deconstruct_chest = nil
end

function create_quality_content_space_deconstruction_to_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local quality = quality_under_test(run)
    require_item_prototype("speed-module")
    remove_all_qualities_from_main_inventory(player, "speed-module")
    remove_from_main_inventory(player, { name = "wooden-chest", quality = "normal" })
    insert(player, { name = "wooden-chest", count = 1, quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    run.context.quality_content_space_filler_item_name = "iron-plate"
    run.context.quality_content_space_filler_start_count = inventory.get_item_count({ name = run.context.quality_content_space_filler_item_name, quality = "normal" })
    run.context.quality_content_space_quality_start_count = inventory.get_item_count({ name = "speed-module", quality = quality })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.quality_content_space_filler_item_name, count = 100, quality = "normal" },
        { name = "speed-module", count = 1, quality = quality }
    )
    if not inventory.can_insert({ name = "wooden-chest", count = 1, quality = "normal" }) then
        error("quality-content space test needs room for the mined chest result")
    end
    if not inventory.can_insert({ name = "speed-module", count = 1, quality = "normal" }) then
        error("quality-content space test needs normal speed-module space")
    end
    local position = position_near_player(run, 19, -10)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create quality-content space chest") end
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    if not (chest_inventory and chest_inventory.valid) then
        error("missing quality-content space chest inventory")
    end
    if chest_inventory.insert({ name = "speed-module", count = 1, quality = quality }) < 1 then
        error("failed to seed quality-content space chest")
    end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order quality-content space deconstruction")
    end
    run.context.quality_content_space_chest = chest
    run.context.quality_content_space_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function quality_content_space_deconstruction_was_ignored(run)
    if game.tick - run.context.quality_content_space_started_tick < 60 then return false end
    local chest = run.context.quality_content_space_chest
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    return chest
        and chest.valid
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
end

function free_inventory_for_quality_content_space(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.quality_content_space_chest
    if not (chest and chest.valid) then
        error("missing quality-content space target before freeing inventory")
    end
    local filler_item_name = run.context.quality_content_space_filler_item_name or "iron-plate"
    inventory.remove({ name = filler_item_name, count = 100, quality = "normal" })
    mark_expected_task(run, "deconstruct_entity")
end

function quality_content_space_deconstruction_completed_after_space(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.quality_content_space_chest
    local quality = quality_under_test(run)
    local completed = expected_task_was_seen(run)
        and (not chest or not chest.valid)
        and inventory.get_item_count({ name = "speed-module", quality = quality }) > run.context.quality_content_space_quality_start_count
        and all_spiderbots_idle(run.player_index)
    if completed then
        run.context.quality_content_space_chest = nil
    end
    return completed
end

function cleanup_quality_content_space_deconstruction(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local chest = run.context.quality_content_space_chest
    if chest and chest.valid then
        chest.destroy({ raise_destroy = true })
    end
    local filler_item_name = run.context.quality_content_space_filler_item_name or "iron-plate"
    local start_count = run.context.quality_content_space_filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    remove_all_qualities_from_main_inventory(player, "speed-module")
    run.context.quality_content_space_chest = nil
end

function create_full_inventory_tile_deconstruction_to_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    run.context.full_inventory_tile_deconstruct_filler_item_name = "iron-plate"
    run.context.full_inventory_tile_deconstruct_filler_start_count = inventory.get_item_count({ name = run.context.full_inventory_tile_deconstruct_filler_item_name, quality = "normal" })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.full_inventory_tile_deconstruct_filler_item_name, count = 100, quality = "normal" },
        { name = "stone-brick", count = 1, quality = "normal" }
    )
    local position = position_near_player(run, 18, -10)
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to prepare full-inventory tile deconstruction target")
    end
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order full-inventory tile deconstruction")
    end
    run.context.full_inventory_tile_deconstruct_position = position
    run.context.full_inventory_tile_deconstruct_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function full_inventory_tile_deconstruction_was_ignored(run)
    if game.tick - run.context.full_inventory_tile_deconstruct_started_tick < 60 then return false end
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.full_inventory_tile_deconstruct_position
    local tile = surface.get_tile(position.x, position.y)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    return tile
        and tile.valid
        and tile.name == "stone-path"
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
end

function free_inventory_for_tile_deconstruction(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.full_inventory_tile_deconstruct_position
    local tile = position and surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("missing tile deconstruction target before freeing inventory")
    end
    local filler_item_name = run.context.full_inventory_tile_deconstruct_filler_item_name or "iron-plate"
    inventory.remove({ name = filler_item_name, count = 100, quality = "normal" })
    mark_expected_task(run, "deconstruct_tile")
end

function full_inventory_tile_deconstruction_completed_after_space(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.full_inventory_tile_deconstruct_position
    local tile = position and surface.get_tile(position.x, position.y)
    return expected_task_was_seen(run)
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and all_spiderbots_idle(run.player_index)
end

function cleanup_full_inventory_tile_deconstruction_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.full_inventory_tile_deconstruct_position
    if position then
        set_square_tiles(surface, position, 0, natural_ground_tile_name())
    end
    local filler_item_name = run.context.full_inventory_tile_deconstruct_filler_item_name or "iron-plate"
    local start_count = run.context.full_inventory_tile_deconstruct_filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    run.context.full_inventory_tile_deconstruct_position = nil
end

function create_missing_item_request_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    local position = position_near_player(run, 16, -10)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create missing-item request assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create missing-item request proxy") end
    run.context.missing_item_request_assembler = assembler
    run.context.missing_item_request_proxy = proxy
    run.context.missing_item_request_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function missing_item_request_was_ignored(run)
    if game.tick - run.context.missing_item_request_started_tick < 60 then return false end
    local assembler = run.context.missing_item_request_assembler
    local proxy = run.context.missing_item_request_proxy
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = assembler
        and assembler.valid
        and proxy
        and proxy.valid
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    return ignored
end

function supply_missing_item_request_item(run)
    local player = require_player(run)
    local assembler = run.context.missing_item_request_assembler
    local proxy = run.context.missing_item_request_proxy
    if not (assembler and assembler.valid and proxy and proxy.valid) then
        error("missing item request target before supplying item")
    end
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    mark_expected_task(run, "insert_items")
end

function missing_item_request_completed_after_supply(run)
    local assembler = run.context.missing_item_request_assembler
    if not (assembler and assembler.valid) then return false end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    local completed = expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
    if completed then
        local proxy = run.context.missing_item_request_proxy
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        run.context.missing_item_request_proxy = nil
        run.context.missing_item_request_assembler = nil
    end
    return completed
end

function create_upgrading_target_request_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("assembling-machine-3")
    require_item_prototype("assembling-machine-3")
    remove_from_main_inventory(player, { name = "assembling-machine-3", quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 17, -10)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create upgrading-target request assembler") end
    if not assembler.order_upgrade {
            target = { name = "assembling-machine-3", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order upgrading-target assembler upgrade")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create upgrading-target item request proxy") end
    run.context.upgrading_target_request_assembler = assembler
    run.context.upgrading_target_request_proxy = proxy
    run.context.upgrading_target_request_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function upgrading_target_request_was_ignored(run)
    if game.tick - run.context.upgrading_target_request_started_tick < 60 then return false end
    local assembler = run.context.upgrading_target_request_assembler
    local proxy = run.context.upgrading_target_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = assembler
        and assembler.valid
        and assembler.to_be_upgraded()
        and proxy
        and proxy.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
    if ignored then
        proxy.destroy({ raise_destroy = true })
        assembler.destroy({ raise_destroy = true })
        run.context.upgrading_target_request_proxy = nil
        run.context.upgrading_target_request_assembler = nil
    end
    return ignored
end

function create_empty_item_request_proxy_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -10)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create empty-proxy assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            { id = { name = "speed-module", quality = "normal" }, items = { in_inventory = { { inventory = defines.inventory.crafter_modules, stack = 0, count = 1 } } } },
        },
    }
    if not proxy then error("failed to create empty item-request-proxy") end
    proxy.insert_plan = {}
    proxy.removal_plan = {}
    run.context.empty_item_proxy_assembler = assembler
    run.context.empty_item_proxy = proxy
    run.context.empty_item_proxy_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function empty_item_request_proxy_was_ignored(run)
    if game.tick - run.context.empty_item_proxy_started_tick < 60 then return false end
    local assembler = run.context.empty_item_proxy_assembler
    local proxy = run.context.empty_item_proxy
    local ignored = assembler
        and assembler.valid
        and (not proxy or not proxy.valid or (not proxy.insert_plan[1] and not proxy.removal_plan[1]))
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        run.context.empty_item_proxy = nil
        run.context.empty_item_proxy_assembler = nil
    end
    return ignored
end

function create_destroyed_target_item_request_proxy_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 15, -13)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create destroyed-target proxy assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            { id = { name = "speed-module", quality = "normal" }, items = { in_inventory = { { inventory = defines.inventory.crafter_modules, stack = 0, count = 1 } } } },
        },
    }
    if not proxy then error("failed to create destroyed-target item-request-proxy") end
    assembler.destroy({ raise_destroy = true })
    run.context.destroyed_target_item_proxy = proxy
    run.context.destroyed_target_item_proxy_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function destroyed_target_item_request_proxy_was_ignored(run)
    if game.tick - run.context.destroyed_target_item_proxy_started_tick < 60 then return false end
    local proxy = run.context.destroyed_target_item_proxy
    local ignored = (not proxy or not proxy.valid or not proxy.proxy_target)
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        run.context.destroyed_target_item_proxy = nil
    end
    return ignored
end

function create_damaged_repair_target_to_ignore(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_entity_prototype("stone-wall")
    require_item_prototype("repair-pack")
    insert(player, { name = "repair-pack", count = 1, quality = "normal" })
    local position = position_near_player(run, 18, -13)
    prepare_buildable_ground(surface, position, 3)
    local wall = surface.create_entity {
        name = "stone-wall",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not wall then error("failed to create damaged repair target") end
    wall.health = math.max(1, wall.max_health * 0.5)
    run.context.damaged_repair_target = wall
    run.context.damaged_repair_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function damaged_repair_target_was_ignored(run)
    if game.tick - run.context.damaged_repair_started_tick < 60 then return false end
    local wall = run.context.damaged_repair_target
    local ignored = wall
        and wall.valid
        and wall.health < wall.max_health
        and next(run.context.seen_tasks or {}) == nil
        and first_spiderbot_idle_without_task(run)
    if ignored then
        wall.destroy({ raise_destroy = true })
        remove_from_main_inventory(require_player(run), { name = "repair-pack", quality = "normal" })
        run.context.damaged_repair_target = nil
    end
    return ignored
end

function create_full_inventory_removal_request_to_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    run.context.full_inventory_removal_filler_item_name = "iron-plate"
    run.context.full_inventory_removal_filler_start_count = inventory.get_item_count({ name = run.context.full_inventory_removal_filler_item_name, quality = "normal" })
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.full_inventory_removal_filler_item_name, count = 100, quality = "normal" },
        { name = "speed-module", count = 1, quality = "normal" }
    )
    local position = position_near_player(run, 18, -10)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create full-inventory removal assembler") end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing module inventory for full-inventory removal request")
    end
    if module_inventory.insert({ name = "speed-module", count = 1, quality = "normal" }) < 1 then
        error("failed to seed full-inventory removal module")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create full-inventory removal proxy") end
    run.context.full_inventory_removal_assembler = assembler
    run.context.full_inventory_removal_proxy = proxy
    run.context.full_inventory_removal_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
end

function full_inventory_removal_request_was_ignored(run)
    if game.tick - run.context.full_inventory_removal_started_tick < 60 then return false end
    local assembler = run.context.full_inventory_removal_assembler
    local proxy = run.context.full_inventory_removal_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    return assembler
        and assembler.valid
        and proxy
        and proxy.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 1
        and no_tasks_seen
        and first_spiderbot_idle_without_task(run)
end

function free_inventory_for_removal_request(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local assembler = run.context.full_inventory_removal_assembler
    local proxy = run.context.full_inventory_removal_proxy
    if not (assembler and assembler.valid and proxy and proxy.valid) then
        error("missing removal request target before freeing inventory")
    end
    local filler_item_name = run.context.full_inventory_removal_filler_item_name or "iron-plate"
    inventory.remove({ name = filler_item_name, count = 100, quality = "normal" })
    mark_expected_task(run, "insert_items")
end

function full_inventory_removal_completed_after_space(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local assembler = run.context.full_inventory_removal_assembler
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    return expected_task_was_seen(run)
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= 1
        and all_spiderbots_idle(run.player_index)
end

function cleanup_full_inventory_removal_request_ignore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local proxy = run.context.full_inventory_removal_proxy
    local assembler = run.context.full_inventory_removal_assembler
    if proxy and proxy.valid then
        proxy.destroy({ raise_destroy = true })
    end
    if assembler and assembler.valid then
        assembler.destroy({ raise_destroy = true })
    end
    local filler_item_name = run.context.full_inventory_removal_filler_item_name or "iron-plate"
    local start_count = run.context.full_inventory_removal_filler_start_count or 0
    local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
    if current_count > start_count then
        inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
    end
    run.context.full_inventory_removal_proxy = nil
    run.context.full_inventory_removal_assembler = nil
end

function create_assigned_item_removal_no_space_request(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    run.context.assigned_removal_no_space_filler_item_name = "iron-plate"
    run.context.assigned_removal_no_space_filler_start_count = inventory.get_item_count({
        name = run.context.assigned_removal_no_space_filler_item_name,
        quality = "normal",
    })
    run.context.assigned_removal_no_space_start_speed = inventory.get_item_count({ name = "speed-module", quality = "normal" })
    local position = position_near_player(run, 20, -10)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create assigned removal no-space assembler") end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing module inventory for assigned removal no-space reset")
    end
    if module_inventory.insert({ name = "speed-module", count = 1, quality = "normal" }) < 1 then
        error("failed to seed assigned removal no-space module")
    end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create assigned removal no-space proxy") end
    if not inventory.can_insert({ name = "speed-module", count = 1, quality = "normal" }) then
        error("assigned removal no-space reset requires initial inventory space")
    end
    run.context.assigned_removal_no_space_assembler = assembler
    run.context.assigned_removal_no_space_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function trigger_assigned_item_removal_no_space_reset(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local proxy = run.context.assigned_removal_no_space_proxy
    if not (proxy and proxy.valid) then
        error("missing assigned removal no-space proxy")
    end
    local spiderbot_data = assigned_task_for_target(run, "insert_items", proxy)
    if not spiderbot_data then return false end
    fill_inventory_until_cannot_insert(
        inventory,
        { name = run.context.assigned_removal_no_space_filler_item_name, count = 100, quality = "normal" },
        { name = "speed-module", count = 1, quality = "normal" }
    )
    return complete_assigned_task_now(spiderbot_data)
end

function assigned_item_removal_no_space_reset_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local assembler = run.context.assigned_removal_no_space_assembler
    local proxy = run.context.assigned_removal_no_space_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local reset = assembler
        and assembler.valid
        and proxy
        and proxy.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 1
        and inventory.get_item_count({ name = "speed-module", quality = "normal" }) == run.context.assigned_removal_no_space_start_speed
        and first_spiderbot_idle_without_task(run)
    if reset then
        proxy.destroy({ raise_destroy = true })
        assembler.destroy({ raise_destroy = true })
        local filler_item_name = run.context.assigned_removal_no_space_filler_item_name or "iron-plate"
        local start_count = run.context.assigned_removal_no_space_filler_start_count or 0
        local current_count = inventory.get_item_count({ name = filler_item_name, quality = "normal" })
        if current_count > start_count then
            inventory.remove({ name = filler_item_name, count = current_count - start_count, quality = "normal" })
        end
        run.context.assigned_removal_no_space_proxy = nil
        run.context.assigned_removal_no_space_assembler = nil
    end
    return reset
end

function create_vehicle_relink_assigned_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local ghost_position = position_near_player(run, 21, -10)
    prepare_buildable_ground(surface, ghost_position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    local car_position = position_near_player(run, 2, -10)
    prepare_buildable_ground(surface, car_position, 3)
    local car = surface.create_entity {
        name = "car",
        position = car_position,
        force = player.force,
    }
    if not car then error("failed to create active-task vehicle relink car") end
    run.context.active_vehicle_relink_car = car
    run.context.active_vehicle_relink_ghost = ghost
    run.context.active_vehicle_relink_ghost_position = ghost_position
    run.context.active_vehicle_task_preserved = nil
    mark_expected_task(run, "build_ghost")
end

function enter_vehicle_during_assigned_task(run)
    local player = require_player(run)
    local car = run.context.active_vehicle_relink_car
    local ghost = run.context.active_vehicle_relink_ghost
    if not (car and car.valid) then
        error("missing car for active-task vehicle relink")
    end
    if not (ghost and ghost.valid) then
        error("missing ghost for active-task vehicle relink")
    end
    local spiderbot_data, spiderbot_id = assigned_task_for_target(run, "build_ghost", ghost)
    if not spiderbot_data then
        return false
    end
    run.context.active_vehicle_relink_spiderbot_id = spiderbot_id
    if not run.context.active_vehicle_relink_entered then
        car.set_driver(player)
        run.context.active_vehicle_relink_entered = true
        return false
    end
    if not entity_matches(player.physical_vehicle, car) and not entity_matches(player.vehicle, car) then
        return false
    end
    if not run.context.active_vehicle_relink_handler_called then
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = car,
        })
        run.context.active_vehicle_relink_handler_called = true
    end
    local spiderbot = spiderbot_data.spiderbot
    local task_matches_ghost = task_target_matches(spiderbot_data.task, ghost)
    local destination_count = spiderbot and spiderbot.valid and #(spiderbot.autopilot_destinations or {}) or 0
    local task_preserved = spiderbot
        and spiderbot.valid
        and spiderbot_data.status == "task_assigned"
        and spiderbot_data.task
        and task_matches_ghost
        and destination_count > 0
    run.context.active_vehicle_relink_task_state = {
        physical_vehicle_is_car = entity_matches(player.physical_vehicle, car),
        vehicle_is_car = entity_matches(player.vehicle, car),
        follow_target_is_car = spiderbot and spiderbot.valid and entity_matches(spiderbot.follow_target, car) or false,
        destination_count = destination_count,
        status = spiderbot_data.status,
        task_type = spiderbot_data.task and spiderbot_data.task.task_type or nil,
        task_matches_ghost = task_matches_ghost,
    }
    run.context.active_vehicle_task_preserved = task_preserved
    return task_preserved
end

function active_task_follow_target_relinked_after_completion(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_id = run.context.active_vehicle_relink_spiderbot_id
    local spiderbot_data = spiderbot_id and tracked_spiderbots(run.player_index)[spiderbot_id]
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    local car = run.context.active_vehicle_relink_car
    local ghost = run.context.active_vehicle_relink_ghost
    run.context.active_vehicle_relink_state = {
        tracked_spiderbot_id = spiderbot_id,
        car_valid = car and car.valid or false,
        ghost_valid = ghost and ghost.valid or false,
        spiderbot_valid = spiderbot and spiderbot.valid or false,
        follow_target_is_car = spiderbot and spiderbot.valid and entity_matches(spiderbot.follow_target, car) or false,
        status = spiderbot_data and spiderbot_data.status,
        task_type = spiderbot_data and spiderbot_data.task and spiderbot_data.task.task_type or nil,
        task_is_ghost = spiderbot_data and spiderbot_data.task and task_target_matches(spiderbot_data.task, ghost) or false,
        task_preserved_before_completion = run.context.active_vehicle_task_preserved == true,
        task_state = run.context.active_vehicle_relink_task_state,
    }
    local relinked = run.context.active_vehicle_task_preserved == true
        and spiderbot
        and spiderbot.valid
        and spiderbot_data
        and spiderbot_data.status == "idle"
        and spiderbot_data.task == nil
        and entity_matches(spiderbot.follow_target, car)
        and find_entity_near("small-electric-pole", run.context.active_vehicle_relink_ghost_position, nil, run.context.surface_name) ~= nil
    if relinked then
        if car and car.valid then
            car.set_driver(nil)
        end
        call_registered_handler(defines.events.on_player_driving_changed_state, {
            player_index = player.index,
            entity = car,
        })
        if spiderbot and spiderbot.valid then
            spiderbot.follow_target = character
        end
        if ghost and ghost.valid then
            ghost.destroy({ raise_destroy = true })
        end
        local built = find_entity_near("small-electric-pole", run.context.active_vehicle_relink_ghost_position, nil, run.context.surface_name)
        if built and built.valid then
            built.destroy({ raise_destroy = true })
        end
        if car and car.valid then
            car.destroy({ raise_destroy = true })
        end
        run.context.active_vehicle_relink_car = nil
        run.context.active_vehicle_relink_ghost = nil
        run.context.active_vehicle_relink_spiderbot_id = nil
        run.context.active_vehicle_relink_ghost_position = nil
        run.context.active_vehicle_task_preserved = nil
        run.context.active_vehicle_relink_task_state = nil
        run.context.active_vehicle_relink_entered = nil
        run.context.active_vehicle_relink_handler_called = nil
    end
    return relinked
end

function trigger_unknown_path_response_noop(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for unknown path response no-op")
    end
    run.context.unknown_path_spiderbot_unit_number = spiderbot.unit_number
    run.context.unknown_path_status = spiderbot_data.status
    run.context.unknown_path_task = spiderbot_data.task
    run.context.unknown_path_request_id = spiderbot_data.path_request_id
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = next_synthetic_path_request_id(run),
        path = synthetic_path_to(position_near_player(run, 3, -9)),
    })
end

function unknown_path_response_nooped(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    return spiderbot_data
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.unknown_path_spiderbot_unit_number
        and spiderbot_data.status == run.context.unknown_path_status
        and spiderbot_data.task == run.context.unknown_path_task
        and spiderbot_data.path_request_id == run.context.unknown_path_request_id
        and first_spiderbot_idle_without_task(run)
end

function trigger_no_path_request_reset(run)
    local _, _, path_request_id = assign_synthetic_build_ghost_path_task(run, "no_path", 4, -7)
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = nil,
    })
end

function no_path_request_reset_complete(run)
    cleanup_context_entity(run, "no_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_cleared_task_path_request_reset(run)
    local spiderbot_data, ghost, path_request_id = assign_synthetic_build_ghost_path_task(run, "cleared_task_path", 4, -9)
    spiderbot_data.task = nil
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(ghost.position),
    })
end

function cleared_task_path_request_reset_complete(run)
    cleanup_context_entity(run, "cleared_task_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_stale_path_response_wrong_status(run)
    local spiderbot_data, ghost, path_request_id = assign_synthetic_build_ghost_path_task(run, "stale_path", 5, -7)
    spiderbot_data.status = "idle"
    run.context.stale_path_spiderbot_unit_number = spiderbot_data.spiderbot.unit_number
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(ghost.position),
    })
end

function stale_path_response_wrong_status_nooped(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local ghost = run.context.stale_path_ghost
    local nooped = spiderbot_data
        and spiderbot_data.spiderbot
        and spiderbot_data.spiderbot.valid
        and spiderbot_data.spiderbot.unit_number == run.context.stale_path_spiderbot_unit_number
        and spiderbot_data.status == "idle"
        and spiderbot_data.path_request_id == run.context.stale_path_path_request_id
        and ghost
        and ghost.valid
        and first_spiderbot_idle_without_task(run) == false
    if nooped then
        spiderbot_data.task = nil
        spiderbot_data.path_request_id = nil
        cleanup_context_entity(run, "stale_path_ghost")
    end
    return nooped
end

function trigger_empty_path_response_completion(run)
    local player = require_player(run)
    local spiderbot_data, ghost, path_request_id = assign_synthetic_build_ghost_path_task(run, "empty_path", 6, -7)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.empty_path_position = ghost.position
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = {},
    })
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = spiderbot_data.spiderbot,
    })
end

function empty_path_response_completed_task(run)
    return find_entity_near("small-electric-pole", run.context.empty_path_position, nil, run.context.surface_name) ~= nil
        and first_spiderbot_idle_without_task(run)
end

function trigger_disabled_path_request_reset(run)
    local _, _, path_request_id = assign_synthetic_build_ghost_path_task(run, "disabled_path", 7, -7)
    storage.spiderbots_enabled[run.player_index] = false
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(position_near_player(run, 7, -7)),
    })
    storage.spiderbots_enabled[run.player_index] = true
end

function disabled_path_request_reset_complete(run)
    cleanup_context_entity(run, "disabled_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_surface_mismatch_path_request_reset(run)
    local player = require_player(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    if not (spiderbot_data and spiderbot_data.spiderbot and spiderbot_data.spiderbot.valid) then
        error("missing spiderbot for surface-mismatch path reset")
    end
    local target_surface = ensure_surface(TRANSITION_SURFACE_NAME, START_POSITION)
    local position = p(6, -12)
    prepare_buildable_ground(target_surface, position, 2)
    local ghost = create_small_pole_ghost(target_surface, player, position)
    local path_request_id = next_synthetic_path_request_id(run)
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id_for_entity(ghost),
        entity = ghost,
        projectile_item = "small-electric-pole",
    }
    spiderbot_data.status = "path_requested"
    spiderbot_data.path_request_id = path_request_id
    run.context.surface_mismatch_path_ghost = ghost
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(position),
    })
end

function surface_mismatch_path_request_reset_complete(run)
    cleanup_context_entity(run, "surface_mismatch_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_invalid_target_path_request_reset(run)
    local _, ghost, path_request_id = assign_synthetic_build_ghost_path_task(run, "invalid_target_path", 10, -7)
    ghost.destroy({ raise_destroy = true })
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(position_near_player(run, 10, -7)),
    })
end

function invalid_target_path_request_reset_complete(run)
    cleanup_context_entity(run, "invalid_target_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_distant_target_path_request_reset(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot_data, ghost, path_request_id = assign_synthetic_build_ghost_path_task(run, "distant_target_path", 13, -7)
    local spiderbot = spiderbot_data.spiderbot
    local distant_position = position_near_player(run, -55, -7)
    prepare_buildable_ground(surface, distant_position, 4)
    if not spiderbot.teleport(distant_position, surface) then
        error("failed to move spiderbot for distant target path reset")
    end
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(ghost.position),
    })
    local return_position = position_near_player(run, 3, 0)
    return_position = player.surface.find_non_colliding_position("spiderbot-leg-1", return_position, 20, 0.5) or return_position
    if not spiderbot.teleport(return_position, player.surface) then
        error("failed to return spiderbot after distant target path reset")
    end
end

function distant_target_path_request_reset_complete(run)
    cleanup_context_entity(run, "distant_target_path_ghost")
    return first_spiderbot_idle_without_task(run)
end

function trigger_far_assigned_task_command_reset(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for far assigned-task reset")
    end
    local far_position = p(character.position.x + 100, character.position.y - 7)
    local surface = ensure_surface(run.context.surface_name, far_position)
    prepare_buildable_ground(surface, far_position, 3)
    local ghost = create_small_pole_ghost(surface, player, far_position)
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id_for_entity(ghost),
        entity = ghost,
    }
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = nil
    spiderbot.autopilot_destination = nil
    for i = 1, 6 do
        spiderbot.add_autopilot_destination(p(spiderbot.position.x + i, spiderbot.position.y))
    end
    run.context.far_assigned_task_ghost = ghost
    for _ = 1, 512 do
        call_registered_handler(defines.events.on_spider_command_completed, {
            vehicle = spiderbot,
        })
        if first_spiderbot_idle_without_task(run) then
            break
        end
    end
end

function far_assigned_task_command_reset_complete(run)
    local spiderbot = first_spiderbot(run.player_index)
    local reset = first_spiderbot_idle_without_task(run)
    if reset then
        if spiderbot and spiderbot.valid then
            spiderbot.autopilot_destination = nil
        end
        cleanup_context_entity(run, "far_assigned_task_ghost")
    end
    return reset
end

function create_destroyed_target_command_reset_task(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.destroyed_target_start_poles = inventory.get_item_count({ name = "small-electric-pole", quality = "normal" })
    local position = position_near_player(run, 21, -10)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.destroyed_target_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function trigger_destroyed_target_command_reset(run)
    local ghost = run.context.destroyed_target_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for destroyed target command reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_ghost", ghost)
    if not spiderbot_data then return false end
    ghost.destroy({ raise_destroy = true })
    return complete_assigned_task_now(spiderbot_data)
end

function destroyed_target_command_reset_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return first_spiderbot_idle_without_task(run)
        and inventory.get_item_count({ name = "small-electric-pole", quality = "normal" }) >= run.context.destroyed_target_start_poles
end

function create_destroyed_tile_ghost_command_reset_task(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    run.context.destroyed_tile_ghost_start_bricks = inventory.get_item_count({ name = "stone-brick", quality = "normal" })
    local position = position_near_player(run, 21, -7)
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not ghost then error("failed to create destroyed tile ghost reset target") end
    run.context.destroyed_tile_ghost_position = position
    run.context.destroyed_tile_ghost = ghost
    mark_expected_task(run, "build_tile")
end

function trigger_destroyed_tile_ghost_command_reset(run)
    local ghost = run.context.destroyed_tile_ghost
    if not (ghost and ghost.valid) then
        error("missing tile ghost for destroyed tile ghost command reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_tile", ghost)
    if not spiderbot_data then return false end
    ghost.destroy({ raise_destroy = true })
    return complete_assigned_task_now(spiderbot_data)
end

function destroyed_tile_ghost_command_reset_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.destroyed_tile_ghost_position
    local tile = surface.get_tile(position.x, position.y)
    return tile
        and tile.valid
        and tile.name ~= "stone-path"
        and inventory.get_item_count({ name = "stone-brick", quality = "normal" }) >= run.context.destroyed_tile_ghost_start_bricks
        and first_spiderbot_idle_without_task(run)
end

function create_destroyed_item_request_command_reset_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -4)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create destroyed-proxy reset assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create destroyed item-request proxy") end
    run.context.destroyed_item_request_assembler = assembler
    run.context.destroyed_item_request_proxy = proxy
    mark_expected_task(run, "insert_items")
end

function trigger_destroyed_item_request_command_reset(run)
    local proxy = run.context.destroyed_item_request_proxy
    if not (proxy and proxy.valid) then
        error("missing item-request proxy for destroyed request reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "insert_items", proxy)
    if not spiderbot_data then return false end
    proxy.destroy({ raise_destroy = true })
    return complete_assigned_task_now(spiderbot_data)
end

function destroyed_item_request_command_reset_complete(run)
    local assembler = run.context.destroyed_item_request_assembler
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local reset = assembler
        and assembler.valid
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and first_spiderbot_idle_without_task(run)
    if reset then
        assembler.destroy({ raise_destroy = true })
        run.context.destroyed_item_request_assembler = nil
    end
    return reset
end

function create_destroyed_cliff_target_retarget_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    storage.cliffs_to_be_exploded = {}
    insert(player, { name = "cliff-explosives", count = 2, quality = "normal" })
    local destroyed_position = position_near_player(run, 16, -10)
    local fallback_position = position_near_player(run, 21, -10)
    set_square_tiles(surface, destroyed_position, 4, natural_ground_tile_name())
    set_square_tiles(surface, fallback_position, 4, natural_ground_tile_name())
    local destroyed_cliff = surface.create_entity {
        name = "cliff",
        position = destroyed_position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not destroyed_cliff then
        error("failed to create cliffs for destroyed target retarget")
    end
    if not destroyed_cliff.order_deconstruction(player.force, player) then
        error("failed to order destroyed cliff deconstruction")
    end
    run.context.destroyed_cliff_retarget_destroyed_cliff = destroyed_cliff
    run.context.destroyed_cliff_retarget_fallback_position = fallback_position
    mark_expected_task(run, "deconstruct_entity")
end

function trigger_destroyed_cliff_target_retarget(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local destroyed_cliff = run.context.destroyed_cliff_retarget_destroyed_cliff
    if not (destroyed_cliff and destroyed_cliff.valid) then
        error("missing destroyed cliff target for retarget")
    end
    local spiderbot_data = assigned_task_for_target(run, "deconstruct_entity", destroyed_cliff)
    if not spiderbot_data then return false end
    local fallback_position = run.context.destroyed_cliff_retarget_fallback_position
    destroyed_cliff.destroy({ raise_destroy = true })
    local fallback_cliff = surface.create_entity {
        name = "cliff",
        position = fallback_position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not fallback_cliff then error("failed to create fallback cliff deconstruction target") end
    if not fallback_cliff.order_deconstruction(player.force, player) then
        error("failed to order fallback cliff deconstruction")
    end
    run.context.destroyed_cliff_retarget_position = fallback_cliff.position
    return complete_assigned_task_now(spiderbot_data)
end

function destroyed_cliff_target_retarget_complete(run)
    return expected_task_was_seen(run)
        and #find_entities_near({ type = "cliff" }, run.context.destroyed_cliff_retarget_position, 4, run.context.surface_name) == 0
        and first_spiderbot_idle_without_task(run)
end

function create_missing_cliff_explosives_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "cliff-explosives", quality = "normal" })
    insert(player, { name = "cliff-explosives", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -10)
    set_square_tiles(surface, position, 4, natural_ground_tile_name())
    local cliff = surface.create_entity {
        name = "cliff",
        position = position,
        cliff_orientation = "west-to-east",
        force = game.forces.enemy,
    }
    if not cliff then error("failed to create cliff for missing explosives reset") end
    if not cliff.order_deconstruction(player.force, player) then
        error("failed to order cliff for missing explosives reset")
    end
    run.context.missing_cliff_explosives_cliff = cliff
    mark_expected_task(run, "deconstruct_entity")
end

function trigger_missing_cliff_explosives_command_reset(run)
    local player = require_player(run)
    local cliff = run.context.missing_cliff_explosives_cliff
    if not (cliff and cliff.valid) then
        error("missing cliff for missing explosives reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "deconstruct_entity", cliff)
    if not spiderbot_data then return false end
    remove_from_main_inventory(player, { name = "cliff-explosives", quality = "normal" })
    return complete_assigned_task_now(spiderbot_data)
end

function missing_cliff_explosives_command_reset_complete(run)
    local cliff = run.context.missing_cliff_explosives_cliff
    if cliff and cliff.valid then
        cliff.destroy({ raise_destroy = true })
    end
    run.context.missing_cliff_explosives_cliff = nil
    return first_spiderbot_idle_without_task(run)
end

function create_missing_entity_item_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -10)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.missing_entity_item_ghost = ghost
    run.context.missing_entity_item_position = position
    mark_expected_task(run, "build_ghost")
end

function trigger_missing_entity_item_command_reset(run)
    local player = require_player(run)
    local ghost = run.context.missing_entity_item_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for missing entity item reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_ghost", ghost)
    if not spiderbot_data then return false end
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    return complete_assigned_task_now(spiderbot_data)
end

function missing_entity_item_command_reset_complete(run)
    local ghost = run.context.missing_entity_item_ghost
    local built = find_entity_near("small-electric-pole", run.context.missing_entity_item_position, nil, run.context.surface_name)
    local reset = ghost
        and ghost.valid
        and not built
        and first_spiderbot_idle_without_task(run)
    if reset then
        ghost.destroy({ raise_destroy = true })
        run.context.missing_entity_item_ghost = nil
    end
    return reset
end

function create_missing_upgrade_item_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("fast-transport-belt")
    remove_from_main_inventory(player, { name = "fast-transport-belt", quality = "normal" })
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -10)
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create missing-upgrade-item command target") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order missing-upgrade-item command target")
    end
    run.context.missing_upgrade_item_command_belt = belt
    run.context.missing_upgrade_item_command_position = position
    mark_expected_task(run, "upgrade_entity")
end

function trigger_missing_upgrade_item_command_reset(run)
    local player = require_player(run)
    local belt = run.context.missing_upgrade_item_command_belt
    if not (belt and belt.valid) then
        error("missing belt for missing upgrade item reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "upgrade_entity", belt)
    if not spiderbot_data then return false end
    remove_from_main_inventory(player, { name = "fast-transport-belt", quality = "normal" })
    return complete_assigned_task_now(spiderbot_data)
end

function missing_upgrade_item_command_reset_complete(run)
    local belt = run.context.missing_upgrade_item_command_belt
    local upgraded = find_entity_near("fast-transport-belt", run.context.missing_upgrade_item_command_position, nil, run.context.surface_name)
    local reset = belt
        and belt.valid
        and upgraded == nil
        and first_spiderbot_idle_without_task(run)
    if reset then
        belt.destroy({ raise_destroy = true })
        run.context.missing_upgrade_item_command_belt = nil
    end
    return reset
end

function create_missing_tile_item_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -7)
    prepare_buildable_ground(surface, position, 2)
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not ghost then error("failed to create missing-item tile ghost") end
    run.context.missing_tile_item_ghost = ghost
    mark_expected_task(run, "build_tile")
end

function trigger_missing_tile_item_command_reset(run)
    local player = require_player(run)
    local ghost = run.context.missing_tile_item_ghost
    if not (ghost and ghost.valid) then
        error("missing tile ghost for missing tile item reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_tile", ghost)
    if not spiderbot_data then return false end
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    return complete_assigned_task_now(spiderbot_data)
end

function missing_tile_item_command_reset_complete(run)
    cleanup_context_entity(run, "missing_tile_item_ghost")
    return first_spiderbot_idle_without_task(run)
end

function create_failed_entity_revive_preservation_task(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("water")
    require_item_prototype("small-electric-pole")
    local position = position_near_player(run, 21, -7)
    set_square_tiles(surface, position, 0, "water")
    remove_from_main_inventory(player, { name = "small-electric-pole", quality = "normal" })
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    run.context.failed_entity_revive_start_poles = inventory.get_item_count({ name = "small-electric-pole", quality = "normal" })
    run.context.failed_entity_revive_position = position
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not ghost then error("failed to create failed-revive entity ghost") end
    run.context.failed_entity_revive_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function trigger_failed_entity_revive_preserves_inventory(run)
    local ghost = run.context.failed_entity_revive_ghost
    local position = run.context.failed_entity_revive_position
    if not (ghost and ghost.valid) then
        error("missing failed-revive entity ghost")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_ghost", ghost)
    if not spiderbot_data then return false end
    complete_assigned_task_now(spiderbot_data)
    run.context.failed_entity_revive_failed = ghost.valid
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) == nil
    if ghost.valid then
        ghost.destroy({ raise_destroy = true })
    end
    run.context.failed_entity_revive_ghost = nil
    return true
end

function failed_entity_revive_preserved_inventory(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.failed_entity_revive_position
    local tile = position and surface.get_tile(position.x, position.y)
    local preserved = run.context.failed_entity_revive_failed
        and find_entity_near("small-electric-pole", position, nil, run.context.surface_name) == nil
        and inventory.get_item_count({ name = "small-electric-pole", quality = "normal" }) >= run.context.failed_entity_revive_start_poles
        and first_spiderbot_idle_without_task(run)
    if preserved and tile and tile.valid and tile.name == "water" then
        set_square_tiles(surface, position, 0, natural_ground_tile_name())
    end
    return preserved
end

function create_failed_tile_revive_preservation_task(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("water")
    require_tile_prototype("stone-path")
    require_item_prototype("stone-brick")
    local position = position_near_player(run, 21, -7)
    set_square_tiles(surface, position, 0, "water")
    remove_from_main_inventory(player, { name = "stone-brick", quality = "normal" })
    insert(player, { name = "stone-brick", count = 1, quality = "normal" })
    run.context.failed_tile_revive_start_bricks = inventory.get_item_count({ name = "stone-brick", quality = "normal" })
    run.context.failed_tile_revive_position = position
    local ghost = surface.create_entity {
        name = "tile-ghost",
        inner_name = "stone-path",
        position = position,
        force = player.force,
    }
    if not ghost then error("failed to create failed-revive tile ghost") end
    run.context.failed_tile_revive_ghost = ghost
    mark_expected_task(run, "build_tile")
end

function trigger_failed_tile_revive_preserves_inventory(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.failed_tile_revive_position
    local ghost = run.context.failed_tile_revive_ghost
    if not (ghost and ghost.valid) then
        error("missing failed-revive tile ghost")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_tile", ghost)
    if not spiderbot_data then return false end
    complete_assigned_task_now(spiderbot_data)
    local tile = surface.get_tile(position.x, position.y)
    run.context.failed_tile_revive_failed = ghost.valid
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
    if ghost.valid then
        ghost.destroy({ raise_destroy = true })
    end
    run.context.failed_tile_revive_ghost = nil
    return true
end

function failed_tile_revive_preserved_inventory(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.failed_tile_revive_position
    local tile = position and surface.get_tile(position.x, position.y)
    return run.context.failed_tile_revive_failed
        and tile
        and tile.valid
        and tile.name ~= "stone-path"
        and inventory.get_item_count({ name = "stone-brick", quality = "normal" }) >= run.context.failed_tile_revive_start_bricks
        and first_spiderbot_idle_without_task(run)
end

function create_cancelled_deconstruction_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create cancelled deconstruction chest") end
    if not chest.order_deconstruction(player.force, player) then
        error("failed to order cancelled deconstruction chest")
    end
    run.context.cancelled_deconstruction_chest = chest
    mark_expected_task(run, "deconstruct_entity")
end

function trigger_cancelled_deconstruction_command_reset(run)
    local player = require_player(run)
    local chest = run.context.cancelled_deconstruction_chest
    if not (chest and chest.valid) then
        error("missing chest for cancelled deconstruction reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "deconstruct_entity", chest)
    if not spiderbot_data then return false end
    chest.cancel_deconstruction(player.force, player)
    return complete_assigned_task_now(spiderbot_data)
end

function cancelled_deconstruction_command_reset_complete(run)
    local chest = run.context.cancelled_deconstruction_chest
    local reset = chest
        and chest.valid
        and not chest.to_be_deconstructed()
        and first_spiderbot_idle_without_task(run)
    if reset then
        chest.destroy({ raise_destroy = true })
        run.context.cancelled_deconstruction_chest = nil
    end
    return reset
end

function create_cancelled_upgrade_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "fast-transport-belt", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 2)
    local belt = surface.create_entity {
        name = "transport-belt",
        position = position,
        direction = defines.direction.east,
        force = player.force,
        quality = "normal",
    }
    if not belt then error("failed to create cancelled upgrade belt") end
    if not belt.order_upgrade {
            target = { name = "fast-transport-belt", quality = "normal" },
            force = player.force,
            player = player,
        } then
        error("failed to order cancelled belt upgrade")
    end
    run.context.cancelled_upgrade_belt = belt
    run.context.cancelled_upgrade_position = position
    mark_expected_task(run, "upgrade_entity")
end

function trigger_cancelled_upgrade_command_reset(run)
    local player = require_player(run)
    local belt = run.context.cancelled_upgrade_belt
    if not (belt and belt.valid) then
        error("missing belt for cancelled upgrade reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "upgrade_entity", belt)
    if not spiderbot_data then return false end
    belt.cancel_upgrade(player.force, player)
    return complete_assigned_task_now(spiderbot_data)
end

function cancelled_upgrade_command_reset_complete(run)
    local belt = run.context.cancelled_upgrade_belt
    local upgraded = find_entity_near("fast-transport-belt", run.context.cancelled_upgrade_position, nil, run.context.surface_name)
    local reset = belt
        and belt.valid
        and not belt.to_be_upgraded()
        and not upgraded
        and first_spiderbot_idle_without_task(run)
    if reset then
        belt.destroy({ raise_destroy = true })
        run.context.cancelled_upgrade_belt = nil
    end
    return reset
end

function create_cancelled_tile_deconstruction_command_task(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    require_tile_prototype("stone-path")
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 2)
    set_square_tiles(surface, position, 0, "stone-path")
    local tile = surface.get_tile(position.x, position.y)
    if not (tile and tile.valid and tile.name == "stone-path") then
        error("failed to create cancelled tile deconstruction target")
    end
    if not tile.order_deconstruction(player.force, player) then
        error("failed to order cancelled tile deconstruction")
    end
    run.context.cancelled_tile_deconstruction_position = position
    mark_expected_task(run, "deconstruct_tile")
end

function trigger_cancelled_tile_deconstruction_command_reset(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.cancelled_tile_deconstruction_position
    local tile = position and surface.get_tile(position.x, position.y)
    if not (tile and tile.valid) then
        error("missing tile for cancelled tile deconstruction reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "deconstruct_tile", tile)
    if not spiderbot_data then return false end
    tile.cancel_deconstruction(player.force, player)
    return complete_assigned_task_now(spiderbot_data)
end

function cancelled_tile_deconstruction_command_reset_complete(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = run.context.cancelled_tile_deconstruction_position
    local tile = position and surface.get_tile(position.x, position.y)
    local reset = tile
        and tile.valid
        and tile.name == "stone-path"
        and not tile.to_be_deconstructed()
        and first_spiderbot_idle_without_task(run)
    if reset then
        run.context.cancelled_tile_deconstruction_position = nil
    end
    return reset
end

function create_cleared_item_request_command_task(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create cleared item request assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create cleared item request proxy") end
    run.context.cleared_item_request_assembler = assembler
    run.context.cleared_item_request_proxy = proxy
    run.context.cleared_item_request_start_count = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    mark_expected_task(run, "insert_items")
end

function trigger_cleared_item_request_command_reset(run)
    local proxy = run.context.cleared_item_request_proxy
    if not (proxy and proxy.valid) then
        error("missing proxy for cleared item request reset")
    end
    local spiderbot_data, spiderbot_id = assigned_task_for_target(run, "insert_items", proxy)
    if not spiderbot_data then return false end
    run.context.cleared_item_request_spiderbot_id = spiderbot_id
    proxy.insert_plan = {}
    return complete_assigned_task_now(spiderbot_data)
end

function cleared_item_request_command_reset_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.cleared_item_request_assembler
    local proxy = run.context.cleared_item_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local proxy_cleared = not proxy or not proxy.valid or not (proxy.insert_plan and proxy.insert_plan[1])
    run.context.cleared_item_request_state = {
        proxy_valid = proxy and proxy.valid or false,
        proxy_cleared = proxy_cleared,
        module_speed_count = module_inventory and module_inventory.valid and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) or nil,
        inventory_speed_count = player_inventory.get_item_count({ name = "speed-module", quality = "normal" }),
        start_speed_count = run.context.cleared_item_request_start_count,
        spiderbot_idle = spiderbot_id_idle_without_task(run, run.context.cleared_item_request_spiderbot_id) and true or false,
    }
    local reset = assembler
        and assembler.valid
        and proxy_cleared
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) >= run.context.cleared_item_request_start_count
        and spiderbot_id_idle_without_task(run, run.context.cleared_item_request_spiderbot_id)
    if reset then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        run.context.cleared_item_request_proxy = nil
        run.context.cleared_item_request_assembler = nil
        run.context.cleared_item_request_spiderbot_id = nil
    end
    return reset
end

function create_changed_insert_request_command_task(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("efficiency-module")
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
    insert(player, { name = "speed-module", count = 1, quality = "normal" })
    insert(player, { name = "efficiency-module", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create changed insert request assembler") end
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create changed insert request proxy") end
    run.context.changed_insert_request_assembler = assembler
    run.context.changed_insert_request_proxy = proxy
    run.context.changed_insert_request_start_speed = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    run.context.changed_insert_request_start_efficiency = player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" })
    mark_expected_task(run, "insert_items")
end

function trigger_changed_insert_request_command_reset(run)
    local proxy = run.context.changed_insert_request_proxy
    if not (proxy and proxy.valid) then
        error("missing proxy for changed insert request")
    end
    local spiderbot_data, spiderbot_id = assigned_task_for_target(run, "insert_items", proxy)
    if not spiderbot_data then return false end
    run.context.changed_insert_request_spiderbot_id = spiderbot_id
    proxy.insert_plan = {
        {
            id = { name = "efficiency-module", quality = "normal" },
            items = {
                in_inventory = {
                    {
                        inventory = defines.inventory.crafter_modules,
                        stack = 1,
                        count = 1,
                    },
                },
            },
        },
    }
    return complete_assigned_task_now(spiderbot_data)
end

function changed_insert_request_command_reset_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.changed_insert_request_assembler
    local proxy = run.context.changed_insert_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local proxy_finished = not proxy or not proxy.valid or not (proxy.insert_plan and proxy.insert_plan[1])
    local completed = assembler
        and assembler.valid
        and proxy_finished
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 0
        and module_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == 1
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == run.context.changed_insert_request_start_speed
        and player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == run.context.changed_insert_request_start_efficiency - 1
        and spiderbot_id_idle_without_task(run, run.context.changed_insert_request_spiderbot_id)
    if completed then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
        remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
        run.context.changed_insert_request_proxy = nil
        run.context.changed_insert_request_assembler = nil
        run.context.changed_insert_request_spiderbot_id = nil
    end
    return completed
end

function create_changed_removal_request_command_task(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    require_item_prototype("efficiency-module")
    remove_from_main_inventory(player, { name = "speed-module", quality = "normal" })
    remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 3)
    local assembler = surface.create_entity {
        name = "assembling-machine-2",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not assembler then error("failed to create changed removal request assembler") end
    local module_inventory = assembler.get_inventory(defines.inventory.crafter_modules)
    if not (module_inventory and module_inventory.valid) then
        error("missing module inventory for changed removal request")
    end
    module_inventory[1].set_stack({ name = "speed-module", count = 1, quality = "normal" })
    module_inventory[2].set_stack({ name = "efficiency-module", count = 1, quality = "normal" })
    local proxy = surface.create_entity {
        name = "item-request-proxy",
        position = position,
        force = player.force,
        target = assembler,
        modules = {},
        removal_plan = {
            {
                id = { name = "speed-module", quality = "normal" },
                items = {
                    in_inventory = {
                        {
                            inventory = defines.inventory.crafter_modules,
                            stack = 0,
                            count = 1,
                        },
                    },
                },
            },
        },
    }
    if not proxy then error("failed to create changed removal request proxy") end
    run.context.changed_removal_request_assembler = assembler
    run.context.changed_removal_request_proxy = proxy
    run.context.changed_removal_request_start_speed = player_inventory.get_item_count({ name = "speed-module", quality = "normal" })
    run.context.changed_removal_request_start_efficiency = player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" })
    mark_expected_task(run, "insert_items")
end

function trigger_changed_removal_request_command_reset(run)
    local proxy = run.context.changed_removal_request_proxy
    if not (proxy and proxy.valid) then
        error("missing proxy for changed removal request")
    end
    local spiderbot_data, spiderbot_id = assigned_task_for_target(run, "insert_items", proxy)
    if not spiderbot_data then return false end
    run.context.changed_removal_request_spiderbot_id = spiderbot_id
    proxy.removal_plan = {
        {
            id = { name = "efficiency-module", quality = "normal" },
            items = {
                in_inventory = {
                    {
                        inventory = defines.inventory.crafter_modules,
                        stack = 1,
                        count = 1,
                    },
                },
            },
        },
    }
    return complete_assigned_task_now(spiderbot_data)
end

function changed_removal_request_command_reset_complete(run)
    local player = require_player(run)
    local player_inventory = require_inventory(player)
    local assembler = run.context.changed_removal_request_assembler
    local proxy = run.context.changed_removal_request_proxy
    local module_inventory = assembler and assembler.valid and assembler.get_inventory(defines.inventory.crafter_modules)
    local proxy_finished = not proxy or not proxy.valid or not (proxy.removal_plan and proxy.removal_plan[1])
    local completed = assembler
        and assembler.valid
        and proxy_finished
        and module_inventory
        and module_inventory.valid
        and module_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == 1
        and module_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == 0
        and player_inventory.get_item_count({ name = "speed-module", quality = "normal" }) == run.context.changed_removal_request_start_speed
        and player_inventory.get_item_count({ name = "efficiency-module", quality = "normal" }) == run.context.changed_removal_request_start_efficiency + 1
        and spiderbot_id_idle_without_task(run, run.context.changed_removal_request_spiderbot_id)
    if completed then
        if proxy and proxy.valid then
            proxy.destroy({ raise_destroy = true })
        end
        assembler.destroy({ raise_destroy = true })
        remove_from_main_inventory(player, { name = "efficiency-module", quality = "normal" })
        run.context.changed_removal_request_proxy = nil
        run.context.changed_removal_request_assembler = nil
        run.context.changed_removal_request_spiderbot_id = nil
    end
    return completed
end

function trigger_repair_task_command_reset(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for repair task reset")
    end
    local position = position_near_player(run, 8, -1)
    prepare_buildable_ground(surface, position, 2)
    local chest = surface.create_entity {
        name = "wooden-chest",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not chest then error("failed to create repair task target") end
    spiderbot_data.task = {
        task_type = "repair_entity",
        task_id = task_id_for_entity(chest),
        entity = chest,
    }
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = nil
    spiderbot.autopilot_destination = nil
    run.context.repair_task_target = chest
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = spiderbot,
    })
end

function repair_task_command_reset_complete(run)
    local chest = run.context.repair_task_target
    local reset = chest
        and chest.valid
        and first_spiderbot_idle_without_task(run)
    if reset then
        chest.destroy({ raise_destroy = true })
        run.context.repair_task_target = nil
    end
    return reset
end

function create_missing_player_entity_command_task(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local position = position_near_player(run, 21, -1)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.missing_player_entity_character = character
    run.context.missing_player_entity_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function trigger_missing_player_entity_command_reset(run)
    local player = require_player(run)
    local ghost = run.context.missing_player_entity_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for missing-player-entity reset")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_ghost", ghost)
    if not spiderbot_data then return false end
    player.set_controller { type = defines.controllers.god }
    return complete_assigned_task_now(spiderbot_data)
end

function missing_player_entity_command_reset_complete(run)
    local player = require_player(run)
    local character = run.context.missing_player_entity_character
    if character and character.valid and player.controller_type ~= defines.controllers.character then
        player.set_controller {
            type = defines.controllers.character,
            character = character,
        }
        call_registered_handler(defines.events.on_player_controller_changed, {
            player_index = player.index,
        })
    end
    local ghost = run.context.missing_player_entity_ghost
    local reset = player.controller_type == defines.controllers.character
        and first_spiderbot_idle_without_task(run)
    if reset then
        if ghost and ghost.valid then
            ghost.destroy({ raise_destroy = true })
        end
        run.context.missing_player_entity_character = nil
        run.context.missing_player_entity_ghost = nil
    end
    return reset
end

function trigger_wrong_event_noops(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for wrong-event no-op test")
    end
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    run.context.wrong_event_spiderbot_unit_number = spiderbot.unit_number
    run.context.wrong_event_spiderbot_count = spiderbot_count(run.player_index)
    run.context.wrong_event_enabled = storage.spiderbots_enabled[run.player_index]
    run.context.wrong_event_projectile_count = projectiles and #projectiles or 0
    local position = position_near_player(run, 5, -4)
    prepare_buildable_ground(surface, position, 3)
    local car = surface.create_entity {
        name = "car",
        position = position,
        force = player.force,
    }
    if not car then error("failed to create wrong-event no-op car") end
    run.context.wrong_event_car = car
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = player.index,
        prototype_name = "not-toggle-spiderbots",
    })
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = car,
    })
    call_registered_handler(defines.events.script_raised_teleported, {
        entity = car,
    })
    call_registered_handler(defines.events.on_object_destroyed, {
        registration_number = 987654321,
    })
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = car,
        source = character,
    })
    call_registered_handler(defines.events.on_player_used_capsule, {
        player_index = player.index,
        item = { name = "raw-fish" },
        position = position_near_player(run, 6, -4),
        quality = prototypes.quality["normal"],
    })
    run.context.wrong_event_started_tick = game.tick
end

function wrong_event_noops_complete(run)
    if game.tick - run.context.wrong_event_started_tick < 1 then return false end
    local car = run.context.wrong_event_car
    local spiderbot = first_spiderbot(run.player_index)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    local noops = car
        and car.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.wrong_event_spiderbot_unit_number
        and spiderbot_count(run.player_index) == run.context.wrong_event_spiderbot_count
        and storage.spiderbots_enabled[run.player_index] == run.context.wrong_event_enabled
        and (projectiles and #projectiles or 0) == run.context.wrong_event_projectile_count
        and first_spiderbot_idle_without_task(run)
    if noops then
        car.destroy({ raise_destroy = true })
        run.context.wrong_event_car = nil
    end
    return noops
end

function trigger_invalid_player_event_noops(run)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for invalid-player no-op test")
    end
    local invalid_player_index = nil
    for candidate = 65536, 1, -1 do
        if not game.get_player(candidate)
            and (not storage.spiderbots_enabled or storage.spiderbots_enabled[candidate] == nil)
            and (not storage.spiderbots or storage.spiderbots[candidate] == nil)
        then
            invalid_player_index = candidate
            break
        end
    end
    if not invalid_player_index then
        error("failed to find unused clean player index for invalid-player no-op test")
    end
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    run.context.invalid_player_index = invalid_player_index
    run.context.invalid_player_spiderbot_unit_number = spiderbot.unit_number
    run.context.invalid_player_spiderbot_count = spiderbot_count(run.player_index)
    run.context.invalid_player_enabled = storage.spiderbots_enabled[run.player_index]
    run.context.invalid_player_projectile_count = projectiles and #projectiles or 0
    call_registered_handler(defines.events.on_lua_shortcut, {
        player_index = invalid_player_index,
        prototype_name = "toggle-spiderbots",
    })
    call_registered_handler("toggle-spiderbots", {
        player_index = invalid_player_index,
        input_name = "toggle-spiderbots",
    })
    call_registered_handler(defines.events.on_player_used_capsule, {
        player_index = invalid_player_index,
        item = { name = "spiderbot" },
        position = START_POSITION,
        quality = prototypes.quality["normal"],
    })
    call_registered_handler(defines.events.on_player_changed_surface, {
        player_index = invalid_player_index,
    })
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = invalid_player_index,
    })
    call_registered_handler(defines.events.on_player_driving_changed_state, {
        player_index = invalid_player_index,
    })
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = invalid_player_index,
    })
    call_registered_handler(defines.events.on_player_cursor_stack_changed, {
        player_index = invalid_player_index,
    })
    run.context.invalid_player_event_started_tick = game.tick
end

function invalid_player_event_noops_complete(run)
    if game.tick - run.context.invalid_player_event_started_tick < 1 then return false end
    local invalid_player_index = run.context.invalid_player_index
    local spiderbot = first_spiderbot(run.player_index)
    local projectiles = storage.spiderbot_projectiles and storage.spiderbot_projectiles[run.player_index]
    local noops = spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.invalid_player_spiderbot_unit_number
        and spiderbot_count(run.player_index) == run.context.invalid_player_spiderbot_count
        and storage.spiderbots_enabled[run.player_index] == run.context.invalid_player_enabled
        and storage.spiderbots_enabled[invalid_player_index] == nil
        and (not storage.spiderbots or storage.spiderbots[invalid_player_index] == nil)
        and (projectiles and #projectiles or 0) == run.context.invalid_player_projectile_count
        and first_spiderbot_idle_without_task(run)
    if noops then
        run.context.invalid_player_index = nil
    end
    return noops
end

function seed_offline_player_storage_ignored(run)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for offline-player storage test")
    end
    local offline_player_index = 900000 + run.player_index
    storage.spiderbots = storage.spiderbots or {}
    storage.spiderbots_enabled = storage.spiderbots_enabled or {}
    storage.spiderbots[offline_player_index] = {
        offline_test_spiderbot = {
            spiderbot = spiderbot,
            spiderbot_id = "offline-test-spiderbot",
            player = nil,
            player_index = offline_player_index,
            status = "task_assigned",
            path_request_id = 123456789,
            task = {
                task_type = "build_ghost",
                task_id = "offline-test-task",
            },
        },
    }
    storage.spiderbots_enabled[offline_player_index] = true
    run.context.offline_player_index = offline_player_index
    run.context.offline_player_started_tick = game.tick
end

function offline_player_storage_was_ignored(run)
    if game.tick - run.context.offline_player_started_tick < 60 then return false end
    local offline_player_index = run.context.offline_player_index
    local offline_storage = storage.spiderbots and storage.spiderbots[offline_player_index]
    local data = offline_storage and offline_storage.offline_test_spiderbot
    local ignored = data
        and data.status == "task_assigned"
        and data.path_request_id == 123456789
        and data.task
        and data.task.task_id == "offline-test-task"
        and first_spiderbot_idle_without_task(run)
    if ignored then
        storage.spiderbots[offline_player_index] = nil
        storage.spiderbots_enabled[offline_player_index] = nil
        run.context.offline_player_index = nil
    end
    return ignored
end

function trigger_stale_player_assigned_task_cleanup(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 8, -4)
    position = surface.find_non_colliding_position("spiderbot-leg-1", position, 20, 0.5) or position
    local stale_spiderbot = surface.create_entity {
        name = "spiderbot",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not stale_spiderbot then error("failed to create stale-player cleanup spiderbot") end
    local stale_player_index = 9100000 + run.player_index
    local stale_spiderbot_id = task_id_for_entity(stale_spiderbot)
    storage.spiderbots = storage.spiderbots or {}
    storage.spiderbots[stale_player_index] = {
        [stale_spiderbot_id] = {
            spiderbot = stale_spiderbot,
            spiderbot_id = stale_spiderbot_id,
            player = nil,
            player_index = stale_player_index,
            status = "task_assigned",
            path_request_id = nil,
            task = {
                task_type = "build_ghost",
                task_id = "stale-player-test-task",
            },
        },
    }
    run.context.stale_player_cleanup_index = stale_player_index
    run.context.stale_player_cleanup_spiderbot = stale_spiderbot
    call_registered_handler(defines.events.on_spider_command_completed, {
        vehicle = stale_spiderbot,
    })
end

function stale_player_assigned_task_cleaned_up(run)
    local stale_player_index = run.context.stale_player_cleanup_index
    local stale_spiderbot = run.context.stale_player_cleanup_spiderbot
    local cleaned = storage.spiderbots
        and storage.spiderbots[stale_player_index]
        and next(storage.spiderbots[stale_player_index]) == nil
        and first_spiderbot_idle_without_task(run)
    if cleaned then
        if stale_spiderbot and stale_spiderbot.valid then
            stale_spiderbot.destroy({ raise_destroy = true })
        end
        storage.spiderbots[stale_player_index] = nil
        run.context.stale_player_cleanup_index = nil
        run.context.stale_player_cleanup_spiderbot = nil
    end
    return cleaned
end

function second_connected_character_player(run)
    for _, player in pairs(game.connected_players) do
        if player.index ~= run.player_index
            and player.valid
            and player.controller_type == defines.controllers.character
            and player.character
            and player.character.valid
        then
            return player
        end
    end
end

function trigger_connected_player_shared_task_isolation(run)
    local player = require_player(run)
    local second_player = second_connected_character_player(run)
    if not second_player then
        run.context.connected_multiplayer_skipped = "no second connected character player"
        return
    end
    storage.spiderbots = storage.spiderbots or {}
    if next(storage.spiderbots[second_player.index] or {}) ~= nil then
        run.context.connected_multiplayer_skipped = "second player already has tracked spiderbots"
        return
    end

    local surface = game.surfaces[run.context.surface_name]
    local second_character = second_player.character
    run.context.connected_multiplayer_second_player_index = second_player.index
    run.context.connected_multiplayer_second_old_surface = second_character.surface
    run.context.connected_multiplayer_second_old_position = second_character.position
    run.context.connected_multiplayer_second_start_poles = require_inventory(second_player).get_item_count({ name = "small-electric-pole", quality = "normal" })

    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = true
    storage.spiderbots_enabled[second_player.index] = true
    storage.spiderbot_follower_count[player.force.name] = 10
    storage.spiderbot_follower_count[second_player.force.name] = 10

    local player_position = position_near_player(run, 0, 0)
    local second_position = p(player_position.x + 6, player_position.y)
    prepare_buildable_ground(surface, player_position, 8)
    prepare_buildable_ground(surface, second_position, 8)
    if not second_player.teleport(second_position, surface) then
        error("failed to move second player to multiplayer test surface")
    end
    second_character = second_player.character
    if not (second_character and second_character.valid) then
        error("second player missing character after multiplayer test teleport")
    end

    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local second_inventory = require_inventory(second_player)
    second_inventory.insert({ name = "small-electric-pole", count = 1, quality = "normal" })

    local primary_spiderbot = surface.create_entity {
        name = "spiderbot",
        position = p(player_position.x + 1, player_position.y),
        force = player.force,
        quality = "normal",
    }
    local second_spiderbot = surface.create_entity {
        name = "spiderbot",
        position = p(second_position.x - 1, second_position.y),
        force = second_player.force,
        quality = "normal",
    }
    if not primary_spiderbot or not second_spiderbot then
        error("failed to create multiplayer isolation spiderbots")
    end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = primary_spiderbot,
        source = require_character(player),
    })
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = second_spiderbot,
        source = second_character,
    })

    local ghost_position = p(player_position.x + 3, player_position.y + 3)
    run.context.connected_multiplayer_ghost_position = ghost_position
    prepare_buildable_ground(surface, ghost_position, 3)
    local ghost = surface.create_entity {
        name = "entity-ghost",
        inner_name = "small-electric-pole",
        position = ghost_position,
        force = game.forces.neutral,
        quality = "normal",
    }
    if not ghost then error("failed to create multiplayer shared neutral ghost") end
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    run.context.first_seen_task = nil
end

function cleanup_connected_player_shared_task(run)
    local second_index = run.context.connected_multiplayer_second_player_index
    local second_player = second_index and game.get_player(second_index)
    if second_player and second_player.valid then
        local old_surface = run.context.connected_multiplayer_second_old_surface
        local old_position = run.context.connected_multiplayer_second_old_position
        if old_surface and old_surface.valid and old_position then
            second_player.teleport(old_position, old_surface)
        end
        local inventory = second_player.get_main_inventory()
        local start_count = run.context.connected_multiplayer_second_start_poles or 0
        local current_count = inventory and inventory.valid and inventory.get_item_count({ name = "small-electric-pole", quality = "normal" }) or start_count
        if inventory and inventory.valid and current_count > start_count then
            inventory.remove({ name = "small-electric-pole", count = current_count - start_count, quality = "normal" })
        end
        if storage.spiderbots and storage.spiderbots[second_index] then
            for _, spiderbot_data in pairs(storage.spiderbots[second_index]) do
                local spiderbot = spiderbot_data.spiderbot
                if spiderbot and spiderbot.valid then
                    spiderbot.destroy({ raise_destroy = true })
                end
            end
            storage.spiderbots[second_index] = {}
        end
        storage.spiderbots_enabled[second_index] = nil
    end
end

cleanup_failed_run = function(run)
    cleanup_connected_player_shared_task(run)
end

function connected_player_shared_task_isolated_or_skipped(run)
    if run.context.connected_multiplayer_skipped then
        run.context.connected_multiplayer_skipped = nil
        return true
    end
    local second_index = run.context.connected_multiplayer_second_player_index
    local second_spiderbots = second_index and storage.spiderbots and storage.spiderbots[second_index]
    local built = find_entity_near("small-electric-pole", run.context.connected_multiplayer_ghost_position, nil, run.context.surface_name)
    local complete = built
        and built.valid
        and built.force.name == "neutral"
        and all_spiderbots_idle(run.player_index)
    if complete and second_spiderbots then
        for _, spiderbot_data in pairs(second_spiderbots) do
            if spiderbot_data.spiderbot and spiderbot_data.spiderbot.valid and spiderbot_data.status ~= "idle" then
                complete = false
                break
            end
        end
    end
    if complete then
        cleanup_connected_player_shared_task(run)
        return true
    end
    return false
end

function create_active_task_toggle_recall_ghost(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local surface = game.surfaces[run.context.surface_name]
    local position = position_near_player(run, 21, -7)
    prepare_buildable_ground(surface, position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.active_toggle_recall_ghost = ghost
    run.context.active_toggle_recall_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    storage.spiderbots_enabled[run.player_index] = true
    mark_expected_task(run, "build_ghost")
end

function trigger_active_task_toggle_recall(run)
    local player = require_player(run)
    local ghost = run.context.active_toggle_recall_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for active task toggle recall")
    end
    if not assigned_task_for_target(run, "build_ghost", ghost) then
        return false
    end
    call_registered_handler("toggle-spiderbots", {
        player_index = player.index,
        input_name = "toggle-spiderbots",
    })
    return true
end

function active_task_toggle_recall_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    local complete = spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) > run.context.active_toggle_recall_start_inventory
    if complete then
        cleanup_context_entity(run, "active_toggle_recall_ghost")
    end
    return complete
end

function trigger_invalid_spiderbot_path_request_cleanup(run)
    local player = require_player(run)
    local character = require_character(player)
    reset_active_spiderbots(run)
    local surface = character.surface
    local destination = position_near_player(run, 5, -12)
    destination = surface.find_non_colliding_position("spiderbot-leg-1", destination, 20, 0.5) or destination
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = destination,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create invalid-path cleanup spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
    local spiderbot_data = first_spiderbot_data(run.player_index)
    if not spiderbot_data then error("failed to register invalid-path cleanup spiderbot") end
    local ghost_position = position_near_player(run, 8, -12)
    prepare_buildable_ground(surface, ghost_position, 2)
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    local path_request_id = next_synthetic_path_request_id(run)
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id_for_entity(ghost),
        entity = ghost,
        projectile_item = "small-electric-pole",
    }
    spiderbot_data.status = "path_requested"
    spiderbot_data.path_request_id = path_request_id
    run.context.invalid_spiderbot_path_id = spiderbot_data.spiderbot_id
    run.context.invalid_spiderbot_path_ghost = ghost
    spiderbot.destroy()
    call_registered_handler(defines.events.on_script_path_request_finished, {
        id = path_request_id,
        path = synthetic_path_to(ghost_position),
    })
end

function invalid_spiderbot_path_request_cleaned_up(run)
    local spiderbots = storage.spiderbots and storage.spiderbots[run.player_index]
    cleanup_context_entity(run, "invalid_spiderbot_path_ghost")
    return spiderbot_count(run.player_index) == 0
        and (not spiderbots or spiderbots[run.context.invalid_spiderbot_path_id] == nil)
end

function create_registered_spiderbot_for_test(player, character, surface, position)
    local spiderbot = surface.create_entity {
        name = "spiderbot",
        position = position,
        force = player.force,
        quality = "normal",
    }
    if not spiderbot then error("failed to create registered test spiderbot") end
    call_registered_handler(defines.events.on_trigger_created_entity, {
        entity = spiderbot,
        source = character,
    })
    return spiderbot
end

function create_assigned_spiderbot_destroy_requeue_task(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = game.surfaces[run.context.surface_name]
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 2
    storage.spiderbots_enabled[run.player_index] = true
    local first_position = position_near_player(run, 4, -12)
    local second_position = position_near_player(run, 6, -12)
    prepare_buildable_ground(surface, first_position, 3)
    prepare_buildable_ground(surface, second_position, 3)
    create_registered_spiderbot_for_test(player, character, surface, first_position)
    create_registered_spiderbot_for_test(player, character, surface, second_position)
    if spiderbot_count(run.player_index) ~= 2 then
        error("failed to register two spiderbots for assigned destroy requeue")
    end
    local ghost_position = position_near_player(run, 21, -12)
    prepare_buildable_ground(surface, ghost_position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = create_small_pole_ghost(surface, player, ghost_position)
    run.context.assigned_destroy_requeue_ghost_position = ghost_position
    run.context.assigned_destroy_requeue_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function trigger_assigned_spiderbot_destroy_requeues_task(run)
    local ghost = run.context.assigned_destroy_requeue_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for assigned destroy requeue")
    end
    local spiderbot_data, spiderbot_id = assigned_task_for_target(run, "build_ghost", ghost)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_id and spiderbot and spiderbot.valid) then
        return false
    end
    run.context.assigned_destroy_requeue_destroyed_id = spiderbot_id
    spiderbot.destroy({ raise_destroy = true })
    return true
end

function assigned_spiderbot_destroy_requeued_task(run)
    local spiderbots = storage.spiderbots and storage.spiderbots[run.player_index]
    local complete = expected_task_was_seen(run)
        and spiderbot_count(run.player_index) == 1
        and run.context.assigned_destroy_requeue_destroyed_id ~= nil
        and (not spiderbots or spiderbots[run.context.assigned_destroy_requeue_destroyed_id] == nil)
        and find_entity_near("small-electric-pole", run.context.assigned_destroy_requeue_ghost_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
    if complete then
        run.context.assigned_destroy_requeue_ghost = nil
        reset_active_spiderbots(run)
    end
    return complete
end

function deploy_transition_spiderbot(run)
    local player = require_player(run)
    reset_active_spiderbots(run)
    storage.spiderbot_follower_count[player.force.name] = 1
    player.clear_cursor()
    local cursor_stack = player.cursor_stack
    if not (cursor_stack and cursor_stack.valid) then
        error("missing cursor stack")
    end
    cursor_stack.set_stack({ name = "spiderbot", count = 1, quality = "normal" })
    local position = position_near_player(run, 3, 0)
    prepare_buildable_ground(player.surface, position, 4)
    player.use_from_cursor(position)
end

function transition_spiderbot_deployed(run)
    return spiderbot_count(run.player_index) == 1
        and all_spiderbots_idle(run.player_index)
end

function trigger_changed_surface_redeploy(run)
    local player = require_player(run)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for changed-surface redeploy")
    end
    run.context.changed_surface_old_unit_number = spiderbot.unit_number
    local surface = ensure_surface(TRANSITION_SURFACE_NAME, START_POSITION)
    prepare_buildable_ground(surface, START_POSITION, 12)
    if not player.teleport(START_POSITION, surface) then
        error("failed to teleport player to transition surface")
    end
    run.context.surface_name = surface.name
    call_registered_handler(defines.events.on_player_changed_surface, {
        player_index = player.index,
    })
end

function changed_surface_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.changed_surface_old_unit_number
        and spiderbot.surface == character.surface
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function create_active_task_surface_change_ghost(run)
    local player = require_player(run)
    local current_surface = game.surfaces[run.context.surface_name]
    local ghost_position = position_near_player(run, 21, -5)
    prepare_buildable_ground(current_surface, ghost_position, 2)
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local ghost = create_small_pole_ghost(current_surface, player, ghost_position)
    run.context.active_surface_change_ghost = ghost
    mark_expected_task(run, "build_ghost")
end

function trigger_active_task_changed_surface_redeploy(run)
    local player = require_player(run)
    local ghost = run.context.active_surface_change_ghost
    if not (ghost and ghost.valid) then
        error("missing ghost for active-task changed-surface redeploy")
    end
    local spiderbot_data = assigned_task_for_target(run, "build_ghost", ghost)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot and spiderbot.valid) then
        return false
    end
    run.context.active_surface_change_old_unit_number = spiderbot.unit_number
    local surface = ensure_surface(ACTIVE_TASK_SURFACE_CHANGE_TEST_SURFACE_NAME, START_POSITION)
    prepare_buildable_ground(surface, START_POSITION, 12)
    if not player.teleport(START_POSITION, surface) then
        error("failed to teleport player for active-task surface change")
    end
    run.context.surface_name = surface.name
    call_registered_handler(defines.events.on_player_changed_surface, {
        player_index = player.index,
    })
    return true
end

function active_task_changed_surface_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    local ghost = run.context.active_surface_change_ghost
    local redeployed = spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.active_surface_change_old_unit_number
        and spiderbot.surface == character.surface
        and spiderbot.follow_target == character
        and ghost
        and ghost.valid
        and all_spiderbots_idle(run.player_index)
    if redeployed then
        ghost.destroy({ raise_destroy = true })
        run.context.active_surface_change_ghost = nil
    end
    return redeployed
end

function trigger_changed_position_redeploy(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for changed-position redeploy")
    end
    run.context.changed_position_old_unit_number = spiderbot.unit_number
    storage.previous_player_position = storage.previous_player_position or {}
    storage.previous_player_surface_index = storage.previous_player_surface_index or {}
    storage.previous_player_position[player.index] = character.position
    storage.previous_player_surface_index[player.index] = character.surface_index
    local target = p(character.position.x + 70, character.position.y)
    character.surface.request_to_generate_chunks(target, 4)
    character.surface.force_generate_chunk_requests()
    prepare_buildable_ground(character.surface, target, 12)
    if not player.teleport(target, character.surface) then
        error("failed to teleport player for changed-position redeploy")
    end
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = player.index,
    })
end

function changed_position_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number ~= run.context.changed_position_old_unit_number
        and spiderbot.surface == character.surface
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function trigger_small_position_change_no_redeploy(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for small position-change no-redeploy")
    end
    run.context.small_position_old_unit_number = spiderbot.unit_number
    storage.previous_player_position = storage.previous_player_position or {}
    storage.previous_player_surface_index = storage.previous_player_surface_index or {}
    storage.previous_player_position[player.index] = character.position
    storage.previous_player_surface_index[player.index] = character.surface_index
    local target = p(character.position.x + 10, character.position.y)
    character.surface.request_to_generate_chunks(target, 4)
    character.surface.force_generate_chunk_requests()
    prepare_buildable_ground(character.surface, target, 12)
    if not player.teleport(target, character.surface) then
        error("failed to teleport player for small position-change no-redeploy")
    end
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = player.index,
    })
end

function small_position_change_no_redeploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    return spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.small_position_old_unit_number
        and spiderbot.surface == character.surface
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function factory_travel_planet()
    local ok, planets = pcall(function() return game.planets end)
    if not ok or not planets then return nil end
    local planet = planets["factory-travel-surface"]
    if planet and planet.valid then
        return planet
    end
end

function trigger_factory_travel_surface_exception(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for factory-travel surface exception")
    end
    local planet = factory_travel_planet()
    if not planet then
        run.context.factory_travel_exception_skipped = true
        return
    end
    local old_surface = character.surface
    local old_position = character.position
    local surface = ensure_surface(FACTORY_TRAVEL_TEST_SURFACE_NAME, START_POSITION)
    local surface_planet = surface.planet
    if not (surface_planet and surface_planet.valid and surface_planet.name == "factory-travel-surface") then
        local ok, err = pcall(function()
            planet.associate_surface(surface)
        end)
        if not ok then
            error("failed to associate factory-travel test surface: " .. tostring(err))
        end
    end
    prepare_buildable_ground(surface, START_POSITION, 12)
    run.context.factory_travel_old_surface = old_surface
    run.context.factory_travel_old_position = old_position
    run.context.factory_travel_old_surface_name = run.context.surface_name
    run.context.factory_travel_spiderbot_unit_number = spiderbot.unit_number
    run.context.factory_travel_spiderbot_surface_index = spiderbot.surface_index
    if not player.teleport(START_POSITION, surface) then
        error("failed to teleport player to factory-travel test surface")
    end
    run.context.surface_name = surface.name
    call_registered_handler(defines.events.on_player_changed_surface, {
        player_index = player.index,
    })
    character = require_character(player)
    storage.previous_player_position = storage.previous_player_position or {}
    storage.previous_player_surface_index = storage.previous_player_surface_index or {}
    storage.previous_player_position[player.index] = character.position
    storage.previous_player_surface_index[player.index] = character.surface_index
    local moved_position = p(character.position.x + 70, character.position.y)
    surface.request_to_generate_chunks(moved_position, 4)
    surface.force_generate_chunk_requests()
    prepare_buildable_ground(surface, moved_position, 12)
    if not player.teleport(moved_position, surface) then
        error("failed to move player on factory-travel test surface")
    end
    call_registered_handler(defines.events.on_player_changed_position, {
        player_index = player.index,
    })
end

function factory_travel_surface_exception_complete(run)
    if run.context.factory_travel_exception_skipped then
        run.context.factory_travel_exception_skipped = nil
        return true
    end
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    local ignored = spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.factory_travel_spiderbot_unit_number
        and spiderbot.surface_index == run.context.factory_travel_spiderbot_surface_index
        and character.surface.name == FACTORY_TRAVEL_TEST_SURFACE_NAME
        and first_spiderbot_idle_without_task(run)
    if ignored then
        local old_surface = run.context.factory_travel_old_surface
        local old_position = run.context.factory_travel_old_position
        if old_surface and old_surface.valid and old_position then
            player.teleport(old_position, old_surface)
        end
        run.context.surface_name = run.context.factory_travel_old_surface_name
        run.context.factory_travel_old_surface = nil
        run.context.factory_travel_old_position = nil
        run.context.factory_travel_old_surface_name = nil
    end
    return ignored
end

function trigger_disallowed_controller_surface_change(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for disallowed-controller surface change")
    end
    run.context.disallowed_controller_character = character
    run.context.disallowed_controller_spiderbot_unit_number = spiderbot.unit_number
    player.set_controller {
        type = defines.controllers.god,
        surface = character.surface,
        position = character.position,
    }
    call_registered_handler(defines.events.on_player_changed_surface, {
        player_index = player.index,
    })
end

function disallowed_controller_surface_change_ignored(run)
    local player = require_player(run)
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.god
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.disallowed_controller_spiderbot_unit_number
        and all_spiderbots_idle(run.player_index)
end

function restore_character_controller_after_disallowed_controller(run)
    local player = require_player(run)
    local character = run.context.disallowed_controller_character
    if not (character and character.valid) then
        error("missing character to restore after disallowed-controller test")
    end
    player.set_controller {
        type = defines.controllers.character,
        character = character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function disallowed_controller_character_restored(run)
    local player = require_player(run)
    local character = run.context.disallowed_controller_character
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.character
        and character
        and character.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.disallowed_controller_spiderbot_unit_number
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function trigger_disallowed_controller_work_ignore(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = character.surface
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for disallowed-controller work ignore")
    end
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local position = p(character.position.x + 8, character.position.y + 2)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.disallowed_work_character = character
    run.context.disallowed_work_ghost = ghost
    run.context.disallowed_work_spiderbot_unit_number = spiderbot.unit_number
    run.context.disallowed_work_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    player.set_controller {
        type = defines.controllers.god,
        surface = surface,
        position = character.position,
    }
end

function disallowed_controller_work_was_ignored(run)
    if game.tick - run.context.disallowed_work_started_tick < 60 then return false end
    local player = require_player(run)
    local ghost = run.context.disallowed_work_ghost
    local spiderbot = first_spiderbot(run.player_index)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = player.controller_type == defines.controllers.god
        and ghost
        and ghost.valid
        and no_tasks_seen
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.disallowed_work_spiderbot_unit_number
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        run.context.disallowed_work_ghost = nil
    end
    return ignored
end

function restore_character_controller_after_disallowed_work(run)
    local player = require_player(run)
    local character = run.context.disallowed_work_character
    if not (character and character.valid) then
        error("missing character to restore after disallowed-controller work test")
    end
    player.set_controller {
        type = defines.controllers.character,
        character = character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function disallowed_work_character_restored(run)
    local player = require_player(run)
    local character = run.context.disallowed_work_character
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.character
        and character
        and character.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.disallowed_work_spiderbot_unit_number
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

local disallowed_controller_matrix_cases = {
    { name = "spectator", controller = defines.controllers.spectator, x_offset = 12 },
    { name = "ghost", controller = defines.controllers.ghost, x_offset = 14 },
}

function restore_disallowed_controller_matrix_character(run)
    local player = require_player(run)
    local state = run.context.disallowed_controller_matrix
    local character = state and state.character
    if not (character and character.valid) then
        error("missing character to restore after disallowed-controller matrix")
    end
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end
    if player.controller_type ~= defines.controllers.character then
        player.set_controller {
            type = defines.controllers.character,
            character = character,
        }
    end
    if state.original_admin ~= nil then
        pcall(function() player.admin = state.original_admin end)
    end
    if state.original_cheat_mode ~= nil then
        pcall(function() player.cheat_mode = state.original_cheat_mode end)
    end
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function start_next_disallowed_controller_matrix_case(run)
    local player = require_player(run)
    local state = run.context.disallowed_controller_matrix
    while state do
        state.index = (state.index or 0) + 1
        local case = state.cases[state.index]
        if not case then
            restore_disallowed_controller_matrix_character(run)
            state.done = true
            state.current_case = nil
            state.current_ghost = nil
            return
        end
        restore_disallowed_controller_matrix_character(run)
        local character = state.character
        local surface = character.surface
        local spiderbot = first_spiderbot(run.player_index)
        if not (spiderbot and spiderbot.valid) then
            error("missing spiderbot for disallowed-controller matrix")
        end
        local position = p(character.position.x + case.x_offset, character.position.y + 3)
        prepare_buildable_ground(surface, position, 2)
        local ghost = create_small_pole_ghost(surface, player, position)
        state.current_case = case
        state.current_ghost = ghost
        state.started_tick = game.tick
        run.context.expected_task = nil
        run.context.expected_tasks = nil
        run.context.seen_tasks = {}
        local ok, err = pcall(function()
            player.set_controller { type = case.controller }
        end)
        if ok and player.controller_type == case.controller then
            call_registered_handler(defines.events.on_player_controller_changed, {
                player_index = player.index,
            })
            return
        end
        state.skipped[case.name] = tostring(err or ("controller remained " .. tostring(player.controller_type)))
        if ghost and ghost.valid then
            ghost.destroy({ raise_destroy = true })
        end
        state.current_case = nil
        state.current_ghost = nil
    end
end

function trigger_disallowed_controller_matrix_ignore(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for disallowed-controller matrix")
    end
    local admin_ok, original_admin = pcall(function() return player.admin end)
    local cheat_ok, original_cheat_mode = pcall(function() return player.cheat_mode end)
    insert(player, { name = "small-electric-pole", count = #disallowed_controller_matrix_cases, quality = "normal" })
    run.context.disallowed_controller_matrix = {
        cases = disallowed_controller_matrix_cases,
        character = character,
        spiderbot_unit_number = spiderbot.unit_number,
        original_admin = admin_ok and original_admin or nil,
        original_cheat_mode = cheat_ok and original_cheat_mode or nil,
        index = 0,
        completed_count = 0,
        skipped = {},
    }
    start_next_disallowed_controller_matrix_case(run)
end

function disallowed_controller_matrix_was_ignored(run)
    local state = run.context.disallowed_controller_matrix
    if not state then return false end
    if state.done then
        if (state.completed_count or 0) == 0 then
            error("all disallowed-controller matrix cases were skipped")
        end
        return true
    end
    local case = state.current_case
    local ghost = state.current_ghost
    if not case then
        start_next_disallowed_controller_matrix_case(run)
        return false
    end
    if game.tick - (state.started_tick or 0) < 60 then return false end
    local player = require_player(run)
    local spiderbot = first_spiderbot(run.player_index)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    local ignored = player.controller_type == case.controller
        and ghost
        and ghost.valid
        and no_tasks_seen
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == state.spiderbot_unit_number
        and first_spiderbot_idle_without_task(run)
    if ignored then
        ghost.destroy({ raise_destroy = true })
        state.completed_count = (state.completed_count or 0) + 1
        state.current_case = nil
        state.current_ghost = nil
        restore_disallowed_controller_matrix_character(run)
        start_next_disallowed_controller_matrix_case(run)
        return state.done and state.completed_count > 0
    end
    return false
end

function trigger_disallowed_controller_toggle_recall(run)
    local player = require_player(run)
    local character = require_character(player)
    local inventory = require_inventory(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for disallowed-controller toggle recall")
    end
    run.context.disallowed_toggle_character = character
    run.context.disallowed_toggle_spiderbot_unit_number = spiderbot.unit_number
    run.context.disallowed_toggle_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    storage.spiderbots_enabled[run.player_index] = true
    player.set_controller {
        type = defines.controllers.god,
        surface = character.surface,
        position = character.position,
    }
    call_registered_handler("toggle-spiderbots", {
        player_index = player.index,
        input_name = "toggle-spiderbots",
    })
    run.context.disallowed_toggle_started_tick = game.tick
end

function disallowed_controller_toggle_did_not_recall(run)
    if game.tick - run.context.disallowed_toggle_started_tick < 60 then return false end
    local player = require_player(run)
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.god
        and storage.spiderbots_enabled[run.player_index] == false
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.disallowed_toggle_spiderbot_unit_number
end

function restore_character_after_disallowed_toggle(run)
    local player = require_player(run)
    local character = run.context.disallowed_toggle_character
    if not (character and character.valid) then
        error("missing character to restore after disallowed-controller toggle")
    end
    player.set_controller {
        type = defines.controllers.character,
        character = character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function disallowed_controller_toggle_recalled_after_restore(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return player.controller_type == defines.controllers.character
        and storage.spiderbots_enabled[run.player_index] == false
        and spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) > run.context.disallowed_toggle_start_inventory
end

function trigger_cutscene_controller_work_ignore(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = character.surface
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for cutscene-controller work ignore")
    end
    insert(player, { name = "small-electric-pole", count = 1, quality = "normal" })
    local position = p(character.position.x + 10, character.position.y + 2)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    run.context.cutscene_work_character = character
    run.context.cutscene_work_ghost = ghost
    run.context.cutscene_work_position = position
    run.context.cutscene_work_spiderbot_unit_number = spiderbot.unit_number
    run.context.cutscene_work_started_tick = game.tick
    run.context.expected_task = nil
    run.context.expected_tasks = nil
    run.context.seen_tasks = {}
    player.set_controller {
        type = defines.controllers.cutscene,
        start_position = character.position,
        start_zoom = 1,
        waypoints = {
            {
                position = p(character.position.x + 2, character.position.y),
                transition_time = 1,
                time_to_wait = 60 * 10,
                zoom = 1,
            },
        },
    }
end

function cutscene_controller_work_was_ignored(run)
    if game.tick - run.context.cutscene_work_started_tick < 60 then return false end
    local player = require_player(run)
    local ghost = run.context.cutscene_work_ghost
    local spiderbot = first_spiderbot(run.player_index)
    local no_tasks_seen = next(run.context.seen_tasks or {}) == nil
    return player.controller_type == defines.controllers.cutscene
        and player.cutscene_character == run.context.cutscene_work_character
        and ghost
        and ghost.valid
        and no_tasks_seen
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.cutscene_work_spiderbot_unit_number
        and first_spiderbot_idle_without_task(run)
end

function restore_character_after_cutscene_work(run)
    local player = require_player(run)
    local character = run.context.cutscene_work_character
    if not (character and character.valid) then
        error("missing character to restore after cutscene-controller work test")
    end
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end
    if player.controller_type ~= defines.controllers.character then
        player.set_controller {
            type = defines.controllers.character,
            character = character,
        }
    end
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
    mark_expected_task(run, "build_ghost")
end

function cutscene_work_built_after_restore(run)
    local player = require_player(run)
    local character = run.context.cutscene_work_character
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.character
        and character
        and character.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.cutscene_work_spiderbot_unit_number
        and spiderbot.follow_target == character
        and expected_task_was_seen(run)
        and find_entity_near("small-electric-pole", run.context.cutscene_work_position, nil, run.context.surface_name) ~= nil
        and all_spiderbots_idle(run.player_index)
end

function trigger_controller_changed_relink(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = character.surface
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for controller relink")
    end
    local dummy_position = position_near_player(run, 4, 2)
    prepare_buildable_ground(surface, dummy_position, 4)
    local dummy = surface.create_entity {
        name = "car",
        position = dummy_position,
        force = player.force,
    }
    if not dummy then error("failed to create controller relink dummy target") end
    run.context.controller_relink_dummy = dummy
    spiderbot.follow_target = dummy
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function controller_changed_relink_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    local dummy = run.context.controller_relink_dummy
    if dummy and dummy.valid then
        dummy.destroy({ raise_destroy = true })
    end
    run.context.controller_relink_dummy = nil
    return spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function trigger_character_replacement_relink(run)
    local player = require_player(run)
    local old_character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for character replacement relink")
    end
    local position = p(old_character.position.x + 3, old_character.position.y + 4)
    local surface = old_character.surface
    prepare_buildable_ground(surface, position, 3)
    local new_character = surface.create_entity {
        name = "character",
        position = position,
        force = player.force,
    }
    if not new_character then error("failed to create replacement character") end
    new_character.destructible = false
    run.context.replacement_old_character = old_character
    run.context.replacement_new_character = new_character
    run.context.replacement_spiderbot_unit_number = spiderbot.unit_number
    player.set_controller {
        type = defines.controllers.character,
        character = new_character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function character_replacement_relinked(run)
    local player = require_player(run)
    local new_character = run.context.replacement_new_character
    local spiderbot = first_spiderbot(run.player_index)
    return player.controller_type == defines.controllers.character
        and player.character == new_character
        and new_character
        and new_character.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.replacement_spiderbot_unit_number
        and spiderbot.follow_target == new_character
        and all_spiderbots_idle(run.player_index)
end

function restore_original_character_after_replacement(run)
    local player = require_player(run)
    local old_character = run.context.replacement_old_character
    if not (old_character and old_character.valid) then
        error("missing original character after replacement relink")
    end
    player.set_controller {
        type = defines.controllers.character,
        character = old_character,
    }
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function original_character_restored_after_replacement(run)
    local player = require_player(run)
    local old_character = run.context.replacement_old_character
    local new_character = run.context.replacement_new_character
    local spiderbot = first_spiderbot(run.player_index)
    local restored = player.controller_type == defines.controllers.character
        and player.character == old_character
        and old_character
        and old_character.valid
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.replacement_spiderbot_unit_number
        and spiderbot.follow_target == old_character
        and all_spiderbots_idle(run.player_index)
    if restored then
        if new_character and new_character.valid then
            new_character.destroy({ raise_destroy = true })
        end
        run.context.replacement_old_character = nil
        run.context.replacement_new_character = nil
    end
    return restored
end

function trigger_surface_mismatch_relink_reset(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for surface-mismatch relink reset")
    end
    local other_surface = ensure_surface(TRANSITION_SURFACE_NAME, START_POSITION)
    local old_unit_number = spiderbot.unit_number
    if not spiderbot.teleport(START_POSITION, other_surface, true) then
        error("failed to move spiderbot to mismatch surface")
    end
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = "surface-mismatch-relink-reset",
    }
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = next_synthetic_path_request_id(run)
    run.context.surface_mismatch_relink_unit_number = old_unit_number
    run.context.surface_mismatch_player_surface_index = character.surface_index
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function surface_mismatch_relink_reset_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    return spiderbot_data
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.surface_mismatch_relink_unit_number
        and spiderbot.surface_index == run.context.surface_mismatch_player_surface_index
        and spiderbot.surface_index == character.surface_index
        and spiderbot.follow_target == character
        and spiderbot_data.status == "idle"
        and spiderbot_data.task == nil
        and spiderbot_data.path_request_id == nil
end

function trigger_invalid_assigned_target_relink_reset(run)
    local player = require_player(run)
    local character = require_character(player)
    local surface = character.surface
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for invalid assigned-target relink reset")
    end
    local position = position_near_player(run, 8, 2)
    prepare_buildable_ground(surface, position, 2)
    local ghost = create_small_pole_ghost(surface, player, position)
    local task_id = task_id_for_entity(ghost)
    ghost.destroy({ raise_destroy = true })
    spiderbot_data.task = {
        task_type = "build_ghost",
        task_id = task_id,
        entity = ghost,
        projectile_item = "small-electric-pole",
    }
    spiderbot_data.status = "task_assigned"
    spiderbot_data.path_request_id = next_synthetic_path_request_id(run)
    run.context.invalid_assigned_target_relink_unit_number = spiderbot.unit_number
    call_registered_handler(defines.events.on_player_controller_changed, {
        player_index = player.index,
    })
end

function invalid_assigned_target_relink_reset_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    return spiderbot_data
        and spiderbot
        and spiderbot.valid
        and spiderbot.unit_number == run.context.invalid_assigned_target_relink_unit_number
        and spiderbot.follow_target == character
        and spiderbot_data.status == "idle"
        and spiderbot_data.task == nil
        and spiderbot_data.path_request_id == nil
end

function trigger_previous_entity_relink(run)
    local player = require_player(run)
    local surface = game.surfaces[run.context.surface_name]
    local spiderbot = first_spiderbot(run.player_index)
    if not (spiderbot and spiderbot.valid) then
        error("missing spiderbot for previous-entity relink")
    end
    local dummy_position = position_near_player(run, 6, 2)
    prepare_buildable_ground(surface, dummy_position, 4)
    local dummy = surface.create_entity {
        name = "car",
        position = dummy_position,
        force = player.force,
    }
    if not dummy then error("failed to create previous-entity relink dummy target") end
    run.context.previous_entity_relink_dummy = dummy
    spiderbot.follow_target = dummy
    storage.previous_player_entity = storage.previous_player_entity or {}
    storage.previous_player_entity[player.index] = -1
end

function previous_entity_relink_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local spiderbot = first_spiderbot(run.player_index)
    local dummy = run.context.previous_entity_relink_dummy
    if dummy and dummy.valid then
        dummy.destroy({ raise_destroy = true })
    end
    run.context.previous_entity_relink_dummy = nil
    return spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and all_spiderbots_idle(run.player_index)
end

function trigger_custom_input_toggle_deploy(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    reset_active_spiderbots(run)
    storage.spiderbots_enabled[run.player_index] = false
    storage.spiderbot_follower_count[player.force.name] = 1
    remove_all_qualities_from_main_inventory(player, "spiderbot")
    insert(player, { name = "spiderbot", count = 1, quality = "normal" })
    run.context.custom_input_deploy_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    call_registered_handler("toggle-spiderbots", {
        player_index = player.index,
        input_name = "toggle-spiderbots",
    })
end

function custom_input_toggle_deploy_complete(run)
    local player = require_player(run)
    local character = require_character(player)
    local inventory = require_inventory(player)
    local spiderbot = first_spiderbot(run.player_index)
    return storage.spiderbots_enabled[run.player_index] == true
        and shortcut_toggled(player) == true
        and spiderbot_count(run.player_index) == 1
        and spiderbot
        and spiderbot.valid
        and spiderbot.follow_target == character
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) < run.context.custom_input_deploy_start_inventory
        and all_spiderbots_idle(run.player_index)
end

function trigger_custom_input_toggle_recall(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    if spiderbot_count(run.player_index) < 1 then
        error("missing spiderbot for custom input recall")
    end
    run.context.custom_input_recall_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = "normal" })
    storage.spiderbots_enabled[run.player_index] = true
    call_registered_handler("toggle-spiderbots", {
        player_index = player.index,
        input_name = "toggle-spiderbots",
    })
end

function custom_input_toggle_recall_complete(run)
    local player = require_player(run)
    local inventory = require_inventory(player)
    return storage.spiderbots_enabled[run.player_index] == false
        and spiderbot_count(run.player_index) == 0
        and inventory.get_item_count({ name = "spiderbot", quality = "normal" }) > run.context.custom_input_recall_start_inventory
        and shortcut_toggled(player) == false
end

function mine_tracked_spiderbot_manually(run)
    local player = require_player(run)
    local inventory = require_character_inventory(player)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for manual mining cleanup")
    end
    local quality = spiderbot.quality.name
    local item_stack = { name = "spiderbot", count = 1, quality = quality }
    if not inventory.can_insert(item_stack) then
        inventory.remove({ name = "iron-plate", count = 1000, quality = "normal" })
    end
    if not inventory.can_insert(item_stack) then
        error("manual mining test needs inventory space for spiderbot")
    end
    run.context.manual_mine_spiderbot_id = spiderbot_data.spiderbot_id
    run.context.manual_mine_quality = quality
    run.context.manual_mine_start_inventory = inventory.get_item_count({ name = "spiderbot", quality = quality })
    if not spiderbot.mine { inventory = inventory, force = false, raise_destroyed = true } then
        error("failed to mine tracked spiderbot")
    end
end

function manually_mined_spiderbot_removed(run)
    local player = require_player(run)
    local inventory = require_character_inventory(player)
    local spiderbots = storage.spiderbots and storage.spiderbots[run.player_index]
    local quality = run.context.manual_mine_quality or "normal"
    return spiderbot_count(run.player_index) == 0
        and (not spiderbots or spiderbots[run.context.manual_mine_spiderbot_id] == nil)
        and inventory.get_item_count({ name = "spiderbot", quality = quality }) > run.context.manual_mine_start_inventory
end

function destroy_tracked_spiderbot_externally(run)
    local spiderbot_data = first_spiderbot_data(run.player_index)
    local spiderbot = spiderbot_data and spiderbot_data.spiderbot
    if not (spiderbot_data and spiderbot and spiderbot.valid) then
        error("missing spiderbot for external destroy cleanup")
    end
    run.context.external_destroy_spiderbot_id = spiderbot_data.spiderbot_id
    spiderbot.destroy({ raise_destroy = true })
    call_registered_handler(defines.events.on_object_destroyed, {
        registration_number = spiderbot_data.spiderbot_id,
    })
end

function externally_destroyed_spiderbot_removed(run)
    local spiderbots = storage.spiderbots and storage.spiderbots[run.player_index]
    return spiderbot_count(run.player_index) == 0
        and (not spiderbots or spiderbots[run.context.external_destroy_spiderbot_id] == nil)
end

add_section("bootstrap", "bootstrap and prototype checks")
add_action("prepare isolated test surface", setup_run, 15)
add_action("validate storage bootstrap", validate_storage_bootstrap, 1)
add_action("validate 0.2.0 migration contract", validate_0_2_0_migration_contract, 1)
add_action("validate generated projectile prototypes", validate_generated_projectile_prototypes, 1)
add_section("capsule-follow-color", "capsule deploy, following, and color", { prefix = "setup" })
add_action("use spiderbot capsule", use_spiderbot_capsule, 1)
add_wait("capsule deploy registered one following spiderbot", deploy_complete, 60 * 10, 15)
add_action("change player color", change_player_color, 15)
add_wait("idle spiderbot synced player color", player_color_sync_complete, 60 * 5, 1)
add_action("create assigned-task color ghost", create_assigned_task_color_ghost, 1)
add_wait("mod assigned color-preservation task", assigned_task_color_task_started, 60 * 10, 1)
add_wait("assigned-task spiderbot preserved task color", assigned_task_color_preserved, 60 * 5, 15)
add_section("cursor-follow-targets", "cursor visualization and follow targets", { prefix = "deploy" })
add_action("show cursor visualization", show_cursor_visualization, 1)
add_wait("cursor visualization render object exists", cursor_visualization_complete, 60 * 5, 1)
add_action("disable cursor visualization", disable_cursor_visualization, 1)
add_wait("disabled cursor visualization cleared render object", cursor_visualization_cleared, 60 * 5, 1)
add_action("clear cursor visualization", clear_cursor_visualization, 1)
add_wait("cursor visualization render object cleared", cursor_visualization_cleared, 60 * 5, 15)
add_action("show upgrade cursor visualization", show_upgrade_cursor_visualization, 1)
add_wait("upgrade cursor visualization render object exists", cursor_visualization_complete, 60 * 5, 1)
add_action("clear upgrade cursor visualization", clear_cursor_visualization, 1)
add_wait("upgrade cursor visualization render object cleared", cursor_visualization_cleared, 60 * 5, 15)
add_action("show blueprint cursor visualization", show_blueprint_cursor_visualization, 1)
add_wait("blueprint cursor visualization render object exists", cursor_visualization_complete, 60 * 5, 1)
add_action("clear blueprint cursor visualization", clear_cursor_visualization, 1)
add_wait("blueprint cursor visualization render object cleared", cursor_visualization_cleared, 60 * 5, 15)
add_action("show blueprint book cursor visualization", show_blueprint_book_cursor_visualization, 1)
add_wait("blueprint book cursor visualization render object exists", cursor_visualization_complete, 60 * 5, 1)
add_action("clear blueprint book cursor visualization", clear_cursor_visualization, 1)
add_wait("blueprint book cursor visualization render object cleared", cursor_visualization_cleared, 60 * 5, 15)
add_action("enter test vehicle", enter_test_vehicle, 1)
add_wait("idle spiderbot followed vehicle", vehicle_follow_complete, 60 * 5, 1)
add_action("destroy followed vehicle", destroy_followed_vehicle, 1)
add_wait("idle spiderbot followed character after vehicle destruction", destroyed_followed_vehicle_relinked, 60 * 5, 1)
add_action("exit test vehicle", exit_test_vehicle, 1)
add_wait("idle spiderbot followed character again", character_follow_complete, 60 * 5, 15)
add_section("entity-proxy-work", "entity work and item request proxies", { prefix = "deploy" })
add_action("create entity ghost", create_build_ghost, 1)
add_wait("spiderbot built entity ghost", build_ghost_complete, 60 * 20, 15)
add_action("create upgrade order", create_upgrade_order, 1)
add_wait("spiderbot upgraded entity", upgrade_complete, 60 * 20, 15)
add_action("create underground belt upgrade order", create_underground_belt_upgrade_order, 1)
add_wait("spiderbot upgraded underground belt preserving type", underground_belt_upgrade_complete, 60 * 20, 15)
add_action("create loader upgrade order if available", create_loader_upgrade_order, 1)
add_wait("spiderbot upgraded loader preserving type if available", loader_upgrade_complete, 60 * 20, 15)
add_action("create entity deconstruction order", create_deconstruction_order, 1)
add_wait("spiderbot deconstructed entity", deconstruction_complete, 60 * 20, 15)
add_action("create tree deconstruction order", create_tree_deconstruction_order, 1)
add_wait("spiderbot deconstructed tree and returned product", tree_deconstruction_complete, 60 * 20, 15)
add_action("create rock deconstruction order", create_rock_deconstruction_order, 1)
add_wait("spiderbot deconstructed rock and returned product", rock_deconstruction_complete, 60 * 20, 15)
add_action("create vehicle contents deconstruction order", create_vehicle_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed vehicle with contents", vehicle_contents_deconstruction_complete, 60 * 20, 15)
add_action("create spider-vehicle contents deconstruction order", create_spider_vehicle_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed spider-vehicle with contents", spider_vehicle_contents_deconstruction_complete, 60 * 20, 15)
add_action("create cargo-wagon contents deconstruction order", create_cargo_wagon_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed cargo-wagon with contents", cargo_wagon_contents_deconstruction_complete, 60 * 20, 15)
add_action("create item entity deconstruction order", create_item_entity_deconstruction_order, 1)
add_wait("spiderbot deconstructed item entity", item_entity_deconstruction_complete, 60 * 20, 15)
add_action("create belt contents deconstruction order", create_belt_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed belt with contents", belt_contents_deconstruction_complete, 60 * 20, 15)
add_action("create splitter contents deconstruction order", create_splitter_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed splitter with contents", splitter_contents_deconstruction_complete, 60 * 20, 15)
add_action("create underground-belt contents deconstruction order", create_underground_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed underground-belt with contents", underground_contents_deconstruction_complete, 60 * 20, 15)
add_action("create loader contents deconstruction order", create_loader_contents_deconstruction_order, 1)
add_wait("spiderbot deconstructed loader with contents", loader_contents_deconstruction_complete, 60 * 20, 15)
add_action("create item request proxy", create_item_request_proxy, 1)
add_wait("spiderbot fulfilled item request proxy", item_request_complete, 60 * 20, 15)
add_action("create chest inventory insertion proxy", create_chest_inventory_insertion_proxy, 1)
add_wait("spiderbot fulfilled chest inventory insertion proxy", chest_inventory_insertion_complete, 60 * 20, 15)
add_action("create item removal request proxy", create_item_removal_request_proxy, 1)
add_wait("spiderbot fulfilled item removal proxy", item_removal_request_complete, 60 * 20, 15)
add_action("create chest inventory removal proxy", create_chest_inventory_removal_proxy, 1)
add_wait("spiderbot fulfilled chest inventory removal proxy", chest_inventory_removal_complete, 60 * 20, 15)
add_action("create bidirectional item request proxy", create_bidirectional_item_request_proxy, 1)
add_wait("spiderbot fulfilled bidirectional item request proxy", bidirectional_item_request_complete, 60 * 30, 15)
add_action("create multi-item request proxy", create_multi_item_request_proxy, 1)
add_wait("spiderbot fulfilled multi-item request proxy", multi_item_request_complete, 60 * 30, 15)
add_action("create later-plan item request proxy", create_later_item_request_plan_proxy, 1)
add_wait("spiderbot fulfilled later satisfiable item request plan", later_item_request_plan_complete, 60 * 20, 15)
add_action("create multi-item removal request proxy", create_multi_item_removal_request_proxy, 1)
add_wait("spiderbot fulfilled multi-item removal proxy", multi_item_removal_request_complete, 60 * 30, 15)
add_action("create later-plan item removal proxy", create_later_item_removal_plan_proxy, 1)
add_wait("spiderbot fulfilled later satisfiable item removal plan", later_item_removal_plan_complete, 60 * 20, 15)
add_section("tile-dependency-work", "tile and dependency ordering work", { prefix = "deploy" })
add_action("create tile ghost", create_tile_ghost, 1)
add_wait("spiderbot built tile ghost", tile_build_complete, 60 * 20, 15)
add_action("create tile deconstruction order", create_tile_deconstruction_order, 1)
add_wait("spiderbot deconstructed tile", tile_deconstruction_complete, 60 * 20, 15)
add_action("create multiple tile ghosts", create_multiple_tile_ghosts, 1)
add_wait("spiderbot built multiple tile ghosts", multiple_tile_ghosts_complete, 60 * 30, 15)
add_action("create assigned tile deconstruction no-space order", create_assigned_tile_deconstruction_no_space_order, 1)
add_wait("mod assigned no-space tile deconstruction", trigger_full_inventory_assigned_tile_deconstruction_noop, 60 * 10, 1)
add_wait("full-inventory assigned tile deconstruction made no change", full_inventory_assigned_tile_deconstruction_noop_complete, 60 * 5, 15)
add_action("create stacked tile ghosts", create_stacked_tile_ghosts, 1)
add_wait("spiderbot built stacked tile ghosts", stacked_tile_ghosts_complete, 60 * 45, 15)
add_action("create tile ghost over tile deconstruction order", create_tile_ghost_on_deconstruction_order, 1)
add_wait("spiderbot deconstructed tile then built tile ghost", tile_ghost_on_deconstruction_order_complete, 60 * 45, 15)
add_action("create entity ghost on landfill ghost", create_entity_ghost_on_landfill_ghost, 1)
add_wait("spiderbot built landfill then entity ghost", entity_ghost_on_landfill_ghost_complete, 60 * 30, 15)
add_action("create entity ghost on tile ghost", create_entity_ghost_on_tile_ghost, 1)
add_wait("spiderbot built entity and tile ghosts", entity_ghost_on_tile_ghost_complete, 60 * 30, 15)
add_action("create entity ghost on deconstruction target", create_entity_ghost_on_deconstruction_target, 1)
add_wait("spiderbot cleared entity then built ghost", entity_ghost_on_deconstruction_target_complete, 60 * 30, 15)
add_action("create entity ghost on tree deconstruction", create_entity_ghost_on_tree_deconstruction, 1)
add_wait("spiderbot cleared tree then built ghost", entity_ghost_on_tree_deconstruction_complete, 60 * 30, 15)
add_action("create entity ghost on cliff deconstruction", create_entity_ghost_on_cliff_deconstruction, 1)
add_wait("spiderbot cleared cliff then built ghost", entity_ghost_on_cliff_deconstruction_complete, 60 * 45, 15)
add_action("create foundation priority tasks", create_foundation_priority_tasks, 1)
add_wait("foundation tile priority completed mixed work", foundation_priority_tasks_complete, 60 * 90, 15)
add_section("redeploy-cliff-research", "redeploy, cliff, and research events", { prefix = "deploy" })
add_action("trigger teleport redeploy", trigger_teleport_redeploy, 1)
add_wait("spiderbot redeployed after teleport", teleport_redeploy_complete, 60 * 10, 15)
add_action("trigger idle far-range redeploy", trigger_idle_far_range_redeploy, 1)
add_wait("idle far-range spiderbot redeployed", idle_far_range_redeploy_complete, 60 * 10, 15)
add_action("trigger stuck jump recovery", trigger_stuck_jump, 15)
add_wait("stuck spiderbot jumped and re-registered", stuck_jump_complete, 60 * 10, 15)
add_action("trigger build collision stuck freeing", trigger_build_collision_free_stuck, 1)
add_wait("build collision freed stuck spiderbot", build_collision_free_stuck_complete, 60 * 10, 15)
add_action("create cliff deconstruction order", create_cliff_deconstruction_order, 1)
add_wait("spiderbot destroyed cliff with explosives", cliff_deconstruction_complete, 60 * 30, 15)
add_action("create quality cliff deconstruction order", create_quality_cliff_deconstruction_order, 1)
add_wait("spiderbot destroyed cliff with quality explosives", quality_cliff_deconstruction_complete, 60 * 30, 15)
add_action("seed cliff reservations for cleanup", seed_cliff_reservations_for_cleanup, 1)
add_wait("expired and invalid cliff reservations cleaned up", cliff_reservations_cleaned_up, 60 * 5, 15)
add_action("recall active spiderbot", recall_spiderbots, 1)
add_wait("active spiderbot returned to inventory", recall_complete, 60 * 10, 15)
add_action("raise follower count research event", raise_follower_count_research, 1)
add_wait("follower count research updated storage", follower_count_research_complete, 60 * 5, 1)
add_action("raise technology effects reset event", raise_technology_effects_reset, 1)
add_wait("technology effects reset recalculated follower count", technology_effects_reset_complete, 60 * 5, 1)
add_action("raise highest follower count reset event", raise_highest_follower_count_reset, 1)
add_wait("highest follower count reset recalculated storage", highest_follower_count_reset_complete, 60 * 5, 1)
add_section("toggle-quality", "shortcut toggle and quality variants", { prefix = "setup" })
add_action("toggle with no spiderbot inventory", toggle_with_no_spiderbot_inventory, 1)
add_wait("empty-inventory toggle changed shortcut without deployment", empty_inventory_toggle_noop_complete, 60 * 5, 1)
add_action("toggle deploy respects follower limit", toggle_deploy_respects_follower_limit, 1)
add_wait("toggle deployed only follower limit", toggle_deploy_limit_complete, 60 * 10, 15)
add_action("recall limited deployment spiderbots", recall_spiderbots, 1)
add_wait("limited deployment spiderbots returned to inventory", recall_complete, 60 * 10, 1)
add_action("toggle deploy limit combines character and vehicle inventory", toggle_deploy_limit_combines_character_and_vehicle, 1)
add_wait("combined character and vehicle deploy limit respected", combined_character_vehicle_deploy_limit_complete, 60 * 10, 15)
add_action("recall combined character and vehicle deployment", recall_spiderbots, 1)
add_wait("combined character and vehicle deployment recalled", combined_character_vehicle_deploy_recalled, 60 * 10, 1)
add_action("clean up combined character and vehicle deployment", cleanup_combined_character_vehicle_deploy_limit, 15)
add_action("toggle deploys mixed quality spiderbots", toggle_deploys_mixed_quality_spiderbots, 1)
add_wait("mixed quality toggle deployed both qualities", mixed_quality_toggle_deploy_complete, 60 * 10, 15)
add_action("recall mixed quality toggle spiderbots", recall_mixed_quality_toggle_spiderbots, 1)
add_wait("mixed quality toggle spiderbots returned", mixed_quality_toggle_recall_complete, 60 * 10, 1)
add_action("use uncommon spiderbot capsule", use_quality_spiderbot_capsule, 1)
add_wait("uncommon capsule deploy registered uncommon spiderbot", quality_deploy_complete, 60 * 10, 15)
add_action("create uncommon entity ghost", create_quality_build_ghost, 1)
add_wait("uncommon spiderbot built uncommon entity ghost", quality_build_ghost_complete, 60 * 20, 15)
add_action("create uncommon upgrade order", create_quality_upgrade_order, 1)
add_wait("uncommon spiderbot upgraded entity", quality_upgrade_complete, 60 * 20, 15)
add_action("create uncommon entity deconstruction order", create_quality_deconstruction_order, 1)
add_wait("uncommon spiderbot deconstructed uncommon entity", quality_deconstruction_complete, 60 * 20, 15)
add_action("create uncommon content deconstruction order", create_quality_contents_deconstruction_order, 1)
add_wait("uncommon spiderbot returned uncommon contents", quality_contents_deconstruction_complete, 60 * 20, 15)
add_action("create uncommon belt-content deconstruction order", create_quality_belt_contents_deconstruction_order, 1)
add_wait("uncommon spiderbot returned uncommon belt contents", quality_belt_contents_deconstruction_complete, 60 * 20, 15)
add_action("create uncommon item request proxy", create_quality_item_request_proxy, 1)
add_wait("uncommon spiderbot fulfilled uncommon item request proxy", quality_item_request_complete, 60 * 20, 15)
add_action("create uncommon item removal proxy", create_quality_item_removal_request_proxy, 1)
add_wait("uncommon spiderbot fulfilled uncommon item removal proxy", quality_item_removal_complete, 60 * 20, 15)
add_action("trigger uncommon teleport redeploy", trigger_quality_teleport_redeploy, 1)
add_wait("uncommon spiderbot redeployed with quality preserved", quality_teleport_redeploy_complete, 60 * 10, 15)
add_action("trigger uncommon stuck jump recovery", trigger_quality_stuck_jump, 15)
add_wait("uncommon stuck spiderbot jumped with quality preserved", quality_stuck_jump_complete, 60 * 10, 15)
add_action("recall uncommon spiderbot", recall_quality_spiderbots, 1)
add_wait("uncommon spiderbot returned to uncommon inventory", quality_recall_complete, 60 * 10, 15)
add_action("toggle deploys all quality spiderbots", toggle_deploys_all_available_quality_spiderbots, 1)
add_wait("all quality toggle deployed every quality", all_quality_toggle_deploy_complete, 60 * 10, 15)
add_action("recall all quality spiderbots", recall_all_available_quality_spiderbots, 1)
add_wait("all quality toggle recalled every quality", all_quality_toggle_recall_complete, 60 * 10, 15)
add_section("search-pathfinding", "search window and pathfinding corridors", { prefix = "setup" })
add_action("deploy search-window spiderbot", deploy_search_window_spiderbot, 1)
add_wait("search-window spiderbot deployed", search_window_spiderbot_deployed, 60 * 10, 15)
add_action("create distant search ghost", create_distant_search_ghost, 1)
add_wait("distant search ghost ignored before move", distant_search_ghost_ignored_before_move, 60 * 5, 1)
add_action("move player near distant search ghost", move_player_near_distant_search_ghost, 1)
add_wait("distant search ghost built after move", distant_search_ghost_built_after_move, 60 * 20, 15)
add_action("create distant non-entity search tasks", create_distant_non_entity_search_tasks, 1)
add_wait("distant non-entity tasks ignored before move", distant_non_entity_search_tasks_ignored_before_move, 60 * 5, 1)
add_action("move player near distant non-entity search tasks", move_player_near_distant_non_entity_search_tasks, 1)
add_wait("distant non-entity tasks completed after move", distant_non_entity_search_tasks_completed_after_move, 60 * 90, 15)
add_action("create obstacle-corridor build ghost", create_obstacle_corridor_build_ghost, 1)
add_wait("spiderbot built ghost through obstacle corridor", obstacle_corridor_build_complete, 60 * 30, 15)
add_action("create gate-corridor build ghost", create_gate_corridor_build_ghost, 1)
add_wait("spiderbot built ghost through gate corridor", gate_corridor_build_complete, 60 * 30, 15)
add_section("inventory-sources", "vehicle, spider-vehicle, and cargo-wagon inventories", { prefix = "setup" })
add_action("deploy spiderbot from vehicle inventory", deploy_from_vehicle_inventory, 1)
add_wait("vehicle inventory deployed spiderbot", vehicle_inventory_deploy_complete, 60 * 10, 15)
add_action("create vehicle inventory entity ghost", create_vehicle_inventory_build_ghost, 1)
add_wait("vehicle inventory supplied ghost build", vehicle_inventory_build_complete, 60 * 20, 15)
add_action("create vehicle inventory deconstruction order", create_vehicle_inventory_deconstruction_order, 1)
add_wait("vehicle inventory received deconstruction returns", vehicle_inventory_deconstruction_returned_to_trunk, 60 * 20, 15)
add_action("recall vehicle inventory spiderbot", recall_vehicle_inventory_spiderbot, 1)
add_wait("vehicle recall preferred character inventory", vehicle_recall_prefers_character_inventory, 60 * 10, 1)
add_action("deploy vehicle recall fallback spiderbot", deploy_vehicle_recall_fallback_spiderbot, 1)
add_wait("vehicle recall fallback spiderbot deployed", vehicle_recall_fallback_spiderbot_deployed, 60 * 10, 15)
add_action("recall vehicle fallback with full character inventory", recall_vehicle_fallback_with_full_character, 1)
add_wait("vehicle recall fell back to trunk", vehicle_recall_fell_back_to_trunk, 60 * 10, 1)
add_action("clean up vehicle recall fallback", cleanup_vehicle_recall_fallback, 15)
add_action("clean up vehicle inventory test", cleanup_vehicle_inventory_test, 15)
add_action("deploy spiderbot for spider-vehicle inventory test", deploy_spider_vehicle_inventory_spiderbot, 1)
add_wait("spider-vehicle inventory spiderbot deployed", spider_vehicle_inventory_spiderbot_deployed, 60 * 10, 15)
add_action("enter spider-vehicle and create inventory ghost", enter_spider_vehicle_and_create_inventory_ghost, 1)
add_wait("spider-vehicle inventory supplied ghost build", spider_vehicle_inventory_build_complete, 60 * 20, 15)
add_action("clean up spider-vehicle inventory test", cleanup_spider_vehicle_inventory_test, 15)
add_action("deploy spiderbot for cargo-wagon inventory test", deploy_cargo_wagon_inventory_spiderbot, 1)
add_wait("cargo-wagon inventory spiderbot deployed", cargo_wagon_inventory_spiderbot_deployed, 60 * 10, 15)
add_action("enter cargo-wagon and create inventory ghost", enter_cargo_wagon_and_create_inventory_ghost, 1)
add_wait("cargo-wagon inventory supplied ghost build", cargo_wagon_inventory_build_complete, 60 * 20, 15)
add_action("clean up cargo-wagon inventory test", cleanup_cargo_wagon_inventory_test, 15)
add_section("refund-contention", "refund paths and task contention", { prefix = "setup" })
add_action("use capsule over follower limit", use_capsule_over_follower_limit, 1)
add_wait("capsule over follower limit was refunded", follower_limit_capsule_refunded, 60 * 5, 1)
add_action("clear refunded capsule cursor", clear_refunded_capsule_cursor, 15)
add_action("use capsule with no landing position", use_capsule_with_no_landing_position, 1)
add_wait("capsule with no landing position was refunded", no_landing_capsule_refunded, 60 * 5, 1)
add_action("clean up no landing position", cleanup_no_landing_position, 15)
add_action("trigger quality refund with conflicting cursor", trigger_quality_refund_with_conflicting_cursor, 1)
add_wait("quality refund restored quality to conflicting cursor", quality_refund_with_conflicting_cursor_restored_quality_to_cursor, 60 * 5, 15)
add_action("deploy spiderbot for full-inventory recall", deploy_no_space_recall_spiderbot, 1)
add_wait("full-inventory recall spiderbot deployed", no_space_recall_spiderbot_deployed, 60 * 10, 15)
add_action("recall with full character inventory", recall_with_full_character_inventory, 1)
add_wait("full-inventory recall spilled spiderbot", full_inventory_recall_spilled, 60 * 10, 1)
add_action("clean up full-inventory recall", cleanup_full_inventory_recall, 15)
add_action("trigger toggle spam with in-flight projectile", trigger_toggle_spam_with_in_flight_projectile, 1)
add_wait("toggle spam settled to one spiderbot", toggle_spam_spiderbot_settled, 60 * 30, 15)
add_action("recall toggle-spam spiderbot", recall_toggle_spam_spiderbot, 1)
add_wait("toggle-spam spiderbot recalled", toggle_spam_spiderbot_recalled, 60 * 10, 15)
add_action("deploy multiple spiderbots", deploy_multiple_spiderbots, 1)
add_wait("multiple spiderbots deployed", multiple_spiderbots_deployed, 60 * 10, 15)
add_action("create single upgrade for duplicate suppression", create_single_upgrade_for_duplicate_suppression, 1)
add_wait("single upgrade target assigned once", single_upgrade_duplicate_suppression_complete, 60 * 20, 15)
add_action("create single tile deconstruction for duplicate suppression", create_single_tile_deconstruction_for_duplicate_suppression, 1)
add_wait("single tile deconstruction target assigned once", single_tile_deconstruction_duplicate_suppression_complete, 60 * 20, 15)
add_action("create multiple simultaneous build ghosts", create_multiple_build_ghosts, 1)
add_wait("multiple simultaneous ghosts built once", multiple_build_ghosts_complete, 60 * 20, 15)
add_action("create mixed simultaneous tasks", create_mixed_simultaneous_tasks, 1)
add_wait("mixed simultaneous tasks all completed", mixed_simultaneous_tasks_complete, 60 * 45, 15)
add_action("recall multiple spiderbots", recall_multiple_spiderbots, 1)
add_wait("multiple spiderbots recalled", multiple_spiderbots_recalled, 60 * 10, 15)
add_action("deploy max-dispatch spiderbots", deploy_max_dispatch_spiderbots, 1)
add_wait("max-dispatch spiderbots deployed", max_dispatch_spiderbots_deployed, 60 * 10, 15)
add_action("create max-dispatch build ghosts", create_max_dispatch_build_ghosts, 1)
add_wait("max-dispatch cap respected and ghosts built", max_dispatch_builds_complete, 60 * 45, 15)
add_action("recall max-dispatch spiderbots", recall_multiple_spiderbots, 1)
add_wait("max-dispatch spiderbots recalled", multiple_spiderbots_recalled, 60 * 10, 15)
add_section("remote-view", "remote-view work and restore", { prefix = "setup" })
add_action("enter remote view and deploy spiderbot", enter_remote_view_and_deploy_spiderbot, 1)
add_wait("remote-view spiderbot deployed", remote_view_spiderbot_deployed, 60 * 10, 15)
add_action("create remote-view build ghost", create_remote_view_build_ghost, 1)
add_wait("remote-view spiderbot built ghost", remote_view_build_complete, 60 * 20, 15)
add_action("create remote-view upgrade order", create_remote_view_upgrade_order, 1)
add_wait("remote-view spiderbot upgraded entity", remote_view_upgrade_complete, 60 * 20, 15)
add_action("create remote-view deconstruction order", create_remote_view_deconstruction_order, 1)
add_wait("remote-view spiderbot deconstructed entity", remote_view_deconstruction_complete, 60 * 20, 15)
add_action("create remote-view item request proxy", create_remote_view_item_request_proxy, 1)
add_wait("remote-view spiderbot fulfilled item request", remote_view_item_request_complete, 60 * 20, 15)
add_action("create remote-view tile ghost", create_remote_view_tile_ghost, 1)
add_wait("remote-view spiderbot built tile ghost", remote_view_tile_build_complete, 60 * 20, 15)
add_action("create remote-view tile deconstruction order", create_remote_view_tile_deconstruction_order, 1)
add_wait("remote-view spiderbot deconstructed tile", remote_view_tile_deconstruction_complete, 60 * 20, 15)
add_action("recall remote-view spiderbot", recall_remote_view_spiderbot, 1)
add_wait("remote-view spiderbot recalled", remote_view_spiderbot_recalled, 60 * 10, 1)
add_action("restore character controller after remote view", restore_character_controller_after_remote_view, 1)
add_wait("character controller restored after remote view", character_controller_restored, 60 * 5, 15)
add_section("projectile-registration", "projectile registration and ownership cleanup", { prefix = "setup" })
add_action("trigger source-known projectile registration", trigger_source_known_projectile_registration, 1)
add_wait("source-known projectile registered and cleaned up", source_known_projectile_registered, 60 * 5, 15)
add_action("trigger cross-surface projectile registration", trigger_cross_surface_projectile_registration, 1)
add_wait("cross-surface projectile registered and relinked", cross_surface_projectile_registered_and_relinked, 60 * 5, 15)
add_action("trigger source-known projectile owner isolation", trigger_source_known_projectile_owner_isolation, 1)
add_wait("source-known projectile cleaned only source owner", source_known_projectile_owner_isolated, 60 * 5, 15)
add_action("trigger custom-label registration", trigger_custom_label_registration, 1)
add_wait("custom-label registration preserved label", custom_label_registration_preserved, 60 * 5, 15)
add_action("trigger default-label registration", trigger_default_label_registration, 1)
add_wait("default-label registration assigned label", default_label_registration_assigned, 60 * 5, 15)
add_action("trigger source-missing projectile registration", trigger_source_missing_projectile_registration, 1)
add_wait("source-missing projectile registered by stored owner", source_missing_projectile_registered, 60 * 5, 15)
add_action("trigger source-missing projectile stale-owner cleanup", trigger_source_missing_projectile_stale_owner_cleanup, 1)
add_wait("source-missing projectile skipped stale owner", source_missing_projectile_stale_owner_cleaned_up, 60 * 5, 15)
add_action("trigger expired projectile cleanup", trigger_expired_projectile_cleanup, 1)
add_wait("expired projectile record cleaned up", expired_projectile_cleaned_up, 60 * 5, 15)
add_section("force-ignore", "force isolation and ignored work", { prefix = "deploy" })
add_action("create neutral-force tasks", create_neutral_force_tasks, 1)
add_wait("neutral-force tasks completed", neutral_force_tasks_complete, 60 * 30, 15)
add_action("create friendly-force ghost to ignore", create_friendly_force_ghost_to_ignore, 1)
add_wait("friendly-force ghost was ignored", friendly_force_ghost_was_ignored, 60 * 5, 15)
add_action("create friendly-force deconstruction to ignore", create_friendly_force_deconstruction_to_ignore, 1)
add_wait("friendly-force deconstruction was ignored", friendly_force_deconstruction_was_ignored, 60 * 5, 15)
add_action("create friendly-force tile ghost to ignore", create_friendly_force_tile_ghost_to_ignore, 1)
add_wait("friendly-force tile ghost was ignored", friendly_force_tile_ghost_was_ignored, 60 * 5, 15)
add_action("create friendly-force upgrade to ignore", create_friendly_force_upgrade_to_ignore, 1)
add_wait("friendly-force upgrade was ignored", friendly_force_upgrade_was_ignored, 60 * 5, 15)
add_action("create friendly-force item request to ignore", create_friendly_force_item_request_to_ignore, 1)
add_wait("friendly-force item request was ignored", friendly_force_item_request_was_ignored, 60 * 5, 15)
add_action("create friendly-force tile deconstruction to ignore", create_friendly_force_tile_deconstruction_to_ignore, 1)
add_wait("friendly-force tile deconstruction was ignored", friendly_force_tile_deconstruction_was_ignored, 60 * 5, 15)
add_action("create fish deconstruction to ignore", create_fish_deconstruction_to_ignore, 1)
add_wait("fish deconstruction was ignored", fish_deconstruction_was_ignored, 60 * 5, 15)
add_action("create other-force ghost to ignore", create_other_force_ghost_to_ignore, 1)
add_wait("other-force ghost was ignored", other_force_ghost_was_ignored, 60 * 5, 15)
add_action("create other-force deconstruction to ignore", create_other_force_deconstruction_to_ignore, 1)
add_wait("other-force deconstruction was ignored", other_force_deconstruction_was_ignored, 60 * 5, 15)
add_action("create other-force upgrade to ignore", create_other_force_upgrade_to_ignore, 1)
add_wait("other-force upgrade was ignored", other_force_upgrade_was_ignored, 60 * 5, 15)
add_action("create other-force item request to ignore", create_other_force_item_request_to_ignore, 1)
add_wait("other-force item request was ignored", other_force_item_request_was_ignored, 60 * 5, 15)
add_action("create other-force tile ghost to ignore", create_other_force_tile_ghost_to_ignore, 1)
add_wait("other-force tile ghost was ignored", other_force_tile_ghost_was_ignored, 60 * 5, 15)
add_action("create other-force tile deconstruction to ignore", create_other_force_tile_deconstruction_to_ignore, 1)
add_wait("other-force tile deconstruction was ignored", other_force_tile_deconstruction_was_ignored, 60 * 5, 15)
add_action("create unbuildable ghosts to ignore", create_unbuildable_ghosts_to_ignore, 1)
add_wait("unbuildable ghosts were ignored", unbuildable_ghosts_were_ignored, 60 * 5, 15)
add_action("create terrain-invalid entity ghost", create_terrain_invalid_entity_ghost, 1)
add_wait("terrain-invalid ghost preserved inventory", terrain_invalid_entity_ghost_preserved_inventory, 60 * 20, 15)
add_action("create missing upgrade item to ignore", create_missing_upgrade_item_to_ignore, 1)
add_wait("missing upgrade item was ignored", missing_upgrade_item_was_ignored, 60 * 5, 15)
add_action("supply missing upgrade item", supply_missing_upgrade_item, 1)
add_wait("previously ignored upgrade completed after supply", missing_upgrade_item_completed_after_supply, 60 * 20, 15)
add_action("create full-inventory deconstruction to ignore", create_full_inventory_deconstruction_to_ignore, 1)
add_wait("full-inventory deconstruction was ignored", full_inventory_deconstruction_was_ignored, 60 * 5, 1)
add_action("free inventory for deconstruction", free_inventory_for_deconstruction, 1)
add_wait("previously ignored deconstruction completed after space", full_inventory_deconstruction_completed_after_space, 60 * 20, 1)
add_action("clean up full-inventory deconstruction ignore", cleanup_full_inventory_deconstruction_ignore, 15)
add_action("create quality-content space-gated deconstruction", create_quality_content_space_deconstruction_to_ignore, 1)
add_wait("quality-content deconstruction was ignored without quality space", quality_content_space_deconstruction_was_ignored, 60 * 5, 1)
add_action("free inventory for quality-content deconstruction", free_inventory_for_quality_content_space, 1)
add_wait("quality-content deconstruction completed after quality space", quality_content_space_deconstruction_completed_after_space, 60 * 20, 1)
add_action("clean up quality-content deconstruction", cleanup_quality_content_space_deconstruction, 15)
add_action("create full-inventory tile deconstruction to ignore", create_full_inventory_tile_deconstruction_to_ignore, 1)
add_wait("full-inventory tile deconstruction was ignored", full_inventory_tile_deconstruction_was_ignored, 60 * 5, 1)
add_action("free inventory for tile deconstruction", free_inventory_for_tile_deconstruction, 1)
add_wait("previously ignored tile deconstruction completed after space", full_inventory_tile_deconstruction_completed_after_space, 60 * 20, 1)
add_action("clean up full-inventory tile deconstruction ignore", cleanup_full_inventory_tile_deconstruction_ignore, 15)
add_action("create missing item request to ignore", create_missing_item_request_to_ignore, 1)
add_wait("missing item request was ignored", missing_item_request_was_ignored, 60 * 5, 15)
add_action("supply missing item request item", supply_missing_item_request_item, 1)
add_wait("previously ignored item request completed after supply", missing_item_request_completed_after_supply, 60 * 20, 15)
add_action("create upgrading-target request to ignore", create_upgrading_target_request_to_ignore, 1)
add_wait("upgrading-target request was ignored", upgrading_target_request_was_ignored, 60 * 5, 15)
add_action("create empty item request proxy to ignore", create_empty_item_request_proxy_to_ignore, 1)
add_wait("empty item request proxy was ignored", empty_item_request_proxy_was_ignored, 60 * 5, 15)
add_action("create destroyed-target item request proxy to ignore", create_destroyed_target_item_request_proxy_to_ignore, 1)
add_wait("destroyed-target item request proxy was ignored", destroyed_target_item_request_proxy_was_ignored, 60 * 5, 15)
add_action("create damaged repair target to ignore", create_damaged_repair_target_to_ignore, 1)
add_wait("damaged repair target was ignored", damaged_repair_target_was_ignored, 60 * 5, 15)
add_action("create full-inventory removal request to ignore", create_full_inventory_removal_request_to_ignore, 1)
add_wait("full-inventory removal request was ignored", full_inventory_removal_request_was_ignored, 60 * 5, 1)
add_action("free inventory for removal request", free_inventory_for_removal_request, 1)
add_wait("previously ignored removal request completed after space", full_inventory_removal_completed_after_space, 60 * 20, 1)
add_action("clean up full-inventory removal request ignore", cleanup_full_inventory_removal_request_ignore, 15)
add_action("create assigned item-removal no-space request", create_assigned_item_removal_no_space_request, 1)
add_wait("mod assigned no-space item-removal request", trigger_assigned_item_removal_no_space_reset, 60 * 10, 1)
add_wait("assigned item-removal no-space reset spiderbot to idle", assigned_item_removal_no_space_reset_complete, 60 * 5, 15)
add_action("create vehicle-relink assigned task", create_vehicle_relink_assigned_task, 1)
add_wait("mod assigned vehicle-relink task", enter_vehicle_during_assigned_task, 60 * 10, 1)
add_wait("active-task follow target relinked after completion", active_task_follow_target_relinked_after_completion, 60 * 20, 15)
add_section("path-reset", "path responses and command resets", { prefix = "deploy" })
add_action("trigger unknown path response no-op", trigger_unknown_path_response_noop, 1)
add_wait("unknown path response left spiderbot unchanged", unknown_path_response_nooped, 60 * 5, 15)
add_action("trigger no-path request reset", trigger_no_path_request_reset, 1)
add_wait("no-path request reset spiderbot to idle", no_path_request_reset_complete, 60 * 5, 15)
add_action("trigger cleared-task path request reset", trigger_cleared_task_path_request_reset, 1)
add_wait("cleared-task path request reset spiderbot to idle", cleared_task_path_request_reset_complete, 60 * 5, 15)
add_action("trigger stale path response wrong status", trigger_stale_path_response_wrong_status, 1)
add_wait("stale path response wrong status no-oped", stale_path_response_wrong_status_nooped, 60 * 5, 15)
add_action("trigger empty path response completion", trigger_empty_path_response_completion, 1)
add_wait("empty path response completed task", empty_path_response_completed_task, 60 * 5, 15)
add_action("trigger disabled path request reset", trigger_disabled_path_request_reset, 1)
add_wait("disabled path request reset spiderbot to idle", disabled_path_request_reset_complete, 60 * 5, 15)
add_action("trigger surface-mismatch path request reset", trigger_surface_mismatch_path_request_reset, 1)
add_wait("surface-mismatch path request reset spiderbot to idle", surface_mismatch_path_request_reset_complete, 60 * 5, 15)
add_action("trigger invalid-target path request reset", trigger_invalid_target_path_request_reset, 1)
add_wait("invalid-target path request reset spiderbot to idle", invalid_target_path_request_reset_complete, 60 * 5, 15)
add_action("trigger distant-target path request reset", trigger_distant_target_path_request_reset, 1)
add_wait("distant-target path request reset spiderbot to idle", distant_target_path_request_reset_complete, 60 * 5, 15)
add_action("trigger far assigned-task command reset", trigger_far_assigned_task_command_reset, 1)
add_wait("far assigned-task command reset spiderbot to idle", far_assigned_task_command_reset_complete, 60 * 5, 15)
add_action("create destroyed target command-reset task", create_destroyed_target_command_reset_task, 1)
add_wait("mod assigned destroyed-target task", trigger_destroyed_target_command_reset, 60 * 10, 1)
add_wait("destroyed target command reset spiderbot to idle", destroyed_target_command_reset_complete, 60 * 5, 15)
add_action("create destroyed tile ghost command-reset task", create_destroyed_tile_ghost_command_reset_task, 1)
add_wait("mod assigned destroyed tile ghost task", trigger_destroyed_tile_ghost_command_reset, 60 * 10, 1)
add_wait("destroyed tile ghost reset spiderbot to idle", destroyed_tile_ghost_command_reset_complete, 60 * 5, 15)
add_action("create destroyed item request command-reset task", create_destroyed_item_request_command_reset_task, 1)
add_wait("mod assigned destroyed item request task", trigger_destroyed_item_request_command_reset, 60 * 10, 1)
add_wait("destroyed item request reset spiderbot to idle", destroyed_item_request_command_reset_complete, 60 * 5, 15)
add_action("create destroyed cliff target retarget task", create_destroyed_cliff_target_retarget_task, 1)
add_wait("mod assigned destroyed cliff target", trigger_destroyed_cliff_target_retarget, 60 * 10, 1)
add_wait("destroyed cliff target retargeted to nearby cliff", destroyed_cliff_target_retarget_complete, 60 * 30, 15)
add_action("create missing cliff explosives command-reset task", create_missing_cliff_explosives_command_task, 1)
add_wait("mod assigned missing cliff explosives task", trigger_missing_cliff_explosives_command_reset, 60 * 10, 1)
add_wait("missing cliff explosives command reset spiderbot to idle", missing_cliff_explosives_command_reset_complete, 60 * 5, 15)
add_action("create missing entity item command-reset task", create_missing_entity_item_command_task, 1)
add_wait("mod assigned missing entity item task", trigger_missing_entity_item_command_reset, 60 * 10, 1)
add_wait("missing entity item command reset spiderbot to idle", missing_entity_item_command_reset_complete, 60 * 5, 15)
add_action("create missing upgrade item command-reset task", create_missing_upgrade_item_command_task, 1)
add_wait("mod assigned missing upgrade item task", trigger_missing_upgrade_item_command_reset, 60 * 10, 1)
add_wait("missing upgrade item command reset spiderbot to idle", missing_upgrade_item_command_reset_complete, 60 * 5, 15)
add_action("create missing tile item command-reset task", create_missing_tile_item_command_task, 1)
add_wait("mod assigned missing tile item task", trigger_missing_tile_item_command_reset, 60 * 10, 1)
add_wait("missing tile item command reset spiderbot to idle", missing_tile_item_command_reset_complete, 60 * 5, 15)
add_action("create failed entity revive inventory-preservation task", create_failed_entity_revive_preservation_task, 1)
add_wait("mod assigned failed entity revive task", trigger_failed_entity_revive_preserves_inventory, 60 * 10, 1)
add_wait("failed entity revive preserved inventory", failed_entity_revive_preserved_inventory, 60 * 5, 15)
add_action("create failed tile revive inventory-preservation task", create_failed_tile_revive_preservation_task, 1)
add_wait("mod assigned failed tile revive task", trigger_failed_tile_revive_preserves_inventory, 60 * 10, 1)
add_wait("failed tile revive preserved inventory", failed_tile_revive_preserved_inventory, 60 * 5, 15)
add_action("create cancelled deconstruction command-reset task", create_cancelled_deconstruction_command_task, 1)
add_wait("mod assigned cancelled deconstruction task", trigger_cancelled_deconstruction_command_reset, 60 * 10, 1)
add_wait("cancelled deconstruction reset spiderbot to idle", cancelled_deconstruction_command_reset_complete, 60 * 5, 15)
add_action("create cancelled upgrade command-reset task", create_cancelled_upgrade_command_task, 1)
add_wait("mod assigned cancelled upgrade task", trigger_cancelled_upgrade_command_reset, 60 * 10, 1)
add_wait("cancelled upgrade reset spiderbot to idle", cancelled_upgrade_command_reset_complete, 60 * 5, 15)
add_action("create cancelled tile deconstruction command-reset task", create_cancelled_tile_deconstruction_command_task, 1)
add_wait("mod assigned cancelled tile deconstruction task", trigger_cancelled_tile_deconstruction_command_reset, 60 * 10, 1)
add_wait("cancelled tile deconstruction reset spiderbot to idle", cancelled_tile_deconstruction_command_reset_complete, 60 * 5, 15)
add_action("create cleared item request command-reset task", create_cleared_item_request_command_task, 1)
add_wait("mod assigned cleared item request task", trigger_cleared_item_request_command_reset, 60 * 10, 1)
add_wait("cleared item request reset spiderbot to idle", cleared_item_request_command_reset_complete, 60 * 5, 15)
add_action("create changed insert request task", create_changed_insert_request_command_task, 1)
add_wait("mod assigned changed insert request task", trigger_changed_insert_request_command_reset, 60 * 10, 1)
add_wait("changed insert request fulfilled modified proxy", changed_insert_request_command_reset_complete, 60 * 5, 15)
add_action("create changed removal request task", create_changed_removal_request_command_task, 1)
add_wait("mod assigned changed removal request task", trigger_changed_removal_request_command_reset, 60 * 10, 1)
add_wait("changed removal request fulfilled modified proxy", changed_removal_request_command_reset_complete, 60 * 5, 15)
add_action("trigger repair task command reset", trigger_repair_task_command_reset, 1)
add_wait("repair task reset spiderbot to idle", repair_task_command_reset_complete, 60 * 5, 15)
add_action("create missing-player-entity command-reset task", create_missing_player_entity_command_task, 1)
add_wait("mod assigned missing-player-entity task", trigger_missing_player_entity_command_reset, 60 * 10, 1)
add_wait("missing-player-entity reset spiderbot to idle", missing_player_entity_command_reset_complete, 60 * 5, 15)
add_section("event-storage", "event no-ops and storage cleanup", { prefix = "deploy" })
add_action("trigger wrong-event no-ops", trigger_wrong_event_noops, 1)
add_wait("wrong-event no-ops left spiderbot unchanged", wrong_event_noops_complete, 60 * 5, 15)
add_action("trigger invalid-player event no-ops", trigger_invalid_player_event_noops, 1)
add_wait("invalid-player event no-ops left spiderbot unchanged", invalid_player_event_noops_complete, 60 * 5, 15)
add_action("seed offline-player storage", seed_offline_player_storage_ignored, 1)
add_wait("offline-player storage was ignored", offline_player_storage_was_ignored, 60 * 5, 15)
add_action("trigger stale-player assigned task cleanup", trigger_stale_player_assigned_task_cleanup, 1)
add_wait("stale-player assigned task was cleaned up", stale_player_assigned_task_cleaned_up, 60 * 5, 15)
add_action("trigger connected-player shared task isolation if available", trigger_connected_player_shared_task_isolation, 1)
add_wait("connected-player shared task isolated or skipped", connected_player_shared_task_isolated_or_skipped, 60 * 30, 15)
add_section("active-task-recall", "active-task recall and requeue", { prefix = "deploy" })
add_action("create active-task toggle recall ghost", create_active_task_toggle_recall_ghost, 1)
add_wait("mod assigned active-toggle task", trigger_active_task_toggle_recall, 60 * 10, 1)
add_wait("active-task toggle recalled spiderbot", active_task_toggle_recall_complete, 60 * 10, 15)
add_action("trigger invalid-spiderbot path request cleanup", trigger_invalid_spiderbot_path_request_cleanup, 1)
add_wait("invalid-spiderbot path request cleaned up", invalid_spiderbot_path_request_cleaned_up, 60 * 5, 15)
add_action("create assigned-spiderbot destroy requeue task", create_assigned_spiderbot_destroy_requeue_task, 1)
add_wait("mod assigned destroy-requeue task", trigger_assigned_spiderbot_destroy_requeues_task, 60 * 10, 1)
add_wait("assigned-spiderbot destroy requeued task", assigned_spiderbot_destroy_requeued_task, 60 * 20, 15)
add_section("surface-controller", "surface, controller, and relink behavior", { prefix = "setup" })
add_action("deploy transition spiderbot", deploy_transition_spiderbot, 1)
add_wait("transition spiderbot deployed", transition_spiderbot_deployed, 60 * 10, 15)
add_action("trigger changed-surface redeploy", trigger_changed_surface_redeploy, 1)
add_wait("changed-surface redeploy completed", changed_surface_redeploy_complete, 60 * 10, 15)
add_action("create active-task surface-change ghost", create_active_task_surface_change_ghost, 1)
add_wait("mod assigned active surface-change task", trigger_active_task_changed_surface_redeploy, 60 * 10, 1)
add_wait("active-task changed-surface redeployed idle", active_task_changed_surface_redeploy_complete, 60 * 10, 15)
add_action("trigger changed-position redeploy", trigger_changed_position_redeploy, 1)
add_wait("changed-position redeploy completed", changed_position_redeploy_complete, 60 * 10, 15)
add_action("trigger small position-change no redeploy", trigger_small_position_change_no_redeploy, 1)
add_wait("small position-change kept existing spiderbot", small_position_change_no_redeploy_complete, 60 * 5, 15)
add_action("trigger factory-travel surface exception if available", trigger_factory_travel_surface_exception, 1)
add_wait("factory-travel surface exception ignored redeploy if available", factory_travel_surface_exception_complete, 60 * 5, 15)
add_action("redeploy transition spiderbot for disallowed-controller tests", deploy_transition_spiderbot, 1)
add_wait("transition spiderbot redeployed for disallowed-controller tests", transition_spiderbot_deployed, 60 * 10, 15)
add_action("trigger disallowed-controller surface change", trigger_disallowed_controller_surface_change, 1)
add_wait("disallowed-controller surface change was ignored", disallowed_controller_surface_change_ignored, 60 * 5, 1)
add_action("restore character controller after disallowed-controller test", restore_character_controller_after_disallowed_controller, 1)
add_wait("character controller restored after disallowed-controller test", disallowed_controller_character_restored, 60 * 5, 15)
add_action("trigger disallowed-controller work ignore", trigger_disallowed_controller_work_ignore, 1)
add_wait("disallowed-controller work was ignored", disallowed_controller_work_was_ignored, 60 * 5, 15)
add_action("restore character controller after disallowed-controller work test", restore_character_controller_after_disallowed_work, 1)
add_wait("character controller restored after disallowed-controller work test", disallowed_work_character_restored, 60 * 5, 15)
add_action("trigger disallowed-controller matrix ignore", trigger_disallowed_controller_matrix_ignore, 1)
add_wait("disallowed-controller matrix was ignored", disallowed_controller_matrix_was_ignored, 60 * 20, 15)
add_action("trigger disallowed-controller toggle recall", trigger_disallowed_controller_toggle_recall, 1)
add_wait("disallowed-controller toggle did not recall", disallowed_controller_toggle_did_not_recall, 60 * 5, 1)
add_action("restore character after disallowed-controller toggle", restore_character_after_disallowed_toggle, 1)
add_wait("disallowed-controller toggle recalled after restore", disallowed_controller_toggle_recalled_after_restore, 60 * 10, 15)
add_action("redeploy transition spiderbot after disallowed-controller toggle", deploy_transition_spiderbot, 1)
add_wait("transition spiderbot redeployed after disallowed-controller toggle", transition_spiderbot_deployed, 60 * 10, 15)
add_action("trigger cutscene-controller work ignore", trigger_cutscene_controller_work_ignore, 1)
add_wait("cutscene-controller work was ignored", cutscene_controller_work_was_ignored, 60 * 5, 1)
add_action("restore character after cutscene-controller work test", restore_character_after_cutscene_work, 1)
add_wait("cutscene-controller ghost built after restore", cutscene_work_built_after_restore, 60 * 20, 15)
add_action("trigger controller-changed relink", trigger_controller_changed_relink, 1)
add_wait("controller-changed relink completed", controller_changed_relink_complete, 60 * 5, 15)
add_action("trigger character replacement relink", trigger_character_replacement_relink, 1)
add_wait("replacement character became spiderbot follow target", character_replacement_relinked, 60 * 5, 1)
add_action("restore original character after replacement relink", restore_original_character_after_replacement, 1)
add_wait("original character restored after replacement relink", original_character_restored_after_replacement, 60 * 5, 15)
add_action("trigger surface-mismatch relink reset", trigger_surface_mismatch_relink_reset, 1)
add_wait("surface-mismatch relink reset spiderbot", surface_mismatch_relink_reset_complete, 60 * 5, 15)
add_action("trigger invalid assigned-target relink reset", trigger_invalid_assigned_target_relink_reset, 1)
add_wait("invalid assigned-target relink reset spiderbot", invalid_assigned_target_relink_reset_complete, 60 * 5, 15)
add_action("trigger previous-entity relink", trigger_previous_entity_relink, 1)
add_wait("previous-entity relink completed", previous_entity_relink_complete, 60 * 5, 15)
add_section("custom-input-cleanup", "custom input, manual mining, and external cleanup", { prefix = "deploy" })
add_action("trigger custom input toggle recall", trigger_custom_input_toggle_recall, 1)
add_wait("custom input toggle recalled spiderbot", custom_input_toggle_recall_complete, 60 * 10, 15)
add_action("trigger custom input toggle deploy", trigger_custom_input_toggle_deploy, 1)
add_wait("custom input toggle deployed spiderbot", custom_input_toggle_deploy_complete, 60 * 10, 15)
add_action("trigger custom input toggle recall after deploy", trigger_custom_input_toggle_recall, 1)
add_wait("custom input toggle recalled deployed spiderbot", custom_input_toggle_recall_complete, 60 * 10, 15)
add_action("deploy transition spiderbot for manual mining", deploy_transition_spiderbot, 1)
add_wait("transition spiderbot redeployed for manual mining", transition_spiderbot_deployed, 60 * 10, 15)
add_action("mine tracked spiderbot manually", mine_tracked_spiderbot_manually, 1)
add_wait("manually mined spiderbot removed from storage", manually_mined_spiderbot_removed, 60 * 5, 15)
add_action("deploy transition spiderbot for external destroy", deploy_transition_spiderbot, 1)
add_wait("transition spiderbot redeployed for external destroy", transition_spiderbot_deployed, 60 * 10, 15)
add_action("destroy tracked spiderbot externally", destroy_tracked_spiderbot_externally, 1)
add_wait("externally destroyed spiderbot removed from storage", externally_destroyed_spiderbot_removed, 60 * 5, 1)

close_section()

function on_test_tick(event)
    local run = storage.spiderbots_test
    if not run or run.status ~= "running" then return end
    observe_tasks(run)
    if event.tick < (run.due_tick or 0) then return end
    local step = steps[run.step_index]
    if not step then
        finish(run)
        return
    end
    if step.type == "action" then
        local ok, err = pcall(step.fn, run)
        if not ok then
            fail(run, step.name .. ": " .. tostring(err))
            return
        end
        pass_step(run, step)
        return
    end
    if step.type == "wait" then
        run.wait_started_tick = run.wait_started_tick or event.tick
        local ok, result = pcall(step.predicate, run)
        if not ok then
            fail(run, step.name .. ": " .. tostring(result))
            return
        end
        if result then
            pass_step(run, step)
            return
        end
        if event.tick - run.wait_started_tick > step.timeout then
            fail(run, step.name .. " timed out")
        end
    end
end

function start(player_index, step_index, prepare, stop_after_step)
    local index = player_index or (game.player and game.player.index) or 1
    local start_step = tonumber(step_index) or 1
    start_step = math.floor(start_step)
    if not steps[start_step] then
        error("invalid spiderbots test step " .. tostring(step_index))
    end
    local stop_step = tonumber(stop_after_step)
    if stop_step then
        stop_step = math.floor(stop_step)
        if stop_step < start_step or not steps[stop_step] then
            error("invalid spiderbots test stop step " .. tostring(stop_after_step))
        end
    end
    storage.spiderbots_test = {
        status = "running",
        player_index = index,
        started_tick = game.tick,
        due_tick = game.tick + 1,
        step_index = start_step,
        stop_after_step = stop_step,
        context = {},
    }
    if prepare then
        local ok, err = pcall(setup_run, storage.spiderbots_test)
        if not ok then
            fail(storage.spiderbots_test, "prepare focused run: " .. tostring(err))
            return
        end
    end
    if start_step == 1 then
        print_to_player(storage.spiderbots_test, "starting " .. #steps .. "-step smoke run")
    elseif stop_step then
        print_to_player(storage.spiderbots_test, "starting steps " .. start_step .. "-" .. stop_step .. "/" .. #steps .. ": " .. steps[start_step].name)
    else
        print_to_player(storage.spiderbots_test, "starting at step " .. start_step .. "/" .. #steps .. ": " .. steps[start_step].name)
    end
end

function status()
    return storage.spiderbots_test or { status = "not-started" }
end

function start_at(player_index, step_index)
    start(player_index, step_index, true)
end

function start_range(player_index, start_step, stop_step)
    start(player_index, start_step, true, stop_step)
end

script.on_event(defines.events.on_tick, on_test_tick)

if remote.interfaces["spiderbots_tests"] and remote.remove_interface then
    remote.remove_interface("spiderbots_tests")
end

remote.add_interface("spiderbots_tests", {
    start = start,
    start_at = start_at,
    start_range = start_range,
    start_section = start_section,
    status = status,
    sections = list_sections,
    capabilities = function() return capabilities end,
})

if game and game.player then
    start(game.player.index)
end
