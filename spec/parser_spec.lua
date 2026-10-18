local assert = require("luassert")
local parser = require("tekstitv.parser")

--- Parse a bare <pre> body.
---@return tekstitv.Page
local function parse(body)
    local page, err = parser.parse_html("<html><pre>" .. body .. "</pre></html>")
    assert(page, err)
    return page
end

local function read_fixture()
    return table.concat(vim.fn.readfile("spec/fixtures/100_0001.htm"), "\n")
end

describe("parser", function()
    describe("lines", function()
        it("plain text and newlines become lines", function()
            assert.are.same({ "one", "two", "three" }, parse("one\ntwo\nthree").lines)
        end)

        it("a trailing newline does not add an empty line, a missing one is flushed", function()
            assert.are.same({ "a", "b" }, parse("a\nb\n").lines)
            assert.are.same({ "a", "b" }, parse("a\nb").lines)
        end)

        it("other tags are dropped", function()
            assert.are.same({ "abc" }, parse('a<span class="x">b</span>c').lines)
        end)

        it("&nbsp; and unknown entities", function()
            assert.are.same({ "a b" }, parse("a&nbsp;b").lines)
            assert.are.same({ "a&euro;b" }, parse("a&euro;b").lines)
        end)

        it("stray < and & do not hang or crash", function()
            assert.are.same({ "x < y & z" }, parse("x < y & z").lines)
        end)
    end)

    describe("links", function()
        it("text kept, tag stripped, range recorded", function()
            local p = parse('<a href="199_0001.htm">199</a> P&Auml;&Auml;HAKEMISTO')
            assert.are.same({ "199 PÄÄHAKEMISTO" }, p.lines)
            assert.are.same({ { row = 0, col_start = 0, col_end = 3, target = { page = 199, subpage = 1 } } }, p.links)
        end)

        it("columns are byte offsets of the output text (multi-byte entity before link)", function()
            local p = parse('&Auml;&ouml; <a href="101_0001.htm">101</a>')
            assert.are.same({ "Äö 101" }, p.lines)
            -- "Äö " is 2+2+1 = 5 bytes
            assert.are.equal(5, p.links[1].col_start)
            assert.are.equal(8, p.links[1].col_end)
            assert.are.equal("101", p.lines[1]:sub(p.links[1].col_start + 1, p.links[1].col_end))
        end)

        it("rows are tracked per link", function()
            local p = parse('x\n  <a href="201_0001.htm">201</a>\n<a href="300_0002.htm">300</a>')
            assert.are.equal(1, p.links[1].row)
            assert.are.equal(2, p.links[1].col_start)
            assert.are.equal(2, p.links[2].row)
            assert.are.same({ page = 300, subpage = 2 }, p.links[2].target)
        end)

        it("several links on one line", function()
            local p = parse('<a href="101_0001.htm">101</a> UUTISET  <a href="160_0001.htm">160</a> TALOUS')
            assert.are.same({ "101 UUTISET  160 TALOUS" }, p.lines)
            assert.are.equal(2, #p.links)
            assert.are.same({ row = 0, col_start = 13, col_end = 16, target = { page = 160, subpage = 1 } }, p.links[2])
        end)

        it("external links keep their text but are not navigable", function()
            local p = parse('<a href="https://yle.fi/tekstitv" target="_blank">yle.fi/tekstitv</a> x')
            assert.are.same({ "yle.fi/tekstitv x" }, p.lines)
            assert.are.same({}, p.links)
        end)

        it("<a> without </a> is skipped without looping forever", function()
            local p = parse('a <a href="101_0001.htm">101')
            assert.are.same({}, p.links)
            assert.are.same({ "a 101" }, p.lines)
        end)
    end)

    describe("document", function()
        it("empty html and a missing <pre> are errors", function()
            for _, html in ipairs({ "", "<html>nothing</html>" }) do
                local page, err = parser.parse_html(html)
                assert.is_nil(page)
                assert.are.equal("no content", err)
            end
        end)

        it("the subpage line is appended after the page, on its own line", function()
            local page = parser.parse_html('<pre>x</pre><p>Alasivut: 1, <a href="100_0002.htm">2</a></p>')
            assert(page)
            assert.are.same({ "x", "Alasivut 1, 2" }, page.lines)
            assert.are.same(
                { { row = 1, col_start = 12, col_end = 13, target = { page = 100, subpage = 2 } } },
                page.links
            )
        end)

        it("real page fixture: link text is its page number (subpage number on the subpage line)", function()
            local page, err = parser.parse_html(read_fixture())
            assert(page, err)
            assert(#page.lines > 10, "too few lines: " .. #page.lines)
            assert(#page.links > 10, "too few links: " .. #page.links)
            for _, l in ipairs(page.links) do
                local text = page.lines[l.row + 1]:sub(l.col_start + 1, l.col_end)
                local p, s = l.target.page, l.target.subpage
                assert(
                    tonumber(text) == p or tonumber(text) == s,
                    ("link text %q does not match target %d.%d"):format(text, p, s)
                )
            end
            assert.are.equal("Alasivut 1, 2, 3, 4 ", page.lines[#page.lines])
            for _, line in ipairs(page.lines) do
                assert(not line:find("[<>]") and not line:find("&%a+;"), "markup leaked: " .. line)
            end
        end)
    end)

    describe("nav", function()
        it("the nav bar's links are kept, in order", function()
            local page = parser.parse_html(
                '<html><SPAN class="US"><a href="100_0001.htm">Edellinen sivu</a>&nbsp;|&nbsp;'
                    .. 'Edellinen alasivu&nbsp;|&nbsp;<a href="101_0002.htm">Seuraava alasivu</a>&nbsp;|&nbsp;'
                    .. '<a href="102_0001.htm">Seuraava sivu</a></SPAN><pre>x</pre></html>'
            )
            assert(page)
            assert.are.same({
                { page = 100, subpage = 1 },
                { page = 101, subpage = 2 },
                { page = 102, subpage = 1 },
            }, page.nav)
        end)

        it("a missing nav bar is empty", function()
            assert.are.same({}, parse("x").nav)
        end)

        it("real page fixture", function()
            local page = parser.parse_html(read_fixture())
            assert(page)
            assert.are.same({ { page = 100, subpage = 2 }, { page = 101, subpage = 1 } }, page.nav)
        end)
    end)
end)
