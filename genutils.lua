local mos   = require 'moses'

local CHARSETS = require 'CHARSETS'

local genutils = {}

function genutils.newUID(length)
    return math.random(0,math.pow(10,length))
end

function genutils.newPassword(length, level)
    legnth = length or 6
    level = level or 0
    if     level == 0 then return newUID(length)
    elseif level == 1 then return table.concat(mos.sample(CHARSETS.alpha  , length))
    elseif level == 2 then return table.concat(mos.sample(CHARSETS.cased  , length))
    else                   return table.concat(mos.sample(CHARSETS.casenum, length))
    end
end

return genutils
