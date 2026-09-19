-- Game/Overrides.lua -- declarative whole-module replacement (optional, no code)
--
-- Write a mapping table to swap an engine module for your own implementation
-- in the Game area, without writing a single line of Lua logic:
--
--     ["engine module name"] = "Game area module name"
--
-- Example (replace the entire battle UI):
--
--     return {
--         ["Scripts.Libraries.Battle.UI"] = "Game.UI.Battle",
--     }
--
-- This is equivalent to calling `Hack.Replace(...)` from a hack; it shares the
-- same mechanism and the same diagnostics:
-- engine module not loaded yet -> clean replacement; already loaded -> it
-- degrades to a per-field hot swap and prints a WARNING.
-- Game module missing or throwing -> a [Hack] ERROR is printed, never silent.
--
-- If you only want to change one or two functions, Wrap/Set/Patch under
-- Game/Hacks/ is a better fit: a full copy does not follow engine updates
-- (when the engine changes the UI, your copy will not error - it just quietly
-- goes stale).

return {
    -- ["Scripts.Libraries.Battle.UI"] = "Game.UI.Battle",
}
