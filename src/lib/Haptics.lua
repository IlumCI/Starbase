-- Haptics.lua: vibration feedback for mobile
-- Uses love.system.vibrate on supported platforms
-- Falls back silently on desktop/non-vibration devices

local C = require("consts")

local Haptics = {
    enabled = true,
}

function Haptics.init()
    -- Check if vibration is supported
    if love.system.getOS() == "Android" then
        Haptics.enabled = true
    elseif love.system.getOS() == "iOS" then
        Haptics.enabled = true
    else
        Haptics.enabled = false
    end
end

function Haptics.vibrate(duration)
    if not Haptics.enabled then return end
    duration = duration or C.HAPTIC.MEDIUM
    love.system.vibrate(duration / 1000)  -- convert ms to seconds
end

function Haptics.light()
    Haptics.vibrate(C.HAPTIC.LIGHT)
end

function Haptics.medium()
    Haptics.vibrate(C.HAPTIC.MEDIUM)
end

function Haptics.heavy()
    Haptics.vibrate(C.HAPTIC.HEAVY)
end

-- Impact feedback for button presses
function Haptics.press()
    Haptics.light()
end

-- Selection feedback
function Haptics.select()
    Haptics.light()
end

-- Success (e.g., wave complete)
function Haptics.success()
    Haptics.medium()
end

-- Warning (e.g., low HP)
function Haptics.warn()
    Haptics.heavy()
end

return Haptics