if vim.g.loaded_seak then
  return
end
vim.g.loaded_seak = true

require('seak'):init()

vim.cmd([[
  cnoremap <Plug>(seak-select) <Cmd>lua require('seak'):select()<CR>
]])

