local M = {}

local cache = require("tekstitv.cache")
local config = require("tekstitv.config")
local network = require("tekstitv.network")
local parse = require("tekstitv.parse")
local uri = require("tekstitv.uri")

local ns = vim.api.nvim_create_namespace("tekstitv")
local augroup = vim.api.nvim_create_augroup("tekstitv_buffer", { clear = true })

---@class tekstitv.BufState
---@field links tekstitv.Link[]
---@field nav tekstitv.Nav

---@type table<integer, tekstitv.BufState>
local state = {}

local function set_highlights()
    vim.api.nvim_set_hl(0, "TekstitvLink", { link = "Identifier", default = true })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { group = augroup, callback = set_highlights })

---@param bufnr integer
local function set_keymaps(bufnr)
    local keymaps = config.get().keymaps
    for name, plug in pairs(config.plugs) do
        local lhs = keymaps[name]
        -- Skip the default when the user has mapped the <Plug> themselves.
        if lhs and vim.fn.hasmapto(plug, "n") == 0 then
            vim.keymap.set("n", lhs, plug, { buffer = bufnr })
        end
    end
end

---@param bufnr integer
---@param page integer
---@param subpage integer
function M.setup(bufnr, page, subpage)
    state[bufnr] = { links = {}, nav = {} }
    vim.b[bufnr].tekstitv_page = page
    vim.b[bufnr].tekstitv_subpage = subpage

    local bo = vim.bo[bufnr]
    bo.buftype = "nofile"
    bo.swapfile = false
    bo.bufhidden = "hide"
    bo.modifiable = false
    bo.filetype = "tekstitv"
    set_keymaps(bufnr)
    require("tekstitv.lsp").attach(bufnr)

    -- :e! runs BufReadCmd (and so this function) again.
    vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = augroup,
        buffer = bufnr,
        callback = function()
            -- [0] is :setlocal, so the winbar goes away when the window shows another buffer.
            -- An expression, since the subpage count is only known once the page has loaded.
            vim.wo[0][0].winbar = " %{v:lua.require'tekstitv'.statusline()}"
        end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = augroup,
        buffer = bufnr,
        once = true,
        callback = function()
            state[bufnr] = nil
        end,
    })
end

---@param bufnr integer
---@return tekstitv.Link[]
function M.links(bufnr)
    return state[bufnr] and state[bufnr].links or {}
end

---@param bufnr integer
---@param lines string[]
---@param links tekstitv.Link[]
local function draw(bufnr, lines, links)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    for _, link in ipairs(links) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, link.row, link.col_start, {
            end_col = link.col_end,
            hl_group = "TekstitvLink",
        })
    end
    vim.bo[bufnr].modifiable = false
end

---@param bufnr integer
---@param page integer
---@param subpage integer
function M.load(bufnr, page, subpage)
    ---@param ok boolean
    ---@param html_or_err string
    local function render(ok, html_or_err)
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        local parsed, err
        if ok then
            parsed, err = parse.parse(html_or_err)
        else
            err = html_or_err
        end
        if parsed then
            draw(bufnr, parsed.lines, parsed.links)
            state[bufnr] = { links = parsed.links, nav = parsed.nav }
            vim.b[bufnr].tekstitv_subpages = parsed.subpages
        else
            draw(bufnr, vim.split(err or "unknown error", "\n"), {})
        end
    end

    local cached = cache.get(page, subpage)
    if cached then
        render(true, cached)
        return
    end
    network.fetch(page, subpage, function(ok, html_or_err)
        vim.schedule(function()
            -- Only network responses are cached; re-writing on a hit would reset the TTL.
            if ok then
                cache.set(page, subpage, html_or_err)
            end
            render(ok, html_or_err)
        end)
    end)
end

--- This is just `:edit tekstitv://100/1`. The BufReadCmd in init.lua does the rest
---@param page integer
---@param subpage integer
function M.open(page, subpage)
    vim.cmd.edit(vim.fn.fnameescape(uri.build(page, subpage)))
end

---@param slot "prev_page"|"prev_subpage"|"next_subpage"|"next_page"
local function follow_nav(slot)
    local s = state[vim.api.nvim_get_current_buf()]
    local target = s and s.nav[slot]
    if target then
        M.open(target.page, target.subpage)
    end
end

--- Move the cursor to the next or previous link, wrapping around.
---@param dir 1|-1
local function jump_link(dir)
    local links = M.links(vim.api.nvim_get_current_buf())
    if #links == 0 then
        return
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local first, last = 1, #links
    if dir < 0 then
        first, last = last, first
    end
    local pick = links[first]
    for i = first, last, dir do
        local l = links[i]
        local ahead = l.row ~= row - 1 and l.row - (row - 1) or l.col_start - col
        if ahead * dir > 0 then
            pick = l
            break
        end
    end
    vim.api.nvim_win_set_cursor(0, { pick.row + 1, pick.col_start })
end

function M.next_page()
    follow_nav("next_page")
end

function M.prev_page()
    follow_nav("prev_page")
end

function M.next_subpage()
    follow_nav("next_subpage")
end

function M.prev_subpage()
    follow_nav("prev_subpage")
end

function M.next_link()
    jump_link(1)
end

function M.prev_link()
    jump_link(-1)
end

return M
