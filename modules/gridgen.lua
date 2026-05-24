-- modules/gridgen.lua
-- Generates the word-search grid — all 8 directions
-- BUG FIX: original used  `if canPlace(...) do` which is invalid Lua;
--          corrected to    `if canPlace(...) then`

local M = {}

local DIRECTIONS = {
    { 0,  1}, { 0, -1},   -- right / left
    { 1,  0}, {-1,  0},   -- down  / up
    { 1,  1}, { 1, -1},   -- ↘ / ↙
    {-1,  1}, {-1, -1},   -- ↗ / ↖
}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- ─── Internal helpers ─────────────────────────────────────
local function canPlace(grid, word, row, col, dr, dc, size)
    local r, c = row, col
    for i = 1, #word do
        if r < 1 or r > size or c < 1 or c > size then return false end
        local existing = grid[r][c]
        local letter   = word:sub(i, i)
        if existing ~= "" and existing ~= letter then return false end
        r = r + dr
        c = c + dc
    end
    return true
end

local function placeWord(grid, word, size)
    -- Shuffle directions each attempt for better distribution
    local dirs = {}
    for i, d in ipairs(DIRECTIONS) do dirs[i] = d end
    for i = #dirs, 2, -1 do
        local j = math.random(i)
        dirs[i], dirs[j] = dirs[j], dirs[i]
    end

    local maxAttempts = 300
    for attempt = 1, maxAttempts do
        local dir = dirs[(attempt - 1) % #dirs + 1]
        local dr, dc = dir[1], dir[2]
        local row = math.random(size)
        local col = math.random(size)

        if canPlace(grid, word, row, col, dr, dc, size) then   -- ← FIXED
            local r, c = row, col
            local positions = {}
            for i = 1, #word do
                grid[r][c] = word:sub(i, i)
                positions[#positions + 1] = {r, c}
                r = r + dr
                c = c + dc
            end
            return true, positions
        end
    end
    return false, {}
end

-- ─── Public API ───────────────────────────────────────────
-- Returns: grid (2-D array), wordData (table keyed by word), placed (list)
function M.generate(words, size)
    -- Initialise empty grid
    local grid = {}
    for r = 1, size do
        grid[r] = {}
        for c = 1, size do grid[r][c] = "" end
    end

    local wordData = {}
    local placed   = {}

    -- Sort longest-first so big words get placed while the grid is still open
    local sorted = {}
    for i, w in ipairs(words) do sorted[i] = w end
    table.sort(sorted, function(a, b) return #a > #b end)

    for _, word in ipairs(sorted) do
        local ok, positions = placeWord(grid, word, size)
        if ok then
            placed[#placed + 1] = word
            wordData[word] = { positions = positions, found = false }
        end
    end

    -- Fill blanks with random letters
    for r = 1, size do
        for c = 1, size do
            if grid[r][c] == "" then
                local idx = math.random(#ALPHABET)
                grid[r][c] = ALPHABET:sub(idx, idx)
            end
        end
    end

    return grid, wordData, placed
end

return M
