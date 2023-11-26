
local tasks_util = require("util/tasks")
local abandon_task = tasks_util.abandon_task

local function toggle_debug()
	global.debug = not global.debug
	for _, player in pairs(game.connected_players) do
		local messaage = global.debug and { "spiderbot-messages.debug-mode-enabled" } or { "spiderbot-messages.debug-mode-disabled" }
		player.print(messaage)
	end
end

---@param event EventData.on_console_command
local function recall_spiderbots(event)
	local player_index = event.player_index
	if not player_index then return end
	local player = game.get_player(player_index)
	if not player then return end

	-- abandon all tasks
	global.spiders[player_index] = global.spiders[player_index] or {}
	for spider_id, spider in pairs(global.spiders[player_index]) do
		if spider.valid then
			abandon_task(spider, player)
		else
			global.spiders[player_index][spider_id] = nil
		end
	end
end

local function add_commands()
	commands.add_command("spiderbots-debug",
		"- toggles debug mode for the spiderbots, showing task targets and path request renderings", toggle_debug)
	commands.add_command("spiderbots-recall",
		"- recalls all spiderbots to the player's inventory", recall_spiderbots)
end

return {
	add_commands = add_commands,
}
