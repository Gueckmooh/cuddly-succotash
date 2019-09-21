--[[

     Licensed under GNU General Public License v2
      * (c) 2013, Luca CPZ

--]]

local spawn      = require("awful.spawn")
local timer      = require("gears.timer")
local debug      = require("debug")
local io         = { lines = io.lines,
                     open  = io.open }
local pairs      = pairs
local rawget     = rawget
local table      = { sort  = table.sort }

local helpers = {}

helpers.cuddly_dir    = debug.getinfo(1, 'S').source:match[[^@(.*/).*$]]
helpers.icons_dir     = helpers.cuddly_dir .. 'icons/'

return helpers