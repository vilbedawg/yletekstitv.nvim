local M = {}

local lexer = require("tekstitv.lexer")

---@class tekstitv.Target
---@field page integer
---@field subpage integer

---@class tekstitv.Link
---@field row integer       0-based line index into `lines`
---@field col_start integer 0-based byte column, inclusive
---@field col_end integer   0-based byte column, exclusive
---@field target tekstitv.Target

---@class tekstitv.Span
---@field row integer       0-based line index
---@field col_start integer 0-based byte column, inclusive
---@field col_end integer   0-based byte column, exclusive
---@field hl_group string

---@class tekstitv.Page
---@field lines string[]
---@field links tekstitv.Link[]
---@field spans tekstitv.Span[]
---@field nav tekstitv.Target[] link targets in the site's nav bar (prev/next page and subpage)

---@type table<string, string> token type -> highlight group
local HL_GROUPS = {
    link = "TekstitvLink",
    text = "TekstitvText",
}

--- Split a lexer link target ("245_0001") into page and subpage.
---@param target string
---@return integer page
---@return integer subpage
local function split_target(target)
    local page, subpage = target:match("^(%d+)_(%d+)$")
    assert(page, ("bad link target %q"):format(target))
    local p = tonumber(page) --[[@as integer]]
    local s = tonumber(subpage) --[[@as integer]]
    return p, s
end

--- Lay the lexer's tokens out as screen lines and link ranges.
---@param tokens tekstitv.token[]
---@return tekstitv.Page
function M.parse_tokens(tokens)
    local lines, links, spans, nav = {}, {}, {}, {}
    local cur = {} -- pieces of the line being assembled
    local row, col = 0, 0
    ---@type tekstitv.section|nil
    local section

    local function end_line()
        lines[#lines + 1] = table.concat(cur)
        cur, row, col = {}, row + 1, 0
    end

    for _, token in ipairs(tokens) do
        if token.type == "section" then
            section = token.text
            if #cur > 0 then -- each section starts on its own line
                end_line()
            end
        elseif section == "nav" then
            if token.type == "link" then
                local page, subpage = split_target(token.target)
                nav[#nav + 1] = { page = page, subpage = subpage }
            end
        elseif token.type == "newline" then
            end_line()
        else
            spans[#spans + 1] = {
                row = row,
                col_start = col,
                col_end = col + #token.text,
                hl_group = HL_GROUPS[token.type],
            }
            if token.type == "link" then
                local page, subpage = split_target(token.target)
                links[#links + 1] = {
                    row = row,
                    col_start = col,
                    col_end = col + #token.text,
                    target = { page = page, subpage = subpage },
                }
            end
            cur[#cur + 1] = token.text
            col = col + #token.text
        end
    end

    if #cur > 0 then -- body did not end with a newline
        lines[#lines + 1] = table.concat(cur)
    end

    return { lines = lines, links = links, spans = spans, nav = nav }
end

---@param html string
---@return tekstitv.Page|nil page
---@return string|nil err
function M.parse_html(html)
    local tokens, err = lexer.tokenise_html(html)
    if not tokens then
        return nil, err
    end
    return M.parse_tokens(tokens), nil
end

return M
