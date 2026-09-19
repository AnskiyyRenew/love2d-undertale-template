-- Example hack (NOT an entry point: files starting with "_" are skipped by the
-- loader). Copy the parts you need into e.g. Game/Hacks/010_mine.lua.

-- A whole replacement module for the battle UI lives here too, and is required
-- by name from the hack below.
local my_ui = {}

function my_ui.SetTextPosition(x, y)
    print("[MyUI] SetTextPosition", x, y)
end

return my_ui
