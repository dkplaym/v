
inoremap π <Esc>														" map ctrl+p to Esc
nnoremap <F2> :set nu! nu?<CR>
nnoremap <F3> :set paste! paste?<CR>
nnoremap <F4> :set wrap! wrap?<CR>
nnoremap <F5> :exec exists('syntax_on') ? 'syn off' : 'syn on'<CR>

autocmd! bufwritepost .vimrc source %
"autocmd bufwritepost .vimrc source ~/.vimrc								" auto load .vimrc
cmap w!! w !sudo tee  %	
set showtabline=1														" show tabs in top
syntax on																" syntax
set history=2000														" history : how many lines of history VIM has to remember
set nocompatible														" don't bother with vi compatibility
set autoread															" reload files when changed on disk, i.e. via `git checkout`
set shortmess=atI														" never show msg at start vim
set nobackup															" do not keep a backup file
set novisualbell														" turn off visual bell
set noerrorbells														" don't beep
set visualbell t_vb=													" turn off error beep/flash
set cursorline															"set cursorcolumn
set scrolloff=10															" keep 3 lines when scrolling
set ruler																" show the current row and column
set number																" show line numbers
set nowrap
set showcmd																" display incomplete commands
set showmode															" display current modes
set showmatch															" jump to matches when entering parentheses
set matchtime=2															" tenths of a second to show the matching parenthesis
set hlsearch															" highlight searches
set incsearch															" do incremental searching, search as you type
set ignorecase															" ignore case when searching
set smarttab															" smart ?
set autoindent smartindent shiftround
set shiftwidth=4
set tabstop=4
set softtabstop=4														" insert mode tab and backspace use 4 spaces
set selection=inclusive
set completeopt=longest,menu
set wildmenu															" show a navigable menu for tab completion"
set wildmode=longest,list,full
set backspace=indent,eol,start											" make that backspace key work the way it should
set whichwrap+=<,>,h,l
set nopaste																"no indent when paste
set textwidth=0	
setlocal noswapfile
let g:vimim_disable_chinese_punctuation=1								" 关闭中文标点


" theme
set background=dark
colorscheme ron 
" set mark column color
hi! link SignColumn   LineNr
hi! link ShowMarksHLl DiffAdd
hi! link ShowMarksHLu DiffChange
" status line
set statusline=%<%f\ %h%m%r%=%k[%{(&fenc==\"\")?&enc:&fenc}%{(&bomb?\",BOM\":\"\")}]\ %-14.(%l,%c%V%)\ %P
set laststatus=2   " Always show the status line - use 2 lines for the status bar

" encoding
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
set termencoding=utf-8
set ffs=unix,dos,mac
set formatoptions+=m
set formatoptions+=B

" force to use  hjkl
map <Left> :echo "Use h you asshole!"<cr>
map <Right> :echo "Use l you asshole!"<cr>
map <Up> :echo "Use k you asshole!"<cr>
map <Down> :echo "Use j you asshole!"<cr>

" filetype
filetype on
" Enable filetype plugins
filetype plugin on
filetype indent on




"use cn lang help
set helplang=cn 
if version >= 603
    set helplang=cn
    set encoding=utf-8
endif



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" leader""""""""""""""""""""""""""""""""""""
let mapleader = ','
"let g:mapleader = ','

inoremap <leader>q <Esc>
nnoremap <leader>q <Esc>
xnoremap <leader>q <Esc>

map <leader>w :w<cr>
map <leader>wq :wq<cr>
map <leader>h :nohl<cr>



""""""""""""""""""""""""""""""""""""""""""""""""""""""""" search and quickfix """""""""""""
map <leader>f :vimgrep 

let g:quickfix_is_open = 0
function! QuickfixToggle()
    if g:quickfix_is_open
        cclose
        let g:quickfix_is_open = 0
    else
        copen 
        let g:quickfix_is_open = 1
    endif
endfunction
nnoremap <leader>d :call QuickfixToggle()<cr>
nnoremap <leader>x :cn<cr>
nnoremap <leader>c :cp<cr>

