local ns = vim.api.nvim_create_namespace('aiueo')

local marks = {}
string.gsub('abcdefghijklmnopqrstuvwxyz', '.', function(char)
  table.insert(marks, char)
end)
vim.tbl_add_reverse_lookup(marks)

local Seak = {}

function Seak.new()
  local self = setmetatable({}, { __index = Seak })
  self.matches = {}
  return self
end

function Seak:init()
  vim.cmd([[
    augroup seak
      autocmd!
      autocmd CmdlineChanged * lua require('seak'):on_change()
      autocmd CmdlineLeave * lua require('seak'):clear()
    augroup END
  ]])
end

function Seak:on_change()
  if not vim.g.seak_enabled or not vim.tbl_contains({ '/', '?' }, vim.fn.getcmdtype()) then
    return
  end

  local row_s = vim.fn.line('w0') - 1
  local input = vim.fn.getcmdline()
  local texts = vim.api.nvim_buf_get_lines(0, row_s, vim.fn.line('w$') - 1, false)

  pcall(function()
    local matches = {}
    for i, text in ipairs(texts) do
      local off = 1
      while off < #text do
        local m = vim.fn.matchstrpos(text, input, off - 1)
        if m[1] == '' then
          break
        end
        table.insert(matches, {
          row = row_s + i - 1,
          s = m[2],
          e = m[3],
        })
        off = off + m[2] + 1
      end
    end

    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    for i, m in ipairs(matches) do
      if i <= #marks then
        vim.api.nvim_buf_set_extmark(0, ns, m.row, m.s, {
          end_line = m.row,
          end_col = m.e,
          virt_text = { { marks[i], 'ErrorMsg' } },
          virt_text_pos = 'overlay',
        })
      end
    end
    self.matches = matches
  end)
end

function Seak:clear()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

function Seak:select()
  local index = marks[vim.fn.nr2char(vim.fn.getchar())]
  if index then
    local match = self.matches[index]
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(
        string.format('<Esc><Cmd>call cursor(%s, %s)<CR>', match.row + 1, match.s + 1),
        true,
        true,
        true
      ),
      'n',
      true
    )
  end
  self:clear()
end

return Seak.new()

