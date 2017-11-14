local class = require "middleclass"

local Company = require 'company'
local TIME    = require 'TIME'

local CateringCompany = class('CateringCompany', Company)

function CateringCompany:initialize(govt, name)
    Company.initialize(self, govt, name, 'catering')

    --- override Company parameters
    self.open_time = TIME.walltime(5) -- open at 5am
    self.close_time = TIME.walltime(16) -- close at 4pm

    --- set overrideables
    self.food_cost = 20  -- 35/head for ingredients
    self.prod_time = 300 -- 3 minutes 20 seconds per head
    self.wage      = 20 -- employees are paid $20/hr
    self.margin    = 2.7 -- 270% margin on production cost
    self.pay_policy = 'wage'

    --- set mutables
    -- key = company, value = {order_time,amount,produced,workers}
    self.orders = {}

    --- Re-schedule timers since we updated open_time and close_time
    self:scheduleTimers(SCHEDULER.time)
end

function CateringCompany:atClose(time)
    self.pending_events.close = nil

    local today = self.today
    local excess = today.excess_food or 0
    if excess > 0 then
        today.food_cost = (today.food_cost or 0) + self.food_cost * excess
        LOGGER:log(("%s closed with %d excess units of food produced! That will cost $%d")
                  :format(self.name, excess, self.food_cost*excess), LOG_LEVELS.debug)
    end
    local food_cost = today.food_cost or 0
    local income    = today.income or 0
    if food_cost > 0 then
        self.finance[1]:send(food_cost, MONEYPIT)
    end
    LOGGER:log(("%s spent $%d on raw food today making $%d income"):format(self.name, food_cost, income),
               LOG_LEVELS.verbose)
    self.week.income = (self.week.income or 0) + income
    self.week.expenses = (self.week.expenses or 0) + food_cost
end

function CateringCompany:orderCatering(time)
    -- do our own catering
    self:placeOrder(time, self, #self.employees, 0)
end

function CateringCompany:priceCatering(num_heads)
    local prod_time = self.prod_time * num_heads
    local labor_cost = prod_time * self.wage / TIME.hour
    local prod_cost = labor_cost + self.food_cost * num_heads
    local order_cost = prod_cost * self.margin
    return order_cost
end

function CateringCompany:placeOrder(time, for_company, num_heads, cost)
    local today = self.today

    local food_cost = self.food_cost * num_heads

    LOGGER:log(("%s received a catering order from %s for %d employees")
              :format(self.name, for_company.name, num_heads),
               LOG_LEVELS.verbose)
    today.food_cost = (today.food_cost or 0) + food_cost
    today.income = (today.income or 0) + cost

    self.orders[for_company] = {
        order_time  = time,
        amount      = num_heads,
        produced    = 0,
        workers     = 0 -- workers allocated to doing this
    }

    self:manageEmployees(time)
end

function CateringCompany:manageEmployees(time)
    for e,_ in pairs(self.employees_present) do
        if e ~= 'num' and not e.pending_events.work_task then
            self:employeeFindTask(time, e)
        end
    end
end

function CateringCompany:employeeFindTask(time, employee)
    -- XXX this is awful, clean this up
    local completed_orders = {}
    
    for company, order in pairs(self.orders) do
        if (order.produced + order.workers) < order.amount then
            if (self.today.excess_food or 0) > 0 then -- check for excess left by other workers
                local old_amount = order.produced
                order.produced = math.min(order.produced + self.today.excess_food, order.amount)
                local amount_taken = order.produced - old_amount
                self.today.excess_food = self.today.excess_food - amount_taken
                if self.today.excess_food < 0 then
                    print(old_amount, amount_taken, self.today.excess_food)
                    panic()
                end
                if order.produced == order.amount then
                    return self:employeeFindTask(time, employee) -- start over, recursively, doing return to hopefully get TCO
                end
            end
            order.workers = order.workers + 1
            -- XXX make sure employees don't go home until they have done their work tasks
            local function make_food(time)
                employee.pending_events.work_task =
                    SCHEDULER:schedule(time + self.prod_time,
                    function(time)
                        order.produced = order.produced + 1
                        if order.produced < order.amount then
                            -- if there aren't enough made yet then keep making 'em
                            make_food(time)
                        else
                            -- otherwise find something else to do
                            order.workers = order.workers - 1
                            employee.pending_events.work_task = nil
                            if order.produced > order.amount then
                                self.today.excess_food = (self.today.excess_food or 0) + (order.produced - order.amount)
                                order.produced = order.amount
                            end
                            self:employeeFindTask(time, employee)
                        end
                    end
                )
            end
            make_food(time)
            break -- this employee shouldn't do anything else now
        elseif order.produced >= order.amount then
            if order.produced > order.amount then
                LOGGER:log(("Warning: Caterer %s produced %d instead of %d units of food for %s")
                          :format(self.name, order.produced, order.amount, company.name),
                           LOG_LEVELS.warn)
            end
            table.insert(completed_orders, company)
            company:deliveryArrival(time, 'catering', self, order.produced)
        end
    end

    for _,company in ipairs(completed_orders) do
        self.orders[company] = nil
    end
end

return CateringCompany
