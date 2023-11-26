
local sound_probability = 0.125
local sound_volume = 1

local little_spider_arguments = {
    scale = 0.25,
    leg_scale = 0.82,
    name = "little-spidertron",
    leg_thickness = 1.44,
    leg_movement_speed = 2.5,
}
create_spidertron(little_spider_arguments)
local little_spider_entity = data.raw["spider-vehicle"]["little-spidertron"]
little_spider_entity.guns = nil
little_spider_entity.inventory_size = 0
little_spider_entity.trash_inventory_size = 0
little_spider_entity.equipment_grid = nil
little_spider_entity.allow_passengers = false
little_spider_entity.is_military_target = false
little_spider_entity.torso_rotation_speed = little_spider_entity.torso_rotation_speed * 2
little_spider_entity.chunk_exploration_radius = 1
little_spider_entity.minable.mining_time = little_spider_entity.minable.mining_time / 4
little_spider_entity.working_sound.probability = 1/4
little_spider_entity.minimap_representation.scale = 0.125
local legs = little_spider_entity.spider_engine.legs
if legs[1] then
    for _, leg in pairs(legs) do
        for _, trigger in pairs(leg.leg_hit_the_ground_trigger) do
            trigger.repeat_count = 1
            trigger.probability = 1/32
        end
        local leg_name = leg.leg
        local leg_prototype = data.raw["spider-leg"][leg_name]
        leg_prototype.walking_sound_volume_modifier = 0
        leg_prototype.working_sound.probability = sound_probability
    end
else
    for _, trigger in pairs(legs.leg_hit_the_ground_trigger) do
        trigger.repeat_count = 1
        trigger.probability = 1/32
    end
    local leg_name = legs.leg
    local leg_prototype = data.raw["spider-leg"][leg_name]
    leg_prototype.walking_sound_volume_modifier = 0
    leg_prototype.working_sound.probability = sound_probability
end
local selection_box = little_spider_entity.selection_box
if selection_box then
    selection_box[1][1] = selection_box[1][1] * 2
    selection_box[1][2] = selection_box[1][2] * 2
    selection_box[2][1] = selection_box[2][1] * 2
    selection_box[2][2] = selection_box[2][2] * 2
end
-- little_spider_entity.collision_box = {{-0.005, -0.005}, {0.005, 0.005}}
-- little_spider_entity.collision_mask = {"object-layer", "water-tile", "rail-layer"}

for i = 1, 8 do
    local leg = data.raw["spider-leg"]["little-spidertron-leg-" .. i]
    leg.collision_mask = {"object-layer", "water-tile", "rail-layer", "not-colliding-with-itself" }
end

local little_spider_recipe = table.deepcopy(data.raw["recipe"]["spidertron"])
little_spider_recipe.name = "little-spidertron"
little_spider_recipe.ingredients = {
    {"electronic-circuit", 4},
    {"iron-plate", 12},
    {"inserter", 8},
    {"raw-fish", 1},
}
little_spider_recipe.result = "little-spidertron"
little_spider_recipe.enabled = true
little_spider_recipe.subgroup = "logistic-network"
little_spider_recipe.order = "a[robot]-a[little-spidertron]"
-- little_spider_recipe.icon_size = little_spider_recipe.icon_size * 4
data:extend{little_spider_recipe}

local little_spider_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
little_spider_item.name = "little-spidertron"
little_spider_item.place_result = "little-spidertron"
little_spider_recipe.subgroup = "logistic-network"
little_spider_recipe.order = "a[robot]-a[little-spidertron]"
-- little_spider_item.icon_size = little_spider_item.icon_size * 4
data:extend{little_spider_item}

local toggle_little_spiders_shortcut = {
    type = "shortcut",
    name = "toggle-little-spiders",
    action = "lua",
    associated_control_input = "toggle-little-spiders",
    -- icon = {filename = "__little-spiders__/assets/targeted.png", size = 1024},
    icon = {filename = "__little-spiders__/assets/icons8-spider-67.png", size = 67},
    -- disabled_icon = {filename = "__little-spiders__/assets/spider-face-trans.png", size = 1024},
    toggleable = true,
}
data:extend({toggle_little_spiders_shortcut})

local toggle_little_spiders_hotkey = {
    type = "custom-input",
    name = "toggle-little-spiders",
    key_sequence = "ALT + S",
    -- alternative_key_sequence = "COMMAND + S",
    action = "lua",
}
data:extend({toggle_little_spiders_hotkey})
