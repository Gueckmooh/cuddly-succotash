local functional = {}

function functional.map (f, list)
  local l2 = {}
  for k, v in ipairs (list) do
    l2[k] = f (v)
  end
  return l2
end

function functional.filter (f, list)
  local l2 = {}
  for k, v in ipairs (list) do
    l2[#l2+1] = f (v) and v or nil
  end
  return l2
end

function functional.curry (fun, arg)
  return function (...)
    fun (arg, ...)
  end
end

function functional.fold_left (fun, a, list)
  local tmp = a
  for _, v in pairs (list) do
    tmp = fun (tmp, v)
  end
  return tmp
end


return functional
