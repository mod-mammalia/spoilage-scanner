require '_defs'

---@class CommonData
local Common = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

-- the current version that is the result of the latest migration
Common.current_version = 1
Common.prefix = 'hps__fc-'
Common.name = 'spoilage-scanner'
Common.prefix = Common.name .. '-'
Common.name_packed = Common.name .. '-packed' -- for compakt circuits
Common.dir = {}
Common.dir.root = '__' .. Common.name .. '__'
Common.dir.gfx = Common.dir.root .. '/graphics'
Common.tag_prefix = 'spsc_config'


--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Common:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Common:png(path)
    return self.dir.gfx .. '/' .. path .. '.png'
end

---@param id string
---@return string result
function Common:locale(id)
    return Common:with_prefix('gui.') .. id
end


--------------------------------------------------------------------------------
-- data helper
--------------------------------------------------------------------------------

Common.ac_sprites = {
    'plus_symbol_sprites',
    'minus_symbol_sprites',
    'multiply_symbol_sprites',
    'divide_symbol_sprites',
    'modulo_symbol_sprites',
    'power_symbol_sprites',
    'left_shift_symbol_sprites',
    'right_shift_symbol_sprites',
    'and_symbol_sprites',
    'or_symbol_sprites',
    'xor_symbol_sprites',
}

Common.aggregation_operators = {
    [aggregation_mode.mean] = '%',
    [aggregation_mode.min] = '<<',
    [aggregation_mode.max] = '>>',
}

--------------------------------------------------------------------------------
-- entity names and maps
--------------------------------------------------------------------------------

-- Base name
Common.filter_combinator_name = Common:with_prefix(Common.name)

-- Compactcircuits support
Common.filter_combinator_name_packed = Common:with_prefix(Common.name_packed)

-- Internal entities in normal and debug mode
Common.internal_ac_name = Common:with_prefix('filter-combinator-ac')
Common.internal_cc_name = Common:with_prefix('filter-combinator-cc')
Common.internal_dc_name = Common:with_prefix('filter-combinator-dc')
Common.internal_debug_ac_name = Common:with_prefix('filter-combinator-debug-ac')
Common.internal_debug_cc_name = Common:with_prefix('filter-combinator-debug-cc')
Common.internal_debug_dc_name = Common:with_prefix('filter-combinator-debug-dc')

Common.entity_maps = {
    standard = { ac = Common.internal_ac_name, cc = Common.internal_cc_name, dc = Common.internal_dc_name, },
    debug = { ac = Common.internal_debug_ac_name, dc = Common.internal_debug_dc_name, cc = Common.internal_debug_cc_name, }
}

-- all internal entities
Common.internal_entity_names = {
    Common.internal_ac_name, Common.internal_cc_name, Common.internal_dc_name,
    Common.internal_debug_ac_name, Common.internal_debug_cc_name, Common.internal_debug_dc_name,
}

--------------------------------------------------------------------------------
return Common