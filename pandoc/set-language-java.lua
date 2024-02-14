-- pandoc -t ~/git/devdocs.vim/pandoc/writer.lua --lua-filter ~/git/devdocs.vim/pandoc/set-language.lua  string.html
-- not much use for this
function  CodeBlock(el)
    el.attr.classes[1] = 'java'
    return pandoc.CodeBlock(el.text, el.attr)
end


