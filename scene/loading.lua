-- scene/loading.lua
-- Warm splash screen with floating particle animation

local composer = require("composer")
local scene    = composer.newScene()
local P        = require("modules.palette")

local W = display.contentWidth
local H = display.contentHeight

-- ─── Floating particle ───────────────────────────────────
local symbols = { "✦", "❋", "✿", "◈", "◆", "❧", "✾" }
local warmCols = {
    P.sage, P.sageLt, P.mint, P.rose, P.amber, P.amberLt, P.bark, P.sand, P.sageDk
}

local function spawnParticle(parent, delay)
    local sym  = symbols[math.random(#symbols)]
    local col  = warmCols[math.random(#warmCols)]
    local px   = math.random(W)
    local size = math.random(10, 22)

    local leaf = display.newText({
        parent = parent, text = sym,
        x = px, y = H + 20,
        fontSize = size,
    })
    leaf:setTextColor(col[1], col[2], col[3])
    leaf.alpha = 0

    timer.performWithDelay(delay, function()
        if not (leaf and leaf.parent) then return end
        local dur = math.random(2200, 4500)
        local dx  = math.random(-70, 70)
        transition.to(leaf, {
            time     = dur,
            y        = -30,
            x        = leaf.x + dx,
            rotation = math.random(-360, 360),
            alpha    = 0,
            onStart  = function() transition.to(leaf, { time = 250, alpha = 0.55 }) end,
            onComplete = function() display.remove(leaf) end,
        })
    end)
end

-- ─── Scene ───────────────────────────────────────────────
function scene:create(event)
    local sg = self.view

    -- Warm cream background
    local bg = display.newRect(sg, W/2, H/2, W, H)
    bg:setFillColor(unpack(P.cream))

    -- Soft radial glow
    local glow = display.newCircle(sg, W/2, H * 0.42, W * 0.75)
    glow:setFillColor(P.rose[1], P.rose[2], P.rose[3])
    glow.alpha = 0

    local particles = display.newGroup()
    sg:insert(particles)

    -- Decorative rings
    local ring1 = display.newCircle(sg, W/2, H * 0.42, 90)
    ring1:setFillColor(0,0,0,0)
    ring1.strokeWidth = 1.5
    ring1:setStrokeColor(P.ink[1], P.ink[2], P.ink[3], 0.4)
    ring1.alpha = 0

    local ring2 = display.newCircle(sg, W/2, H * 0.42, 125)
    ring2:setFillColor(0,0,0,0)
    ring2.strokeWidth = 1.0
    ring2:setStrokeColor(P.ink[1], P.ink[2], P.ink[3], 0.25)
    ring2.alpha = 0

    -- Logo leaf
    local logoLeaf = P.text(sg, "🌿", W/2, H * 0.38, 64)
    logoLeaf.alpha = 0
    logoLeaf.yScale = 0.3

    -- Title
    local title = P.text(sg, "WORD FOREST", W/2, H * 0.47, 22,
                         native.systemFontBold, P.moss)
    title.alpha = 0

    local sub = P.text(sg, "find · discover · grow", W/2, H * 0.52, 12,
                       native.systemFont, P.bark)
    sub.alpha = 0

    -- Loading bar
    local barW    = W * 0.62
    local barBg   = display.newRoundedRect(sg, W/2, H - 110, barW, 6, 4)
    barBg:setFillColor(P.ink[1], P.ink[2], P.ink[3], 0.10)
    barBg.alpha = 0

    local barFill = display.newRoundedRect(sg, W/2 - barW/2, H - 110, 2, 6, 4)
    barFill.anchorX = 0
    barFill:setFillColor(P.mint[1], P.mint[2], P.mint[3])
    barFill.alpha = 0

    local loadTxt = P.text(sg, "Planting seeds…", W/2, H - 132, 12,
                            native.systemFontBold, P.ink)
    loadTxt.alpha = 0

    self._refs = {
        glow=glow, ring1=ring1, ring2=ring2,
        logoLeaf=logoLeaf, title=title, sub=sub,
        barBg=barBg, barFill=barFill, barW=barW,
        loadTxt=loadTxt,
        particles=particles,
    }
end

function scene:show(event)
    if event.phase ~= "did" then return end
    local r = self._refs

    -- Particles
    for i = 1, 20 do spawnParticle(r.particles, math.random(0, 3500)) end
    self._partTimer = timer.performWithDelay(900, function()
        spawnParticle(r.particles, 0)
    end, 0)

    -- Animations
    timer.performWithDelay(200, function()
        transition.to(r.glow,  { time=900, alpha=0.18 })
        transition.to(r.ring1, { time=600, alpha=1.0  })
        transition.to(r.ring2, { time=750, alpha=1.0  })
    end)
    timer.performWithDelay(500, function()
        transition.to(r.logoLeaf, {
            time=520, alpha=1.0, yScale=1.0,
            transition=easing.outElastic
        })
    end)
    timer.performWithDelay(950, function()
        transition.to(r.title, { time=380, alpha=1.0 })
    end)
    timer.performWithDelay(1150, function()
        transition.to(r.sub, { time=380, alpha=1.0 })
    end)

    -- Loading bar
    timer.performWithDelay(1400, function()
        transition.to(r.barBg,   { time=300, alpha=1.0 })
        transition.to(r.barFill, { time=300, alpha=1.0 })
        transition.to(r.loadTxt, { time=300, alpha=1.0 })

        local msgs = {
            "Planting seeds…",
            "Growing the forest…",
            "Hiding the words…",
            "Ready to explore!",
        }
        for step = 1, #msgs do
            timer.performWithDelay((step-1)*650, function()
                r.loadTxt.text = msgs[step]
                transition.to(r.barFill, {
                    time   = 580,
                    width  = r.barW * (step / #msgs),
                    transition = easing.outQuad,
                })
            end)
        end
    end)

    -- Auto-load into menu
    timer.performWithDelay(4200, function()
        transition.to(r.loadTxt, { time=300, alpha=0 })
        timer.performWithDelay(260, function()
            if self._partTimer then timer.cancel(self._partTimer) end
            composer.gotoScene("scene.menu", { effect="crossFade", time=600 })
        end)
    end)
end

function scene:hide(event)
    if event.phase == "will" then
        if self._partTimer then
            timer.cancel(self._partTimer)
            self._partTimer = nil
        end
    end
end

function scene:destroy(event) end

scene:addEventListener("create",  scene)
scene:addEventListener("show",    scene)
scene:addEventListener("hide",    scene)
scene:addEventListener("destroy", scene)
return scene
