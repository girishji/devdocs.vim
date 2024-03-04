vim9script

import autoload 'find.vim'
import autoload 'install.vim'
import autoload 'uninstall.vim'
import autoload 'options.vim'
import autoload 'popup.vim'

export def Find()
    find.Find()
enddef

export def Install()
    install.Install()
enddef

export def Uninstall()
    uninstall.Uninstall()
enddef

export def OptionsSet(opt: dict<any>)
    options.opt->extend(opt)
enddef

export def OptionsGet(): dict<any>
    return options.opt->deepcopy()
enddef

export def PopupOptionsSet(opt: dict<any>)
    popup.options->extend(opt)
enddef

