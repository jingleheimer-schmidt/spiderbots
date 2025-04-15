
local counts = {
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
        counts[sound_type] = counts[sound_type] + 1
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
        counts[sound_type] = counts[sound_type] + 1
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
log(serpent.block(counts))

---@param item data.ItemPrototype
---@return string[]
local function get_item_icon_filenames(item)
    local filenames = {}
    if item.icons then
        for _, icon in pairs(item.icons) do
            if icon.icon then
                table.insert(filenames, icon.icon)
            end
        end
    elseif item.icon then
        table.insert(filenames, item.icon)
    end
    return filenames
end

---@param item data.ItemPrototype
---@return integer
local function get_item_icon_size(item)
    local size = 32
    if item.icons then
        for _, icon in pairs(item.icons) do
            if icon.icon_size then
                size = icon.icon_size
            end
        end
    elseif item.icon_size then
        size = item.icon_size
    end
    return size or 32
end

local projectile_items = {
    "item",
    "module",
    "tool",
    "armor",
    "capsule",
    "ammo",
}

for _, item_type in pairs(projectile_items) do
    for _, item in pairs(data.raw[item_type]) do
        ---@type data.ProjectilePrototype
        local projectile = {
            name = item.name .. "-spiderbot-projectile",
            type = "projectile",
            acceleration = 0.001,
            animation = {
                direction_count = 1,
                filenames = get_item_icon_filenames(item),
                lines_per_file = 1,
                line_length = 1,
                frame_count = 1,
                size = get_item_icon_size(item),
            },
            turn_speed = 5,
            rotatable = true,
            shadow = data.raw["projectile"]["distractor-capsule"].shadow,
            enable_drawing_with_mask = true,
            hidden = true,
        }
        projectile.animation.scale = 0.4
        projectile.shadow.scale = 0.4
        data:extend { projectile }
    end
end
