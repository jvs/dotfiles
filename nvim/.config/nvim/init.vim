" From: https://github.com/junegunn/vim-plug/wiki/tips#automatic-installation
" Install vim-plug if not found
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif


call plug#begin()

Plug '907th/vim-auto-save'
Plug 'ambv/black'
Plug 'mbbill/undotree'
Plug 'mg979/vim-visual-multi', {'branch': 'master'}
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/playground'
Plug 'rust-lang/rust.vim'
Plug 'tomasiser/vim-code-dark'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'vimwiki/vimwiki'

" Plug 'tpope/vim-dispatch'
" Plug 'tpope/vim-projectionist'
" Plug 'tpope/vim-surround'
" Plug 'tpope/vim-repeat'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'

call plug#end()


" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif


lua require'nvim-treesitter.configs'.setup { highlight = { enable = true } }


" Remap leader key.
nnoremap <SPACE> <Nop>
let mapleader = "\<Space>"
" Or should this be:
" let mapleader = " "



" Color scheme.
colorscheme codedark
let g:airline_theme = 'codedark'



" FROM: https://github.com/skwp/dotfiles/blob/master/vim/settings/yadr-window-killer.vim
" Use <leader>q to intelligently close a window
" (if there are multiple windows into the same buffer)
" or kill the buffer entirely if it's the last window looking into that buffer
function! CloseWindowOrKillBuffer()
  let number_of_windows_to_this_buffer = len(filter(range(1, winnr('$')), "winbufnr(v:val) == bufnr('%')"))

  " We should never bdelete a nerd tree
  if matchstr(expand("%"), 'NERD') == 'NERD'
    wincmd c
    return
  endif

  if number_of_windows_to_this_buffer > 1
    wincmd c
  else
    bdelete
  endif
endfunction

nnoremap <silent> <leader>q :call CloseWindowOrKillBuffer()<CR>


" Navigating splits.
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
