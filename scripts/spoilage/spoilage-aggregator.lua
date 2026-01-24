local table = require('stdlib.utils.table')
local Common = require 'common'
local ContainerNetwork = require 'scripts.spoilage.container-network'

--- TODO:
--- This class will encapsulate the spoilage aggregation functions as well
--- as interaction with the combinator filters.

---@class SpoilageAggregator
local SpoilageAggregator = {}

---@param t1 table<any,any>
---@param t2 table<any,any> | LuaInventory | nil
local function table_concat(t1, t2)
    if not t2 then return end
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
end

---@param exc_entity SpoilageCombinatorData
---@return table<defines.wire_type, LuaItemStack[]>
function SpoilageAggregator.load_inventories(exc_entity)
    local inventories = {}
    for wire_type, wire_containers in pairs(exc_entity.containers) do
        ---@type table<any,any>
        local wire_inventory = {}
        for _, container in ipairs(wire_containers) do
            local inventory_types = ContainerNetwork.container_inventories[container.type]
            if inventory_types then
                for _, inv_type in ipairs(inventory_types) do
                    local inv = container.get_inventory(inv_type)
                    -- table_concat(wire_inventory, inv) # this works, does array_combine?
                    table.array_combine(wire_inventory, inv)
                end
            end
        end
        inventories[wire_type] = wire_inventory
    end

    return inventories
end

SpoilageAggregator.default_aggregation_values = {
    [aggregation_mode.mean] = 0,
    [aggregation_mode.min] = 0,
    [aggregation_mode.max] = 100,
}

---@param inventory LuaItemStack[]
---@param mode aggregation_mode
---@return SpoilageSignals
function SpoilageAggregator.compute_wire_signals(inventory, mode)
    local signals = {}
    local counts = {}
    for i=1, #inventory do
        local itemStack = inventory[i]
        if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
            local item_name = itemStack.name
            signals[item_name] = signals[item_name] or SpoilageAggregator.default_aggregation_values[mode]
            if mode == aggregation_mode.mean then
                signals[item_name] = signals[item_name] + itemStack.spoil_percent * itemStack.count
                counts[item_name] = (counts[item_name] or 0) + itemStack.count
            elseif mode == aggregation_mode.min then
                if signals[item_name] < itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
            elseif mode == aggregation_mode.max then
                if signals[item_name] > itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
            end
        end
    end

    for k,v in pairs(signals) do
        if mode == aggregation_mode.mean then
            v = v / counts[k]
        end
        signals[k] = math.ceil(100 * (1 - v))
    end
    return signals 
end

---@param inventories table<defines.wire_type, LuaItemStack[]>
---@param mode aggregation_mode
---@return WiredSpoilageSignals
function SpoilageAggregator.compute_signals(inventories, mode)
    local signals = {}
    for wire_type, wire_inventory in pairs(inventories) do
        signals[wire_type] = SpoilageAggregator.compute_wire_signals(wire_inventory, mode)
    end
    return signals
end

---@param containers table<defines.wire_type, LuaEntity[]>
function SpoilageAggregator.filter_valid_containers(containers)
    if not containers then
        containers = {}
    end
    for wire_type, wire_sources in pairs(containers) do
        local valid_sources = {}
        for _, source in ipairs(wire_sources) do
            if source.valid then
                table.insert(valid_sources, source)
            end
        end
        containers[wire_type] = valid_sources
    end
    return containers
end

---@param exc_entity SpoilageCombinatorData
function SpoilageAggregator.load_spoilage_networks(exc_entity)
    local networks = ContainerNetwork.create_from_combinator(exc_entity.main)
    exc_entity.containers = {}
    for _, network in ipairs(networks) do
        exc_entity.containers[network.wire_type] = network.containers
    end
end

---@param exc_entity SpoilageCombinatorData
---@return WiredSpoilageSignals
function SpoilageAggregator.read_spoilage_networks(exc_entity)
    exc_entity.containers = SpoilageAggregator.filter_valid_containers(exc_entity.containers)
    if #exc_entity.containers == 0 then
        return {}
    end
    local inventories = SpoilageAggregator.load_inventories(exc_entity.containers)
    local signals = SpoilageAggregator.compute_signals(inventories, exc_entity.config.aggregation_mode)
    return signals
end

--- TODO: example of how you convert a name-value map to actual logistic filters for the combinators
---@param signals table<string, integer>
---@return LogisticFilter[]
local function create_filters(signals)
    ---@type LogisticFilter[]
    local filters = {}
    for k, v in pairs(signals) do
        local filter = {
            value = { name = k, type="item", quality="normal"},
            min = v
        }
    end
    return filters
end


return SpoilageAggregator