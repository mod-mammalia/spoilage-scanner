------------------------------------------------------------------------
-- Filter combinator main code
------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')
local table = require('stdlib.utils.table')
local tools = require('framework.tools')
local Gui = require('scripts.gui.extended-combinator')
local const = require('lib.constants')

---@class ExtendedCombinator
local ExtendedCombinator = {}

------------------------------------------------------------------------
---@type ExtendedCombinatorConfig
local default_config = {
    enabled = true,
    use_wire = false,
    filter_wire = defines.wire_type.green,
    include_mode = true,
    filters = {}
}

ExtendedCombinator.default_config = {
    enabled = true,
    use_wire = false,
    filter_wire = defines.wire_type.green,
    include_mode = true,
    filters = {},
    aggregation_mode = aggregation_mode.mean
}

ExtendedCombinator.combinator_name = 'UNDEFINED'
ExtendedCombinator.packed_combinator_name = 'UNDEFINED'
ExtendedCombinator.gui_name = 'UNDEFINED'
ExtendedCombinator.gui = Gui
---@return string[]
function ExtendedCombinator:get_entity_names()
    return { self.combinator_name, self.packed_combinator_name }
end

---@param parent_config ExtendedCombinatorConfig?
---@return ExtendedCombinatorConfig config
function ExtendedCombinator:create_config(parent_config)
    parent_config = parent_config or self.default_config

    local config = {}
    -- iterate over all field names given in the default_config
    for field_name, _ in pairs(default_config) do
        if parent_config[field_name] ~= nil then
            config[field_name] = parent_config[field_name]
        else
            config[field_name] = default_config[field_name]
        end
    end

    return config
end

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global fico data structure.
function ExtendedCombinator:init()
    if storage.exc_data then return end

    ---@type ExtendedCombinatorStorageData
    local storage_data = {
        exc = {},
        count = 0,
        VERSION = const.current_version,
    }

    storage.exc_data = storage_data
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

--- Returns the registered total count
---@return integer count The total count of filter combinators
function ExtendedCombinator:totalCount()
    return storage.exc_data.count
end

--- Returns data for all filter combinators.
---@return ExtendedCombinatorData[] entities
function ExtendedCombinator:entities()
    return storage.exc_data.exc
end

--- Returns data for a given filter combinator
---@param entity_id integer main unit number (== entity id)
---@return ExtendedCombinatorData? entity
function ExtendedCombinator:entity(entity_id)
    return storage.exc_data.exc[entity_id]
end

--- Sets or clears a filter combinator entity
---@param entity_id integer The unit_number of the primary
---@param fc_entity ExtendedCombinatorData?
function ExtendedCombinator:setEntity(entity_id, fc_entity)
    assert((fc_entity ~= nil and storage.exc_data.exc[entity_id] == nil)
        or (fc_entity == nil and storage.exc_data.exc[entity_id] ~= nil))

    if (fc_entity) then
        assert(Is.Valid(fc_entity.main) and fc_entity.main.unit_number == entity_id)
    end

    storage.exc_data.exc[entity_id] = fc_entity
    storage.exc_data.count = storage.exc_data.count + ((fc_entity and 1) or -1)

    if storage.exc_data.count < 0 then
        storage.exc_data.count = table_size(storage.exc_data.exc)
        Framework.logger:logf('Filter Combinator count got negative (bug), size is now: %d', storage.exc_data.count)
    end
end

------------------------------------------------------------------------
-- filter management
------------------------------------------------------------------------

---@param control LuaConstantCombinatorControlBehavior
---@param filters LogisticFilter[]
function ExtendedCombinator:assign_filters(control, filters)
    for i = 1, control.sections_count, 1 do
        control.remove_section(i)
    end

    ---@type integer
    local idx = 0

    ---@type table<string, table<string, table<string, number>>>
    local cache = {}

    for i, filter in pairs(filters) do
        local signal = filter.value --[[@as SignalFilter]]
        local type = signal.type or 'item'
        cache[type] = cache[type] or {}
        cache[type][signal.name] = cache[type][signal.name] or {}

        local index = cache[type][signal.name][signal.quality]
        if not index then
            index = idx
            cache[type][signal.name][signal.quality] = index
            idx = idx + 1
            local section = control.sections[math.floor(index / 1000) + 1] or control.add_section()

            local pos = index % 1000 + 1
            section.set_slot(pos, filter)
        else
            local section = control.sections[math.floor(index / 1000) + 1]
            assert(section)

            local pos = index % 1000 + 1
            filter.min = filter.min + section.filters[pos].min
            section.set_slot(pos, filter)
        end
    end
end

------------------------------------------------------------------------
-- internal wiring management
------------------------------------------------------------------------

function ExtendedCombinator:get_wire_name(circuit, wire)
    circuit = circuit and 'combinator_' .. circuit or 'circuit'

    local wire_name = circuit .. '_' .. wire
    return defines.wire_connector_id[wire_name]
end

---@param fc_entity ExtendedCombinatorData
---@param wire_cfg ExcWireConfig
---@param wire_type table<string, defines.wire_type>?
function ExtendedCombinator:connect_wire(fc_entity, wire_cfg, wire_type)
    wire_type = wire_type or defines.wire_type
    local wire = wire_type[wire_cfg.wire or 'red']
    local wire_name = wire_type_names[wire]

    local wire_origin = defines.wire_origin[fc_entity.comb_visible and 'player' or 'script']

    assert(fc_entity.ref[wire_cfg.src])
    assert(fc_entity.ref[wire_cfg.dst])

    local src_connector = fc_entity.ref[wire_cfg.src].get_wire_connector(self:get_wire_name(wire_cfg.src_circuit, wire_name), false)
    local dst_connector = fc_entity.ref[wire_cfg.dst].get_wire_connector(self:get_wire_name(wire_cfg.dst_circuit, wire_name), false)

    if src_connector and dst_connector then
        assert(src_connector.connect_to(dst_connector, false, wire_origin))
    end
end

---@param fc_entity ExtendedCombinatorData
---@param wire_cfg ExcWireConfig
function ExtendedCombinator:disconnect_wire(fc_entity, wire_cfg)
    local wire = defines.wire_type[wire_cfg.wire or 'red']
    local wire_name = wire_type_names[wire]

    local wire_origin = defines.wire_origin[fc_entity.comb_visible and 'player' or 'script']

    assert(fc_entity.ref[wire_cfg.src])

    if wire_cfg.dst then
        assert(fc_entity.ref[wire_cfg.dst])
    end

    local src_connector = wire_cfg.src and fc_entity.ref[wire_cfg.src].get_wire_connector(self:get_wire_name(wire_cfg.src_circuit, wire_name), false)
    assert(src_connector)

    local dst_connector = wire_cfg.dst and fc_entity.ref[wire_cfg.dst].get_wire_connector(self:get_wire_name(wire_cfg.dst_circuit, wire_name), false)

    if dst_connector then
        src_connector.disconnect_from(dst_connector, wire_origin)
    else
        src_connector.disconnect_all(wire_origin)
    end
end

---@type SubEntityConfig[]
ExtendedCombinator.sub_entities = {
    { id = 'signals', type = 'cc', x = 0,  y = 2, desc = 'GUI Settings' },
}

---@type table<string, DcConfig[]>
ExtendedCombinator.dc_config = {}

---@type table<string, AcConfig[]>
ExtendedCombinator.ac_config = {}
---@type table<string, ExcWireConfig[]>
ExtendedCombinator.wiring = {
    -- the base wiring that needs to be done when the combinator is created
    init = { },
}

------------------------------------------------------------------------
-- create internal entities
------------------------------------------------------------------------

---@param cfg ExcCreateInternalEntityCfg
local function create_internal_entity(cfg)
    local fc_entity = cfg.entity
    local type = cfg.type
    local comb_visible = cfg.comb_visible or false
    local desc = cfg.desc or ''


    -- invisible combinators share position with the main unit
    local x = (comb_visible and cfg.x or 0) or 0
    local y = (comb_visible and cfg.y or 0) or 0

    local entity_map = const.entity_maps[comb_visible and 'debug' or 'standard']

    local main = fc_entity.main

    ---@type LuaEntity?
    local sub_entity = main.surface.create_entity {
        name = entity_map[type],
        position = { x = main.position.x + x, y = main.position.y + y },
        direction = main.direction,
        force = main.force,
        quality = main.quality,

        create_build_effect_smoke = false,
        spawn_decorations = false,
        move_stuck_players = true,
    }

    assert(sub_entity)

    sub_entity.combinator_description = desc
    sub_entity.minable = false
    sub_entity.destructible = false
    sub_entity.operable = comb_visible -- for debugging

    fc_entity.entities[sub_entity.unit_number] = sub_entity

    return sub_entity
end

---@param fc_entity ExtendedCombinatorData
---@param dc_config DcConfig
function ExtendedCombinator:configure_dc(fc_entity, dc_config)
    local condition = {
        first_signal = dc_config.first_signal or const.signal_each,
        comparator = dc_config.comparator,
        constant = dc_config.second_constant
    }

    local output = {
        signal = dc_config.output_signal or const.signal_each,
        copy_count_from_input = dc_config.copy_count_from_input,
        networks = { red = dc_config.red_network == nil and true or dc_config.red_network, green = dc_config.green_network == nil and true or dc_config.green_network, }
    }

    local dc_control_behavior = fc_entity.ref[dc_config.src].get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
    assert(dc_control_behavior)
    dc_control_behavior.set_condition(1, condition)
    dc_control_behavior.set_output(1, output)
end

--- Rewires a FC to match its configuration. Must be called after every configuration
--- change.
---@param fc_entity ExtendedCombinatorData
---@param fc_config ExtendedCombinatorConfig?
function ExtendedCombinator:reconfigure(fc_entity, fc_config)

end

------------------------------------------------------------------------
-- create/destroy
------------------------------------------------------------------------

--- Creates and wires up all the sub entities.
---@param fc_entity ExtendedCombinatorData
function ExtendedCombinator:create_sub_entities(fc_entity)
    -- create sub-entities
    for _, cfg in pairs(self.sub_entities) do
        fc_entity.ref[cfg.id] = create_internal_entity {
            entity = fc_entity,
            type = cfg.type,
            x = cfg.x,
            y = cfg.y,
            desc = cfg.desc,
            comb_visible = fc_entity.comb_visible
        }
    end

    local signals_control_behavior = fc_entity.ref.signals.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    assert(signals_control_behavior)
    for i = 1, signals_control_behavior.sections_count, 1 do
        signals_control_behavior.remove_section(i)
    end

    -- setup all the sub-entities
    for _, behavior in pairs(self.ac_config.init) do
        local parameters = {
            first_signal = behavior.first_signal or const.signal_each,
            output_signal = behavior.output_signal or const.signal_each,
            operation = behavior.operation,
            second_constant = behavior.second_constant
        }
        local ac_control_behavior = fc_entity.ref[behavior.src].get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
        ac_control_behavior.parameters = parameters
    end

    for _, behavior in pairs(self.dc_config.init) do
        self:configure_dc(fc_entity, behavior)
    end

    -- setup the initial wiring
    for _, connect in pairs(self.wiring.init) do
        self:connect_wire(fc_entity, connect)
    end
end

--- Creates a new entity from the main entity, registers with the mod
--- and configures it.
---@param main LuaEntity
---@param config ExtendedCombinatorConfig?
function ExtendedCombinator:create(main, config)
    if not Is.Valid(main) then return end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:entity(entity_id) == nil)

    -- if true, draw all combinators and wires. For debugging
    local comb_visible = Framework.settings:startup_setting('debug_mode') --[[@as boolean]]

    -- if config was passed in, use that
    config = self:create_config(config)
    config.status = main.status

    ---@type ExtendedCombinatorData
    local fc_entity = {
        main = main,
        config = tools.copy(config), -- config may refer to the signal object in parent or default config.
        comb_visible = comb_visible,
        entities = {},
        ref = { main = main },
    }

    self:create_sub_entities(fc_entity)

    self:setEntity(entity_id, fc_entity)

    self:reconfigure(fc_entity)

    return fc_entity
end

--- Destroys a FC and all its sub-entities
---@param entity_id integer main unit number (== entity id)
---@return boolean true if an entity was actually destroyed
function ExtendedCombinator:destroy(entity_id)
    assert(Is.Number(entity_id))

    local fc_entity = self:entity(entity_id)
    if not fc_entity then return false end

    for _, sub_entity in pairs(fc_entity.entities) do
        sub_entity.destroy()
    end

    self:setEntity(entity_id, nil)
    return true
end

--------------------------------------------------------------------------------
-- Config serialization for blueprint and tombstone
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return table<string, any>?
function ExtendedCombinator:serialize_config(entity)
    if not Is.Valid(entity) then return end

    local exc_entity = self:entity(entity.unit_number)
    if not exc_entity then return end

    return {
        [const.config_tag_name] = exc_entity.config,
    }
end

------------------------------------------------------------------------
-- ticker code, updates the status
------------------------------------------------------------------------

--- Can be called from a ticker to update e.g. power status. Useful in
--- the GUI.
---@param fc_entity ExtendedCombinatorData
function ExtendedCombinator:tick(fc_entity)
    if not fc_entity then return end

    -- update status based on the main entity
    if not Is.Valid(fc_entity.main) then
        fc_entity.config.enabled = false
        fc_entity.config.status = defines.entity_status.marked_for_deconstruction
    else
        local old_status = fc_entity.config.status
        fc_entity.config.status = fc_entity.main.status

        if old_status ~= fc_entity.config.status then
            self:reconfigure(fc_entity)
        end
    end
end

------------------------------------------------------------------------
-- picker dollies (move)
------------------------------------------------------------------------

function ExtendedCombinator:move(start_pos, entity)
    local fc_entity = self:entity(entity.unit_number)
    if not fc_entity then return end

    local x = entity.position.x - start_pos.x
    local y = entity.position.y - start_pos.y

    for _, e in pairs(fc_entity.entities) do
        if e.valid then
            e.teleport { x = e.position.x + x, y = e.position.y + y }
        end
    end
end

------------------------------------------------------------------------
-- Events

local Event = require('stdlib.event.event')
local Position = require('stdlib.area.position')
local Player = require('stdlib.event.player')

local Matchers = require('framework.matchers')

local const = require('lib.constants')

local TICK_INTERVAL = 10

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@alias on_entity_created_params EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive | EventData.script_raised_built
---@param event on_entity_created_params
function ExtendedCombinator:on_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        tags = tags or entity_ghost.tags
    end

    local config = tags and tags[const.config_tag_name] --[[@as ExtendedCombinatorConfig ]]
    This.exi:create(entity, config)
end

---@alias on_entity_deleted_params EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.script_raised_destroy
---@param event on_entity_deleted_params
function ExtendedCombinator:on_entity_deleted(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end
    assert(entity.unit_number)

    if This.exi:destroy(entity.unit_number) then
        Framework.gui_manager:destroy_gui_by_entity_id(entity.unit_number)
        storage.last_tick_entity = nil
    end
end

--------------------------------------------------------------------------------
-- Entity destruction
--------------------------------------------------------------------------------

---@alias on_object_destroyed_params EventData.on_object_destroyed
---@param event on_object_destroyed_params
function ExtendedCombinator:on_object_destroyed(event)
    -- main entity destroyed
    if This.fico:destroy(event.useful_id) then
        storage.last_tick_entity = nil
        Framework.gui_manager:destroy_gui_by_entity_id(event.useful_id)
    end
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

---@alias on_entity_cloned_params EventData.on_entity_cloned
---@param event on_entity_cloned_params
function ExtendedCombinator:on_entity_cloned(event)
    if not (event and event.source and event.source.valid and event.destination and event.destination.valid) then return end

    local src_data = This.fico:entity(event.source.unit_number)
    if not src_data then return end

    for _, cloned_entity in pairs(event.destination.surface.find_entities_filtered {
        area = Position(event.destination.position):expand_to_area(0.5),
        name = const.internal_entity_names,
    }) do
        cloned_entity.destroy()
    end

    This.fico:create(event.destination, src_data.config)
end

---@alias on_internal_entity_cloned_params EventData.on_entity_cloned
---@param event on_internal_entity_cloned_params
function ExtendedCombinator:on_internal_entity_cloned(event)
    if not (event.source and event.source.valid and event.destination and event.destination.valid) then return end

    -- delete the destination entity, it is not needed as the internal structure of the
    -- filter combinator is recreated when the main entity is cloned
    event.destination.destroy()
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@alias on_entity_settings_pasted_params EventData.on_entity_settings_pasted
---@param event on_entity_settings_pasted_params
function ExtendedCombinator:on_entity_settings_pasted(event)
    if not (event and event.source and event.source.valid and event.destination and event.destination.valid) then return end

    local player = Player.get(event.player_index)
    if not (player and player.valid and player.force == event.source.force and player.force == event.destination.force) then return end

    local src_fc_entity = This.fico:entity(event.source.unit_number)
    local dst_fc_entity = This.fico:entity(event.destination.unit_number)

    if not (src_fc_entity and dst_fc_entity) then return end

    This.fico:reconfigure(dst_fc_entity, src_fc_entity.config)
end

--------------------------------------------------------------------------------
-- Configuration changes (startup)
--------------------------------------------------------------------------------

function ExtendedCombinator:on_configuration_changed()
    This.fico:init()

    -- enable filter combinator if circuit network is researched.
    for _, force in pairs(game.forces) do
        if force.recipes[self.combinator_name] and force.technologies['circuit-network'] then
            force.recipes[self.combinator_name].enabled = force.technologies['circuit-network'].researched
        end
    end
end

--------------------------------------------------------------------------------
-- Event ticker
--------------------------------------------------------------------------------

function ExtendedCombinator:on_nth_tick()
    local interval = TICK_INTERVAL -- fraction of the ficos to update
    local entities = This.fico:entities()
    local process_count = math.ceil(table_size(entities) / interval)
    local index = storage.last_tick_entity

    if process_count > 0 then
        local fc_entity
        repeat
            index, fc_entity = next(entities, index)
            if fc_entity then
                if fc_entity.main and fc_entity.main.valid then
                    This.fico:tick(fc_entity)
                    process_count = process_count - 1
                elseif index then
                    This.fico:destroy(index)
                end
            end
        until process_count == 0 or not index
    else
        index = nil
    end

    storage.last_tick_entity = index
end

--------------------------------------------------------------------------------
-- event registration and management
--------------------------------------------------------------------------------

ExtendedCombinator.singleton_events_registered = false
function ExtendedCombinator:register_singleton_events()
    if ExtendedCombinator.singleton_events_registered then return end
    local match_internal_entities = Matchers:matchEventEntityName(const.internal_entity_names)
    Event.register(defines.events.on_entity_cloned, function(event) self:on_internal_entity_cloned(event --[[@as on_internal_entity_cloned_params]]) end, match_internal_entities)
    ExtendedCombinator.singleton_events_registered = true
end

ExtendedCombinator.nth_tick_interval = 31
function ExtendedCombinator:register_events()
    local match_all_main_entities = Matchers:matchEventEntityName(self:get_entity_names())
    local match_main_entity = Matchers:matchEventEntityName(self.combinator_name)
    
    -- entity create / delete
    Event.register(Matchers.CREATION_EVENTS, function(event) self:on_entity_created(event --[[@as on_entity_created_params]]) end, match_all_main_entities)
    Event.register(Matchers.DELETION_EVENTS, function(event) self:on_entity_deleted(event --[[@as on_entity_deleted_params]]) end, match_all_main_entities)

    -- manage ghost building (robot building)
    Framework.ghost_manager:registerForName(self.combinator_name)

    -- entity destroy (can't filter on that)
    Event.register(defines.events.on_object_destroyed, function(event) self:on_object_destroyed(event --[[@as on_object_destroyed_params]]) end)

    -- Configuration changes (startup)
    Event.on_configuration_changed(function() self:on_configuration_changed() end)

    local serializer = function(entity) self:serialize_config(entity) end
    -- manage blueprinting and copy/paste
    Framework.blueprint:registerCallbackForNames(self.combinator_name, serializer)

    -- manage tombstones for undo/redo and dead entities
    Framework.tombstone:registerCallback(self.combinator_name, {
        create_tombstone = serializer,
        apply_tombstone = Framework.ghost_manager.mapTombstoneToGhostTags,
    })

    -- Entity cloning
    Event.register(defines.events.on_entity_cloned, function(event) self:on_entity_cloned(event --[[@as on_entity_cloned_params]]) end, match_main_entity)
    

    -- Entity settings pasting
    Event.register(defines.events.on_entity_settings_pasted, function(event) self:on_entity_settings_pasted(event --[[@as on_entity_settings_pasted_params]]) end, match_main_entity)

    -- Event ticker
    Event.on_nth_tick(self.nth_tick_interval, function() self:on_nth_tick() end)

    self:register_singleton_events()
end

function ExtendedCombinator:init_gui()
    Framework.gui_manager:register_gui_type(self.gui_name, self.gui:get_gui_event_definition())

    local match_main_entity = Matchers:matchEventEntityName(self.combinator_name)
    local match_ghost_main_entity = Matchers:matchEventEntityGhostName(self.combinator_name)

    Event.on_event(defines.events.on_gui_opened, self.gui.onGuiOpened, match_main_entity)
    Event.on_event(defines.events.on_gui_opened, self.gui.onGhostGuiOpened, match_ghost_main_entity)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

function ExtendedCombinator:on_init()
    self:init()
    self:register_events()
    self:init_gui()
end

function ExtendedCombinator:on_load()
    self:register_events()
    self:init_gui()
end


------------------------------------------------------------------------

return ExtendedCombinator
