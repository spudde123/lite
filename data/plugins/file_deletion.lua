local command = require "core.command"
local keymap = require "core.keymap"
local core = require "core"

local commands = {
  ["doc:delete-file"] = function()
    local filename = core.active_view.doc.filename
    if not filename then
      core.error("Can't remove unsaved doc")
      return
    end

    local node = core.root_view:get_active_node()
    node:close_active_view(core.root_view.root_node)

    os.remove(filename)
  end,
}

command.add("core.docview", commands)
keymap.add { ["ctrl+delete"] = "doc:delete-file" }
