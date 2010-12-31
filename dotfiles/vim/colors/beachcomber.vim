" Vim color file
" beachcomber v1.0
" Maintainer:	Rob Valentine <hjzx5ga02@sneakemail.com>

" Beachcomber
"
" This theme is meant to remind one of a day at the beach.
"
" useful help screens & commands
" :syntax
" :he group-name
" :he highlight-groups
" :he cterm-colors
"
" useful online resource
" http://www.colorpicker.com

if version > 580
    " no guarantees for version 5.8 and below, but this makes it stop
    " complaining
    hi clear
    if exists("syntax_on")
		syntax reset
    endif
endif
let g:colors_name="beachcomber"

hi Normal	guibg=#F1EFD8 guifg=#192B4E

" syntax highlighting
hi Comment	  guifg=#6C5B5B
hi Title      guifg=#416B24
hi Underlined guifg=#20b0eF gui=none
hi Statement  guifg=#41898A
hi Type		    guifg=#204546
hi PreProc    guifg=#984D4D
hi Constant	  guifg=#6A3F70
hi Identifier guifg=#395420 

"highlight groups
hi Ignore	      guifg=grey40
hi Todo		      guifg=#204546 guibg=#FFBCFD
hi Cursor	      guifg=#FF05EA guibg=#A8CDCD 
hi MatchParen                 guibg=#eae5a6
hi Directory    guifg=#395420
hi DiffAdd      guifg=#07AF07 guibg=#FFFFFF
hi DiffChange   guifg=#333333 guibg=#FFFFFF
hi DiffDelete   guifg=#FF0000 guibg=#FFFFFF
hi DiffText     guifg=#000000 guibg=#FFE572
hi ErrorMsg     guifg=#FFFFFF guibg=#0000FF
hi VertSplit	  guifg=#A3FFFE guibg=#555555 gui=none
hi Folded	      guifg=#2F2F2F guibg=#7BD3D4 
hi FoldColumn	  guifg=#2F2F2F guibg=#7BD3D4 
hi LineNr       guifg=#2F2F2F guibg=#D8D6BC
hi NonText      guifg=#52503B guibg=#F1EFD8
hi Search	      guibg=#FDFF5B guifg=#52503B
hi IncSearch	  guifg=#FDFF5B guibg=#52503B
hi StatusLine	  guifg=#2F2F2F guibg=#7BD3D4 gui=none
hi StatusLineNC	guifg=#A3FFFE guibg=#555555 gui=none
hi Visual                     guibg=#eae5a6
hi Pmenu	      guifg=#A3FFFE guibg=#555555
hi PmenuSel	    guifg=#A3FFFE guibg=#204546

" complete menu
"hi Pmenu           guifg=#66D9EF guibg=#000000
"hi PmenuSel                      guibg=#808080
"hi PmenuSbar                     guibg=#080808
"hi PmenuThumb      guifg=#66D9EF

"vim: sw=4
