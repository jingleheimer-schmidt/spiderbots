
local max_task_range = 45
local half_max_task_range = max_task_range / 2
local double_max_task_range = max_task_range * 2
---@type table<defines.controllers, boolean>
local allowed_controllers = {
    [defines.controllers.character] = true,
    [defines.controllers.cutscene] = false,
    [defines.controllers.editor] = false,
    [defines.controllers.ghost] = false,
    [defines.controllers.god] = false,
    [defines.controllers.remote] = true,
    [defines.controllers.spectator] = false,
}

return {
    max_task_range = max_task_range,
    half_max_task_range = half_max_task_range,
    double_max_task_range = double_max_task_range,
    allowed_controllers = allowed_controllers,
}
