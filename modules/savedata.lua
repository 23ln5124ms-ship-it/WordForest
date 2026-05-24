-- modules/savedata.lua
-- JSON persistence: scores, streaks, unlocks, hints, achievements

local json  = require("json")
local M     = {}

local SAVE_FILE = system.pathForFile("wordforest_save.json", system.DocumentsDirectory)

local defaults = {
    totalWordsFound  = 0,
    gamesCompleted   = 0,
    bestTimes        = {},      -- keyed "categoryId_difficulty" → seconds
    dailyStreak      = 0,
    lastDailyDate    = "",
    dailyCompleted   = false,
    achievements     = {},
    hintsUsed        = 0,
    hintsEarned      = 3,       -- 3 free starter hints
    unlockedCategories = { nature = true },
}

local data = {}

-- ─── Load / Save ─────────────────────────────────────────
function M.load()
    local file = io.open(SAVE_FILE, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded then
            data = decoded
            for k, v in pairs(defaults) do
                if data[k] == nil then data[k] = v end
            end
            return
        end
    end
    -- First run
    data = {}
    for k, v in pairs(defaults) do data[k] = v end
end

function M.save()
    local file = io.open(SAVE_FILE, "w")
    if file then
        file:write(json.encode(data))
        file:close()
    end
end

function M.get(key)        return data[key]        end
function M.set(key, value) data[key] = value; M.save() end

-- ─── Game completion ─────────────────────────────────────
function M.recordGameComplete(categoryId, difficulty, timeSecs, wordsFound)
    data.totalWordsFound = (data.totalWordsFound or 0) + wordsFound
    data.gamesCompleted  = (data.gamesCompleted  or 0) + 1

    -- Best time
    local key = categoryId .. "_" .. difficulty
    if not data.bestTimes[key] or timeSecs < data.bestTimes[key] then
        data.bestTimes[key] = timeSecs
    end

    -- Progressive unlocks (by games completed)
    local gc = data.gamesCompleted
    if gc >= 2  then data.unlockedCategories["ocean"]   = true end
    if gc >= 5  then data.unlockedCategories["cosmos"]  = true end
    if gc >= 10 then data.unlockedCategories["ancient"] = true end

    -- Earn a hint per game; expert gives 2
    local hintReward = (difficulty == "expert") and 2 or 1
    data.hintsEarned = (data.hintsEarned or 0) + hintReward

    -- Achievements
    if data.totalWordsFound >= 100 and not data.achievements["wordsmith"] then
        data.achievements["wordsmith"] = true
    end
    if data.gamesCompleted >= 10 and not data.achievements["explorer"] then
        data.achievements["explorer"] = true
    end
    if difficulty == "expert" and not data.achievements["treemaster"] then
        data.achievements["treemaster"] = true
    end

    M.save()
end

-- ─── Daily challenge ─────────────────────────────────────
function M.checkDailyStreak()
    local today     = os.date("%Y-%m-%d")
    local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
    local last      = data.lastDailyDate or ""

    if last == today then
        return data.dailyStreak, true       -- done today
    elseif last == yesterday then
        return data.dailyStreak, false      -- streak alive, not yet done
    else
        data.dailyStreak    = 0
        data.dailyCompleted = false
        M.save()
        return 0, false
    end
end

function M.completeDailyChallenge()
    local today = os.date("%Y-%m-%d")
    data.lastDailyDate    = today
    data.dailyCompleted   = true
    data.dailyStreak      = (data.dailyStreak or 0) + 1
    data.hintsEarned      = (data.hintsEarned or 0) + 2   -- bonus hints
    M.save()
    return data.dailyStreak
end

-- ─── Hints ───────────────────────────────────────────────
function M.useHint()
    local available = (data.hintsEarned or 0) - (data.hintsUsed or 0)
    if available > 0 then
        data.hintsUsed = (data.hintsUsed or 0) + 1
        M.save()
        return true
    end
    return false
end

function M.getHintsAvailable()
    return math.max(0, (data.hintsEarned or 0) - (data.hintsUsed or 0))
end

return M
