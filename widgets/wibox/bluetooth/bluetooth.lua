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
local gears           = require "gears"



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


local function get_devices_infos (lines)
  local devices_infos = {}
  if lines:match("No default controller available") ~= nil then
    return devices_infos end

  local devices = {}
  local last_mac = ""
  for line in string.gmatch (lines, "[^\n]*") do
    local mac = string.match (line, "Device ([^%s]*) .*")
    if mac then devices[mac] = line
      last_mac = mac
    else devices[last_mac] = devices[last_mac] .. "\n" .. line end
  end

  local infos = {}
  for k, d in pairs (devices) do
    infos[#infos+1] = {}
    local t = infos[#infos]
    t.mac = k
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

local function disconnect (c)
  awful.spawn.easy_async_with_shell (
    string.format([[bluetoothctl disconnect %s]], c.mac),
    function (stdout, stderr, reason, exit_code)
      for line in string.gmatch (stdout, "[^\n]*") do
        if string.match (line, "Successful disconnected") then
          c:set_icon (bluetooth.icon_unchecked)
          bluetooth:update()
          return
        end
      end
    end
  )
end

local function connect (c)
  awful.spawn.easy_async_with_shell (
    string.format([[bluetoothctl connect %s]], c.mac),
    function (stdout, stderr, reason, exit_code)
      for line in string.gmatch (stdout, "[^\n]*") do
        if string.match (line, "Connection successful") then
          c:set_icon (bluetooth.icon_checked)
          bluetooth:update()
          return
        end
      end
    end
  )
end

local function power_on (c, devices)
  awful.spawn.easy_async_with_shell (
    [[bluetoothctl power on]],
    function (stdout, stderr, reason, exit_code)
      for line in string.gmatch (stdout, "[^\n]*") do
        if string.match (line, "Changing power on succeeded") then
          c:set_icon (bluetooth.icon_checked)
          for _, v in pairs(devices) do
            v:set_bg (bluetooth.bg_normal)
            v:set_icon (bluetooth.icon_unchecked)
          end
          bluetooth:update()
          return
        end
      end
    end
  )
end

local function power_off (c, devices)
  awful.spawn.easy_async_with_shell (
    [[bluetoothctl power off]],
    function (stdout, stderr, reason, exit_code)
      for line in string.gmatch (stdout, "[^\n]*") do
        if string.match (line, "Changing power off succeeded") then
          c:set_icon (bluetooth.icon_unchecked)
          for _, v in pairs(devices) do
            v:set_bg ("#666666")
            v:set_icon (bluetooth.icon_unchecked)
          end
          bluetooth:update()
          return
        end
      end
    end
  )
end

local function create_rows (bluetooth)

  local rows = {
    layout = wibox.layout.fixed.vertical,
  }

  local devices = {}

  for k, v in pairs (bluetooth.infos.devices_infos) do
    local icon = v.connected and bluetooth.icon_checked
      or bluetooth.icon_unchecked

    local bg = bluetooth.infos.powered and bluetooth.bg_normal or "#666666"

    local tmp = wibox.widget {
      widget = wibox.container.background,
      bg = bg,
      id = "background",
      {
        layout = wibox.layout.fixed.horizontal,
        id = "lay",
        {
          id = "margin_icon",
          layout = wibox.container.margin,
          margins = 4,
          {
            id = "icon",
            widget = wibox.widget.imagebox,
            image = icon,
            resize = true,
            forced_height = 30,
            forced_width = 30,
          }
        },
        {
          id = "margin_txt",
          layout = wibox.container.margin,
          margins = 8,
          {
            id = "txt",
            widget = wibox.widget.textbox,
            text = k
          }
        }
      },
      set_text = function (self, new_value)
        self.lay.margin_txt.txt.text = new_value
      end,
      set_icon = function(self, new_value)
        self.lay.margin_icon.icon.image = new_value
      end,
      name = k,
      mac = v.mac
    }

    tmp:connect_signal ("mouse::enter",
                        function (c)
                          if bluetooth.infos.powered then
                            c:set_bg(bluetooth.bg_focus)
                          else
                            c:set_bg("#666666")
                          end
                        end
    )
    tmp:connect_signal ("mouse::leave",
                        function (c)
                          if bluetooth.infos.powered then
                            c:set_bg(bluetooth.bg_normal)
                          else
                            c:set_bg("#666666")
                          end
                        end
    )

    tmp:buttons (
      gears.table.join (
        awful.button({}, 1, function()
            if bluetooth.infos.powered then
              if bluetooth.infos.devices_infos[tmp.name].connected then
                disconnect (tmp)
              else
                connect (tmp)
              end
            end
        end)
      )
    )

      table.insert (devices, tmp)
      table.insert (rows, tmp)

  end

  -- For power

  local icon = bluetooth.infos.powered and bluetooth.icon_checked
    or bluetooth.icon_unchecked

  local tmp = wibox.widget {
    widget = wibox.container.background,
    bg = bluetooth.bg_normal,
    id = "background",
    {
      layout = wibox.layout.fixed.horizontal,
      id = "lay",
      {
        id = "margin_icon",
        layout = wibox.container.margin,
        margins = 4,
        {
          id = "icon",
          widget = wibox.widget.imagebox,
          image = icon,
          resize = true,
          forced_height = 30,
          forced_width = 30,
        }
      },
      {
        id = "margin_txt",
        layout = wibox.container.margin,
        margins = 8,
        {
          id = "txt",
          widget = wibox.widget.textbox,
          text = "Powered"
        }
      }
    },
    set_text = function (self, new_value)
      self.lay.margin_txt.txt.text = new_value
    end,
    set_icon = function(self, new_value)
      self.lay.margin_icon.icon.image = new_value
    end,
  }

  tmp:connect_signal ("mouse::enter", function (c) c:set_bg(bluetooth.bg_focus) end)
  tmp:connect_signal ("mouse::leave", function (c) c:set_bg(bluetooth.bg_normal) end)

  tmp:buttons (
    gears.table.join (
      awful.button({}, 1, function()
          if bluetooth.infos.powered then
            print "power_off"
            power_off (tmp, devices)
          else
            print "power_on"
            power_on (tmp, devices)
          end
      end)
    )
  )

  table.insert (rows, tmp)

  return rows

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
    end
  )

  awful.spawn.easy_async_with_shell (
    [[bluetoothctl show]],
    function (stdout, stderr, reason, exit_code)
      local lines = stdout
      local infos = get_host_infos (lines)
      bluetooth.infos.host_infos = infos
      bluetooth.infos.powered = infos.powered
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

  local devices_names = ""
  for k, _ in pairs (bluetooth.infos.devices_infos) do
    devices_names = devices_names .. k
  end

  if devices_names ~= bluetooth.devices_names then
    bluetooth.devices_names = devices_names

    local rows = create_rows (bluetooth)

    bluetooth.popup:setup(rows)

  end

end

local function factory (args, theme)
  local theme = theme or beautiful
  local args = args or {}

  bluetooth = {}

  bluetooth.theme = theme

  bluetooth.update = update

  bluetooth.icon_active = icons_dir .. "bluetooth-active.svg"
  bluetooth.icon_disabled = icons_dir .. "bluetooth-disabled.svg"
  bluetooth.icon_connected = icons_dir .. "bluetooth-connected.svg"
  bluetooth.icon_checked = icons_dir .. "checkbox-checked-symbolic.svg"
  bluetooth.icon_unchecked = icons_dir .. "checkbox-symbolic.svg"

  bluetooth.infos = {
    host_infos = {},
    devices_infos = {},
    connected = false,
    items = {},
    powered = {},
    devices_names = ""
  }

  bluetooth.rows = {layout = wibox.layout.align.vertical}

  bluetooth.timeout = args.timeout or 2
  bluetooth.notify_interval = args.notify_interval or 300
  bluetooth.theme = theme
  bluetooth.notification = nil

  bluetooth.bg_normal = args.bg_normal or theme.bg_normal
  bluetooth.bg_focus = args.bg_focus or theme.bg_focus


  -- {{{ SETUP OF THE WIDGET
  bluetooth.widget_icon = wibox.widget {
    image = bluetooth.icon_disabled,
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


  bluetooth.popup = awful.popup{
    bg = theme.bg_normal,
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    border_width = 1,
    border_color = theme.bg_focus,
    maximum_width = 400,
    offset = { y = 5 },
    widget = {}
  }


  function bluetooth.popup:toggle()
    if bluetooth.popup.visible then
      bluetooth.popup.visible = not bluetooth.popup.visible
    else
      bluetooth.popup:move_next_to(mouse.current_widget_geometry)
    end
  end


  bluetooth.widget:buttons (
    gears.table.join (
      awful.button({}, 1, function()
          bluetooth.popup:toggle()
      end)
    )
  )


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

  return bluetooth
end


local widget = {
  factory = factory
}


return widget
