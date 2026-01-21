require '_defs'

local ID_CIRCUITS = { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }

local CONTAINER_INVENTORIES = {
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

local CONTAINER_TYPES = {}
for t, _ in pairs(CONTAINER_INVENTORIES) do
    table.insert(CONTAINER_TYPES, t)
end

local flib_gui = require "__flib__.gui"

-- NOTE: ghost of destroyed entities have different unit_number than the original entity 
--   but accessible with ghost_unit_number
--   could also just reset data on destruction?
--   uses of spoilage scanner is liable for destruction so it would be best for it to be recoverable
--   could also just don't delete data but that might cause issues

-- TODO: Dynamically update gui to match target
-- NOTE: current migration script might be an issue with multiplayer

---@param t1 table<any,any>
---@param t2 table<any,any> | LuaInventory | nil
local function table_concat(t1, t2)
    if not t2 then
        return
    end
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
end

---@param arr string[]
---@param value string
---@return boolean
local function table_contains(arr, value)
  for _, v in ipairs(arr) do
    if v == value then
      return true
    end
  end
  return false
end

i = 0
local function print_console(msg)
    i = i + 1
    local prefix = '[' .. string.format("%05d", i) .. '] '
    game.print(prefix .. msg)
end


---@param source LuaEntity
---@param network_id integer
---@param entities? table<integer, LuaEntity>
---@return table<integer, LuaEntity>
local function recurse_connected_entities(source, network_id, entities)
    if not entities then
        entities = {}
    end
    for _, id in ipairs(ID_CIRCUITS) do
        local connector = source.get_wire_connector(id, false)
        if connector.network_id == 0 then
            goto continue
        end
        local required_network_id = network_id
        if network_id == 0 then
            required_network_id = connector.network_id
        end
        if connector.network_id == required_network_id then
            for _, connection in ipairs(connector.real_connections) do
                local c_entity = connection.target.owner
                if not entities[c_entity.unit_number] then
                    entities[c_entity.unit_number] = c_entity
                    recurse_connected_entities(c_entity, required_network_id, entities)
                end
            end
        end
        ::continue::
    end
    return entities
end

---@param source LuaEntity
---@return LuaEntity[]
local function get_connected_containers(source)
    
    local entities = recurse_connected_entities(source, 0)
    local containers = {}
    for _, entity in pairs(entities) do
        if table_contains(CONTAINER_TYPES, entity.type) then
            table.insert(containers, entity)
        end
    end
    return containers
end

---@param entity_data EntityData
local function update_target(entity_data)
    local combinator = entity_data.combinator
    if not combinator.valid then return end
    local target_pos = combinator.position

    if combinator.direction == defines.direction.north then
        target_pos.y = target_pos.y - 1
    elseif combinator.direction == defines.direction.east then
        target_pos.x = target_pos.x + 1
    elseif combinator.direction == defines.direction.south then
        target_pos.y = target_pos.y + 1
    elseif combinator.direction == defines.direction.west then
        target_pos.x = target_pos.x - 1
    end

    local entities = get_connected_containers(entity_data.combinator)
    if #entities == 0 then
        entities = combinator.surface.find_entities_filtered({
            position = target_pos, 
            type = CONTAINER_TYPES
        })
    end
    
    if #entities > 0 then
        entity_data.target = entities[1]
    else
        entity_data.target = nil
    end
end

---@param entity_data EntityData
local function update_signals(entity_data)
    if not (entity_data and entity_data.combinator and entity_data.combinator.valid) then return end
    if not entity_data.target then
        -- TODO: set entity light to red (or green when there's a target)
        local control_behavior = entity_data.combinator.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        if control_behavior.sections_count == 0 then control_behavior.add_section() end
        control_behavior.get_section(1).filters = {}
        return
    elseif not entity_data.target.valid then
        entity_data.target = nil
        return
    end

    local entity_type = entity_data.target.type
    local inv = {}
    local inventory_types = CONTAINER_INVENTORIES[entity_type]
    if inventory_types then
        for _, inv_type in ipairs(inventory_types) do
            table_concat(inv, entity_data.target.get_inventory(inv_type))
        end
    end

    -- calculate freshness
    local signals = {}
    if entity_data.mode == aggregation_mode.mean then
        local counts = {}
        for i=1, #inv do
            local itemStack = inv[i]
            if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                local item_name = itemStack.name
                if not signals[item_name] then
                    signals[item_name] = 0
                    counts[item_name] = 0
                end
                signals[item_name] = signals[item_name] + itemStack.spoil_percent * itemStack.count
                counts[item_name] = counts[item_name] + itemStack.count
            end
        end
        for k,v in pairs(signals) do
            signals[k] = math.ceil(100 - v / counts[k] * 100)
        end
    elseif entity_data.mode == aggregation_mode.min then
        for i=1, #inv do
            local itemStack = inv[i]
            if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                local item_name = itemStack.name
                if not signals[item_name] then signals[item_name] = 0 end
                if signals[item_name] < itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
            end
        end
        for k,v in pairs(signals) do
            signals[k] = math.ceil(100 - v * 100)
        end
    elseif entity_data.mode == aggregation_mode.max then
        for i=1, #inv do
            local itemStack = inv[i]
            if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                local item_name = itemStack.name
                if not signals[item_name] then signals[item_name] = 100 end
                if signals[item_name] > itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
            end
        end
        for k,v in pairs(signals) do
            signals[k] = math.ceil(100 - v * 100)
        end
    end

    -- set signals
    local control_behavior = entity_data.combinator.get_control_behavior()
    if control_behavior.sections_count == 0 then control_behavior.add_section() end
    local section = control_behavior.get_section(1)
    section.filters = {}
    local i = 1
    for k,v in pairs(signals)
    do
        section.set_slot(i, {value = {type="item", name=k, quality="normal"}, min=v})
        i = i + 1
    end
end

local function on_tick (event)
    local tickupdate = event.tick % settings.global["spoilage-sensor-signal-update-interval"].value
    local tickscan = event.tick % settings.global["spoilage-sensor-signal-scan-interval"].value
    for k,v in pairs(storage.entity_data) do
        if tickupdate == ( k % settings.global["spoilage-sensor-signal-update-interval"].value ) then
            update_signals(v)
        end
    end

    for k,v in pairs(storage.entity_data) do
        if tickscan == ( k % settings.global["spoilage-sensor-signal-scan-interval"].value + 1 ) then
            update_target(v)
        end
    end
end

local function on_entity_created(event)
    local entity = event.entity
    if storage.entity_data[entity.unit_number] then return end
    local entity_data = {combinator=entity, target=nil, mode=aggregation_mode.mean}
    storage.entity_data[entity.unit_number] = entity_data
    update_target(entity_data)
end

local function on_entity_removed(event)
    storage.entity_data[event.entity.unit_number] = nil
end

local function on_entity_rotated(event)
    local entity = event.entity
    if not entity.name == "spoilage-scanner" then return end
    if not storage.entity_data[entity.unit_number] then return end
    update_target(storage.entity_data[entity.unit_number])
end


-- GUI CRAP STARTS HERE
local function on_mode_changed(event)
    local elem = event.element
    if not elem then return end

    if elem.name == "ssrb-agg-mean" then
        elem.parent["ssrb-agg-min" ].state = false
        elem.parent["ssrb-agg-max" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = aggregation_mode.mean
    elseif elem.name == "ssrb-agg-min" then
        elem.parent["ssrb-agg-mean" ].state = false
        elem.parent["ssrb-agg-max" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = aggregation_mode.min
    elseif elem.name == "ssrb-agg-max" then
        elem.parent["ssrb-agg-mean" ].state = false
        elem.parent["ssrb-agg-min" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = aggregation_mode.max
    end
end

local function on_gui_opened(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if event.gui_type ~= defines.gui_type.entity then return end
    if not entity or not entity.valid or entity.name ~= "spoilage-scanner" then return end
    if not player then return end
    if player.gui.relative["scanner-gui"] then player.gui.relative["scanner-gui"].destroy() end

    local entity_data = storage.entity_data[entity.unit_number]
    if not entity_data then return end

    update_target(storage.entity_data[entity.unit_number])

    local _, frame = flib_gui.add(player.gui.relative, {
        type = "frame",
        name = "scanner-gui",
        tags = {unit_number = entity.unit_number},
        direction="vertical",
        elem_mods = {
            anchor = {
                gui = defines.relative_gui_type.constant_combinator_gui,
                position = defines.relative_gui_position.right
            }
        },
        children = {
            {
                type = "flow",
                name = "titlebar",
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = { "gui.spoilage-sensor-title" },
                        elem_mods = { ignored_by_interaction = true },
                    },
                    {
                        type = "empty-widget", 
                        style = "flib_titlebar_drag_handle", 
                        elem_mods = { ignored_by_interaction = true } 
                    }
                },
            }
        }
    })

    local target_preview_flow = {
        type = "flow",
        direction = "vertical"
    }
    if entity_data.target then
        target_preview_flow.children = {
            {
                type = "flow",
                style = "flib_titlebar_flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontally_stretchable = true,
                    bottom_padding = 4,
                },
                children = {
                    {
                        type = "sprite",
                        sprite = "utility/status_working",
                        style = "status_image",
                        style_mods = { stretch_image_to_widget_size = true },
                    },
                    {
                        type = "label",
                        caption = {"gui.spoilage-sensor-target"}
                    },
                },
            },
            {
                type = "frame",
                style = "deep_frame_in_shallow_frame",
                style_mods = {
                    minimal_width = 0,
                    horizontally_stretchable = true,
                    padding = 0,
                },
                children = {
                    { 
                        type = "entity-preview", 
                        style = "wide_entity_button",
                        elem_mods = {
                            entity = entity_data.target
                        },
                    },
                },
            }
        }
    else
        target_preview_flow.children = {
            {
                type = "flow",
                style = "flib_titlebar_flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontally_stretchable = true,
                    bottom_padding = 4,
                },
                children = {
                    {
                        type = "sprite",
                        sprite = "utility/status_yellow",
                        style = "status_image",
                        style_mods = { stretch_image_to_widget_size = true },
                    },
                    {
                        type = "label",
                        caption = {"gui.spoilage-sensor-no-target"}
                    },
                },
            }
        }
    end

    local mode_flow = {
        type = "flow",
        direction = "vertical",
        children = {
            {
                type = "label",
                style = "caption_label",
                caption = {"gui-control-behavior.mode-of-operation"}
            },
            {
                name = "ssrb-agg-mean",
                type = "radiobutton",
                state = entity_data.mode==aggregation_mode.mean,
                caption = { "gui.spoilage-sensor-agg-mean" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            },
            {
                name = "ssrb-agg-min",
                type = "radiobutton",
                state = entity_data.mode==aggregation_mode.min,
                caption = { "gui.spoilage-sensor-agg-min" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            },
            {
                name = "ssrb-agg-max",
                type = "radiobutton",
                state = entity_data.mode==aggregation_mode.max,
                caption = { "gui.spoilage-sensor-agg-max" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            }
        }
    }

    local content_frame = {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding_and_vertical_spacing",
        style_mods = {minimal_width = 250},
        children = {target_preview_flow, { type = "line", style_mods = { top_padding = 4 } }, mode_flow}
    }
    flib_gui.add(frame, content_frame)
end

local function on_gui_closed(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if event.gui_type ~= defines.gui_type.entity then return end
    if not entity or not entity.valid or entity.name ~= "spoilage-scanner" then return end
    if not player then return end
    if player.gui.relative["scanner-gui"] then player.gui.relative["scanner-gui"].destroy() end
end


flib_gui.add_handlers({["scanner-gui-mode_select"] = on_mode_changed})
flib_gui.handle_events()

local event_filter = {{ filter="name", name="spoilage-scanner" }}
script.on_event(defines.events.on_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.on_robot_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.on_entity_cloned, on_entity_created, event_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.script_raised_built, on_entity_created, event_filter)
script.on_event(defines.events.script_raised_revive, on_entity_created, event_filter)
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_entity_died, on_entity_removed, event_filter)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, event_filter)
script.on_event(defines.events.on_player_rotated_entity, on_entity_rotated)
script.on_event(defines.events.on_player_flipped_entity, on_entity_rotated)
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_tick, on_tick)


script.on_init(function()
    storage.entity_data = {}
end)


script.on_configuration_changed(function(changes)
    if changes.mod_changes["spoilage-scanner"]
            and changes.mod_changes["spoilage-scanner"].old_version
            and changes.mod_changes["spoilage-scanner"].old_version < '0.3.0'
            and changes.mod_changes["spoilage-scanner"].new_version >= '0.3.0' then 
        local temp_table = {}
        for _,v in pairs(storage.entity_data) do
            temp_table[v.combinator.unit_number] = v
            temp_table[v.combinator.unit_number].mode = aggregation_mode.mean
        end
        storage.entity_data = temp_table
    end
end)