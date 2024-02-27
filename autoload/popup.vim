vim9script

var options = {
    borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    bordercharsp: ['─', '│', '─', '│', '┌', '┐', '┤', '├'],
    borderhighlight: hlexists('PopupBorderHighlight') ? ['PopupBorderHighlight'] : [],
    popuphighlight: get(g:, "popuphighlight", 'Normal'),
    popupscrollbarhighlight: get(g:, "popupscrollbarhighlight", 'PmenuSbar'),
    popupthumbhighlight: get(g:, "popupthumbhighlight", 'PmenuThumb'),
    promptchar: '>',
}

export class FilterMenuPopup

    var prompt: string = ''
    var id: number
    var idp: number  # id of prompt window
    var title: string
    var items_dict: list<dict<any>>
    var filtered_items: list<any>

    def _CommonProps(borderchars: list<string>, top_pos: number, winheight: number, minwidth: number, maxwidth: number): dict<any>
        return {
            line: top_pos,
            minwidth: minwidth,
            maxwidth: maxwidth,
            minheight: winheight,
            maxheight: winheight,
            border: [],
            borderchars: borderchars,
            borderhighlight: options.borderhighlight,
            highlight: options.popuphighlight,
            scrollbarhighlight: options.popupscrollbarhighlight,
            thumbhighlight: options.popupthumbhighlight,
            drag: 0,
            wrap: 0,
            cursorline: false,
            padding: [0, 1, 0, 1],
            mapping: 0,
        }
    enddef

    def new(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number) = null_function, GetItems: func(list<any>, string): list<any> = null_function)
        if empty(prop_type_get('FilterMenuMatch'))
            highlight default FilterMenuMatch term=bold cterm=bold gui=bold
            prop_type_add('FilterMenuMatch', {highlight: "FilterMenuMatch", override: true, priority: 1000, combine: true})
        endif
        this.title = title
        this.items_dict = items_dict
        this.filtered_items = [this.items_dict]
        var items_count = this.items_dict->len()
        var height = min([&lines - 8, max([items_count, 5])])
        var minwidth = (&columns * 0.6)->float2nr()
        var maxwidth = (&columns - 14)
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

        this.idp = popup_create([$'{options.promptchar}  '],
            # this._CommonProps(options.bordercharsp, pos_top, 1, width, width)->extend({
            this._CommonProps(options.bordercharsp, pos_top, 1, minwidth, maxwidth)->extend({
            title: $" ({items_count}/{items_count}) {this.title}",
            }))
        matchaddpos('Cursor', [[1, 3]], 10, -1, {window: this.idp})

        this.id = popup_create(this._Printify(this.filtered_items),
            this._CommonProps(options.borderchars, pos_top + 3, height, minwidth, maxwidth)->extend({
            border: [0, 1, 1, 1],
            filter: (id, key) => {
                items_count = this.items_dict->len()
                if key == "\<esc>"
                    popup_close(id, -1)
                    popup_close(this.idp, -1)
                elseif ["\<cr>", "\<C-j>", "\<C-v>", "\<C-t>", "\<C-o>"]->index(key) > -1
                        && this.filtered_items[0]->len() > 0 && items_count > 0
                    popup_close(id, {idx: getcurpos(id)[1], key: key})
                    popup_close(this.idp, -1)
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
                    var titletxt = $" ({items_count > 0 ? this.filtered_items[0]->len() : 0}/{items_count}) {this.title}"
                    this.idp->popup_setoptions({title: titletxt})
                    id->popup_settext(this._Printify(this.filtered_items))
                    this.idp->popup_settext($'{options.promptchar} {this.prompt} ')
                    this.idp->clearmatches()
                    matchaddpos('Cursor', [[1, 3 + this.prompt->len()]], 10, -1, {window: this.idp})

                    var new_width = id->popup_getpos().core_width
                    if new_width > minwidth
                        minwidth = new_width
                        popup_move(id, {minwidth: minwidth})
                        var widthp = minwidth + (id->popup_getpos().scrollbar ? 1 : 0)
                        popup_move(this.idp, {minwidth: widthp, maxwidth: widthp})
                    else
                        var pos = id->popup_getpos()
                        var widthp = minwidth + (pos.scrollbar ? 1 : 0)
                        popup_move(this.idp, {minwidth: widthp, maxwidth: widthp})
                    endif
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
        }))
        win_execute(this.id, "setl nu cursorline cursorlineopt=both")
        var widthp = this.id->popup_getpos().scrollbar ? minwidth + 1 : minwidth
        popup_move(this.idp, {minwidth: widthp, maxwidth: widthp})
        if Setup != null_function
            Setup(this.id)
        endif
        this.id = this.id
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
        this.id = popup_create(text, {
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
    enddef
endclass

# Adapted from:
#   https://github.com/habamax/.vim/blob/master/autoload/popup.vim#L89-L89

