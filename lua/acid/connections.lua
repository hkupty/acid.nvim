-- luacheck: globals vim

--- low-level connection handler
-- @module acid.connections
local utils = require("acid.utils")

local connections = {
  store = {},
  current = {},
}

local pwd_to_key = function(pwd)
  if not utils.ends_with(pwd, "/") then
    return pwd .. "/"
  end
  return pwd
end

--- Stores connection for reuse later
-- @tparam {string,string} addr Address tuple with ip and port.
connections.add = function(addr)
  local ulid = utils.ulid()
  connections.store[ulid] = addr
  return ulid
end

connections.remove = function(key)
  -- Remove all addresses that point to id
  for ix, v in pairs(connections.current) do
    if v == key then
      connections.current[ix] = nil
    end
  end

  connections.store[key] = nil
end

--- Elects selected connection as primary (thus default) for a certain address
-- @tparam string pwd path (usually project root).
-- Assumed to be neovim's `pwd`.
-- @tparam int ix index of the stored connection
connections.select = function(pwd, ix)
  pwd = pwd_to_key(pwd)

  connections.current[pwd] = ix
end

--- Dissociates the connection for the given path
-- @tparam string pwd path (usually project root).
connections.unselect = function(pwd)
  pwd = pwd_to_key(pwd)

  connections.current[pwd] = nil
end

--- Return active connection for the given path
-- @tparam[opt] string pwd path (usually project root).
-- @treturn string Id of the current connection for the path or nil.
connections.peek = function(pwd)
  pwd = pwd_to_key(pwd or vim.fn.getcwd())
  return connections.current[pwd]
end

--- Return active connection for the given path
-- @tparam string pwd path (usually project root).
-- @treturn {string,string} Connection tuple with ip and port or nil.
connections.get = function(pwd)
  local ix = connections.peek(pwd)

  if ix == nil then
    return nil
  end

  return connections.store[ix]
end

connections.search = function(pwd)
  pwd = pwd_to_key(pwd)
  local fpath = vim.fn.findfile(pwd .. ".nrepl-port")
  if fpath ~= "" then
    local portno = table.concat(vim.fn.readfile(fpath), "")
    local conn = {"127.0.0.1", utils.trim(portno)}
    return connections.add(conn)
  end
  return nil
end

connections.reverse_lookup = function(conn)
  for k, v in pairs(connections.store) do
    if v[2] == conn[2] and v[1] == conn[1] then
      return k
    end
  end

  return nil
end

connections.attempt_get = function(pwd)
  local conn = connections.get(pwd)
  if conn == nil then
    local ix = connections.search(pwd)
    if ix ~= nil then
      connections.select(pwd, ix)
      conn = connections.store[ix]
    else
      return nil
    end
  end
  return conn
end

--- Add and select the given connection for given path.
-- @tparam string pwd path (usually project root).
-- @tparam {string,string} addr tuple with ip and port or nil.
connections.set = function(pwd, addr)
  connections.select(pwd, connections.add(addr))
end

return connections
