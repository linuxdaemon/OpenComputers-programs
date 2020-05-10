local lib = {}

local _root = {}

function lib.class(name, parent)
  local parent_cls = parent or lib.Object
  local cls = {
    mt = {
      __call = function(self, ...)
        return self:_new(...)
      end,
      __index = parent_cls,
    },
    instance_meta = {},
    _name = name,
  }
  -- Instances should fall back to looking up indexes on the class
  cls.instance_meta.__index = cls
  return setmetatable(cls, cls.mt)
end

local Object = lib.class("Object", _root)

function Object._init()
end

function Object:_new(...)
  local obj = {}
  setmetatable(obj, self.instance_meta)
  obj:_init(...)
  return obj
end

lib.Object = Object

local lib_mt = {
  __call = function(self, ...)
    return self.class(...)
  end,
}

setmetatable(lib, lib_mt)

return lib
