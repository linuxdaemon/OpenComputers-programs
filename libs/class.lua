return function()
  local cls = {
    mt = {},
    instance_meta = {},
    _init = function() end, -- default noop init
    -- Provide the ability for the object creation logic to be overridden
    _new = function(cls, ...)
      local obj = {}
      setmetatable(obj, cls.instance_meta)
      obj:_init(...)
      return obj
    end,
  }
  -- Instances should fall back to looking up indexes on the class
  cls.instance_meta.__index = cls
  cls.mt.__call = function(self, ...)
    return self:_new(...)
  end
  return setmetatable(cls, cls.mt)
end
