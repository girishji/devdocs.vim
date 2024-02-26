vim9script

import './options.vim'
import './syntax.vim'
import './task.vim'

var stack = []
var data_dir = options.opt.data_dir
var curpage: dict<any> = null_dict
var path2bufnr: dict<any>

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
    for t in doc.tag
        var tstr = t[0]->trim()
        if tstr == tag || (tstr[0] == '#' && tstr->slice(1) == tag)
            return t[1]
        endif
    endfor
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
        return true
    endif
    var open_cmd = OpenWinCmd()
    silent execute $":{open_cmd}"
    execute $':{path2bufnr[fpath]}b'
    :setl bufhidden=hide
    :setl nobuflisted
    :setl noma
    curpage = page
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
            page.doc = doc
            LoadDoc(page)
        })
enddef

export def GetPage()
    var curline = line('.')
    var curcol = col('.')
    for lnk in curpage.doc.link
        if lnk[2] == curline && curcol <= lnk[4] && curcol >= lnk[3]
            LoadPage(lnk[1], curpage.slug)
            return
        endif
    endfor
    echoerr 'devdoc: link target not found'
enddef

export def LoadDoc(page: dict<any>)
    stack->add({bufnr: bufnr("%"), line: line("."), col: col("."), page: curpage})
    curpage = page

    var open_cmd = OpenWinCmd()
    def Rand(): string
        return reltime()->reltimestr()->matchstr('\v\.@<=\d+')->slice(0, 3)
    enddef
    silent execute $":{open_cmd} $HOME/{page.slug}.{page.path->fnamemodify(':t:r')}.{Rand()}~"

    # Avoid warning for editing the dummy file twice
    :setl buftype=nofile noswapfile

    :setl fdc=0 ma nofen nonu nornu
    :%delete _

    # remove null chars (^@) (:h NL-used-for-Nul)
    (page.doc.doc)->mapnew((_, v) => v->substitute('[[:cntrl:]]', '', 'g'))->setline(1)

    :exe $':{LineNr(page.tag, page.doc)}'
    :setl ft=devdoc nomod
    :setl bufhidden=hide
    :setl nobuflisted
    :setl noma
    path2bufnr[$'{page.slug}/{page.path}'] = bufnr('%')
    syntax.Syntax(page.doc)
enddef

export def PopPage()
    if !stack->empty()
        var entry = stack->remove(-1)
        exec $':{entry.bufnr}b'
        cursor(entry.line, entry.col)
        curpage = entry.page
    endif
enddef
