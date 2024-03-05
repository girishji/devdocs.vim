
<h1 align="center"> Devdocs </h1>

<h4 align="center"> Browse API documentation from <a href="https://devdocs.io">devdocs.io</a> inside Vim.</h4>
<h4 align="center"> (Navigate links, fuzzy find API keywords, search & copy, TUI, and more!)</h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a> •
</p>

![Demo](data/demo.gif)


## Usage

### Navigate Links

Links are underlined. Place the cursor on a link and type `<C-]>` to follow the link. `<C-t>` to go back.

### Install New Documentation

`:DevdocsInstall` command opens a popup window. It may take a few seconds to
gather all the slugs (document tree metadata) from [devdocs](https://devdocs.io)) website. Fuzzy search,
use `<Tab>` and `<S-Tab>` to navigate.

Depending on the size of documentation, this may take up to a minute to
download. Be patient.

You can change the installation directory. See configuration below.

### Uninstall Documentation

Use `:DevdocsUninstall` command.

### Search Documentation Tree

Use `:DevdocsFind` command (or map it to your favorite shortcut) to fuzzy find API keywords.
Use `<Tab>` and `<S-Tab>` to navigate.

Documentation file opens in a new split window (just like Vim's help
files). Height of this window can be configured. Window can be split vertically
and syntax highlighting can be changed.

### TUI

If you are already a Vim user, you can use the provided shell script `devdocs` to view documents.

If you are _not_ a regular Vim user you can still use Vim as a pager. Clone this repository anywhere and use the provided script `devdocs-local`. It will not load the `.vimrc` file, but you can customize using `~/.devdocs.vim` file.

To use custom installation of Vim set `$VIMCMD` environment variable to the path of Vim executable.

## Requirements

- Vim version 9.1 or higher
- [pandoc](https://pandoc.org/)

## Installation

Install [pandoc](https://pandoc.org/installing.html).

Install this plugin via [vim-plug](https://github.com/junegunn/vim-plug).

<details><summary><b>Show instructions</b></summary>
<br>
  
Using vim9 script:

```vim
vim9script
plug#begin()
Plug 'girishji/devdocs.vim'
plug#end()
```

Using legacy script:

```vim
call plug#begin()
Plug 'girishji/devdocs.vim'
call plug#end()
```

</details>

Install using Vim's built-in package manager.

<details><summary><b>Show instructions</b></summary>
<br>
  
```bash
$ mkdir -p $HOME/.vim/pack/downloads/opt
$ cd $HOME/.vim/pack/downloads/opt
$ git clone https://github.com/girishji/devdocs.vim.git
```

Add the following line to your $HOME/.vimrc file.

```vim
packadd devdocs.vim
```

</details>

## Configuration

Map keys, set options and change highlight groups.

### Keymap

Map keys for quick navigation.

```
vim9script
if exists('g:loaded_devdocs')
    import 'devdocs.vim'
    nnoremap <leader>I <scriptcmd>devdocs.Install()<CR>
    nnoremap <leader>U <scriptcmd>devdocs.Uninstall()<CR>
    nnoremap <leader>h <scriptcmd>devdocs.Find()<CR>
endif
```

Legacy script users can use the commands `DevdocsInstall`, `DevdocsUninstall`,
and `DevdocsFind` directly in the keymaps.

### Options

There are a couple of options you can set. Here are the defaults:

```
var opt = {
    data_dir: '~/.local/share/devdocs',  # installation directory for document trees
    pandoc: 'pandoc',                    # pandoc executable path
    height: 20,                          # height of split window in number of lines
    open_mode: 'split',                  # 'split' (horizontal), 'vert' (vertical), and 'tab' for tab edit
    slugs: [],                           # list of slugs to search (when empty search 'all')
    format: {}                           # see below
}
```

Options are set using `devdocs.OptionsSet(dict)`, or for legacy script users `g:DevdocsOptionsSet(dict)`.

For example, use only plain ascii characters in tables (if your font is bitmapped) and set window height to 30 lines.

```
vim9script
import 'devdocs.vim'
devdocs.OptionsSet({format: {extended_ascii: false}, height: 30})
```

If you installed documentation for multiple languages you can set `slugs` list to limit search to specific
documentation only. You can use the `filetype` event of `autocmd` to set a
list of slugs based on the filetype you are working on.

```
vim9script
import 'devdocs.vim'
autocmd filetype python devdocs.OptionsSet({slugs: ['python~3.12', 'python~3.11']})
```


`format` is a dictionary passed directly to _pandoc_ to control the output. Pandoc builds a AST out of html files which is then transformed into a Vim suitable format using Lua custom writer. The default values for `format` are as follows:

```
format: {
    extended_ascii: true,      # create tables using box characters instead plain ascii (`-`, `|`, `=`)
    divide_section: true,      # sections are marked by a horizontal line if `true`
    use_terminal_width: true,  # make the document as wide as the terminal, otherwise 80 chars wide if `false`
    indent_section: false,     # sections are progressively indented if `true`, otherwise fixed indentation
    fence_codeblock: false     # turn off Vim's syntax highlighting of code block (use `DevdocCodeblock` group instead)
}
```

### Syntax Highlighting

Following syntax groups control the look and feel of document. They are linked by default to Vim groups as follows:

Group|Default
------|----
`DevdocCodeblock`|`Special`
`DevdocBlockquote`|`None`
`DevdocLink`|`SpellRare`
`DevdocCode`|`String`
`DevdocUnderline`|`Underlined`
`DevdocSection`|`Comment`
`DevdocDefn`|`PreProc`
`DevdocH1`|`PreProc`
`DevdocH2`|`PreProc`
`DevdocH3`|`PreProc`
`DevdocH4`|`PreProc`
`DevdocH5`|`PreProc`
`DevdocH6`|`PreProc`

### Popup Window

Popup window appearance is controlled by following groups:

Group|Default
------|----
`PopupBorderHighlight`|`None`
`PopupHighlight`|`Normal`
`PopupScrollbarHighlight`|`PmenuSbar`
`PopupThumbHighlight`|`PmenuThumb`
`DevdocMenuMatch`|`Bold`

`DevdocMenuMatch` highlights the characters during search.

`borderchars` of the popup window and other `:h popup_create-arguments` can be
configured using `devdocs.PopupOptionsSet(dict)`.

**Open an issue if you encounter errors.**
