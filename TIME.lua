local TIME = {}
TIME.minute = 60
TIME.hour   = TIME.minute*60
TIME.day    = TIME.hour*24
TIME.week   = TIME.day*7
TIME.year   = TIME.day*365.25
TIME.days_in_months = {31,28,31,30,31,30,31,31,30,31,30,31}
TIME.dow_strings = {"Monday","Tuesday","Wednesday","Thursday","Friday",
                    "Saturday", "Sunday"}
TIME.month_strings = {"January", "February", "March", "April", "May",
                      "June", "July", "August", "September", "October",
                      "November", "December"}
TIME.short_month_strings = {}
for _,month in ipairs(TIME.month_strings) do
    table.insert(TIME.short_month_strings, month:sub(0, 3))
end

--- XXX probably doesn't account for leap years correctly
--- Maybe everything smaller than a year should first subtract the current
--- year offset before doing calculations?

TIME.today = function(time)
    return math.floor(time/TIME.day)*TIME.day
end

TIME.tomorrow = function(time)
    return TIME.today(time) + TIME.day
end

TIME.walltime = function(hours, minutes, seconds)
    minutes = minutes or 0
    seconds = seconds or 0
    return hours * TIME.hour + minutes * TIME.minute + seconds
end

TIME.tomorrow_at = function(time, hours, minutes, seconds)
    return TIME.tomorrow(time) + TIME.walltime(hours, minutes, seconds)
end

TIME.this_week = function(time)
    return math.floor(time / TIME.week) * TIME.week
end

TIME.next_week = function(time)
    return TIME.this_week(time) + TIME.week
end

TIME.dow_index = function(time)
    return math.floor((time - TIME.this_week(time)) / TIME.day)
end

TIME.dow = function(time)
    return TIME.dow_strings[TIME.dow_index(time)+1]
end

TIME.year_number = function(time)
    return math.floor(time / TIME.year)
end

local function divisible_by(numerator, denominator)
    return (numerator/denominator == math.floor(numerator/denominator))
end

TIME.leap_year = function(year_number)
    -- XXX these are for the Gregorian calendar, do they actually apply to our start-at-zero world?
    if     not divisible_by(year_number,4  ) then return false
    elseif not divisible_by(year_number,100) then return true
    elseif not divisible_by(year_number,400) then return false
    else                                          return true
    end
end

TIME.this_year = function(time)
    return TIME.year_number(time) * TIME.year
end

TIME.month_number = function(time)
    local year = TIME.year_number(time)
    local leap = TIME.leap_year(year)
    local off  = time - (year * TIME.year)
    for month_num, days in ipairs(TIME.days_in_months) do
        if month_num == 2 and leap then -- check for leap in February
            days = days + 1
        end
        
        local month_length = (days * TIME.day)
        if off < month_length then
            return month_num, math.floor(off / TIME.day)+1
        end

        off = off - month_length
    end
    error("TIME.month_number somehow had an offset greater than the number of seconds in the year")
end

TIME.month = function(time)
    local month, day = TIME.month_number(time)
    return TIME.month_strings[month], day
end

TIME.short_month = function(time)
    local month, day = TIME.month_number(time)
    return TIME.short_month_strings[month], day
end

TIME.date_string = function(time)
    local dow = TIME.dow(time)
    local month, day = TIME.month(time)
    local year = TIME.year_number(time)
    return ("%s, %02d %s %04d"):format(dow, day, month, year)
end

return TIME
