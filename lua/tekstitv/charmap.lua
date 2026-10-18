local M = {}

-- stylua: ignore
M.entities = {
    nbsp = " ",
    amp = "&",
    lt = "<",
    gt = ">",
    quot = '"',
    ndash = "–",
    rdquo = "”",
    apos = "'",

    auml = "ä", Auml = "Ä",
    ouml = "ö", Ouml = "Ö",
    aring = "å", Aring = "Å",
}

--- Decode HTML entities (named, decimal, and hex) into UTF-8 text.
--- Unknown named entities are left as written so a missing mapping is visible.
---@param str string
---@return string
function M.decode(str)
    str = str:gsub("&#x(%x+);", function(hex)
        return vim.fn.nr2char(tonumber(hex, 16))
    end)

    str = str:gsub("&#(%d+);", function(dec)
        return vim.fn.nr2char(tonumber(dec) --[[@as integer]])
    end)

    str = str:gsub("&(%a+);", function(name)
        return M.entities[name] or ("&" .. name .. ";")
    end)

    return str
end

return M
