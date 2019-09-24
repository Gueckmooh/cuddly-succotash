local progress = {}

function progress.get_bar (percent, number)
  local number = number or 20
  local i1 = math.ceil (number * (percent/100))
  local i2 = number - i1

  local str = string.format ("[%s%s]",
                             string.rep ("#", i1), string.rep ("-", i2))

  return str
end

return progress
