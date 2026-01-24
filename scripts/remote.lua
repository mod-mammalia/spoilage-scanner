------------------------------------------------------------------------
-- Remote API
------------------------------------------------------------------------
assert(script)

local tools = require('framework.tools')

---@param entity_id integer
---@return ExtendedCombinatorConfig? config
local function get_config(entity_id)
    local exc_entity = This:entity(entity_id)
    if not exc_entity then return nil end

    return exc_entity.config
end

---@param entity_id integer
---@param config ExtendedCombinatorConfig
local function set_config(entity_id, config)
    local exc_entity = This:entity(entity_id)
    if not exc_entity then return end

    exc_entity.config = tools.copy(config)
    This:reconfigure(exc_entity)
end

if Framework.remote_api then
    -- use get_config(entity_id) to retrieve configuration
    Framework.remote_api.get_config = get_config
    -- use set_config(entity_id, config) to set config
    Framework.remote_api.set_config = set_config
end
