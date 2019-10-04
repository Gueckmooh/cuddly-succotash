local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly.util.markup"
local curry           = require "cuddly.util.functional".curry
local progress        = require "cuddly.util.progress"
local helpers         = require "cuddly.helpers"
local timer           = require "gears.timer"

local mem = nil

local function get_mem_info (mem)
  local file = io.open ("/proc/meminfo", "r")
  local lines = file:read "*a"
  file:close ()

  local id = 0
  for line in lines:gmatch ("[^\n]+") do
    local k, v = line:match ("^([^ ]*) (.*) (.*)$")
    if     k == "MemTotal:"  then mem.mem_total   = tonumber (v)
    elseif k == "MemFree:"   then mem.mem_free    = tonumber (v)
    elseif k == "SwapTotal:" then mem.swap_total  = tonumber (v)
    elseif k == "SwapFree:"  then mem.swap_free   = tonumber (v)
    elseif k == "Buffers:"   then mem.buffers     = tonumber (v)
    elseif k == "Cached:"    then mem.cached      = tonumber (v)
    elseif k == "Slab:"      then mem.slab        = tonumber (v)
    end
    mem.mem_used = mem.mem_total - mem.mem_free - mem.buffers - mem.cached - mem.slab
    mem.swap_used = mem.swap_total - mem.swap_free

    mem.mem_percent = (100/mem.mem_total) * mem.mem_used
    mem.swap_percent = (100/mem.swap_total) * mem.swap_used
  end
end

local function get_mem_str (value)
  local v = value
  local n = 1
  if v > 10000 then
    n = n + 1
    v = v / 1024
  end
  if v > 10000 then
    n = n + 1
    v = v / 1024
  end
  if v > 10000 then
    n = n + 1
    v = v / 1024
  end

  local units = {"kB", "MB", "GB", "TB"}
  return string.format ("%.2f %s", v, units[n])
end

local function get_notification_text (mem)
  local tab = {}
  local t = {}

  local mem_used = get_mem_str (mem.mem_used)
  local mem_total = get_mem_str (mem.mem_total)

  local swap_used = get_mem_str (mem.swap_used)
  local swap_total = get_mem_str (mem.swap_total)

  local l1 = math.max (mem_used:len (), swap_used:len ())
  local l2 = math.max (mem_total:len (), swap_total:len ())

  t = {
    string.format ("Mem : ", k),
    progress.get_bar (mem.mem_percent, 40),
    string.format ("%6.2f%% - [%"..l1.."s/%"..l2.."s]\n", mem.mem_percent, mem_used, mem_total)
  }
  tab[1] = table.concat (t)

  t = {
    string.format ("Swap: ", k),
    progress.get_bar (mem.swap_percent, 40),
    string.format ("%6.2f%% - [%"..l1.."s/%"..l2.."s]", mem.swap_percent, swap_used, swap_total)
  }
  tab[2] = table.concat (t)

  return table.concat (tab)
end

local function update (mem)
  local text = mem.widget_text
  get_mem_info (mem)
  text:set_markup (
    markup.markup {
      fg = mem.theme.fg_normal,
      font = mem.theme.font,
      string.format ("%d%%", math.ceil(mem.mem_percent))
    }
  )

 if mem.notification then
   naughty.replace_text (mem.notification, "Memory status",
                         get_notification_text (mem))
 end
end

local function notify (mem)
  mem.notification = naughty.notify {
    preset = mem.notification_preset,
    title = "Memory status",
    text = get_notification_text (mem)
  }
end

local function factory (args, theme)

  mem = { mem_total = 0, mem_free = 0,
          swap_total = 0, swap_free = 0,
          buffers = 0, cached = 0, slab = 0}

  mem.icon = theme.widget_mem or helpers.icons_dir .. "mem.png"

  mem.notification_preset = {
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    font = "Monospace 10",
    timeout = 0
  }

  mem.timeout = args.timeout or 2
  mem.theme = theme
  mem.notification = nil

  -- {{{ SETUP OF THE WIDGET
  mem.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  mem.widget_icon = wibox.widget {
    image = mem.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  mem.widget = wibox.widget {
    mem.widget_icon,
    {
      mem.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (mem)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, mem)
  mem.update = update
  mem.timer = timer {timeout = mem.timeout}
  mem.timer:start ()
  mem.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, mem)
  mem.notify = notify

  mem.widget:connect_signal("mouse::enter", notify)
  mem.widget:connect_signal("mouse::leave", function()
                              naughty.destroy(mem.notification) end)

  return mem
end

local widget = {
  factory = factory
}

return widget
