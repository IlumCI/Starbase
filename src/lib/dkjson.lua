--[[
  dkjson.lua - Public Domain JSON encoder/decoder
  Minimal implementation: json.encode(value) and json.decode(str)
]]

local json = {}

-- Encoder: convert Lua value to JSON string

local escape_chars = {
  ["\""] = "\\\"",
  ["\\"] = "\\\\",
  ["/"]  = "\\/",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(s)
  return "\"" .. (tostring(s):gsub('[\\"/%c]', escape_chars)) .. "\""
end

local function encode_value(v)
  local vt = type(v)
  if vt == "nil" then
    return "null"
  elseif vt == "boolean" then
    return v and "true" or "false"
  elseif vt == "number" then
    if v ~= v then
      return "null"  -- NaN -> null
    elseif v == math.huge then
      return "null"  -- Infinity -> null
    elseif v == -math.huge then
      return "null"
    else
      return tostring(v)
    end
  elseif vt == "string" then
    return encode_string(v)
  elseif vt == "table" then
    return json.encode(v)
  else
    return "null"  -- functions, threads, userdata -> null
  end
end

local function is_array(t)
  local max = 0
  local count = 0
  for k, _ in pairs(t) do
    if type(k) == "number" and k > 0 and k == math.floor(k) then
      if k > max then max = k end
      count = count + 1
    else
      return false
    end
  end
  return count > 0 and max == count
end

function json.encode(data)
  if type(data) ~= "table" then
    return encode_value(data)
  end

  if is_array(data) then
    local parts = {}
    for i = 1, #data do
      parts[i] = json.encode(data[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
  else
    local parts = {}
    local i = 1
    for k, v in pairs(data) do
      if type(k) == "string" then
        parts[i] = encode_string(k) .. ":" .. json.encode(v)
        i = i + 1
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
end

-- Decoder: parse JSON string to Lua value

local function next_char(s, i)
  local ch = s:sub(i, i)
  return ch, ch ~= "" and i + 1 or i
end

local function skip_whitespace(s, i)
  while true do
    local ch = s:sub(i, i)
    if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
      i = i + 1
    else
      return i
    end
  end
end

local escape_map = {
  ["\""] = "\"",
  ["\\"] = "\\",
  ["/"]  = "/",
  ["b"]  = "\b",
  ["f"]  = "\f",
  ["n"]  = "\n",
  ["r"]  = "\r",
  ["t"]  = "\t",
}

local function parse_string(s, i)
  i = i + 1  -- skip opening quote
  local res = {}
  while true do
    if i > #s then
      return nil, "unterminated string"
    end
    local ch = s:sub(i, i)
    if ch == "\"" then
      return table.concat(res), i + 1
    elseif ch == "\\" then
      i = i + 1
      local esc = s:sub(i, i)
      if escape_map[esc] then
        table.insert(res, escape_map[esc])
        i = i + 1
      elseif esc == "u" then
        local hex = s:sub(i + 1, i + 4)
        if #hex == 4 and hex:match("^[0-9a-fA-F]+$") then
          local code = tonumber(hex, 16)
          if code then
            table.insert(res, string.char(code))
            i = i + 5
          else
            return nil, "invalid unicode escape"
          end
        else
          return nil, "invalid unicode escape"
        end
      else
        return nil, "invalid escape"
      end
    else
      table.insert(res, ch)
      i = i + 1
    end
  end
end

local function parse_number(s, i)
  local start = i
  -- optional minus
  if s:sub(i, i) == "-" then i = i + 1 end
  -- integer part
  while s:sub(i, i):match("[0-9]") do i = i + 1 end
  -- decimal
  if s:sub(i, i) == "." then
    i = i + 1
    while s:sub(i, i):match("[0-9]") do i = i + 1 end
  end
  -- exponent
  local exp = s:sub(i, i)
  if exp == "e" or exp == "E" then
    i = i + 1
    if s:sub(i, i) == "+" or s:sub(i, i) == "-" then i = i + 1 end
    while s:sub(i, i):match("[0-9]") do i = i + 1 end
  end
  local num = tonumber(s:sub(start, i - 1))
  if not num then return nil, "invalid number", i end
  return num, i
end

local function parse_literal(s, i)
  local rest = s:sub(i)
  if rest:find("^true") then
    return true, i + 4
  elseif rest:find("^false") then
    return false, i + 5
  elseif rest:find("^null") then
    return nil, i + 4
  else
    return nil, "unexpected token"
  end
end

local function parse_value(s, i)
  i = skip_whitespace(s, i)
  local ch = s:sub(i, i)

  if ch == "\"" then
    return parse_string(s, i)
  elseif ch == "[" then
    return parse_array(s, i)
  elseif ch == "{" then
    return parse_object(s, i)
  elseif ch == "t" or ch == "f" or ch == "n" then
    return parse_literal(s, i)
  elseif ch == "-" or ch:match("[0-9]") then
    return parse_number(s, i)
  else
    return nil, "unexpected character: " .. ch
  end
end

function parse_array(s, i)
  i = i + 1  -- skip '['
  i = skip_whitespace(s, i)
  local arr = {}
  if s:sub(i, i) == "]" then
    return arr, i + 1
  end
  while true do
    local val
    val, i = parse_value(s, i)
    if val == nil then return nil, i end
    table.insert(arr, val)
    i = skip_whitespace(s, i)
    local ch = s:sub(i, i)
    if ch == "]" then
      return arr, i + 1
    elseif ch == "," then
      i = i + 1
    else
      return nil, "expected , or ]"
    end
  end
end

function parse_object(s, i)
  i = i + 1  -- skip '{'
  i = skip_whitespace(s, i)
  local obj = {}
  if s:sub(i, i) == "}" then
    return obj, i + 1
  end
  while true do
    i = skip_whitespace(s, i)
    if s:sub(i, i) ~= "\"" then
      return nil, "expected key string"
    end
    local key
    key, i = parse_string(s, i)
    if key == nil then return nil, i end
    i = skip_whitespace(s, i)
    if s:sub(i, i) ~= ":" then
      return nil, "expected :"
    end
    i = i + 1
    local val
    val, i = parse_value(s, i)
    if val == nil then return nil, i end
    obj[key] = val
    i = skip_whitespace(s, i)
    local ch = s:sub(i, i)
    if ch == "}" then
      return obj, i + 1
    elseif ch == "," then
      i = i + 1
    else
      return nil, "expected , or }"
    end
  end
end

function json.decode(str)
  if type(str) ~= "string" then
    return nil, "expected string"
  end
  local i = skip_whitespace(str, 1)
  if i > #str then
    return nil, "empty input"
  end
  local result, new_i = parse_value(str, i)
  if result == nil then
    return nil, "parse error at position " .. i
  end
  -- check for trailing garbage
  local trailing = skip_whitespace(str, new_i)
  if trailing <= #str then
    return nil, "trailing characters after JSON"
  end
  return result, new_i
end

return json