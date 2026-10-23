local assert = require("luassert")
local parse = require("tekstitv.parse").parse

--- Parse a bare <pre> body.
---@return tekstitv.Page
local function pre(body)
    local page, err = parse("<html><pre>" .. body .. "</pre></html>")
    assert(page, err)
    return page
end

local function read_fixture()
    return table.concat(vim.fn.readfile("spec/fixtures/100_0001.htm"), "\n")
end

describe("parse", function()
    describe("lines", function()
        it("newlines split lines, whitespace is kept", function()
            assert.are.same({ "  one", "", "two  " }, pre("  one\n\ntwo  ").lines)
        end)

        it("the newlines right after <pre> and before </pre> are dropped", function()
            assert.are.same({ "a", "b" }, pre("\na\nb\n").lines)
        end)

        it("entities are decoded", function()
            assert.are.same({ "a bÄö█" }, pre("a&nbsp;b&Auml;&ouml;&#9608;").lines)
        end)

        it("unknown entities and a bare & are kept as written", function()
            assert.are.same({ "a&euro;b & c" }, pre("a&euro;b & c").lines)
        end)
    end)

    describe("links", function()
        it("text kept, tag stripped, range recorded", function()
            local p = pre('<a href="199_0001.htm">199</a> P&Auml;&Auml;HAKEMISTO')
            assert.are.same({ "199 PÄÄHAKEMISTO" }, p.lines)
            assert.are.same({ { row = 0, col_start = 0, col_end = 3, target = { page = 199, subpage = 1 } } }, p.links)
        end)

        it("columns are byte offsets of the decoded text", function()
            local p = pre('&Auml;&ouml; <a href="101_0001.htm">101</a>')
            assert.are.same({ "Äö 101" }, p.lines)
            assert.are.equal(5, p.links[1].col_start)
            assert.are.equal(8, p.links[1].col_end)
        end)

        it("several links over several lines", function()
            local p = pre('x\n  <a href="201_0001.htm">201</a> A  <a href="300_0002.htm">300</a>')
            assert.are.same({ "x", "  201 A  300" }, p.lines)
            assert.are.same({ row = 1, col_start = 2, col_end = 5, target = { page = 201, subpage = 1 } }, p.links[1])
            assert.are.same({ row = 1, col_start = 9, col_end = 12, target = { page = 300, subpage = 2 } }, p.links[2])
        end)

        it("link text is decoded", function()
            local p = pre('<a href="101_0001.htm">&Auml;</a>')
            assert.are.same({ "Ä" }, p.lines)
            assert.are.equal(2, p.links[1].col_end)
        end)

        it("external links keep their text but are not navigable", function()
            local p = pre('<a href="https://yle.fi/tekstitv" target="_blank">yle.fi/tekstitv</a> x')
            assert.are.same({ "yle.fi/tekstitv x" }, p.lines)
            assert.are.same({}, p.links)
        end)
    end)

    describe("document", function()
        it("a missing <pre> is an error", function()
            for _, html in ipairs({ "", "<html><title>YLE Teleport</title></html>" }) do
                local page, err = parse(html)
                assert.is_nil(page)
                assert.are.equal("no content", err)
            end
        end)

        it("the subpage line is counted", function()
            local page = parse('<pre>x</pre><p>Flersida: 1,<font size="1"> </font><a href="100_0002.htm">2</a></p>')
            assert(page)
            assert.are.same({ "x" }, page.lines)
            assert.are.same({}, page.links)
            assert.are.equal(2, page.subpages)
        end)

        it("a page without a subpage line has one subpage", function()
            local page = parse("<pre>x</pre>")
            assert(page)
            assert.are.equal(1, page.subpages)
        end)

        it("real page fixture: link text is its page number", function()
            local page, err = parse(read_fixture())
            assert(page, err)
            assert(#page.links > 10, "too few links: " .. #page.links)
            for _, l in ipairs(page.links) do
                local text = page.lines[l.row + 1]:sub(l.col_start + 1, l.col_end)
                local p, s = l.target.page, l.target.subpage
                assert(tonumber(text) == p, ("link text %q does not match target %d.%d"):format(text, p, s))
            end
            assert.are.equal(4, page.subpages)
            for _, line in ipairs(page.lines) do
                assert(not line:find("[<>]") and not line:find("&%a+;"), "markup leaked: " .. line)
            end
        end)
    end)

    describe("nav", function()
        it("slots are read by position", function()
            local page = parse(
                '<SPAN class="US"><a href="100_0001.htm">Edellinen sivu</a>&nbsp;|&nbsp;'
                    .. 'Edellinen alasivu&nbsp;|&nbsp;<a href="101_0002.htm">Seuraava alasivu</a>&nbsp;|&nbsp;'
                    .. '<a href="102_0001.htm">Seuraava sivu</a></SPAN><pre>x</pre>'
            )
            assert(page)
            assert.are.same({
                prev_page = { page = 100, subpage = 1 },
                next_subpage = { page = 101, subpage = 2 },
                next_page = { page = 102, subpage = 1 },
            }, page.nav)
        end)

        it("a missing nav bar is empty", function()
            assert.are.same({}, pre("x").nav)
        end)

        it("real page fixture", function()
            local page = parse(read_fixture())
            assert(page)
            assert.are.same({
                next_subpage = { page = 100, subpage = 2 },
                next_page = { page = 101, subpage = 1 },
            }, page.nav)
        end)
    end)
end)
