-- Example hack. Files starting with "_" are skipped by the loader, so copy the
-- parts you need into e.g. Game/Hacks/010_mine.lua.

local my_ui = {}

function my_ui.SetTextPosition(x, y)
    print("[MyUI] SetTextPosition", x, y)
end

return my_ui
