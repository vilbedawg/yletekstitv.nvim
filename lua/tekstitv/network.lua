local M = {}

-- curl exit codes that mean the site could not be reached at all
-- (6 host not resolved, 7 connect failed, 28 curl timeout, 124 vim.system timeout).
local UNREACHABLE = { [6] = true, [7] = true, [28] = true, [124] = true }

---@param page number
---@param subpage number
---@param obj table vim.system() result
---@return string
local function error_message(page, subpage, obj)
    -- -f makes curl fail on HTTP errors: exit 22 over HTTP/1.1 but 56 over
    -- HTTP/2, so look for the status in stderr instead of the exit code.
    if (obj.stderr or ""):find("returned error: 404", 1, true) then
        return string.format("Page %d.%d does not exist.", page, subpage)
    end
    if UNREACHABLE[obj.code] then
        return "Could not reach yle.fi."
    end
    return string.format("Could not load page %d.%d.", page, subpage)
end

---@param page number
---@param subpage number
---@param callback fun(ok: boolean, html_or_err: string)
function M.fetch(page, subpage, callback)
    local url = string.format("https://yle.fi/tekstitv/txt/%d_%04d.htm", page, subpage)
    vim.system({ "curl", "-A", "tekstitv.nvim", "-fsS", url }, { text = true, timeout = 1000 }, function(obj)
        if obj.code ~= 0 then
            callback(false, error_message(page, subpage, obj))
            return
        end
        if not obj.stdout or obj.stdout == "" then
            callback(false, string.format("Page %d.%d is empty.", page, subpage))
            return
        end
        callback(true, obj.stdout)
    end)
end

return M
