let s:state = {
\   'matches': [],
\   'search': 0,
\   'incsearch': 0,
\ }

"
" seak#on_enter
"
function! seak#on_enter() abort
  if s:is_in_cmdwin()
    augroup seak-cmdwin
      autocmd!
      autocmd TextChanged,TextChangedI,TextChangedP <buffer>
      \   call timer_start(0, { -> seak#on_change() })
    augroup END
  endif

  call seak#on_change()
endfunction

"
" seak#on_leave
"
function! seak#on_leave() abort
  call seak#clear()
endfunction

"
" seak#on_change
"
function! seak#on_change() abort
  if !get(g:, 'seak_enabled', v:false) || index(['/', '?'], s:getcmdtype()) == -1
    return
  endif

  let l:winID = s:get_current_winID()
  let l:lnum_s = line('w0', l:winID)
  let l:lnum_e = line('w$', l:winID)
  let l:texts = s:get_current_bufline(l:lnum_s, l:lnum_e)
  let l:input = s:getcmdline()
  let l:curpos = s:getcurpos_on_current_window()
  let l:next = s:getcmdtype() ==# '/'

  if !empty(get(g:, 'seak_auto_accept', v:true))
    let l:mark = l:input[strlen(l:input) - 1]
    if index(g:seak_marks, l:mark) >= 0
      let l:option = g:seak_auto_accept
      if l:option is v:true
        let l:option = { 'nohlsearch': v:true, 'jumplist': v:true }
      endif
      let l:option = deepcopy(l:option)
      let l:option.mark = l:mark
      let l:option._on_auto_accept = v:true
      call seak#select(l:option)
      return
    endif
  endif

  try
    let l:matches = []
    let l:nextmatch = []
    for l:i in range(0, len(l:texts) - 1)
      let l:text = l:texts[l:i]
      let l:off = 0
      while l:off < strlen(l:text)
        let l:m = matchstrpos(l:text, l:input, l:off, 1)
        if l:m[0] ==# ''
          break
        endif
        let l:mark = get(g:seak_marks, len(l:matches), v:null)
        if empty(l:mark)
          break
        endif
        let l:match = {
        \   'lnum': l:lnum_s + l:i,
        \   'col': l:m[1] + 1,
        \   'end_col': l:m[2] + 1,
        \   'mark': l:mark,
        \ }
        call add(l:matches, l:match)
        if empty(l:nextmatch) && l:next && (l:curpos[1] == l:match.lnum || l:curpos[1] == l:match.lnum && l:curpos[2] <= l:match.col)
          let l:nextmatch = l:match
        elseif !l:next && l:match.lnum < l:curpos[1] || l:match.lnum == l:curpos[1] && l:match.col <= l:curpos[2]
          let l:nextmatch = l:match
        endif
        let l:off = l:m[2] + 1
      endwhile
    endfor

    call seak#clear()
    for l:match in l:matches
      let l:match.id = s:open(l:match.lnum, l:match.col, l:match.mark)
    endfor
    let s:state.matches = l:matches
    let s:state.search = matchadd('Search', l:input, 10, -1, { 'window': l:winID })
    let s:state.incsearch = empty(l:nextmatch) ? 0 : matchaddpos('IncSearch', [[l:nextmatch.lnum, l:nextmatch.col, l:nextmatch.end_col - l:nextmatch.col]], 10, -1, { 'window': l:winID })

    redraw
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

"
" seak#clear
"
function! seak#clear() abort
  let l:winID = s:get_current_winID()
  for l:match in s:state.matches
    try
      call s:close(l:match.id)
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
  endfor
  let s:state.matches = []

  " search
  try
    call matchdelete(s:state.search, l:winID)
  catch /.*/
  endtry
  let s:state.search = 0

  " incsearch
  try
    call matchdelete(s:state.incsearch, l:winID)
  catch /.*/
  endtry
  let s:state.incsearch = 0
endfunction

"
" seak#select
"
function! seak#select(...) abort
  let l:opts = get(a:000, 0, {})
  if empty(s:state.matches)
    return
  endif
  let l:index = index(g:seak_marks, has_key(l:opts, 'mark') ? l:opts.mark : nr2char(getchar()))
  if l:index >= 0
    let l:match = get(s:state.matches, l:index, v:null)
    if !empty(l:match)
      if get(l:opts, 'jumplist', v:true)
        normal! m'
      endif
      let l:match = s:state.matches[l:index]

      let l:exit_key = "\<ESC>"
      if s:is_in_cmdwin()
        " If cpoptions contains 'x', <ESC> in cmdline executes the input,
        " otherwise throws away the input.
        " (For more information, see :h c_ESC and :h E199)
        if stridx(&cpoptions, 'x') == -1
          let l:exit_key = "\<Cmd>quit\<CR>"
          if mode() ==# 'i'
            let l:exit_key = "\<ESC>" . l:exit_key
          endif
        else
          let l:exit_key = "\<CR>"
        endif
      endif

      if has_key(l:opts, '_on_auto_accept') && l:opts._on_auto_accept
        let l:exit_key = "\<C-h>" .. l:exit_key
      endif

      let l:keys = ''
      let l:keys .= printf("%s\<Cmd>call cursor(%s, %s)\<CR>", l:exit_key, l:match.lnum, l:match.col)
      let l:keys .= get(l:opts, 'nohlsearch', v:false) ? "\<Cmd>nohlsearch\<CR>" : ''
      call feedkeys(l:keys, 'nit')
    endif
  endif
  call seak#clear()
endfunction

"
" prepare
"
if has('nvim')
  let s:ns = nvim_create_namespace('seak')
else
  let s:text_prop_id = 0
  call prop_type_add('seak', {})
endif

"
" s:open
"
if has('nvim')
  function! s:open(lnum, col, mark) abort
    return nvim_buf_set_extmark(s:get_current_bufnr(), s:ns, a:lnum - 1, max([0, a:col - 2]), {
    \   'end_line': a:lnum - 1,
    \   'end_col': max([0, a:col - 2]),
    \   'virt_text': [[a:mark, 'SeakChar']],
    \   'virt_text_pos': 'overlay'
    \ })
  endfunction
else
  function! s:open(lnum, col, mark) abort
    let s:text_prop_id += 1
    call prop_add(a:lnum, a:col, {
    \   'type': 'seak',
    \   'id': s:text_prop_id,
    \   'bufnr': s:get_current_bufnr(),
    \ })
    call popup_create(a:mark, {
    \   'line': -1,
    \   'col': -1,
    \   'textprop': 'seak',
    \   'textpropid': s:text_prop_id,
    \   'textpropwin': s:get_current_winID(),
    \   'width': 1,
    \   'height': 1,
    \   'highlight': 'SeakChar'
    \ })
    return s:text_prop_id
  endfunction
endif

"
" s:close
"
if has('nvim')
  function! s:close(id) abort
    call nvim_buf_del_extmark(s:get_current_bufnr(), s:ns, a:id)
  endfunction
else
  function! s:close(id) abort
    call prop_remove({
    \   'type': 'seak',
    \   'id': a:id,
    \   'bufnr': s:get_current_bufnr(),
    \ })
  endfunction
endif

"
" s:getcmdline
"
" Similar to the built-in getcmdline(), but cooperate with cmdwin.
"
function! s:getcmdline() abort
  if s:is_in_cmdwin()
    return getline('.')
  else
    return getcmdline()
  endif
endfunction

"
" s:getcmdtype
"
" Similar to the built-in getcmdtype(), but cooperate with cmdwin.
"
function! s:getcmdtype() abort
  let l:cmdtype = getcmdtype()
  if l:cmdtype !=# ''
    return l:cmdtype
  else
    return getcmdwintype()
  endif
endfunction

"
" s:is_in_cmdwin
"
function! s:is_in_cmdwin() abort
  return getcmdwintype() !=# '' && getcmdtype() ==# ''
endfunction

"
" s:get_current_bufnr
"
function! s:get_current_bufnr() abort
  if s:is_in_cmdwin()
    return bufnr('#')
  endif
  return bufnr('%')
endfunction

"
" s:get_current_bufline
"
function! s:get_current_bufline(lnum, ...) abort
  return call('getbufline', [s:get_current_bufnr(), a:lnum] + a:000)
endfunction

"
" s:get_current_winID
"
function! s:get_current_winID() abort
  return bufwinid(s:get_current_bufnr())
endfunction

"
" s:getcurpos_on_current_window
"
if has('nvim')
  function! s:getcurpos_on_current_window() abort
    let l:cursor = nvim_win_get_cursor(s:get_current_winID())
    return [0, l:cursor[0], l:cursor[1] + 1]
  endfunction
else
  function! s:getcurpos_on_current_window() abort
    return getcurpos(s:get_current_winID())
  endfunction
endif
