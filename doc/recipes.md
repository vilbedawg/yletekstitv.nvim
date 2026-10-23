# Recipes

The plugin does not provide tools to navigate the teletext, as neovim offers us multiple ways to navigate around. Pages are ordinary buffers named `tekstitv://{page}/{subpage}`, so most built-in navigation works as it is.

<!-- TOC -->
- [Bookmarks](#bookmarks)
- [Navigating between pages](#navigating-between-pages)
- [Multitasking](#multitasking)
<!-- /TOC -->

## Bookmarks

Global marks persist even after restarting Neovim (unless configured otherwise). Therefore, you can use them as bookmarks to jump quickly to your favourite pages:

```vim
mT        " bookmark this page as T
'T        " open it
:marks T  " show which page T points to
```

## Navigating between pages

Links are followed with "go to definition" (`<C-]>` or `gd`), because each page has a small built-in language server attached. Anything that calls `vim.lsp.buf.definition()` works, such as a picker's "go to definition" action.

Next/previous page, subpage and link have buffer-local defaults (`]p` `[p`, `]s` `[s`, `]l` `[l`), see `:h tekstitv-mappings`.

If you are an avid news reader, you might want to bind the pages you read often to a key:

```lua
vim.keymap.set("n", "<leader>t1", "<cmd>Tekstitv 100<cr>", { desc = "Teksti-TV front page" })
```

## Multitasking

Pages are normal buffers, so you can open them in splits and tabs, for example next to your coding agent while you wait for it to do your work:

```vim
:vsplit tekstitv://100/1
:tabedit tekstitv://100/1
```

