--[[
  Inspired by Lain's quake
--]]

local awful = require "awful"
local quake = {}
local pretty = require "pl.pretty"

function quake.foo ()
  local app = "termite"
  local name = "QuakeDD"
  local set_name = "-t %s"
  local cmd = string.format ("%s %s", app, string.format (set_name, name))

  local my_screen = awful.screen.focused ()
  local my_screen_geometry = screen[my_screen.index].geometry

  local props = {
    tag = my_screen.selected_tag,
    floating = true,
    size_hints_honor = false,
    titlebars_enabled = false
  }

  print (cmd)

  awful.spawn (cmd, props)
end

return quake
