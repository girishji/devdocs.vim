if !has('vim9script') ||  v:version < 901
    " Needs Vim version 9.01 and above
    finish
endif
vim9script

import autoload 'install.vim'
import autoload 'uninstall.vim'
import autoload 'find.vim'
import autoload 'devdoc.vim'

nnoremap <leader>h <scriptcmd>install.Install()<CR>
# command DevdocsInstall <scriptcmd>install.Install()
nnoremap <leader>H <scriptcmd>uninstall.Uninstall()<CR>
nnoremap <leader>f <scriptcmd>find.Find()<CR>

autocmd filetype devdoc nnoremap <buffer> <silent> q :q<CR>
            \| nnoremap <buffer> <silent> <c-]> <scriptcmd>devdoc.GetPage()<CR>
            \| nnoremap <buffer> <silent> <c-t> <scriptcmd>devdoc.PopPage()<CR>
