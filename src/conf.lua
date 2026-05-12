-- LÖVE2D config — mobile-ready
function love.conf(t)
    t.window.title = "Zen Fortress"
    t.window.width = 1080
    t.window.height = 1920
    t.window.resizable = true
    t.window.fullscreen = false
    t.window.vsync = true
    t.window.minwidth = 540
    t.window.minheight = 960
    t.window.highdpi = true  -- Retina support on mobile

    -- Enable all modules (keep for future audio/ambient)
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.audio = true
    t.modules.video = false
    t.modules.sound = true
end