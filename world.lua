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
local CateringCompany = require 'cateringcompany'

local CreateMoneypit = require 'moneypit'

MONEYPIT = true
function MakeTestWorld()
    local govt = Government:new("One World Govt")

    local boe  = Bank:new(govt, "Bank of E")
    local cap  = Bank:new(govt, "Capitalism Inc")
    local meg  = Bank:new(govt, "Megabank")

    MONEYPIT = CreateMoneypit(govt)

    local vd   = Company:new(govt, "Viridian Dynamics")
    local dl   = Company:new(govt, "Downlink Corporation")
    local is   = Company:new(govt, "Infinity Solutions")
    local ld   = Company:new(govt, "Lattice Design")
    ld.wage    = 40
    ld.pay_policy = 'wage'
    local tc   = Company:new(govt, "Tyrell Corporation")
    local ec   = Company:new(govt, "E Corp")
    ec.reserve = 0.3

    local mj     = CateringCompany:new(govt, "MacJack's")
    mj.food_cost = 10
    mj.wage      = 12
    mj.margin    = 4
    local rw   = CateringCompany:new(govt, "Red Wheelbarrow")
    rw.wage    = 25
    rw.margin  = 3.15
    local dc      = CateringCompany:new(govt, "The Dead Cow")
    dc.pay_policy = 'fairshare'

    local p    = mos.times(100, function() local p=Person:new(govt) end)

    return {govt,p}
end

w=MakeTestWorld()

for year=1,50 do
    local last=SCHEDULER:run(SCHEDULER.time + TIME.year)
    if last then
        print("Out of events at "..last)
    end
        
    if year % 4 == 0 then
        --[[
        local f = io.open(SCHEDULER.time.."_acc_summary",'w')
        f:write("Account summaries for t="..SCHEDULER.time..'\n')
        for _,bank in ipairs(w[1].banks) do
            for id,account in pairs(bank.accounts) do
                f:write(("-> %s\t%d\t%s\t%d\n")
                        :format(account.owner.name,
                                account.balance,
                                bank.name,
                                id))
            end
        end
        f:close()
        ]]--

        -- --[[
        os.execute("rm dots/*.dot")
        for _,person in ipairs(w[1].people) do
            person:dumpDOT("dots/"..SCHEDULER.time..'_')
        end
        local tree_filename = SCHEDULER.time..'_fam_tree.png'
        os.execute('cat dots/*.dot | sort | uniq | sed -e "/.*digraph.*/d" | tail -n+2 | cat dot_prefix - dot_postfix | dot -Tpng > '..tree_filename)
        print("Wrote " ..tree_filename)
        
        
        os.execute("rm dots/*.dot")
        w[1]:dumpCompanyDOT("dots/"..SCHEDULER.time)
        tree_filename = SCHEDULER.time.."_comp_tree.png"
        os.execute('dot -Tpng < dots/'..SCHEDULER.time..'_comp.dot > '..tree_filename)
        -- ]]--
    end
end
