local M = {}

local plenary = require("plenary.job")
local ns_id = vim.api.nvim_create_namespace("gpt4")
local dmp = require("myplugins/diff_match_patch")

local api_key = nil

local system_prompts = {
  replace = "Make the requested modification. Do not include changes unrequested by me. If I don't ask for changes to some part of the code, still include it in the code block.",
  insert = "Make the requested modifications based on the context. You cannot change the context code. Do not output the context code again. If you have nothing to say, output an empty code block.",
  chat = "Engage in a natural language conversation while providing relevant code snippets when appropriate. Keep the discussion informative and friendly."
}

function M.set_api_key(key)
  api_key = key
end

-- Function to get the text in visual mode
local function get_visual_selection(start_pos, end_pos)
  -- Get the full lines between the starting and ending positions
  local lines = vim.fn.getline(start_pos[2], end_pos[2])
  return table.concat(lines, "\n")
end

local function show_write_message(message)
  vim.cmd('redraw')
  vim.cmd('echo "' .. message .. '"')
end

-- Function to send request to OpenAI GPT-4 API
local function send_request(code, prompt, system_prompt_key, filetype)
  local curl = require("plenary.curl")
  local system_prompt = system_prompts[system_prompt_key]

  -- Change the status message to show "Generating..."
  show_write_message("Generating...")

  local response = curl.post("https://api.openai.com/v1/chat/completions", {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
    },
    body = vim.fn.json_encode({
      model = "gpt-4o-mini",
      messages = {
        {
          role = "system",
          content = system_prompt .. ' The filetype is ' .. filetype
        },
        {
          role = "user",
          content = code
        },
        {
          role = "user",
          content = prompt
        },
      },
      temperature = 1,
      max_tokens = 10000,
      top_p = 1,
      frequency_penalty = 0,
      presence_penalty = 0,
    }),
  })

  -- Restore the previous status message (if needed, implement accordingly)
  show_write_message("")

  local result = vim.fn.json_decode(response.body)
  return result.choices[1].message.content
end

-- Function to extract code from response
local function extract_code(response)
  -- Match the code block in markdown format
  
  local code = response:match("```[a-z]*\n(.-)\n```")
  return code or response  -- Return the code if found, otherwise return the whole response
end

-- Function to compute line-level diff using diff_match_patch
local function compute_line_diff(original_lines, new_lines)
  local diffs = dmp.diff_main(table.concat(original_lines, "\n"), table.concat(new_lines, "\n"))
  dmp.diff_cleanupSemantic(diffs)

  return diffs
end

-- Apply highlights for added text
local attached_buffers = {}
local highlighted_lines = {}

local function apply_highlights(bufnr, diffs, start_line)
  local current_line = start_line - 1
  local col_offset = 0

  -- Define the new highlight group
  vim.api.nvim_set_hl(0, "LightGreenBackground", { bg = "#2a4734", fg = "NONE" })  -- Light green background
  vim.api.nvim_set_hl(0, "LightGreenForeground", { bg = "NONE", fg = "#73c991" })  -- Light green foreground

  for _, diff in ipairs(diffs) do
    local operation, text = diff[1], diff[2]

    for line in text:gmatch("[^\n]*\n?") do
      if operation == dmp.DIFF_EQUAL then
        col_offset = col_offset + #line
        if line:sub(-1) == "\n" then
          current_line = current_line + 1
          col_offset = 0
        end
      elseif operation == dmp.DIFF_INSERT then
        -- Replace DiffAdd with LightGreenBackground
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "LightGreenBackground", current_line, col_offset, col_offset + #line)

        -- Highlight the line number itself in green
        vim.fn.sign_define('MySign', { text = '┃', texthl = 'LightGreenForeground' }) 
        vim.fn.sign_place(0, ns_id, 'MySign', bufnr, { lnum = current_line + 1 })

        table.insert(highlighted_lines, current_line)  -- Track highlighted lines
        col_offset = col_offset + #line
        if line:sub(-1) == "\n" then
          current_line = current_line + 1
          col_offset = 0
        end
      elseif operation == dmp.DIFF_DELETE then
        -- if line:sub(-1) == "\n" then
        --   current_line = current_line + 1
        --   col_offset = 0
        -- end
      end
    end
  end

  -- Clear highlights if the user modifies the buffer and the modification is in the highlighted lines
  if not attached_buffers[bufnr] then
    attached_buffers[bufnr] = true
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, changed_bufnr, _, first_changed_line, last_changed_line)
        for line_number = first_changed_line, last_changed_line do
          if vim.tbl_contains(highlighted_lines, line_number) then
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_number, line_number + 1)
            -- Optionally remove the line from highlighted_lines if necessary
            highlighted_lines[line_number] = nil
          end
        end
      end
    })
  end
end

-- Function to select the inserted text in visual mode
local function select_inserted_text(start_line, num_lines)
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal! v" .. num_lines .. "j")
end

-- Function to replace visual selection with GPT-4 response and highlight changes
local function replace_selection_with_gpt4(prompt, selection, start_pos, end_pos, filetype)
  local response = send_request(selection, prompt, "replace", filetype)
  local code = extract_code(response)

  local bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Get the original text from the buffer
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)
  local original_text = table.concat(original_lines, "\n")

  -- Split the new code into lines
  local new_lines = vim.split(code, "\n", true)

  -- Add a comment with the prompt at the beginning
  --table.insert(new_lines, 1, "#vimgpt: " .. prompt) # TODO: add better chat history and conceal it as a comment in the files. This could work a lot better
  --vim.cmd [[ syntax match VimgptConceal "^#vimgpt:.*" conceal cchar=§ ]]

  if original_lines[#original_lines] == "" then
    table.insert(new_lines, "")
  end

  -- Compute line-level diffs
  local diffs = compute_line_diff(original_lines, new_lines)

  -- Replace the selected lines with the new code
  vim.api.nvim_buf_set_lines(bufnr, start_pos[2] - 1, end_pos[2], false, new_lines)

  -- Apply highlights to the added text after setting the buffer lines
  vim.schedule(function()
    apply_highlights(bufnr, diffs, start_pos[2])
    -- Select the newly inserted text in visual mode
    --select_inserted_text(start_pos[2], #new_lines)
  end)
end

-- Function to insert GPT-4 response at cursor position
local function insert_at_cursor(prompt, cursor_line, filetype)
  local bufnr = vim.api.nvim_get_current_buf()
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) -- Get entire buffer content as code
  local code = table.concat(original_lines, "\n")

  local response = send_request(code, prompt, "insert", filetype)
  local new_code = extract_code(response)

  -- Split the new code into lines
  local new_lines = vim.split(new_code, "\n", true)

  -- Insert the new code at the cursor line
  vim.api.nvim_buf_set_lines(bufnr, cursor_line - 1, cursor_line - 1, false, new_lines)

  -- Apply highlights to the added text after setting the buffer lines
  vim.schedule(function()
    apply_highlights(bufnr, { {1, new_code} }, cursor_line)
    -- Select the newly inserted text in visual mode
    select_inserted_text(cursor_line, #new_lines)
  end)
end

-- Function to display a floating window with some text
local function show_floating_window(text)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create a new buffer for the floating window
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set the buffer's lines
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))

  -- Create the floating window
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
  }
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Dismiss on Esc or q keypress
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<Cmd>close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<Cmd>close<CR>', { noremap = true, silent = true })
end

-- Function to get the text of the current code block using Treesitter
function M.select_block()
  local ts_utils = require 'nvim-treesitter.ts_utils'
  local node = ts_utils.get_node_at_cursor()

  if node:type() == 'module' then
    return ''
  end

  while true do
    if node:parent():type() ~= 'module' then
      node = node:parent()
    else
      break
    end
  end

  local start_row, start_col, end_row, end_col = node:range()

  -- Select the found node text in visual mode
  vim.api.nvim_command('normal! ' .. start_row + 1 .. 'G' .. start_col + 1 .. '|v' .. end_row + 1 .. 'G' .. (end_col + 1) .. '|')

  return vim.fn.getline(start_row + 1, end_row + 1) -- Return the lines as well if needed
end



-- Main function to handle text sending
function M.GPTReplace(range)
  local mode = vim.fn.mode()
  local filetype = vim.bo.filetype  -- Get the filetype of the current file
  local start_pos, end_pos
  local text = ""

  if range > 0 then
    -- Get the visual selection range
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  else
    -- Set the range to the entire buffer
    start_pos = { 0, 1, 0, 0 } -- starting from line 1, column 0
    end_pos = { 0, vim.fn.line('$'), 0, 0 } -- end at the last line, column 0
  end

  text = get_visual_selection(start_pos, end_pos)

  vim.ui.input({ prompt = range > 0 and "Replace Prompt: " or "Replace All Prompt: " }, function(input)
    if input then
      replace_selection_with_gpt4(input, text, start_pos, end_pos, filetype)
    else
      print("Prompt cancelled.")
    end
  end)
end

-- Function to handle chat with GPT-4
function M.GPTChat(range)
  local mode = vim.fn.mode()
  local filetype = vim.bo.filetype  -- Get the filetype of the current file
  local start_pos, end_pos
  local text = ""

  if range > 0 then
    -- Get the visual selection range
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  else
    -- Set the range to the entire buffer
    start_pos = { 0, 1, 0, 0 } -- starting from line 1, column 0
    end_pos = { 0, vim.fn.line('$'), 0, 0 } -- end at the last line, column 0
  end

  text = get_visual_selection(start_pos, end_pos)

  vim.ui.input({ prompt = range > 0 and "Chat Prompt: " or "Chat All Prompt: " }, function(input)
    if input then
      local response = send_request(text, input, "chat", filetype)
      show_floating_window(response)
    else
      print("Prompt cancelled.")
    end
  end)
end

-- Function to insert code at cursor position
function M.GPTInsert()
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {row, col}
  local cursor_line = cursor_pos[1]
  local filetype = vim.bo.filetype  -- Get the filetype of the current file

  vim.ui.input({ prompt = "Insert Prompt: " }, function(input)
    if input then
      insert_at_cursor(input, cursor_line, filetype)
    else
      print("Prompt cancelled.")
    end
  end)
end

-- Create a command to trigger the plugin, accepting a range
vim.api.nvim_create_user_command("GPTReplace", function(opts)
  M.GPTReplace(opts and opts.range or nil)
end, { range = true })

-- Create a command to trigger the GPTInsert function
vim.api.nvim_create_user_command("GPTInsert", function(opts)
  M.GPTInsert()
end, {})

-- Create a command to trigger the GPTChat function, accepting a range
vim.api.nvim_create_user_command("GPTChat", function(opts)
  M.GPTChat(opts and opts.range or nil)
end, { range = true })

-- Create a command to trigger the GPTChat function, accepting a range
vim.api.nvim_create_user_command("GPTSelectBlock", function(opts)
  M.select_block()
end, { range = true })


return M
