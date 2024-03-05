
<h1 align="center"> Devdocs </h1>

<h4 align="center"> Browse API documentation from <a href="https://devdocs.io">devdocs.io</a> inside Vim.</h4>

<h4 align="center">
  <a href="#navigate-links">Navigate Links</a> •
  <a href="#fuzzy-search-documentation-trees">Fuzzy Find API</a> •
  <a href="#interact">Search & Copy</a> •
  <a href="#tui">TUI</a>
</h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a>
</p>

![Demo](data/demo.gif)


## Usage

### Install New Documentation

The `:DevdocsInstall` command opens a popup window for downloading new documentation trees. Please allow a few seconds for the gathering of all slugs (document tree metadata) from [devdocs.io](https://devdocs.io).

Navigate through the choices using `<Tab>` and `<S-Tab>`, or simply type in the window for fuzzy searching. Depending on the documentation size, the downloading process may take up to a minute.

Installation directory can be changed, as explained below.

### Uninstall Documentation

To remove documentation trees, use the `:DevdocsUninstall` command.

### Fuzzy Search Documentation Trees

Use the `:DevdocsFind` command, or map it to your preferred shortcut, for a
fuzzy search of API keywords. Use `<Tab>` and `<S-Tab>` for navigation.

The documentation file opens in a new split window, similar to Vim's help
files. You can configure the height of this window.

### Navigate Links

Links are underlined. Place the cursor on a link and type `<C-]>` (Control-]) or `K` to follow the
link. `<C-t>` to go back. These mappings mirror Vim tags.

### Interact

Search and copy using familiar Vim commands. There are no markup artifacts that require cleanup.

### TUI

If you are already a Vim user, use the provided shell script `devdocs` to view documents in full window.

If you are _not_ a regular Vim user you can still use Vim as a pager. Clone
this repository anywhere and use the provided script `devdocs2`.
It avoids loading the `~/.vimrc` file, but customization is possible through the `~/.devdocs.vim` file.

To use custom installation of Vim, set the `$VIMCMD` environment variable to the path of Vim executable.

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

Note: If you are going to use `devdocs2` script only, you can clone this
repository anywhere. It does not use Vim's plugin system.

</details>

## Configuration

Map keys, set options, and change highlight groups.

### Keymaps

Map keys as shown (for instance) for quick navigation.

```
if exists('g:loaded_devdocs')
    nnoremap <leader>h <cmd>DevdocsFind<CR>
    nnoremap <leader>I <cmd>DevdocsInstall<CR>
    nnoremap <leader>U <cmd>DevdocsUninstall<CR>
endif
```

### Options

There are a couple of options you can set. Here are the defaults:

```
var opt = {
    data_dir: '~/.local/share/devdocs',  # installation directory for document trees
    pandoc: 'pandoc',                    # pandoc executable path
    height: 20,                          # height of split window in number of lines
    open_mode: 'split',                  # 'split' (horizontal), 'vert' (vertical), and 'tab' for tab edit
    slugs: [],                           # list of slugs to search (when empty search 'all', see below)
    format: {}                           # see below
}
```

`format` (above) is a dictionary passed directly to _pandoc_ to control the
output. Pandoc builds an AST out of html files which is then transformed using
Lua custom writer. The default values for `format` are as follows:

```
format: {
    extended_ascii: true,      # create tables using box characters instead plain ascii (`-`, `|`, `=`)
    divide_section: true,      # sections are marked by a horizontal line if `true`
    use_terminal_width: true,  # make the document as wide as the terminal, otherwise 80 chars wide if `false`
    indent_section: false,     # sections are progressively indented if `true`, otherwise fixed indentation
    fence_codeblock: false     # turn off Vim's syntax highlighting of code block (use `DevdocCodeblock` group instead)
}
```

Options are set using `g:DevdocsOptionsSet(dict)`.

For example, use the following configuration to generate documents with fixed
80 char width (instead of full terminal width) and to set window height to 30
lines.

```
vim9script
g:DevdocsOptionsSet({format: {use_terminal_width: false}, height: 30})
```

If you installed documentation for multiple languages you can set `slugs` list to limit search to specific
documentation trees only. Further, you can also use the `filetype` event of `autocmd` to set a
list of slugs based on the filetype you are working on.

```
vim9script
autocmd filetype python g:DevdocsOptionsSet({slugs: ['python~3.12', 'python~3.11']})
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
configured using `g:DevdocsPopupOptionsSet(dict)`.

**Open an issue if you encounter errors.**
