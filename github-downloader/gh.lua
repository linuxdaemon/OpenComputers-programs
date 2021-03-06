local JSON = nil
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
local rateLimit = {
  remaining = 1
}

local function error_exit(...)
  io.stderr:write(..., "\n")
  os.exit(1)
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

local function downloadFile(url, path)
  local req = inet.request(url, nil, BASE_HEADERS)
  local res, msg, headers, resp = readReq(req)
  if not(res == 200) then
    error(res.." "..msg)
  end
  if resp then
    local parentDirs = fs.path(path)
    if #parentDirs > 0 then
      fs.makeDirectory(parentDirs)
    end
    local f, err = io.open(path, "w")
    if not f then error(err) end
    f:write(resp)
    f:close()
  else
    error("nil response")
  end
end

local function getDep(url, name)
  local dep = nil
  local res, err = pcall(function() dep = require(name) end)
  if not res then
    print("Downloading libs...")
    downloadFile(url, "/home/lib/"..name..".lua")
    local res, err = pcall(function() dep = require(name) end)
    if not res then
      error(err)
    end
  end
  return dep
end

local function checkDeps()
  JSON = getDep("http://regex.info/code/JSON.lua", "JSON")
end

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
    error_exit("No requests remaining,\nLimnit resets at ", rateLimit.reset, " unix epoch time (UTC)")
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

local function downloadRaw(base_dir, path, url)
  downloadFile(url, fs.concat(base_dir, path))
end

local function downloadBlob(base_dir, path, from)
  local blobreq = inet.request(from, nil, BASE_HEADERS)
  local res, msg, headers, resp = readReq(blobreq)
  if not(res == 200) then
    error(res.." "..msg)
  end
  local blobjson = JSON:decode(resp)
  local f = io.open(fs.concat(base_dir, path), "w")
  local s = data.decode64(blobjson.content)
  f:write(s)
  f:close()
end

local function checkRateLimit()
  local json = apiReq("/rate_limit")
  rateLimit = json.resources.core
end

local function getCommits(remote)
  return apiReq("/repos/"..remote.."/commits")
end

local function update()
  local workingDir = shell.resolve(".")
  local gitdir = fs.concat(workingDir, ".git")
  while not fs.exists(gitdir) do
    if workingDir == "/" then
      error_exit("This does not appear to be a git repository")
    end
    workingDir = shell.resolve(fs.concat(workingDir, ".."))
    gitdir = fs.concat(workingDir, ".git")
  end
  local remoteFile = fs.concat(gitdir, "remote")
  local commitFile = fs.concat(gitdir, "commit")
  if not fs.exists(remoteFile) and fs.exists(commitFile) then
    error_exit("Repository information appears incomplete")
  end
  local remote = readFile(remoteFile):gsub("[\n]+$", "")
  local lastCommit = readFile(commitFile):gsub("[\n]+$", "")
  local commits = getCommits(remote)
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
      downloadRaw(workingDir, path, file.raw_url)
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
  local remote = args[1]
  local dir
  if #args > 1 then
    dir = args[2]
  else
    local i = remote:find("/")
    dir = remote:sub(i+1)
  end
  local workingDir = shell.resolve(dir)
  if fs.exists(workingDir) then
    error_exit("Directory exists, not cloning")
  end
  local gitdir = fs.concat(workingDir, ".git")
  fs.makeDirectory(gitdir)
  writeFile(fs.concat(gitdir, "remote"), remote)
  local commits = getCommits(remote)
  local commit = commits[1]
  writeFile(fs.concat(gitdir, "commit"), commit.sha)
  local url = commit.commit.tree.url.."?recursive=1"
  url = url:gsub("^https?://[^/]+", "")
  local treejson = apiReq(url)
  for _, obj in ipairs(treejson.tree) do
    if obj.type == "blob" then
      print("Downloading: " .. obj.path)
      downloadBlob(workingDir, obj.path, obj.url)
    else
      fs.makeDirectory(fs.concat(workingDir, obj.path))
    end
  end
end

local function main()
  checkDeps()
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
