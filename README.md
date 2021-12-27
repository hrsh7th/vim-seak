vim-seak
=====

The plugin that enhances the `/` and `?`.


Usage
=====

```vim
let g:seak_enabled = v:true
cnoremap <C-j> <Cmd>call seak#select({ 'nohlsearch': v:true })<CR>
```

See [doc](./doc/seak.txt) for more detailed information.

