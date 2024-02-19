vim9script

import './popup.vim'
import './task.vim'

var data_dir = '~/.local/share/devdocs'
# var devdocs_site_url = 'https://devdocs.io'
# var devdocs_cdn_url = 'https://documents.devdocs.io'

# var outdir = $'{data_dir}/{entry.slug}'->expand()->fnameescape()

# def Extract(outdir: string): bool
#     var tmpdir = $'{outdir}.tmp'
#     if !$'{tmpdir}/index.json'->filereadable() || !$'{tmpdir}/db.json'->filereadable()
#         :echohl ErrorMsg | echoerr 'Missing {index,db}.json' | echohl None
#         return false
#     endif
#     var db: dict<any>
#     try
#         # 100 MB json file takes ~900 ms to read and decode
#         db = $'{tmpdir}/db.json'->readfile()->join()->json_decode()
#     catch
#         :echohl ErrorMsg | echoerr $'Failed to read devdocs db.json ({v:exception})' | echohl None
#         return false
#     endtry
#     for [fname, content] in db->items()
#         var dir = $'{tmpdir}/{fname->fnamemodify(":h")}'
#         if !dir->isdirectory() && !mkdir(dir, 'p')
#             :echohl ErrorMsg | echoerr $'Failed to create {dir}' | echohl None
#             return false
#         endif
#         var filename = $'{tmpdir}/{fname}.html'
#         # splitting along \n is necessary to avoid NUL char in file
#         # https://superuser.com/questions/935574/get-rid-of-null-character-in-vim-variable
#         if content->trim()->split('\n')->writefile(filename) == -1
#             :echohl ErrorMsg | echoerr $'Failed to write {filename}' | echohl None
#             return false
#         endif
#     endfor
#     if outdir->isdirectory() && outdir->delete('rf') != 0
#         :echohl ErrorMsg | echoerr $'Failed to remove {outdir}' | echohl None
#         return false
#     endif
#     $'mv {tmpdir} {outdir}'->system()
#     if v:shell_error != 0
#         :echohl ErrorMsg | echoerr $'Failed to rename {outdir}' | echohl None
#         return false
#     endif
#     return true
# enddef

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
        $'pandoc -t {scriptdir}/pandoc/writer.lua {fpath}',
        (msg: string) => {
            var doc: dict<any>
            try
                doc = msg->json_decode()
            catch
                :echohl ErrorMsg | echoerr $'Pandoc failed ({v:exception})' | echohl None
                return
            endtry
            echom doc.doc
        })
enddef
#     if entry.slug->empty() | return | endif
#     var outdir = $'{data_dir}/{entry.slug}'->expand()->fnameescape()
#     var tmpdir = $'{outdir}.tmp'
#     if tmpdir->isdirectory() && tmpdir->delete('rf') != 0
#         :echohl ErrorMsg | echoerr $'Failed to remove {tmpdir}' | echohl None
#         return
#     endif
#     def Text(t: string): list<string>
#         return [t, '', 'This may take up to a minute', '', '<Esc> to dismiss window', '<C-c> to abort job']
#     enddef
#     var atask: task.AsyncCmd
#     var notif: popup.NotificationPopup
#     var aborted = false
#     notif = popup.NotificationPopup.new(Text($'Downloading {entry.db_size} bytes ...'),
#         () => {
#             # <C-c> was pressed.
#             if atask->type() == v:t_object
#                 atask.Stop()
#             endif
#             aborted = true
#             tmpdir->isdirectory() && tmpdir->delete('rf')
#         })
# enddef

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
