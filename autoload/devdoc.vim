vim9script

# var curslug: string, curpath: string, curtag: string
var properties = {
    DevdocCodeblock: 'None',
    DevdocBlockquote: 'None',
    DevdocDefn: 'Statement',
    DevdocLink: 'Underlined',
    # DevdocStrong: 'Special',
    # DevdocEmph: 'Preproc',
    # DevdocCode: 'CursorLine',
    DevdocCode: 'String',
    DevdocUnderline: 'Underlined',
    DevdocSection: 'Comment',
    DevdocH1: 'Identifier',
    DevdocH2: 'Constant',
    DevdocH3: 'Identifier',
    DevdocH4: 'Identifier',
    DevdocH5: 'Statement',
    DevdocH6: 'Statement',
}

def Syntax(doc: dict<any>)
    for [typ, lnk] in properties->items()
        if empty(prop_type_get(typ))
            exe $'highlight default link {typ} {lnk}'
            var priority = typ == 'DevdocLink' ? 1001 : 1000
            typ->prop_type_add({highlight: typ, override: true, priority: priority})
        endif
    endfor
    if empty(prop_type_get('DevdocStrong'))
        :highlight default DevdocStrong term=bold cterm=bold gui=bold
        'DevdocStrong'->prop_type_add({highlight: 'DevdocStrong', override: true, priority: 1000})
    endif
    if empty(prop_type_get('DevdocEmph'))
        :highlight default DevdocEmph term=italic cterm=italic gui=italic
        'DevdocEmph'->prop_type_add({highlight: 'DevdocEmph', override: true, priority: 1000})
    endif
    for tag in ['code', 'emph', 'strong', 'underline']
        var group = $'Devdoc{tag[0]->toupper()}{tag[1 : ]}'
        if doc[tag]->type() != v:t_dict  # lua empty list becomes empty dict in json
            {type: group}->prop_add_list((doc[tag])->mapnew((_, v) => [v[0], v[1], v[0], v[2] + 1]))
        endif
    endfor
    if doc.link->type() != v:t_dict
        {type: 'DevdocLink'}->prop_add_list((doc.link)->mapnew((_, v) => [v[2], v[3], v[2], v[4] + 1]))
    endif
    for tag in ['defn', 'section', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']
        var group = $'Devdoc{tag[0]->toupper()}{tag[1 : ]}'
        if doc[tag]->type() != v:t_dict
            {type: group}->prop_add_list((doc[tag])->mapnew((_, v) => [v, 1, v, 1000]))
        endif
    endfor
    # for tag in ['blockquote', 'codeblock']
    #     var group = $'Devdoc{tag[0]->toupper()}{tag[1 : ]}'
    #     if doc[tag]->type() != v:t_dict
    #         {type: group}->prop_add_list((doc[tag])->mapnew((_, v) => [v[0], 1, v[1], 1000]))
    #     endif
    # endfor
enddef

import './options.vim'

var stack = []
var data_dir = options.opt.data_dir
var current: dict<any> = null_dict

def Page(target: string, slug: string): dict<any>
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
        var fullpath = $'{data_dir}/{slug}/{path}.html'->expand()->fnameescape()
        if fullpath->filereadable()
            return {path: path, slug: slug, tag: tag}
        endif
        var tail = $'{current.path->fnamemodify(":h")}/{path}'
        fullpath = $'{data_dir}/{slug}/{tail}.html'->expand()->fnameescape()
        if fullpath->filereadable()
            return {path: tail, slug: slug, tag: tag}
        endif
    endif
    return {path: current.path, slug: slug, tag: tag, doc: current.doc}
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

def LoadLocation(page: dict<any>)
    stack->add({bufnr: bufnr("%"), line: line("."), col: col("."), page: page})
    var linenr = LineNr(page.tag, page.doc)
    :exe $':{linenr}'
enddef

import './task.vim'

export def LoadPage(fpath: string, slug: string)
    var page = Page(fpath, slug)
    if current != null_dict && page.path == current.path
        LoadLocation(page)
        return
    endif
    var fullpath = $'{data_dir}/{slug}/{page.path}.html'->expand()->fnameescape()
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
    for lnk in current.doc.link
        if lnk[2] == curline && curcol <= lnk[4] && curcol >= lnk[3]
            LoadPage(lnk[1], current.slug)
            return
        endif
    endfor
    echoerr 'devdoc: link target not found'
enddef

export def LoadDoc(page: dict<any>)
  # " To support:	    nmap K :Man <cWORD><CR>
  # if page ==? '<cword>'
  #   let what = s:ParseIntoPageAndSection()
  #   let sect = what.section
  #   let page = what.page
  # endif

    stack->add({bufnr: bufnr("%"), line: line("."), col: col("."), page: page})
    current = page

    var open_cmd = 'edit'
    # Use an existing 'devdoc' window if it exists, otherwise open a new one.
    if &filetype != "devdoc"
        var thiswin = winnr()
        :exe "norm! \<C-W>b"
        if winnr() > 1
            :exe "norm! " .. thiswin .. "\<C-W>w"
            while 1
                if &filetype == "devdoc"
                    break
                endif
                :exe "norm! \<C-W>w"
                if thiswin == winnr()
                    break
                endif
            endwhile
        endif
        if &filetype != "devdoc"
            if exists("g:ft_devdoc_open_mode")
                if g:ft_devdoc_open_mode == 'vert'
                    open_cmd = 'vsplit'
                elseif g:ft_devdoc_open_mode == 'tab'
                    open_cmd = 'tabedit'
                else
                    open_cmd = 'split'
                endif
            else
                open_cmd = 'split'
            endif
        endif
    endif

    def Rand(): string
        return reltime()->reltimestr()->matchstr('\v\.@<=\d+')->slice(0, 3)
    enddef
    silent execute $"{open_cmd} $HOME/{page.slug}.{page.path->fnamemodify(':t:r')}.{Rand()}~"

    # Avoid warning for editing the dummy file twice
    :setl buftype=nofile noswapfile

    :setl fdc=0 ma nofen nonu nornu
    :%delete _
    # var unsetwidth = 0
    # if empty($DEVDOC_WIDTH)
    #     $DEVDOC_WIDTH = winwidth(0)
    #     unsetwidth = 1
    # endif

  # " Ensure Vim is not recursively invoked (man-db does this) when doing ctrl-[
  # " on a man page reference by unsetting MANPAGER.
  # " Some versions of env(1) do not support the '-u' option, and in such case
  # " we set MANPAGER=cat.
  # if !exists('s:env_has_u')
  #   call system('env -u x true')
  #   let s:env_has_u = (v:shell_error == 0)
  # endif
  # let env_cmd = s:env_has_u ? 'env -u MANPAGER' : 'env MANPAGER=cat'
  # let env_cmd .= ' GROFF_NO_SGR=1'
  # let man_cmd = env_cmd . ' man ' . s:GetCmdArg(sect, page)

  # silent exec "r !" . man_cmd

    # remove null chars (^@) (:h NL-used-for-Nul)
    (page.doc.doc)->mapnew((_, v) => v->substitute('[[:cntrl:]]', '', 'g'))->setline(1)
    Syntax(page.doc)

    :exe $':{LineNr(page.tag, page.doc)}'
    :setl ft=devdoc nomod
    :setl bufhidden=hide
    :setl nobuflisted
    :setl noma

    :syntax include @Pod /opt/homebrew/share/vim/vim91/syntax/java.vim
    # :syntax region perlPOD start="^=head" end="^=cut" contains=@Pod
    if has("conceal")
        :syn region helpExample	matchgroup=helpIgnore start=" >$" start="^>$" end="^<$" end=" <$" contains=@Pod concealends
        :setl conceallevel=2
    else
        :syn region helpExample	matchgroup=helpIgnore start=" >$" start="^>$" end="^<$" end=" <$" contains=@Pod
    endif

    # nnoremap <buffer> <silent> <c-]> :call dist#man#PreGetPage(v:count)<CR>
    # nnoremap <buffer> <silent> <c-t> :call dist#man#PopPage()<CR>
    # nnoremap <buffer> <silent> q :q<CR>
enddef

export def PopPage()
#   if s:man_tag_depth > 0
#     let s:man_tag_depth = s:man_tag_depth - 1
#     exec "let s:man_tag_buf=s:man_tag_buf_".s:man_tag_depth
#     exec "let s:man_tag_lin=s:man_tag_lin_".s:man_tag_depth
#     exec "let s:man_tag_col=s:man_tag_col_".s:man_tag_depth

#     exec s:man_tag_buf."b"
#     call cursor(s:man_tag_lin, s:man_tag_col)

#     exec "unlet s:man_tag_buf_".s:man_tag_depth
#     exec "unlet s:man_tag_lin_".s:man_tag_depth
#     exec "unlet s:man_tag_col_".s:man_tag_depth
#     unlet s:man_tag_buf s:man_tag_lin s:man_tag_col
#   endif
enddef

# var tag_depth = 0

# let s:man_sect_arg = ""
# let s:man_find_arg = "-w"
# try
#   if !has("win32") && $OSTYPE !~ 'cygwin\|linux'
#     " cache the value
#     let uname_s = system('uname -s')

#     if uname_s =~ "SunOS" && system('uname -r') =~ "^5"
#       " Special Case for Man on SunOS
#       let s:man_sect_arg = "-s"
#       let s:man_find_arg = "-l"
#     elseif uname_s =~? 'AIX'
#       " Special Case for Man on AIX
#       let s:man_sect_arg = ""
#       let s:man_find_arg = ""
#     endif
#   endif
# catch /E145:/
#   " Ignore the error in restricted mode
# endtry

# unlet! uname_s

# func s:ParseIntoPageAndSection()
#   " Accommodate a reference that terminates in a hyphen.
#   "
#   " See init_charset_table() at
#   " https://git.savannah.gnu.org/cgit/groff.git/tree/src/roff/troff/input.cpp?h=1.22.4#n6794
#   "
#   " See can_break_after() at
#   " https://git.savannah.gnu.org/cgit/groff.git/tree/src/roff/troff/charinfo.h?h=1.22.4#n140
#   "
#   " Assumptions and limitations:
#   " 1) Manual-page references (in consequence of command-related filenames)
#   "    do not contain non-ASCII HYPHENs (0x2010), any terminating HYPHEN
#   "    must have been introduced to mark division of a word at the end of
#   "    a line and can be discarded; whereas similar references may contain
#   "    ASCII HYPHEN-MINUSes (0x002d) and any terminating HYPHEN-MINUS forms
#   "    a compound word in addition to marking word division.
#   " 2) Well-formed manual-page references always have a section suffix, e.g.
#   "    "git-commit(1)", therefore suspended hyphenated compounds are not
#   "    determined, e.g.     [V] (With cursor at _git-merge-_ below...)
#   "    ".................... git-merge- and git-merge-base. (See git-cherry-
#   "    pick(1) and git-cherry(1).)" (... look up "git-merge-pick(1)".)
#   "
#   " Note that EM DASH (0x2014), a third stooge from init_charset_table(),
#   " neither connects nor divides parts of a word.
#   let str = expand("<cWORD>")

#   if str =~ '\%u2010$'	" HYPHEN (-1).
#     let str = strpart(str, 0, strridx(str, "\u2010"))

#     " Append the leftmost WORD (or an empty string) from the line below.
#     let str .= get(split(get(getbufline(bufnr('%'), line('.') + 1), 0, '')), 0, '')
#   elseif str =~ '-$'	" HYPHEN-MINUS.
#     " Append the leftmost WORD (or an empty string) from the line below.
#     let str .= get(split(get(getbufline(bufnr('%'), line('.') + 1), 0, '')), 0, '')
#   endif

#   " According to man(1), section name formats vary (MANSECT):
#   " 1 n l 8 3 2 3posix 3pm 3perl 3am 5 4 9 6 7
#   let parts = matchlist(str, '\(\k\+\)(\(\k\+\))')
#   return (len(parts) > 2)
# 	  \ ? {'page': parts[1], 'section': parts[2]}
# 	  \ : {'page': matchstr(str, '\k\+'), 'section': ''}
# endfunc

# func dist#man#PreGetPage(cnt)
#   if a:cnt == 0
#     let what = s:ParseIntoPageAndSection()
#     let sect = what.section
#     let page = what.page
#   else
#     let what = s:ParseIntoPageAndSection()
#     let sect = a:cnt
#     let page = what.page
#   endif

#   call dist#man#GetPage('', sect, page)
# endfunc

# func s:GetCmdArg(sect, page)
#   if empty(a:sect)
#     return shellescape(a:page)
#   endif

#   return s:man_sect_arg . ' ' . shellescape(a:sect) . ' ' . shellescape(a:page)
# endfunc

# func s:FindPage(sect, page)
#   let l:cmd = printf('man %s %s', s:man_find_arg, s:GetCmdArg(a:sect, a:page))
#   call system(l:cmd)

#   if v:shell_error
#     return 0
#   endif

#   return 1
# endfunc

