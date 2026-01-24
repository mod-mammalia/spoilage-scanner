---@meta

---@enum wire_type_names
wire_type_names = {
    [defines.wire_type.copper] = 'copper',
    [defines.wire_type.red] = 'red',
    [defines.wire_type.green] = 'green',
}

---@enum combinator_type
combinator_type = {
    constant = 'cc',
    arithmetic = 'ac',
    decider = 'dc'
}

---@enum extended_combinator_type
extended_combinator_type = {
    filter_combinator = 'fico',
    spoilage_combinator = 'spco'
}

---@enum aggregation_mode
aggregation_mode = {
    mean = 1 --[[@as aggregation_mode.mean ]],
    max = 2 --[[@as aggregation_mode.max ]],
    min = 3 --[[@as aggregation_mode.min ]],
}

---@class AcConfig
---@field src string
---@field first_signal string?
---@field operation string
---@field second_constant number
---@field output_signal string?

---@class DcConfig
---@field src string
---@field first_signal string?
---@field comparator string
---@field second_constant number
---@field output_signal string?
---@field copy_count_from_input boolean?
---@field red_network boolean?
---@field green_network boolean?

---@class ExcWireConfig
---@field src string
---@field dst string?
---@field src_circuit string?
---@field dst_circuit string?
---@field wire string?

---@class ExtendedCombinatorConfig
---@field enabled boolean
---@field status defines.entity_status?
---@field combinator_type extended_combinator_type

--- @class ExtendedCombinatorData
--- @field main LuaEntity
--- @field config ExtendedCombinatorConfig
--- @field comb_visible boolean
--- @field entities LuaEntity[]
--- @field ref table<string, LuaEntity>
---@class FilterCombinatorConfig : ExtendedCombinatorConfig
---@field use_wire boolean
---@field filter_wire defines.wire_type
---@field include_mode boolean
---@field filters LogisticFilter[]

---@class FilterCombinatorData : ExtendedCombinatorData
---@field config FilterCombinatorConfig

---@class SpoilageCombinatorConfig : ExtendedCombinatorConfig
---@field aggregation_mode aggregation_mode

---@class SpoilageCombinatorData : ExtendedCombinatorData
---@field config SpoilageCombinatorConfig
---@field containers table<defines.wire_type, LuaEntity[]>

---@class ExcCreateInternalEntityCfg
---@field entity ExtendedCombinatorData
---@field type string
---@field ignore boolean?
---@field comb_visible boolean
---@field desc string?
---@field x integer?
---@field y integer?

---@class SubEntityConfig
---@field id string
---@field type combinator_type
---@field x number
---@field y number
---@field desc string

---@class ExtendedCombinatorStorageData
---@field exc table<integer,ExtendedCombinatorData>
---@field count integer
---@field VERSION integer

---@alias SpoilageSignals table<string, integer>
---@alias WiredSpoilageSignals table<defines.wire_type, SpoilageSignals>
