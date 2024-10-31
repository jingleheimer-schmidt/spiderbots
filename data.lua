
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
spiderbot_prototype.minable.result = "spiderbot"
spiderbot_prototype.placeable_by = { item = "spiderbot", count = 1 }
spiderbot_prototype.guns = nil
spiderbot_prototype.inventory_size = 0
spiderbot_prototype.trash_inventory_size = 0
spiderbot_prototype.equipment_grid = nil
spiderbot_prototype.allow_passengers = false
spiderbot_prototype.is_military_target = false
spiderbot_prototype.torso_rotation_speed = spiderbot_prototype.torso_rotation_speed * 2
spiderbot_prototype.chunk_exploration_radius = 1
spiderbot_prototype.minable.mining_time = spiderbot_prototype.minable.mining_time / 4
spiderbot_prototype.working_sound.probability = 1 / 4
spiderbot_prototype.minimap_representation.scale = 0.125
local lights = spiderbot_prototype.graphics_set.light or {}
for _, light in pairs(lights) do
    light.intensity = light.intensity / 2.5
end
local legs = spiderbot_prototype.spider_engine.legs
if legs[1] then
    for _, leg in pairs(legs) do
        for _, trigger in pairs(leg.leg_hit_the_ground_trigger) do
            trigger.repeat_count = 1
            trigger.probability = 1 / 32
        end
        local leg_name = leg.leg
        local leg_prototype = data.raw["spider-leg"][leg_name]
        leg_prototype.walking_sound_volume_modifier = 0
        leg_prototype.working_sound.probability = sound_probability
    end
else
    for _, trigger in pairs(legs.leg_hit_the_ground_trigger) do
        trigger.repeat_count = 1
        trigger.probability = 1 / 32
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
data:extend { spiderbot_prototype }

for i = 1, 8 do
    local leg = data.raw["spider-leg"]["spiderbot-leg-" .. i]
    leg.collision_mask = {
        layers = {
            -- ground_tile = true,
            water_tile = true,
            -- resource = true,
            -- doodad = true,
            -- floor = true,
            rail = true,
            -- transport_belt = true,
            -- item = true,
            ghost = true,
            -- object = true,
            -- player = true,
            -- car = true,
            -- train = true,
            -- elevated_rail = true,
            -- elevated_train = true,
            empty_space = true,
            lava_tile = true,
            -- meltable = true,
            -- rail_support = true,
            -- trigger_target = true,
            cliff = true,
            -- is_lower_object = true,
            -- is_object = true
        },
        not_colliding_with_itself = true,
        consider_tile_transitions = false,
        colliding_with_tiles_only = false,
    }
    leg.minimal_step_size = leg.minimal_step_size * 4
    -- leg.movement_based_position_selection_distance = leg.movement_based_position_selection_distance * 1.5
end

local spiderbot_recipe = table.deepcopy(data.raw["recipe"]["spidertron"])
spiderbot_recipe.name = "spiderbot"
spiderbot_recipe.ingredients = {
    { type = "item", name = "electronic-circuit", amount = 4 },
    { type = "item", name = "iron-plate", amount = 12 },
    { type = "item", name = "inserter", amount = 8 },
    { type = "item", name = "raw-fish", amount = 1 },
}
spiderbot_recipe.results = {
    { type = "item", name = "spiderbot", amount = 1 }
}
spiderbot_recipe.enabled = true
spiderbot_recipe.subgroup = "logistic-network"
spiderbot_recipe.order = "a[robot]-a[spiderbot]"
data:extend { spiderbot_recipe }

local spidertron_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
local spiderbot_item = {
    type = "capsule",
    name = "spiderbot",
    icon = spidertron_item.icon,
    icon_size = spidertron_item.icon_size,
    stack_size = 25,
    subgroup = "logistic-network",
    order = "a[robot]-a[spiderbot]",
    capsule_action = {
        type = "throw",
        attack_parameters = {
            activation_type = "throw",
            ammo_category = "capsule",
            type = "projectile",
            cooldown = 10,
            projectile_creation_distance = .3,
            range = 50,
            ammo_type = {
                category = "capsule",
                target_type = "position",
                -- 	no action, since control.lua creates the projectile when a player uses the capsule. the ammo type here is just for the tooltip on the item
            }
        }
    }
}
data:extend { spiderbot_item }

local spiderbot_projectile = {
    type = "projectile",
    name = "spiderbot-trigger",
    acceleration = 0.005,
    action = {
        action_delivery = {
            target_effects = {
                {
                    entity_name = "spiderbot",
                    type = "create-entity",
                    show_in_tooltip = true,
                    trigger_created_entity = true
                }
            },
            type = "instant"
        },
        type = "direct"
    },
    animation = data.raw["projectile"]["distractor-capsule"].animation,
    shadow = data.raw["projectile"]["distractor-capsule"].shadow,
    flags = { "not-on-map" },
    enable_drawing_with_mask = true,
}
data:extend { spiderbot_projectile }

local spiderbot_no_trigger_projectile = {
    type = "projectile",
    name = "spiderbot-no-trigger",
    acceleration = 0.005,
    animation = data.raw["projectile"]["distractor-capsule"].animation,
    shadow = data.raw["projectile"]["distractor-capsule"].shadow,
    flags = { "not-on-map" },
    enable_drawing_with_mask = true,
}
data:extend { spiderbot_no_trigger_projectile }

---@type data.ShortcutPrototype
local toggle_spiderbots_shortcut = {
    type = "shortcut",
    name = "toggle-spiderbots",
    action = "lua",
    associated_control_input = "toggle-spiderbots",
    -- icon = {filename = "__spiderbots__/assets/targeted.png", size = 1024},
    icon = "__spiderbots__/assets/icons8-spider-67.png",
    icon_size = 67,
    small_icon = "__spiderbots__/assets/icons8-spider-67.png",
    small_icon_size = 67,
    -- icon = { filename = "__spiderbots__/assets/icons8-spider-67.png", size = 67 },
    -- disabled_icon = {filename = "__spiderbots__/assets/spider-face-trans.png", size = 1024},
    toggleable = true,
}
data:extend({ toggle_spiderbots_shortcut })

local toggle_spiderbots_hotkey = {
    type = "custom-input",
    name = "toggle-spiderbots",
    key_sequence = "ALT + S",
    action = "lua",
}
data:extend({ toggle_spiderbots_hotkey })
