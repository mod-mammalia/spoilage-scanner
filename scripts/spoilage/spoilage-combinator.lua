------------------------------------------------------------------------
-- Filter combinator main code
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')
local ExtendedCombinator = require('scripts.extended-combinator')

---@class SpoilageCombinator : ExtendedCombinator
local SpoilageCombinator = setmetatable({}, { __index = ExtendedCombinator })

SpoilageCombinator.default_config = table.deepcopy(ExtendedCombinator.default_config)
SpoilageCombinator.default_config.combinator_type = extended_combinator_type.spoilage_combinator
SpoilageCombinator.combinator_name = const.spoilage_combinator_name
SpoilageCombinator.packed_combinator_name = const.filter_combinator_name_packed

SpoilageCombinator.sub_entities = {
    { id = 'cache_red', type = 'cc', x = 0,  y = -1, desc = 'Cached spoilage aggregation values for red wire connections.' },
    { id = 'cache_green', type = 'cc', x = 0,  y = 1, desc = 'Cached spoilage aggregation values for green wire connections.' },
}

---@type table<string, ExcWireConfig[]>
SpoilageCombinator.wiring = {
    init = {
        { src = 'cache_red', dst = 'main', dst_circuit = 'output', wire = 'red' },
        { src = 'cache_green', dst = 'main', dst_circuit = 'output', wire = 'green' },
    },
}

---@param fc_entity ExtendedCombinatorData
---@param fc_config ExtendedCombinatorConfig?
function SpoilageCombinator:reconfigure(fc_entity, fc_config)
end

---@param exc_entity ExtendedCombinatorData
---@param exc_config ExtendedCombinatorConfig?
function SpoilageCombinator:aggregate_spoilage(exc_entity, exc_config)
end

return SpoilageCombinator
