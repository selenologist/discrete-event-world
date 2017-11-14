local class = require "middleclass"

local TIME = require "TIME"

local Logger = class('Logger')

LOG_LEVELS={
    all=6,
    verbose=5,
    debug=4,
    info=3,
    warn=2,
    err=1,
    off=0
}

function Logger:initialize(log_level)
    self.log_level = log_level or LOG_LEVELS.all
end

logfile=io.open("logfile",'w')
function Logger:log(x, level)
    level = level or LOG_LEVELS.info
    local str = TIME.time_string(SCHEDULER.time)..' '..TIME.date_string(SCHEDULER.time)..': '..x
    logfile:write(str..'\n')
    if level <= self.log_level then
        print(str)
    end
end

return Logger
