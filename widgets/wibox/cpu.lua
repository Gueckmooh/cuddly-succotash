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

local cpu = nil

local function get_cpu_info (cpu)
  local file = io.open ("/proc/stat", "r")
  local lines = file:read "*a"
  file:close ()

  local id = 0
  for line in lines:gmatch ("[^\n]+") do
    local k, v = line:match ("^([^ ]*) (.*)$")
    if k:sub(0, 3) == "cpu" then
      local core = cpu.core[id] or
        { last_active = 0 , last_total = 0, usage = 0}
      local user, nice, system, idle, iowait, irq, softirq = v:match ("(%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)")
      local idle = idle + iowait
      local total = user + nice + system + idle + iowait + irq + softirq

      local active = total - idle

      if core.last_active ~= active or core.last_total ~= total then
        -- Read current data and calculate relative values.
        local dactive = active - core.last_active
        local dtotal  = total - core.last_total
        local usage  = ((dactive / dtotal) * 100)

        core.last_active = active
        core.last_total  = total
        core.usage       = usage

        cpu.core[id] = core
      end
      id = id + 1
    end
  end
  return cpu
end

local pretty = require "pl.pretty"

local function get_notification_text (cpu)
  local tab = {}

  for k, v in ipairs (cpu.core) do
    local t = {
      string.format ("%-2d: ", k),
      progress.get_bar (v.usage),
      k%2 ~= 0 and string.format ("%6.2f%%    ", v.usage) or
        k ~= #cpu.core and string.format ("%6.2f%%\n", v.usage) or
        string.format ("%6.2f%%", v.usage)
    }
    tab[k] = table.concat (t)
  end
  return table.concat (tab)
end

local function update (cpu)
  local text = cpu.widget_text
  get_cpu_info (cpu)
  text:set_markup (
    markup.markup {
      fg = cpu.theme.fg_normal,
      font = cpu.theme.font,
      string.format ("%d%%", math.ceil(cpu.core[0].usage))
    }
  )

 if cpu.notification then
   naughty.replace_text (cpu.notification, "CPU status",
                         get_notification_text (cpu))
 end
end

local function notify (cpu)
  cpu.notification = naughty.notify {
    preset = cpu.notification_preset,
    title = "CPU status",
    text = get_notification_text (cpu)
  }
end

local function factory (args, theme)

  cpu = {}

  cpu.core = {}

  cpu.icon = theme.widget_cpu or helpers.icons_dir .. "cpu.png"

  cpu.notification_preset = {
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    font = "Monospace 10",
    timeout = 0
  }

  cpu.timeout = args.timeout or 2
  cpu.theme = theme
  cpu.notification = nil

  -- {{{ SETUP OF THE WIDGET
  cpu.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  cpu.widget_icon = wibox.widget {
    image = cpu.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  cpu.widget = wibox.widget {
    cpu.widget_icon,
    {
      cpu.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (cpu)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, cpu)
  cpu.update = update
  cpu.timer = timer {timeout = cpu.timeout}
  cpu.timer:start ()
  cpu.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, cpu)
  cpu.notify = notify

  cpu.widget:connect_signal("mouse::enter", notify)
  cpu.widget:connect_signal("mouse::leave", function()
                              naughty.destroy(cpu.notification) end)

  return cpu
end

-- local cpu = get_cpu_info ()
-- local pretty = require "pl.pretty"

-- print (pretty.write (cpu))

-- local tab = {}

-- for k, v in ipairs (cpu.core) do
--   local t = {
--     string.format ("%-2d: ", k),
--     foo (v.usage),
--     k%2 ~= 0 and string.format ("%6.2f%%    ", v.usage) or string.format ("%6.2f%%\n", v.usage)
--   }
--   tab[k] = table.concat (t)
-- end

-- print (table.concat (tab))

local widget = {
  factory = factory
}

return widget
