vim9script

import './popup.vim'
import './task.vim'
import './options.vim'
import autoload 'devdoc.vim'

var data_dir = options.opt.data_dir

def ShowMenu(items: list<dict<any>>)
    def Filter(lst: list<dict<any>>, prompt: string): list<any>
        if prompt->empty()
            return [lst, [lst]]
        else
            var pat = prompt->trim()
            var matches = lst->matchfuzzypos(pat, {key: "name"})
            return [lst, matches]
        endif
    enddef
    popup.FilterMenuPopup.new('Devdocs',
        items,
        (res, key) => {
            devdoc.LoadPage(res.data.path, res.slug, true)
        },
        (winid) => {
            win_execute(winid, "syn match FilterMenuAttributesSubtle ' ‹.*$'")
            hi def link FilterMenuAttributesSubtle Comment
        },
        Filter)
enddef

def Slugs(): list<any>
    var dir = data_dir->expand()
    var slugs: list<string>
    if !options.opt->has_key('slugs') || !options.opt.slugs->empty()
        slugs = dir->readdir((v) => $'{dir}/{v}'->isdirectory() && v !~ '\.tmp$')
        if slugs->empty()
            :echohl WarningMsg | echom $'Devdocs not installed' | echohl None
            return []
        endif
    else
        slugs = options.opt.slugs
    endif
    var items = []
    for slug in slugs
        if $'{dir}/{slug}/index.json'->filereadable()
            items->add(slug)
        else
            :echohl WarningMsg | echom $'{slug}/index.json is not readable' | echohl None
        endif
    endfor
    return items
enddef

export def Find()
    var items = []
    for slug in Slugs()
        var fname = $'{data_dir}/{slug}/index.json'->expand()
        var fdata = fname->readfile()->join()
        try
            var jlist = fdata->json_decode()
            items->extend(jlist.entries->mapnew((_, v) => {
                return {text: $'{v.name} ‹{slug}› {v.type}', name: v.name, slug: slug, data: v}
            }))
        catch
            :echohl WarningMsg | echom $'{slug}/index.json decode failed ({v:exception})' | echohl None
        endtry
    endfor
    ShowMenu(items)
enddef
