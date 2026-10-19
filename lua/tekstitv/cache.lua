local M = {}

local ttl = 3600

-- Pages are only a few KB at most and page numbers are bounded,
-- so in-memory cache serves us fine
---@type table<string, { html: string, time: integer }>
local entries = {}

---@param page integer
---@param subpage integer
---@return string
local function key(page, subpage)
    return page .. "_" .. subpage
end

---@param page integer
---@param subpage integer
---@return string|nil
function M.get(page, subpage)
    local entry = entries[key(page, subpage)]
    if not entry or os.time() - entry.time > ttl then
        return nil
    end
    return entry.html
end

---@param page integer
---@param subpage integer
---@param html string
function M.set(page, subpage, html)
    entries[key(page, subpage)] = { html = html, time = os.time() }
end

return M
