-- Lua config replaces the deprecated hyprlang configuration.

hl.config({
    misc = {
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
})

require("conf.monitor")
require("conf.autostart")
require("conf.apps")
require("conf.keybinding")
require("conf.windowrule")
require("conf.window")
require("conf.decoration")
require("conf.animation")
require("conf.environment")
require("conf.layout")
