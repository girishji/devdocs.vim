if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.01 and above'
    finish
endif
vim9script

g:loaded_devdocs = true

if get(g:, 'loaded_devdocs_tui', false)
    import '../autoload/install.vim'
    import '../autoload/uninstall.vim'
    import '../autoload/find.vim'
    import '../autoload/devdoc.vim'
    import '../autoload/options.vim'
else
    import autoload 'install.vim'
    import autoload 'uninstall.vim'
    import autoload 'find.vim'
    import autoload 'devdoc.vim'
    import autoload 'options.vim'
endif

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
