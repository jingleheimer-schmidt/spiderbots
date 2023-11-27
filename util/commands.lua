
local tasks_util = require("util/tasks")
local abandon_task = tasks_util.abandon_task
local return_to_inventory = tasks_util.return_to_inventory

local function toggle_debug()
	global.debug = not global.debug
	for _, player in pairs(game.connected_players) do
		local messaage = global.debug and { "spiderbot-messages.debug-mode-enabled" } or { "spiderbot-messages.debug-mode-disabled" }
		player.print(messaage)
	end
end

---@param event EventData.on_console_command | EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_spiderbots(event)
	local name = event.prototype_name or event.input_name or event.command
	if name ~= "toggle-spiderbots" then return end
	local player_index = event.player_index
	if not player_index then return end
	local player = game.get_player(player_index)
	if not player then return end

	global.spiders_enabled[player_index] = not global.spiders_enabled[player_index]
	player.set_shortcut_toggled("toggle-spiderbots", global.spiders_enabled[player_index])
end

---@param event EventData.on_console_command | EventData.on_lua_shortcut | EventData.CustomInputEvent
local function toggle_backpack_mode(event)
	local name = event.prototype_name or event.input_name or event.command
	if name ~= "toggle-backpack-mode" then return end
	local player_index = event.player_index
	if not player_index then return end
	local player = game.get_player(player_index)
	if not player then return end

	global.backpack_mode_enabled[player_index] = not global.backpack_mode_enabled[player_index]
	player.set_shortcut_toggled("toggle-backpack-mode", global.backpack_mode_enabled[player_index])
	local message = global.backpack_mode_enabled[player_index] and { "spiderbot-messages.backpack-mode-enabled" } or { "spiderbot-messages.backpack-mode-disabled" }
	player.print(message)
	if not global.backpack_mode_enabled[player_index] then return end

	-- abandon tasks and return to the player's inventory
	global.spiders[player_index] = global.spiders[player_index] or {}
	for spider_id, spider in pairs(global.spiders[player_index]) do
		if spider.valid then
			abandon_task(spider, player)
		else
			global.spiders[player_index][spider_id] = nil
		end
	end
	for surface_index, available_spiders in pairs(global.available_spiders[player_index]) do
		for spider_index, spider in pairs(available_spiders) do
			if spider.valid then
				local spider_surface_index = spider.surface_index
				local player_surface_index = player.surface_index
				if spider_surface_index == player_surface_index then
					return_to_inventory(spider, player)
					table.remove(available_spiders, spider_index)
				end
			else
				table.remove(available_spiders, spider_index)
			end
		end
	end
end

---@param event EventData.on_lua_shortcut
local function on_lua_shortcut(event)
	if event.prototype_name == "toggle-spiderbots" then
		toggle_spiderbots(event)
	elseif event.prototype_name == "toggle-backpack-mode" then
		toggle_backpack_mode(event)
	end
end

local function add_commands()
	commands.add_command("debug-spiderbots",
		"- toggles debug mode for the spiderbots, showing task targets and path request renderings", toggle_debug)
	commands.add_command("spiderbots-backpack-mode",
		"- toggles backpack mode for the spiderbots, actively recalls all spiderbots to the player's inventory", toggle_backpack_mode)
end

return {
	add_commands = add_commands,
	toggle_spiderbots = toggle_spiderbots,
	toggle_backpack_mode = toggle_backpack_mode,
	on_lua_shortcut = on_lua_shortcut,
}
