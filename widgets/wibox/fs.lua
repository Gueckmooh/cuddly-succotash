local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly-succotash.util.markup"
local curry           = require "cuddly-succotash.util.functional".curry
local progress        = require "cuddly-succotash.util.progress"
local helpers         = require "cuddly-succotash.helpers"
local timer           = require "gears.timer"

local fs = nil

local function notif_message (fs)
  local tab = {}

  local fslen = 0
  local l1 = 0
  local l2 = 0
  for _, v in ipairs (fs.infos) do
    fslen = math.max (fslen, v.mounted:len ())
    l1 = math.max (v.used:len (), l1)
    l2 = math.max (v.size:len (), l2)
  end
  fslen = fslen + 1
  for k, v in ipairs (fs.infos) do

    tab[k] = {
      string.format ("%-"..fslen.."s ", v.mounted .. ":"),
      progress.get_bar (tonumber (v.percent), 40),
      string.format (" %3s%% ", v.percent),
      string.format ("[%"..l1.."s/%"..l2.."s]", v.used, v.size),
      k ~= #fs.infos and "\n" or ""
    }
    tab[k] = table.concat (tab[k])
  end

  return table.concat (tab)
end

local function notify (fs)
  local message = notif_message (fs)

  fs.notification = naughty.notify {
    preset = fs.notification_preset,
    text = message
  }
end


local function update (fs)
  local cmd = "df -h"
  awful.spawn.easy_async (
    cmd,
    function (stdout, stderr, reason, exit_code)
      fs.infos = {}
      for line in stdout:gmatch ("[^\n]*") do
        local filesystem, size, used, avail, percent, mounted =
          line:match ("([^ ]*)[ ]*([^ ]*)[ ]*([^ ]*)[ ]*([^ ]*)[ ]*([^ ]*)%%[ ]*([^ ]*)")
        if filesystem ~= "Filesystem" and filesystem ~= nil then
          fs.infos[#fs.infos+1] = {
            filesystem = filesystem,
            size = size,
            used = used,
            avail = avail,
            percent = percent,
            mounted = mounted
          }
        end
        if mounted == "/home" then
          fs.widget_text:set_markup (
            markup.markup {
              fg = fs.theme.fg_normal,
              font = fs.theme.font,
              string.format ("%s%%", percent)
            }
          )
        end
      end
  end)
end


local function factory (args, theme)

  fs = {}

  fs.infos = {}

  fs.icon = theme.widget_hdd or helpers.icons_dir .. "hdd.png"

  fs.timeout = args.timeout or 2
  fs.theme = theme
  fs.notification = nil

  fs.notification_preset = args.notification_preset or {
    font = "Monospace 10",
    title = "File System status",
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    timeout = 0
                                                       }

  -- {{{ SETUP OF THE WIDGET
  fs.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  fs.widget_icon = wibox.widget {
    image = fs.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  fs.widget = wibox.widget {
    fs.widget_icon,
    {
      fs.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (fs)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, fs)
  fs.update = update
  fs.timer = timer {timeout = fs.timeout}
  fs.timer:start ()
  fs.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, fs)
  fs.notify = notify

  fs.widget:connect_signal("mouse::enter", notify)
  fs.widget:connect_signal("mouse::leave", function()
                                  naughty.destroy(fs.notification) end)

  return fs
end

local widget = {
  factory = factory
}

return widget
