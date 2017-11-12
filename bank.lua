local class = require "middleclass"

local genutils = require "genutils"

local Bank = class('Bank')

function Bank:initialize(govt, name)
    self.name       = name
    self.accounts   = {}
    self.government = govt
    table.insert(govt.banks, self)
end

function Bank:register(password, owner)
    local new_uid
    repeat
        new_uid = genutils.newUID(8)
    until self.accounts[new_uid] == nil
    self.accounts[new_uid] = {password=password,
                              balance=0,
                              owner=owner}
    return new_uid
end

function Bank:getBalance(uid, password)
    local acc = self.accounts[uid]
    if (not acc) or (acc.password ~= password) then
        return nil,'bad-auth'
    else
        return acc.balance
    end
end

function Bank:send(uid, password, amount, otherbank, otheruid)
    local acc = self.accounts[uid]
    if (not acc) or (acc.password ~= password) then
        return nil,'bad-auth'
    elseif (acc.balance < amount) then
        return nil,'insuff-funds'
    else
        local result, err = otherbank:receive(otheruid,amount, self, uid)
        if not result then
            return nil,'dest-'..err
        else
            acc.balance = acc.balance - amount
            LOGGER:log(("%s %d sent %d to %s %d")
                              :format(self.name,uid,amount,otherbank.name,otheruid),
                              LOG_LEVELS.verbose)
            return true
        end
    end
end

function Bank:receive(uid, amount, frombank, fromuid)
    local acc = self.accounts[uid]
    if (not acc) then
        return nil,'no-such-acc'
    else
        acc.balance = acc.balance + amount
        LOGGER:log(("%s %d received %d from %s %d")
                          :format(self.name,uid,amount,frombank.name,fromuid),
                          LOG_LEVELS.verbose)
        return true
    end
end

return Bank
