-- :checkhealth tekstitv
local M = {}

function M.check()
    vim.health.start("tekstitv")

    -- vim.system, vim.lsp.start with a function `cmd`, and vim.wo[win][buf].
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim " .. tostring(vim.version()))
    else
        vim.health.error("Neovim 0.10 or newer is required")
    end

    local errors, unknown = require("tekstitv.config").validate(require("tekstitv.config").get())
    for _, err in ipairs(errors) do
        vim.health.error(err)
    end
    if #errors == 0 then
        vim.health.ok("config is valid")
    end
    if #unknown > 0 then
        vim.health.warn("Unknown keymaps (ignored): " .. table.concat(unknown, ", "))
    end

    if vim.fn.executable("curl") == 0 then
        vim.health.error("curl not found in PATH", "Install curl; pages are fetched with it")
        return
    end
    vim.health.ok("curl found")

    -- Fetch the front page directly, skipping the cache, to test the connection.
    local result
    require("tekstitv.network").fetch(100, 1, function(ok, err)
        result = { ok = ok, err = err }
    end)
    vim.wait(5000, function()
        return result ~= nil
    end)
    if not result then
        vim.health.warn("yle.fi did not answer within 5 seconds")
    elseif result.ok then
        vim.health.ok("yle.fi reachable")
    else
        vim.health.error(result.err)
    end
end

return M
