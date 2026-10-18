local M = {}

local charmap = require("tekstitv.charmap")

---@alias tekstitv.section "nav"|"page"|"subpages"

---@class tekstitv.token
---@field type "text"|"link"|"newline"|"section"
---@field text string|nil -- for "section" tokens, the name of the section that starts here
---@field target string|nil -- TODO: Externals should be able to be opened via lsp keymap (open external in browser)

---@param body string
---@return tekstitv.token[]
local function tokenise(body)
    ---@type tekstitv.token[]
    local tokens = {}

    ---@param type "text"|"link"|"newline"
    ---@param text string|nil
    ---@param target string|nil
    local function push(type, text, target)
        tokens[#tokens + 1] = { type = type, text = text, target = target }
    end

    local pos = 1
    while pos <= #body do
        local start = pos
        local c = body:sub(pos, pos)
        if c == "\n" then
            push("newline")
            pos = pos + 1
        elseif c == "&" then
            local e = body:find(";", pos, true) or pos
            push("text", charmap.decode(body:sub(pos, e)))
            pos = e + 1
        elseif c == "<" then
            local e = body:find(">", pos, true)
            local href = e and body:sub(pos, e):match('^<a%s[^>]-href%s*=%s*"([^"]*)"')
            local close_s, close_e
            if href then
                close_s, close_e = body:find("</a>", e + 1, true)
            end

            if close_s then
                local inner = body:sub(e + 1, close_s - 1):gsub("<[^>]*>", "")
                local text = charmap.decode(inner)
                local page, sub = href:match("^(%d+)_(%d+)%.htm$")
                if page then
                    push("link", text, page .. "_" .. sub)
                else
                    push("text", text) -- external link
                end
                pos = close_e + 1
            elseif e then
                pos = e + 1 -- any other tag: skip
            else
                push("text", "<") -- stray "<"
                pos = pos + 1
            end
        else
            local s = body:find("[<&\n]", pos + 1) or (#body + 1) -- end of plain run
            push("text", body:sub(pos, s - 1))
            pos = s
        end

        assert(pos > start, ("lexer stuck at byte %d (%q)"):format(start, c))
    end

    return tokens
end

---@param html string
---@return tekstitv.token[]|nil tokens
---@return string|nil err
function M.tokenise_html(html)
    if not html or html == "" then
        return nil, "no content"
    end

    local page = html:match("<pre[^>]*>\n?(.-)</pre>") -- like browsers, drop the newline right after <pre>
    if not page then
        return nil, "no content"
    end
    local nav = html:match('<SPAN%s+class="US"%s*>(.-)</SPAN>') or ""
    local label, subpages = html:match("</pre>.-<p>(%a+):%s*(.-)</p>")

    ---@type tekstitv.token[]
    local tokens = {}

    tokens[#tokens + 1] = { type = "section", text = "nav" }
    vim.list_extend(tokens, tokenise(nav))

    tokens[#tokens + 1] = { type = "section", text = "page" }
    vim.list_extend(tokens, tokenise(page))
    if label then
        tokens[#tokens + 1] = { type = "section", text = "subpages" }
        vim.list_extend(tokens, tokenise(label .. " " .. subpages))
    end
    return tokens, nil
end

return M
