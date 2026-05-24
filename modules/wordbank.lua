-- modules/wordbank.lua
-- Word Bank — categories, colours, difficulty word-counts

local M = {}

-- ─── Category definitions ────────────────────────────────
-- color      = selection trail / accent text (warm variants)
-- accentColor= found-word letter colour
-- bgColor    = scene background (warm tinted)
M.categories = {
    {
        id   = "nature",
        name = "NATURE",
        icon = "🌿",
        color       = { 0.478, 0.620, 0.431 },   -- sage
        accentColor = { 0.239, 0.400, 0.196 },   -- moss
        bgColor     = { 0.961, 0.984, 0.949 },   -- very pale green-cream
        words = {
            "FOREST","RIVER","MOUNTAIN","VALLEY","MEADOW",
            "BLOSSOM","FERN","MOSS","WILLOW","CANYON",
            "GLACIER","TUNDRA","LAGOON","SAVANNA","DELTA",
            "PETAL","GROVE","MARSH","DUNE","BROOK",
        }
    },
    {
        id   = "ocean",
        name = "OCEAN",
        icon = "🌊",
        color       = { 0.494, 0.686, 0.769 },   -- sky blue
        accentColor = { 0.184, 0.431, 0.557 },   -- deep ocean
        bgColor     = { 0.941, 0.965, 0.980 },   -- pale blue-cream
        words = {
            "CORAL","WHALE","TRENCH","KELP","CURRENT",
            "ABYSS","TIDE","DOLPHIN","SHARK","PLANKTON",
            "REEF","NAUTILUS","URCHIN","BARNACLE","KRAKEN",
            "BRINE","SHOAL","LAGOON","SWELL","DRIFT",
        }
    },
    {
        id   = "cosmos",
        name = "COSMOS",
        icon = "✨",
        color       = { 0.545, 0.435, 0.667 },   -- dusk purple
        accentColor = { 0.329, 0.196, 0.502 },   -- deep violet
        bgColor     = { 0.969, 0.957, 0.984 },   -- pale lavender-cream
        words = {
            "NEBULA","PULSAR","QUASAR","COMET","GALAXY",
            "PHOTON","ORBIT","ECLIPSE","METEOR","AURORA",
            "SOLSTICE","ZENITH","COSMOS","NOVA","VORTEX",
            "PRISM","FLARE","CORONA","APOGEE","VOID",
        }
    },
    {
        id   = "ancient",
        name = "ANCIENT",
        icon = "🏛",
        color       = { 0.788, 0.663, 0.431 },   -- sand
        accentColor = { 0.478, 0.361, 0.118 },   -- dark amber
        bgColor     = { 0.996, 0.980, 0.953 },   -- warm parchment
        words = {
            "SPHINX","ORACLE","TEMPLE","RELIC","DYNASTY",
            "SCROLL","PHARAOH","LEGION","COLOSSUS","MURAL",
            "TABLET","RITUAL","THRONE","LABYRINTH","CODEX",
            "ALTAR","CITADEL","RUNE","TOTEM","MOSAIC",
        }
    },
}

-- ─── Word count per difficulty ────────────────────────────
local WORD_COUNTS = {
    easy   =  6,
    medium =  9,
    hard   = 12,
    expert = 16,
}

-- Returns a shuffled subset of words for the given category + difficulty
function M.getWords(categoryId, difficulty)
    local cat = nil
    for _, c in ipairs(M.categories) do
        if c.id == categoryId then cat = c; break end
    end
    if not cat then return {} end

    local count = WORD_COUNTS[difficulty] or 6
    count = math.min(count, #cat.words)

    -- Fisher-Yates shuffle on a copy
    local pool = {}
    for i, w in ipairs(cat.words) do pool[i] = w end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local out = {}
    for i = 1, count do out[i] = pool[i] end
    return out
end

-- Daily challenge uses a fixed cross-category set seeded by day
function M.getDailyWords()
    -- Seed by day so everyone gets the same puzzle
    math.randomseed(os.time() - (os.time() % 86400))
    local all = {}
    for _, cat in ipairs(M.categories) do
        for _, w in ipairs(cat.words) do all[#all+1] = w end
    end
    -- Shuffle
    for i = #all, 2, -1 do
        local j = math.random(i)
        all[i], all[j] = all[j], all[i]
    end
    math.randomseed(os.time())   -- restore random seed
    local out = {}
    for i = 1, 12 do out[i] = all[i] end
    return out
end

return M
