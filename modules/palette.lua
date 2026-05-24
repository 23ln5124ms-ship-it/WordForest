-- modules/palette.lua
-- Centralised warm colour palette & reusable UI helpers
-- All colours are Solar 2D {r, g, b} 0-1 floats

local M = {}

-- ─── Base palette ─────────────────────────────────────────
M.cream      = { 0.992, 0.965, 0.925 }   -- #fdf6ec  background
M.parchment  = { 0.961, 0.918, 0.847 }   -- #f5ead8  card surface
M.warmTan    = { 0.910, 0.835, 0.718 }   -- #e8d5b7  borders
M.bark       = { 0.769, 0.659, 0.510 }   -- #c4a882  muted text
M.amber      = { 0.831, 0.522, 0.227 }   -- #d4853a  accent warm
M.amberLt    = { 0.910, 0.659, 0.353 }   -- #e8a85a  lighter amber
M.rust       = { 0.722, 0.361, 0.165 }   -- #b85c2a  danger / timer crit
M.sage       = { 0.478, 0.620, 0.431 }   -- #7a9e6e  mid green
M.sageLt     = { 0.639, 0.769, 0.580 }   -- #a3c494  light green
M.sageDk     = { 0.306, 0.478, 0.259 }   -- #4e7a42  dark green
M.moss       = { 0.239, 0.400, 0.196 }   -- #3d6632  deep forest
M.gold       = { 0.831, 0.627, 0.188 }   -- #d4a030  achievement gold
M.mint       = { 0.553, 0.769, 0.690 }   -- #8dc4b0  fresh accent
M.leafGlow   = { 0.658, 0.839, 0.682 }   -- #a7d6ad  glow accent
M.rose       = { 0.933, 0.604, 0.671 }   -- #ee9aae  soft highlight
M.ink        = { 0.145, 0.165, 0.200 }   -- #262b33  high contrast text
M.paper      = { 0.984, 0.957, 0.918 }   -- #f9f3e9  soft paper surface
M.skyBlue    = { 0.494, 0.686, 0.769 }   -- #7eafc4  ocean accent
M.skyLt      = { 0.690, 0.831, 0.894 }   -- #b0d4e4  ocean light
M.dusk       = { 0.545, 0.435, 0.667 }   -- #8b6faa  cosmos accent
M.duskLt     = { 0.722, 0.651, 0.831 }   -- #b8a6d4  cosmos light
M.sand       = { 0.788, 0.663, 0.431 }   -- #c9a96e  ancient accent
M.sandLt     = { 0.898, 0.808, 0.624 }   -- #e5ce9f  ancient light

-- ─── Difficulty colours ───────────────────────────────────
M.diff = {
    easy   = { main = {0.306,0.478,0.259}, label = "🌱 EASY",   bg = {0.910,0.957,0.886} },
    medium = { main = {0.831,0.522,0.227}, label = "🌿 MEDIUM", bg = {0.996,0.957,0.898} },
    hard   = { main = {0.722,0.361,0.165}, label = "🌳 HARD",   bg = {0.996,0.918,0.886} },
    expert = { main = {0.545,0.435,0.667}, label = "🦅 EXPERT", bg = {0.941,0.925,0.965} },
}

-- ─── Helpers ─────────────────────────────────────────────

-- Draw a filled rounded rectangle (Solar 2D lacks built-in fill+stroke in one call)
function M.roundRect(parent, x, y, w, h, r, fill, stroke, strokeW)
    local rect = display.newRoundedRect(parent, x, y, w, h, r or 12)
    if fill then rect:setFillColor(unpack(fill)) end
    if stroke then
        rect.strokeWidth = strokeW or 1.5
        rect:setStrokeColor(unpack(stroke))
    end
    return rect
end

-- Simple text helper (anchored centre by default)
function M.text(parent, str, x, y, size, font, col)
    local t = display.newText({
        parent = parent, text = str,
        x = x, y = y,
        fontSize = size,
        font = font or native.systemFont,
    })
    if col then t:setTextColor(unpack(col)) end
    return t
end

-- Invisible tap rect (full-area touch capture)
function M.tapRect(parent, x, y, w, h, fn)
    local r = display.newRect(parent, x, y, w, h)
    r.alpha = 0
    r.isHitTestable = true
    r:addEventListener("tap", fn)
    return r
end

-- Flash a card bg, then run callback
function M.flashTap(bg, cb)
    transition.to(bg, { time = 70, alpha = 0.45, onComplete = function()
        transition.to(bg, { time = 70, alpha = 1.0, onComplete = cb })
    end})
end

return M
