-- LÖVE2D config
function love.conf(t)
    t.window.title = "Zen Fortress"
    t.window.width = 1080
    t.window.height = 1920
    t.window.resizable = false
    t.window.fullscreen = false
    t.window.vsync = true
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.audio = false
    t.modules.video = false
    t.modules.sound = false
end