cd %:p:h
set hlsearch
set background=dark

filetype plugin on

let g:tex_flavor='latex'

set expandtab
set tabstop=4
set shiftwidth=4
set nocompatible
set tw=80

" This line makes crontab -e work with vim
set backupskip=/tmp/*,/private/tmp/*

" Latex plugin stuff
set shellslash

" IMPORTANT: grep will sometimes skip displaying the file name if you
" search in a singe file. This will confuse Latex-Suite. Set your grep
" program to always generate a file-name.
set grepprg=grep\ -nH\ $*

"" " Vundle
"" filetype off
"" set rtp+=~/.vim/bundle/Vundle.vim
"" call vundle#begin()
"" Plugin 'VundleVim/Vundle.vim'
"" Plugin 'vimwiki/vimwiki'
"" Plugin 'tbabej/taskwiki'
"" Plugin 'vim-latex/vim-latex'
"" "Plugin 'vim-syntastic/syntastic'
"" "Plugin 'embear/vim-localvimrc'
"" "Plugin 'neapel/vim-java-bytecode'
"" "Plugin 'vim-pandoc/vim-pandoc'
"" "Plugin 'vim-pandoc/vim-pandoc-syntax'
"" call vundle#end()

" Plug
call plug#begin('~/.vim/plugged')
Plug 'vimwiki/vimwiki'
Plug 'tbabej/taskwiki'
Plug 'vim-latex/vim-latex'
Plug 'vim-syntastic/syntastic'
Plug 'udalov/javap-vim'
call plug#end()

let g:taskwiki_disable_concealcursor = ''

syntax on
filetype on
filetype plugin on
filetype plugin indent on

" Highlight trailing whitespaces as errors
match ErrorMsg '\s\+$'

let g:localvimrc_persistent=1

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
