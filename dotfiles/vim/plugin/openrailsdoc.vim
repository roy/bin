function! OpenRailsDoc(keyword)
  let url = 'http://apidock.com/rails/'.a:keyword
  call system("open -a Firefox ". url)
endfunction

noremap RR :call OpenRailsDoc(expand('<cword>')) <CR>
