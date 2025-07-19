local M = {}

local ns = vim.api.nvim_create_namespace("chat")

local function dbg(str)
  vim.cmd("vsplit")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  local lines = vim.split(str, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Function to get the text in visual mode
local function get_visual_selection(start_pos, end_pos)
  -- Get the full lines between the starting and ending positions
  local lines = vim.fn.getline(start_pos[2], end_pos[2])
  return table.concat(lines, "\n")
end

vim.fn.sign_define(
  "ChatSign",
  { text = "»", texthl = "DiagnosticOk", numhl = "DiagnosticOk" }
)

-- Main function to handle text sending
function M.Chat(range)
  local ctx = ""

  local cur_buf = vim.api.nvim_get_current_buf()

  local extmark_id
  local outfile

  if range > 0 then
    -- Get the visual selection range
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    ctx = get_visual_selection(start_pos, end_pos)

    -- extmark_id = vim.api.nvim_buf_set_extmark(cur_buf, ns, start_pos[2] - 1, 0, {
    --   end_line = end_pos[2],
    --   hl_group = "Visual",
    --   hl_eol = true,
    -- })

    for i = start_pos[2], end_pos[2] - 1 do
      vim.fn.sign_place(0, "ChatSign", "ChatSign", cur_buf, { lnum = i, priority = 100 })
    end
  else
    local all = vim.fn.getline(1, "$")

    for i = 1, #all - 1 do
      vim.fn.sign_place(0, "ChatSign", "ChatSign", cur_buf, { lnum = i, priority = 100 })
    end

    ctx = table.concat(all, "\n")
  end

  local ctxfile = vim.fn.tempname() .. ".ctx"
  outfile = vim.fn.tempname() .. ".out"

  local file = io.open(ctxfile, "w")
  if file ~= nil then
    file:write(ctx)
    file:flush()
    file:close()
  else
    print("Could not write to file")
    return
  end

  local filetype = vim.bo.filetype
  local cmd =
    string.format("python3 /Users/vondrick/projs/chat.py --ctx %s --out %s --filetype %s", ctxfile, outfile, filetype)

  -- local popup_id = require("detour").Detour() -- open a detour popup
  -- if not popup_id then
  --   return
  -- end

  vim.cmd.split()
  vim.cmd.terminal(cmd) -- open a terminal buffer
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.bo.bufhidden = "delete" -- close the terminal when window closes
  --vim.wo[popup_id].signcolumn = "no" -- In Neovim 0.10, the signcolumn can push the TUI a bit out of window

  -- It's common for people to have `<Esc>` mapped to `<C-\><C-n>` for terminals.
  -- This can get in the way when interacting with TUIs.
  -- This maps the escape key back to itself (for this buffer) to fix this problem.
  --vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = true })

  vim.cmd.startinsert() -- go into insert mode

  vim.api.nvim_create_autocmd({ "TermClose" }, {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
      -- This automated keypress skips for you the "[Process exited 0]" message
      -- that the embedded terminal shows.
      vim.api.nvim_feedkeys("i", "n", false)

      local outfd = io.open(outfile, "r")
      if outfd ~= nil then
        local content = outfd:read("*all")
        file:close()
        vim.fn.setreg('"', content)
      else
        print("Could not read from file " .. outfile)
      end

      if extmark_id then
        vim.api.nvim_buf_del_extmark(cur_buf, ns, extmark_id)
        extmark_id = nil
      end

      vim.fn.sign_unplace("ChatSign", { buffer = cur_buf })

      os.remove(ctxfile)
      os.remove(outfile)
    end,
  })
end

-- Create a command to trigger the plugin, accepting a range
vim.api.nvim_create_user_command("Chat", function(opts)
  M.Chat(opts.range)
end, { range = true })

return M
