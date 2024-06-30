--- Configure how grfon-lua parses GRFON.
--
-- GRFON itself does not define any semantics for values that are not a string
-- or a collection, so the author of the host app has to decide how other
-- structures are represented.
--
-- grfon-lua takes the path of defining a Dialect type, which takes in a string
-- or collection and returns what that string or collection *means* to the host
-- application.
--
-- @module grfon.dialect

local dialect = {}

--- Dialect base class.
-- @class Dialect
local Dialect = {}
Dialect.__index = Dialect
dialect.Dialect = Dialect

--- Returns a subclass of Dialect.
-- @return The new Dialect subclass.
function Dialect:subclass()
    local v = setmetatable({},self)
    v.__index = v
    return v
end

--- Returns the host-app representation of the string or collection `value`.
-- @param value A string or collection
-- @return The value as understood by the host app.
function Dialect:unserialize(value)
    -- Base class: just return the value unchanged.
    return value
end

--- Returns a GRFON representation of the value `value`.
-- Specifically, parsing the GRFON resulting from this method should result in
-- the value `value` being produced.
-- If this method returns nil, the serializer will throw an error saying the
-- value is unsupported by the dialect.
-- @param value Any Lua value (except table)
-- @return The value in a GRFON string representation (or nil if unsupported)
function Dialect:serialize(value)
    if type(value)=="string" then
        return (value:gsub(
            [[([:;}/\])]], function(c) return "\\"..c end
        ):gsub(
            [[\:\/\/]], "://"
        ))
    end
    return nil
end

--- Dialect subclass which interprets values.
-- @class InterpretDialect
local InterpretDialect = Dialect:subclass()
dialect.InterpretDialect = InterpretDialect

--- Interpret "nil" as nil.
InterpretDialect.nil_as_nil = false

--- Interpret "null" as nil.
InterpretDialect.null_as_nil = false

-- The above values default to false because nil values in a table aren't very
-- useful in Lua. But if you want them to be interpreted here, you can set them
-- in your own dialect (subclassed from InterpretDialect).

--- Interpret "\ddd" escapes.
InterpretDialect.interpret_decimal_escapes = false

function InterpretDialect:unescape(str)
    return (str:gsub(
        [[\a]], "\a"
    ):gsub(
        [[\b]], "\b"
    ):gsub(
        [[\f]], "\f"
    ):gsub(
        [[\t]], "\t"
    ):gsub(
        [[\n]], "\n"
    ):gsub(
        [[\r]], "\r"
    ):gsub(
        [[\v]], "\v"
    ):gsub(
        [[\(%d%d?%d?)]], function(n)
            if self.interpret_decimal_escapes then
                return string.char(tonumber(n))
            else
                return n
            end
        end
    ):gsub(
        [[\(.)]], function(c) return c end
    ))
end

function InterpretDialect:escape(str)
    if type(str)~="string" then return str end
    str = str:gsub("\\",[[\\]])
    if not utf8.len(str) then
        if not self.interpret_decimal_escapes then
            error(("Invalid UTF-8 string %q!"):format(str:gsub([[\\]],"\\")),2)
        end
        local len, errpos = utf8.len(str)
        while not len do
            str = str:sub(1,errpos-1)
                ..("\\%03d"):format(str:byte(errpos))
                ..str:sub(errpos+1)
            len, errpos = utf8.len(str)
        end
    end
    return (str:gsub(
        "\a", [[\a]]
    ):gsub(
        "\b", [[\b]]
    ):gsub(
        "\f", [[\f]]
    ):gsub(
        "\t", [[\t]]
    ):gsub(
        "\n", [[\n]]
    ):gsub(
        "\r", [[\r]]
    ):gsub(
        "\v", [[\v]]
    ):gsub(
        [[([:;}/\])]], function(c) return "\\"..c end
    ):gsub(
        [[\:\/\/]], "://"
    ))
end

function InterpretDialect:unserialize(value)
    if value=="true" then return true end
    if value=="false" then return false end
    if self.nil_as_nil and value=="nil" then return nil end
    if self.null_as_nil and value=="null" then return nil end
    return tonumber(value) or self:unescape(value)
end

function InterpretDialect:serialize(value)
    if value==true then return "true" end
    if value==false then return "false" end
    if value==nil then
        -- this shouldn't happen, since you can't index a table with nil
        -- and a nil value would be skipped over but whatever
        if self.nil_as_nil then return "nil" end
        if self.null_as_nil then return "null" end
        return nil -- otherwise unsupported
    end
    if type(value)=="number" then value=tostring(value) end
    return Dialect.serialize(self,self:escape(value))
end

return dialect