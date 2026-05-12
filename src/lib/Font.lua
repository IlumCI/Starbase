-- Font.lua: geometric canvas-based font renderer
-- Replaces love.graphics.print for consistent, styled text across all screens
-- Characters built from rectangles/lines/curves — no external font files needed

local C = require("consts")

local Font = {
    sizes = {},  -- cache: sizeName -> Canvas
}

-- Character definitions: each is a draw function(cr,cg,cb, scale)
-- Using a custom approach: geometric glyphs built from shapes
-- Format: { advance, lines={ {type, pts...} } }
-- type: "l"=line, "c"=arc(ox,oy,r,start,end)

local GLYPHS = {}

-- Helper to build glyph from line segments
local function glyph(advance, segments)
    return { advance = advance, draw = function(cr, cg, cb, s)
        love.graphics.setColor(cr, cg, cb)
        love.graphics.setLineWidth(math.max(1, s * 0.15))
        for _, seg in ipairs(segments) do
            if seg[1] == "l" then
                love.graphics.line(seg[2]*s, seg[3]*s, seg[4]*s, seg[5]*s)
            elseif seg[1] == "a" then
                love.graphics.setLineWidth(math.max(0.5, s * 0.12))
                love.graphics.arc("line", seg[2]*s, seg[3]*s, seg[4]*s, seg[5], seg[6])
            end
        end
    end }
end

-- Space
GLYPHS[" "] = { advance = 0.3, draw = function() end }

-- Digits
GLYPHS["0"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0.5,1},{"l",0.5,1,0,1},{"l",0,1,0,0}})
GLYPHS["1"] = glyph(0.4, {{"l",0.15,0,0.25,0},{"l",0.25,0,0.2,0.6},{"l",0.2,0.6,0.3,1}})
GLYPHS["2"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.35},{"l",0.5,0.35,0,1},{"l",0,1,0.5,1}})
GLYPHS["3"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5},{"l",0,0.5,0.5,0.5},{"l",0.5,0.5,0.5,1},{"l",0.5,1,0,1}})
GLYPHS["4"] = glyph(0.6, {{"l",0,0,0,0.6},{"l",0,0.6,0.5,0.6},{"l",0.5,0,0.5,1}})
GLYPHS["5"] = glyph(0.55, {{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5},{"l",0.5,0.5,0.5,1},{"l",0.5,1,0,1}})
GLYPHS["6"] = glyph(0.55, {{"l",0.5,0,0,0},{"l",0,0,0,1},{"l",0,1,0.5,1},{"l",0.5,1,0.5,0.5},{"l",0.5,0.5,0,0.5}})
GLYPHS["7"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0.3,1}})
GLYPHS["8"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0,0,0,1},{"l",0.5,0,0.5,1},{"l",0,1,0.5,1},{"a",0.25,0.5,0.25,math.pi,math.pi*2},{"a",0.25,0.5,0.25,0,math.pi}})
GLYPHS["9"] = glyph(0.55, {{"l",0,1,0.5,1},{"l",0.5,1,0.5,0},{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5}})

-- Uppercase
GLYPHS["A"] = glyph(0.6, {{"l",0.3,0,0,1},{"l",0,1,0.6,1},{"l",0.1,0.5,0.5,0.5}})
GLYPHS["B"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5},{"l",0.5,0.5,0.5,1},{"l",0.5,1,0,1}})
GLYPHS["C"] = glyph(0.55, {{"l",0.5,0,0,0},{"l",0,0,0,1},{"l",0,1,0.5,1}})
GLYPHS["D"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.45,0},{"l",0.45,0,0.5,0.3},{"l",0.5,0.3,0.5,0.7},{"l",0.5,0.7,0.45,1},{"l",0.45,1,0,1}})
GLYPHS["E"] = glyph(0.5, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0,0.5,0.35,0.5},{"l",0,1,0.5,1}})
GLYPHS["F"] = glyph(0.5, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0,0.5,0.35,0.5}})
GLYPHS["G"] = glyph(0.6, {{"l",0.5,0,0,0},{"l",0,0,0,1},{"l",0,1,0.5,1},{"l",0.5,1,0.5,0.5},{"l",0.5,0.5,0.2,0.5}})
GLYPHS["H"] = glyph(0.6, {{"l",0,0,0,1},{"l",0.5,0,0.5,1},{"l",0,0.5,0.5,0.5}})
GLYPHS["I"] = glyph(0.3, {{"l",0,0,0.3,0},{"l",0.15,0,0.15,1},{"l",0,1,0.3,1}})
GLYPHS["J"] = glyph(0.45, {{"l",0.15,0,0.45,0},{"l",0.45,0,0.45,0.8},{"l",0.45,0.8,0.2,1},{"l",0.2,1,0,1}})
GLYPHS["K"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0.5,0.5,0},{"l",0,0.5,0.5,1}})
GLYPHS["L"] = glyph(0.5, {{"l",0,0,0,1},{"l",0,1,0.5,1}})
GLYPHS["M"] = glyph(0.7, {{"l",0,1,0,0},{"l",0,0,0.35,0.5},{"l",0.35,0.5,0.7,0},{"l",0.7,0,0.7,1}})
GLYPHS["N"] = glyph(0.6, {{"l",0,1,0,0},{"l",0,0,0.5,1},{"l",0.5,1,0.5,0}})
GLYPHS["O"] = glyph(0.6, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,1},{"l",0,1,0.5,1}})
GLYPHS["P"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5}})
GLYPHS["Q"] = glyph(0.6, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,1},{"l",0,1,0.5,1},{"l",0.25,0.7,0.5,1}})
GLYPHS["R"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5},{"l",0.15,0.5,0.5,1}})
GLYPHS["S"] = glyph(0.55, {{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5},{"l",0.5,0.5,0.5,1},{"l",0.5,1,0,1}})
GLYPHS["T"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.25,0,0.25,1}})
GLYPHS["U"] = glyph(0.6, {{"l",0,0,0,0.8},{"l",0,0.8,0.5,1},{"l",0.5,1,0.5,0}})
GLYPHS["V"] = glyph(0.55, {{"l",0,0,0.25,1},{"l",0.25,1,0.5,0}})
GLYPHS["W"] = glyph(0.75, {{"l",0,0,0.15,1},{"l",0.15,1,0.375,0.5},{"l",0.375,0.5,0.6,1},{"l",0.6,1,0.75,0}})
GLYPHS["X"] = glyph(0.6, {{"l",0,0,0.5,1},{"l",0.5,0,0,1}})
GLYPHS["Y"] = glyph(0.6, {{"l",0,0,0.3,0.5},{"l",0.3,0.5,0.6,0},{"l",0.3,0.5,0.3,1}})
GLYPHS["Z"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0,1},{"l",0,1,0.5,1}})

-- Lowercase
GLYPHS["a"] = glyph(0.5, {{"l",0.15,0.3,0.15,0},{"l",0.15,0,0.5,0},{"l",0.15,0.3,0.5,0.3},{"l",0.5,0.3,0.5,0.5}})
GLYPHS["b"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5}})
GLYPHS["c"] = glyph(0.5, {{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5}})
GLYPHS["d"] = glyph(0.55, {{"l",0.5,0,0.5,1},{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5}})
GLYPHS["e"] = glyph(0.55, {{"l",0,0.25,0.5,0.25},{"l",0.5,0.25,0.5,0},{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5}})
GLYPHS["f"] = glyph(0.35, {{"l",0.15,0,0.15,1},{"l",0.15,0,0.35,0},{"l",0,0.5,0.3,0.5}})
GLYPHS["g"] = glyph(0.55, {{"l",0.5,0,0.5,1},{"l",0.5,1,0,1},{"l",0,1,0,0.5},{"l",0,0.5,0.5,0.5},{"l",0.5,0.5,0.5,0}})
GLYPHS["h"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5}})
GLYPHS["i"] = glyph(0.25, {{"l",0.12,0,0.12,0.7},{"l",0.12,0.85,0.12,0.95}})
GLYPHS["j"] = glyph(0.3, {{"l",0.15,0,0.15,0.9},{"l",0.15,0.95,0.05,1},{"l",0.05,1,0,1}})
GLYPHS["k"] = glyph(0.5, {{"l",0,0,0,1},{"l",0.15,0.5,0.5,0},{"l",0.15,0.5,0.5,1}})
GLYPHS["l"] = glyph(0.25, {{"l",0.12,0,0.12,1}})
GLYPHS["m"] = glyph(0.7, {{"l",0,0,0,0.5},{"l",0,0,0.25,0},{"l",0.25,0,0.25,0.5},{"l",0.25,0,0.5,0},{"l",0.5,0,0.5,0.5}})
GLYPHS["n"] = glyph(0.55, {{"l",0,0,0,0.5},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5}})
GLYPHS["o"] = glyph(0.55, {{"l",0,0,0,0.5},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0,0.5,0.5,0.5}})
GLYPHS["p"] = glyph(0.55, {{"l",0,0,0,1},{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.5},{"l",0.5,0.5,0,0.5}})
GLYPHS["q"] = glyph(0.55, {{"l",0.5,0,0.5,1},{"l",0.5,0,0,0},{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5}})
GLYPHS["r"] = glyph(0.4, {{"l",0,0,0,0.5},{"l",0,0,0.35,0},{"l",0.2,0.2,0.35,0.5}})
GLYPHS["s"] = glyph(0.5, {{"l",0.45,0,0,0},{"l",0,0,0,0.25},{"l",0,0.25,0.45,0.25},{"l",0.45,0.25,0.45,0.5},{"l",0.45,0.5,0,0.5}})
GLYPHS["t"] = glyph(0.35, {{"l",0.15,0,0.15,0.8},{"l",0,0.2,0.3,0.2}})
GLYPHS["u"] = glyph(0.55, {{"l",0,0,0,0.5},{"l",0,0.5,0.5,0.5},{"l",0.5,0.5,0.5,0}})
GLYPHS["v"] = glyph(0.5, {{"l",0,0,0.25,0.7},{"l",0.25,0.7,0.5,0}})
GLYPHS["w"] = glyph(0.7, {{"l",0,0,0.15,0.7},{"l",0.15,0.7,0.35,0.4},{"l",0.35,0.4,0.55,0.7},{"l",0.55,0.7,0.7,0}})
GLYPHS["x"] = glyph(0.5, {{"l",0,0,0.5,0.5},{"l",0.5,0,0,0.5}})
GLYPHS["y"] = glyph(0.55, {{"l",0,0,0.2,0.5},{"l",0.2,0.5,0.5,0},{"l",0.5,0,0.5,1},{"l",0.5,1,0.2,1}})
GLYPHS["z"] = glyph(0.5, {{"l",0,0,0.5,0},{"l",0.5,0,0,0.5},{"l",0,0.5,0.5,0.5}})

-- Symbols
GLYPHS["."] = glyph(0.2, {{"l",0.1,0.9,0.1,0.95}})
GLYPHS[","] = glyph(0.2, {{"l",0.1,0.8,0.05,0.95}})
GLYPHS["!"] = glyph(0.25, {{"l",0.12,0,0.12,0.7},{"l",0.12,0.85,0.12,0.95}})
GLYPHS["?"] = glyph(0.55, {{"l",0,0,0.5,0},{"l",0.5,0,0.5,0.35},{"l",0.5,0.35,0,0.35},{"l",0,0.35,0.5,0.35},{"l",0.25,0.55,0.25,0.75},{"l",0.25,0.85,0.25,0.95}})
GLYPHS[":"] = glyph(0.2, {{"l",0.1,0.2,0.1,0.25},{"l",0.1,0.75,0.1,0.8}})
GLYPHS["/"] = glyph(0.55, {{"l",0.5,0,0,1}})
GLYPHS["-"] = glyph(0.35, {{"l",0,0.45,0.3,0.45}})
GLYPHS["+"] = glyph(0.4, {{"l",0,0.5,0.35,0.5},{"l",0.175,0.25,0.175,0.75}})
GLYPHS["("] = glyph(0.3, {{"l",0.2,0,0.05,0.2},{"l",0.05,0.2,0.05,0.8},{"l",0.05,0.8,0.2,1}})
GLYPHS[")"] = glyph(0.3, {{"l",0.1,0,0.25,0.2},{"l",0.25,0.2,0.25,0.8},{"l",0.25,0.8,0.1,1}})
GLYPHS["["] = glyph(0.3, {{"l",0.25,0,0.05,0},{"l",0.05,0,0.05,1},{"l",0.05,1,0.25,1}})
GLYPHS["]"] = glyph(0.3, {{"l",0.05,0,0.25,0},{"l",0.25,0,0.25,1},{"l",0.25,1,0.05,1}})
GLYPHS["<"] = glyph(0.4, {{"l",0.3,0,0,0.5},{"l",0,0.5,0.3,1}})
GLYPHS[">"] = glyph(0.4, {{"l",0,0,0.3,0.5},{"l",0.3,0.5,0,1}})
GLYPHS["="] = glyph(0.4, {{"l",0,0.3,0.35,0.3},{"l",0,0.7,0.35,0.7}})
GLYPHS["'"] = glyph(0.15, {{"l",0.07,0,0.07,0.2}})
GLYPHS["\""] = glyph(0.3, {{"l",0.05,0,0.05,0.2},{"l",0.2,0,0.2,0.2}})
GLYPHS["#"] = glyph(0.6, {{"l",0,0.2,0.5,0.2},{"l",0,0.8,0.5,0.8},{"l",0.1,0,0.1,1},{"l",0.4,0,0.4,1}})
GLYPHS["*"] = glyph(0.4, {{"l",0,0.5,0.4,0.5},{"l",0.2,0,0.2,1},{"l",0,0.2,0.4,0.8}})
GLYPHS["&"] = glyph(0.65, {{"l",0,0,0.5,0},{"l",0.5,0,0.6,0.2},{"l",0.6,0.2,0.3,0.5},{"l",0.3,0.5,0.55,0.5},{"l",0.55,0.5,0,0.5},{"l",0,0.5,0,1},{"l",0,1,0.5,1}})
GLYPHS["@"] = glyph(0.7, {{"l",0.1,0,0.1,1},{"l",0.1,0,0.6,0},{"l",0.6,0,0.6,0.7},{"l",0.6,0.7,0.4,0.7},{"l",0.4,0.7,0.4,0.5},{"l",0.4,0.5,0.5,0.5}})
GLYPHS["^"] = glyph(0.4, {{"l",0.2,0.3,0.35,0},{"l",0.35,0,0.5,0.3}})

-- Measure text width given a size scale (char width * text length + kerning)
function Font.measure(text, scale)
    local scale = scale or 1
    local total = 0
    for i = 1, #text do
        local ch = text:sub(i, i)
        local g = GLYPHS[ch] or GLYPHS["?"]
        total = total + g.advance * scale
    end
    return total
end

-- Render text to an existing canvas at (x, y) with given color and scale
-- This draws directly without building a cached canvas (faster for dynamic text)
local function drawText(text, x, y, cr, cg, cb, scale, canvas)
    local function doDraw()
        local cx = 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            local g = GLYPHS[ch] or GLYPHS["?"]
            if g.draw then
                love.graphics.push()
                love.graphics.translate(x + cx, y)
                g.draw(cr, cg, cb, scale)
                love.graphics.pop()
            end
            cx = cx + g.advance * scale
        end
    end
    if canvas then
        canvas:renderTo(doDraw)
    else
        doDraw()
    end
end

-- Build a cached canvas for static text (title, labels that don't change often)
function Font.buildText(text, sizeName, cr, cg, cb)
    local key = text .. "_" .. sizeName .. "_" .. tostring(cr) .. tostring(cg) .. tostring(cb)
    if Font.sizes[key] then return Font.sizes[key] end

    local scale = C.FONT_SIZE[sizeName] or 24
    local textW = Font.measure(text, scale)
    local textH = scale * 1.5

    local canvas = love.graphics.newCanvas(textW + scale * 0.5, textH + scale * 0.3)
    canvas:renderTo(function()
        drawText(text, 0, scale * 0.1, cr, cg, cb, scale)
    end)

    Font.sizes[key] = { canvas = canvas, w = textW, h = textH, scale = scale }
    return Font.sizes[key]
end

-- Static draw: rendered text at position (fast path for mostly-static labels)
function Font.draw(text, x, y, cr, cg, cb, sizeName)
    local scale = C.FONT_SIZE[sizeName] or 24
    drawText(text, x, y, cr, cg, cb, scale)
end

-- Width of text at given size
function Font.width(text, sizeName)
    local scale = C.FONT_SIZE[sizeName] or 24
    return Font.measure(text, scale)
end

-- Centered draw
function Font.drawCentered(text, centerX, y, cr, cg, cb, sizeName)
    local scale = C.FONT_SIZE[sizeName] or 24
    local w = Font.measure(text, scale)
    local x = centerX - w / 2
    drawText(text, x, y, cr, cg, cb, scale)
end

return Font