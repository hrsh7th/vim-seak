if exists('g:loaded_seak')
  finish
endif
let g:loaded_seak = v:true

let g:seak_enabled = get(g:, 'seak_enabled', v:false)
let g:seak_marks = get(g:, 'seak_marks', split('asdfhjkl', '.\zs'))
let g:seak_auto_accept = get(g:, 'seak_auto_accept', v:true)

if !hlexists('SeakChar')
  highlight! default SeakChar
  \   gui=bold,underline
  \   guifg=Black
  \   guibg=Red
  \   cterm=bold,underline
  \   ctermfg=Black
  \   ctermbg=Red
endif

augroup seak
  autocmd!
  autocmd CmdlineChanged [/\?] call timer_start(0, { -> seak#on_change() })
  autocmd CmdlineEnter [/\?] call timer_start(0, { -> seak#on_change() })
  autocmd CmdlineLeave [/\?] call seak#clear()
augroup END

