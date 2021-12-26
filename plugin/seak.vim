if exists('g:loaded_seak')
  finish
endif
let g:loaded_seak = v:true

augroup seak
  autocmd!
  autocmd CmdlineChanged * call seak#on_change()
  autocmd CmdlineLeave * call seak#clear()
augroup END

cnoremap <Plug>(seak-select) <Cmd>call seak#select()<CR>

