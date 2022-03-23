-------------------------------------------------------------------
-- AIRDROP CONTRACT - DIFFERENT AMOUNT FOR EACH
-------------------------------------------------------------------

airdrop_diff_amount = [[

state.var {
  recipients = state.map()
}

creator = "%creator_address%"
token_address = "%token_address%"

local function _typecheck(x, t)
  if (x and t == 'address') then -- a string of alphanumeric char. except for '0, I, O, l'
    assert(type(x) == 'string', "AirDrop: address must be string type")
    assert(#x == 52, string.format("AirDrop: invalid address length: %s (%s)", x, #x))
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(nil == invalidChar, string.format("AirDrop: invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'str_ubig') then   -- a positive big number in string format
    assert(type(x) == 'string', "AirDrop: amount must be string")
    assert(string.match(x, '[^0-9]') == nil, "AirDrop: amount contains invalid character")
    x = bignum.number(x)
    assert(x >= bignum.number(0), string.format("AirDrop: %s must be positive number", bignum.tostring(x)))
  else
    assert(type(x) == t, string.format("AirDrop: invalid type: %s != %s", type(x), t or 'nil'))
  end
end

function add_recipients(list)

  assert(system.getSender() == creator, "permission denied")

  for address,amount in pairs(list) do
    _typecheck(address, "address")
    _typecheck(amount, "str_ubig")
    recipients[address] = amount
  end

end

function token()
  return token_address  
end

function has_tokens(address)
  _typecheck(address, "address")
  return recipients[address]
end

function withdraw()

  local address = system.getSender()
  local amount = recipients[address]
  if amount ~= nil then
    amount = bignum.number(amount)
  end
  assert(amount ~= nil and amount > bignum.number(0), "no amount to withdraw")

  -- update state before external call to avoid re-entrancy attack
  recipients[address] = nil

  -- transfer tokens to the requester
  contract.call(token_address, "transfer", address, amount)

end

function tokensReceived(operator, from, amount, ...)
  -- used to receive tokens from the contract
end

abi.register(add_recipients, withdraw, tokensReceived)
abi.register_view(token, has_tokens)
]]

-------------------------------------------------------------------
-- AIRDROP CONTRACT - SAME AMOUNT FOR ALL
-------------------------------------------------------------------

airdrop_same_amount = [[

state.var {
  recipients = state.map()
}

creator = "%creator_address%"
token_address = "%token_address%"
withdraw_amount = "%withdraw_amount%"

local function _typecheck(x, t)
  if (x and t == 'address') then -- a string of alphanumeric char. except for '0, I, O, l'
    assert(type(x) == 'string', "AirDrop: address must be string type")
    assert(#x == 52, string.format("AirDrop: invalid address length: %s (%s)", x, #x))
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(nil == invalidChar, string.format("AirDrop: invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'str_ubig') then   -- a positive big number in string format
    assert(type(x) == 'string', "AirDrop: amount must be string")
    assert(string.match(x, '[^0-9]') == nil, "AirDrop: amount contains invalid character")
    x = bignum.number(x)
    assert(x >= bignum.number(0), string.format("AirDrop: %s must be positive number", bignum.tostring(x)))
  else
    assert(type(x) == t, string.format("AirDrop: invalid type: %s != %s", type(x), t or 'nil'))
  end
end

function add_recipients(list)

  assert(system.getSender() == creator, "permission denied")

  for _,address in ipairs(list) do
    _typecheck(address, "address")
    recipients[address] = true
  end

end

function token()
  return token_address  
end

function has_tokens(address)
  _typecheck(address, "address")
  if recipients[address] == true then
    return withdraw_amount
  else
    return nil
  end
end

function withdraw()

  local address = system.getSender()
  assert(recipients[address] == true, "no amount to withdraw")

  -- update state before external call to avoid re-entrancy attack
  recipients[address] = nil

  -- transfer tokens to the requester
  contract.call(token_address, "transfer", address, withdraw_amount)

end

function tokensReceived(operator, from, amount, ...)
  -- used to receive tokens from the contract
end

abi.register(add_recipients, withdraw, tokensReceived)
abi.register_view(token, has_tokens)
]]

-------------------------------------------------------------------
-- FACTORY
-------------------------------------------------------------------

state.var {
  _num_airdrops = state.value(),
  _airdrops = state.map()
}

local function _typecheck(x, t)
  if (x and t == 'address') then -- a string of alphanumeric char. except for '0, I, O, l'
    assert(type(x) == 'string', "AirDrop: address must be string type")
    assert(#x == 52, string.format("AirDrop: invalid address length: %s (%s)", x, #x))
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(nil == invalidChar, string.format("AirDrop: invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'str_ubig') then   -- a positive big number in string format
    assert(type(x) == 'string', "AirDrop: amount must be string")
    assert(string.match(x, '[^0-9]') == nil, "AirDrop: amount contains invalid character")
    x = bignum.number(x)
    assert(x >= bignum.number(0), string.format("AirDrop: %s must be positive number", bignum.tostring(x)))
  else
    assert(type(x) == t, string.format("AirDrop: invalid type: %s != %s", type(x), t or 'nil'))
  end
end

function new_airdrop(owner, token, airdrop_type, amount)
  _typecheck(token, "address")

  if owner == nil or owner == '' then
    owner = system.getSender()
  else
    _typecheck(owner, "address")
  end

  -- check if it is an ARC1 token - discard the result
  local result = contract.call(token, "arc1_extensions")

  local contract_code

  if airdrop_type == "same" then
    _typecheck(amount, "str_ubig")
    contract_code = airdrop_same_amount
    contract_code = string.gsub(contract_code, "%%withdraw_amount%%", amount)
  elseif airdrop_type == "diff" then
    contract_code = airdrop_diff_amount
  else
    assert(false, "invalid airdrop type: '" .. airdrop_type .. "'")
  end

  contract_code = string.gsub(contract_code, "%%creator_address%%", owner)
  contract_code = string.gsub(contract_code, "%%token_address%%", token)

  local address = contract.deploy(contract_code)

  local num_airdrops = (_num_airdrops:get() or 0) + 1
  _num_airdrops:set(num_airdrops)
  _airdrops[tostring(num_airdrops)] = address

  contract.event("new_airdrop", address)

  return address
end

function list_airdrops(first, size)

  if first == nil or first == 0 then
    first = 1
  end
  if size == nil or size == 0 then
    size = 100
  end
  local last = first + size - 1

  local list = {}

  for n = first,last do
    local address = _airdrops[tostring(n)]
    if address == nil then break end
    list[#list + 1] = address
  end

  return list
end

function has_tokens(account, first, size)

  if first == nil or first == 0 then
    first = 1
  end
  if size == nil or size == 0 then
    size = 100
  end
  local last = first + size - 1

  local num_airdrops = _num_airdrops:get() or 0
  if first > num_airdrops then
    return nil
  end

  local list = {}

  for n = first,last do
    local address = _airdrops[tostring(n)]
    if address == nil then break end
    local amount = contract.call(address, "has_tokens", account)
    if amount ~= nil then
      local token = contract.call(address, "token")
      local name = contract.call(token, "name")
      local symbol = contract.call(token, "symbol")
      local decimals = contract.call(token, "decimals")
      -- list[#list + 1] = {address, amount, name, symbol, decimals}
      local item = {
        address = address,
        amount = amount,
        name = name,
        symbol = symbol,
        decimals = decimals
      }
      list[#list + 1] = item
    end
  end

  return list
end

abi.register(new_airdrop)
abi.register_view(list_airdrops, has_tokens)
