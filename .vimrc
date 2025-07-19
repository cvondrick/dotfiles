set nocompatible " enable vim features

call plug#begin()

  " Run :PlugInstall to install these

  Plug 'tpope/vim-sensible'
  Plug 'tpope/vim-sleuth'
  Plug 'tomasiser/vim-code-dark'
  "Plug 'vim-airline/vim-airline'
  "Plug 'vim-airline/vim-airline-themes'
  Plug 'itchyny/lightline.vim'
  Plug 'preservim/nerdtree'
  "Plug 'morhetz/gruvbox'

call plug#end()

colorscheme codedark

let g:lightline = {
      \ 'colorscheme': 'Tomorrow_Night',
      \ }

nnoremap <C-n> :bnext<CR>
nnoremap <C-p> :bprev<CR>

set t_Co=256

set number
set cursorline

set expandtab " replace a tab with spaces
set shiftround " round indent with > and <
set softtabstop=2 " tab is 4 characters
set tabstop=2
set shiftwidth=2
set backspace=2

set hlsearch
nnoremap <Esc> :nohlsearch<Bar>:echo<CR>

set noshowmode

" NERDTree
nnoremap , :NERDTreeToggle<CR>

