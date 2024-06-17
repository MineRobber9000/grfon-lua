--- GRFON unserialization in Lua.
--
-- @module grfon

local grfon = {}

grfon.dialect = require"grfon.dialect"
grfon.parser = require"grfon.parser"
grfon.serializer = require"grfon.serializer"

function grfon.parse(source,dialect)
    local parser = grfon.parser.Parser:new(source,dialect)
    return parser:parse_element()
end

function grfon.dump(tbl,dialect)
    return grfon.serializer.serialize(tbl,dialect)
end

return grfon