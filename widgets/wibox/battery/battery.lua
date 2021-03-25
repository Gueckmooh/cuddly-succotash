local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly.util.markup"
local curry           = require "cuddly.util.functional".curry
local helpers         = require "cuddly.helpers"
local timer           = require "gears.timer"

local get_battery_cmd = debug.getinfo(1, 'S').source:match[[^@(.*/).*$]] .. "get-battery.sh"

local battery = nil

-- full: Battery 0: Full, 100% Adapter 0: on-line
-- discharging: Battery 0: Discharging, 97%, 01:49:38 remaining Adapter 0: off-line
-- charging: Battery 0: Charging, 89%, 11:26:40 until charged Adapter 0: on-line
-- unknown: Battery 0: Unknown, 89% Adapter 0: on-line
local function update (battery)
  local text         = battery.widget_text
  local wicon        = battery.widget_icon
  local cmd          = "bash " .. get_battery_cmd
  local matching_str = [[([^:]*): (%a*), (%d?%d?%d?)%%(.*)// ([^:]*): ([a-z-]*)]]
  local theme        = battery.theme

  awful.spawn.easy_async_with_shell (
    cmd,
    function (stdout, stderr, reason, exit_code)
      local line = stdout
      local _, status, charge, remain, _, plugged = string.match (line, matching_str)
      plugged = plugged == "on-line"
      charge = tonumber (charge)

      battery.infos = {
        status = status,
        charge = charge,
        remain = remain:sub(3),
        plugged = plugged
      }

      local fg   = theme.fg_normal
      local icon = nil

      if status == "Unknown" then return end
      if plugged then
        icon = battery.icon_charging
      else
        if charge > 70 then
          icon = battery.icon_full
        elseif charge > 30 then
          icon = battery.icon_low
        else
          icon = battery.icon_empty
          fg = theme.fg_urgent
        end
      end
      local message = markup.markup {
        fg = fg,
        font = theme.font,
        string.format ("%d%%", charge)
      }

      text:set_markup (message)
      wicon:set_image (icon)

      if plugged then
        if charge == 100 then
          if battery.warning_type ~= "full" then
            naughty.notify { preset = battery.charged_preset }
            battery.warning_type = "full"
          end
        else
          battery.warning_type = "charging"
        end
      else -- unplugged
        if charge > 30 then
          battery.warning_type = "discharging"
        elseif charge > 15 then
          if battery.warning_type ~= "low" or os.difftime (os.time (), battery.last_warning) > battery.notify_interval then
            naughty.notify { preset = battery.low_preset }
            battery.warning_type = "low"
            battery.last_warning = os.time ()
          end
        else -- < 15
          if battery.warning_type ~= "critical" or os.difftime (os.time (), battery.last_warning) > battery.notify_interval then
            naughty.notify { preset = battery.critical_preset }
            battery.warning_type = "critical"
            battery.last_warning = os.time ()
          end
        end
      end
  end)
end

local function notify (battery)
  local infos = battery.infos
  local message = nil
  local title = infos.status
  if     infos.status == "Unknown" then
    message = "Oops.."
  elseif infos.status == "Charging" or infos.status == "Discharging" then
    message = infos.remain
  elseif infos.status == "Full" then
    return
  end

  battery.notification = naughty.notify {
    title = title,
    text  = message,
    icon  = icon
  }
end


local function factory (args, theme)

  battery = {}

  battery.infos = {
    status = "Unknown",
    charge = -1,
    remain = "N/A",
    plugged = false
  }
  battery.icon_charging = theme.widget_ac or helpers.icons_dir .. "ac.png"
  battery.icon_full     = theme.widget_battery
  battery.icon_low      = theme.widget_battery_low
  battery.icon_empty    = theme.widget_battery_empty
  battery.fg_urgent     = theme.fg_urgent

  battery.popup_icon    = theme.widget_battery_popup_icon or helpers.icons_dir .. "spaceman.jpg"

  battery.timeout = args.timeout or 2
  battery.notify_interval = args.notify_interval or 300
  battery.theme = theme
  battery.notification = nil

  battery.last_warning = 0
  battery.warning_type = "full"

  battery.critical_preset = {
    title   = "PAAAAAANIC",
    text    = "Battery exhausted",
    timeout = 15,
    fg      = theme.fg_urgent,
    bg      = theme.bg_urgent,
    icon    = battery.popup_icon,
    icon_size = 100,
  }

  battery.low_preset = {
    title   = "Huston, we have a pronlem",
    text    = "Battery is dying",
    timeout = 15,
    fg      = "#202020",
    bg      = "#CDCDCD",
    icon    = battery.popup_icon,
    icon_size = 100,
  }


  battery.charged_preset = {
    title   = "Fiou",
    text    = "Battery Full",
    timeout = 15,
    fg      = "#202020",
    bg      = "#CDCDCD"
  }


  -- {{{ SETUP OF THE WIDGET
  battery.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  battery.widget_icon = wibox.widget {
    image = nil,
    resize = true,
    widget = wibox.widget.imagebox
  }

  -- battery.widget_arc = wibox.widget {
  --     max_value = 100,
  --     min_value = 0,
  --     thickness = 2,
  --     start_angle = 4.71238898, -- 2pi*3/4
  --     fg = theme.fg_normal,
  --     paddings = 2,
  --     widget = wibox.container.arcchart,
  --     value = 76
  -- }

  battery.widget = wibox.widget {
    battery.widget_icon,
    {
      battery.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (battery)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, battery)
  battery.update = update
  battery.timer = timer {timeout = battery.timeout}
  battery.timer:start ()
  battery.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, battery)
  battery.notify = notify

  battery.widget:connect_signal("mouse::enter", notify)
  battery.widget:connect_signal("mouse::leave", function()
                                  naughty.destroy(battery.notification) end)

  return battery
end

local widget = {
  factory = factory
}

return widget
