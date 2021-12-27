let s:state = {
\   'matches': [],
\   'search': 0,
\   'incsearch': 0,
\ }

"
" seak#on_change
"
function! seak#on_change() abort
  if !get(g:, 'seak_enabled', v:false) || index(['/', '?'], getcmdtype()) == -1
    return
  endif

  let l:lnum_s = line('w0')
  let l:lnum_e = line('w$')
  let l:texts = getbufline('%', l:lnum_s, l:lnum_e)
  let l:input = getcmdline()
  let l:curpos = getcurpos()
  let l:next = getcmdtype() ==# '/'

  if get(g:, 'seak_auto_accept', v:true)
    let l:mark = l:input[strlen(l:input) - 1]
    if index(g:seak_marks, l:mark) >= 0
      call seak#select({ 'nohlsearch': v:true, 'mark': l:mark })
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
    let s:state.search = matchadd('Search', l:input)
    let s:state.incsearch = empty(l:nextmatch) ? 0 : matchaddpos('IncSearch', [[l:nextmatch.lnum, l:nextmatch.col, l:nextmatch.end_col - l:nextmatch.col]])
    redraw
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

"
" seak#clear
"
function! seak#clear() abort
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
    call matchdelete(s:state.search)
  catch /.*/
  endtry
  let s:state.search = 0

  " incsearch
  try
    call matchdelete(s:state.incsearch)
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
      let l:match = s:state.matches[l:index]
      let l:keys = ''
      let l:keys .= printf("\<Esc>\<Cmd>call cursor(%s, %s)\<CR>", l:match.lnum, l:match.col)
      let l:keys .= get(l:opts, 'nohlsearch', v:false) ? "\<Cmd>nohlsearch\<CR>" : ''
      call feedkeys(l:keys, 'nit')
    endif
  end
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
    return nvim_buf_set_extmark(0, s:ns, a:lnum - 1, max([0, a:col - 2]), {
    \   'end_line': a:lnum - 1,
    \   'end_col': max([0, a:col - 2]),
    \   'virt_text': [[a:mark, 'SeakChar']],
    \   'virt_text_pos': 'overlay'
    \ })
  endfunction
else
  function! s:open(lnum, col, mark) abort
    let s:text_prop_id += 1
    call prop_add(a:lnum, a:col, { 'type': 'seak', 'id': s:text_prop_id })
    call popup_create(a:mark, {
    \   'line': -1,
    \   'col': -1,
    \   'textprop': 'seak',
    \   'textpropid': s:text_prop_id,
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
    call nvim_buf_del_extmark(0, s:ns, a:id)
  endfunction
else
  function! s:close(id) abort
    call prop_remove({
    \   'type': 'seak',
    \   'id': a:id,
    \ })
  endfunction
endif

