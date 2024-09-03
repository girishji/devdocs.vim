if !has('vim9script') ||  v:version < 901
    " echoerr 'Needs Vim version 9.01 and above'
    finish
endif
vim9script

g:loaded_devdocs = true

import autoload '../autoload/devdocs/find.vim'
import autoload '../autoload/devdocs/install.vim'
import autoload '../autoload/devdocs/uninstall.vim'
import autoload '../autoload/devdocs/options.vim'
import autoload '../autoload/devdocs/devdoc.vim'

def Keymaps()
    if maparg('q', 'n')->empty()
        :nnoremap <buffer> <silent> q :q<CR>
    endif
    :nnoremap <buffer> <silent> <c-]> <scriptcmd>devdoc.GetPage()<CR>
    :nnoremap <buffer> <silent> K     <scriptcmd>devdoc.GetPage()<CR>
    :nnoremap <buffer> <silent> <c-t> <scriptcmd>devdoc.PopPage()<CR>
enddef

:autocmd filetype devdoc Keymaps()

:command DevdocsInstall install.Install()
:command DevdocsUninstall uninstall.Uninstall()
:command DevdocsFind find.Find()
:command DevdocsTagStack devdoc.DevdocTagStack()

def! g:DevdocsOptionsSet(opt: dict<any>)
    options.opt->extend(opt)
enddef

def! g:DevdocsOptionsGet(): dict<any>
    return options.opt->deepcopy()
enddef
