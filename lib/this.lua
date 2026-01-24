----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------
local const = require('lib.constants')

---@class ExtendedCombinatorModInstance
---@field other_mods table<string, string>
---@field combinators ExtendedCombinator[]
---@field gui FilterCombinatorGui?
This = {
    other_mods = {
        compaktcircuit = 'compaktcircuit',
        PickerDollies = 'PickerDollies',
        ['even-pickier-dollies'] = 'PickerDollies',
    }
}

---@param handlerName string
function This:wrap_handlers(handlerName)
    for _, c in ipairs(self.combinators) do
        local c_handler = c[handlerName]
        c_handler(c)
    end
end

---@param entity LuaEntity
---@return ExtendedCombinator?
function This:get_combinator_from_entity(entity)
    if entity.name == const.filter_combinator_name or entity.name == const.filter_combinator_name_packed then
        return This.fico
    end
    if entity.name == const.spoilage_combinator_name or entity.name == const.filter_combinator_name_packed then
        return This.spco
    end
end

---@param exc_config ExtendedCombinatorConfig
---@return ExtendedCombinator?
function This:get_combinator_from_entity_config(exc_config)
    local c_type = exc_config.combinator_type
    if c_type == extended_combinator_type.filter_combinator then
        return This.fico
    end
    if c_type == extended_combinator_type.spoilage_combinator then
        return This.spco
    end
end


---@param exc_entity ExtendedCombinatorData
---@return ExtendedCombinator?
function This:get_combinator_from_entity_data(exc_entity)
    return This:get_combinator_from_entity_config(exc_entity.config)
end


---@param entity LuaEntity
---@param config ExtendedCombinatorConfig?
function This:create(entity, config)
    local combinator = self:get_combinator_from_entity(entity)
    if not combinator then return end
    return combinator:create(entity, config)
end

---@param entity_id integer
---@return ExtendedCombinatorData?
function This:entity(entity_id)
    return This.exco:entity(entity_id)
end

---@param start_pos MapPosition
---@param entity LuaEntity
function This:move(start_pos, entity)
    local combinator = self:get_combinator_from_entity(entity)
    if not combinator then return end
    combinator:move(start_pos, entity)
end

---@param exc_entity ExtendedCombinatorData
---@param exc_config ExtendedCombinatorConfig?
function This:reconfigure(exc_entity, exc_config)
    local combinator = self:get_combinator_from_entity_data(exc_entity)
    if not combinator then return end
    return combinator:reconfigure(exc_entity, exc_config)
end


if script then
    This.exco = require('scripts.extended-combinator')
    This.fico = require('scripts.filter-combinator')
    This.spco = require('scripts.spoilage.spoilage-combinator')
    This.combinators = { This.fico, This.spco }
    local wrappedHandlerNames = {'on_init', 'on_load'}
    for _, handlerName in ipairs(wrappedHandlerNames) do
        This[handlerName] = This:wrap_handlers(handlerName)
    end
    -- setup remote interface
    require('scripts.remote')
end

return This
