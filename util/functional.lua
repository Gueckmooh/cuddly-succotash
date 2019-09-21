local functional = {}

function functional.curry (fun, arg)
  return function (...)
    fun (arg, ...)
  end
end

return functional
