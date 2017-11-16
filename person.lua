local class = require "middleclass"
local mos   = require 'moses'

local TIME = require 'TIME'
local Names = require 'names'
local genutils = require 'genutils'

local Person = class('Person')

Person.static.name_mt = {}
Person.static.name_mt.__call = function(self)
    return self.first .. ' ' .. self.last
end
Person.static.name_mt.__tostring = Person.static.name_mt.__call

function Person:initialize(govt, mother, father)
    -- register with govt
    self.government = govt
    table.insert(govt.people, self)

    -- set immutables
    local first,last = Names.randomName()
    self.age=-1
    
    if father then
        last = father.name.last
    elseif mother then
        last = mother.name.last
    else -- parent-less persons start at 16
        self.age=15
    end

    self.name={first=first, last=last}
    setmetatable(self.name, Person.name_mt)
    self.parents={m=mother or false, f=father or false}

    local sex = {}
    local rand = math.random()
    if rand < 0.5 then
        sex.f = true
    elseif rand > 0.98 then
        sex.f = true
        sex.m = true
    else
        sex.m = true
    end
    self.sex = sex

    LOGGER:log(("%s %s was born")
                      :format(self.name, self:sexSymbol()),
                      LOG_LEVELS.info)

    self.birth_time = SCHEDULER.time
    
    -- set mutables
    
    self.location='home'
    self.fertile={false,{immature=true}}

    -- events that should be cancelled if the Person dies
    self.pending_events = {}
    -- events that should be triggered if the Person dies
    self.death_triggers = {}
    
    -- schedule ageup and daily events
    local age_up_lambda = true
    age_up_lambda = function(time)
        self:ageUp(time)
        self.pending_events.age_up = SCHEDULER:schedule(time+TIME.year, age_up_lambda)
    end
    age_up_lambda(SCHEDULER.time)

    local daily_lambda = true
    daily_lambda = function(time)
        self:dailyEvents(time)
        self.pending_events.daily = SCHEDULER:schedule(time+TIME.day, daily_lambda)
    end
    self.pending_events.daily = SCHEDULER:schedule(
        TIME.tomorrow(SCHEDULER.time),
        daily_lambda)
end

function Person:dailyEvents(time)
    local employer = self.employer
    if employer and employer:isOpenOnDay(time) then
        SCHEDULER:schedule(TIME.today(time) + employer.open_time,
            function(time)
                if self.location == 'home' then
                    employer:employeeArrival(time, self)
                else
                    LOGGER:log(("%s was not at home when due for work and so did not go to work!")
                               :format(self.name()),
                               LOG_LEVEL.warn)
                end
            end)
    end
end

function Person:leaveWork(time)
    LOGGER:log(("%s has left work"):format(self.name()), LOG_LEVELS.verbose)
    self.location = 'home'
end

function Person:ageUp(time)
    self.age = self.age + 1
    if self.age > 1 then
        LOGGER:log(("It is %s's %dth birthday")
                          :format(self.name, self.age),
                          LOG_LEVELS.verbose)
    end

    if self.age == 16 then
        local govt = self.government
        local bank = mos.sample(govt.banks)[1]
        local password = genutils.newPassword(6,1)
        local account = bank:register(password, self)
        self.finance = {account}
        
        local company = mos.sample(self.government.companies)[1]
        company:employ(self)

        local rand = math.random()
        local a,b = false,false
        if rand < 0.6 then
            a = true
        elseif rand > 0.8 then
            a = true
            b = true
        else
            b = true
        end

        if self.sex.f then
            self.sex_pref = {m=a,f=b}
            self.pregnancies = 0
        else
            self.sex_pref = {f=a,m=b}
        end

        LOGGER:log(("%s %s %s men and %s women")
                   :format(self.name, self:sexSymbol(),
                          (self.sex_pref.m and "likes" or "doesn't like"),
                          (self.sex_pref.f and "likes" or "doesn't like")))
    end

    if self.age == 18 then
        self.fertile = {true,{}}    
    end 
end

function Person:sexSymbol(age)
    age = age or false
    return table.concat({'(',
        self.sex.f and 'F' or '',
        self.sex.m and 'M' or '',
        age and self.age or '',
    ')'})
end

function Person:dumpDOT(prefix)
    prefix = prefix or ""
    local filename = prefix..tostring(self.name)..'.dot'
    local f = io.open(filename, 'w')
    if not f then
        print("Failed to open " .. filename)
        return
    end
    f:write('digraph "'..tostring(self.name)..'"{\n')
    local trav = true
    trav = function(child)
        local mother,father = child.parents.m, child.parents.f
        local cname=tostring(child.name)..child:sexSymbol(true)
        local pnode="God"
        
        if mother and father then
            local mname = tostring(mother.name)..mother:sexSymbol(true)
            local fname = tostring(father.name)..father:sexSymbol(true)
            pnode = mname..fname
            f:write(('"%s" [label="",shape=diamond,height=.1,width=.1]'):format(pnode))
            f:write(('"%s" -> "%s" [color="red"]\n'):format(mname,pnode))
            f:write(('"%s" -> "%s" [color="blue"]\n'):format(fname,pnode))
            if mother.relationship and mother.relationship[2] == father then
                f:write(('"%s" -> "%s" [dir=none,color="green"]\n'):format(mname,fname))
            end
        end
        
        if child.relationship and (child.relationship[1] == 'homo') then
            local partner = child.relationship[2]
            local pname = tostring(partner.name)..partner:sexSymbol(true)
            f:write(('"%s" -> "%s" [dir=none,color="yellow"]\n'):format(cname,pname))
        end

        f:write(('"%s" -> "%s"\n'):format(pnode,cname))
        f:write(('"%s" [label="%s\\nBorn %s%s\\n$%.02d",shape=box]\n')
            :format(cname, cname, TIME.date_string(child.birth_time),
                    child.employer and "\\nWorks at "..child.employer.name or '',
                    child.employer and child.finance[1].balance or 0))
    end
    trav(self)
    f:write("}")

    f:close()
end

function Person.static.mother_recovery(mother)
    return function(time)
        mother.fertile[2].recovery = nil
        -- if there are any other reasons why the mother is not fertile then
        -- do not make her fertile again after pregnancy
        local other_reason = false
        for k,v in pairs(mother.fertile[2]) do
            if k then
                other_reason = true
                break
            end
        end
        if mother.pregnancies >= 2 and math.random() < 0.6 then
            other_reason=true
            mother.fertile[2].had_many = true
        end
        mother.fertile={not other_reason,mother.fertile[2]}
    end
end

function Person.static.pregnancy(govt, mother, father)
    return function(time)
        LOGGER:log(("%s is giving birth"):format(mother.name),
                   LOG_LEVELS.verbose)

        local person = Person:new(govt, mother, father)

        -- there is no longer an event to cancel on death
        mother.pending_events.pregnant = nil
        -- make fertile again after pregnancy
        mother.fertile[2].pregnant = nil
        mother.fertile[2].recovery = true
        SCHEDULER:schedule(
            time + math.random()*TIME.year,
            Person.mother_recovery(mother))
    end
end

function Person:breakup_recovery()
    return function(time)
        self.relationship = nil
        self.pending_events.breakup_recovery = nil
    end
end

function Person:hetero_relationship(time)
    local mother,father = self, self.relationship[2]
    local rand = math.random()
    if rand < 0.2 and mother.fertile[1] then
        -- conceive
        LOGGER:log(("%s is pregnant with %s's child"):format(
                    mother.name, father.name),
                    LOG_LEVELS.verbose)

        mother.fertile = {false,{pregnant=true}}
        mother.pregnancies = mother.pregnancies + 1
        mother.pending_events.pregnant = SCHEDULER:schedule(
            SCHEDULER.time + 40*TIME.week + (math.random()-0.5)*2*TIME.week, 
            Person.pregnancy(self.government, mother, father))
    elseif rand > 0.95 then
        -- break up
        LOGGER:log(("%s and %s have broken up"):format(mother.name, father.name), LOG_LEVELS.verbose)
        local relationship = {'broken-up'}
        mother.relationship = relationship
        father.relationship = relationship
        mother.pending_events.breakup_recovery = SCHEDULER:schedule(
            time + math.random() * 2 * TIME.week,
            mother:breakup_recovery())
        father.pending_events.breakup_recovery = SCHEDULER:schedule(
            time + math.random() * 2 * TIME.week,
            father:breakup_recovery())
    end
end

function Person:homo_relationship(time)
    local rand = math.random()
    local a, b = self, self.relationship[2]
    if rand > 0.95 then
        -- break up
        LOGGER:log(("%s and %s have broken up"):format(a.name, b.name), LOG_LEVELS.verbose)
        local relationship = {'broken-up'}
        a.relationship = relationship
        b.relationship = relationship
        a.pending_events.breakup_recovery = SCHEDULER:schedule(
            time + math.random() * 2 * TIME.week,
            a:breakup_recovery())
        b.pending_events.breakup_recovery = SCHEDULER:schedule(
            time + math.random() * 2 * TIME.week,
            b:breakup_recovery())
    end
end

return Person
