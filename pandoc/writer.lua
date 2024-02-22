-- custom pandoc writer to convert AST to Vim help like format

Writer = pandoc.scaffolding.Writer

local unpack = unpack or table.unpack
local format = string.format
local layout = pandoc.layout
local literal, empty, cr, concat, blankline, chomp, space, cblock, rblock,
    lblock, prefixed, nest, hang, nowrap, height =
    layout.literal, layout.empty, layout.cr, layout.concat, layout.blankline,
    layout.chomp, layout.space, layout.cblock, layout.rblock, layout.lblock,
    layout.prefixed, layout.nest, layout.hang, layout.nowrap, layout.height
local footnotes = {}
local links = {}
local TEXT_INDENT = 4
local TEXT_WIDTH = 80
local marker = {link = '¦', strong = '‡', emph = '†', code = '·', underline = '¿'}
local emptylines_around_codeblock = false
local use_terminal_width = true
-- only for unicode font sets, not for 'fixedsys' font.
local extended_ascii = true
local indent_section = false
local divide_section = true
local sepchars = extended_ascii and { '═', '—' } or { '=', '-' }
local doublequote = extended_ascii and { '"', '"'} or {'"', '"'}
local singlequote = extended_ascii and { "'", "'"} or {"'", "'"}

local function string_split(str, pat)
    local split = {}
    for s in str:gmatch(pat) do
        table.insert(split, s)
    end
    return split
end

local function set_columns(opts)
    if opts.columns == pandoc.WriterOptions({}).columns then
        -- 'columns' is not set in command line
        opts.columns = TEXT_WIDTH
        if not use_terminal_width then
            return
        end
        local out = pandoc.pipe('tput', {'cols'}, '')
        local num = tonumber(out, 10)
        local right_margin = 2 * TEXT_INDENT
        if num then
            opts.columns = math.min(300, math.max(num - right_margin, 70))
            return
        end
        out = string_split(pandoc.pipe('stty', {'size'}, ''), '[^ ]+')
        if #out == 2 then
            num = tonumber(out[2], 10)
            if num then
                opts.columns = math.min(300, math.max(num - right_margin, 70))
            end
        end
    end
end

local format_number = {}
format_number.Decimal = function(n)
    return format("%d", n)
end
format_number.Example = format_number.Decimal
format_number.DefaultStyle = format_number.Decimal
format_number.LowerAlpha = function(n)
    return string.char(96 + (n % 26))
end
format_number.UpperAlpha = function(n)
    return string.char(64 + (n % 26))
end
format_number.UpperRoman = function(n)
    return to_roman(n)
end
format_number.LowerRoman = function(n)
    return string.lower(to_roman(n))
end

local function is_tight_list(el)
    if not (el.tag == "BulletList" or el.tag == "OrderedList" or
        el.tag == "DefinitionList") then
        return false
    end
    for i=1,#el.content do
        if #el.content[i] == 1 and el.content[i][1].tag == "Plain" then
            -- no change
        elseif #el.content[i] == 2 and el.content[i][1].tag == "Plain" and
            el.content[i][2].tag:match("List") then
            -- no change
        else
            return false
        end
    end
    return true
end

-- remove marker chars and obtain marked positions through DFS
-- 'init' is the index of char just previous to start of line
local function scrub(line, lnum, init)
    local function pattern(ch)
        return ch .. '([^' .. ch .. ']+)' .. ch
    end
    local function first_match(start)
        local fbegin, fend, fcapture, ftype = #line + 1
        for mtype, ch in pairs(marker) do
            local s, e, capture = line:find(pattern(ch), start)
            if s and s < fbegin then
                fbegin, fend, fcapture, ftype = s, e, capture, mtype
            end
        end
        if fbegin > #line then
            return nil
        end
        return fbegin, fend, fcapture, ftype
    end
    local mitems, slist, unseen = {}, {}, 1
    for k in pairs(marker) do
        mitems[k] = {}
    end
    local function slistlen()
        local sll = 0
        for _, s in ipairs(slist) do
            sll = sll + s:len()
        end
        return sll
    end
    local s, e, capture, mtype = first_match(unseen)
    -- s points to first byte of left marker (2-3 bytes utf-8) and e points to last byte of right marker
    while s do
        if s > unseen then
            table.insert(slist, line:sub(unseen, s - 1))
        end
        local markerlen = string.len(marker[mtype])
        local scrubbed, items = scrub(line:sub(s + markerlen, e - markerlen), lnum, s - 1)
        table.insert(mitems[mtype], {lnum, init + slistlen() + 1, init + slistlen() + #scrubbed, scrubbed})
        table.insert(slist, scrubbed)
        if items then
            for mtype in pairs(marker) do
                local from, to = items[mtype], mitems[mtype]
                table.move(from, 1, #from, #to + 1, to)
            end
        end
        unseen = e + 1
        s, e, capture, mtype = first_match(unseen)
    end
    if unseen <= #line then
        table.insert(slist, line:sub(unseen))
    end
    return table.concat(slist), mitems
end

local function demarkup(doc)
    local lnum = 1
    local formatted = {}
    local error = {}
    local startl = 1
    local endl = doc:find('\n', 1, true)
    local tag, codeblock, defn, blockquote = {}, {}, {}, {}
    local h = {{}, {}, {}, {}, {}, {}}
    local mitems = {}
    for k in pairs(marker) do
        mitems[k] = {}
    end
    local startcb = -1
    local startbq = -1
    while endl do
        local line = doc:sub(startl, endl - 1)  -- remove \n from the end
        -- tagged regions
        if line:find('%s*>>$') then
            startbq = lnum
        elseif startbq ~= -1 and line:find('%s*<<$') then
            table.insert(blockquote, {startbq, lnum})
            startbq = -1
        elseif line:find('%s*>$') then
            startcb = lnum
        elseif startcb ~= -1 and line:find('%s*<$') then
            table.insert(codeblock, {startcb, lnum})
            startcb = -1
        else
            -- tagged lines
            local st, en, capture = line:find('%s*::: ([^ ]+)')
            if st then
                table.insert(tag, {capture, lnum})
            else
                if line:find(' ¶$') then
                    table.insert(defn, lnum)
                    line = line:sub(1, #line - 3)
                elseif line:find('~$') then
                    for i = 1, 6 do
                        if line:find(' ' .. string.rep('~', i) .. '$') then
                            table.insert(h[i], lnum)
                            line = line:sub(1, #line - i - 1)
                        end
                    end
                end
                -- tagged words
                local scrubbed, items = scrub(line, lnum, 0)
                for mtype in pairs(marker) do
                    local from, to = items[mtype], mitems[mtype]
                    table.move(from, 1, #from, #to + 1, to)
                end
                table.insert(formatted, scrubbed .. '\n')
                lnum = lnum + 1
            end
        end
        startl = endl + 1
        endl = doc:find('\n', startl, true)
    end
    local function link_add_target()
        local function target(src)
            for lnk, tgt in pairs(links) do
                if src == lnk then
                    return tgt
                end
            end
            table.insert(error, 'missing link target for {' .. src .. '}')
            return nil
        end
        local items = {}
        for _, lnk in ipairs(mitems.link) do
            local tgt = target(lnk[1])
            if tgt then
                table.insert(items, {lnk[1], tgt, lnk[2], lnk[3], lnk[4]})
            end
        end
        return items
    end
    local res = {}
    res.doc, res.error, res.tag, res.codeblock, res.blockquote, res.defn,
        res.link, res.strong, res.emph, res.code, res.underline,
        res.h1, res.h2, res.h3, res.h4, res.h5, res.h6 =
        formatted, error, tag, codeblock, blockquote, defn, link_add_target(),
        mitems.strong, mitems.emph, mitems.code, mitems.underline,
        h[1], h[2], h[3], h[4], h[5], h[6]
    return res
end

Writer.Pandoc = function(doc, opts)
    set_columns(opts)
    local sectioned = pandoc.utils.make_sections(true, nil, doc.blocks)
    local d = Writer.Blocks(sectioned)
    local notes = {}
    for i=1,#footnotes do
        local note = hang(Writer.Blocks(footnotes[i]), TEXT_INDENT, concat{format("[^%d]:",i),space})
        table.insert(notes, note)
    end
    local formatted = concat{d, blankline, concat(notes, blankline)}
    if not indent_section then
        -- indent the whole document
        formatted = nest(formatted, 2)
    end
    -- Doc type returned by layout functions is just a string
    local doc = layout.render(formatted, opts.columns)
    local payload = demarkup(doc)
    -- return concat{table.concat(payload.doc), cr}
    return pandoc.json.encode(payload)
end

Writer.Block.Header = function(el, opts)
    local result = {}
    if el.level < 5 then
        result = {}
        for _, str in ipairs({Writer.Inlines(el.content), space, string.rep('~', math.min(6, el.level))}) do
            table.insert(result, str)
        end
    else
        result = { Writer.Inlines(el.content), space, '~' }
    end
    return nowrap(concat(result))
end

Writer.Block.Div = function(el, opts)
    -- local doc = Writer.Blocks(el.content, opts, blankline)
    local doc = Writer.Blocks(el.content)
    if el.classes:includes("section") then
        if el.attr and el.attr.attributes and el.attr.attributes.number then
            local section = el.attr.attributes.number
            local fragments = string_split(section, '[^.]+')
            local indent = 0
            if indent_section then
                -- apply one unit of indent per heading level (even if levels may or may not be nested)
                indent = (#fragments > 1 and #fragments < 4) and TEXT_INDENT or 0
            end
            local sec = ''
            if divide_section then
                sec = extended_ascii and ('§' .. section) or ('[' .. section .. ']')
                if #fragments < 4 then
                    -- horizontal line above section header
                    local schar = #fragments == 1 and sepchars[1] or sepchars[2]
                    local slen = opts.columns - indent - 1 - string.len(sec)
                    sec = nowrap(concat{string.rep(schar, slen), space, sec})
                else
                    sec = nowrap(sec)
                end
            end
            if #fragments > 1 then
                return nest(concat{sec, cr, doc}, indent)
            else
                return concat{sec, cr, doc}
            end
        else
            if el.attr.identifier ~= nil and el.attr.identifier ~= '' then
                return concat{lblock(nowrap(concat{"::: ", el.attr.identifier}), opts.columns), cr, doc, cr }
            end
        end
    end
    return doc
end

Writer.Block.RawBlock = function(el)
    if el.format == "devdoc" then
        return concat({el.text})
    elseif el.format == "rst_table" then
        local lines = string_split(el.text, "[^\r\n]+")  -- \r is CR (ascii 13), \n is LF (ascii 10)
        local formatted = {}
        for i, s in ipairs(lines) do
            local str = empty
            if s:find('^+(=+)+') then
                str = s:gsub('^+', '╞'):gsub('+$', '╡'):gsub('+', '╪'):gsub('=', '═')
            elseif s:find('^+(-+)+') then
                if i == 1 then
                    str = s:gsub('^+', '┌'):gsub('+$', '┐'):gsub('+', '┬'):gsub('-', '─')
                elseif i == #lines then
                    str = s:gsub('^+', '└'):gsub('+$', '┘'):gsub('+', '┴'):gsub('-', '─')
                else
                    str = s:gsub('^+', '├'):gsub('+$', '┤'):gsub('+', '┼'):gsub('-', '─')
                end
            else
                str = s:gsub(' | ', ' │ '):gsub('^|', '│'):gsub('|$', '│')
            end
            table.insert(formatted, str)
        end
        return concat{table.concat(formatted, '\n'), cr}
    else
        return concat{el.text, cr}
    end
end

Writer.Block.Null = function(el)
    return empty
end

Writer.Block.LineBlock = function(el)
    local result = {}
    for i=1,#el.content do
        result[#result + 1] = Writer.Inlines(el.content[i])
    end
    return concat(result, concat{"\\", cr})
end

Writer.Block.Table = function(el, opts)
    -- 'plain' table overflows column width on some occasions. 'rst' table is
    -- more reliable, but it includes lots of markup. first, cleanup the
    -- markup (otherwise table will look wonky after concealed text) and
    -- use 'rst' writer for formatting table.
    local function filter()
        local filter = {}
        filter.Link = function(el, opts)
            return pandoc.utils.stringify(el.content)
        end
        filter.Code = function(el, opts)
            return el.text
        end
        filter.Table = function(el, opts)
            -- remove caption, as it will create markup artifacts from 'rst'.
            return pandoc.Table({long = '', short = ''}, el.colspecs, el.head, el.bodies, el.foot, el.attr)
        end
        for _, inline in ipairs({'Image', 'Math', 'Note' }) do
            filter[inline] = function(el, opts)
                return pandoc.write(pandoc.Pandoc({el}), "plain", opts)
            end
        end
        for _, inline in ipairs({'Cite', 'Emph', 'SmallCaps', 'Strikeout',
            'Strong', 'Subscript', 'Subscript', 'Underline' }) do
            filter[inline] = function(el, opts)
                return el.content
            end
        end
        for _, block in ipairs({
            'Div', 'BlockQuote', 'BulletList', 'CodeBlock', 'DefinitionList',
            'Figure', 'Header', 'HorizontalRule', 'LineBlock', 'OrderedList',
            'Para', 'Plain', 'RawBlock',
        }) do
            filter[block] = function(el, opts)
                return pandoc.write(pandoc.Pandoc({el}), "plain", opts)
            end
        end
        return filter
    end
    local savedcols = opts.columns
    opts.columns = opts.columns - TEXT_INDENT
    local table = pandoc.write(pandoc.Pandoc({el}):walk(filter()), "rst", opts)
    opts.columns = savedcols
    if extended_ascii then
        return Writer.Block.RawBlock(pandoc.RawBlock('rst_table', table))
    else
        return table
    end
end

Writer.Block.DefinitionList = function(el)
    local result = {}
    for i=1,#el.content do
        local term , defs = unpack(el.content[i])
        local inner = empty
        for j=1,#defs do
            inner = concat{inner, cr, Writer.Blocks(defs[j])}
        end
        result[#result + 1] =
            hang(inner, TEXT_INDENT, concat{ Writer.Inlines(term), space, '¶', blankline })
    end
    return concat(result, blankline)
end

Writer.Block.BulletList = function(el)
    local result = {cr}
    for i=1,#el.content do
        result[#result + 1] = hang(Writer.Blocks(el.content[i]), 2, concat{"-",space})
    end
    local sep = blankline
    if is_tight_list(el) then
        sep = cr
    end
    return concat(result, sep)
end

Writer.Block.OrderedList = function(el)
    local result = {cr}
    local num = el.start
    local width = 3
    local maxnum = num + #el.content
    if maxnum > 9 then
        width = 4
    end
    local delimfmt = "%s."
    if el.delimiter == "OneParen" then
        delimfmt = "%s)"
    elseif el.delimiter == "TwoParens" then
        delimfmt = "(%s)"
    end
    local sty = el.style
    for i=1,#el.content do
        local barenum = format_number[sty](num)
        local numstr = format(delimfmt, barenum)
        local sps = width - #numstr
        local numsp
        if sps < 1 then
            numsp = space
        else
            numsp = string.rep(" ", sps)
        end
        result[#result + 1] = hang(Writer.Blocks(el.content[i]), width, concat{numstr,numsp})
        num = num + 1
    end
    local sep = blankline
    if is_tight_list(el) then
        sep = cr
    end
    return concat(result, sep)
end

Writer.Block.CodeBlock = function(el)
    return concat{ '>', cr, nest(el.text:gsub('%s*$', ''), TEXT_INDENT), cr, '<' }
end

do
    for _, block in ipairs({'Para', 'Plain'}) do
        Writer.Block[block] = function(el, opts)
            return Writer.Inlines(el.content, opts)
        end
    end
end

Writer.Block.BlockQuote = function(el)
    -- return concat{'>>', cr, nest(Writer.Blocks(el.content), TEXT_INDENT), cr, '<<'}
    return concat{'>>', cr, Writer.Blocks(el.content), cr, '<<'}
end

Writer.Block.HorizontalRule = function(el, opts)
    return cblock("* * * * *", opts.columns)
end

do
    for _, inline in ipairs({'SmallCaps', 'Span', 'Cite'}) do
        Writer.Inline[inline] = function(el, opts)
            return Writer.Inlines(el.content, opts)
        end
    end
end

Writer.Inline.Str = function(el)
    return el.text
end

Writer.Inline.Space = function(el)
    return space
end

Writer.Inline.SoftBreak = function(el, opts)
    if opts.wrap_text == "wrap-preserve" then
        return cr
    else
        return space
    end
end

Writer.Inline.LineBreak = function(el)
    return cr
end

Writer.Inline.RawInline = function(el)
    return el.text
end

Writer.Inline.Code = function(el)
    local result = {marker.code, el.text, marker.code}
    return concat(result)
end

Writer.Inline.Emph = function(el)
    return concat{marker.emph, Writer.Inlines(el.content), marker.emph}
end

Writer.Inline.Strong = function(el)
    return concat{marker.strong, Writer.Inlines(el.content), marker.strong}
end

Writer.Inline.Strikeout = function(el)
    return concat{ "{-", Writer.Inlines(el.content), "-}" }
end

Writer.Inline.Subscript = function(el)
    return concat{ "{~", Writer.Inlines(el.content), "~}" }
end

Writer.Inline.Superscript = function(el)
    return concat{ "{^", Writer.Inlines(el.content), "^}" }
end

Writer.Inline.Underline = function(el)
    return concat{marker.underline, Writer.Inlines(el.content), marker.underline}
end

Writer.Inline.Math = function(el)
    local mark
    if el.mathtype == "DisplayMath" then
        mark = "$$"
    else
        mark = "$"
    end
    return concat{ mark, Inlines.Code(el) }
end

Writer.Inline.Link = function(el)
    if string.find(el.target, 'http') == nil then
        local rendered = pandoc.utils.stringify(el.content)
        links[rendered] = el.target
        local result = {marker.link, rendered, marker.link}
        return nowrap(concat(result))
    end
    return Writer.Inlines(el.content)
end

Writer.Inline.Image = function(el)
    local result = {"![", Writer.Inlines(el.caption), "](", el.src, ")"}
    return concat(result)
end

Writer.Inline.Quoted = function(el)
    if el.quotetype == "DoubleQuote" then
        return concat{doublequote[1], Writer.Inlines(el.content), doublequote[2]}
    else
        return concat{singlequote[1], Writer.Inlines(el.content), singlequote[2]}
    end
end

Writer.Inline.Note = function(el)
    footnotes[#footnotes + 1] = el.content
    local num = #footnotes
    return literal(format("[^%d]", num))
end

-- examples: https://github.com/jgm/djot.lua/blob/main/djot-writer.lua
--  and pandoc/pandoc-lua-engine/test/sample.lua
