local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly-succotash.util.markup"
local curry           = require "cuddly-succotash.util.functional".curry
local helpers         = require "cuddly-succotash.helpers"
local timer           = require "gears.timer"
local path            = require "cuddly-succotash.util.path"

local screenshot = nil

local function shot_and_notify (screenshot, opt)
  local opt = opt or ""
  local dir = screenshot.screenshot_dir .. "/" .. os.date ("%F") .. "-screenshots"
  local filename = os.date ("%Y-%m-%d-%T"):gsub(":","-") .. "-screenshot.png"
  local cmd = string.format ([[sleep 0.1; scrot "%s/%s" %s]],
    dir, filename, opt)
  if not path.isdir (dir) then path.mkdir (dir) end

  awful.spawn.easy_async_with_shell (
    cmd,
    function (stdout, stderr, reason, exit_code)
      if exit_code ~= 0 then return end

      screenshot.notification = naughty.notify {
        preset = screenshot.notification_preset,
        text = filename,
        icon = dir .. "/" .. filename
      }
  end)
end

local function factory (args, theme)
  screenshot = {}
  screenshot.theme = theme

  screenshot.notification = nil
  screenshot.screenshot_dir = os.getenv ("HOME") .. "/Images/screenshots"

  screenshot.notification_preset = args.notification_preset or {
    title = "Screenshot taken",
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    timeout = 5,
    icon_size = 100
  }

  local shot = curry (shot_and_notify, screenshot)
  screenshot.shot = shot

  local shot_s = curry (shot, "-s")
  screenshot.shot_s = shot_s

  return screenshot
end

local function instance ()
  return screenshot
end

local widget = {
  factory = factory,
  instance = instance
}

return widget
