-- put user settings here
-- this module will be loaded after everything else when the application starts

local common = require "core.common"
local keymap = require "core.keymap"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"
local translate = require "core.doc.translate"

-- light theme:
require "user.colors.summer"

style.scrollbar_size = common.round(12 * SCALE)

-- key binding:
keymap.add { ["ctrl+m"] = "doc:rename" }
keymap.add { ["ctrl+shift+r"] = "core:reload-module" }
keymap.add { ["ctrl+shift+p"] = "core:open-project-module" }
keymap.add { ["ctrl+l"] = "core:open-log" }

-- Copied from docview and modified
function DocView:on_mouse_pressed(button, x, y, clicks)
  local caught = DocView.super.on_mouse_pressed(self, button, x, y, clicks)
  if caught then
    return
  end
  local line, col = self:resolve_screen_position(x, y)
  if clicks == 2 then
    local line1, col1 = translate.start_of_word(self.doc, line, col)
    local line2, col2 = translate.end_of_word(self.doc, line, col)
    self.doc:set_selection(line2, col2, line1, col1)
  elseif clicks == 3 then
    self.doc:set_selection(line + 1, 1, line, 1)
  elseif clicks == 1 and keymap.modkeys["shift"] == true then
    local old_line, old_col = self.doc:get_selection()
    self.doc:set_selection(old_line, old_col, line, col)
  else
    self.doc:set_selection(line, col)
    self.mouse_selecting = true
  end
  self.blink_timer = 0
end
