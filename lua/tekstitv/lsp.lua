local M = {}

local uri = require("tekstitv.uri")

---@param params table textDocument/definition params
---@return table|nil location
local function definition(params)
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    local pos = params.position
    for _, link in ipairs(require("tekstitv.buffer").links(bufnr)) do
        if link.row == pos.line and pos.character >= link.col_start and pos.character < link.col_end then
            local top = { line = 0, character = 0 }
            return {
                uri = uri.build(link.target.page, link.target.subpage),
                range = { start = top, ["end"] = top },
            }
        end
    end
end

---@param dispatchers table
---@return table client see `:h vim.lsp.ClientConfig` (cmd as a function)
local function server(dispatchers)
    local closing, id = false, 0
    return {
        request = function(method, params, callback)
            id = id + 1
            local result
            if method == "initialize" then
                -- utf-8 so positions are byte columns, like the parser's link ranges.
                result = { capabilities = { positionEncoding = "utf-8", definitionProvider = true } }
            elseif method == "textDocument/definition" then
                result = definition(params)
            end
            vim.schedule(function()
                callback(nil, result)
            end)
            return true, id
        end,
        notify = function(method)
            if method == "exit" then
                closing = true
                dispatchers.on_exit(0, 15)
            end
            return true
        end,
        is_closing = function()
            return closing
        end,
        terminate = function()
            closing = true
        end,
    }
end

---@param bufnr integer
function M.attach(bufnr)
    vim.lsp.start({ name = "tekstitv", cmd = server }, {
        bufnr = bufnr,
        -- One client for every page. Without this, Neovim 0.10 starts another client on each :edit.
        reuse_client = function(client, config)
            return client.name == config.name
        end,
    })
end

return M
