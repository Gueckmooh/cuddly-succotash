local wibox           = require ("wibox")
local awful           = require ("awful")
local naughty         = require ("naughty")
local xresources      = require("beautiful.xresources")
local dpi             = xresources.apply_dpi
local markup          = require "cuddly.util.markup"
local functional      = require "cuddly.util.functional"
local curry           = functional.curry
local helpers         = require "cuddly.helpers"
local timer           = require "gears.timer"

local notmuch = nil

local function get_mails (stdout, stderr, reason, exit_code)
  local mails = {}
  for line in stdout:gmatch ("[^\n]*") do
    if line ~= "" then
      local id, date, nb, _, _, from, subject = line:match ("^thread:([^ ]*)[ ]*(.*) %[(%d*)/(%d*)%((%d*)%)%] (.*); (.*) %(.*%)$")
      if not id then
        id, date, nb, _, from, subject = line:match ("^thread:([^ ]*)[ ]*(.*) %[(%d*)/(%d*)%] (.*); (.*) %(.*%)$")
      end
      mails[#mails+1] = {
        id = id,
        date = date,
        from = from,
        subject = subject,
        nb = nb
      }
    end
  end

  return mails
end

local function get_message (notmuch, mails)
  local mails = mails or notmuch.mails
  local fold_left = functional.fold_left
  local truncate = markup.truncate
  local ldate = fold_left (function (a, b) return math.max (a, string.len (b.date)) end, 0, mails)
  local ldate = math.min (ldate, notmuch.lmax - 10)
  local lfrom = fold_left (function (a, b) return math.max (a, string.len (b.from)) end, 0, mails)
  local lsubject = fold_left (function (a, b) return math.max (a, string.len (b.subject)) end, 0, mails)
  local lsubject = math.min (lsubject, notmuch.lmax)
  local lfrom = math.min (lfrom, math.max (lsubject - ldate - 3, 30))


  local l1 = 6 + lfrom + 3 + ldate
  local l2 = 9 + lsubject
  local l3 = l1 > l2 and lfrom or (l2 -ldate -9)
  local tab = {string.rep ("-", math.max (l1, l2)).."\n"}
  for k, mail in ipairs (mails) do
    tab[#tab+1] = string.format (markup.bold ("From:").." %-"..(l3).."s   %"..ldate.."s\n", truncate (mail.from, l3), mail.date)
    tab[#tab+1] = string.format (markup.bold ("Subject:").." %-"..lsubject.."s\n", truncate (mail.subject, math.max(l1, l2) - 9))
    tab[#tab+1] = string.format ("%s", string.rep ("-", math.max (l1, l2)))
    if k ~= #mails and k ~= notmuch.max_notif then
      tab[#tab] = tab[#tab] .. "\n"
    elseif k == notmuch.max_notif and k ~= #mails then
      tab[#tab+1] = string.format ("\nAnd %d more...", #mails - k)
      break
    end
  end

  local message = table.concat (tab)
  return message
end

-- TODO: Change new mail determination
local function get_new_mails (old_list, new_list)
  local get_ids = function (v) return v.id end
  local set = function (l)
    local set = {}
    for _, v in ipairs (l) do set[v] = true end
    return set
  end
  local old_ids = functional.map (get_ids, old_list)
  local new_ids = functional.map (get_ids, new_list)
  local old_set = set (old_ids)
  local news = {}
  for _, v in ipairs (new_ids) do
    if not old_set[v] then
      news[#news+1] = v
    end
  end
  local new_set = set (news)
  return functional.filter (function (v) return new_set[v.id] end, new_list)
end

local function update (notmuch)
  local cmd = "notmuch search tag:unread"
  local theme = notmuch.theme
  notmuch.old_mails = notmuch.mails
  awful.spawn.easy_async (
    cmd,
    function (stdout, stderr, reason, exit_code)

      notmuch.mails = get_mails (stdout, stderr, reason, exit_code)

      local text = notmuch.widget_text
      local wicon = notmuch.widget_icon

      if #notmuch.mails == 0 then
        text:set_text ("")
        wicon:set_image (notmuch.icon)
      else
        local nb = functional.fold_left (
          function (a, b) return a + b.nb end
          , 0, notmuch.mails
                                  )
        nb = math.floor (nb)
        text:set_markup (
          markup.markup {
            fg = theme.fg_normal,
            font = theme.font,
            tostring (nb)
          }
        )
        wicon:set_image (notmuch.icon_new)
      end
      if notmuch.old_mails then
        notmuch.new_mails = get_new_mails (notmuch.old_mails, notmuch.mails)
      else
        notmuch.new_mails = {}
      end
      if #notmuch.new_mails > 0 then
        local message = get_message (notmuch, notmuch.new_mails)

        notmuch.notification = naughty.notify {
          preset = notmuch.notification_preset,
          text = message,
          title = string.format ("%d new mail(s) !", #notmuch.new_mails),
          timeout = 7
        }
      end
  end)
end

local function notify (notmuch)
  if #notmuch.mails == 0 then return end
  local message = get_message (notmuch, nil)

  notmuch.notification = naughty.notify {
    preset = notmuch.notification_preset,
    text = message,
    title = string.format ("%d unread threads(s)", #notmuch.mails)
  }
end

local function factory (args, theme)

  notmuch = {}

  notmuch.mails = nil

  notmuch.timeout = args.timeout or 15
  notmuch.theme = theme
  notmuch.notification = nil
  notmuch.icon = theme.widget_mail or helpers.icons_dir .. "mail.png"
  notmuch.icon_new = theme.widget_mail_on or helpers.icons_dir .. "mail_on.png"

  notmuch.max_notif = args.max_notif or 5
  notmuch.lmax = args.lmax or 40

  -- notmuch.color1 = "#37364c"
  notmuch.color1 = "#99a6c4"
  notmuch.color2 = "#93014a"

  notmuch.notification_preset = args.notification_preset or {
    title = "New mails",
    bg = theme.bg_normal,
    fg = theme.fg_normal,
    font = "Monospace 10",
    timeout = 0
  }

  -- {{{ SETUP OF THE WIDGET
  notmuch.widget_text = wibox.widget {
    text = "",
    widget = wibox.widget.textbox
  }

  notmuch.widget_icon = wibox.widget {
    image = notmuch.icon,
    resize = true,
    widget = wibox.widget.imagebox
  }

  notmuch.widget = wibox.widget {
    notmuch.widget_icon,
    {
      notmuch.widget_text,
      left = dpi(4),
      right = dpi(4),
      widget = wibox.container.margin,
    },
    layout = wibox.layout.align.horizontal,
  }
  -- }}}

  -- Init
  update (notmuch)
  -- }}}

  -- {{{ SETUP OF THE TIMER
  local update = curry (update, notmuch)
  notmuch.update = update
  notmuch.timer = timer {timeout = notmuch.timeout}
  notmuch.timer:start ()
  notmuch.timer:connect_signal ("timeout", update)
  -- }}}

  local notify = curry (notify, notmuch)
  notmuch.notify = notify

  notmuch.widget:connect_signal("mouse::enter", notify)
  notmuch.widget:connect_signal("mouse::leave", function()
                                 naughty.destroy(notmuch.notification) end)

  return notmuch
end

local widget = {
  factory = factory
}

return widget
