local function stringToCharset(str)
    local set = {}
    for i=0,#str do
        table.insert(set,str:sub(i,i))
    end
    return set
end

local CHARSETS={}
do
    local alpha = "abcdefghijklmnopqrstuvwxyz"
    local ALPHA = alpha:upper()
    local numer = "0123456789"
    CHARSETS.alpha   = stringToCharset(alpha)
    CHARSETS.cased   = stringToCharset(alpha..ALPHA)
    CHARSETS.casenum = stringToCharset(alpha..ALPHA..numer)
end

return CHARSETS
