-- scene/difficulty.lua
-- Difficulty picker: Easy · Medium · Hard · Expert

local composer = require("composer")
local scene    = composer.newScene()
local wordbank = require("modules.wordbank")
local P        = require("modules.palette")

local W = display.contentWidth
local H = display.contentHeight

-- ─── Difficulty definitions ───────────────────────────────
-- gridSize used by game.lua; timerSecs = nil → no timer
local DIFFICULTIES = {
    {
        id       = "easy",
        label    = "EASY",
        desc     = "10×10 grid  ·  6 words  ·  no timer",
        badge    = "Relaxed 🌱",
        icon     = "🌱",
        gridSize = 10,
        timerSecs= nil,
        fillCol  = { 0.910, 0.957, 0.886 },
        strokeCol= { P.sageDk[1], P.sageDk[2], P.sageDk[3], 0.6 },
        textCol  = P.sageDk,
    },
    {
        id       = "medium",
        label    = "MEDIUM",
        desc     = "12×12 grid  ·  9 words  ·  5 min timer",
        badge    = "Breezy 🍃",
        icon     = "🌿",
        gridSize = 12,
        timerSecs= 300,
        fillCol  = { 0.996, 0.957, 0.898 },
        strokeCol= { P.amber[1], P.amber[2], P.amber[3], 0.6 },
        textCol  = P.amber,
    },
    {
        id       = "hard",
        label    = "HARD",
        desc     = "14×14 grid  ·  12 words  ·  3 min timer",
        badge    = "Challenge 🔥",
        icon     = "🌳",
        gridSize = 14,
        timerSecs= 180,
        fillCol  = { 0.996, 0.929, 0.898 },
        strokeCol= { P.rust[1], P.rust[2], P.rust[3], 0.6 },
        textCol  = P.rust,
    },
    {
        id       = "expert",
        label    = "EXPERT",
        desc     = "16×16 grid  ·  16 words  ·  2 min timer",
        badge    = "Legend 🦅",
        icon     = "🦅",
        gridSize = 16,
        timerSecs= 120,
        fillCol  = { 0.941, 0.925, 0.965 },
        strokeCol= { P.dusk[1], P.dusk[2], P.dusk[3], 0.6 },
        textCol  = P.dusk,
    },
}

-- ─── Scene ───────────────────────────────────────────────
function scene:create(event)
    local sg     = self.view
    local params = event.params or {}
    local catId  = params.categoryId or "nature"

    -- Find category
    local cat = wordbank.categories[1]
    for _, c in ipairs(wordbank.categories) do
        if c.id == catId then cat = c; break end
    end

    -- Background tinted to category
    local bg = display.newRect(sg, W/2, H/2, W, H)
    bg:setFillColor(unpack(cat.bgColor))

    -- Back button
    local backT = P.text(sg, "← back", 44, 38, 13,
                          native.systemFontBold, P.ink)
    backT:addEventListener("tap", function()
        composer.gotoScene("scene.menu", { effect="slideRight", time=300 })
    end)

    -- Header
    P.text(sg, cat.icon, W/2, 82,  44)
    P.text(sg, cat.name, W/2, 130, 24, native.systemFontBold, P.ink)
    P.text(sg, "choose difficulty", W/2, 155, 12,
           native.systemFontBold, P.ink)

    -- ─── Cards ───────────────────────────────────────────
    local cardW  = W - 52
    local cardH  = 82
    local startY = 200
    local gap    = 12

    for i, diff in ipairs(DIFFICULTIES) do
        local cy = startY + (i-1)*(cardH + gap) + cardH/2

        local cardBg = display.newRoundedRect(sg, W/2, cy, cardW, cardH, 14)
        cardBg:setFillColor(unpack(diff.fillCol))
        cardBg.strokeWidth = 1.8
        cardBg:setStrokeColor(unpack(diff.strokeCol))

        -- Left icon
        P.text(sg, diff.icon, 44, cy - 8, 26)

        -- Label
        P.text(sg, diff.label, W/2 + 14, cy - 14, 15,
               native.systemFontBold, diff.textCol)

        -- Description
        P.text(sg, diff.desc, W/2 + 14, cy + 8, 11,
               native.systemFontBold, P.ink)

        -- Badge (top-right)
        local badgeBg = display.newRoundedRect(sg,
            W - 30, cy - cardH/2 + 14, 80, 18, 9)
        badgeBg:setFillColor(diff.textCol[1], diff.textCol[2], diff.textCol[3], 0.12)
        P.text(sg, diff.badge, W - 30, cy - cardH/2 + 14, 9,
               native.systemFont, diff.textCol)

        -- Touch
        local id   = diff.id
        local gsz  = diff.gridSize
        P.tapRect(sg, W/2, cy, cardW, cardH, function()
            P.flashTap(cardBg, function()
                composer.gotoScene("scene.game", {
                    effect = "slideLeft", time = 380,
                    params = {
                        categoryId = catId,
                        difficulty = id,
                        gridSize   = gsz,
                    }
                })
            end)
        end)
    end
end

function scene:show(event) end
function scene:hide(event) end
function scene:destroy(event) end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)
return scene
