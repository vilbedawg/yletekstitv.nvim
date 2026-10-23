local M = {}

local uri = require("tekstitv.uri")

---@param args string
---@return integer page
---@return integer subpage
local function parse_args(args)
    local page, subpage = args:match("^(%d+)[%s%.]+(%d+)$")
    if page then
        ---@diagnostic disable-next-line: return-type-mismatch
        return tonumber(page), tonumber(subpage)
    end

    page = args:match("^(%d+)$")
    if page then
        ---@diagnostic disable-next-line: return-type-mismatch
        return tonumber(page), 1
    end

    -- defaults to page 100 and subpage 1
    return 100, 1
end

---@param opts table|nil see lua/tekstitv/config.lua for available fields
function M.setup(opts)
    require("tekstitv.config").setup(opts)
end

---@return string
function M.statusline()
    local page = vim.b.tekstitv_page
    if not page then
        return ""
    end
    local count = vim.b.tekstitv_subpages
    if count and count > 1 then
        return string.format("Teksti-TV %d (%d/%d)", page, vim.b.tekstitv_subpage, count)
    end
    return string.format("Teksti-TV %d", page)
end

-- buffer.lua is required inside the callbacks so startup only loads this file and uri.lua.
function M.register_command()
    local group = vim.api.nvim_create_augroup("tekstitv", { clear = true })

    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = group,
        pattern = "tekstitv://*",
        callback = function(args)
            local page, subpage = uri.parse(vim.api.nvim_buf_get_name(args.buf))
            if not page then
                return
            end
            local buffer = require("tekstitv.buffer")
            buffer.setup(args.buf, page, subpage or 1)
            buffer.load(args.buf, page, subpage or 1)
        end,
    })

    vim.api.nvim_create_user_command("Tekstitv", function(cmd_opts)
        require("tekstitv.buffer").open(parse_args(cmd_opts.args))
    end, {
        nargs = "*",
        desc = "Open a Yle Teksti-TV page: :Tekstitv [page] [subpage]",
    })
end

return M
