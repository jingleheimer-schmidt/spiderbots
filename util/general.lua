
local floor = math.floor

---@param entity LuaEntity
---@return string|integer
local function entity_uuid(entity)
	local unit_number = entity.unit_number
	if unit_number then
		return unit_number
	else
		local uuid = script.register_on_entity_destroyed(entity)
		return uuid
	end
end

---@param tile LuaTile
---@param surface_index integer?
---@param position TilePosition?
---@return string
local function tile_uuid(tile, surface_index, position)
	surface_index = surface_index or tile.surface.index
	position = position or tile.position
	local x = position.x
	local y = position.y
	local uuid = surface_index .. "," .. x .. "," .. y
	return uuid
end

---@param player LuaPlayer
---@return LuaEntity?
local function get_player_entity(player)
	return player.character or player.vehicle or nil
end

---@return string
local function random_backer_name()
	local backer_names = game.backer_names
	local index = math.random(#backer_names)
	return backer_names[index]
end

---@param name string
---@return boolean
local function is_backer_name(name)
	if not global.backer_name_lookup then
		global.backer_name_lookup = {}
		for _, backer_name in pairs(game.backer_names) do
			global.backer_name_lookup[backer_name] = true
		end
	end
	return global.backer_name_lookup[name]
end

return {
	entity_uuid = entity_uuid,
	tile_uuid = tile_uuid,
	get_player_entity = get_player_entity,
	random_backer_name = random_backer_name,
	is_backer_name = is_backer_name,
}
