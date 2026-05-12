-- Persistence: save/load JSON data to disk
local json = require("lib.dkjson")
local C = require("consts")

local P = {}

local SAVE_FILE = "zen_fortress_save.json"

function P.save(data)
    local ok, str = pcall(json.encode, data)
    if not ok then
        return false, str
    end
    local success, err = love.filesystem.write(SAVE_FILE, str)
    return success, err
end

function P.load()
    if love.filesystem.getInfo(SAVE_FILE) == nil then
        return nil
    end
    local contents, err = love.filesystem.read(SAVE_FILE)
    if not contents or #contents == 0 then
        return nil
    end
    local ok, data = pcall(json.decode, contents)
    if not ok then
        return nil
    end
    return data
end

function P.getDefault()
    return {
        playerLevel = 1,
        playerXP = 0,
        totalXP = 0,
        wavesCleared = 0,
        highestWave = 0,
        unlockedTurrets = { "BLASTER", "CANNON" },
        turretLevels = {
            BLASTER = 1,
            CANNON = 1,
            SNIPER = 1,
            ZAPPER = 1,
        },
        permanentUpgrades = {},
        bankedGold = 0,
    }
end

return P