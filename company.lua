local class = require "middleclass"
local mos   = require 'moses'

local TIME     = require 'TIME'
local genutils = require 'genutils'

local Company = class('Company')

function Company:initialize(govt, name)
    self.government = govt
    self.name       = name
    self.employees  = {}

    table.insert(govt.companies, self)

    local bank = mos.sample(govt.banks)[1]
    local account = {bank=bank, password=genutils.newPassword(8,2)}
    account.id = bank:register(account.password, self)
    self.finance = {account}

    -- events to be cancelled if the company is destroyed
    self.destruction_cancels = {}

    local payout_lambda = true
    payout_lambda = function(time)
        local profit = 50000 * math.pow(1.1,#self.employees)
        local account = self.finance[1]
        account.bank:receive(account.id, profit, {name="Magic Company Profit For Testing"}, 1337)
        local each   = profit / #self.employees -- TOTAL EQUALITY WEW
        for k,employee in pairs(self.employees) do
            local eacc = employee.finance[1]
            account.bank:send(account.id, account.password, each, eacc.bank, eacc.id)
        end
        
        self.destruction_cancels.payout = SCHEDULER:schedule(time+TIME.week, payout_lambda)
    end

    payout_lambda(SCHEDULER.time)
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
