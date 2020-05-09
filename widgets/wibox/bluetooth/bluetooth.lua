local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly.util.markup"
local curry           = require "cuddly.util.functional".curry
local helpers         = require "cuddly.helpers"
local timer           = require "gears.timer"
local beautiful       = require "beautiful"

local icons_dir = debug.getinfo(1, 'S').source:match[[^@(.*/).*$]] .. "icons/"

-- local cmd = "/usr/bin/bluetoothctl"

local bluetooth = {}

function get_devices (lines)

  local n = 1
  for line in string.gmatch(lines, "[^\n]*") do
    for mac, name in string.gmatch(line, "Device ([^ ]*) (.*)") do
      devices[n] = {
        mac = mac,
        name = name
      }
    end
    n = n + 1
  end

  return devices
end

local function get_host_infos (lines)
  local host_infos = {}


  for line in string.gmatch (lines, "[^\n]*") do
    for key, value in string.gmatch (line, "%s*([^:]*): (.*)") do
      if     key == "Name"         then host_infos.name = value
      elseif key == "Alias"        then host_infos.alias = value
      elseif key == "Powered"      then host_infos.powered = value == "yes"
      elseif key == "Discoverable" then host_infos.discoverable = value == "yes"
      elseif key == "Discovering"  then host_infos.discovering = value == "yes"
      end
    end
  end

  return host_infos
end

-- for i in $(bluetoothctl devices | awk '{print $2}'); do bluetoothctl info "$i"; done

local function get_devices_infos (lines)
  local devices_infos = {}

  local devices = {}
  for line in string.gmatch (lines, "[^\n]*") do
    if string.match (line, "Device .*") then devices[#devices+1] = line
    else devices[#devices] = devices[#devices] .. "\n" .. line end
  end

  local infos = {}
  for _, d in pairs (devices) do
    infos[#infos+1] = {}
    local t = infos[#infos]
    for line in string.gmatch (d, "[^\n]*") do
      local k, v = string.match (line, "%s*([^:]*): (.*)")
      if     k == "Name"            then t.name = v
      elseif k == "Alias"           then t.alias = v
      elseif k == "Paired"          then t.paired = v == "yes"
      elseif k == "Trusted"         then t.trusted = v == "yes"
      elseif k == "Blocked"         then t.blocked = v == "yes"
      elseif k == "Connected"       then t.connected = v == "yes"
      elseif k == "LegacyConnected" then t.legacy = v == "yes"
      end
    end
    devices_infos[t.name] = t
  end

  return devices_infos
end

local function update (bluetooth)
  local wicon        = bluetooth.widget_icon
  local icon = nil

  awful.spawn.easy_async_with_shell (
    [[for i in $(bluetoothctl devices | awk '{print $2}'); do bluetoothctl info "$i"; done]],
    function (stdout, stderr, reason, exit_code)
      local lines = stdout
      local infos = get_devices_infos (lines)
      bluetooth.infos.devices_infos = infos
      local connected = false
      for k, v in pairs (infos) do
        connected = connected or v.connected end
      bluetooth.infos.connected = connected
      require ("pl.pretty").dump (infos)
    end
  )

  awful.spawn.easy_async_with_shell (
    [[bluetoothctl show]],
    function (stdout, stderr, reason, exit_code)
      local lines = stdout
      local infos = get_host_infos (lines)
      bluetooth.infos.host_infos = infos
      bluetooth.infos.powered = infos.powered
      require ("pl.pretty").dump (infos)
    end
  )

  if bluetooth.infos.powered then
    icon = bluetooth.icon_active
  else
    icon = bluetooth.icon_disabled
  end

  if bluetooth.infos.connected then
    icon = bluetooth.icon_connected
  end

  wicon:set_image (icon)

end

local function factory (args, theme)
  local theme = theme or beautiful
  local args = args or {}

  bluetooth = {}

  bluetooth.icon_active = icons_dir .. "bluetooth-active.svg"
  bluetooth.icon_disabled = icons_dir .. "bluetooth-disabled.svg"
  bluetooth.icon_connected = icons_dir .. "bluetooth-connected.svg"

  bluetooth.infos = {
    host_infos = {},
    devices_infos = {},
    connected = false,
  }
  bluetooth.icon_charging = theme.widget_ac or helpers.icons_dir .. "ac.png"
  bluetooth.icon_full     = theme.widget_bluetooth
  bluetooth.icon_low      = theme.widget_bluetooth_low
  bluetooth.icon_empty    = theme.widget_bluetooth_empty
  bluetooth.fg_urgent     = theme.fg_urgent

  bluetooth.popup_icon    = theme.widget_bluetooth_popup_icon or helpers.icons_dir .. "spaceman.jpg"

  bluetooth.timeout = args.timeout or 2
  bluetooth.notify_interval = args.notify_interval or 300
  bluetooth.theme = theme
  bluetooth.notification = nil


  -- {{{ SETUP OF THE WIDGET
  bluetooth.widget_icon = wibox.widget {
    image = bluetooth.icon_active,
    resize = true,
    widget = wibox.widget.imagebox
  }


  bluetooth.widget = wibox.widget {
    {
      bluetooth.widget_icon,
      margins = dpi(2),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (bluetooth)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, bluetooth)
  bluetooth.update = update
  bluetooth.timer = timer {timeout = bluetooth.timeout}
  bluetooth.timer:start ()
  bluetooth.timer:connect_signal ("timeout", update)
  -- }}}

  -- local notify = curry (notify, battery)
  -- battery.notify = notify

  -- battery.widget:connect_signal("mouse::enter", notify)
  -- battery.widget:connect_signal("mouse::leave", function()
  --                                 naughty.destroy(battery.notification) end)

  return bluetooth
end


local widget = {
  factory = factory
}


return widget
