--[[

  Author: Gueckmooh
  Date: 21/09/19
  MPD widget inspired by Luca CPZ Lain's one (https://github.com/lcpz/lain)

--]]

local awful      = require "awful"
local spawn      = require("awful.spawn")
local shell      = require("awful.util").shell
local escape_f   = require("awful.util").escape
local focused    = require("awful.screen").focused
local naughty    = require("naughty")
local wibox      = require("wibox")
local os         = os
local string     = string
local xresources = require("beautiful.xresources")
local dpi        = xresources.apply_dpi
local timer      = require "gears.timer"
local markup     = require "cuddly-succotash.util.markup"
local curry      = require ("cuddly-succotash.util.functional").curry

local mpd = nil

local function get_status(stdout, stderr, reason, exit_code)

  mpd_now = {
    random_mode  = false,
    single_mode  = false,
    repeat_mode  = false,
    consume_mode = false,
    pls_pos      = "N/A",
    pls_len      = "N/A",
    state        = "N/A",
    file         = "N/A",
    name         = "N/A",
    artist       = "N/A",
    title        = "N/A",
    album        = "N/A",
    genre        = "N/A",
    track        = "N/A",
    date         = "N/A",
    time         = "N/A",
    elapsed      = "N/A"
  }

  local lines = stdout

  for line in string.gmatch(lines, "[^\n]+") do
    for k, v in string.gmatch(line, "([%w]+):[%s](.*)$") do
      if     k == "state"          then mpd_now.state        = v
      elseif k == "file"           then mpd_now.file         = v
      elseif k == "Name"           then mpd_now.name         = escape_f(v)
      elseif k == "Artist"         then mpd_now.artist       = escape_f(v)
      elseif k == "Title"          then mpd_now.title        = escape_f(v)
      elseif k == "Album"          then mpd_now.album        = escape_f(v)
      elseif k == "Genre"          then mpd_now.genre        = escape_f(v)
      elseif k == "Track"          then mpd_now.track        = escape_f(v)
      elseif k == "Date"           then mpd_now.date         = escape_f(v)
      elseif k == "Time"           then mpd_now.time         = v
      elseif k == "elapsed"        then mpd_now.elapsed      = string.match(v, "%d+")
      elseif k == "song"           then mpd_now.pls_pos      = v
      elseif k == "playlistlength" then mpd_now.pls_len      = v
      elseif k == "repeat"         then mpd_now.repeat_mode  = v ~= "0"
      elseif k == "single"         then mpd_now.single_mode  = v ~= "0"
      elseif k == "random"         then mpd_now.random_mode  = v ~= "0"
      elseif k == "consume"        then mpd_now.consume_mode = v ~= "0"
      end
    end
  end

  return mpd_now
end

local function async(cmd, callback)
  return spawn.easy_async(cmd,
                          function (stdout, stderr, reason, exit_code)
                            callback(stdout, exit_code)
  end)
end

local function get_cover (mpd)
  local music_dir     = mpd.music_dir
  local infos         = mpd.infos
  local cover_pattern = mpd.cover_pattern
  local path          = string.format("%s/%s", music_dir, string.match(infos.file, ".*/"))
  local cover         = string.format("find '%s' -maxdepth 1 -type f | egrep -i -m1 '%s'",
                               path:gsub("'", "'\\''"), cover_pattern)
  local icon = nil
  local f = io.popen (cover, "r")
  local l = f:read "*a"
  f:close ()
  icon = l:gsub ("\n", "")
  if #icon == 0 then icon = nil end

  return icon
end

local function update (mpd)
  local icon  = mpd.widget_icon
  local text  = mpd.widget_text

  awful.spawn.easy_async (
    mpd.cmd,
    function (stdout, stderr, reason, exit_code)

      mpd.infos   = get_status (stdout, stderr, reason, exit_code)

      ------------------------------ COVER ------------------------------

      local music_dir     = mpd.music_dir
      local infos         = mpd.infos
      local cover_pattern = mpd.cover_pattern
      local path          = string.format("%s/%s", music_dir, string.match(infos.file, ".*/"))
      local cover         = string.format("find '%s' -maxdepth 1 -type f | egrep -i -m1 '%s'",
                                          path:gsub("'", "'\\''"), cover_pattern)

      awful.spawn.easy_async_with_shell (
        cover,
        function (stdout, stderr, reason, exit_code)
          local icon = nil
          local l = stdout
          icon = l:gsub ("\n", "")
          if #icon == 0 then icon = nil end
          mpd.cover   = icon or mpd.default_art
      end)

      -------------------------------------------------------------------
      local infos = mpd.infos
      local theme = mpd.theme
      if infos.state == "play"
      then
        if infos.title ~= "N/A" then
          local title  = infos.title
          local artist = infos.artist
          local color1 = mpd.color_play
          local color2 = theme.fg_normal
          text:set_markup (markup.markup
                           {
                             fg = color2,
                             font = theme.font,
                             markup.markup {fg = color1, artist} .. " " .. title
                           }
          )
        else
          local filename = infos.file
          text:set_markup (markup.markup
                           {
                             fg = color2,
                             font = theme.font,
                             filename
                           }
          )
        end
        icon:set_image (mpd.icon_on)
      elseif infos.state == "pause"
      then
        local title  = infos.title
        local artist = infos.artist
        local color1 = mpd.color_pause
        local color2 = theme.fg_normal
        if infos.title ~= "N/A" then
          text:set_markup (markup.markup
                           {
                             fg = color2,
                             font = theme.font,
                             markup.markup {fg = color1, artist} .. " " .. title
                           }
          )
        else
          local filename = infos.file
          text:set_markup (markup.markup
                           {
                             fg = color1,
                             font = theme.font,
                             filename
                           }
          )
        end
        icon:set_image (mpd.icon_pause)
      else
        text:set_text ("")
        icon:set_image (mpd.icon)
      end
  end)
end

local function notify (mpd)
  local infos = mpd.infos
  local theme = mpd.theme
  local message

  if infos.title ~= "N/A" then
    message = string.format (
      "%s - %s (%s)\n"..
        "%s",
      infos.artist, infos.album, infos.date,
      infos.title
    )
  else
    message = string.format (
      "%s",
      infos.file
    )
  end
  mpd.notification = naughty.notify{
    icon      = mpd.cover,
    icon_size = 100,
    title     = "Now playing",
    text      = message,
    timeout   = 5, hover_timeout = 0.5,
    position  = "top_right",
    bg        = theme.bg_normal,
    fg        = theme.fg_normal,
    width     = 300,
  }
end

local function factory (args, theme)
  mpd               = {}

  mpd.icon          = theme.widget_music or nil
  mpd.icon_on       = theme.widget_music_on or theme.widget_music or nil
  mpd.icon_pause    = theme.widget_music_pause or theme.widget_music or nil
  mpd.icon_stop     = theme.widget_music_stop or theme.widget_music or nil
  mpd.color_pause   = theme.widget_music_color_pause or "#AAAAAA"
  mpd.color_play    = theme.widget_music_color_play or "#FF8466"

  mpd.args          = args or {}
  mpd.timeout       = args.timeout or 2
  mpd.password      = (args.password and #args.password > 0 and
                         string.format("password %s\\n", args.password)) or ""
  mpd.host          = args.host or os.getenv("MPD_HOST") or "localhost"
  mpd.port          = args.port or os.getenv("MPD_PORT") or "6600"
  mpd.music_dir     = args.music_dir or os.getenv("HOME") .. "/Music"
  mpd.cover_pattern = args.cover_pattern or "*\\.(jpg|jpeg|png|gif)$"
  mpd.cover_size    = args.cover_size or 100
  mpd.default_art   = args.default_art or theme.widget_music_default_art
  mpd.use_exiftool  = false
  mpd.notify        = args.notify or "on"
  mpd.followtag     = args.followtag or false
  mpd.settings      = args.settings or function() end

  mpd.theme         = theme

  local mpdh = string.format("telnet://%s:%s", mpd.host, mpd.port)
  local echo = string.format("printf \"%sstatus\\ncurrentsong\\nclose\\n\"", mpd.password)
  local cmd  = string.format("%s | curl --connect-timeout 1 -fsm 3 %s", echo, mpdh)

  mpd.cmd = cmd
  mpd.infos = get_status (cmd)

  -- {{{ SETUP OF THE WIDGET
  mpd.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  mpd.widget_icon = wibox.widget {
    image = mpd.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  mpd.widget = wibox.widget {
    mpd.widget_icon,
    {
      mpd.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin
    },
    layout = wibox.layout.fixed.horizontal
  }

  -- Init
  update (mpd)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, mpd)
  mpd.update = update
  mpd.timer = timer {timeout = mpd.timeout}
  mpd.timer:start ()
  mpd.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, mpd)
  mpd.notify = notify
  mpd.notification = nil

  mpd.widget:connect_signal("mouse::enter", notify)
  mpd.widget:connect_signal("mouse::leave", function()
                              naughty.destroy(mpd.notification) end)

  return mpd

end

local function get_instance ()
  return mpd
end

local widget = {
    factory = factory,
    get_instance = get_instance
  }

return widget
