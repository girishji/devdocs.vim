if has('vim9script')
    finish
endif

let g:loaded_devdocs = v:true

" this file provides minimal support for legacy vim and neovim
" implement a 'DevdocsFind' command that uses command-line completion to choose
"   help documents

let s:data_dir = '~/.local/share/devdocs'
let s:docs_list = []

" stack is not used in neovim since prop_add_list() is not implemented
let s:stack = []
let s:path2bufnr = {}

fun! s:getDocsList()
    if !s:docs_list->empty()
        return s:docs_list
    endif
    let dir = s:data_dir->expand()

    let all_slugs = dir->readdir({v -> $'{dir}/{v}'->isdirectory() && v !~ '\.tmp$'})
    if all_slugs->empty()
        :echohl WarningMsg | echom $'Devdocs not installed' | echohl None
        return []
    endif

    let slugs = []
    for slug in all_slugs
        if $'{dir}/{slug}/index.json'->filereadable()
            call add(slugs, slug)
        else
            :echohl WarningMsg | echom $'{slug}/index.json is not readable' | echohl None
        endif
    endfor

    let items = []
    for slug in slugs
        let fname = $'{s:data_dir}/{slug}/index.json'->expand()
        let fdata = fname->readfile()->join()
        fun! s:doc_entry(k, v) closure
            " include the index into the array, to make it easy to find the item in show_doc()
            " return #{text: $'{a:v.name} {a:v.type} {a:k}', name: a:v.name, slug: slug, data: a:v}
            return #{text: $'{a:v.name} {a:v.type}', name: a:v.name, slug: slug, data: a:v}
        endfun
        try
            let jlist = fdata->json_decode()
            call extend(items, jlist.entries->mapnew(function('s:doc_entry')))
        catch
            :echoerr $'{slug}/index.json decode failed ({v:exception})'
        endtry
    endfor
    let s:docs_list = items
    return s:docs_list
endfun

fun! s:listDocs(prefix, line, cursorPos)
    let docs = s:getDocsList()
    return docs->mapnew({_, v -> v.text})->join("\n")
endfun

fun! s:Page(target, slug, absolute_path)
    let [path, tag] = ['', '']
    let tagidx = a:target->strridx('#')
    if tagidx == 0
        let tag = a:target->slice(1)->trim()
    elseif tagidx != -1
        let tag = a:target->slice(tagidx + 1)->trim()
        let path = a:target->slice(0, tagidx)->trim()
    elseif a:target != ''
        let path = a:target
    endif
    let curpage = bufnr()->getbufvar('page')
    if path != ''
        " could be absolute or relative path
        " do not use fnameescape() as it escapes $localize.html in angular which fails
        let fullpath = $'{s:data_dir->expand()}/{a:slug}/{path}.html'
        if fullpath->filereadable()
            return #{path: path, slug: a:slug, tag: tag}
        elseif a:absolute_path
            :echoerr $'Failed to locate {fullpath}'
            return {}
        endif
        let tail = $'{curpage.path->fnamemodify(":h")}/{path}'
        let fullpath = $'{s:data_dir->expand()}/{a:slug}/{tail}.html'
        if fullpath->filereadable()
            return #{path: tail, slug: a:slug, tag: tag}
        endif
    endif
    return #{path: curpage.path, slug: a:slug, tag: tag, doc: curpage.doc}
endfun

fun! s:LoadPage(fpath, slug, absolute_path)
    let page = s:Page(a:fpath, a:slug, a:absolute_path)
    let fullpath = $'{s:data_dir->expand()}/{a:slug}/{page.path}.html'
    if 'pandoc'->exepath() == ''
        :echohl ErrorMsg | echoerr $'Failed to find pandoc' | echohl None
        return
    endif
    let scriptdir = getscriptinfo(#{name: 'legacy.vim'})[0].name->fnamemodify(':h:h')
    let TEXT_INDENT = 4
    let right_margin = 2 * TEXT_INDENT
    let docwidth = min([300, max([winwidth(0) - right_margin, 50])])

    let msg = system($'pandoc --columns={docwidth} -t "{scriptdir}/pandoc/writer.lua" "{fullpath}"')
    let doc = {}
    try
        let doc = msg->json_decode()
    catch
        :echohl ErrorMsg | echoerr $'Pandoc failed ({v:exception})' | echohl None
        return
    endtry
    " tags removed from html table rows show up as errors (do not echo, except for debug)
    " if !doc.error->empty()
    "     echoerr doc.error
    " endif
    let page.doc = doc
    call s:LoadDoc(page)
endfun

fun! s:OpenWinCmd()
    " Use an existing 'devdoc' window if it exists, otherwise open a new one.
    let open_cmd = 'edit'
    if &filetype != "devdoc"
        let thiswin = winnr()
        :exe "norm! \<C-W>b"
        if winnr() > 1
            :exe $"norm! {thiswin}\<C-W>w"
            while &filetype != "devdoc"
                :exe "norm! \<C-W>w"
                if thiswin == winnr()
                    break
                endif
            endwhile
        endif
        if &filetype != "devdoc"
            let height = 20
            let open_cmd = $'{height}split'
        endif
    endif
    return open_cmd
endfun

fun! s:LoadDoc(page)
    let curpage = bufnr()->getbufvar('page')
    if &filetype == 'devdoc'
        call add(s:stack, #{bufnr: bufnr("%"), line: line("."), col: col(".")})
    endif

    let open_cmd = s:OpenWinCmd()
    let randnr = reltime()->reltimestr()->matchstr('\v\.@<=\d+')->slice(0, 3)
    silent execute $":{open_cmd} $HOME/{a:page.slug}.{a:page.path->fnamemodify(':t:r')}.{randnr}~"

    " Avoid warning for editing the dummy file twice
    :setl buftype=nofile noswapfile

    :setl fdc=0 ma nofen nonu nornu
    :%delete _

    " remove null chars (^@) (:h NL-used-for-Nul)
    let cleaned = mapnew(a:page.doc.doc, {_, v -> v->substitute('[[:cntrl:]]', '', 'g')})
    call setline(1, cleaned)

    :exe $':{s:LineNr(a:page.tag, a:page.doc)}'
    :setl ft=devdoc nomod bufhidden=hide nobuflisted noma
    :setl listchars=trail:\ ,tab:\ \
    :setl fillchars=eob:\

    call setbufvar(bufnr(), 'page', a:page)
    let s:path2bufnr[$'{a:page.slug}/{a:page.path}'] = bufnr('%')
    call s:Syntax(a:page.doc)
endfun

fun! s:LineNr(tag, doc)
    if a:doc.tag->type() == v:t_dict
        return 1
    endif
    if a:doc.tag->type() != v:t_dict
        for t in a:doc.tag
            let tstr = t[0]->trim()
            if tstr == a:tag || (tstr[0] == '#' && tstr->slice(1) == a:tag)
                return t[1]
            endif
        endfor
    endif
    return 1
endfun

fun! s:showDoc(...)
    let dname = join(a:000[0:-2], ' ')
    for item in s:docs_list
        if item.name == dname
            call s:LoadPage(item.data.path, item.slug, v:true)
            break
        endif
    endfor
endfun

fun! s:Syntax(docdict)
    let doc = a:docdict
    let syntax_langs = $'{$VIMRUNTIME}/syntax'->readdir({v -> v =~ '\.vim$'})
    call map(syntax_langs, {_, v -> v->slice(0, -4)})
    let missing = doc.cblangs->copy()->filter({_, v -> syntax_langs->index(v) == -1})
    if doc.cblangs->type() != v:t_dict
        for lang in doc.cblangs
            let cmd = $':syn region devdocCodeBlock matchgroup=helpIgnore start=" >{lang}$" start="^>{lang}$" end="^<$" end=" <$"'
            if missing->index(lang) == -1
                exe $':syntax include @LangPod_{lang} {$VIMRUNTIME}/syntax/{lang}.vim'
                let cmd = $'{cmd} contains=@LangPod_{lang}'
            endif
            if has("conceal")
                :exe $'{cmd} concealends'
                :setl conceallevel=2
            else
                :exe $'{cmd}'
            endif
        endfor
    endif
endfun

command -nargs=+ -complete=custom,s:listDocs DevdocsFind call s:showDoc(<f-args>)

:autocmd filetype devdoc if maparg('q', 'n')->empty() | :nnoremap <buffer> <silent> q :q<CR> | endif

fun! s:canExpandDD()
    if getcmdtype() == ':'
        let context = getcmdline()->strpart(0, getcmdpos() - 1)
        if context == 'dd'
            return 1
        endif
    endif
    return 0
endfun

fun! DevdocsExpandDD()
    cabbr <expr> dd     <SID>canExpandDD() ? 'DevdocsFind' : 'dd'
endfun
