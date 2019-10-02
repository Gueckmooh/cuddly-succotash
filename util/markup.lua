local format = string.format

local markup = {}

function markup.bold(text)      return format("<b>%s</b>",         text) end
function markup.italic(text)    return format("<i>%s</i>",         text) end
function markup.strike(text)    return format("<s>%s</s>",         text) end
function markup.underline(text) return format("<u>%s</u>",         text) end
function markup.monospace(text) return format("<tt>%s</tt>",       text) end
function markup.big(text)       return format("<big>%s</big>",     text) end
function markup.small(text)     return format("<small>%s</small>", text) end

function markup.color(fg, bg, text)
    return format("<span foreground='%s' background='%s'>%s</span>", fg, bg, text)
end

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

function markup.truncate (str, len)
  if string.len (str) > len then
    return string.format ("%s...", string.sub (str, 0, len-3))
  else
    return str
  end
end


setmetatable(markup, { __call = markup.markup })

return markup
