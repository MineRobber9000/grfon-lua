--- GRFON parser.
--
-- GRFON is a simple language to parse, complicated only by its use of UTF-8
-- encoding, which Lua doesn't natively handle. Still, as long as we're careful
-- with utf8lib, we can still parse it really easily.
--
-- @module grfon.parser

local parser = {}

local Parser = {}
Parser.__index = Parser
parser.Parser = Parser

--- Should the parser error on non-string keys?
-- C# implementation says yes, MiniScript implementation (by a principal author
-- of GRFON) says no, we say "leave it up to the user".
-- Defaults to yes.
Parser.keys_must_be_string = true

--- Creates a new parser object.
-- @param source The GRFON source being parsed.
-- @param dialect A dialect of GRFON to use (defaults to the base class).
function Parser:new(source, dialect)
    if dialect==nil then dialect = require"grfon.dialect".Dialect end
    local len, errpos = utf8.len(source)
    if not len then
        error(
            ("Invalid UTF-8 source! (Erroneous %02X at position %d)"):format(
                source:byte(errpos),
                errpos
            ),2)
    end
    local self = setmetatable({},self) -- gross but I can't be bothered
    self.source = source
    self.source_len = len
    self.dialect = dialect
    self.c = 1
    self.i = 1
    return self
end

--- Retrieves the character at the parser's current position.
-- @return The character at the parser's current position.
function Parser:char()
    if self.c>self.source_len then return "" end
    return utf8.char(utf8.codepoint(self.source,self.i))
end

--- Retrieves the character one beyond the parser's current position.
-- @return The character one beyond the parser's current position.
function Parser:peek_char()
    if (self.c+1)>self.source_len then return "" end
    return utf8.char(utf8.codepoint(self.source,utf8.offset(self.source,self.c+1)))
end

--- Advances the parser past the current character.
-- Has no effect when the parser is already out of characters.
function Parser:advance_char()
    if self.c>self.source_len then return end
    self.c=self.c+1
    self.i=utf8.offset(self.source,self.c)
end

--- A list of characters considered "whitespace".
local whitespace = {
    [" "] = true,
    ["\t"] = true,
    ["\r"] = true,
    ["\n"] = true
}

--- Advances the parser until the current character is no longer whitespace.
-- If a comment is encountered, the parser will skip to the next line.
-- POST-CONDITION: current character is no longer whitespace
-- (that is, `not whitespace[self:char()]` would evaluate to true)
function Parser:skip_whitespace()
    while self.c<=self.source_len do
        local c = self:char()
        if c=="/" and self:peek_char()=="/" then
            self:advance_char()
            self:advance_char()
            self:skip_to_eol()
            c = self:char()
        end
        if not whitespace[c] then return end
        self:advance_char()
    end
end

--- Advances the parser until the current character is a newline.
-- POST-CONDITION: current character is U+000D or U+000A.
function Parser:skip_to_eol()
    while self.c<=self.source_len do
        local c = self:char()
        if c=="\r" or c=="\n" then break end
        self:advance_char()
    end
end

--- A list of characters that, unescaped, end a string.
local string_delimiters = {
    [":"] = true,
    [";"] = true,
    ["}"] = true,
    ["\r"] = true,
    ["\n"] = true
}

--- Parses a GRFON collection or value.
-- @param asvalue Whether to skip collection parsing and just return a value
-- @return The value parsed.
function Parser:parse_element(asvalue)
    local result = nil
    while true do
        self:skip_whitespace()
        if self.c>self.source_len then return result end
        if self:char()=="}" then
            if asvalue then return result end
            self:advance_char()
            return result
        end
        local token
        if self:char()=="{" then
            self:advance_char()
            token = self:parse_element()
        else
            token = self.dialect:unserialize(self:parse_string())
        end
        if asvalue then return token end
        self:skip_whitespace()
        local next = self:char()
        if next==":" then -- key/value pair
            assert(
                (not self.keys_must_be_string) or type(token)=="string",
                "Invalid GRFON (keys must be string!)")
            self:advance_char()
            token2 = self:parse_element(true)
            if result==nil then result={} end
            if type(result)~="table" then result={result} end
            result[token] = token2
        elseif next==";" then
            if result==nil then
                result={token}
            else
                result[#result+1]=token
            end
            self:advance_char()
        else
            if result==nil then
                result=token
            elseif type(result)=="table" then
                result[#result+1]=token
            else
                result={result,token}
            end
            if next=="" then return result end
        end
    end
end

function Parser:parse_string()
    self:skip_whitespace()
    if whitespace[self:char()] then error("skipped whitespace and still have whitespace *somehow*") end
    local s = ""
    while self.c<=self.source_len do
        local c = self:char()
        if string_delimiters[c] then break end
        if c=="/" and self:peek_char()=="/" then break end
        s = s .. c
        self:advance_char()
        if c==[[\]] then
            s = s .. self:char()
            self:advance_char()
        end
    end
    return s
end

return parser