if !has('vim9script') ||  v:version < 901
    " Needs Vim version 9.01 and above
    finish
endif
vim9script

g:loaded_devdocs = true

import autoload 'install.vim'
import autoload 'uninstall.vim'
import autoload 'find.vim'
import autoload 'devdoc.vim'
import autoload 'options.vim'

nnoremap <leader>I <scriptcmd>install.Install()<CR>
nnoremap <leader>U <scriptcmd>uninstall.Uninstall()<CR>
nnoremap <leader>h <scriptcmd>find.Find()<CR>

autocmd filetype devdoc nnoremap <buffer> <silent> q :q<CR>
            \| nnoremap <buffer> <silent> <c-]> <scriptcmd>devdoc.GetPage()<CR>
            \| nnoremap <buffer> <silent> K     <scriptcmd>devdoc.GetPage()<CR>
            \| nnoremap <buffer> <silent> <c-t> <scriptcmd>devdoc.PopPage()<CR>

command DevdocsInstall install.Install()
command DevdocsUninstall uninstall.Uninstall()
command DevdocsFind find.Find()

def! g:DevdocsOptionsSet(opt: dict<any>)
    options.opt->extend(opt)
enddef
