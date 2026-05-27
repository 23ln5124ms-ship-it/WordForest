-- scene/game.lua
-- Core gameplay: grid rendering, touch selection, animations
--
-- Features:
--   1. Path Trail    — capsule highlight while dragging
--   2. Word Bloom    — letters pop when a word is found
--   3. Hint Ripple   — ripple from first unfound letter
--   4. Speed Bonus   — extra score for fast finds
--   5. Expert mode   — 16×16 grid, 2-min timer, 16 words

local composer  = require("composer")
local scene     = composer.newScene()
local wordbank  = require("modules.wordbank")
local gridgen   = require("modules.gridgen")
local savedata  = require("modules.savedata")
local P         = require("modules.palette")

local W = display.contentWidth
local H = display.contentHeight
local ACTW = display.actualContentWidth
local ACTH = display.actualContentHeight
local ORX = display.screenOriginX
local ORY = display.screenOriginY
local CX = ORX + ACTW * 0.5
math.randomseed(os.time())

-- ─── Layout constants ─────────────────────────────────────
local HEADER_H    = 124
local WORD_LIST_H = 108
local PADDING     = 6

-- ─── Grid sizes per difficulty ────────────────────────────
local GRID_SIZES = { easy=10, medium=12, hard=14, expert=16 }
local TIMER_SECS = { easy=nil, medium=300, hard=180, expert=120 }

-- ─── State ───────────────────────────────────────────────
local state = {}
local timerText = nil
local timerPanel = nil

local function resetState()
    state = {
        grid=nil, wordData=nil, placedWords=nil,
        cells={}, cellSize=0, gridOffX=0, gridOffY=0, gridSize=10,
        selecting=false, selStart=nil, selCells={},
        trailGroup=nil,
        wordsFound=0, totalWords=0,
        score=0, startTime=os.time(), lastWordTime=os.time(),
        timerLimit=nil, timerRemaining=0, timerRunning=false,
        paused=false, categoryData=nil, hintsUsed=0,
        isDailyMode=false, difficulty="easy",
        combo=0, bestCombo=0,
        _foundTxt=nil,
    }
    timerText = nil
    timerPanel = nil
end

-- ─── Coord helpers ───────────────────────────────────────
local function cellToXY(r, c)
    return state.gridOffX + (c-0.5)*state.cellSize,
           state.gridOffY + (r-0.5)*state.cellSize
end

local function xyToCell(px, py)
    local c = math.floor((px - state.gridOffX) / state.cellSize) + 1
    local r = math.floor((py - state.gridOffY) / state.cellSize) + 1
    return r, c
end

local function inGrid(r, c)
    return r>=1 and r<=state.gridSize and c>=1 and c<=state.gridSize
end

-- ─── 8-direction snap ───────────────────────────────────
local function snapSelection(r1, c1, r2, c2)
    local dr = r2-r1; local dc = c2-c1
    local ax = math.abs(dc); local ay = math.abs(dr)
    local len
    if ax > ay*2 then
        len=ax; dr=0; dc=dc>0 and 1 or -1
    elseif ay > ax*2 then
        len=ay; dc=0; dr=dr>0 and 1 or -1
    else
        len=math.max(ax,ay)
        dr=dr>0 and 1 or -1
        dc=dc>0 and 1 or -1
    end
    local cells={}
    for i=0, len do
        local nr=r1+i*dr; local nc=c1+i*dc
        if inGrid(nr,nc) then cells[#cells+1]={nr,nc} end
    end
    return cells
end

-- ─── Trail ───────────────────────────────────────────────
local function drawTrail(gameGroup, selCells, cat)
    if state.trailGroup then display.remove(state.trailGroup); state.trailGroup=nil end
    if #selCells < 1 then return end

    local tg = display.newGroup()
    gameGroup:insert(tg)
    state.trailGroup = tg

    -- Line under circles
    if #selCells > 1 then
        for i = 1, #selCells-1 do
            local x1,y1 = cellToXY(selCells[i][1],   selCells[i][2])
            local x2,y2 = cellToXY(selCells[i+1][1], selCells[i+1][2])
            local line = display.newLine(tg, x1,y1, x2,y2)
            line.strokeWidth = state.cellSize * 0.86
            line:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.20)
        end
    end

    for _, cell in ipairs(selCells) do
        local x,y = cellToXY(cell[1], cell[2])
        local dot = display.newCircle(tg, x, y, state.cellSize*0.43)
        dot:setFillColor(cat.color[1],cat.color[2],cat.color[3], 0.28)
        dot.strokeWidth = 1.5
        dot:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.65)

        if state.cells[cell[1]] and state.cells[cell[1]][cell[2]] then
            state.cells[cell[1]][cell[2]].text:setTextColor(
                cat.accentColor[1], cat.accentColor[2], cat.accentColor[3])
        end
    end
end

-- ─── Word Bloom animation ────────────────────────────────
local function wordBloom(positions, cat)
    for i, pos in ipairs(positions) do
        local r,c = pos[1], pos[2]
        if state.cells[r] and state.cells[r][c] then
            local co = state.cells[r][c]
            timer.performWithDelay((i-1)*38, function()
                transition.to(co.bg, { time=115, xScale=1.28, yScale=1.28, onComplete=function()
                    transition.to(co.bg, { time=190, xScale=1.0, yScale=1.0 })
                end})
                co.bg:setFillColor(
                    cat.color[1]*0.35 + P.cream[1]*0.65,
                    cat.color[2]*0.35 + P.cream[2]*0.65,
                    cat.color[3]*0.35 + P.cream[3]*0.65)
                co.text:setTextColor(
                    cat.accentColor[1], cat.accentColor[2], cat.accentColor[3])
            end)
        end
    end
end

-- ─── Build word list ─────────────────────────────────────
local function buildWordList(parent, words, cat, startY)
    local container = display.newGroup()
    parent:insert(container)

    local cols  = (#words <= 6) and 2 or 3
    local colW  = (ACTW - 16) / cols
    local rowH  = 20
    local padX  = 8

    for i, word in ipairs(words) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        local x   = padX + colW/2 + col*colW
        local y   = startY + row*rowH + rowH/2

        local wObj = display.newText({
            parent = container,
            text   = "· " .. word,
            x=x, y=y, fontSize=10,
            font = native.systemFont,
        })
        wObj:setTextColor(cat.accentColor[1], cat.accentColor[2], cat.accentColor[3])

        if state.wordData[word] then
            state.wordData[word].displayObj = wObj
        end
    end
    return container
end

-- ─── Timer display ─────────────────────────────────────
local function updateTimerDisplay()
    if not timerText then return end
    local secs = math.max(0, math.floor(state.timerRemaining))
    local m = math.floor(secs/60)
    local s = secs % 60
    timerText.text = string.format("%d:%02d", m, s)
    if secs <= 20 then
        timerText:setTextColor(P.rust[1],  P.rust[2],  P.rust[3])
    elseif secs <= 60 then
        timerText:setTextColor(P.amber[1], P.amber[2], P.amber[3])
    else
        timerText:setTextColor(P.sageDk[1],P.sageDk[2],P.sageDk[3])
    end
end

-- ─── Hint Ripple ─────────────────────────────────────────
local function useHint(gameGroup, cat)
    if not savedata.useHint() then
        local msg = P.text(gameGroup, "No hints left!", W/2, H/2-40, 15,
                            native.systemFontBold, P.rust)
        transition.to(msg, { time=1200, alpha=0, y=msg.y-38,
            onComplete=function() display.remove(msg) end })
        return
    end

    local target = nil
    for _, w in ipairs(state.placedWords) do
        if state.wordData[w] and not state.wordData[w].found then
            target=w; break
        end
    end
    if not target then return end

    local wd   = state.wordData[target]
    local fp   = wd.positions[1]
    local x, y = cellToXY(fp[1], fp[2])

    for ring = 1, 3 do
        timer.performWithDelay(ring*110, function()
            local ripple = display.newCircle(gameGroup, x, y, state.cellSize*0.5)
            ripple:setFillColor(0,0,0,0)
            ripple.strokeWidth = 2
            ripple:setStrokeColor(cat.color[1],cat.color[2],cat.color[3], 0.85)
            transition.to(ripple, {
                time=620, xScale=3.0, yScale=3.0, alpha=0,
                onComplete=function() display.remove(ripple) end
            })
        end)
    end

    if state.cells[fp[1]] and state.cells[fp[1]][fp[2]] then
        local co = state.cells[fp[1]][fp[2]]
        transition.to(co.bg, { time=200, alpha=0.8, onComplete=function()
            transition.to(co.bg, { time=700, alpha=0.08 })
        end})
        co.text:setTextColor(P.gold[1], P.gold[2], P.gold[3])
        timer.performWithDelay(900, function()
            co.text:setTextColor(cat.accentColor[1],cat.accentColor[2],cat.accentColor[3])
        end)
    end
    state.hintsUsed = state.hintsUsed + 1
end

-- ─── Score ───────────────────────────────────────────────
local function calcScore(word, dt)
    local base = #word * 100
    local bonus = 0
    if     dt < 4  then bonus = base * 0.6
    elseif dt < 10 then bonus = base * 0.3
    end
    return math.floor(base+bonus), bonus>0
end

-- ─── Check selection ─────────────────────────────────────
local function checkSelection(gameGroup, cat, scoreDisplay, hud)
    if #state.selCells < 2 then return end

    local word = ""
    for _, pos in ipairs(state.selCells) do
        word = word .. state.grid[pos[1]][pos[2]]
    end
    local rev = word:reverse()

    local matched, matchedWord = nil, nil
    for _, w in ipairs(state.placedWords) do
        if (word==w or rev==w) and state.wordData[w] and not state.wordData[w].found then
            matched=state.wordData[w]; matchedWord=w; break
        end
    end
    if not matched then return end

    matched.found = true
    state.wordsFound = state.wordsFound + 1
    wordBloom(matched.positions, cat)

    local now = os.time()
    local pts, hasBonus = calcScore(matchedWord, now - state.lastWordTime)
    state.lastWordTime = now
    if hasBonus then
        state.combo = state.combo + 1
    else
        state.combo = 0
    end
    state.bestCombo = math.max(state.bestCombo, state.combo)

    local streakBonus = 0
    if state.combo >= 3 then
        streakBonus = 100
        state.score = state.score + streakBonus
    end
    state.score = state.score + pts

    if matched.displayObj then
        matched.displayObj.text = "✓ " .. matchedWord
        matched.displayObj:setTextColor(
            cat.accentColor[1]*0.7, cat.accentColor[2]*0.7, cat.accentColor[3]*0.7)
    end

    -- Score popup
    local popStr = "+" .. pts
    local popCol = P.moss
    if hasBonus then
        popStr = popStr .. " ⚡"
        popCol = P.amber
    end
    if streakBonus > 0 then
        popStr = popStr .. " +" .. streakBonus .. " 🌱"
    end
    local popup = P.text(gameGroup, popStr, CX, ORY + ACTH*0.5 - 28, hasBonus and 20 or 16,
                          native.systemFontBold,
                          popCol)
    transition.to(popup, { time=1050, y=popup.y-58, alpha=0,
        onComplete=function() display.remove(popup) end })

    if scoreDisplay then scoreDisplay.text = tostring(state.score) end
    if hud and hud.comboText then
        hud.comboText.text = state.combo > 1 and "STREAK: "..state.combo or "streak: 0"
        hud.comboText:setTextColor(state.combo > 1 and P.rust or P.leafGlow)
    end

    if state.wordsFound >= state.totalWords then
        timer.performWithDelay(650, function()
            local elapsed = os.time() - state.startTime
            savedata.recordGameComplete(
                state.categoryData.id, state.difficulty,
                elapsed, state.wordsFound)
            if state.isDailyMode then savedata.completeDailyChallenge() end
            composer.gotoScene("scene.result", {
                effect="crossFade", time=600,
                params={
                    score=state.score, wordsFound=state.wordsFound,
                    elapsed=elapsed, categoryId=state.categoryData.id,
                    difficulty=state.difficulty,
                }
            })
        end)
    end
end

-- ─── Build grid ──────────────────────────────────────────
local function buildGrid(parent, cat)
    local sz    = state.gridSize
    local availW = ACTW - PADDING*2
    local availH = ACTH - HEADER_H - WORD_LIST_H - PADDING*2
    local cellSz = math.min(availW/sz, availH/sz)
    -- For expert (16×16) allow a smaller cell floor
    cellSz = math.max(cellSz, 14)
    state.cellSize = cellSz

    local totalW = sz * cellSz
    local totalH = sz * cellSz
    state.gridOffX = ORX + (ACTW - totalW) / 2
    state.gridOffY = ORY + HEADER_H + PADDING

    -- Grid background
    local gridBg = display.newRect(parent,
        state.gridOffX + totalW/2, state.gridOffY + totalH/2,
        totalW+6, totalH+6)
    gridBg:setFillColor(P.paper[1], P.paper[2], P.paper[3])
    gridBg.strokeWidth = 2
    gridBg:setStrokeColor(P.ink[1], P.ink[2], P.ink[3], 0.22)

    local gridGlow = display.newCircle(parent,
        state.gridOffX + totalW/2, state.gridOffY + totalH/2,
        totalW * 0.52)
    gridGlow:setFillColor(cat.color[1], cat.color[2], cat.color[3], 0.12)
    gridGlow.blendMode = "add"

    local fontSize = math.max(8, math.floor(cellSz * 0.46))

    for r = 1, sz do
        state.cells[r] = {}
        for c = 1, sz do
            local x,y = cellToXY(r, c)
            local cg = display.newGroup()
            parent:insert(cg)
            cg.x=x; cg.y=y

            local bg = display.newRect(cg, 0,0, cellSz-1, cellSz-1)
            bg:setFillColor(P.paper[1], P.paper[2], P.paper[3], 0.35)
            bg.strokeWidth = 0.7
            bg:setStrokeColor(P.ink[1], P.ink[2], P.ink[3], 0.35)

            local letter = display.newText({
                parent=cg, text=state.grid[r][c],
                x=0, y=0, fontSize=fontSize,
                font=native.systemFontBold,
            })
            letter:setTextColor(P.ink[1], P.ink[2], P.ink[3])

            state.cells[r][c] = { bg=bg, text=letter }
        end
    end
end

-- ─── Touch handler ───────────────────────────────────────
local function setupTouch(gameGroup, cat, scoreDisplay, hud)
    local overlay = display.newRect(gameGroup, CX, ORY + ACTH/2, ACTW, ACTH)
    overlay.alpha = 0
    overlay.isHitTestable = true

    local function resetNonFoundColor(selList)
        for _, pos in ipairs(selList) do
            local pr,pc = pos[1], pos[2]
            local isFound = false
            for _, w in ipairs(state.placedWords) do
                if state.wordData[w] and state.wordData[w].found then
                    for _, wp in ipairs(state.wordData[w].positions) do
                        if wp[1]==pr and wp[2]==pc then isFound=true; break end
                    end
                end
                if isFound then break end
            end
            if not isFound and state.cells[pr] and state.cells[pr][pc] then
                state.cells[pr][pc].text:setTextColor(P.ink[1],P.ink[2],P.ink[3])
            end
        end
    end

    overlay:addEventListener("touch", function(event)
        if state.paused then return true end
        local px,py = event.x, event.y
        local r,c   = xyToCell(px, py)

        if event.phase == "began" then
            if not inGrid(r,c) then return true end
            state.selecting=true; state.selStart={r,c}
            state.selCells={{r,c}}
            drawTrail(gameGroup, state.selCells, cat)

        elseif event.phase == "moved" then
            if not state.selecting or not state.selStart then return true end
            if not inGrid(r,c) then return true end
            resetNonFoundColor(state.selCells)
            state.selCells = snapSelection(
                state.selStart[1], state.selStart[2], r, c)
            drawTrail(gameGroup, state.selCells, cat)

        elseif event.phase == "ended" or event.phase == "cancelled" then
            if state.selecting then
                checkSelection(gameGroup, cat, scoreDisplay, hud)
                state.selecting = false
                if state.trailGroup then
                    display.remove(state.trailGroup); state.trailGroup=nil
                end
                resetNonFoundColor(state.selCells)
                state.selCells = {}
            end
        end
        return true
    end)
end

-- ─── Helpers to allow rebuilding when composer reuses scene ──
local function clearSceneView(sg)
    if not sg then return end
    for i = sg.numChildren, 1, -1 do
        local child = sg[i]
        if child then display.remove(child) end
    end
    if scene._timerHandle then timer.cancel(scene._timerHandle); scene._timerHandle = nil end
    if scene._foundTimer  then timer.cancel(scene._foundTimer);  scene._foundTimer  = nil end
    timerText = nil
    timerPanel = nil
end

local function initScene(self, event)
    local sg     = self.view
    local params = event.params or {}
    resetState()
    savedata.load()

    local catId     = params.categoryId or "nature"
    local difficulty= params.difficulty or "easy"
    local gridSize  = params.gridSize   or GRID_SIZES[difficulty] or 10
    state.isDailyMode = (params.mode == "daily")
    state.difficulty  = difficulty

    local cat = wordbank.categories[1]
    for _, c in ipairs(wordbank.categories) do
        if c.id == catId then cat=c; break end
    end
    state.categoryData = cat

    local words
    if state.isDailyMode then
        words     = wordbank.getDailyWords()
        gridSize  = 13
        difficulty= "medium"
    else
        words = wordbank.getWords(catId, difficulty)
    end
    state.gridSize = gridSize

    state.grid, state.wordData, state.placedWords =
        gridgen.generate(words, gridSize)
    state.totalWords = #state.placedWords
    state.startTime  = os.time()
    state.lastWordTime = os.time()

    -- Timer
    local tSecs = TIMER_SECS[difficulty]
    if tSecs then
        state.timerLimit     = tSecs
        state.timerRemaining = tSecs
        state.timerRunning   = true
    end

    -- ── Background ─────────────────────────────────────
    local bgRect = display.newRect(sg, CX, ORY + ACTH/2, ACTW, ACTH)
    bgRect:setFillColor(unpack(cat.bgColor))

    -- ── Header ─────────────────────────────────────────
    local headerBg = display.newRect(sg, CX, ORY + HEADER_H/2, ACTW, HEADER_H)
    headerBg:setFillColor(P.parchment[1],P.parchment[2],P.parchment[3])
    -- bottom border line
    local hBorder = display.newRect(sg, CX, ORY + HEADER_H, ACTW, 1)
    hBorder:setFillColor(P.warmTan[1],P.warmTan[2],P.warmTan[3])

    -- Back button
    local backT = P.text(sg, "✕", 24, 24, 18, native.systemFontBold, P.ink)
    backT:addEventListener("tap", function()
        composer.gotoScene("scene.menu", { effect="slideRight", time=300 })
    end)

    -- Category label
    local modeLabel = state.isDailyMode and "DAILY" or cat.name
    local modeT = P.text(sg, cat.icon.."  "..modeLabel, CX, ORY + 24, 14,
                          native.systemFontBold, P.ink)
    P.text(sg, string.upper(difficulty), CX, ORY + 42, 9,
            native.systemFont, P.ink)

    -- Score
    local rightEdge = ORX + ACTW - 42
    P.text(sg, "SCORE", rightEdge, 18, 9, native.systemFontBold, P.ink)
    local scoreDisplay = P.text(sg, "0", rightEdge, 36, 18,
                                 native.systemFontBold, cat.accentColor)
    local comboText = P.text(sg, "STREAK: 0", rightEdge, 58, 10,
                             native.systemFontBold, P.ink)

    -- Timer
    if timerPanel then display.remove(timerPanel) end
    timerPanel = P.roundRect(sg, CX, ORY + 72, 128, 36, 18,
                             P.paper, P.warmTan, 1.2)
    timerPanel.alpha = 0.96
    if state.timerRunning then
        P.text(sg, "TIME", CX, ORY + 58, 9, native.systemFont, P.ink)
        timerText = P.text(sg, "—:——", CX, ORY + 74, 18,
                            native.systemFontBold, P.ink)
        updateTimerDisplay()
    else
        P.text(sg, "NO TIMER", CX, ORY + 72, 10, native.systemFont, P.bark)
    end

    -- Words-found counter
    local foundTxt = P.text(sg, "0/"..state.totalWords, ORX + 42, ORY + 52, 14,
                              native.systemFontBold, P.ink)
    state._foundTxt = foundTxt

    -- ── Hint button ────────────────────────────────────
    local hints    = savedata.getHintsAvailable()
    local hintY    = ORY + HEADER_H - 18
    local hintBg   = display.newRoundedRect(sg, CX, hintY, 118, 28, 12)
    hintBg:setFillColor(P.ink[1]*0.12, P.ink[2]*0.12, P.ink[3]*0.12, 0.95)
    hintBg.strokeWidth = 1.5
    hintBg:setStrokeColor(P.ink[1],P.ink[2],P.ink[3], 0.28)

    local hintTxt = P.text(sg, "💡 HINT ("..hints..")", CX, hintY, 12,
                            native.systemFontBold, P.cream)

    -- ── Grid ──────────────────────────────────────────
    local gameGroup = display.newGroup()
    sg:insert(gameGroup)
    buildGrid(gameGroup, cat)

    -- ── Word list ──────────────────────────────────────
    local wordListY = state.gridOffY + state.gridSize * state.cellSize + 8
    local listTop   = wordListY + 8
    local listBottom = ORY + ACTH - 12
    local listHeight = math.max(WORD_LIST_H, listBottom - listTop)
    local wlBg = display.newRect(sg, CX, listTop + listHeight/2, ACTW, listHeight)
    wlBg:setFillColor(P.paper[1],P.paper[2],P.paper[3])
    local wlBorder = display.newRect(sg, CX, listTop, ACTW, 1.5)
    wlBorder:setFillColor(P.ink[1],P.ink[2],P.ink[3], 0.22)

    buildWordList(sg, state.placedWords, cat, listTop + 6)

    -- ── Touch ──────────────────────────────────────────
    setupTouch(gameGroup, cat, scoreDisplay,
               { foundTxt=foundTxt, hintTxt=hintTxt, comboText=comboText })

    -- Hint tap
    local hintOverlay = display.newRect(sg, CX, hintY, 118, 28)
    hintOverlay.alpha = 0
    hintOverlay.isHitTestable = true
    hintOverlay:addEventListener("tap", function()
        useHint(gameGroup, cat)
        timer.performWithDelay(120, function()
            hintTxt.text = "💡 HINT ("..savedata.getHintsAvailable()..")"
        end)
    end)

    -- ── Timer loop ─────────────────────────────────
    if state.timerRunning then
        local function tick()
            if state.paused then return end
            state.timerRemaining = state.timerRemaining - 1
            updateTimerDisplay()
            if state.timerRemaining <= 0 then
                composer.gotoScene("scene.result", {
                    effect="crossFade", time=600,
                    params={
                        score=state.score, wordsFound=state.wordsFound,
                        elapsed=state.timerLimit, categoryId=cat.id,
                        difficulty=difficulty, timeout=true,
                    }
                })
            end
        end
        self._timerHandle = timer.performWithDelay(1000, tick, 0)
    end

    -- Words-found counter updater
    local prev = 0
    local function updateCounter()
        if state.wordsFound ~= prev then
            prev = state.wordsFound
            foundTxt.text = state.wordsFound.."/"..state.totalWords
        end
    end
    self._foundTimer = timer.performWithDelay(300, updateCounter, 0)
    self._built = true
end

function scene:create(event)
    initScene(scene, event)
end

function scene:show(event)
    if event.phase ~= "will" then return end
    local params = event.params or {}
    -- If scene wasn't built yet, init is already done in create.
    if not self._built then return end
    -- If no params provided, nothing to change
    if not next(params) then return end

    -- If difficulty/category changed, rebuild the scene
    local changed = false
    if params.difficulty and params.difficulty ~= state.difficulty then changed = true end
    if params.categoryId and state.categoryData and params.categoryId ~= state.categoryData.id then changed = true end
    if params.mode and params.mode ~= (state.isDailyMode and "daily" or nil) then changed = true end

    if changed then
        clearSceneView(self.view)
        initScene(self, event)
    end
end

function scene:hide(event)
    if event.phase == "will" then
        if self._timerHandle then timer.cancel(self._timerHandle); self._timerHandle=nil end
        if self._foundTimer  then timer.cancel(self._foundTimer);  self._foundTimer=nil  end
    end
end

function scene:destroy(event)
    timerText = nil
end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)
return scene
