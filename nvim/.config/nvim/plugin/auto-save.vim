" Enable AutoSave on Vim startup.
let g:auto_save = 1

" Do not display the auto-save notification.
let g:auto_save_silent = 1

" Automatically save when losing focus.
:au FocusLost * :wa
