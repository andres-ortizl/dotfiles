local theme = require("conf.theme")
local colors = theme.palette

hl.config({
    general = {
        border_size = 2,
        col = {
            active_border = {
                colors = {
                    "rgba(" .. colors.mauve .. "ee)",
                    "rgba(" .. colors.blue .. "ee)",
                    "rgba(" .. colors.teal .. "ee)",
                    "rgba(" .. colors.pink .. "ee)",
                },
                angle = 45,
            },
            inactive_border = "rgba(" .. colors.overlay0 .. "aa)",
        },
        gaps_in = 5,
        gaps_out = 10,
    },
})
