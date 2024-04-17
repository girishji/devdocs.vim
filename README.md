
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

![Demo](https://gist.githubusercontent.com/girishji/40e35cd669626212a9691140de4bd6e7/raw/6041405e45072a7fbc4e352cbd461e450a7af90e/devdocs-demo.gif)

# Usage

## Install New Documentation

The `:DevdocsInstall` command opens a popup window for downloading new documentation trees. Please allow a few seconds for the gathering of all slugs (document tree metadata) from [devdocs.io](https://devdocs.io).

Navigate through the choices using `<Tab>` and `<S-Tab>`, or simply type in the window for fuzzy searching. Depending on the documentation size, the downloading process may take up to a minute.

Installation directory can be changed, as explained below.

## Uninstall Documentation

To remove documentation trees, use the `:DevdocsUninstall` command.

## Fuzzy Search Documentation Trees

Use the `:DevdocsFind` command, or map it to your preferred shortcut, for a
fuzzy search of API keywords. Use `<Tab>` and `<S-Tab>` for navigation.

The documentation file opens in a new split window, similar to Vim's help
files. You can configure the height of this window. Type `q` to quit the window.

## Navigate Links

Links are underlined. Place the cursor on a link and type `<C-]>` (Control-]) or `K` to follow the
link. `<C-t>` to go back. These mappings mirror Vim tags. Link targets are
echoed on the command line when the cursor is on the link.

## Interact

Search and copy using familiar Vim commands. There are no markup artifacts that require cleanup.

## TUI

Use the provided shell script `devdocs` to view documents in full window. Vim
is used as a sort of pager.

The `devdocs2` script is similar except it does not source `~/.vimrc`. Instead,
customization is done through `~/.devdocs.vim` file. You can treat this as a
standalone app and configure it independent of normal Vim configuration.

To use custom installation of Vim, set the `$VIMCMD` environment variable to
the path of Vim executable.

# Requirements

- Vim version 9.1 or higher
- [pandoc](https://pandoc.org/) version 3.1 or higher

# Installation

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
repository anywhere. The script does not use Vim's plugin system.

</details>

# Configuration

Map keys as shown for quick navigation.

```vim
if exists('g:loaded_devdocs')
    nnoremap <your_key> :DevdocsFind<CR>
    nnoremap <your_key> :DevdocsInstall<CR>
    nnoremap <your_key> :DevdocsUninstall<CR>
endif
```

## Options

There are a couple of options you can set. Here are the defaults:

```vim
let g:DevdocsOptions = {
    data_dir: '~/.local/share/devdocs',  # installation directory for document trees
    pandoc: 'pandoc',                    # pandoc executable path
    height: 20,                          # height of split window in number of lines
    open_mode: 'split',                  # 'split' (horizontal), 'vert' (vertical), and 'tab' for tab edit
    slugs: [],                           # list of slugs to search (when empty search 'all', see below)
    format: {
        extended_ascii: true,      # create tables using box characters instead of plain ascii
        divide_section: true,      # sections are marked by a horizontal line if `true`
        use_terminal_width: true,  # make the document as wide as the terminal, otherwise 80 chars wide
        indent_section: false,     # sections are progressively indented if `true`, otherwise fixed indentation
        fence_codeblock: false     # turn off Vim's syntax highlighting of code block (use `DevdocCodeblock` group instead)
    }
}
```

Options are set using `g:DevdocsOptionsSet()`.

For example, use the following configuration to generate documents with a fixed
80-character width (instead of full terminal width) and to set split window height to
30 lines.

```vim
vim9script
call g:DevdocsOptionsSet({format: {use_terminal_width: false}, height: 30})
```

If you installed documentation for multiple languages, you can set the `slugs`
list to limit the fuzzy search to specific documentation trees. Furthermore,
you can use the `filetype` event to set a list of slugs based on the filetype
you are working on.

```vim
vim9script
autocmd FileType python call g:DevdocsOptionsSet({slugs: ['python~3.12', 'python~3.11']})
```

## Syntax Highlighting

The following syntax groups control the look and feel of the document. They are
linked by default to Vim groups as follows:

Group|Default
------|----
`DevdocCodeblock`|`Special`
`DevdocBlockquote`|`None`
`DevdocLink`|`Underlined`
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

## Popup Window

The appearance of the popup window can be configured using `borderchars`,
`borderhighlight`, `highlight`, `scrollbarhighlight`, `thumbhighlight`, and
other `:h popup_create-arguments`. To configure these settings, use
`popup.OptionsSet()`.

For instance, to set the border of the popup window to the `Comment` highlight
group:

```vim
import autoload 'devdocs/popup.vim' dp
dp.OptionsSet({borderhighlight: ['Comment']})
```

or,

```
devdocs#popup#OptionsSet(#{borderhighlight: ['Comment']})
```

The `DevdocMenuMatch` highlight group modifies the appearance of characters
searched so far. By default, it is linked to the `Special` group.

# Other Plugins to Enhance Your Workflow

1. [**vimcomplete**](https://github.com/girishji/vimcomplete) - enhances autocompletion in Vim.

2. [**easyjump.vim**](https://github.com/girishji/easyjump.vim) - makes code navigation a breeze.

3. [**fFtT.vim**](https://github.com/girishji/fFtT.vim) - accurately target words in a line.

4. [**scope.vim**](https://github.com/girishji/scope.vim) - fuzzy find anything.

5. [**autosuggest.vim**](https://github.com/girishji/autosuggest.vim) - live autocompletion for Vim's command mode.
