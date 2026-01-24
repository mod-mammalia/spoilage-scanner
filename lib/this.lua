----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class FilterCombinatorMod
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

if script then
    This.exi = require('scripts.event-interface')
    This.fico = require('scripts.filter-combinator')
    This.spco = require('scripts.spoilage-combinator')
    This.combinators = { This.fico, This.spco }
    This.gui = require('scripts.gui') --[[@as FilterCombinatorGui ]]
    This.on_init = function()
        for _, c in ipairs(This.combinators) do
            c:on_init()
        end
    end
    This.on_load = function()
        for _, c in ipairs(This.combinators) do
            c:on_load()
        end
    end

    -- setup remote interface
    require('scripts.remote')
end

return This
