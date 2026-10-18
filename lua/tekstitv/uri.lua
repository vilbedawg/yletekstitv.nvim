local M = {}

---@param page number
---@param subpage number
---@return string
function M.build(page, subpage)
    return string.format("tekstitv://%d/%d", page, subpage)
end

---@param name string buffer name / URI
---@return number|nil page
---@return number|nil subpage
function M.parse(name)
    local page, subpage = name:match("^tekstitv://(%d+)/(%d+)$")
    if not page then
        return nil, nil
    end
    return tonumber(page), tonumber(subpage)
end

return M
