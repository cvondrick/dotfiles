-- Create a new Neovim plugin
local M = {}

local ns = vim.api.nvim_create_namespace("py2tmux")

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Function to get the text in visual mode
local function get_visual_selection(start_pos, end_pos)
  -- Get the full lines between the starting and ending positions
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  -- Filter out empty lines and trim whitespace
  local non_empty_lines = {}
  for _, line in ipairs(lines) do
    local trimmed_line = trim(line)
    if trimmed_line ~= "" then
      table.insert(non_empty_lines, trimmed_line)
    end
  end

  return table.concat(non_empty_lines, "\n")
end

-- Function to get the text of the current code block using Treesitter
local function get_treesitter_block()
  local ts_utils = require("nvim-treesitter.ts_utils")
  local node = ts_utils.get_node_at_cursor()

  if node:type() == "module" then
    return ""
  end

  while true do
    if node:parent():type() ~= "module" then
      node = node:parent()
    else
      break
    end
  end

  local start_row, start_col, end_row, end_col = node:range()

  local lines = vim.fn.getline(start_row + 1, end_row + 1)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)

  if start_row == end_row then
    -- Expand to include non-empty lines above the start_row
    local current_row = start_row
    while current_row > 0 do
      local line = vim.fn.getline(current_row)
      if line:gsub("%s+", "") == "" then
        break
      end
      table.insert(lines, 1, line)
      start_row = start_row - 1
      current_row = start_row
    end

    -- Expand to include non-empty lines below the end_row
    current_row = end_row + 2
    local total_lines = vim.fn.line("$")
    while current_row <= total_lines do
      local line = vim.fn.getline(current_row)
      if line:gsub("%s+", "") == "" then
        break
      end
      table.insert(lines, line)
      end_row = end_row + 1
      current_row = current_row + 1
    end
  end

  -- Filter out empty lines
  local non_empty_lines = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(non_empty_lines, line)
    end
  end

  --vim.highlight.range(0, ns, 'IncSearch', { start_row, 0 }, { end_row + 1, 0 }, { timeout = 150 })
  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns, start_row, 0, {
    end_line = end_row + 1,
    hl_group = "IncSearch",
    hl_eol = true,
  })

  vim.defer_fn(function()
    vim.api.nvim_buf_del_extmark(0, ns, extmark_id)
  end, 150)

  -- Add an extra line at the end
  table.insert(non_empty_lines, "")

  return table.concat(non_empty_lines, "\n")
end

-- Function to collect necessary imports using LSP
local function collect_imports(text)
  -- WARN: not implemented yet!
end

-- Function to send text to the other tmux pane in chunks asynchronously
local function send_to_tmux(text)
  local chunk_size = 100 -- Define the chunk size

  local function get_python_pane_id()
    -- Get the list of panes with their corresponding running command
    local handle = io.popen("tmux list-panes -F '#{pane_id} #{pane_current_command}'")
    local panes = handle:read("*a")
    handle:close()

    for pane_id, command in panes:gmatch("(%S+) ([^\r\n]+)") do
      if command:lower() == "python" then
        return pane_id
      end
    end

    return nil
  end

  local python_pane_id = get_python_pane_id()

  if not python_pane_id then
    print("Error: No pane running Python found.")
    return
  end

  -- Split the text into chunks
  local function split_into_chunks(str, size)
    local chunks = {}
    for i = 1, #str, size do
      table.insert(chunks, str:sub(i, i + size - 1))
    end
    return chunks
  end

  local chunks = split_into_chunks(text, chunk_size)

  -- Function to send chunks recursively
  local function send_chunk(index)
    if index > #chunks then
      -- Send Enter key to execute the command
      --os.execute("tmux send-keys -t :.+ Enter")
      os.execute(string.format("tmux send-keys -t %s Enter", python_pane_id))
      return
    end

    local chunk = chunks[index]
    --local command = string.format("tmux send-keys -t :.+ '%s'", chunk:gsub("'", "'\\''"))
    local command = string.format("tmux send-keys -t %s '%s'", python_pane_id, chunk:gsub("'", "'\\''"))
    os.execute(command)

    -- Schedule the next chunk to be sent after 50ms
    vim.defer_fn(function()
      send_chunk(index + 1)
    end, 50)
  end

  -- Start sending chunks from the first one
  send_chunk(1)
end

-- Main function to handle text sending
function M.send_text(range)
  if vim.bo.filetype ~= "python" then
    print("SendToTmux is only available for Python files.")
    return
  end

  local text = ""

  if range > 0 then
    -- Get the visual selection range
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    text = get_visual_selection(start_pos, end_pos)
  else
    text = get_treesitter_block()
  end

  if text ~= "" then
    send_to_tmux(text)
  end
end

-- Create a command to trigger the plugin, accepting a range
vim.api.nvim_create_user_command("Py2Tmux", function(opts)
  M.send_text(opts.range)
end, { range = true })

return M
