local internet = require("internet")
local serialization = require("serialization")

local string_util = {
    startswith = function(s, ...)
        local subs = table.pack(...)
        for _, sub in ipairs(subs) do
            if s:sub(1, #sub) == sub then
                return true
            end
        end
        return false
    end,
}

-- Utility functions for sequenced tables
local list_util = {
    append = function(tbl, value)
        tbl[#tbl + 1] = value
        return tbl
    end,
    extend = function(tbl, other)
        for k, v in ipairs(other) do
            list_util.append(tbl, v)
        end
        return tbl
    end,
}

local table_util = {
    copy = function(tbl)
        local new = {}
        for k, v in pairs(tbl) do
            new[k] = v
        end
        return new
    end,
    deepcopy = function(tbl, copy_cache)
        if not(type(tbl) == "table") then
            -- probably passed a string or something
            -- sure, let 'em do it
            return tbl
        end
        -- if we just cache already copied tables that may stop infinite loops
        copy_cache = copy_cache or {}
        if copy_cache[tbl] then
            return copy_cache[tbl]
        end
        local new = {}
        -- make sure the copy_cache is updated before we start recursing
        -- for our own sanity
        -- also prevents infinite loops, references are updated
        copy_cache[tbl] = new
        for k, v in pairs(tbl) do
            new[table_util.deepcopy(k, copy_cache)] = table_util.deepcopy(v, copy_cache)
        end
        return new
    end,
}

local function class()
    local cls = {
        mt = {},
        instance_meta = {},
    }
    cls.mt.__call = function(cls, ...)
        local obj = {
            mt=cls.instance_meta,
        }
        setmetatable(obj, obj.mt)
        if obj._init then
            obj:_init(...)
        end
        return obj
    end
    cls.instance_meta.__index = cls
    return setmetatable(cls, cls.mt)
end

local Prefix = class()

function Prefix:_init(nick, user, host, is_server)
    self.nick = nick
    self.user = user
    self.host = host
    self.is_server = is_server
end

function Prefix:get_fullhost()
    if self.is_server then
        return self.nick
    end
    return string.format("%s!%s@%s", self.nick, self.user, self.host)
end

Prefix.instance_meta.__tostring = function(self)
    return self:get_fullhost()
end

function Prefix.parse(text)
    local nick, user, host = text:match("^:?([^!]+)!([^@]+)@(%S+)$")
    if not nick then
        local server_name = text:match("^:?(%S+%.%S+)$")
        if server_name then
            return Prefix(server_name, nil, nil, true)
        end
        error(string.format("Attempted to parse invalid prefix: %s", text))
    end
    return Prefix(nick, user, host)
end

local ParsedLine = class()

function ParsedLine:_init(prefix, command, params)
    self.prefix = prefix
    self.command = command
    self.params = params or {}
end

function ParsedLine.parse(text)
    local pfx = ""
    local params = {}
    local pfx_text, new_line = text:match("^:(%S+)%s+(.*)$")
    if pfx_text then
        text = new_line
        pfx = Prefix.parse(pfx_text)
    end
    local cmd, param_text = text:match("^(%S+)%s*(.*)$")
    local param
    while #param_text > 0 do
        if string_util.startswith(param_text, ":") then
            list_util.append(params, param_text:sub(2))
            param_text = ""
            break
        else
            param, param_text = param_text:match("^(%S+)%s*(.*)$")
            list_util.append(params, param)
        end
    end
    return ParsedLine(pfx, cmd, params)
end

ParsedLine.instance_meta.__tostring = function(self)
    local out = ""
    if self.prefix then
        out = out .. ":" .. tostring(self.prefix) .. " "
    end
    local temp_params = table_util.copy(self.params)
    if temp_params and #temp_params > 0 and string_util.startswith(temp_params[#temp_params], ":") then
        temp_params[#temp_params] = ":" .. temp_params[#temp_params]
    end
    return out .. self.command .. " " .. table.concat(temp_params, " ")
end

local Bot = class()

function Bot:_init()
    self.nick = "OpenComputersBot"
    self.command_prefix = "%"
    self:reset_state()
end

function Bot:reset_state()
    self._sock = nil
    self.connected = false
    self._current_channels = {}
    self._channel_key_cache = {}
    self.commands = {}
    self:load_default_commands()
    self:load_command_files()
end

function Bot:add_command(name, handler)
    if self.commands[name] then
        error("Attempted to add duplicate command: " .. name)
    end
    self.commands[name] = handler
end

function Bot:load_default_commands()
    self:add_command("test", "Response!")
    self:add_command("stop", function(bot) bot:send("QUIT :Bye!") end)
end

function Bot:load_command_files()
    -- TODO implement loading command files from floppy
end

function Bot:connect(host, port)
    self._sock = internet.open(host, port)
    if self._sock then
        self.connected = true
    else
        error(string.format("Failed to connect to server: %s:%d", host, port))
    end
end

function Bot:send(...)
    local data = table.pack(...)
    local out = table.concat(data, " ")
    print(">> ", out)
    return self._sock:write(out .. "\r\n")
end

function Bot:join_channel(channel, key)
    if not key then
        key = self._channel_key_cache[channel]
    else
        self._channel_key_cache[channel] = key
    end
    return self:send(string.format("JOIN :%s", table.concat({channel, key}, ",")))
end

local function counter(format)
    format = format or "%d"
    local i = 0
    return function()
        i = i + 1
        return string.format(format, i)
    end
end

function Bot:run_command(handler, params)
    if type(handler) == "string" then
        return handler
    elseif type(handler) == "number" then
        return tostring(handler)
    else
        return handler(params)
    end
end

function Bot:message(target, ...)
    return self:send(string.format("PRIVMSG %s :%s", target, table.concat(table.pack(...), " ")))
end

function Bot:handle_message(line)
    local channel = line.params[1]
    if channel == self.nick then
        channel = line.prefix.nick
    end
    local msg = line.params[2]:match("^:?(.*)$")
    -- Try parsing as command
    local command, params = msg:match("^%%(%S+)%s*(.*)$")
    local handler = self.commands[command]
    if handler then
        local result = self:run_command(handler, params)
        if result then
            self:message(channel, result)
        end
    end
end

function Bot:get_next_line()
    local line, err = self._sock:read()
    if err then
        error(err)
    end
    if not line then
        return nil
    end
    return ParsedLine.parse(line)
end

function Bot:read_loop()
    while self.connected do
        local line = self:get_next_line()
        if not line then
            break
        end
        print(tostring(line))
        if line.command == "PING" then
            self:send(string.format("PONG %s", table.concat(line.params, " ")))
        elseif line.command == "376" then
            self:join_channel("#snoonet-games")
        elseif line.command == "PRIVMSG" then
            self:handle_message(line)
        end
    end
end

function Bot:run()
    self:connect("irc.snoonet.org", 6667)
    self:send(string.format("NICK :%s", self.nick))
    self:send("USER bot 0 * :")
    self:read_loop()
end

local function main()
    local bot = Bot()
    bot:run()
end

main()
