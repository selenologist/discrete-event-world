local class = require "middleclass"
local mos   = require 'moses'

local TIME     = require 'TIME'
local genutils = require 'genutils'

local Company = class('Company')

function Company:initialize(govt, name, industry)
    industry = industry or "generic"

    self.government = govt
    self.name       = name
    self.employees  = {}

    -- Register with govt
    table.insert(govt.companies, self)
    if not govt.industries[industry] then
        govt.industries[industry] = {}
    end
    table.insert(govt.industries[industry], self)

    -- Make a bank account at a random bank
    local bank = mos.sample(govt.banks)[1]
    local account = {bank=bank, password=genutils.newPassword(8,2)}
    account.id = bank:register(account.password, self)
    self.finance = {account}

    -- Set overridable parameters
    self.days_open = {0,1,2,3,4} -- open weekdays

    -- events to be cancelled if the company is destroyed
    self.destruction_cancels = {}

    local daily_lambda, weekly_lambda = true, true
    daily_lambda = function(time)
        self:dailyEvents(time)
        self.destruction_cancels.daily = SCHEDULER:schedule(time+TIME.day, daily_lambda)
    end
    weekly_lambda = function(time)
        self:weeklyEvents(time)
        self.destruction_cancels.weekly = SCHEDULER:schedule(time+TIME.week, weekly_lambda)
    end

    local time = SCHEDULER.time

    -- schedule for 6am tomorrow
    self.destruction_cancels.daily = SCHEDULER:schedule(
        TIME.tomorrow_at(time, 6),
        daily_lambda)

    -- schedule for 6am next monday
    weekly_lambda(SCHEDULER.time)
end

function Company:dailyEvents(time)
end

function Company:weeklyEvents(time)
    self:payEmployees(time)
end

function Company:payEmployees(time)
    local profit = 50000 * math.pow(1.1,#self.employees)
    local account = self.finance[1]
    account.bank:receive(account.id, profit, {name="Magic Company Profit For Testing"}, 1337)
    local each   = profit / #self.employees -- TOTAL EQUALITY WEW
    for k,employee in pairs(self.employees) do
        local eacc = employee.finance[1]
        account.bank:send(account.id, account.password, each, eacc.bank, eacc.id)
    end
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
