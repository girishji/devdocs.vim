-- custom pandoc writer to convert AST to devdoc file
-- example: https://github.com/jgm/djot.lua/blob/main/djot-writer.lua

Writer = pandoc.scaffolding.Writer

local unpack = unpack or table.unpack
local format = string.format
local layout = pandoc.layout
local literal, empty, cr, concat, blankline, chomp, space, cblock, rblock,
  prefixed, nest, hang, nowrap =
  layout.literal, layout.empty, layout.cr, layout.concat, layout.blankline,
  layout.chomp, layout.space, layout.cblock, layout.rblock,
  layout.prefixed, layout.nest, layout.hang, layout.nowrap
local to_roman = pandoc.utils.to_roman_numeral
local footnotes = {}
local links = {}
local to_indent = false
local CODE_INDENT = 4
local TEXT_INDENT = 3
-- local sepchars = { '=', '-' }
local sepchars = { '═', '—' }  -- only for unicode font sets, not for 'fixedsys' font.

local function indent(s)
    if to_indent then
        return nest(s, 2 * TEXT_INDENT)
    else
        return s
    end
end

-- Escape special characters
-- local function escape(s)
--     return (s:gsub("[][\\`{}_*<>~^'\"]", function(s) return "\\" .. s end))
-- end

-- local format_number = {}
-- format_number.Decimal = function(n)
--     return format("%d", n)
-- end
-- format_number.Example = format_number.Decimal
-- format_number.DefaultStyle = format_number.Decimal
-- format_number.LowerAlpha = function(n)
--     return string.char(96 + (n % 26))
-- end
-- format_number.UpperAlpha = function(n)
--     return string.char(64 + (n % 26))
-- end
-- format_number.UpperRoman = function(n)
--     return to_roman(n)
-- end
-- format_number.LowerRoman = function(n)
--     return string.lower(to_roman(n))
-- end

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

-- local function render_attributes(el, isblock)
--     if not has_attributes(el) then
--         return empty
--     end
--     local attr = el.attr
--     local buff = {"{"}
--     if #attr.identifier > 0 then
--         buff[#buff + 1] = "#" .. attr.identifier
--     end
--     for i=1,#attr.classes do
--         if #buff > 1 then
--             buff[#buff + 1] = space
--         end
--         buff[#buff + 1] = "." .. attr.classes[i]
--     end
--     for k,v in pairs(attr.attributes) do
--         if #buff > 1 then
--             buff[#buff + 1] = space
--         end
--         buff[#buff + 1] = k .. '="' .. v:gsub('"', '\\"') .. '"'
--     end
--     buff[#buff + 1] = "}"
--     if isblock then
--         -- XXX
--         -- return rblock(nowrap(concat(buff)), PANDOC_WRITER_OPTIONS.columns)
--         return concat(buff)
--     else
--         return concat(buff)
--     end
-- end

-- Blocks = {}
-- Blocks.mt = {}
-- Blocks.mt.__index = function(tbl,key)
--   return function() io.stderr:write("Unimplemented " .. key .. "\n") end
-- end
-- setmetatable(Blocks, Blocks.mt)

-- Inlines = {}
-- Inlines.mt = {}
-- Inlines.mt.__index = function(tbl,key)
--   return function() io.stderr:write("Unimplemented " .. key .. "\n") end
-- end
-- setmetatable(Inlines, Inlines.mt)

-- local function inlines(ils)
--   local buff = {}
--   for i=1,#ils do
--     local el = ils[i]
--     buff[#buff + 1] = Inlines[el.tag](el)
--   end
--   return concat(buff)
-- end

-- local function blocks(bs, sep)
--   local dbuff = {}
--   for i=1,#bs do
--     local el = bs[i]
--     dbuff[#dbuff + 1] = Blocks[el.tag](el)
--   end
--   return concat(dbuff, sep)
-- end


Writer.Pandoc = function(doc)
    local d = Writer.Blocks(doc.blocks)
    --     lang = " " .. el.classes[1]
    local notes = {}
    for i,f in ipairs(footnotes) do
        local note = string.format("[%d] ",i)  .. " " .. Writer.Blocks(f)
        table.insert(notes, note)
    end
    return {d, '\n\n' ,pandoc.layout.concat(notes, '\n')}
end

Writer.Block.Header = function(el, opts)
    local result = {}
    if el.level < 5 then
        result = {}
        if el.level == 2 then
            result = { string.rep(sepchars[1], opts.columns), cr }
        elseif el.level == 3 then
            result = { string.rep(sepchars[2], opts.columns), cr }
        end
        for _, str in ipairs({ Writer.Inlines(el.content), space, '~' }) do
            table.insert(result, str)
        end
    else
        result = { Writer.Inlines(el.content), space, '~' }
    end
    return concat(result)
end

Writer.Block.Div = function(el)
    -- if el.classes:includes("section") then
    --     -- sections are implicit in djot
    --     if el.identifier and el.content[1].t == "Header" and
    --         el.content[1].identifier == "" then
    --         el.content[1].identifier = el.identifier
    --     end
    --     return Writer.Blocks(el.content)
    --     -- return Writer.Blocks(el.content, blankline)
    -- else
    --     local attr = render_attributes(el, true)
    --     -- return concat{attr, cr, ":::", cr, blocks(el.content, blankline), cr, ":::"}
    --     return concat{attr, cr, ":::", cr, Writer.Blocks(el.content), cr, ":::"}
    -- end
    return nest(Writer.Blocks(el.content), 3)
end

Writer.Block.RawBlock = function(el)
    if el.format == "devdoc" then
        return concat({el.text})
    elseif el.format == "rst_table" then
        local lines = {}
        for s in (el.text):gmatch("[^\r\n]+") do
            table.insert(lines, s)
        end
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
            local src = pandoc.write(pandoc.Pandoc({el}), "plain", opts)
            if #src > 0 then
                src = src:sub(1, #src - 1)  -- remove trailing space
            end
            return src
        end
        filter.Code = function(el, opts)
            return el.text
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
    local table = pandoc.write(pandoc.Pandoc({el}):walk(filter()), "rst", opts)
    return Writer.Block.RawBlock(pandoc.RawBlock('rst_table', table))
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
    -- local ticks = 3
    -- el.text:gsub("(`+)", function(s) if #s >= ticks then ticks = #s + 1 end end)
    -- local fence = string.rep("`", ticks)
    -- local lang = empty
    -- if #el.classes > 0 then
    --     lang = " " .. el.classes[1]
    --     table.remove(el.classes, 1)
    -- end
    -- local attr = render_attributes(el, true)
    -- local result = { attr, cr, fence, lang, cr, el.text, cr, fence, cr }
    -- return concat(result)
    -- local nestval = to_indent and (2 * CODE_INDENT) or CODE_INDENT
    -- local result = { prefixed(nest(el.text:gsub('%s$', ''), nestval), '>') }
    -- local result = { nest(el.text:gsub('%s$', ''), nestval) }
    -- local result = { '>', lang, cr, el.text:gsub('%s*$', ''), cr, '<' }
    local result = { '>', cr, el.text:gsub('%s*$', ''), cr, '<' }
    return concat(result)
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
    return concat({ "\\", cr })
end

Writer.Inline.RawInline = function(el)
    return el.text
end

Writer.Inline.Code = function(el)
    -- local ticks = 0
    -- el.text:gsub("(`+)", function(s) if #s > ticks then ticks = #s end end)
    -- local use_spaces = el.text:match("^`") or el.text:match("`$")
    -- local start = string.rep("`", ticks + 1) .. (use_spaces and " " or "")
    -- local finish = (use_spaces and " " or "") .. string.rep("`", ticks + 1)
    -- local attr = render_attributes(el)
    -- local result = { start, el.text, finish, attr }
    -- return concat(result)

    local result = { '·', el.text, '·' }
    -- local result = { el.text }
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

Writer.Inline.SmallCaps = function(el)
    return Writer.Inlines(el.content)
end

Writer.Inline.Underline = function(el)
    return concat{ "…", Writer.Inlines(el.content), "…" }
end

Writer.Inline.Cite = function(el)
    return Writer.Inlines(el.content)
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

Writer.Inline.Span = function(el)
    return concat{Writer.Inlines(el.content)}
end

Writer.Inline.Link = function(el)
    -- if el.title and #el.title > 0 then
    --     el.attributes.title = el.title
    --     el.title = nil
    -- end
    -- local attr = render_attributes(el)
    -- local result = {"[", Writer.Inlines(el.content), "](", el.target, ")", attr}
    local lsrc = Writer.Inlines(el.content)
    local rendered = pandoc.write(pandoc.Pandoc({el.content}), "plain")
    if #rendered > 0 then
        rendered = rendered:sub(1, #rendered - 1)
    end
    local idx = string.find(rendered, ' ')
    if idx == nil then
        links[rendered] = el.target
        -- local result = {"¦", lsrc, "¦"}
        local result = {"¦", rendered, "¦"}
        return concat(result)
    end
    return lsrc
end

Writer.Inline.Image = function(el)
    -- if el.title and #el.title > 0 then
    --     el.attributes.title = el.title
    --     el.title = nil
    -- end
    -- local attr = render_attributes(el)
    -- local result = {"![", Writer.Inlines(el.caption), "](", el.src, ")", attr}
    local result = {"![", Writer.Inlines(el.caption), "](", el.src, ")"}
    return concat(result)
end

Writer.Inline.Quoted = function(el)
    if el.quotetype == "DoubleQuote" then
        return concat{'"', Writer.Inlines(el.content), '"'}
    else
        return concat{"'", Writer.Inlines(el.content), "'"}
    end
end

Writer.Inline.Note = function(el)
    footnotes[#footnotes + 1] = el.content
    local num = #footnotes
    return literal(format("[^%d]", num))
end

-- function Writer (doc, opts)
--   PANDOC_WRITER_OPTIONS = opts
--   local d = blocks(doc.blocks, blankline)
--   local notes = {}
--   for i=1,#footnotes do
--     local note = hang(blocks(footnotes[i], blankline), 4, concat{format("[^%d]:",i),space})
--     table.insert(notes, note)
--   end
--   local formatted = concat{d, blankline, concat(notes, blankline)}
--   if PANDOC_WRITER_OPTIONS.wrap_text == "wrap-none" then
--     return layout.render(formatted)
--   else
--     return layout.render(formatted, opts.columns)
--   end
-- end

-- Writer.Inline.Link = function (link)
--     return "$" .. Writer.Inlines(link.content) .. ':' .. link.target .. "$"
-- end

-- Writer.Block.Header = function(h)
--     return "<h" .. h.level.. ">" .. Writer.Inlines(h.content) .. "</h>"
-- end
