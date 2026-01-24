assert(script)
local tools = require('framework.tools')
local const = require('lib.constants')

local ExtendedCombinator = require('scripts.extended-combinator')

---@class FilterCombinator : ExtendedCombinator
local FilterCombinator = setmetatable({}, { __index = ExtendedCombinator })

FilterCombinator.default_config = table.deepcopy(ExtendedCombinator.default_config)
FilterCombinator.default_config.combinator_type = extended_combinator_type.filter_combinator
FilterCombinator.combinator_name = const.filter_combinator_name
FilterCombinator.packed_combinator_name = const.filter_combinator_name_packed

-- Position grid for sub-entities if they are visible (for debugging)
--
--    -2/-4 (sig_shift) 0/-4        2/-4 (pos_proc)   4/-4 (neg_proc)
--    -2/-2 (sig_norm)  0/-2        2/-2 (pos_filter) 4/-2 (neg_filter)
--    -2/ 0 (signals)   0/ 0 (main) 2/ 0 (pos_split)  4/ 0 (neg_split)
--
FilterCombinator.sub_entities = {
    { id = 'signals',    type = 'cc', x = 0,  y = 2, desc = 'GUI Settings' },

    { id = 'pos_split',  type = 'dc', x = 2,  y = 2, desc = 'Split out all positive data signals.' },
    { id = 'neg_split',  type = 'dc', x = 4,  y = 2, desc = 'Split out all negative data signals.' },

    { id = 'pos_filter', type = 'dc', x = 2,  y = 0, desc = 'Positive signal filter. Removes unwanted signals.' },
    { id = 'neg_filter', type = 'dc', x = 4,  y = 0, desc = 'Negative signal filter. Removes unwanted signals.' },

    { id = 'sig_norm',   type = 'dc', x = -2, y = 2, desc = 'Normalizes all signals to 0/1' },
    { id = 'sig_shift',  type = 'ac', x = -2, y = 0, desc = 'Shifts values to 0/2^31' },
}

---@type table<string, DcConfig[]>
FilterCombinator.dc_config = {
    init = {
        { src = 'pos_split', comparator = '>',  second_constant = 0 },
        { src = 'neg_split', comparator = '<',  second_constant = 0 },
        { src = 'sig_norm',  comparator = '!=', second_constant = 0, copy_count_from_input = false, }
    },

    exclude = {
        { src = 'pos_filter', comparator = '>', second_constant = 0, green_network = false, },
        { src = 'neg_filter', comparator = '<', second_constant = 0, green_network = false, },
    },

    include = {
        { src = 'pos_filter', comparator = '<', second_constant = 0, green_network = false, },
        { src = 'neg_filter', comparator = '>', second_constant = 0, green_network = false, },
    },
}


---@type table<string, AcConfig[]>
FilterCombinator.ac_config = {
    init = {
        { src = 'sig_shift', operation = '<<', second_constant = 31, }
    }
}

---@type table<string, ExcWireConfig[]>
FilterCombinator.wiring = {
    -- the base wiring that needs to be done when the fc is created
    init = {
        -- all data path connections use red wires
        -- positive signal path
        { src = 'pos_split', dst = 'pos_filter', src_circuit = 'output', dst_circuit = 'input', wire = 'red' },
        -- negative signal path
        { src = 'neg_split', dst = 'neg_filter', src_circuit = 'output', dst_circuit = 'input', wire = 'red' },

        -- all signal path connection use green wires
        { src = 'sig_norm',  dst = 'sig_shift',  src_circuit = 'output', dst_circuit = 'input', wire = 'green', },
        { src = 'sig_shift', dst = 'pos_filter', src_circuit = 'output', dst_circuit = 'input', wire = 'green', },
        { src = 'sig_shift', dst = 'neg_filter', src_circuit = 'output', dst_circuit = 'input', wire = 'green', },
    },

    -- enable the FC - wire the processors to the main entity output pins
    enable = {
        { src = 'pos_filter', src_circuit = 'output', dst = 'main', dst_circuit = 'output', wire = 'red', },
        { src = 'pos_filter', src_circuit = 'output', dst = 'main', dst_circuit = 'output', wire = 'green', },
        { src = 'neg_filter', src_circuit = 'output', dst = 'main', dst_circuit = 'output', wire = 'red', },
        { src = 'neg_filter', src_circuit = 'output', dst = 'main', dst_circuit = 'output', wire = 'green', },
    },

    -- do not use a wire for signal selection. Wire the signal buffer to the signal controller and both data wires to the data buffer
    no_wire = {
        { src = 'signals', dst = 'sig_norm',      dst_circuit = 'input', wire = 'green', },
        { src = 'main',    src_circuit = 'input', dst = 'pos_split',     dst_circuit = 'input', wire = 'red', },
        { src = 'main',    src_circuit = 'input', dst = 'pos_split',     dst_circuit = 'input', wire = 'green', },
        { src = 'main',    src_circuit = 'input', dst = 'neg_split',     dst_circuit = 'input', wire = 'red', },
        { src = 'main',    src_circuit = 'input', dst = 'neg_split',     dst_circuit = 'input', wire = 'green', },
    },

    -- use red wire for signal selection. Wire it to the signal buffer, wire only the green wire to the data buffer
    red_wire = {
        { src = 'main', src_circuit = 'input', dst = 'sig_norm',  dst_circuit = 'input', wire = 'red', },
        { src = 'main', src_circuit = 'input', dst = 'pos_split', dst_circuit = 'input', wire = 'green', },
        { src = 'main', src_circuit = 'input', dst = 'neg_split', dst_circuit = 'input', wire = 'green', },
    },

    -- use green wire for signal selection. Wire it to the signal buffer, wire only the red wire to the data buffer
    green_wire = {
        { src = 'main', src_circuit = 'input', dst = 'sig_norm',  dst_circuit = 'input', wire = 'green', },
        { src = 'main', src_circuit = 'input', dst = 'pos_split', dst_circuit = 'input', wire = 'red', },
        { src = 'main', src_circuit = 'input', dst = 'neg_split', dst_circuit = 'input', wire = 'red', },
    },
}

--- Rewires a FC to match its configuration. Must be called after every configuration
--- change.
---@param fc_entity ExtendedCombinatorData
---@param fc_config ExtendedCombinatorConfig?
function FilterCombinator:reconfigure(fc_entity, fc_config)
    if not fc_entity then return end

    fc_config = fc_config and util.copy(fc_config) or fc_entity.config

    local enabled = fc_config.enabled and tools.STATUS_TABLE[fc_entity.config.status] ~= 'RED'

    -- disconnect all wires
    for _, name in pairs { 'enable', 'no_wire', 'red_wire', 'green_wire', } do
        for _, cfg in pairs(self.wiring[name]) do
            self:disconnect_wire(fc_entity, cfg)
        end
    end

    local signals_control_behavior = fc_entity.ref.signals.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
    assert(signals_control_behavior)
    signals_control_behavior.enabled = enabled

    if not enabled then return end

    -- setup the signals in the signal_control cc
    self:assign_filters(signals_control_behavior, fc_config.filters)

    -- enabled. Connect the wires for enabling
    for _, cfg in pairs(self.wiring.enable) do
        self:connect_wire(fc_entity, cfg)
    end

    -- rewiring for internal settings / green wire / red wire
    local rewire_cfg = 'no_wire'
    if fc_config.use_wire then
        rewire_cfg = fc_config.filter_wire == defines.wire_type.red and 'red_wire' or 'green_wire'
    end

    for _, cfg in pairs(self.wiring[rewire_cfg]) do
        self:connect_wire(fc_entity, cfg)
    end

    -- control include/exclude
    local dc_cfg = fc_config.include_mode and 'include' or 'exclude'
    for _, behavior in pairs(self.dc_config[dc_cfg]) do
        self:configure_dc(fc_entity, behavior)
    end
end



return FilterCombinator
