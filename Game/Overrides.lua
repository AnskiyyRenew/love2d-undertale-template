-- Game/Overrides.lua -- declarative whole-module replacement (optional).
-- Mapping ["engine module name"] = "Game area module name"; equivalent to
-- Hack.Replace(...). Engine module not loaded yet -> clean replacement; already
-- loaded -> per-field hot swap + WARNING. Missing/throwing Game module -> a
-- [Hack] ERROR. For one or two functions prefer Wrap/Set/Patch in Game/Hacks
-- (a full copy does not follow engine updates).

return {
    -- ["Scripts.Libraries.Battle.UI"] = "Game.UI.Battle",
}
