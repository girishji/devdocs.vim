-- custom pandoc writer to convert AST to devdoc file
-- examples: https://github.com/jgm/djot.lua/blob/main/djot-writer.lua
--  and pandoc/pandoc-lua-engine/test/sample.lua

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
local emptylines_around_codeblock = false
local use_terminal_width = true
-- only for unicode font sets, not for 'fixedsys' font.
local extended_ascii = true
-- local extended_ascii = false
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
        -- column option not set through command line
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

local function has_attributes(el)
    return el.attr and
    (#el.attr.identifier > 0 or #el.attr.classes > 0 or #el.attr.attributes > 0)
end

-- for debugging purpose only
local function render_attributes(el, isblock, opts)
    if not has_attributes(el) then
        return empty
    end
    local attr = el.attr
    local buff = {"{"}
    if #attr.identifier > 0 then
        buff[#buff + 1] = "#" .. attr.identifier
    end
    for i=1,#attr.classes do
        if #buff > 1 then
            buff[#buff + 1] = space
        end
        buff[#buff + 1] = "." .. attr.classes[i]
    end
    for k,v in pairs(attr.attributes) do
        if #buff > 1 then
            buff[#buff + 1] = space
        end
        buff[#buff + 1] = k .. '="' .. v:gsub('"', '\\"') .. '"'
    end
    buff[#buff + 1] = "}"
    if isblock then
        return rblock(nowrap(concat(buff)), opts.columns)
    else
        return concat(buff)
    end
end

-- local function blocks(bs, opts, sep)
--     if emptylines_around_codeblock then
--         return Writer.Blocks(bs)
--     end
--     -- remove empty lines above and below CodeBlock
--     --   Writer.Blocks() automatically inserts blankline between blocks
--     local docs = {}
--     local blocks = {}
--     for i, block in ipairs(bs) do
--         if block.tag == 'CodeBlock' or (block.tag == 'BlockQuote' and
--             #block.content > 0 and block.content[1].tag == 'CodeBlock') then
--             if blocks then
--                 table.insert(docs, Writer.Blocks(blocks))
--                 blocks = {}
--             end
--             if block.tag == 'CodeBlock' then
--                 table.insert(docs, concat{cr, Writer.Block.CodeBlock(block, opts), cr})
--             else
--                 table.insert(docs, concat{cr, Writer.Block.BlockQuote(block, opts), cr})
--             end
--         else
--             table.insert(blocks, block)
--         end
--     end
--     if blocks then
--         table.insert(docs, Writer.Blocks(blocks))
--     end
--     return concat(docs)
-- end

local function markup(doc)
    local function desurround(line, ch, extended_ascii)
        local captures = {}
        local pat = ch .. '([^' .. ch .. ']+)' .. ch
        local s, e, capture = line:find(pat)
        while s do
            -- utf-8 extended ascii char (256-512) takes 2 bytes
            table.insert(captures, {capture, lnum, s, e - (extended_ascii and 4 or 2)})
            s, e, capture = line:find(pat, e + 1)
        end
        return captures
    end
    local res = {}
    local formatted = {}
    local lnum = 1
    local startl = 1
    local endl = doc:find('\n', 1, true)
    local target, pre, defn = {}, {}, {}
    local h = {{}, {}, {}, {}, {}, {}}
    local mchar = {'¦', '‡', '†', '·'}
    local marker = {{}, {}, {}, {}}
    local startpre = -1
    while endl do
        local line = doc:sub(startl, endl - 1)  -- remove \n from the end
        if line:find('%s*>$') then
            startpre = lnum
        elseif startpre ~= -1 and line:find('%s*<$') then
            table.insert(pre, {startpre, lnum})
            startpre = -1
        else
            local st, en, capture = line:find('%s*::: ([^ ]+)')
            if st then
                table.insert(target, capture)
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
                for i, ch in ipairs(mchar) do
                    local elems = desurround(line, ch, true)
                    local container = marker[i]
                    table.move(elems, 1, #elems, #container + 1, container)
                end
                for _, ch in ipairs(mchar) do
                    line = line:gsub(ch, '')
                end
                table.insert(formatted, line .. '\n')
                lnum = lnum + 1
            end
        end
        startl = endl + 1
        endl = doc:find('\n', startl, true)
    end
    for _, hotlink in ipairs(marker[1]) do
        local found = false
        for lnk in pairs(links) do
            if hotlink[1] == lnk then
                found = true
                break
            end
        end
        if not found then
            print('missing')
            print(table.unpack(hotlink))
        end
    end
    -- print('emph')
    -- for _, item in ipairs(emph) do
    --     print(table.unpack(item))
    -- end
    -- print('strong')
    -- for _, item in ipairs(strong) do
    --     print(table.unpack(item))
    -- end

    res.link = marker[1]
    -- for _, lnk in ipairs(links) do
    --     print(table.unpack(lnk))
    -- end
    res.doc = formatted
    return res
end


Writer.Pandoc = function(doc, opts)
    set_columns(opts)
    local sectioned = pandoc.utils.make_sections(true, nil, doc.blocks)
    -- local d = Writer.Blocks(sectioned, opts, blankline)
    local d = Writer.Blocks(sectioned)
    local notes = {}
    for i=1,#footnotes do
        local note = hang(Writer.Blocks(footnotes[i]), TEXT_INDENT, concat{format("[^%d]:",i),space})
        table.insert(notes, note)
    end
    local formatted = concat{d, blankline, concat(notes, blankline)}
    local doc = layout.render(formatted, opts.columns)
    -- local formatted = concat{d, blankline, concat(notes, blankline), blankline, concat(hotlinks, cr)}
    -- local hotlinks = { '>>>>>>>>>><<<<<<<<<<' }
    -- for key, val in pairs(links) do
    --     table.insert(hotlinks, concat{key, '\t', val})
    -- end
    local formatted = markup(doc)
    return concat{table.concat(formatted.doc), cr}
end

Writer.Block.Header = function(el, opts)
    local result = {}
    if el.level < 5 then
        result = {}
        -- for _, str in ipairs({ Writer.Inlines(el.content), space, '~' }) do
        for _, str in ipairs({Writer.Inlines(el.content), space, string.rep('~', math.min(4, el.level))}) do
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
            -- apply one unit of indent per heading level (even if levels may or may not be nested)
            local indent = (#fragments > 1 and #fragments < 4) and TEXT_INDENT or 0
            local sec = extended_ascii and ('§' .. section) or ('[' .. section .. ']')
            if #fragments < 4 then
                local schar = #fragments == 1 and sepchars[1] or sepchars[2]
                local slen = opts.columns - indent - 1 - string.len(sec)
                sec = nowrap(concat{string.rep(schar, slen), space, sec})
            else
                sec = nowrap(sec)
            end
            local fragments = string_split(section, '[^.]+')
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
    return Writer.Blocks(el.content)
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
    local result = { '·', el.text, '·' }
    return concat(result)
end

Writer.Inline.Emph = function(el)
    return concat{ "†", Writer.Inlines(el.content), "†" }
end

Writer.Inline.Strong = function(el)
    return concat{ "‡", Writer.Inlines(el.content), "‡" }
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
    return concat{ "…", Writer.Inlines(el.content), "…" }
end

Writer.Inline.Math = function(el)
    local marker
    if el.mathtype == "DisplayMath" then
        marker = "$$"
    else
        marker = "$"
    end
    return concat{ marker, Inlines.Code(el) }
end

Writer.Inline.Link = function(el)
    if string.find(el.target, 'http') == nil then
        local rendered = pandoc.utils.stringify(el.content)
        links[rendered] = el.target
        local result = {"¦", rendered, "¦"}
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
