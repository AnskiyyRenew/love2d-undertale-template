local room = DATA.room
local triggered = 0
local text = {}

function text:GetDialog()
    triggered = triggered + 1
    if (room == "Overworld/scene_ow_new") then
        if (triggered == 1) then
            return "* Hello, my child!"
        elseif (triggered == 2) then
            return "* You called me again![wait:30]\n* I love you so much."
        else
            return "* (But nobody came.)"
        end
    else
        return "* (But nobody came.)"
    end
end

return text