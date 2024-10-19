
-- -@class entity_task_data
-- -@field entity LuaEntity
-- -@field entity_id uuid
-- -@field spider LuaEntity
-- -@field spider_id uuid
-- -@field task_type string
-- -@field player LuaPlayer
-- -@field status string
-- -@field render_ids table<integer, boolean>
-- -@field path_request_id integer?

---@alias uuid string|integer
---@alias player_index string|integer

---@class path_request_data
---@field spider LuaEntity
---@field spider_id uuid
---@field entity LuaEntity
---@field entity_id uuid
---@field player LuaPlayer

---@class position_path_request_data
---@field spider LuaEntity
---@field spider_id uuid
---@field start_position MapPosition
---@field final_position MapPosition
---@field player LuaPlayer

---@class spiderbot_data
---@field spiderbot LuaEntity
---@field spiderbot_id uuid
---@field player LuaPlayer
---@field player_index player_index
---@field status string
---@field path_request_id integer?

