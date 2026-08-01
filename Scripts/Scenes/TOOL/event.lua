--[[local event = {}

function EventU1() end
function EventU2() end
function EventU3() end
function EventU5() end

function Event2() end

function event.update(dt)
    if (beats.OnBeat(1)) then
        EventU1()
        EventU2()
        EventU3()
        EventU5()
    end
    if (beats.OnBeat(2) or beats.OnBeat(2.5) or beats.OnBeat(3) or beats.OnBeat(3.5) or beats.OnBeat(4)) then
        Event2()
    end
end

return event]]