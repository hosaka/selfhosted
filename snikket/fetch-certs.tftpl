#!/usr/bin/lua
-- Copies the Snikket certificates from Caddy into the layout Prosody imports from.
-- run-parts starts refresh-certs after this script, which imports them and reloads Prosody.
local http = require "socket.http"

local function fetch(url)
  local body, code = http.request(url)
  if code ~= 200 then
    error(url .. ": " .. tostring(code))
  end
  assert(body:find("^%-%-%-%-%-BEGIN"), url .. ": not a PEM file")
  return body
end

for _, name in ipairs({ ${names} }) do
  local files = {
    ["fullchain.pem"] = fetch("${caddy}/" .. name .. "/" .. name .. ".crt"),
    ["privkey.pem"] = fetch("${caddy}/" .. name .. "/" .. name .. ".key"),
  }

  local dir = "/snikket/letsencrypt/live/" .. name
  assert(os.execute("mkdir -p " .. dir))
  for file, content in pairs(files) do
    local tmp = dir .. "/." .. file
    local f = assert(io.open(tmp, "w"))
    assert(os.execute("chmod 600 " .. tmp))
    assert(f:write(content))
    f:close()
    -- replaces the symlinks certbot left behind as well
    assert(os.rename(tmp, dir .. "/" .. file))
  end
end
