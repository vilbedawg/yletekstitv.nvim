local M = {}

---@class tekstitv.Target
---@field page integer
---@field subpage integer

---@class tekstitv.Link
---@field row integer       0-based line index into `lines`
---@field col_start integer 0-based byte column, inclusive
---@field col_end integer   0-based byte column, exclusive
---@field target tekstitv.Target

---@class tekstitv.Nav
---@field prev_page tekstitv.Target|nil
---@field prev_subpage tekstitv.Target|nil
---@field next_subpage tekstitv.Target|nil
---@field next_page tekstitv.Target|nil

---@class tekstitv.Page
---@field lines string[]
---@field links tekstitv.Link[]
---@field nav tekstitv.Nav

-- stylua: ignore
local entities = {
    nbsp = " ", amp = "&", lt = "<", gt = ">", quot = '"', apos = "'",
    ndash = "–", rdquo = "”",
    auml = "ä", Auml = "Ä",
    ouml = "ö", Ouml = "Ö",
    aring = "å", Aring = "Å",
}

-- The site's nav bar always has these four slots, in this order.
local NAV_SLOTS = { "prev_page", "prev_subpage", "next_subpage", "next_page" }

--- Unknown named entities are left as written so a missing mapping is visible.
---@param s string
---@return string
local function decode(s)
    s = s:gsub("&#(%d+);", function(n)
        return vim.fn.nr2char(tonumber(n) --[[@as integer]])
    end)
    return (s:gsub("&(%a+);", entities))
end

--- "245_0002.htm" -> 245.2, nil for external links.
---@param href string
---@return tekstitv.Target|nil
local function target(href)
    local page, subpage = href:match("^(%d+)_(%d+)%.htm$")
    if page then
        return { page = tonumber(page), subpage = tonumber(subpage) }
    end
end

---@param page tekstitv.Page
---@param html string one line; the only markup is <a href="...">text</a>
local function add_line(page, html)
    local row, parts, col, pos = #page.lines, {}, 0, 1
    while true do
        local s, e, href, inner = html:find('<a [^>]-href="([^"]*)"[^>]*>(.-)</a>', pos)
        local text = decode(html:sub(pos, (s or 0) - 1))
        parts[#parts + 1] = text
        col = col + #text
        if not s then
            break
        end

        text = decode(inner)
        local t = target(href)
        if t then
            page.links[#page.links + 1] = { row = row, col_start = col, col_end = col + #text, target = t }
        end
        parts[#parts + 1] = text
        col = col + #text
        pos = e + 1
    end
    page.lines[row + 1] = table.concat(parts)
end

---@param html string
---@return tekstitv.Page|nil page
---@return string|nil err
function M.parse(html)
    local body = html:match("<pre[^>]*>\n?(.-)\n?</pre>") -- like browsers, drop the newline right after <pre>
    if not body then
        return nil, "no content"
    end

    ---@type tekstitv.Page
    local page = { lines = {}, links = {}, nav = {} }
    for _, line in ipairs(vim.split(body, "\n")) do
        add_line(page, line)
    end

    local label, subpages = html:match("</pre>.-<p>(%a+):%s*(.-)</p>")
    if label then
        add_line(page, label .. " " .. subpages:gsub("</?font[^>]*>", ""))
    end

    local nav = html:match('<SPAN%s+class="US"%s*>(.-)</SPAN>') or ""
    for i, slot in ipairs(vim.split(nav, "|", { plain = true })) do
        local href = slot:match('href="([^"]*)"')
        if NAV_SLOTS[i] and href then
            page.nav[NAV_SLOTS[i]] = target(href)
        end
    end

    return page, nil
end

return M
