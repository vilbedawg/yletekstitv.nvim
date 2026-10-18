local assert = require("luassert")
local config = require("tekstitv.config")

describe("config", function()
    local notify, messages

    before_each(function()
        config.setup() -- back to the defaults
        messages = {}
        notify = vim.notify
        ---@diagnostic disable-next-line: duplicate-set-field, unused-vararg -- keep vim.notify's signature
        vim.notify = function(msg, ...)
            messages[#messages + 1] = msg
        end
    end)

    after_each(function()
        vim.notify = notify
    end)

    it("works with the defaults without calling setup()", function()
        assert.are.same(config.defaults, config.get())
    end)

    it("merges the user's options over the defaults", function()
        config.setup({ keymaps = { next_page = "<C-n>", prev_page = false } })
        assert.are.equal("<C-n>", config.get().keymaps.next_page)
        assert.is_false(config.get().keymaps.prev_page)
        assert.are.equal("]l", config.get().keymaps.next_link)
        assert.are.same({}, messages)
    end)

    it("rejects a keymap of the wrong type and keeps the previous config", function()
        config.setup({ keymaps = { next_page = "<C-n>" } })
        config.setup({ keymaps = { next_page = 1 } })
        assert.are.equal("<C-n>", config.get().keymaps.next_page)
        assert.are.equal(1, #messages)
        assert.truthy(messages[1]:find("keymaps.next_page must be a string or false, got number", 1, true))
    end)

    it("rejects options that are not a table", function()
        ---@diagnostic disable-next-line: param-type-mismatch -- wrong type on purpose
        config.setup("]p")
        assert.are.same(config.defaults, config.get())
        assert.truthy(messages[1]:find("expects a table", 1, true))
    end)

    it("reports unknown keymap names without rejecting the config", function()
        local cfg = vim.tbl_deep_extend("force", config.defaults, { keymaps = { open_browser = "gx", jump = "J" } })
        local errors, unknown = config.validate(cfg)
        assert.are.same({}, errors)
        assert.are.same({ "jump", "open_browser" }, unknown)
    end)
end)
