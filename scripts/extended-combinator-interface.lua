assert(script)
local tools = require('framework.tools')
local const = require('lib.constants')

local ExtendedCombinator = require('scripts.extended-combinator')

---@class ExtendedCombinatorInterface : ExtendedCombinator
local ExtendedCombinatorInterface = setmetatable({}, { __index = ExtendedCombinator })