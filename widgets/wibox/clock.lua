local wibox           = require ("wibox")
local util            = require ("config.util")
local awful           = require ("awful")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly-succotash.util.markup"
local curry           = require "cuddly-succotash.util.functional".curry
local naughty         = require ("naughty")
local helpers         = require "cuddly-succotash.helpers"
local timer           = require "gears.timer"

local clock = nil

local function update (clock)
  local text = clock.widget_text
  local date = os.date "%R"
  local theme = clock.theme
  local color = theme.fg_normal
  local font = theme.font
  text:set_markup (markup.markup
             {
               fg = color,
               font = font,
               date
             }
  )
end

local function notify (clock)
    local message , icon = get_cal ()
    clock_cal = naughty.notify {
      text = message,
      icon = icon
    }
end

local function build_cal (clock, mounth, year)
  local week_start = clock.week_start
  local current_month = tonumber (os.date ("%m"))
  local current_year  = tonumber (os.date ("%Y"))
  local is_current_month = (not mounth or not year) or
    (mounth == current_month and year == current_year)
  local today = is_current_month and tonumber (os.date ("%d"))
  local t = os.time { year = year or current_year,
                      month = month and month+1 or current_month+1,
                      day = 0 }
  local d = os.date("*t", t)
  local mth_days = d.day
  local st_day = (d.wday - d.day - week_start + 1) %7
  local this_month = os.date ("%B %Y", t)

  local notifytable = {}
  notifytable[1] = string.format("%s%s\n",
                                 string.rep(" ", math.floor((28 - this_month:len())/2)),
                                 markup.bold(this_month))
  for x = 0,6 do
    notifytable[#notifytable+1] = os.date("%a ",
                                          os.time { year=2006,
                                                    month=1,
                                                    day=x+week_start })
  end
  notifytable[#notifytable] = string.format("%s\n%s",
                                            notifytable[#notifytable]:sub(1, -2),
                                            string.rep(" ", st_day*4))
  for x = 1,mth_days do
    local fg, bg = clock.notification_preset.bg, clock.notification_preset.fg
    local strx = x ~= today and x or markup.bold(markup.color(fg, bg, x) .. " ")
    strx = string.format("%s%s", string.rep(" ", 3 - tostring(x):len()), strx)
    notifytable[#notifytable+1] = string.format("%-4s%s", strx, (x+st_day)%7==0 and x ~= mth_days and "\n" or "")
  end

  return notifytable
end


function getdate(month, year, offset)
  if not month or not year then
    month = tonumber(os.date("%m"))
    year  = tonumber(os.date("%Y"))
  end

  month = month + offset

  while month > 12 do
    month = month - 12
    year = year + 1
  end

  while month < 1 do
    month = month + 12
    year = year - 1
  end

  return month, year
end


function show_cal (clock, timeout, month, year)
  local notification_preset = clock.notification_preset
  notification_preset.text = table.concat(build_cal(clock, month, year))

  local today = tonumber (os.date ("%d"))
  local icon = clock.icons .. today .. ".png"
  clock.notification = naughty.notify {
    preset  = notification_preset,
    icon    = icon,
    timeout = timeout or notification_preset.timeout or 5
  }
end

local function factory (args, theme)

  clock = {}
  clock.icons = args.icons or helpers.icons_dir .. "cal/white/"
  clock.timeout = args.timeout or 2
  clock.theme = theme
  clock.week_start = args.week_start or 2
  clock.notification = {}

  clock.notification_preset = args.notification_preset or {
    font = "Monospace 10", fg = theme.fg_normal, bg = theme.bg_normal
                                                          }

  -- {{{ SETUP OF THE WIDGET
  clock.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  clock.widget = wibox.widget {
    {
      clock.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (clock)
  -- }}}

  local show_cal = curry (show_cal, clock)

  local function notify ()
    local current_month = tonumber (os.date ("%m"))
    local current_year  = tonumber (os.date ("%Y"))
    show_cal (10, current_month, current_year)
  end

  clock.notify = notify

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, clock)
  clock.update = update
  clock.timer = timer {timeout = clock.timeout}
  clock.timer:start ()
  clock.timer:connect_signal ("timeout", update)
  -- }}}

  clock.widget:connect_signal("mouse::enter", notify)
  clock.widget:connect_signal("mouse::leave", function()
                              naughty.destroy(clock.notification) end)

  return clock
end

local widget = {
  factory = factory
}

return widget
