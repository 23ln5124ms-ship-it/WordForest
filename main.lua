-- ╔══════════════════════════════════════════════════════╗
-- ║         WORD FOREST — Solar 2D Word Search           ║
-- ║         Warm, Gentle, Eye-Friendly Edition           ║
-- ╚══════════════════════════════════════════════════════╝

local composer = require("composer")

display.setStatusBar(display.HiddenStatusBar)

-- Warm cream background (matches config.lua)
display.setDefault("background", 0.992, 0.965, 0.925)

composer.gotoScene("scene.loading", {
    effect = "fade",
    time   = 400
})
