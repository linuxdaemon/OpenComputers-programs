local JSON = require("JSON")
local component = require("component")
local fs = require("filesystem")
local shell = require("shell")

local inet = component.getPrimary("internet")
local data = component.getPrimary("data")

local config = dofile("/home/.gitconfig/config.lua")

local API_URL = "https://api.github.com"
local BASE_HEADERS = {
  ["Authorization"] = config.api_auth,
  ["User-Agent"] = "OpenComputers"
}

local args = {...}
local remote = nil
local workingDir
local gitdir
local rateLimit = {
  remaining=1
}

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

local function downloadBlob(path, from)
  local apiPath = from:gsub("^https?://api.github.com", "")
  local blobjson = apiReq(apiPath)
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
  local files = compare.filesystem
  for _,file in ipairs(files) do
    local path = file.filename
    if file.status == "added" or file.status == "modified" then
      local dir = fs.path(path)
      if not dir == "" then
        fs.makeDirectory(fs.concat(workingDir, dir))
      end
      print("Updating " .. path .. "...")
      downloadBlob(fs.concat(workingDir, path), file.blob_url)
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
  local commit = commitsJson[1]
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
