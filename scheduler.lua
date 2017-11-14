local class = require "middleclass"
local PriorityQueue = require 'mPriorityQueue'

local Scheduler = class('Scheduler')

function Scheduler:initialize()
    self.pqueue = PriorityQueue.new()
    self.time   = 0
end

function Scheduler:schedule(time, lambda)
    -- canceller is a mutable table containing whether
    -- the event should be cancelled that is returned to the function that
    -- scheduled the event. Setting its inner value to true prevents the
    -- event from running.
    if not lambda then
        print(lambda,debug.traceback())
    end
    local canceller = {false}
    local payload = {lambda, canceller}
    self.pqueue:enqueue(payload, time)
    return canceller
end

function Scheduler:run(until_time)
    while true do
        local time, payload = self.pqueue:dequeue()
        if not time then
            -- queue is empty, return
            return self.time
        end
        local lambda, canceller = unpack(payload)
        self.time = time
        if time >= until_time then
            -- this event is after the simulation step, reschedule
            -- for the next call
            self.pqueue:enqueue(payload, time)
            self.time = until_time
            return
        elseif canceller[1] then
            -- this event was cancelled, discard it
            LOGGER:log("Ev cancelled: " .. canceller[2] or "no other info supplied")
            return
        else
            lambda(time)
        end
    end
end

return Scheduler
