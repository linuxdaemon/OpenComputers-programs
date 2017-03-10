local JSON = require("JSON")
local component = require("component")
local fs = require("filesystem")
local term = require("term")
local shell = require("shell")

local inet = component.getPrimary("internet")
local data = component.getPrimary("data")

local config = {}

local API_URL = "https://api.github.com"
local BASE_HEADERS = {
  ["User-Agent"] = "OpenComputers"
}

local args = {...}
local remote = nil
local workingDir = nil
local gitdir = nil
local rateLimit = {
  remaining=1
}

local function authPrompt()
  local auth = {}
  local authtype = ""
  repeat
    io.stdout:write("Auth method[basic/oauth]: ")
    authtype = term.read()
  until authtype:lower() == "basic" or authtype:lower() == "oauth"
  if authtype:lower() == "basic" or authtype:lower() == "oauth" then
    auth.type = authtype:lower()
  end
  if auth.type == "basic" then
    io.stdout:write("Username: ")
    auth.username = term.read()
    io.stdout:write("Password: ")
    auth.pass = term.read()
  elseif auth.type == "oauth" then
    io.stdout:write("Token: ")
    auth.token = term.read()
  end
  config.api_auth = auth
end

local function tableSer(tbl, depth)
  local depth = depth or 1
  local indentWidth = 1
  local s = "{\n"
  for k,v in pairs(tbl) do
    s = s .. string.rep(" ", depth * indentWidth) .. k .. " = "
    if type(v) == "table" then
      s = s .. tableSer(v, depth + 1)
    elseif type(v) == "string" then
      s = s .. '"' .. v .. '"'
    else
      s = s .. tostring(v)
    end
    s = s .. ",\n"
  end
  s = s:sub(1,s:len()-2) .. "\n"
  s = s .. string.rep(" ", (depth - 1) * indentWidth) .. "}"
  return s
end

local function saveConfig(path)
  local s = tableSer(config)
  s = "return " .. s
  local f = io.open(path, "w")
  f:write(s)
  f:close()
end

local function loadConfig()
  local configPath = "/home/.gitconfig/config.lua"
  if not fs.exists(configPath) then
    authPrompt()
    saveConfig(configPath)
  end
  config = dofile(configPath)
  if config.api_auth then
    if config.api_auth.type == "basic" then
      BASE_HEADERS["Authorization"] = "basic " .. data.encode64(config.api_auth.username + ":" + config.api_auth.password)
    elseif config.api_auth.type == "oauth" then
      -- TODO add oauth handling
    end
  end
end

local function readReq(req)
  local data = ""
  while true do
    local chunk, reason = req.read()
    if not chunk then
      req.close()
      if reason then
        error(reason)
      else
        break
      end
    else
      data = data .. chunk
    end
  end
  local res, msg, headers = req.response()
  return res, msg, headers, data
end

local function readFile(path)
  local f = io.open(path)
  local s = f:read("*a")
  f:close()
  return s
end

local function writeFile(path, content)
  local f = io.open(path, "w")
  f:write(content.."\n")
  f:close()
end

local function apiReq(path)
  if rateLimit.remaining < 1 then
    io.stderr:write("No requests remaining,\nLimnit resets at " .. tostring(rateLimit.reset) .. " unix epoch time (UTC)\n")
    os.exit(1)
  end
  local req = inet.request(API_URL..path, nil, BASE_HEADERS)
  local res, msg, headers, resp = readReq(req)
  if not(res == 200) then
    error(res.." "..msg)
  end
  if headers["X-RateLimit-Limit"] and headers["X-RateLimit-Remaining"] and headers["X-RateLimit-Reset"] then
    rateLimit = {
      limit=tonumber(headers["X-RateLimit-Limit"][1]),
      remaining=tonumber(headers["X-RateLimit-Remaining"][1]),
      reset=tonumber(headers["X-RateLimit-Reset"][1])
    }
  end
  return JSON:decode(resp)
end

local function downloadRaw(path, url)
  local rawreq = inet.request(url, nil, BASE_HEADERS)
  local res, msg, headers, resp = readReq(rawreq)
  if not(res == 200) then
    error(res.." "..msg)
  end
  if resp then
    local f,err = io.open(fs.concat(workingDir, path), "w")
    if not f then error(err) end
    f:write(resp)
    f:close()
  else
    error("nil response")
  end
end

local function downloadBlob(path, from)
  local blobreq = inet.request(from, nil, BASE_HEADERS)
  local res, msg, headers, resp = readReq(blobreq)
  if not(res == 200) then
    error(res.." "..msg)
  end
  local blobjson = JSON:decode(resp)
  local f = io.open(fs.concat(workingDir, path), "w")
  local s = data.decode64(blobjson.content)
  f:write(s)
  f:close()
end

local function checkRateLimit()
  local json = apiReq("/rate_limit")
  rateLimit = json.resources.core
end

local function getCommits()
  return apiReq("/repos/"..remote.."/commits")
end

local function update()
  workingDir = shell.resolve(".")
  gitdir = fs.concat(workingDir, ".git")
  if not fs.exists(gitdir) then
    io.stderr:write("This does not appear to be a git repository")
    os.exit(1)
  end
  local remoteFile = fs.concat(gitdir, "remote")
  local commitFile = fs.concat(gitdir, "commit")
  if not fs.exists(remoteFile) and fs.exists(commitFile) then
    io.stderr:write("Repository information appears incomplete")
    os.exit(1)
  end
  remote = readFile(remoteFile):gsub("[\n]+$", "")
  local lastCommit = readFile(commitFile):gsub("[\n]+$", "")
  local commits = getCommits()
  local newestCommit = commits[1].sha
  local compare = apiReq("/repos/"..remote.."/compare/"..lastCommit.."..."..newestCommit)
  local files = compare.files
  for _,file in ipairs(files) do
    local path = file.filename
    if file.status == "added" or file.status == "modified" then
      local dir = fs.path(path)
      if not dir == "" then
        fs.makeDirectory(fs.concat(workingDir, dir))
      end
      print("Updating " .. path .. "...")
      downloadRaw(path, file.raw_url)
    elseif file.status == "removed" then
      print("Deleting " .. path .. "...")
      fs.remove(fs.concat(workingDir, path))
    end
  end
  writeFile(fs.concat(gitdir, "commit"), newestCommit)
end

local function clone()
  if #args == 0 then
    print("Please specify a GitHub repository in the form user/repo")
    os.exit(0)
  end
  remote = args[1]
  local dir
  if #args > 1 then
    dir = args[2]
  else
    local i = repo:find("/")
    dir = repo:sub(i+1)
  end
  workingDir = shell.resolve(dir)
  if fs.exists(workingDir) then
    io.stderr:write("Directory exists, not cloning\n")
    os.exit(1)
  end
  gitdir = fs.concat(workingDir, ".git")
  fs.makeDirectory(gitdir)
  writeFile(fs.concat(gitdir, "remote"), remote)
  local commits = getCommits()
  local commit = commits[1]
  writeFile(fs.concat(gitdir, "commit"), commit.sha)
  local treejson = apiReq(commit.commit.tree.url.."?recursive=1")
  for _,obj in ipairs(treejson.tree) do
    if obj.type == "blob" then
      print("Downloading: " .. obj.path)
      downloadBlob(obj.path, obj.url)
    else
      fs.makeDirectory(fs.concat(workingDir, obj.path))
    end
  end
end

local function main()
  local cmd = args[1]
  table.remove(args, 1)
  checkRateLimit()
  if cmd == "pull" then
    update()
  elseif cmd == "clone" then
    clone()
  end
end

main()
