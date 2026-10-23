-- Buffer, keymap and LSP specs. Pages are served from the cache, so no network is used.
-- The specs share one editor session and run in file order.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd.runtime("plugin/tekstitv.lua")

local assert = require("luassert")
local buffer = require("tekstitv.buffer")
local cache = require("tekstitv.cache")

-- Every page is the real 100/1 fixture (first links 199, 137; nav: 100/2, 101/1).
local fixture = table.concat(vim.fn.readfile("spec/fixtures/100_0001.htm"), "\n")
for _, p in ipairs({ { 100, 1 }, { 100, 2 }, { 101, 1 }, { 102, 1 }, { 199, 1 }, { 137, 1 } }) do
    cache.set(p[1], p[2], fixture)
end

local function name()
    return vim.api.nvim_buf_get_name(0)
end

local function open_front()
    vim.cmd.edit("tekstitv://100/1")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function links()
    return buffer.links(vim.api.nvim_get_current_buf())
end

local function rhs(lhs)
    return vim.fn.maparg(lhs, "n", false, true).rhs
end

--- The client initializes on a later loop tick after attaching, and sets 'tagfunc' only then.
local function wait_for_lsp()
    vim.wait(1000, function()
        return #vim.lsp.get_clients({ bufnr = 0, name = "tekstitv" }) > 0 and vim.bo.tagfunc ~= ""
    end)
end

--- Open an uncached page with curl stubbed to fail with `code` / `stderr`.
---@return string? message passed to vim.notify
---@return integer? level
local function open_failing(page, code, stderr)
    local system, notify = vim.system, vim.notify
    local msg, level
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.system = function(_, _, on_exit)
        on_exit({ code = code, signal = 0, stdout = "", stderr = stderr })
    end
    vim.notify = function(m, l)
        msg, level = m, l
    end
    vim.cmd.edit("tekstitv://" .. page .. "/1")
    vim.wait(1000, function()
        return msg ~= nil
    end)
    vim.system, vim.notify = system, notify
    return msg, level
end

describe("buffer", function()
    it("opening a page renders it and sets buffer state", function()
        open_front()
        assert(vim.api.nvim_buf_line_count(0) > 10)
        assert.are.equal("tekstitv", vim.bo.filetype)
        assert.is_false(vim.bo.modifiable)
        assert.are.equal(100, vim.b.tekstitv_page)
        assert.are.equal(4, vim.b.tekstitv_subpages)
        assert.are.equal(" Teksti-TV 100 (1/4)", vim.api.nvim_eval_statusline(vim.wo.winbar, { use_winbar = true }).str)
    end)

    it(":edit uses the cache and :edit! fetches again", function()
        local system = vim.system
        local fetches = 0
        ---@diagnostic disable-next-line: duplicate-set-field
        vim.system = function(_, _, on_exit)
            fetches = fetches + 1
            on_exit({ code = 0, signal = 0, stdout = fixture, stderr = "" })
        end
        open_front()
        vim.cmd.edit()
        assert.are.equal(0, fetches)
        vim.cmd("edit!")
        vim.wait(1000, function()
            return fetches > 0
        end)
        vim.system = system
        assert.are.equal(1, fetches)
    end)

    it("the winbar is local to the page buffer", function()
        open_front()
        vim.cmd.enew()
        assert.are.equal("", vim.wo.winbar)
        vim.cmd("bwipeout")
    end)

    it("links are highlighted with a coloured group", function()
        open_front()
        assert.are.equal("Identifier", vim.api.nvim_get_hl(0, { name = "TekstitvLink" }).link)
        local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
        local link_marks = vim.tbl_filter(function(m)
            return m[4].hl_group == "TekstitvLink"
        end, marks)
        assert.are.equal(#links(), #link_marks)
    end)

    it("load errors are notified as plain messages", function()
        assert.are.equal(
            "Page 104.1 does not exist.",
            open_failing(104, 22, "curl: (22) The requested URL returned error: 404")
        )
        assert.are.equal(
            "Page 107.1 does not exist.", -- HTTP/2
            open_failing(107, 56, "curl: (56) The requested URL returned error: 404")
        )
        assert.are.equal("Could not reach yle.fi.", open_failing(105, 6, "curl: (6) Could not resolve host: yle.fi"))
        assert.are.equal(vim.log.levels.WARN, select(2, open_failing(108, 6, "curl: (6) Could not resolve host")))
        assert.are.equal(1, vim.api.nvim_buf_line_count(0))
        assert.are.equal(
            "Could not load page 106.1.",
            open_failing(106, 22, "curl: (22) The requested URL returned error: 503")
        )
    end)
end)

describe("navigation", function()
    it("next/prev link walk the links and wrap", function()
        open_front()
        local l = links()
        buffer.next_link()
        assert.are.same({ l[1].row + 1, l[1].col_start }, vim.api.nvim_win_get_cursor(0))
        buffer.next_link()
        assert.are.same({ l[2].row + 1, l[2].col_start }, vim.api.nvim_win_get_cursor(0))
        buffer.prev_link()
        buffer.prev_link()
        assert.are.same({ l[#l].row + 1, l[#l].col_start }, vim.api.nvim_win_get_cursor(0))
    end)

    it("next page follows the nav bar; no prev link means no move", function()
        open_front()
        buffer.next_page()
        assert.are.equal("tekstitv://101/1", name())
        open_front()
        buffer.prev_page()
        assert.are.equal("tekstitv://100/1", name())
    end)

    it("next subpage follows the nav bar; no prev subpage link means no move", function()
        open_front()
        buffer.next_subpage()
        assert.are.equal("tekstitv://100/2", name())
        open_front()
        buffer.prev_subpage()
        assert.are.equal("tekstitv://100/1", name())
    end)
end)

describe("LSP", function()
    it("definition on a link points at its page", function()
        open_front()
        buffer.next_link()
        buffer.next_link() -- 137
        wait_for_lsp()
        local params = vim.lsp.util.make_position_params(0, "utf-8")
        local res = vim.lsp.buf_request_sync(0, "textDocument/definition", params, 1000)
        assert(res)
        local _, reply = next(res)
        assert(reply)
        assert.are.equal("tekstitv://137/1", reply.result.uri)
    end)

    it("<C-]> (tagfunc set on attach) opens the link under the cursor", function()
        open_front()
        buffer.next_link() -- 199
        wait_for_lsp()
        vim.cmd('execute "normal! \\<C-]>"')
        assert.are.equal("tekstitv://199/1", name())
    end)

    it("vim.lsp.buf.definition() opens the link under the cursor", function()
        open_front()
        buffer.next_link() -- 199
        buffer.next_link() -- 137
        wait_for_lsp()
        vim.lsp.buf.definition()
        vim.wait(1000, function()
            return name() ~= "tekstitv://100/1"
        end)
        assert.are.equal("tekstitv://137/1", name())
        assert(vim.api.nvim_buf_line_count(0) > 10, "target page was not loaded")
    end)
end)

describe("keymaps", function()
    it("defaults point at <Plug> mappings", function()
        open_front()
        assert.are.equal("<Plug>(TekstitvNextPage)", rhs("]p"))
        assert.are.equal("<Plug>(TekstitvPrevLink)", rhs("[l"))
        assert.are.equal("<Plug>(TekstitvNextSubpage)", rhs("]s"))
    end)

    -- Last: the user's global mapping stays for the rest of the session.
    it("defaults are skipped when the user maps the <Plug> themselves", function()
        vim.keymap.set("n", "<leader>n", "<Plug>(TekstitvNextPage)")
        vim.cmd.edit("tekstitv://102/1") -- not opened before, so BufReadCmd runs
        assert.is_nil(rhs("]p"))
        assert.are.equal("<Plug>(TekstitvPrevPage)", rhs("[p"))
    end)
end)
