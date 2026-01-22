--- TODO:
--- This class is a base combinator for the existing spoilage scanner as well as the forthcoming spoilage combinator.
--- The former is currently based on a constant combinator, but both should be based on arithmetic combinators so that the
--- filters aren't visible and so we can show the output signals in the entity dialog in-game..
--- Both of these entities require an internal constant combinator for setting output signals, although the spoilage scanner
--- needs to have its combinator filters internalized.

---@class SignalCombinator
local SignalCombinator = {}

return SignalCombinator