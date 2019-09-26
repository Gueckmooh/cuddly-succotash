local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly-succotash.util.markup"
local curry           = require "cuddly-succotash.util.functional".curry
local helpers         = require "cuddly-succotash.helpers"
local timer           = require "gears.timer"

local pulseaudio = nil

local function update (pulseaudio)
  local cmd = "pacmd dump"

  awful.spawn.easy_async(
    cmd,
    function (stdout, stderr, reason, exit_code)

      pulseaudio.default_sink = stdout:match("set%-default%-sink ([^\n]+)")

      for sink, value in stdout:gmatch("set%-sink%-volume ([^%s]+) (0x%x+)") do
        if sink == pulseaudio.default_sink then
          pulseaudio.volume = tonumber(value) / 0x10000 * 100
        end
      end

      for sink, value in stdout:gmatch("set%-sink%-mute ([^%s]+) (%a+)") do
        if sink == pulseaudio.default_sink then
          pulseaudio.mute = value == "yes"
        end
      end

      if pulseaudio.mute then
        pulseaudio.widget_text:set_markup (
          markup.markup {
            fg = pulseaudio.color_mute,
            string.format ("%d%%", math.ceil(pulseaudio.volume))
          }
        )
        pulseaudio.widget_icon:set_image (pulseaudio.icon_mute)
      else
        pulseaudio.widget_text:set_markup (
          markup.markup {
            string.format ("%d%%", math.ceil(pulseaudio.volume))
          }
        )
        if pulseaudio.volume > 50 then
          pulseaudio.widget_icon:set_image (pulseaudio.icon_high)
        elseif pulseaudio.volume > 0 then
          pulseaudio.widget_icon:set_image (pulseaudio.icon_low)
        else
          pulseaudio.widget_icon:set_image (pulseaudio.icon_no)
        end
      end
  end)

end

local function increase (pulseaudio, vol)
  local vol = pulseaudio.volume + vol
  if vol > 100 then vol = 100	end
	if vol < 0   then vol = 0	  end

	vol = (vol/100) * 0x10000
  cmd = string.format ("pacmd set-sink-volume %s 0x%x", pulseaudio.default_sink, math.ceil (vol))

	awful.spawn.with_shell (cmd, function () update (pulseaudio) end)
end

local function decrease (pulseaudio, vol)
  local vol = pulseaudio.volume - vol
  if vol > 100 then vol = 100	end
	if vol < 0   then vol = 0	  end

	vol = (vol/100) * 0x10000
  cmd = string.format ("pacmd set-sink-volume %s 0x%x", pulseaudio.default_sink, math.ceil (vol))

	awful.spawn.with_shell (cmd, function () update (pulseaudio) end)
end

local function set_volume (pulseaudio, vol)
  if vol > 100 then vol = 100	end
	if vol < 0   then vol = 0	  end

	vol = (vol/100) * 0x10000
  cmd = string.format ("pacmd set-sink-volume %s 0x%x", pulseaudio.default_sink, math.ceil (vol))

	awful.spawn.with_shell (cmd, function () update (pulseaudio) end)
end

local function toggle_mute (pulseaudio)
  local cmd = string.format ("pacmd set-sink-mute %s ", pulseaudio.default_sink)
  if pulseaudio.mute then
    cmd = cmd .. "0"
	else
    cmd = cmd .. "1"
	end
  awful.spawn.with_shell (cmd, function () update (pulseaudio) end)
end

local function factory (args, theme)
  pulseaudio = {
    volume = 0,
    default_sink = "",
    mute = false
  }

  pulseaudio.icon_high = theme.widget_vol      or helpers.icons_dir .. "vol.png"
  pulseaudio.icon_low  = theme.widget_vol_low  or helpers.icons_dir .. "vol_low.png"
  pulseaudio.icon_no   = theme.widget_vol_no   or helpers.icons_dir .. "vol_no.png"
  pulseaudio.icon_mute = theme.widget_vol_mute or helpers.icons_dir .. "vol_mute.png"

  pulseaudio.color_mute = args.color_mute or "#AAAAAA"

  pulseaudio.timeout = args.timeout or 2
  pulseaudio.theme = theme
  pulseaudio.notification = nil

  -- {{{ SETUP OF THE WIDGET
  pulseaudio.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  pulseaudio.widget_icon = wibox.widget {
    image = nil,
    resize = true,
    widget = wibox.widget.imagebox
  }

  pulseaudio.widget = wibox.widget {
    pulseaudio.widget_icon,
    {
      pulseaudio.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (pulseaudio)
  -- }}}

  -- {{{
  pulseaudio.increase = curry (increase, pulseaudio)
  pulseaudio.decrease = curry (decrease, pulseaudio)
  pulseaudio.set_volume = curry (set_volume, pulseaudio)
  pulseaudio.toggle_mute = curry (toggle_mute, pulseaudio)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, pulseaudio)
  pulseaudio.update = update
  pulseaudio.timer = timer {timeout = pulseaudio.timeout}
  pulseaudio.timer:start ()
  pulseaudio.timer:connect_signal ("timeout", update)
  -- }}}

  -- local notify = curry (notify, pulseaudio)
  -- pulseaudio.notify = notify

  -- pulseaudio.widget:connect_signal("mouse::enter", notify)
  -- pulseaudio.widget:connect_signal("mouse::leave", function()
  --                                 naughty.destroy(pulseaudio.notification) end)

  return pulseaudio
end

local function instance ()
  return pulseaudio
end

local widget = {
  factory = factory,
  instance = instance
}

return widget
