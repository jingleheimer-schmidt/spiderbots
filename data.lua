
local sound_probability = 0.125
local sound_volume = 1

local spiderbot_arguments = {
    scale = 0.25,
    leg_scale = 0.82,
    name = "spiderbot",
    leg_thickness = 1.44,
    leg_movement_speed = 2.5,
}
create_spidertron(spiderbot_arguments)
local spiderbot_prototype = data.raw["spider-vehicle"]["spiderbot"]
spiderbot_prototype.guns = nil
spiderbot_prototype.inventory_size = 0
spiderbot_prototype.trash_inventory_size = 0
spiderbot_prototype.equipment_grid = nil
spiderbot_prototype.allow_passengers = false
spiderbot_prototype.is_military_target = false
spiderbot_prototype.torso_rotation_speed = spiderbot_prototype.torso_rotation_speed * 2
spiderbot_prototype.chunk_exploration_radius = 1
spiderbot_prototype.minable.mining_time = spiderbot_prototype.minable.mining_time / 4
spiderbot_prototype.working_sound.probability = 1/4
spiderbot_prototype.minimap_representation.scale = 0.125
local legs = spiderbot_prototype.spider_engine.legs
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
local selection_box = spiderbot_prototype.selection_box
if selection_box then
    selection_box[1][1] = selection_box[1][1] * 2
    selection_box[1][2] = selection_box[1][2] * 2
    selection_box[2][1] = selection_box[2][1] * 2
    selection_box[2][2] = selection_box[2][2] * 2
end
data:extend{spiderbot_prototype}

for i = 1, 8 do
    local leg = data.raw["spider-leg"]["spiderbot-leg-" .. i]
    leg.collision_mask = {"object-layer", "water-tile", "rail-layer", "not-colliding-with-itself" }
end

local spiderbot_recipe = table.deepcopy(data.raw["recipe"]["spidertron"])
spiderbot_recipe.name = "spiderbot"
spiderbot_recipe.ingredients = {
    {"electronic-circuit", 4},
    {"iron-plate", 12},
    {"inserter", 8},
    {"raw-fish", 1},
}
spiderbot_recipe.result = "spiderbot"
spiderbot_recipe.enabled = true
spiderbot_recipe.subgroup = "logistic-network"
spiderbot_recipe.order = "a[robot]-a[little-spiderbot]"
-- spiderbot_recipe.icon_size = spiderbot_recipe.icon_size * 4
data:extend{spiderbot_recipe}

local spiderbot_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
spiderbot_item.name = "spiderbot"
spiderbot_item.place_result = "spiderbot"
spiderbot_recipe.subgroup = "logistic-network"
spiderbot_recipe.order = "a[robot]-a[little-spiderbot]"
-- spiderbot_item.icon_size = spiderbot_item.icon_size * 4
data:extend{spiderbot_item}

local toggle_spiderbots_shortcut = {
    type = "shortcut",
    name = "toggle-spiderbots",
    action = "lua",
    associated_control_input = "toggle-spiderbots",
    -- icon = {filename = "__spiderbots__/assets/targeted.png", size = 1024},
    icon = {filename = "__spiderbots__/assets/icons8-spider-67.png", size = 67},
    -- disabled_icon = {filename = "__spiderbots__/assets/spider-face-trans.png", size = 1024},
    toggleable = true,
}
data:extend({toggle_spiderbots_shortcut})

local toggle_spiderbots_hotkey = {
    type = "custom-input",
    name = "toggle-spiderbots",
    key_sequence = "ALT + S",
    -- alternative_key_sequence = "COMMAND + S",
    action = "lua",
}
data:extend({toggle_spiderbots_hotkey})
