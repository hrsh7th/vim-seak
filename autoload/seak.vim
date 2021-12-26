let s:state = {
\   'bufnr': 0,
\   'matches': [],
\ }

let s:marks = split('abcdefghijklmnopqrstuvwxyz', '.\zs')

function! seak#on_change() abort
  if !get(g:, 'seak_enabled', v:false) || index(['/', '?'], getcmdtype()) == -1
    return
  endif

  if s:state.bufnr !=# bufnr('%')
    call seak#clear()
    let s:state.bufnr = bufnr('%')
  endif

  let l:lnum_s = line('w0')
  let l:lnum_e = line('w$')
  let l:input = getcmdline()
  let l:texts = getbufline('%', l:lnum_s, l:lnum_e)
  try
    let l:matches = []
    for l:i in range(0, len(l:texts) - 1)
      let l:text = l:texts[l:i]
      let l:off = 0
      while l:off < strlen(l:text)
        let l:m = matchstrpos(l:text, l:input, l:off)
        if l:m[0] ==# ''
          break
        endif
        let l:mark = get(s:marks, len(l:matches), v:null)
        if empty(l:mark)
          break
        endif
        call add(l:matches, {
        \   'lnum': l:lnum_s + l:i,
        \   'col': l:m[1] + 1,
        \   'mark': l:mark,
        \ })
        let l:off = l:off + l:m[2] + 1
      endwhile
    endfor

    call seak#clear()
    for l:match in l:matches
      let l:match.id = s:open(l:match.lnum, l:match.col, l:match.mark)
    endfor
    let s:state.matches = l:matches
    redraw
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

function! seak#clear() abort
  for l:match in s:state.matches
    try
      call s:close(l:match.id)
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
  endfor
  let s:state.matches = []
endfunction

function! seak#select() abort
  if empty(s:state.matches)
    return
  endif
  let l:index = index(s:marks, nr2char(getchar()))
  if l:index >= 0
    let l:match = get(s:state.matches, l:index, v:null)
    if !empty(l:match)
      let l:match = s:state.matches[l:index]
      call feedkeys(printf("\<Esc>\<Cmd>call cursor(%s, %s)\<CR>", l:match.lnum, l:match.col), 'n')
    endif
  end
  call seak#clear()
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace('seak')
else
  let s:text_prop_id = 0
  call prop_type_add('seak', { 'highlight': 'ErrorMsg' })
endif
function! s:open(lnum, col, mark) abort
  if has('nvim')
    return nvim_buf_set_extmark(0, s:ns, a:lnum - 1, a:col - 1, {
    \   'end_line': a:lnum - 1,
    \   'end_col': a:col - 1,
    \   'virt_text': [[a:mark, 'ErrorMsg']],
    \   'virt_text_pos': 'overlay'
    \ })
  else
    let s:text_prop_id += 1
    call prop_add(a:lnum, a:col, { 'type': 'seak', 'id': s:text_prop_id })
    call popup_create(a:mark, {
    \   'line': -1,
    \   'textprop': 'seak',
    \   'textpropid': s:text_prop_id,
    \   'width': 1,
    \   'height': 1,
    \   'highlight': 'ErrorMsg'
    \ })
    return s:text_prop_id
  endif
endfunction

function! s:close(id) abort
  if has('nvim')
    call nvim_buf_del_extmark(0, s:ns, a:id)
  else
    call prop_remove({
    \   'type': 'seak',
    \   'id': a:id,
    \ })
  endif
endfunction

