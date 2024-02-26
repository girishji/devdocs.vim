vim9script

import autoload 'options.vim'

export def OptionsSet(opt: dict<any>)
    options.opt->extend(opt)
enddef
