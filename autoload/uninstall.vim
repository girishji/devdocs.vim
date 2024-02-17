vim9script

import './popup.vim'

var data_dir = '~/.local/share/devdocs'

export def Uninstall()
    var dir = data_dir->expand()
    var slugs = dir->readdir((v) => $'{dir}/{v}'->isdirectory() && v !~ '\.tmp$')
    if slugs->empty()
        :echohl WarningMsg | echom $'Devdocs not installed' | echohl None
        return
    endif
    var items = slugs->mapnew((_, v) => {
        return {text: v}
    })
    def Filter(lst: list<dict<any>>, prompt: string): list<any>
        if prompt->empty()
            return [lst, [lst]]
        else
            var pat = prompt->trim()
            var matches = lst->matchfuzzypos(pat, {key: "text"})
            return [lst, matches]
        endif
    enddef
    popup.FilterMenuPopup.new('Devdocs Uninstall',
        items,
        (res, key) => {
            var slugdir = $'{dir}/{res.text}'
            if slugdir->delete('rf') != 0
                :echohl ErrorMsg | echoerr $'Failed to remove {slugdir}' | echohl None
            endif
        },
        null_function,
        Filter)
enddef
