local assert = require("luassert")
local lexer = require("tekstitv.lexer")

local function section(name)
    return { type = "section", text = name }
end

local function text(s)
    return { type = "text", text = s }
end

local function link(s, target)
    return { type = "link", text = s, target = target }
end

local NEWLINE = { type = "newline" }

--- Tokenise a bare <pre> body, without the leading (empty) nav and page section tokens.
local function lex(body)
    local tokens, err = lexer.tokenise_html("<html><pre>" .. body .. "</pre></html>")
    assert(tokens, err)
    assert.are.same({ section("nav"), section("page") }, { tokens[1], tokens[2] })
    return vim.list_slice(tokens, 3)
end

--- Rebuild the display text from tokens (newline tokens become "\n").
local function flatten(tokens)
    local out = {}
    for _, t in ipairs(tokens) do
        out[#out + 1] = t.type == "newline" and "\n" or t.text
    end
    return table.concat(out)
end

local function has_link(tokens)
    for _, t in ipairs(tokens) do
        if t.type == "link" then
            return true
        end
    end
    return false
end

describe("lexer", function()
    describe("text", function()
        it("plain text is a single token", function()
            assert.are.same({ text("hello world") }, lex("hello world"))
        end)

        it("newlines split text runs", function()
            assert.are.same({ text("a"), NEWLINE, text("b") }, lex("a\nb"))
        end)

        it("consecutive and trailing newlines are preserved", function()
            assert.are.same({ text("a"), NEWLINE, NEWLINE, text("b"), NEWLINE }, lex("a\n\nb\n"))
        end)

        it("whitespace is preserved exactly", function()
            assert.are.same({ text("  a   b  ") }, lex("  a   b  "))
        end)
    end)

    describe("entities", function()
        it("the cursor skips the whole entity", function()
            assert.are.same({ text("a"), text("ä"), text("b") }, lex("a&auml;b"))
        end)

        it("at the start and end of the body", function()
            assert.are.same({ text(" "), text("x"), text(" ") }, lex("&nbsp;x&nbsp;"))
        end)

        it("adjacent entities", function()
            assert.are.same({ text("Ä"), text("Ä"), text("ö") }, lex("&Auml;&Auml;&ouml;"))
        end)

        it("an unknown entity is kept as written", function()
            assert.are.same({ text("a"), text("&euro;"), text("b") }, lex("a&euro;b"))
        end)

        it("numeric entities", function()
            assert.are.same({ text("ä"), text("ä") }, lex("&#228;&#xE4;"))
        end)

        it("an unterminated & is literal and does not hang", function()
            assert.are.equal("x & y", flatten(lex("x & y")))
            assert.are.equal("trailing &", flatten(lex("trailing &")))
        end)
    end)

    describe("links", function()
        it("a page link becomes a link token with a target", function()
            assert.are.same({ link("199", "199_0001") }, lex('<a href="199_0001.htm">199</a>'))
        end)

        it("a link between text, on one line", function()
            assert.are.same(
                { text("x "), link("101", "101_0001"), text(" UUTISET") },
                lex('x <a href="101_0001.htm">101</a> UUTISET')
            )
        end)

        it("several links keep their own targets", function()
            local tokens = lex('<a href="101_0001.htm">101</a> <a href="300_0002.htm">300</a>')
            assert.are.equal(3, #tokens)
            assert.are.equal("101_0001", tokens[1].target)
            assert.are.equal("300_0002", tokens[3].target)
        end)

        it("link text is decoded", function()
            assert.are.same({ link("Ä", "101_0001") }, lex('<a href="101_0001.htm">&Auml;</a>'))
        end)

        it("tags inside a link are stripped from its text", function()
            assert.are.same({ link("101", "101_0001") }, lex('<a href="101_0001.htm"><span>10</span>1</a>'))
        end)

        it("extra attributes on the anchor are fine", function()
            assert.are.same({ link("101", "101_0001") }, lex('<a class="x" href="101_0001.htm" id="y">101</a>'))
        end)

        it("an external link keeps its text as plain text", function()
            assert.are.same(
                { text("yle.fi/tekstitv") },
                lex('<a href="https://yle.fi/tekstitv" target="_blank">yle.fi/tekstitv</a>')
            )
        end)

        it("an href that is not page_subpage.htm is not navigable", function()
            assert.are.same({ text("x") }, lex('<a href="100.htm">x</a>'))
        end)

        it("an anchor without href is skipped, its text kept", function()
            local tokens = lex('<a name="top">x</a>')
            assert.are.equal("x", flatten(tokens))
            assert.is_false(has_link(tokens))
        end)

        it("<a> without </a> is skipped without hanging", function()
            assert.are.equal("a 101", flatten(lex('a <a href="101_0001.htm">101')))
        end)

        it("a link followed by a newline", function()
            assert.are.same({ link("101", "101_0001"), NEWLINE, text("x") }, lex('<a href="101_0001.htm">101</a>\nx'))
        end)
    end)

    describe("other markup", function()
        it("other tags are dropped, their content kept", function()
            assert.are.same({ text("a"), text("b"), text("c") }, lex('a<span class="x">b</span>c'))
        end)

        it("<abbr> is not an anchor", function()
            local tokens = lex("<abbr>x</abbr>")
            assert.are.equal("x", flatten(tokens))
            assert.is_false(has_link(tokens))
        end)

        it("a stray < with no > becomes literal text", function()
            assert.are.same({ text("x "), text("<"), text(" y") }, lex("x < y"))
        end)
    end)

    describe("document", function()
        it("empty html and a missing <pre> are errors", function()
            for _, html in ipairs({ "", "<html>nothing</html>" }) do
                local tokens, err = lexer.tokenise_html(html)
                assert.is_nil(tokens)
                assert.are.equal("no content", err)
            end
            ---@diagnostic disable-next-line: param-type-mismatch -- nil on purpose
            local tokens, err = lexer.tokenise_html(nil)
            assert.is_nil(tokens)
            assert.are.equal("no content", err)
        end)

        it("an empty <pre> gives no tokens", function()
            assert.are.same({}, lex(""))
        end)

        it("a <pre> with attributes is found", function()
            assert.are.same(
                { section("nav"), section("page"), text("a") },
                lexer.tokenise_html('<pre class="x">a</pre>')
            )
        end)

        it("real page fixture: no markup leaks, links are well formed", function()
            local html = table.concat(vim.fn.readfile("spec/fixtures/100_0001.htm"), "\n")
            local tokens, err = lexer.tokenise_html(html)
            assert(tokens, err)

            local links, sections, current = 0, {}, nil
            for _, t in ipairs(tokens) do
                if t.type == "section" then
                    current = t.text
                    sections[#sections + 1] = t.text
                elseif t.type == "link" then
                    links = links + 1
                    local p, s = t.target:match("^(%d+)_(%d+)$")
                    assert(p, t.target)
                    -- nav links are named ("Seuraava sivu"); subpage links ("Alasivut: 1, 2, 3") show the subpage number
                    assert(
                        current == "nav" or t.text == p or tonumber(t.text) == tonumber(s),
                        ("link text %q vs %s"):format(t.text, t.target)
                    )
                elseif t.type == "text" then
                    assert(not t.text:find("[<>]"), "markup leaked: " .. t.text)
                    assert(not t.text:find("&%a+;"), "entity leaked: " .. t.text)
                end
            end
            assert(links > 10, "too few links: " .. links)
            assert.are.same({ "nav", "page", "subpages" }, sections)
        end)

        it("real page sample (pre.html): 20 page links, external link is text", function()
            local tokens = lex(table.concat(vim.fn.readfile("spec/fixtures/pre.html"), "\n"))
            local links = 0
            for _, t in ipairs(tokens) do
                if t.type == "link" then
                    links = links + 1
                end
            end
            assert.are.equal(20, links)
            assert.truthy(flatten(tokens):find("yle.fi/tekstitv", 1, true))
        end)
    end)
end)
