return {
  unique = function(...)
    local args = {...}
    local t = {}
    for k, v in ipairs(args) do
      if t[v] then
        return error("Duplicate enum entries")
      end
      t[v] = k
    end
    return t
  end,
}
