
local function spawn_all_projectiles()
    local player = game.player
    if not (player and player.valid) then return end
    local position = player.position
    local x_off = -20
    local y_off = 10
    for name, _ in pairs(prototypes.item) do
        player.surface.create_entity {
            name = name .. "-spiderbot-projectile",
            position = { position.x + x_off, position.y + y_off },
            target = { position.x + x_off, position.y + y_off - 100 },
            force = player.force,
            speed = 0,
            orientation = 0.5
        }
        x_off = x_off + 1
        if x_off > 40 then
            y_off = y_off + 1
            x_off = -10
        end
    end
end
spawn_all_projectiles()
