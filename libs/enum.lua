return {
  unique = function(...)
    local t = {}
    for k, v in ipairs(args) do
      t[v] = k
    end
    return t
  end,
}
