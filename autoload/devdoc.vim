vim9script

import './options.vim'
import './syntax.vim'
import './task.vim'

var stack = []
var data_dir = options.opt.data_dir
var path2bufnr: dict<any>

def GetOptionStr(): string
    var omap = {
        use_terminal_width: 'utw',
        extended_ascii: 'ea',
        indent_section: 'is',
        divide_section: 'ds',
        fence_codeblock: 'fc'
    }
    var ostr = null_string
    for [opt, val] in options.opt.format->items()
        var oval = val ? omap[opt] : $'no{omap[opt]}'
        ostr = (ostr == null_string) ? oval : $'{ostr}:{oval}'
    endfor
    return ostr
enddef

def Page(target: string, slug: string, absolute_path: bool): dict<any>
    var [path, tag] = [null_string, null_string]
    var tagidx = target->strridx('#')
    if tagidx == 0
        tag = target->slice(1)->trim()
    elseif tagidx != -1
        tag = target->slice(tagidx + 1)->trim()
        path = target->slice(0, tagidx)->trim()
    elseif target != null_string
        path = target
    endif
    var curpage = bufnr()->getbufvar('page')
    if path != null_string
        # could be absolute or relative path
        # do not use fnameescape() as it escapes $localize.html in angular which fails
        var fullpath = $'{data_dir->expand()}/{slug}/{path}.html'
        if fullpath->filereadable()
            return {path: path, slug: slug, tag: tag}
        elseif absolute_path
            :echohl ErrorMsg | echoerr $'Failed to locate {fullpath}' | echohl None
            return null_dict
        endif
        var tail = $'{curpage.path->fnamemodify(":h")}/{path}'
        fullpath = $'{data_dir->expand()}/{slug}/{tail}.html'
        if fullpath->filereadable()
            return {path: tail, slug: slug, tag: tag}
        endif
    endif
    return {path: curpage.path, slug: slug, tag: tag, doc: curpage.doc}
enddef

def LineNr(tag: string, doc: dict<any>): number
    if doc.tag->type() == v:t_dict
        return 1
    endif
    if doc.tag->type() != v:t_dict
        for t in doc.tag
            var tstr = t[0]->trim()
            if tstr == tag || (tstr[0] == '#' && tstr->slice(1) == tag)
                return t[1]
            endif
        endfor
    endif
    return 1
enddef

def OpenWinCmd(): string
    # Use an existing 'devdoc' window if it exists, otherwise open a new one.
    var open_cmd = 'edit'
    if &filetype != "devdoc"
        var thiswin = winnr()
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
            var height = max([20, options.opt->get('height', 20)])
            var mode = options.opt->get('open_mode', 'split')
            open_cmd = {vert: 'vsplit', tab: 'tabedit', split: $'{height}split'}[mode]
        endif
    endif
    return open_cmd
enddef

def LoadLocation(page: dict<any>): bool
    var fpath = $'{page.slug}/{page.path}'
    if !path2bufnr->has_key(fpath)
        return false
    endif
    if path2bufnr[fpath] == bufnr('%')
        var curpage = bufnr()->getbufvar('page')
        var linenr = LineNr(page.tag, curpage.doc)
        if linenr != line('.')
            stack->add({bufnr: bufnr('%'), line: line('.'), col: col('.')})
            :exe $':{linenr}'
        endif
    else
        stack->add({bufnr: bufnr('%'), line: line('.'), col: col('.')})
        var open_cmd = OpenWinCmd()
        silent execute $':{open_cmd}'
        execute $':{path2bufnr[fpath]}b'
        :setl bufhidden=hide
        :setl nobuflisted
        :setl noma
        var curpage = bufnr()->getbufvar('page')
        :exe $':{LineNr(page.tag, curpage.doc)}'
    endif
    return true
enddef

export def LoadPage(fpath: string, slug: string, absolute_path: bool = false)
    var page = Page(fpath, slug, absolute_path)
    if LoadLocation(page)
        return
    endif
    var fullpath = $'{data_dir->expand()}/{slug}/{page.path}.html'
    if 'pandoc'->exepath() == null_string
        :echohl ErrorMsg | echoerr $'Failed to find pandoc' | echohl None
        return
    endif
    var scriptdir = getscriptinfo({name: 'devdocs'})[0].name->fnamemodify(':h:h')
    var opts = GetOptionStr()
    task.AsyncCmd.new(
        $'{options.opt.pandoc} -t {scriptdir}/pandoc/writer.lua {fullpath}',
        (msg: string) => {
            var doc: dict<any>
            try
                doc = msg->json_decode()
            catch
                :echohl ErrorMsg | echoerr $'Pandoc failed ({v:exception})' | echohl None
                return
            endtry
            # tags removed from html table rows show up as errors (do not echo, except for debug)
            # if !doc.error->empty()
            #     echoerr doc.error
            # endif
            page.doc = doc
            LoadDoc(page)
        }, opts == null_string ? null_dict : {DEVDOC_OPTS: opts})
enddef

def Hotlink(): list<any>
    var curline = line('.')
    var curcol = col('.')
    var curpage = bufnr()->getbufvar('page')
    if curpage.doc.link->type() != v:t_dict
        for lnk in curpage.doc.link
            if lnk[2] == curline && curcol <= lnk[4] && curcol >= lnk[3]
                return lnk
            endif
        endfor
    endif
    return []
enddef

export def GetPage()
    var link = Hotlink()
    if !link->empty()
        var curpage = bufnr()->getbufvar('page')
        LoadPage(link[1], curpage.slug)
    endif
enddef

def DisplayLinkTarget()
    var lnk = Hotlink()
    if !lnk->empty()
        :echo lnk[1]
    else
        :echo ''
    endif
enddef

export def LoadDoc(page: dict<any>)
    var curpage = bufnr()->getbufvar('page')
    stack->add({bufnr: bufnr("%"), line: line("."), col: col(".")})

    var open_cmd: string
    if get(g:, 'loaded_devdocs_tui', false)
        open_cmd = 'edit'
    else
        open_cmd = OpenWinCmd()
    endif
    var randnr = reltime()->reltimestr()->matchstr('\v\.@<=\d+')->slice(0, 3)
    silent execute $":{open_cmd} $HOME/{page.slug}.{page.path->fnamemodify(':t:r')}.{randnr}~"

    # Avoid warning for editing the dummy file twice
    :setl buftype=nofile noswapfile

    :setl fdc=0 ma nofen nonu nornu
    :%delete _

    # remove null chars (^@) (:h NL-used-for-Nul)
    (page.doc.doc)->mapnew((_, v) => v->substitute('[[:cntrl:]]', '', 'g'))->setline(1)

    :exe $':{LineNr(page.tag, page.doc)}'
    :au filetype devdoc au CursorMoved <buffer> DisplayLinkTarget()
    :setl ft=devdoc nomod bufhidden=hide nobuflisted noma
    :setl listchars=trail:\ ,tab:\ \ 
    :setl fillchars=eob:\ 

    page->setbufvar(bufnr(), 'page')
    path2bufnr[$'{page.slug}/{page.path}'] = bufnr('%')
    syntax.Syntax(page.doc)
enddef

export def PopPage()
    if !stack->empty()
        var entry = stack->remove(-1)
        echom 'pop ' entry.bufnr
        exec $':{entry.bufnr}b'
        cursor(entry.line, entry.col)
    endif
enddef

export def DevdocTagStack()
    echom stack
enddef
