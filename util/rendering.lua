
---@param surface LuaSurface
---@param from LuaEntity|MapPosition
---@param to LuaEntity|MapPosition
---@param color Color
---@param time_to_live integer?
---@return integer?
local function draw_line(surface, from, to, color, time_to_live)
    if not global.debug then return end
    local render_id = rendering.draw_line({
        color = color,
        width = 1.25,
        from = from,
        to = to,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
    })
    return render_id
end

---@param surface LuaSurface
---@param from LuaEntity|MapPosition
---@param to LuaEntity|MapPosition
---@param color Color
---@param time_to_live integer?
---@param dash_offset boolean?
---@return integer?
local function draw_dotted_line(surface, from, to, color, time_to_live, dash_offset)
    if not global.debug then return end
    local render_id = rendering.draw_line({
        color = color,
        width = 2,
        from = from,
        to = to,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
        gap_length = 1,
        dash_length = 1,
        dash_offset = dash_offset and 1 or 0,
    })
    return render_id
end

---@param surface LuaSurface
---@param position MapPosition
---@param color Color
---@param radius number
---@param time_to_live integer?
---@return integer?
local function draw_circle(surface, position, color, radius, time_to_live)
    if not global.debug then return end
    local render_id = rendering.draw_circle({
        color = color,
        radius = radius,
        width = 0.5,
        filled = true,
        target = position,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
    })
    return render_id
end

---@param message string
---@param player LuaPlayer
---@param entity LuaEntity
---@param color Color?
local function debug_print(message, player, entity, color)
    if not global.debug then return end
    -- color = color or {}
    -- color.r = color.r or 1
    -- color.g = color.g or 1
    -- color.b = color.b or 1
    -- color.a = color.a or 1
    -- message = string.format("[color=%d,%d,%d,%d]%s[/color]", color.r, color.g, color.b, color.a, message)
    -- player.create_local_flying_text({
    --     text = message,
    --     position = entity.position,
    --     color = {r = 1, g = 1, b = 1},
    --     time_to_live = 180,
    -- })
end

---@param spider_id uuid
local function destroy_associated_renderings(spider_id)
    if not global.tasks.by_spider[spider_id] then return end
    for render_id, bool in pairs(global.tasks.by_spider[spider_id].render_ids) do
        if bool then
            rendering.destroy(render_id)
        end
    end
end

return {
    draw_line = draw_line,
    draw_dotted_line = draw_dotted_line,
    draw_circle = draw_circle,
    debug_print = debug_print,
    destroy_associated_renderings = destroy_associated_renderings,
}
