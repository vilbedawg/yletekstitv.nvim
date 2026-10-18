# yletekstitv.nvim

Read [Yle Teksti-TV](https://yle.fi/tekstitv) in Neovim.

Requires Neovim 0.10+ and `curl`.

```lua
-- vim.pack (Neovim 0.12+)
vim.pack.add({ "https://github.com/vilbedawg/yletekstitv.nvim" })

-- lazy.nvim
{ "vilbedawg/yletekstitv.nvim" }
```

`:Tekstitv 100` opens a page. Follow links with `gd` / `<C-]>`, move between pages with `]p` / `[p`. See `:h tekstitv`.

## Development

Tests use [busted](https://github.com/lunarmodules/busted) with [nlua](https://github.com/mfussenegger/nlua):

```sh
luarocks --local --lua-version 5.1 install busted
luarocks --local --lua-version 5.1 install nlua
eval "$(luarocks --lua-version 5.1 path)"  # add to your shell profile
busted
```
