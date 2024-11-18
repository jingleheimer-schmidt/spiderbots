
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

local function create_build_sound(entity)
    if entity.build_sound then
        if entity.build_sound.filename or entity.build_sound.variations or entity.build_sound[1] then
            create_sound(entity, "build_sound")
        end
    end
end

local function create_mining_sound(entity)
    if entity.mining_sound then
        if entity.mining_sound.filename or entity.mining_sound.variations or entity.mining_sound[1] then
            create_sound(entity, "mining_sound")
        end
    end
end

local function create_mined_sound(entity)
    if entity.mined_sound then
        if entity.mined_sound.filename or entity.mined_sound.variations or entity.mined_sound[1] then
            create_sound(entity, "mined_sound")
        end
    end
end

---@param item data.ItemPrototype
local function create_inventory_move_sound(item)
    if item.inventory_move_sound then
        if item.inventory_move_sound.filename or item.inventory_move_sound.variations or item.inventory_move_sound[1] then
            create_sound(item, "inventory_move_sound")
        end
    end
end

for type_name, prototypes in pairs(data.raw) do
    for prototype_name, prototype in pairs(prototypes) do
        create_inventory_move_sound(prototype)
        create_mined_sound(prototype)
        create_mining_sound(prototype)
        create_build_sound(prototype)
    end
end

log("added sound prototypes:")
log(serpent.block(counts))
