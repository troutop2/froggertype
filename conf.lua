function love.conf(t)
    t.identity = "froggertype"
    t.window.title = "FroggerType 🐸 | monkeytype clone"
    t.window.width = 1100
    t.window.height = 720
    t.window.minwidth = 850
    t.window.minheight = 550
    t.window.resizable = true
    t.window.vsync = 1
    t.modules.audio = true
    t.modules.sound = true
    t.modules.graphics = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.timer = true
    t.modules.window = true
    t.modules.system = true
end

