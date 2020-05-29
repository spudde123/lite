local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

config.treeview_size = 200 * SCALE
local RootView = require "core.rootview"

local TreeView = View:extend()

local root_context_options = { "Create file", "Create directory" }
local dir_context_options = { "Create file", "Create directory", "Rename", "Delete" }
local file_context_options = { "Rename", "Delete" }
local option_index = 1

local function get_depth(filename)
  local n = 0
  for sep in filename:gmatch("[\\/]") do
    n = n + 1
  end
  return n
end


local TreeView = View:extend()

function TreeView:new()
  TreeView.super.new(self)
  self.scrollable = true
  self.focusable = false
  self.visible = true
  self.init_size = true
  self.context_menu_visible = false
  self.context_menu_item = nil
  self.cache = {}
end


function TreeView:get_cached(item)
  local t = self.cache[item.filename]
  if not t then
    t = {}
    t.filename = item.filename
    t.abs_filename = system.absolute_path(item.filename)
    t.path, t.name = t.filename:match("^(.*)[\\/](.+)$")
    t.depth = get_depth(t.filename)
    t.type = item.type
    self.cache[t.filename] = t
  end
  return t
end


function TreeView:get_name()
  return "Project"
end


function TreeView:get_item_height()
  return style.font:get_height() + style.padding.y
end


function TreeView:check_cache()
  -- invalidate cache's skip values if project_files has changed
  if core.project_files ~= self.last_project_files then
    for _, v in pairs(self.cache) do
      v.skip = nil
    end
    self.last_project_files = core.project_files
  end
end


function TreeView:each_item()
  return coroutine.wrap(function()
    self:check_cache()
    local ox, oy = self:get_content_offset()
    local y = oy + style.padding.y
    local w = self.size.x
    local h = self:get_item_height()

    local i = 1
    while i <= #core.project_files do
      local item = core.project_files[i]
      local cached = self:get_cached(item)

      coroutine.yield(cached, ox, y, w, h)
      y = y + h
      i = i + 1

      if not cached.expanded then
        if cached.skip then
          i = cached.skip
        else
          local depth = cached.depth
          while i <= #core.project_files do
            local filename = core.project_files[i].filename
            if get_depth(filename) <= depth then break end
            i = i + 1
          end
          cached.skip = i
        end
      end
    end
  end)
end


function TreeView:on_mouse_moved(px, py)
  if self.context_menu_visible then
    local margin = 100
    local cx, cy, cw, ch = self:get_context_rect(self.hovered_item)
    if px + margin < cx or px - margin > cx + cw or py + margin < cy or py - margin > cy + ch then
      self.context_menu_visible = false
      self.context_menu_item = false
    else
      local option_height = ch / #file_context_options
      for i, sym in ipairs(file_context_options) do
        if px > cx and px < cx + cw and py > cy + (i - 1)*option_height and py < cy + i*option_height then
          option_index = i
          break
        end
      end
    end
  else
    self.hovered_item = nil
    for item, x,y,w,h in self:each_item() do
      if px > x and py > y and px <= x + w and py <= y + h then
        self.hovered_item = item
        break
      end
    end
  end
end


function TreeView:on_mouse_pressed(button, x, y)
  if self.context_menu_visible then
    local cx, cy, cw, ch = self:get_context_rect(self.hovered_item)
    local option_height = ch / #file_context_options

    if x > cx and x < cx + cw and y > cy + (option_index - 1)*option_height and y < cy + option_index*option_height then
      if option_index == 1 then
        self:rename_selected_file()
      elseif option_index == 2 then
        self:delete_selected_file()
      end
    end
  else
    if not self.hovered_item then
      return
    end

    if button == "left" then
      if self.hovered_item.type == "dir" then
        self.hovered_item.expanded = not self.hovered_item.expanded
      else
        core.try(function()
          core.root_view:open_doc(core.open_doc(self.hovered_item.filename))
        end)
      end
    elseif button == "right" then
      self.context_menu_item = self.hovered_item
      self.context_menu_visible = true
    end
  end
end


function TreeView:update()
  -- update width
  local dest = self.visible and config.treeview_size or 0
  if self.init_size then
    self.size.x = dest
    self.init_size = false
  else
    self:move_towards(self.size, "x", dest)
  end

  TreeView.super.update(self)
end


function TreeView:draw()
  self:draw_background(style.background2)

  local icon_width = style.icon_font:get_width("D")
  local spacing = style.font:get_width(" ") * 2
  local root_depth = get_depth(core.project_dir) + 1

  local doc = core.active_view.doc
  local active_filename = doc and system.absolute_path(doc.filename or "")

  for item, x,y,w,h in self:each_item() do
    local color = style.text

    -- highlight active_view doc
    if item.abs_filename == active_filename then
      color = style.accent
    end

    -- hovered item background
    if item == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.accent
    end

    -- icons
    x = x + (item.depth - root_depth) * style.padding.x + style.padding.x
    if item.type == "dir" then
      local icon1 = item.expanded and "-" or "+"
      local icon2 = item.expanded and "D" or "d"
      common.draw_text(style.icon_font, color, icon1, nil, x, y, 0, h)
      x = x + style.padding.x
      common.draw_text(style.icon_font, color, icon2, nil, x, y, 0, h)
      x = x + icon_width
    else
      x = x + style.padding.x
      common.draw_text(style.icon_font, color, "f", nil, x, y, 0, h)
      x = x + icon_width
    end

    -- text
    x = x + spacing
    x = common.draw_text(style.font, color, item.name, nil, x, y, 0, h)
  end
end


function TreeView:get_context_rect(hovered_item)
  local th = style.font:get_height()

  local max_width = 0
  for i, sym in ipairs(file_context_options) do
    max_width = math.max(max_width, style.font:get_width(sym))
  end

  for item, x,y,w,h in self:each_item() do
    if item == hovered_item then
      return
        x + w*0.5 - style.padding.x,
        y - style.padding.y,
        max_width + style.padding.x * 2,
        #file_context_options * (th + style.padding.y) + style.padding.y
    end
  end

  return 0, 0, 0, 0
end

function TreeView:draw_context_box()
  if not self.hovered_item then
    return
  end

  -- draw background rect
  local rx, ry, rw, rh = self:get_context_rect(self.hovered_item)
  renderer.draw_rect(rx, ry, rw, rh, style.background3)

  -- draw text
  local th = style.font:get_height()
  local x, y = rx + style.padding.x, ry + style.padding.y
  for i, sym in ipairs(file_context_options) do
    local color = (i == option_index) and style.accent or style.text
    renderer.draw_text(style.font, sym, x, y, color)
    y = y + th + style.padding.y
  end
end

-- init
local view = TreeView()
local node = core.root_view:get_active_node()
node:split("left", view, true)

-- register commands and keymap
command.add(nil, {
  ["treeview:toggle"] = function()
    view.visible = not view.visible
  end,
})

keymap.add { ["ctrl+b"] = "treeview:toggle" }

local function context_predicate()
  return view.context_menu_visible
end

function TreeView:rename_selected_file()
  self.context_menu_visible = false
  local old_filename = self.context_menu_item.filename
  core.log("Old filename %s", old_filename)
  if not old_filename then
    core.error("Cannot rename unsaved doc")
    return
  end
  core.command_view:set_text(old_filename)
  core.command_view:enter("Rename", function(filename)
    core.log("Saving new file")
    local file = core.open_doc(old_filename)
    file:save(filename)

    core.log("Renamed \"%s\" to \"%s\"", old_filename, filename)
    if filename ~= old_filename then
      os.remove(old_filename)
    end

    self.context_menu_item = nil
  end, common.path_suggest)
end

function TreeView:delete_selected_file()
  local filename = self.context_menu_item.filename
  if not filename then
    core.error("Can't remove unsaved doc")
    return
  end

  -- Should close the tab here if open
  os.remove(filename)
  self.context_menu_visible = false
  self.context_menu_item = nil
end

command.add(context_predicate, {
  ["context:select"] = function()
    if option_index == 1 then
      view:rename_selected_file()
    elseif option_index == 2 then
      view:delete_selected_file()
    end
  end,
  ["context:previous"] = function()
    option_index = math.max(option_index - 1, 1)
  end,
  ["context:next"] = function()
    option_index = math.min(option_index + 1, #file_context_options)
  end,
  ["context:cancel"] = function()
    view.context_menu_visible = false
    view.context_menu_item = nil
  end,
})


keymap.add {
  ["return"] = "context:select",
  ["up"]     = "context:previous",
  ["down"]   = "context:next",
  ["escape"] = "context:cancel",
}

local draw = RootView.draw

RootView.draw = function(...)
  draw(...)

  -- draw options box after everything else
  if view.context_menu_visible then
    core.root_view:defer_draw(TreeView.draw_context_box, view)
  end
end

--[[
RootView.update = function(...)
  update(...)

  local av = get_active_view()
  if av then
    -- reset suggestions if caret was moved
    local line, col = av.doc:get_selection()
    if line ~= last_line or col ~= last_col then
      reset_suggestions()
    end
  end
end
--]]


