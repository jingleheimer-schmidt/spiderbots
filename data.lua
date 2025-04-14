
local sound_probability = 0.125
local sound_volume = 1

local spiderbot_arguments = {
    scale = 0.25,
    leg_scale = 0.82,
    name = "spiderbot",
    leg_thickness = 1.44,
    leg_movement_speed = 1.5,
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
spiderbot_prototype.torso_bob_speed = 0.8 -- default 1
spiderbot_prototype.chunk_exploration_radius = 1
spiderbot_prototype.minable.mining_time = spiderbot_prototype.minable.mining_time / 4
spiderbot_prototype.working_sound.probability = 1 / 4
spiderbot_prototype.minimap_representation.scale = 0.125
local lights = spiderbot_prototype.graphics_set.light or {}
for _, light in pairs(lights) do
    light.intensity = light.intensity / 2.5
end

---@type data.CollisionLayerPrototype
local spiderbot_leg_collision_layer = {
    name = "spiderbot_leg",
    type = "collision-layer",
}
data:extend { spiderbot_leg_collision_layer }

---@param spider_leg_specification data.SpiderLegSpecification
local function modify_spider_legs(spider_leg_specification)
    for _, trigger in pairs(spider_leg_specification.leg_hit_the_ground_trigger) do
        trigger.repeat_count = 1
        trigger.probability = 1 / 32
    end
    local leg_name = spider_leg_specification.leg
    local leg_prototype = data.raw["spider-leg"][leg_name]
    leg_prototype.localised_name = { "entity-name.spiderbot-leg" }
    leg_prototype.walking_sound_volume_modifier = 0
    leg_prototype.working_sound.probability = sound_probability
    leg_prototype.collision_mask = {
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
            cliff = true,
            -- is_lower_object = true,
            -- is_object = true
            spiderbot_leg = true,
        },
        not_colliding_with_itself = true,
        consider_tile_transitions = false,
        colliding_with_tiles_only = false,
    }
    leg_prototype.minimal_step_size = leg_prototype.minimal_step_size * 4
    -- leg_prototype.movement_based_position_selection_distance = leg_prototype.movement_based_position_selection_distance * 1.5
end

local legs = spiderbot_prototype.spider_engine.legs
if legs[1] then
    for _, leg in pairs(legs) do
        modify_spider_legs(leg)
    end
else
    modify_spider_legs(legs)
end
local selection_box = spiderbot_prototype.selection_box
if selection_box then
    selection_box[1][1] = selection_box[1][1] * 2
    selection_box[1][2] = selection_box[1][2] * 2
    selection_box[2][1] = selection_box[2][1] * 2
    selection_box[2][2] = selection_box[2][2] * 2
end
data:extend { spiderbot_prototype }

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
spiderbot_recipe.order = "a[robot]-b[spiderbot]"
data:extend { spiderbot_recipe }

local spidertron_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
local spiderbot_item = {
    type = "capsule",
    name = "spiderbot",
    icon = spidertron_item.icon,
    icon_size = spidertron_item.icon_size,
    stack_size = 25,
    subgroup = "logistic-network",
    order = "a[robot]-b[spiderbot]",
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

---@type data.ProjectilePrototype
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
    icon = "__spiderbots__/assets/icons8-spider-67.png",
    icon_size = 67,
    small_icon = "__spiderbots__/assets/icons8-spider-67.png",
    small_icon_size = 67,
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

local function create_spiderbot_follower_technology(level, automation, logistic, military, chemical, production, utility, space)
    local technology = {
        type = "technology",
        name = "spiderbot-follower-count-" .. level,
        icons = util.technology_icon_constant_followers("__base__/graphics/technology/spidertron.png"),
        upgrade = false,
        enabled = true,
        essential = false,
        visible_when_disabled = false,
        allows_productivity = true,
        unit = {
            count = 75,
            time = 30,
            ingredients = {}
        },
        effects = {
            {
                type = "nothing",
                use_icon_overlay_constant = true,
                effect_description = { "bonus-description.maximum-following-spiderbots", "10", tostring((level - 1) * 10 + 10), tostring(level * 10 + 10) },
                icons = {
                    {
                        icon = "__base__/graphics/technology/spidertron.png",
                        icon_size = 256,
                    },
                    {
                        icon = "__core__/graphics/icons/technology/constants/constant-count.png",
                        icon_size = 128,
                        scale = 0.25,
                        shift = { 10, 10 },
                        floating = true
                    }
                },
                hidden = false,
            }
        }
    }
    technology.prerequisites = {}
    if level > 1 then
        technology.prerequisites = { "spiderbot-follower-count-" .. (level - 1) }
    end
    if automation then
        table.insert(technology.unit.ingredients, { "automation-science-pack", 1 })
        table.insert(technology.prerequisites, "automation-science-pack")
    end
    if logistic then
        table.insert(technology.unit.ingredients, { "logistic-science-pack", 1 })
        table.insert(technology.prerequisites, "logistic-science-pack")
    end
    if chemical then
        table.insert(technology.unit.ingredients, { "chemical-science-pack", 1 })
        table.insert(technology.prerequisites, "chemical-science-pack")
    end
    if military then
        table.insert(technology.unit.ingredients, { "military-science-pack", 1 })
        table.insert(technology.prerequisites, "military-science-pack")
    end
    if utility then
        table.insert(technology.unit.ingredients, { "utility-science-pack", 1 })
        table.insert(technology.prerequisites, "utility-science-pack")
    end
    if production then
        table.insert(technology.unit.ingredients, { "production-science-pack", 1 })
        table.insert(technology.prerequisites, "production-science-pack")
    end
    if space then
        table.insert(technology.unit.ingredients, { "space-science-pack", 1 })
        table.insert(technology.prerequisites, "space-science-pack")
    end
    data:extend({ technology })
end

create_spiderbot_follower_technology(1, true, false, false, false, false, false, false)
create_spiderbot_follower_technology(2, true, true, false, false, false, false, false)
create_spiderbot_follower_technology(3, true, true, true, false, false, false, false)
create_spiderbot_follower_technology(4, true, true, true, true, false, false, false)
create_spiderbot_follower_technology(5, true, true, true, true, true, false, false)
create_spiderbot_follower_technology(6, true, true, true, true, true, true, false)

---@type data.TechnologyPrototype
local spiderbot_follower_count_technology = {
    type = "technology",
    name = "spiderbot-follower-count-7",
    icons = util.technology_icon_constant_followers("__base__/graphics/technology/spidertron.png"),
    upgrade = true,
    enabled = true,
    essential = false,
    visible_when_disabled = false,
    allows_productivity = true,
    unit = {
        count_formula = "75 * (L - 6)",
        time = 30,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "military-science-pack", 1 },
            { "utility-science-pack", 1 },
            { "production-science-pack", 1 },
            { "space-science-pack", 1 },
        }
    },
    max_level = "infinite",
    show_levels_info = true,
    effects = {
        {
            type = "nothing",
            use_icon_overlay_constant = true,
            effect_description = { "bonus-description.maximum-following-spiderbots-7", "5" },
            icons = {
                {
                    icon = "__base__/graphics/technology/spidertron.png",
                    icon_size = 256,
                },
                {
                    icon = "__core__/graphics/icons/technology/constants/constant-count.png",
                    icon_size = 128,
                    scale = 0.25,
                    shift = { 10, 10 },
                    floating = true
                }
            },
            hidden = false,
        }
    },
    prerequisites = { "spiderbot-follower-count-6", "space-science-pack" },
}
data:extend({ spiderbot_follower_count_technology })
