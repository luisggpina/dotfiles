" ~/.vimrc

" ALE options that must be set before the plugin loads
let g:ale_completion_enabled = 1

" ── Plugins (vim-plug; installs itself on first run) ──────────
let s:plug = expand('~/.vim/autoload/plug.vim')
if !filereadable(s:plug)
  silent execute '!curl -fLo ' . s:plug . ' --create-dirs '
        \ . 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'vim-latex/vim-latex'
Plug 'dense-analysis/ale'                 " linting + clangd (LSP)
Plug 'christoomey/vim-tmux-navigator'     " Ctrl-hjkl across vim splits and tmux panes
Plug 'morhetz/gruvbox'
Plug 'junegunn/fzf.vim'                   " :Files, :Rg, :Buffers
Plug 'tpope/vim-commentary'               " gcc / gc{motion}
Plug 'tpope/vim-surround'                 " cs"' / ysiw) / ds(
Plug 'tpope/vim-fugitive'                 " :Git
call plug#end()
" plug#end() already runs `filetype plugin indent on` and `syntax enable`

" ── Look ──────────────────────────────────────────────────────
set termguicolors
set background=dark
silent! colorscheme gruvbox

set number
set scrolloff=5
" Show trailing whitespace (works in every window, unlike :match)
set list listchars=tab:»\ ,trail:·,nbsp:␣

" ── Editing ───────────────────────────────────────────────────
set expandtab tabstop=4 shiftwidth=4
set textwidth=80
set autochdir                   " working dir follows the current file
set clipboard=unnamedplus       " y/p use the system clipboard
set autoread                    " reload files changed on disk
set splitright splitbelow
set wildmenu wildmode=longest:full,full

" Persistent undo
if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p')
endif
set undofile undodir=~/.vim/undo

" ── Search ────────────────────────────────────────────────────
set hlsearch incsearch ignorecase smartcase
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

" ── fzf ───────────────────────────────────────────────────────
nnoremap <C-p>     :Files<CR>
nnoremap <leader>g :Rg<CR>
nnoremap <leader>b :Buffers<CR>

" ── ALE / clangd ──────────────────────────────────────────────
nnoremap <C-]> :ALEGoToDefinition<CR>
nnoremap gr :ALEFindReferences<CR>
nnoremap K  :ALEHover<CR>

" ── Prose: LaTeX and plain text ───────────────────────────────
autocmd FileType tex,markdown,gitcommit setlocal spell spelllang=en_us
augroup prose
  autocmd!
  autocmd FileType tex,text setlocal textwidth=0 wrap linebreak breakindent
        \ spell spelllang=en_us
  autocmd FileType tex,text nnoremap <buffer> <expr> j v:count ? 'j' : 'gj'
  autocmd FileType tex,text nnoremap <buffer> <expr> k v:count ? 'k' : 'gk'
  autocmd FileType markdown,gitcommit setlocal spell spelllang=en_us
augroup END

" ── LaTeX (vim-latex) ─────────────────────────────────────────
let g:tex_flavor = 'latex'
" vim-latex needs grep to always print file names
set grepprg=grep\ -nH\ $*

" Per-host additions, if any
if filereadable(expand('~/.vimrc.local'))
    source ~/.vimrc.local
endif
