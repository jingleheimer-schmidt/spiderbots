
local tasks_util = require("util/tasks")
local abandon_task = tasks_util.abandon_task

local function toggle_debug()
	global.debug = not global.debug
	for _, player in pairs(game.connected_players) do
		local messaage = global.debug and { "spiderbot-messages.debug-mode-enabled" } or { "spiderbot-messages.debug-mode-disabled" }
		player.print(messaage)
	end
end

local function add_commands()
	commands.add_command("spiderbots-debug",
		"- toggles debug mode for the spiderbots, showing task targets and path request renderings", toggle_debug)
end

return {
	add_commands = add_commands,
}
