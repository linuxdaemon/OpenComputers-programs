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
local repo = args[1]
local localDir

local function initDir()
  local dir
  if #args > 1 then
    dir = args[2]
  else
    local i = repo:find("/")
    dir = repo:sub(i+1)
  end
  localDir = shell.resolve(dir)
  local gitdir = fs.concat(localDir, ".git")
  if not fs.exists(gitdir) then
    fs.makeDirectory(gitdir)
  end
  local f = io.open(fs.concat(gitdir, "remote"), "w")
  f:write(repo .. "\n")
  f:close()
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

local function downloadBlob(path, from)
  local req = inet.request(from, nil, BASE_HEADERS)
  local res, msg, headers, blob_resp = readReq(req)
  local blobjson = JSON:decode(blob_resp)
  local f = io.open(fs.concat(localDir, path), "w")
  local s = data.decode64(blobjson.content)
  f:write(s)
  f:close()
end

local function getFiles()
  local commit_req = inet.request(API_URL.."/repos/"..repo.."/commits", nil, BASE_HEADERS)
  local res, msg, headers, commit_resp = readReq(commit_req)
  if not(res == 200) then
    error(res.." "..msg)
  end
  local commitsJson = JSON:decode(commit_resp)

  local treeurl = commitsJson[1].commit.tree.url
  local treereq = inet.request(treeurl.."?recursive=1", nil, BASE_HEADERS)
  local res, msg, headers, tree_resp = readReq(treereq)
  local treejson = JSON:decode(tree_resp)
  for _,obj in ipairs(treejson.tree) do
    if obj.type == "blob" then
      print("Downloading: " .. obj.path)
      downloadBlob(obj.path, obj.url)
    else
      fs.makeDirectory(fs.concat(localDir, obj.path))
    end
  end
end

initDir()
getFiles()
