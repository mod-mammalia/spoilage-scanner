---@class ContainerNetwork
---@field origin LuaWireConnector
---@field wire_type defines.wire_type
---@field network_id integer
---@field wire_id defines.wire_connector_id
---@field entities table<integer, LuaEntity>
---@field containers LuaEntity[]
local ContainerNetwork = {}

ContainerNetwork.io_wire_ids = {
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
}

ContainerNetwork.input_wire_ids = {
    defines.wire_connector_id.combinator_input_red,
    defines.wire_connector_id.combinator_input_green
}

ContainerNetwork.wire_types = {
    [defines.wire_connector_id.combinator_input_red] = defines.wire_type.red,
    [defines.wire_connector_id.combinator_input_green] = defines.wire_type.green,
    [defines.wire_connector_id.circuit_red] = defines.wire_type.red,
    [defines.wire_connector_id.circuit_green] = defines.wire_type.green,
}

ContainerNetwork.container_inventories = {
    ["container"] = {defines.inventory.chest},
    ["logistic-container"] = {defines.inventory.chest},
    ["infinity-container"] = {defines.inventory.chest},
    ["assembling-machine"] = {defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.fuel},
    ["furnace"] = {defines.inventory.furnace_source, defines.inventory.furnace_result},
    ["lab"] = {defines.inventory.lab_input},
    ["reactor"] = {defines.inventory.fuel, defines.inventory.burnt_result},
    ["boiler"] = {defines.inventory.fuel, defines.inventory.burnt_result},
    ["rocket-silo"] = {defines.inventory.rocket_silo_rocket},
    ["space-platform-hub"] = {defines.inventory.hub_main},
    ["cargo-landing-pad"] = {defines.inventory.cargo_landing_pad_main},
    ["agricultural-tower"] = {defines.inventory.assembling_machine_output},
}

ContainerNetwork.container_types = {}
for t, _ in pairs(ContainerNetwork.container_inventories) do
    table.insert(ContainerNetwork.container_types, t)
end

---@param network ContainerNetwork
local function filter_containers(network)
    for _, entity in pairs(network.entities) do
        if ContainerNetwork.container_inventories[entity.type] ~= nil then
            table.insert(network.containers, entity)
        end
    end
end



---@param network ContainerNetwork
---@param connector LuaWireConnector
local function trace_network(network, connector)
    for _, connection in ipairs(connector.real_connections) do
        local next_node = connection.target
        local next_entity = next_node.owner
        if not network.entities[next_entity.unit_number] then
            network.entities[next_entity.unit_number] = next_entity
            trace_network(network, next_node)
        end
    end
end


---@param connector LuaWireConnector
---@return ContainerNetwork
function ContainerNetwork.create(connector)
    local network = {
        origin = connector,
        wire_type = connector.wire_type,
        wire_id = connector.wire_connector_id,
        network_id = connector.network_id,
        entities = {
            [connector.owner.unit_number] = connector.owner
        },
        containers = {}
    }
    trace_network(network, connector)
    filter_containers(network)
    return network
end

---@param combinator LuaEntity
---@return ContainerNetwork[]
function ContainerNetwork.create_from_combinator(combinator)
    local networks = {}
    for _, wire_id in ipairs(ContainerNetwork.io_wire_ids) do
        local connector = combinator.get_wire_connector(wire_id, false)
        if connector then
            local network = ContainerNetwork.create(connector)
            if #network.containers > 1 then
                table.insert(networks, network)
            end
        end
    end
    return networks
end

return ContainerNetwork