if vim.g.loaded_tekstitv then
    return
end
vim.g.loaded_tekstitv = true

for name, plug in pairs(require("tekstitv.config").plugs) do
    vim.keymap.set("n", plug, function()
        require("tekstitv.buffer")[name]()
    end)
end

require("tekstitv").register_command()
