vim9script

var properties = {
    DevdocCodeblock: 'Special',
    DevdocBlockquote: 'None',  # codeblocks are sometimes wrapped in blockquote
    DevdocLink: 'Underlined',
    DevdocCode: 'String',
    DevdocUnderline: 'Underlined',
    DevdocSection: 'Comment',
    DevdocDefn: 'PreProc',
    DevdocH1: 'PreProc',
    DevdocH2: 'PreProc',
    DevdocH3: 'PreProc',
    DevdocH4: 'PreProc',
    DevdocH5: 'PreProc',
    DevdocH6: 'PreProc',
}

export def Syntax(doc: dict<any>)
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
    var syntax_langs = $'{$VIMRUNTIME}/syntax'->readdir((v) => v =~ '\.vim$')
    syntax_langs->map((_, v) => v->slice(0, -4))
    var missing = doc.cblangs->copy()->filter((_, v) => syntax_langs->index(v) == -1)
    def LangMissing(lst: list<any>): bool
        return lst->len() == 2 || (lst->len() == 3 && missing->index(lst[2]) != -1)
    enddef
    for tag in ['blockquote', 'codeblock']
        var group = $'Devdoc{tag[0]->toupper()}{tag[1 : ]}'
        if doc[tag]->type() != v:t_dict
            if tag == 'codeblock'
                var lang_absent = (doc[tag])->copy()->filter((_, v) => LangMissing(v))
                {type: group}->prop_add_list(lang_absent->mapnew((_, v) => [v[0], 1, v[1], 1000]))
            else
                {type: group}->prop_add_list((doc[tag])->mapnew((_, v) => [v[0], 1, v[1], 999]))
            endif
        endif
    endfor
    # syntax highlight code blocks
    if doc.cblangs->type() != v:t_dict
        for lang in doc.cblangs
            var cmd = $':syn region devdocCodeBlock matchgroup=helpIgnore start=" >{lang}$" start="^>{lang}$" end="^<$" end=" <$"'
            if missing->index(lang) == -1
                exe $':syntax include @LangPod_{lang} {$VIMRUNTIME}/syntax/{lang}.vim'
                cmd = $'{cmd} contains=@LangPod_{lang}'
            endif
            if has("conceal")
                :exe $'{cmd} concealends'
                :setl conceallevel=2
            else
                :exe $'{cmd}'
            endif
        endfor
    endif
enddef
