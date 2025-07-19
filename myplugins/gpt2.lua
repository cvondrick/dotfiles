local M = {}

local plenary = require("plenary.job")
local ns_id = vim.api.nvim_create_namespace("gpt4")
local dmp = require("myplugins/diff_match_patch")

local ts_utils = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")

local api_key = nil

local comment_start = "#"

local system_prompt =
  [[Act as an expert %s software developer. Always use best practices when coding. Respect and use existing conventions, libraries, etc that are already present in the code base. Take requests for changes to the supplied code. Always reply to the user in the same language they are using. For each file that needs to be changed, write out the changes similar to a unified diff like `diff -U0` would produce.]]

local example_msgs = {
  { role = "user", content = "Replace is_prime with a call to sympy." },
  {
    role = "assistant",
    content = [[Ok, I will:

1. Add an imports of sympy.
2. Remove the is_prime() function.
3. Replace the existing call to is_prime() with a call to sympy.isprime().

Here are the diffs for those changes:

```diff
--- app.py
+++ app.py
@@ ... @@
-class MathWeb:
+import sympy
+
+class MathWeb:
@@ ... @@
-def is_prime(x):
-    if x < 2:
-        return False
-    for i in range(2, int(math.sqrt(x)) + 1):
-        if x % i == 0:
-            return False
-    return True
@@ ... @@
-@app.route('/prime/<int:n>')
-def nth_prime(n):
-    count = 0
-    num = 1
-    while count < n:
-        num += 1
-        if is_prime(num):
-            count += 1
-    return str(num)
+@app.route('/prime/<int:n>')
+def nth_prime(n):
+    count = 0
+    num = 1
+    while count < n:
+        num += 1
+        if sympy.isprime(num):
+            count += 1
+    return str(num)
```
    ]],
  },
}

local system_prompt_reminder = [[# File editing rules:

Return edits similar to unified diffs that `diff -U0` would produce.

Make sure you include the first 2 lines with the file paths.
Don't include timestamps with the file paths.

Very important: Start each hunk of changes with a `@@ ... @@` line. 
Don't include line numbers like `diff -U0` does.
The user's patch tool doesn't need them.

The user's patch tool needs CORRECT patches that apply cleanly against the current contents of the file!
Think carefully and make sure you include and mark all lines that need to be removed or changed as `-` lines.
Make sure you mark all new or modified lines with `+`.
Don't leave out any lines or the diff patch won't apply correctly.

Indentation matters in the diffs!

Start a new hunk for each section of the file that needs changes.

ONLY output hunks that specify changes with `+` or `-` lines.
Skip any hunks that are entirely unchanging ` ` lines. NEVER output hunks that are entirely ` ` lines.

Output hunks in whatever order makes the most sense.
Hunks don't need to be in any particular order.

When editing a function, method, loop, etc use a hunk to replace the *entire* code block.
Delete the entire existing version with `-` lines and then add a new, updated version with `+` lines.
This will help you generate correct code and correct diffs.

To move code within a file, use 2 hunks: 1 to delete it from its current location, 1 to insert it in the new location.]]

function M.set_api_key(key)
  api_key = key
end

local function display_message(message)
  vim.cmd("redraw")
  vim.cmd('echo " ' .. message .. '"')
end

-- Function to send request to OpenAI GPT-4 API
local function send_request(code, prompt, filetype)
  local curl = require("plenary.curl")

  -- Change the status message to show "Generating..."
  display_message("Generating...")

  local msgs = {
    { role = "system", content = string.format(system_prompt, filetype) .. "\n" .. system_prompt_reminder },
  }

  for _, example_msg in ipairs(example_msgs) do
    table.insert(msgs, example_msg)
  end

  table.insert(msgs, {
    role = "user",
    content = "I switched to a new code base. Please don't consider the above files or try to edit them any longer.",
  })

  table.insert(msgs, { role = "assistant", content = "OK." })

  table.insert(msgs, { role = "user", content = code })

  table.insert(msgs, { role = "user", content = prompt })

  table.insert(msgs, { role = "user", content = system_prompt_reminder })

  local response = curl.post("https://api.openai.com/v1/chat/completions", {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key,
    },
    body = vim.fn.json_encode({
      model = "gpt-4o-mini",
      messages = msgs,
      temperature = 1,
      max_tokens = 10000,
      top_p = 1,
      frequency_penalty = 0,
      presence_penalty = 0,
    }),
  })

  -- Restore the previous status message (if needed, implement accordingly)
  display_message("Done.")

  local result = vim.fn.json_decode(response.body)
  return result.choices[1].message.content
end

-- Function to extract code from response
local function extract_code(response)
  -- Match the code block in markdown format

  local code = response:match("```[a-z]*\n(.-)\n```")
  code = code or response -- Return the code if found, otherwise return the whole response

  return vim.split(code, "\n")
end

-- Function to compute line-level diff using diff_match_patch
local function compute_line_diff(original_lines, new_lines)
  local diffs = dmp.diff_main(table.concat(original_lines, "\n"), table.concat(new_lines, "\n"))
  dmp.diff_cleanupSemantic(diffs)

  return diffs
end

-- Function to select the inserted text in visual mode
local function select_inserted_text(start_line, num_lines)
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal! v" .. num_lines .. "j")
end

local function chunk_code(costs, max_length)
  local function optimize(costs, max_length)
    local n = #costs
    local dp = {}
    local break_point = {}

    -- Initialize dp array and break points
    for i = 0, n do
      dp[i] = math.huge
      break_point[i] = -1
    end

    dp[0] = 0

    for i = 1, n do
      for j = math.max(0, i - max_length), i - 1 do
        local cost = costs[i]
        if dp[j] + cost < dp[i] then
          dp[i] = dp[j] + cost
          break_point[i] = j
        end
      end
    end

    -- Reconstruct breaks
    local breaks = {}
    local i = n
    while i > 0 do
      table.insert(breaks, 1, i)
      i = break_point[i]
    end

    table.insert(breaks, 1, 0)

    return breaks
  end

  function pair_chunks(chunks)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local stripped_chunks = {}
    for i = 2, #chunks do
      local start_of_chunk = chunks[i - 1]
      local end_of_chunk = chunks[i]

      while start_of_chunk < #lines and lines[start_of_chunk + 1]:gsub("^%s*(.-)%s*$", "%1") == "" do
        start_of_chunk = start_of_chunk + 1
      end
      while end_of_chunk > 1 and lines[end_of_chunk]:gsub("^%s*(.-)%s*$", "%1") == "" do
        end_of_chunk = end_of_chunk - 1
      end

      if start_of_chunk < end_of_chunk then
        table.insert(stripped_chunks, { start_of_chunk, end_of_chunk })
      end
    end
    return stripped_chunks
  end

  local boundaries = optimize(costs, max_length)
  local pairs = pair_chunks(boundaries)

  return pairs
end

-- Function to create cost table based on treesitter parsing
local function create_cost_table()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = parsers.get_parser(bufnr)

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find the first non-empty line
  local first_non_empty_line = 0
  for i, line in ipairs(lines) do
    if line:match("%S") then -- Check if the line contains any non-whitespace character
      first_non_empty_line = i - 1
      break
    end
  end

  local root = ts_utils.get_root_for_position(first_non_empty_line, 0, parser)

  local cost_table = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Initialize cost table with default cost
  for i = 1, #lines do
    cost_table[i] = 1000000
  end
  cost_table[0] = 0 -- Always break at the very beginning of the file
  cost_table[#lines] = 0 -- also at the very end

  local function get_node_cost(node)
    local node_type = node:type()

    if node_type == "class_definition" then
      return 0
    elseif node_type == "function_definition" then
      local parent = node:parent()
      while parent and parent:type() ~= "class_definition" do
        parent = parent:parent()
      end
      if parent and parent:type() == "class_definition" then
        return 1
      else
        return 0
      end
    elseif node_type == "if_statement" or node_type == "for_statement" or node_type == "while_statement" then
      return 10
    else
      return 10
    end
  end

  local function set_cost(node, cost)
    local start_row, _, end_row, _ = node:range()
    cost_table[start_row] = cost_table[start_row] < cost and cost_table[start_row] or cost
    cost_table[end_row + 1] = cost_table[end_row + 1] < cost and cost_table[end_row + 1] or cost
  end

  local function set_costs_recursive(node, indent)
    if indent == nil then
      indent = 0
    end

    for child in node:iter_children() do
      local child_cost = get_node_cost(child)
      set_cost(child, child_cost)

      --print(string.rep(" ", indent) .. child:type() .. " " .. child_cost)

      if child:child_count() > 0 then
        set_costs_recursive(child, indent + 1)
      end
    end
  end

  set_costs_recursive(root)

  return cost_table
end

local function chunk_buffer(chunks)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local output = {}

  for chunk = 1, #chunks do
    local first = true
    for i = chunks[chunk][1] + 1, chunks[chunk][2] do
      if first then
        table.insert(output, lines[i] .. ' ' .. comment_start .. " Line " .. i)
        first = false
      else
        table.insert(output, lines[i])
      end
    end
    --table.insert(output, comment_start .. " END CHUNK " .. chunk)
  end

  return output
end

local function apply_patch(patch)
  local bufnr = vim.api.nvim_get_current_buf()
  local input = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Function to parse the patch file
  local function parse_patch(patch)
    local diffs = {}
    local current_diff = nil
    for _, line in ipairs(patch) do
      if line:match("^%-%-%-") or line:match("^%+%+%+") then
        -- skip line
      elseif line:match("^@@") then
        if current_diff then
          table.insert(diffs, current_diff)
        end
        current_diff = { adds = {}, removes = {}, matched = false }
      elseif line:match("^%+") then
        local cont = line:sub(2):gsub("%s*# Line %d+$", "")
        table.insert(current_diff.adds, cont)
      elseif line:match("^%-") then
        local cont = line:sub(2):gsub("%s*# Line %d+$", "")
        table.insert(current_diff.removes, cont)
      end
    end
    if current_diff then
      table.insert(diffs, current_diff)
    end
    return diffs
  end

  local function table_range(tbl, start_idx, end_idx)
    local range = {}
    for i = start_idx, end_idx do
      table.insert(range, tbl[i])
    end
    return range
  end

  -- Function to apply the patch
  local function execute(input, patch)
    local diffs = parse_patch(patch)

    for _, diff in ipairs(diffs) do
      assert(#diff.removes > 0, "No lines to remove in diff. This is a bug.")

      local i = 1
      while i <= #input do
        local matched = true
        for j, line in ipairs(diff.removes) do
          if input[i + j - 1] ~= line then
            matched = false
            break
          end
        end

        if matched then
          for j = 1, #diff.removes do
            table.remove(input, i)
          end
          for j, line in ipairs(diff.adds) do
            table.insert(input, i + j - 1, line)
          end

          diff.start_line = i
          diff.end_line = i + #diff.removes
          diff.matched = true

          vim.api.nvim_buf_set_lines(bufnr, diff.start_line - 1, diff.end_line - 1, false, diff.adds)

          i = i + #diff.adds
        else
          i = i + 1
        end
      end
    end

    return diffs
  end

  return execute(input, patch)
end

local function visualize_patch(patch)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Define the new highlight group
  vim.api.nvim_set_hl(0, "LightGreenBackground", { bg = "#2a4734", fg = "NONE" }) -- Light green background
  vim.api.nvim_set_hl(0, "LightGreenForeground", { bg = "NONE", fg = "#73c991" }) -- Light green foreground

  for _, diff in ipairs(patch) do

    print(vim.inspect(diff))

    if not diff.matched then
      print('----')
      print('failed to match:')
      print(vim.inspect(diff))
      print('----')
    end

    local hunk_diff = compute_line_diff(diff.removes, diff.adds)

    local current_line = diff.start_line - 1
    local col_offset = 0

    for _, word_diff in ipairs(hunk_diff) do
      local operation, text = word_diff[1], word_diff[2]

      for line in text:gmatch("[^\n]*\n?") do
        if operation == dmp.DIFF_EQUAL then
          col_offset = col_offset + #line
          if line:sub(-1) == "\n" then
            current_line = current_line + 1
            col_offset = 0
          end
        elseif operation == dmp.DIFF_INSERT then
          -- Replace DiffAdd with LightGreenBackground
          vim.api.nvim_buf_add_highlight(
            bufnr,
            ns_id,
            "LightGreenBackground",
            current_line,
            col_offset,
            col_offset + #line
          )

          -- Highlight the line number itself in green
          vim.fn.sign_define("MySign", { text = "󰚉", texthl = "LightGreenForeground" })
          vim.fn.sign_place(0, ns_id, "MySign", bufnr, { lnum = current_line + 1 })

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
  end
end

local function log(filename, message)
  local file = io.open(filename, "w")
  file:write(message .. "\n")
  file:close()
end

-- Main function to handle text sending
function M.GPTDo(range)
  local mode = vim.fn.mode()
  local filetype = vim.bo.filetype -- Get the filetype of the current file
  local start_pos, end_pos
  local text = ""

  if range > 0 then
    -- Get the visual selection range
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  else
    -- Set the range to the entire buffer
    start_pos = { 0, 1, 0, 0 } -- starting from line 1, column 0
    end_pos = { 0, vim.fn.line("$"), 0, 0 } -- end at the last line, column 0
  end

  local costs = create_cost_table()

  local chunks = chunk_code(costs, 10)

  local chunked_code = chunk_buffer(chunks)

  vim.ui.input({ prompt = range > 0 and "Prompt (Selection): " or "Prompt: " }, function(input)
    if input then
      local result = send_request(table.concat(chunked_code, "\n"), input, filetype)
      patch = extract_code(result)

      -- WARN: turn this off
      log("/tmp/input.txt", table.concat(chunked_code, "\n"))
      log("/tmp/reply.txt", table.concat(patch, "\n"))

      patch = apply_patch(patch)

      vim.schedule(function()
        visualize_patch(patch)
      end)
    else
      print("Prompt cancelled.")
    end
  end)
end

-- Create a command to trigger the plugin, accepting a range
vim.api.nvim_create_user_command("GPT", function(opts)
  M.GPTDo(opts and opts.range or nil)
end, { range = true })

return M
