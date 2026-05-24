-- scene/result.lua
-- Post-game summary: score, time, words found, achievements

local composer = require("composer")
local scene    = composer.newScene()
local savedata = require("modules.savedata")
local wordbank = require("modules.wordbank")
local P        = require("modules.palette")

local W = display.contentWidth
local H = display.contentHeight

local function formatTime(secs)
    return string.format("%d:%02d", math.floor(secs/60), secs%60)
end

-- Animated count-up
local function countUp(textObj, target, duration)
    local steps = 22
    local delay = duration / steps
    for i = 1, steps do
        timer.performWithDelay(i * delay, function()
            textObj.text = tostring(math.floor(target * i / steps))
        end)
    end
end

-- Warm confetti burst
local function launchConfetti(parent, cat)
    local cols = {
        cat.color, cat.accentColor,
        P.amber, P.amberLt, P.sageLt, P.sand
    }
    for _ = 1, 32 do
        local col  = cols[math.random(#cols)]
        local x    = math.random(W*0.08, W*0.92)
        local sz   = math.random(5, 11)
        local piece= display.newRect(parent, x, -8, sz, sz)
        piece:setFillColor(col[1], col[2], col[3])
        piece.rotation = math.random(360)
        transition.to(piece, {
            time  = math.random(1300, 2400),
            y     = H + 16,
            x     = piece.x + math.random(-90, 90),
            rotation = piece.rotation + math.random(-360,360),
            alpha = 0,
            delay = math.random(0, 700),
            onComplete = function() display.remove(piece) end,
        })
    end
end

-- ─── Scene ───────────────────────────────────────────────
function scene:create(event)
    local sg     = self.view
    local params = event.params or {}
    savedata.load()

    local score      = params.score      or 0
    local wordsFound = params.wordsFound or 0
    local elapsed    = params.elapsed    or 0
    local catId      = params.categoryId or "nature"
    local difficulty = params.difficulty or "easy"
    local timeout    = params.timeout    or false

    local cat = wordbank.categories[1]
    for _, c in ipairs(wordbank.categories) do
        if c.id == catId then cat=c; break end
    end

    -- Background
    local bg = display.newRect(sg, W/2, H/2, W, H)
    bg:setFillColor(unpack(cat.bgColor))

    -- Confetti
    local confettiG = display.newGroup(); sg:insert(confettiG)
    if not timeout then
        timer.performWithDelay(350, function() launchConfetti(confettiG, cat) end)
    end

    -- ── Header ───────────────────────────────────────
    local titleStr = timeout and "TIME'S UP" or "WELL DONE!"
    local titleCol = timeout and P.rust or cat.accentColor

    local resultTitle = P.text(sg, titleStr, W/2, 72, 28,
                                native.systemFontBold, titleCol)
    resultTitle.alpha = 0
    transition.to(resultTitle, { time=500, alpha=1.0, delay=180 })

    -- Badge
    local badge = display.newRoundedRect(sg, W/2, 112, 170, 30, 12)
    badge:setFillColor(cat.color[1]*0.14 + P.cream[1]*0.86,
                       cat.color[2]*0.14 + P.cream[2]*0.86,
                       cat.color[3]*0.14 + P.cream[3]*0.86)
    badge.strokeWidth = 1
    badge:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.55)
    P.text(sg, cat.icon.."  "..cat.name.."  ·  "..string.upper(difficulty),
            W/2, 112, 11, native.systemFontBold, cat.accentColor)

    -- ── Score card ───────────────────────────────────
    local scoreBg = display.newRoundedRect(sg, W/2, 192, W-36, 86, 16)
    scoreBg:setFillColor(P.parchment[1],P.parchment[2],P.parchment[3])
    scoreBg.strokeWidth = 1.5
    scoreBg:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.38)

    P.text(sg, "SCORE", W/2, 160, 11, native.systemFontBold, P.ink)
    local scoreNum = P.text(sg, "0", W/2, 196, 36, native.systemFontBold, P.ink)
    timer.performWithDelay(580, function() countUp(scoreNum, score, 820) end)

    -- ── Stat tiles ───────────────────────────────────
    local statsY = 272
    local statItems = {
        { label="WORDS", value=tostring(wordsFound) },
        { label="TIME",  value=formatTime(elapsed)  },
    }

    -- Best time badge
    local key = catId.."_"..difficulty
    local bests = savedata.get("bestTimes") or {}
    if bests[key] and bests[key] == elapsed then
        statItems[#statItems+1] = { label="BEST!", value="⭐" }
    end

    local statW = (W - 52) / #statItems
    for i, s in ipairs(statItems) do
        local sx = 26 + statW/2 + (i-1)*statW
        local sBg = display.newRoundedRect(sg, sx, statsY, statW-8, 60, 10)
        sBg:setFillColor(P.parchment[1],P.parchment[2],P.parchment[3])
        sBg.strokeWidth = 1
        sBg:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.22)

        P.text(sg, s.label, sx, statsY-13, 10, native.systemFontBold, P.ink)
        P.text(sg, s.value, sx, statsY+8,  20, native.systemFontBold, P.ink)
    end

    -- ── Achievements ─────────────────────────────────
    local achieveY   = 322
    local achieveMap = {
        wordsmith  = "🏆 Wordsmith — 100 words found",
        explorer   = "🌍 Explorer — 10 games played",
        treemaster = "🦅 Tree Master — beat Expert!",
    }
    local achievs = savedata.get("achievements") or {}
    for aKey, aLabel in pairs(achieveMap) do
        if achievs[aKey] then
            local aT = P.text(sg, aLabel, W/2, achieveY, 11,
                               native.systemFont, P.gold)
            achieveY = achieveY + 22
        end
    end

    -- ── Difficulty-specific unlock note ──────────────
    if difficulty == "expert" and not timeout then
        P.text(sg, "🦅 Expert cleared! +2 hints earned.", W/2, achieveY+8, 11,
               native.systemFont, P.dusk)
        achieveY = achieveY + 28
    end

    -- ── Buttons ──────────────────────────────────────
    local btnY = H - 100

    -- Play Again
    local playBg = display.newRoundedRect(sg, W/2, btnY, W-36, 48, 14)
    playBg:setFillColor(cat.color[1]*0.28 + P.cream[1]*0.72,
                        cat.color[2]*0.28 + P.cream[2]*0.72,
                        cat.color[3]*0.28 + P.cream[3]*0.72)
    playBg.strokeWidth = 2
    playBg:setStrokeColor(cat.accentColor[1],cat.accentColor[2],cat.accentColor[3], 0.75)

    P.text(sg, "PLAY AGAIN", W/2, btnY, 15,
            native.systemFontBold, cat.accentColor)

    P.tapRect(sg, W/2, btnY, W-36, 48, function()
        P.flashTap(playBg, function()
            composer.gotoScene("scene.difficulty", {
                effect="slideLeft", time=300,
                params = { categoryId = catId }
            })
        end)
    end)

    -- Main menu
    local menuT = P.text(sg, "← Main Menu", W/2, H-48, 14,
                           native.systemFontBold, P.ink)
    menuT:addEventListener("tap", function()
        composer.gotoScene("scene.menu", { effect="slideRight", time=300 })
    end)
end

function scene:show(event) end
function scene:hide(event) end
function scene:destroy(event) end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)
return scene
