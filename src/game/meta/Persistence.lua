-- Persistence: save/load JSON data to disk
local json = require("json")
local C = require("consts")

local P = {}

local SAVE_FILE = "zen_fortress_save.json"

function P.getSavePath()
    return system.pathForFile(SAVE_FILE, system.DocumentsDirectory)
end

function P.load()
    local path = P.getSavePath()
    local file, err = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    if not content or #content == 0 then
        return nil
    end
    local ok, data = pcall(json.decode, content)
    if not ok then
        return nil
    end
    return data
end

function P.save(data)
    local path = P.getSavePath()
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    local ok, str = pcall(json.encode, data)
    if not ok then
        file:close()
        return false, str
    end
    file:write(str)
    file:close()
    return true
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