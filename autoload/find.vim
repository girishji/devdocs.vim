vim9script

import './popup.vim'
import './task.vim'
import './devdoc.vim'

var data_dir = '~/.local/share/devdocs'
var pandoc = 'pandoc'

def FetchDoc(entry: dict<any>)
    var fpath = entry.data.path
    var idx = fpath->strridx('#')
    var tag = ''
    if idx != -1
        tag = fpath->slice(idx + 1)
        fpath = fpath->slice(0, idx)
    endif
    fpath = $'{data_dir}/{entry.slug}/{fpath}.html'->expand()->fnameescape()
    if !fpath->filereadable()
        :echohl ErrorMsg | echoerr $'Failed to read {fpath}' | echohl None
        return
    endif
    if 'pandoc'->exepath() == ''
        :echohl ErrorMsg | echoerr $'Failed to find pandoc' | echohl None
        return
    endif
    var scriptdir = getscriptinfo({name: 'devdocs'})[0].name->fnamemodify(':h:h')
    task.AsyncCmd.new(
        $'{pandoc} -t {scriptdir}/pandoc/writer.lua {fpath}',
        (msg: string) => {
            var doc: dict<any>
            try
                doc = msg->json_decode()
            catch
                :echohl ErrorMsg | echoerr $'Pandoc failed ({v:exception})' | echohl None
                return
            endtry
            devdoc.LoadPage(doc)
        })
enddef

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
            FetchDoc(res)
        },
        (winid) => {
            win_execute(winid, "syn match FilterMenuAttributesSubtle ' ‹.*$'")
            hi def link FilterMenuAttributesSubtle Comment
        },
        Filter)
enddef

def Slugs(): list<any>
    var dir = data_dir->expand()
    var slugs = dir->readdir((v) => $'{dir}/{v}'->isdirectory() && v !~ '\.tmp$')
    if slugs->empty()
        :echohl WarningMsg | echom $'Devdocs not installed' | echohl None
        return []
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
