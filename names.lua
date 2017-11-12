local moses = require 'moses'

local names = {}

function names.randomName()
    return moses.sample(names.first)[1], moses.sample(names.last)[1]
end

do
    local first, last = {}, {}
    for x in io.lines("random-name/first-names.txt") do
        -- strip off \r at end
        table.insert(first,x:sub(1,#x-1))
    end
    for x in io.lines("random-name/names.txt") do
        table.insert(last, x:sub(1,#x-1))
    end

    names.first = first
    names.last  = last
end

return names
