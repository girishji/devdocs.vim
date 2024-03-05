vim9script

import autoload '../autoload/devdocs/find.vim'
import autoload '../autoload/devdocs/install.vim'
import autoload '../autoload/devdocs/uninstall.vim'
import autoload '../autoload/devdocs/options.vim'

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
