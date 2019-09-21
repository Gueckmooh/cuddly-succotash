local markup = {}

function markup.markup (args)
  local fg   = args.fg and string.format ("foreground='%s'", args.fg) or ""
  local bg   = args.bg and string.format ("background='%s'", args.bg) or ""
  local font = args.font and string.format ("font='%s'", args.font) or ""
  local text = args.text or args[1]

  local markup = string.format ("<span %s %s %s>%%s</span>", fg, bg, font)
  if text then
    return string.format (markup, text)
  else
    return function (text)
      string.format (markup, text)
    end
  end

end

setmetatable(markup, { __call = markup.markup })

return markup
