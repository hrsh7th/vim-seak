The plugin to improve / in the experimental stage.

I have experimented with many plugins of this type and left them alone. ([vim-aim](https://github.com/hrsh7th/vim-aim) etc)
I welcome your comments, but please refrain from using them normally.


```vim
highlight link SeakChar Visual
let g:seak_enabled = v:true
cnoremap <C-j> <Cmd>call seak#select({ 'nohlsearch': v:true })<CR>
```

