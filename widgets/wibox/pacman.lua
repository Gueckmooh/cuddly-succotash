local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly.util.markup"
local curry           = require "cuddly.util.functional".curry
local helpers         = require "cuddly.helpers"
local timer           = require "gears.timer"

local pacman = nil

local function get_packages (stdout, stderr, reason, exit_code)
  -- local cmd = "pacman -Qu"

  local l = {}
  for line in string.gmatch(stdout, "[^\n]+") do
    local pack, from, to = string.match (line, "^([^ ]*) ([^ ]*) %-> ([^ ]*)$")
    l[#l+1] = {pack = pack, from = from, to = to}
  end
  return l
end

local function string_diff (str1, str2)
  local l = 1
  for i = 1,#str1 do
    if str1:sub(i,i) == "." or str1:sub(i,i) == "-" or str1:sub(i,i) == "+" then l = i+1 end
    if str1:sub(i,i) ~= str2:sub(i,i) then
      return l
    end
  end
  return #str1+1
end


local function update (pacman)
  local cmd = "pacman -Qu"
  awful.spawn.easy_async (
    cmd,
    function (stdout, stderr, reason, exit_code)

      pacman.packages = get_packages (stdout, stderr, reason, exit_code)

      local text = pacman.widget_text
      local wicon = pacman.widget_icon

      if #pacman.packages == 0 then
        text:set_text ("")
        wicon:set_image (pacman.icon)
      else
        text:set_markup (
          markup.markup {
              fg = pacman.theme.fg_normal,
              font = pacman.theme.font,
              tostring (#pacman.packages)
            }
          )
        wicon:set_image (pacman.icon_avail)
      end
  end)
end

local function notify (pacman)
  if #pacman.packages == 0 then return end
  local t = {}

  local l1, l2 = 0, 0

  for _, v in pairs (pacman.packages) do
    l1 = math.max (l1, v.pack:len ())
    l2 = math.max (l2, v.from:len ())
  end

  for k, l in pairs (pacman.packages) do
    local i = string_diff (l.from, l.to)

    local from_str = markup.markup {
      fg = pacman.color1,
      markup.bold (string.format ("%-" .. l2 .. "s", l.from))
    }

    local to_str = markup.markup {
      fg = pacman.color1,
      markup.bold (l.to:sub (0, i-1) ..
                     markup.markup {fg = pacman.color2, l.to:sub (i)})
    }

    t[#t+1] = string.format ("%-" .. l1 .. "s\t%s → %s", l.pack, from_str, to_str)
    if k ~= #pacman.packages then t[#t] = t[#t] .. "\n" end
  end
  local message = table.concat (t)
  pacman.notification = naughty.notify {
    preset = pacman.notification_preset,
    text = message,
  }
end

local function factory (args, theme)

  pacman = {}

  pacman.packages = {}

  pacman.timeout = args.timeout or 60
  pacman.theme = theme
  pacman.notification = nil
  pacman.icon = theme.widget_pacman or helpers.icons_dir .. "pacman.png"
  pacman.icon_avail = theme.widget_pacman_avail or helpers.icons_dir .. "pacman_avail.png"

  -- pacman.color1 = "#37364c"
  pacman.color1 = "#99a6c4"
  pacman.color2 = "#93014a"

  pacman.notification_preset = args.notification_preset or {
    title = "Packages to upgrade",
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    font = "Monospace 10",
    timeout = 0
  }

  -- {{{ SETUP OF THE WIDGET
  pacman.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  pacman.widget_icon = wibox.widget {
    image = pacman.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  pacman.widget = wibox.widget {
    pacman.widget_icon,
    {
      pacman.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (pacman)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, pacman)
  pacman.update = update
  pacman.timer = timer {timeout = pacman.timeout}
  pacman.timer:start ()
  pacman.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, pacman)
  pacman.notify = notify

  pacman.widget:connect_signal("mouse::enter", notify)
  pacman.widget:connect_signal("mouse::leave", function()
                                 naughty.destroy(pacman.notification) end)

  return pacman
end

local widget = {
  factory = factory
}

return widget
