local mos = require 'moses'

local genutils = require 'genutils'

local function CreateMoneypit(govt)
    local moneypit = {name="Moneypit for debugging"}
    local bank = mos.sample(govt.banks)[1]
    local password = genutils.newPassword(6,1)
    local account = bank:register(password, moneypit)
    moneypit.finance = {account}

    return moneypit
end

return CreateMoneypit
