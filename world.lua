local class = require "middleclass"
local mos   = require "moses"

local names = require "names"

local TIME = require 'TIME'

local CHARSETS = require 'CHARSETS'

local Logger = require 'logger'
LOGGER = Logger:new(LOG_LEVELS.info)

local Scheduler = require 'scheduler'
SCHEDULER = Scheduler:new()

local Government = require 'government'

local Bank = require 'bank'

local Person = require 'person'

local Company = require 'company'

function MakeTestWorld()
    local govt = Government:new("One World Govt")

    local boe  = Bank:new(govt, "Bank of E")
    local cap  = Bank:new(govt, "Capitalism Inc")
    local meg  = Bank:new(govt, "Megabank")

    local vd   = Company:new(govt, "Viridian Dynamics")
    local md   = Company:new(govt, "Massive Dynamic")
    local tc   = Company:new(govt, "Tyrell Corporation")
    local ec   = Company:new(govt, "E Corp")

    local p    = mos.times(10, function() local p=Person:new(govt) end)

    return {govt,boe,cap,meg,vd,md,tc,ec,p}
end

w=MakeTestWorld()

for year=1,50 do
    local last=SCHEDULER:run(SCHEDULER.time + TIME.year)
    if last then
        print("Out of events at "..last)
    end
    
    local f = io.open(SCHEDULER.time.."_acc_summary",'w')
    f:write("Account summaries for t="..SCHEDULER.time..'\n')
    for _,bank in ipairs(w[1].banks) do
        for id,account in pairs(bank.accounts) do
            f:write(("-> %s  %d  %s %d\n")
                    :format(bank.name,
                            id,
                            account.owner.name,
                            account.balance))
        end
    end
    f:close()
        
    if SCHEDULER.time/TIME.year % 4 == 0 then
        os.execute("rm dots/*.dot")
        for _,person in ipairs(w[1].people) do
            person:dumpDOT("dots/"..SCHEDULER.time..'_')
        end
        local tree_filename = SCHEDULER.time..'_fam_tree.png'
        os.execute('cat dots/*.dot | sort | uniq | sed -e "/.*digraph.*/d" | tail -n+2 | cat dot_prefix - dot_postfix | dot -Tpng > '..tree_filename)
        print("Wrote " ..tree_filename)
    end
end
