-- scene/menu.lua
-- Main menu: category selection, daily challenge, stats

local composer  = require("composer")
local scene     = composer.newScene()
local wordbank  = require("modules.wordbank")
local savedata  = require("modules.savedata")
local P         = require("modules.palette")

local W = display.contentWidth
local H = display.contentHeight

local function spawnDecor(parent)
    local shapes = { "❀", "❧", "✿", "❁", "🍃", "❂" }
    local colors = { P.mint, P.rose, P.amber, P.skyBlue, P.sageLt }
    local sym   = shapes[math.random(#shapes)]
    local col   = colors[math.random(#colors)]
    local size  = math.random(20, 34)
    local x     = math.random(32, W - 32)
    local deco  = display.newText({
        parent = parent,
        text = sym,
        x = x,
        y = H + size,
        fontSize = size,
        font = native.systemFontBold,
    })
    deco:setFillColor(col[1], col[2], col[3], 0.82)
    deco.alpha = 0.88

    transition.to(deco, {
        time = math.random(3600, 5600),
        y = -size,
        x = x + math.random(-32, 32),
        rotation = math.random(-90, 90),
        alpha = 0,
        onComplete = function() display.remove(deco) end,
    })
end

local function rotateLogoRing(ring)
    transition.to(ring, {
        time = 18000,
        rotation = ring.rotation + 360,
        onComplete = function()
            ring.rotation = ring.rotation % 360
            rotateLogoRing(ring)
        end,
    })
end

-- ─── Category card ───────────────────────────────────────
local function makeCard(parent, cat, x, y, cw, ch, isLocked)
    local g = display.newGroup()
    parent:insert(g)
    g.x = x; g.y = y

    -- Background
    local fillCol = isLocked
        and P.parchment
        or  { cat.color[1]*0.22 + P.cream[1]*0.78,
              cat.color[2]*0.22 + P.cream[2]*0.78,
              cat.color[3]*0.22 + P.cream[3]*0.78 }
    local strokeCol = isLocked
        and { P.warmTan[1], P.warmTan[2], P.warmTan[3], 0.6 }
        or  { cat.color[1], cat.color[2], cat.color[3], 0.65 }

    local bg = display.newRoundedRect(g, 0, 0, cw, ch, 14)
    bg:setFillColor(unpack(fillCol))
    bg.strokeWidth = isLocked and 1 or 2
    bg:setStrokeColor(unpack(strokeCol))

    -- Icon
    P.text(g, isLocked and "🔒" or cat.icon, 0, -ch*0.22, 28)

    -- Name
    local nameCol = isLocked and P.bark or cat.accentColor
    local nameT = P.text(g, isLocked and "LOCKED" or cat.name,
                         0, ch*0.08, 12, native.systemFontBold, nameCol)

    -- Unlock hint
    if isLocked then
        P.text(g, "play more to unlock", 0, ch*0.3, 9, native.systemFont, P.bark)
    end

    if not isLocked then
        P.tapRect(g, 0, 0, cw, ch, function()
            P.flashTap(bg, function()
                composer.gotoScene("scene.difficulty", {
                    effect = "slideLeft", time = 340,
                    params = { categoryId = cat.id }
                })
            end)
        end)
    end

    return g
end

-- ─── Scene ───────────────────────────────────────────────
function scene:create(event)
    local sg = self.view
    savedata.load()

    -- Warm cream background
    local bg = display.newRect(sg, W/2, H/2, W, H)
    bg:setFillColor(unpack(P.cream))

    local bgGlowGroup = display.newGroup()
    sg:insert(bgGlowGroup)
    local glow1 = display.newCircle(bgGlowGroup, W*0.28, H*0.18, 140)
    glow1:setFillColor(P.mint[1], P.mint[2], P.mint[3], 0.16)
    local glow2 = display.newCircle(bgGlowGroup, W*0.72, H*0.14, 92)
    glow2:setFillColor(P.rose[1], P.rose[2], P.rose[3], 0.12)
    local glow3 = display.newCircle(bgGlowGroup, W*0.55, H*0.32, 72)
    glow3:setFillColor(P.skyBlue[1], P.skyBlue[2], P.skyBlue[3], 0.10)

    local bubbleGroup = display.newGroup()
    sg:insert(bubbleGroup)
    self._bubbleGroup = bubbleGroup
    for i = 1, 10 do spawnDecor(self._bubbleGroup) end

    -- Decorative scattered dots
    for r = 0, 10 do
        for c = 0, 6 do
            local dot = display.newCircle(sg, c*(W/6), r*(H/10), 1.2)
            dot:setFillColor(P.bark[1], P.bark[2], P.bark[3], 0.12)
        end
    end

    -- Logo
    local logo = P.text(sg, "🌿", W/2, 44, 38)
    local title = P.text(sg, "WORD FOREST", W/2, 82, 22,
                          native.systemFontBold, P.ink)
    local sub   = P.text(sg, "find · discover · grow", W/2, 105, 11,
                          native.systemFont, P.ink)

    -- ─── Daily Challenge ─────────────────────────────────
    local streak, doneToday = savedata.checkDailyStreak()

    local dailyBg = display.newRoundedRect(sg, W/2, 155, W-36, 54, 13)
    if doneToday then
        dailyBg:setFillColor(P.parchment[1], P.parchment[2], P.parchment[3])
        dailyBg.strokeWidth = 1
        dailyBg:setStrokeColor(P.warmTan[1], P.warmTan[2], P.warmTan[3], 0.8)
    else
        dailyBg:setFillColor(
            P.mint[1]*0.58 + P.cream[1]*0.42,
            P.mint[2]*0.58 + P.cream[2]*0.42,
            P.mint[3]*0.58 + P.cream[3]*0.42)
        dailyBg.strokeWidth = 2
        dailyBg:setStrokeColor(P.mint[1], P.mint[2], P.mint[3], 0.75)
    end

    P.text(sg, "📅", 36, 152, 22)

    local dailyTitle = P.text(sg,
        doneToday and "DAILY CHALLENGE  ✓" or "DAILY CHALLENGE",
        W/2 + 12, 143, 13, native.systemFontBold,
        doneToday and P.bark or P.rust)

    P.text(sg, "🔥 " .. streak .. " day streak  ·  new puzzle every day",
           W/2 + 12, 163, 11, native.systemFontBold, P.ink)

    if not doneToday then
        P.tapRect(sg, W/2, 155, W-36, 54, function()
            P.flashTap(dailyBg, function()
                composer.gotoScene("scene.game", {
                    effect = "slideLeft", time = 350,
                    params = { mode = "daily" }
                })
            end)
        end)
    end

    -- ─── Category grid ───────────────────────────────────
    P.text(sg, "CHOOSE A WORLD", W/2, 208, 12,
           native.systemFontBold, P.ink)

    local unlocked = savedata.get("unlockedCategories") or { nature = true }
    local cats     = wordbank.categories
    local cols     = 2
    local cw       = (W - 46) / cols
    local ch       = 102
    local startY   = 238
    local gapX, gapY = 10, 10

    for i, cat in ipairs(cats) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        local cx  = 20 + cw/2 + col*(cw + gapX)
        local cy  = startY + ch/2 + row*(ch + gapY)
        makeCard(sg, cat, cx, cy, cw, ch, not unlocked[cat.id])
    end

    -- ─── How to play / About ─────────────────────────────
    local infoY = H - 155
    local infoBg = display.newRoundedRect(sg, W/2, infoY, W-19, 160, 22)
    infoBg:setFillColor(P.paper[1], P.paper[2], P.paper[3], 0.98)
    infoBg.strokeWidth = 1.4
    infoBg:setStrokeColor(P.ink[1], P.ink[2], P.ink[3], 0.12)

    local leftX = 36
    local columnWidth = (W - 112) * 0.5
    local rightX = leftX + columnWidth + 28
    local topRow = infoY - 48

    local titleLeft = display.newText({
        parent = sg,
        text = "How to play",
        x = leftX,
        y = topRow,
        font = native.systemFontBold,
        fontSize = 14,
        width = columnWidth,
        align = "left",
    })
    titleLeft:setFillColor(P.ink[1], P.ink[2], P.ink[3])
    titleLeft.anchorX = 0
    titleLeft.anchorY = 0

    local titleRight = display.newText({
        parent = sg,
        text = "About",
        x = rightX,
        y = topRow,
        font = native.systemFontBold,
        fontSize = 13,
        width = columnWidth,
        align = "left",
    })
    titleRight:setFillColor(P.ink[1], P.ink[2], P.ink[3])
    titleRight.anchorX = 0
    titleRight.anchorY = 0

    local helpText = {
        "• Choose a category and difficulty.",
        "• Drag across letters to select a word.",
        "• Words may appear in all directions.",
    }
    local currentHelpY = topRow + 22
    for _, line in ipairs(helpText) do
        local lineText = display.newText({
            parent = sg,
            text = line,
            x = leftX,
            y = currentHelpY,
            font = native.systemFont,
            fontSize = 11,
            width = columnWidth,
            align = "left",
        })
        lineText:setFillColor(P.ink[1], P.ink[2], P.ink[3])
        lineText.anchorX = 0
        lineText.anchorY = 0
        currentHelpY = currentHelpY + lineText.contentHeight + 8
    end

    local aboutLines = {
        "A calm word-search game with daily puzzles.",
        "Use hints when you want an extra boost.",
    }
    local currentAboutY = topRow + 22
    for _, line in ipairs(aboutLines) do
        local lineText = display.newText({
            parent = sg,
            text = line,
            x = rightX,
            y = currentAboutY,
            font = native.systemFont,
            fontSize = 11,
            width = columnWidth,
            align = "left",
        })
        lineText:setFillColor(P.bark[1], P.bark[2], P.bark[3])
        lineText.anchorX = 0
        lineText.anchorY = 0
        currentAboutY = currentAboutY + lineText.contentHeight + 8
    end

    local footer = display.newText({
        parent = sg,
        text = "Tap a category to start exploring the forest!",
        x = W/2,
        y = infoY + 70,
        font = native.systemFont,
        fontSize = 10,
        width = W-60,
        align = "center",
    })
    footer:setFillColor(P.ink[1], P.ink[2], P.ink[3], 0.76)

    -- ─── Stats bar ───────────────────────────────────────
    local statsBg = display.newRect(sg, W/2, H - 38, W, 76)
    statsBg:setFillColor(P.paper[1], P.paper[2], P.paper[3])
    -- top border
    local border = display.newRect(sg, W/2, H - 76, W, 2)
    border:setFillColor(P.ink[1], P.ink[2], P.ink[3], 0.22)

    local totalWords = savedata.get("totalWordsFound") or 0
    local hints      = savedata.getHintsAvailable()
    local games      = savedata.get("gamesCompleted") or 0

    local statItems = {
        { val = totalWords, lbl = "words" },
        { val = games,      lbl = "games" },
        { val = hints,      lbl = "hints" },
    }
    local sw = W / #statItems
    for i, s in ipairs(statItems) do
        local sx = (i-1)*sw + sw/2
        P.text(sg, tostring(s.val), sx, H - 48, 20, native.systemFontBold, P.ink)
        P.text(sg, s.lbl, sx, H - 28, 10, native.systemFontBold, P.ink)
    end
end

function scene:show(event)
    if event.phase == "did" then
        if not self._bubbleTimer and self._bubbleGroup then
            self._bubbleTimer = timer.performWithDelay(900, function()
                spawnDecor(self._bubbleGroup)
            end, 0)
        end
    end
end

function scene:hide(event)
    if event.phase == "will" then
        if self._bubbleTimer then
            timer.cancel(self._bubbleTimer)
            self._bubbleTimer = nil
        end
    end
end

function scene:destroy(event)
    if self._bubbleTimer then
        timer.cancel(self._bubbleTimer)
        self._bubbleTimer = nil
    end
    if self._bubbleGroup then
        display.remove(self._bubbleGroup)
        self._bubbleGroup = nil
    end
end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)
return scene
