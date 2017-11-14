-- "Government" is really just a collection of people/banks/companies managed
-- as a unit; later, currency value will depend on how entities within a govt
-- interact.

local class = require "middleclass"
local mos   = require 'moses'

local TIME = require 'TIME'
local Person = require 'person'

local Government = class('Government')

function Government:initialize(name)
    self.name         = name
    self.tot_currency = 0
    -- List of people organised by this government
    self.people       = {}
    -- List of banks within this government
    self.banks        = {}
    -- List of companies within this government
    self.companies    = {}
    -- List of companies within this government organised by industry
    self.industries   = {}

    local bd_lambda = true -- value must exist to be used from itself
    bd_lambda = function(time)
        self:birthDeathProcess(time)
        SCHEDULER:schedule(time+TIME.week, bd_lambda)
    end

    SCHEDULER:schedule(SCHEDULER.time+TIME.week, bd_lambda)
end

function Government:birthDeathProcess(time)
    LOGGER:log("Running birthDeathProcess", LOG_LEVELS.verbose)

    -- Find potential heterosexual relationships between people in this govt
    -- For the sake of this simulation, intersex relationships are considered
    -- hetero if it is functionally possible for them to produce a child.
    -- Gender identity is not (yet) modelled.
    local possible = mos.groupBy(self.people,
        function(id, person)
            if person.age < 18 or (not person.fertile[1]) then
                return 'cannot'
            elseif person.relationship then
                return 'taken'
            elseif person.sex.m      and
                   person.sex_pref.f then
                return 'm'
            elseif person.sex.f      and
                   person.sex_pref.m then
                return 'f'
            elseif person.sex.f then
                return 'homof'
            elseif person.sex.m then
                return 'homom'
            end
        end)

    local taken = possible.taken or {}
    
    if (not possible.m) or (not possible.f) then
        LOGGER:log(("-> There are no possible hetero partners"):format(n_partners), LOG_LEVELS.verbose)
    else
        local n_partners = math.min(#possible.m, #possible.f)
        LOGGER:log(("-> There are %d possible hetero partners"):format(n_partners), LOG_LEVELS.verbose)
        
        local male, female = mos.sample(possible.m)[1], mos.sample(possible.f)[1]
        LOGGER:log(("-> %s and %s are now in a hetero relationship"):format(male.name, female.name), LOG_LEVELS.verbose)
        female.relationship = {'hetero',male}
        male.relationship   = {'with', female}

        table.insert(taken, female)
    end
    
    if possible.homof and #possible.homof >= 2 then
        local homo = mos.sample(possible.homof, 2)
        LOGGER:log(("-> %s and %s are now in a homo relationship")
                  :format(homo[1].name, homo[2].name), LOG_LEVELS.verbose)
        homo[1].relationship = {'homo', homo[2]}
        homo[2].relationship = {'with', homo[1]}
        table.insert(taken, homo[1])
    else
        LOGGER:log("-> There are no possible female homo partners", LOG_LEVELS.verbose)
    end
    if possible.homom and #possible.homom >= 2 then
        local homo = mos.sample(possible.homom, 2)
        LOGGER:log(("-> %s and %s are now in a homo relationship")
                  :format(homo[1].name, homo[2].name), LOG_LEVELS.verbose)
        homo[1].relationship = {'homo', homo[2]}
        homo[2].relationship = {'with', homo[1]}
        table.insert(taken, homo[1])
    else
        LOGGER:log("-> There are no possible male homo partners", LOG_LEVELS.verbose)
    end
    
    for _,p in pairs(taken) do
        if p.relationship[1] == 'hetero' then
            p:hetero_relationship(time)
        elseif p.relationship[1] == 'homo' then
            p:homo_relationship(time)
        end
    end
end

function Government:dumpCompanyDOT(prefix)
    prefix = prefix or ""
    local filename = prefix..'_comp.dot'
    local f = io.open(filename, 'w')
    if not f then
        print("Failed to open " .. filename)
        return
    end
    f:write('digraph "'..tostring(self.name)..'"{\nrankdir = "LR"\n')

    local now = SCHEDULER.time
    for _, c in pairs(self.companies) do
        f:write('subgraph "cluster_'..tostring(c.name)..'"{\n')
        f:write(('"%s" [label="%s\\n%d employees\\n$%0.02d",shape=box]\n')
            :format(c.name, c.name, #c.employees, c.finance[1].balance or 0))
        for _, e in pairs(c.employees) do
            f:write(('"%s" -> "%s"\n'):format(c.name, e.name))
            f:write(('"%s" [label="%s\\n$%0.02d\\nJoined %s (%d years)"]\n')
                    :format(e.name, e.name, e.finance[1].balance,
                    TIME.date_string(e.employment_time),
                    TIME.year_number(now - e.employment_time)))
        end
        f:write('}\n')
    end

    f:write('}\n')
    f:close()
end

return Government
