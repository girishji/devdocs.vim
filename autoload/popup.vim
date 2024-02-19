vim9script

var options = {
    borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    bordertitle: ['─┐', '┌'],
    borderhighlight: hlexists('PopupBorderHighlight') ? ['PopupBorderHighlight'] : [],
    popuphighlight: get(g:, "popuphighlight", 'Normal'),
    popupscrollbarhighlight: get(g:, "popupscrollbarhighlight", 'PmenuSbar'),
    popupthumbhighlight: get(g:, "popupthumbhighlight", 'PmenuThumb')
}

export class FilterMenuPopup
    var prompt: string = ''
    var id: number
    var title: string
    var items_dict: list<dict<any>>
    var filtered_items: list<any>

    def new(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number) = null_function, GetItems: func(list<any>, string): list<any> = null_function, is_hidden: bool = false, winheight: number = 0, winwidth: number = 0)
        if empty(prop_type_get('FilterMenuMatch'))
            highlight default FilterMenuMatch term=bold cterm=bold gui=bold
            prop_type_add('FilterMenuMatch', {highlight: "FilterMenuMatch", override: true, priority: 1000, combine: true})
        endif
        this.title = title
        this.items_dict = items_dict
        this.filtered_items = [this.items_dict]
        var items_count = this.items_dict->len()
        var height = min([&lines - 6, max([items_count, 5])])
        if winheight > 0
            height = winheight
        endif
        var minwidth = (&columns * 0.6)->float2nr()
        var maxwidth = (&columns - 8)
        if winwidth > 0
            [minwidth, maxwidth] = [winwidth, winwidth]
        endif
        var pos_top = ((&lines - height) / 2) - 1
        var ignore_input = ["\<cursorhold>", "\<ignore>", "\<Nul>",
                    \ "\<LeftMouse>", "\<LeftRelease>", "\<LeftDrag>", $"\<2-LeftMouse>",
                    \ "\<RightMouse>", "\<RightRelease>", "\<RightDrag>", "\<2-RightMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<X1Mouse>", "\<X1Release>", "\<X1Drag>", "\<X2Mouse>", "\<X2Release>", "\<X2Drag>",
                    \ "\<ScrollWheelLeft", "\<ScrollWheelRight>"
        ]
        # this sequence of bytes are generated when left/right mouse is pressed and
        # mouse wheel is rolled
        var ignore_input_wtf = [128, 253, 100]
        var winid = popup_create(this._Printify(this.filtered_items), {
            title: $" ({items_count}/{items_count}) {this.title} {options.bordertitle[0]}  {options.bordertitle[1]}",
            line: pos_top,
            minwidth: minwidth,
            maxwidth: maxwidth,
            minheight: height,
            maxheight: height,
            border: [],
            borderchars: options.borderchars,
            borderhighlight: options.borderhighlight,
            highlight: options.popuphighlight,
            scrollbarhighlight: options.popupscrollbarhighlight,
            thumbhighlight: options.popupthumbhighlight,
            drag: 0,
            wrap: (winwidth > 0) ? 0 : 1,
            cursorline: false,
            padding: [0, 1, 0, 1],
            mapping: 0,
            hidden: is_hidden,
            filter: (id, key) => {
                items_count = this.items_dict->len()
                if winwidth <= 0
                    var new_minwidth = popup_getpos(id).core_width
                    if new_minwidth > minwidth
                        minwidth = new_minwidth
                        popup_move(id, {minwidth: minwidth})
                    endif
                endif
                if key == "\<esc>"
                    popup_close(id, -1)
                elseif ["\<cr>", "\<C-j>", "\<C-v>", "\<C-t>", "\<C-o>"]->index(key) > -1
                        && this.filtered_items[0]->len() > 0 && items_count > 0
                    popup_close(id, {idx: getcurpos(id)[1], key: key})
                elseif key == "\<Right>" || key == "\<PageDown>"
                    win_execute(id, 'normal! ' .. "\<C-d>")
                elseif key == "\<Left>" || key == "\<PageUp>"
                    win_execute(id, 'normal! ' .. "\<C-u>")
                elseif key == "\<tab>" || key == "\<C-n>" || key == "\<Down>" || key == "\<ScrollWheelDown>"
                    var ln = getcurpos(id)[1]
                    win_execute(id, "normal! j")
                    if ln == getcurpos(id)[1]
                        win_execute(id, "normal! gg")
                    endif
                elseif key == "\<S-tab>" || key == "\<C-p>" || key == "\<Up>" || key == "\<ScrollWheelUp>"
                    var ln = getcurpos(id)[1]
                    win_execute(id, "normal! k")
                    if ln == getcurpos(id)[1]
                        win_execute(id, "normal! G")
                    endif
                # Ignoring fancy events and double clicks, which are 6 char long: `<80><fc> <80><fd>.`
                elseif ignore_input->index(key) == -1 && strcharlen(key) != 6 && str2list(key) != ignore_input_wtf
                    if key == "\<C-U>"
                        if this.prompt == ""
                            return true
                        endif
                        this.prompt = ""
                    elseif (key == "\<C-h>" || key == "\<bs>")
                        if this.prompt == ""
                            return true
                        endif
                        this.prompt = this.prompt->strcharpart(0, this.prompt->strchars() - 1)
                    elseif key =~ '\p'
                        this.prompt = this.prompt .. key
                    endif
                    var GetItemsFn = GetItems == null_function ? this._GetItems : GetItems
                    [this.items_dict, this.filtered_items] = GetItemsFn(this.items_dict, this.prompt)
                    popup_setoptions(id, {title: $" ({items_count > 0 ? this.filtered_items[0]->len() : 0}/{items_count}) {this.title} {options.bordertitle[0]} {this.prompt} {options.bordertitle[1]}" })
                    popup_settext(id, this._Printify(this.filtered_items))
                endif
                return true
            },
            callback: (id, result) => {
                if result->type() == v:t_number
                    if result > 0
                        Callback(this.filtered_items[0][result - 1], "")
                    endif
                else
                    Callback(this.filtered_items[0][result.idx - 1], result.key)
                endif
            }
        })
        win_execute(winid, "setl nu cursorline cursorlineopt=both")
        if Setup != null_function
            Setup(winid)
        endif
        this.id = winid
    enddef

    def _GetItems(lst: list<dict<any>>, ctx: string): list<any>
        if ctx->empty()
            return [lst, [lst]]
        else
            var filtered = lst->matchfuzzypos(ctx, {key: "text"})
            return [lst, filtered]
        endif
    enddef

    def _Printify(itemsAny: list<any>): list<any>
        if itemsAny[0]->len() == 0 | return [] | endif
        if itemsAny->len() > 1
            return itemsAny[0]->mapnew((idx, v) => {
                return {text: v.text, props: itemsAny[1][idx]->mapnew((_, c) => {
                    return {col: v.text->byteidx(c) + 1, length: 1, type: 'FilterMenuMatch'}
                })}
            })
        else
            return itemsAny[0]->mapnew((_, v) => {
                return {text: v.text}
            })
        endif
    enddef
endclass

export class NotificationPopup
    var id: number

    def Close()
        if !this.id->popup_getpos()->empty()
            this.id->popup_close()
        endif
    enddef

    def Update(text: list<string>)
        this.id->popup_settext(text)
    enddef

    def new(text: list<string>, DismissedCb: func = null_function)
        var winid = popup_create(text, {
            minwidth: 35,
            zindex: 300,
            mapping: 0,
            border: [],
            padding: [0, 1, 0, 1],
            borderchars: options.borderchars,
            borderhighlight: options.borderhighlight,
            highlight: options.popuphighlight,
            drag: 0,
            filter: (id, key) => {
                if key == "\<esc>"
                    popup_close(id, -2)
                endif
                return true
            },
            callback: (id, result) => {
                # <C-c> sends -1 automatically
                if result == -1 && DismissedCb != null_function
                    DismissedCb()
                endif
            }
        })
        this.id = winid
    enddef
endclass

# Adapted from:
#   https://github.com/habamax/.vim/blob/master/autoload/popup.vim#L89-L89

