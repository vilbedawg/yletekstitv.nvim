local M = {}

M.defaults = {
    keymaps = {
        next_page = "]p",
        prev_page = "[p",
        next_subpage = "]s",
        prev_subpage = "[s",
        next_link = "]l",
        prev_link = "[l",
    },
}

-- <Plug> mapping for each keymap above; the keys are functions in buffer.lua.
M.plugs = {
    next_page = "<Plug>(TekstitvNextPage)",
    prev_page = "<Plug>(TekstitvPrevPage)",
    next_subpage = "<Plug>(TekstitvNextSubpage)",
    prev_subpage = "<Plug>(TekstitvPrevSubpage)",
    next_link = "<Plug>(TekstitvNextLink)",
    prev_link = "<Plug>(TekstitvPrevLink)",
}

local resolved = vim.deepcopy(M.defaults)

--- Check a merged config. Unknown keymap names are only reported, since they are ignored anyway.
---@param cfg table
---@return string[] errors
---@return string[] unknown keymap names
function M.validate(cfg)
    if type(cfg.keymaps) ~= "table" then
        return { "keymaps must be a table, got " .. type(cfg.keymaps) }, {}
    end
    local errors, unknown = {}, {}
    for name, lhs in pairs(cfg.keymaps) do
        if not M.plugs[name] then
            unknown[#unknown + 1] = name
        elseif lhs ~= false and type(lhs) ~= "string" then
            errors[#errors + 1] = string.format("keymaps.%s must be a string or false, got %s", name, type(lhs))
        end
    end
    table.sort(unknown)
    return errors, unknown
end

--- Optional: the plugin works with the defaults without calling this.
--- An invalid config is reported and the previous one is kept.
---@param opts table|nil
function M.setup(opts)
    if opts ~= nil and type(opts) ~= "table" then
        vim.notify("tekstitv: setup() expects a table, got " .. type(opts), vim.log.levels.ERROR)
        return
    end
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
    local errors = M.validate(merged)
    if #errors > 0 then
        vim.notify(
            "tekstitv: invalid config, keeping the previous one\n" .. table.concat(errors, "\n"),
            vim.log.levels.ERROR
        )
        return
    end
    resolved = merged
end

---@return table
function M.get()
    return resolved
end

return M
