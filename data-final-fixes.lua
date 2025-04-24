
local sound_counts = {
    mined_sound = 0,
    inventory_move_sound = 0,
    mining_sound = 0,
    build_sound = 0,
}

local function create_sound(prototype, sound_type)
    if prototype[sound_type][1] then
        local sound = {
            name = prototype.name .. "-" .. sound_type,
            type = "sound",
            variations = prototype[sound_type],
        }
        data:extend { sound }
        sound_counts[sound_type] = sound_counts[sound_type] + 1
    else
        ---@type data.SoundPrototype
        local sound = {
            type = "sound",
            name = prototype.name .. "-" .. sound_type,
            category = prototype[sound_type].category,
            priority = prototype[sound_type].priority,
            aggregation = prototype[sound_type].aggregation,
            allow_random_repeat = prototype[sound_type].allow_random_repeat,
            audible_distance_modifier = prototype[sound_type].audible_distance_modifier,
            game_controller_vibration_data = prototype[sound_type].game_controller_vibration_data,
            advanced_volume_control = prototype[sound_type].advanced_volume_control,
            speed_smoothing_window_size = prototype[sound_type].speed_smoothing_window_size,
            variations = prototype[sound_type].variations,
            filename = prototype[sound_type].filename,
            volume = prototype[sound_type].volume,
            min_volume = prototype[sound_type].min_volume,
            max_volume = prototype[sound_type].max_volume,
            preload = prototype[sound_type].preload,
            speed = prototype[sound_type].speed,
            min_speed = prototype[sound_type].min_speed,
            max_speed = prototype[sound_type].max_speed,
            modifiers = prototype[sound_type].modifiers,
        }
        data:extend { sound }
        sound_counts[sound_type] = sound_counts[sound_type] + 1
    end
end

local function create_prototype_sound(prototype, sound_type)
    if prototype[sound_type] then
        if prototype[sound_type].filename or prototype[sound_type].variations or prototype[sound_type][1] then
            create_sound(prototype, sound_type)
        end
    end
end

for _, prototypes in pairs(data.raw) do
    for _, prototype in pairs(prototypes) do
        for _, sound_type in pairs { "mined_sound", "mining_sound", "inventory_move_sound", "build_sound" } do
            create_prototype_sound(prototype, sound_type)
        end
    end
end

log("added sound prototypes:")
log(serpent.block(sound_counts))

---@param item data.ItemPrototype
---@return data.RotatedAnimation
local function create_animation_from_icon(item)
    if item.icons then
        ---@type data.RotatedAnimation
        local animation = { layers = {} }
        for _, icon in pairs(item.icons) do
            if icon.icon then
                local size = icon.icon_size or 64
                ---@type data.RotatedAnimation
                local layer = {
                    filename = icon.icon,
                    width = size,
                    height = size,
                    direction_count = 1,
                    frame_count = 1,
                    line_length = 1,
                    tint = icon.tint,
                    scale = (icon.scale or (64 / 2 / size)) * 0.6,
                }
                table.insert(animation.layers, layer)
            end
        end
        return animation
    else
        local size = item.icon_size or 64
        return {
            filename = item.icon,
            width = size,
            height = size,
            direction_count = 1,
            frame_count = 1,
            line_length = 1,
            scale = 64 / 2 / size * 0.6,
        }
    end
end

local projectile_items = {
    "item",
    "ammo",
    "capsule",
    "gun",
    "item-with-entity-data",
    "item-with-label",
    "item-with-inventory",
    "blueprint-book",
    "item-with-tags",
    "selection-tool",
    "blueprint",
    "copy-paste-tool",
    "deconstruction-item",
    "spidertron-remote",
    "upgrade-item",
    "module",
    "rail-planner",
    "space-platform-starter-pack",
    "tool",
    "armor",
    "repair-tool",
}

local projectile_counts = {}

for _, item_type in pairs(projectile_items) do
    if not data.raw[item_type] then goto next end
    for _, item in pairs(data.raw[item_type]) do
        ---@type data.ProjectilePrototype
        local projectile = {
            name = item.name .. "-spiderbot-projectile",
            type = "projectile",
            acceleration = 0.001,
            animation = create_animation_from_icon(item),
            turn_speed = 5,
            rotatable = true,
            shadow = table.deepcopy(data.raw["projectile"]["distractor-capsule"].shadow),
            enable_drawing_with_mask = true,
            hidden = true,
            flags = { "not-on-map", "placeable-off-grid" },
        }
        projectile.shadow.scale = 0.4
        projectile.icon = table.deepcopy(item.icon)
        projectile.icon_size = table.deepcopy(item.icon_size)
        projectile.icons = table.deepcopy(item.icons)
        data:extend { projectile }
        projectile_counts[item_type] = (projectile_counts[item_type] or 0) + 1
    end
    ::next::
end

log("added projectile prototypes:")
local projectile_counts_to_print = {}
for _, item_type in pairs(projectile_items) do
    if projectile_counts[item_type] then
        local str = item_type .. ": " .. projectile_counts[item_type] .. " / " .. table_size(data.raw[item_type])
        table.insert(projectile_counts_to_print, str)
    end
end
log(serpent.block(projectile_counts_to_print))

local collision_mask_util = require("collision-mask-util")

for name, entity_ghost in pairs(data.raw["entity-ghost"]) do
    entity_ghost.collision_mask = entity_ghost.collision_mask or collision_mask_util.get_mask(entity_ghost)
    entity_ghost.collision_mask.layers = entity_ghost.collision_mask.layers or {}
    entity_ghost.collision_mask.layers["spiderbot_leg"] = true
end
