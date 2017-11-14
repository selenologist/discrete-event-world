local class = require "middleclass"
local mos   = require 'moses'

local TIME     = require 'TIME'
local genutils = require 'genutils'

local Company = class('Company')

function Company:initialize(govt, name, industry)
    industry = industry or "generic"
    self.industry = industry

    self.government = govt
    self.name       = name
    self.employees  = {}

    --- Register with govt
    table.insert(govt.companies, self)
    if not govt.industries[industry] then
        govt.industries[industry] = {}
    end
    table.insert(govt.industries[industry], self)

    --- Make a bank account at a random bank
    local bank = mos.sample(govt.banks)[1]
    local password = genutils.newPassword(8,2)
    local account = bank:register(password, self)
    self.finance = {account}
    account.bank:receive(account.id, 50000, {name="Magic Initial Company Money"}, 31337)

    --- Set overridable parameters
    self.days_open = {[0]=true,[1]=true,[2]=true,[3]=true,[4]=true} -- open weekdays
    self.dates_closed = {[1225] = true} -- closed on xmas day
    self.open_time  = TIME.walltime(6)  -- open at 6am
    self.close_time = TIME.walltime(17) -- close at 5pm
    self.pay_policy = 'fairshare'
    self.reserve    = 0.1 -- fraction of profit the company reserves before paying workers

    --- set mutables
    -- employee = key, arrival time = value
    -- special key 'num' is the number that are present
    self.employees_present = {num=0}
    self.today = {}
    self.week  = {}

    --- events to be cancelled if the company is destroyed
    self.pending_events = {}

    self:scheduleTimers(SCHEDULER.time)
end

function Company:scheduleTimers(time)
    local function clear_if_sched(event)
        if self.pending_events[event] then
            self.pending_events[event][1] = true
            self.pending_events[event][2] = "clear_if_sched " .. self.class.name
        end
    end
    clear_if_sched('daily')
    clear_if_sched('weekly')

    local daily_lambda, weekly_lambda = true, true
    daily_lambda = function(time)
        self:dailyEvents(time)
        self.pending_events.daily = SCHEDULER:schedule(time+TIME.day, daily_lambda)
    end
    weekly_lambda = function(time)
        self:weeklyEvents(time)
        self.pending_events.weekly = SCHEDULER:schedule(time+TIME.week, weekly_lambda)
    end
    
    -- schedule daily events
    self.pending_events.daily = SCHEDULER:schedule(
        TIME.tomorrow(time) + self.open_time,
        daily_lambda)

    -- schedule weekly events
    self.pending_events.weekly = SCHEDULER:schedule(
        TIME.next_week(time),
        weekly_lambda)
end

function Company:isOpenOnDay(time)
    local dow = TIME.dow_index(time)
    local month, day = TIME.month_number(time)
    local monthday = month*100 + day
    return self.days_open[dow] and not self.dates_closed[monthday]
end

function Company:isOpenAtTime(time)
    local walltime = time - TIME.today(time)
    return walltime >= self.open_time and walltime <= self.close_time
end

function Company:dailyEvents(time)
    self.today = {}

    if self:isOpenOnDay(time) then
        self:workingDayEvents(time)
    else
        if self.closedDayEvents then
            self:closedDayEvents(time)
        end
    end
end

function Company:atClose(time)
    self.pending_events.close = nil
end

function Company:workingDayEvents(time)
    if #self.employees > 0 then
        self:orderCatering(time)
        if self.industry == 'generic' then
            self.week.income = (self.week.income or 0) + 500 * math.pow(1.1, self.employees_present.num)
        end
        
        self.pending_events.close = SCHEDULER:schedule(
            TIME.today(time) + self.close_time,
            function(time)
                self:atClose(time)
            end)
    end
end

function Company:weeklyEvents(time)
    self:payEmployees(time)
end

function Company:orderCatering(time)
    local account = self.finance[1]
    local balance = account.balance
    local employees = #self.employees
    local caterer = mos.sample(self.government.industries.catering)[1]
    local cost = caterer:priceCatering(employees)
    if balance > cost then
        caterer:placeOrder(time, self, employees, cost)
        account:send(cost, caterer)
        self.week.expenses = (self.week.expenses or 0) + cost
    end
end

function Company:payEmployees(time)
    local income = (self.week.income or 0)
    local expenses = (self.week.expenses or 0)
    local profit = income - expenses

    LOGGER:log(("%s made a profit of $%d (income $%d expenses $%d)")
              :format(self.name, profit, income, expenses),
               LOG_LEVELS.verbose)

    local account = self.finance[1]
    if self.industry == 'generic' then
        account.bank:receive(account.id, income, {name="Magic Company Income"}, 31337)
    end
    
    if self.pay_policy == 'fairshare' then
        if profit < 0 then profit = (self.last_positive_profit or 5000)
        else self.last_positive_profit = profit end

        local each   = (profit * (1.0 - self.reserve)) / #self.employees
        for k,employee in pairs(self.employees) do
            account:send(each, employee)
        end
    elseif self.pay_policy == 'wage' then
        local hours = math.ceil((self.close_time - self.open_time) / TIME.hour)
        local pay   = hours * self.wage
        for k,employee in pairs(self.employees) do
            account:send(pay, employee)
        end
    end

    self.week = {}
end

function Company:employeeArrival(time, employee)
    employee.location = 'work'
    self.employees_present[employee] = time
    self.employees_present.num = self.employees_present.num + 1
    LOGGER:log(("%s has gone to their job at %s")
              :format(employee.name(), self.name),
               LOG_LEVELS.verbose)
    employee.pending_events.leave_work = SCHEDULER:schedule(TIME.today(time) + self.close_time,
        function(time)
            if employee.location == 'work' then
                self.employees_present[employee] = nil
                self.employees_present.num = self.employees_present.num - 1
                employee:leaveWork(time)
            end
            -- otherwise they were not at work and are not work's problem
        end)
end

function Company:deliveryArrival(time, kind, from, data)
    LOGGER:log(("%s received %s from %s")
              :format(self.name, kind, from.name),
              LOG_LEVELS.verbose)
end

function Company:employ(person)
    LOGGER:log(("%s %s is now employed at %s")
                     :format(person.name.first, person.name.last, self.name),
                      LOG_LEVELS.info)
    person.employer = self
    person.employment_time = SCHEDULER.time
    table.insert(self.employees, person)
end

return Company
