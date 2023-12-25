local curl = require('plenary.curl')


local M = {}
M.opts = {
  api_key = '',
  locale = 'en',
  alternate_locale = 'zh',
}

M.win_id = nil
M.bufnr = nil
local cur_win_width = vim.api.nvim_win_get_width(0)

-- ?
-- utility function
--
local function splitLines(input)
  local lines = {}
  local offset = 1
  while offset > 0 do
    local i = string.find(input, '\n', offset)
    if i == nil then
      table.insert(lines, string.sub(input, offset, -1))
      offset = 0
    else
      table.insert(lines, string.sub(input, offset, i - 1))
      offset = i + 1
    end
  end
  return lines
end

local function split_lines_with_width(lines, width)
  if width == nil then
    width = math.floor(cur_win_width/2)-10
  end

  local result = {}

  for _, line in ipairs(lines) do
    if #line == 0 then
      table.insert(result, line)
    end

    local start = 1
    while start <= #line do
      local end_index = start + width
      if end_index > #line then
        end_index = #line
      end

      table.insert(result, string.sub(line, start, end_index))
      start = end_index + 1
    end
  end

  return result
end

local function joinLines(lines)
  local result = ''
  for _, line in ipairs(lines) do
    result = result .. line
  end
  return result
end

local function isEmpty(text)
  return text == nil or text == ''
end

local function hasLetters(text)
  return type(text) == 'string' and text:match('[a-zA-Z]') ~= nil
end
-- for debug purpose
local function write_to_logfile(input)
  local filepath = '/tmp/logfile'
  local file = io.open(filepath, 'a')

  local input_str = vim.fn.json_encode(input)

  if file then
    file:write(input_str, '\n')
    file:close()
  end
end

-- ?
-- Gemini function
--
function M.getSelectedText()
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_text(0, vstart[2] - 1, vstart[3] - 1, vend[2] - 1, vend[3], {})

  if lines ~= nil then
    return joinLines(lines)
  end
end


function M.askGemini(prompt, opts)
  curl.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' .. M.opts.api_key, {
    raw = { '-H', 'Content-type: application/json' },
    body = vim.fn.json_encode({
      contents = {
        {
          parts = {
            text = prompt,
          },
        },
      },
    }),
    callback = function(res)
      vim.schedule(function()
        local result
        if res.status ~= 200 then
          if opts.handleError ~= nil then
            result = opts.handleError(res.status, res.body)
          else
            result = 'Error: ' .. tostring(res.status) .. '\n\n' .. res.body
          end
        else
          local data = vim.fn.json_decode(res.body)
          result = data['candidates'][1]['content']['parts'][1]['text']
          if opts.handleResult ~= nil then
            result = opts.handleResult(result)
          end
        end
        opts.callback(result)
      end)
    end,
  })
end

function M.createVSP(initialContent)
  if M.bufnr == nil then
    M.bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(M.bufnr, "GeminiReply")
    vim.api.nvim_command('vsp | buffer' .. M.bufnr)

    local win_ids = vim.api.nvim_list_wins()
    for _, win in ipairs(win_ids) do
      local buf_id = vim.api.nvim_win_get_buf(win)

      if buf_id == M.bufnr then
        M.win_id = win
        break
      end
    end
  end

  local update = function(content)
    local lines = splitLines(content)
    local result = split_lines_with_width(lines)
    local current_line = vim.api.nvim_buf_line_count(M.bufnr)
    vim.api.nvim_win_set_buf(M.win_id, M.bufnr)
    vim.api.nvim_win_set_cursor(M.win_id, {current_line, 0})
    vim.bo[M.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, true, result)
    vim.bo[M.bufnr].modifiable = false
  end
  update(initialContent)

  return update
end

function M.freeStyle(prompt)
  local update = M.createVSP('--------------------\n| Asking Gemini... |\n--------------------\n' .. prompt)
  M.askGemini(prompt, {
    handleResult = function(result)
      return '-----------\n| Answer: |\n-----------\n' .. result
    end,
    callback = update,
  })
end

function M.close()
  local bufnr = M.bufnr
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

function M.setupAutocmd()
  vim.api.nvim_create_autocmd({"QuitPre","ExitPre"}, {
    callback = function ()
     M.close()
    end,
  })
end

function M.setup(opts)
  M.opts = opts
  assert(M.opts.api_key ~= nil and M.opts.api_key ~= '', 'api_key is required')
  M.setupAutocmd()
  -- for k, v in pairs(opts) do
  --   if M.opts[k] ~= nil then
  --     M.opts[k] = v
  --   end
  -- end
end
-- ?
-- user command
--
vim.api.nvim_create_user_command('GeminiAskCode', function(args)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
  local text = M.getSelectedText()
  if not isEmpty(args['args']) then
    text = text .. "\n" .. args['args']
  end
  if hasLetters(text) then
    -- delayed so the popup won't be closed immediately
    vim.schedule(function()
      M.freeStyle(text)
    end)
  end
end, { range = true, nargs = '?' })

vim.api.nvim_create_user_command('GeminiLeave', function()
  local bufnr = M.bufnr
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end, { range = true})
return M
