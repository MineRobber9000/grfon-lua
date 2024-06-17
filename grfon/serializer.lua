--- GRFON serializer.
--
-- Serializes a Lua table to a GRFON collection. "Garbage in, garbage out"
-- applies: if you couldn't create the table using a GRFON collection, you
-- can't create a GRFON collection from the table.
--
-- @module grfon.serializer

local serializer = {}

--- Indentation used.
serializer.INDENTATION = "    "

function serializer.serialize(value,dialect,indent,nested,asvalue)
    local dialect = dialect or require"grfon.dialect".Dialect
    local indent = indent or 0
    if type(value)=="table" then
        local s = ""
        if nested then
            if not asvalue then
                s = s..serializer.INDENTATION:rep(indent)
            end
            s = s.."{\n"
        else
            indent = indent - 1
        end
        for k,v in pairs(value) do
            if type(k)~="number" or k>#value then -- lists are handled later
                s = s..serializer.serialize(k,dialect,indent+1,true)
                s = s..": "
                s = s..serializer.serialize(v,dialect,indent+1,true,true)
                s = s.."\n"
            end
        end
        for i=1,#value do
            s = s..serializer.serialize(value[i],dialect,indent+1,true)
            s = s.."\n"
        end
        if nested then
            s = s..serializer.INDENTATION:rep(indent).."}"
        end
        return s
    end
    local v=dialect:serialize(value)
        or error(("Can't serialize value %s"):format(tostring(value)))
    if asvalue then return v end
    return serializer.INDENTATION:rep(indent)..v
end

return serializer