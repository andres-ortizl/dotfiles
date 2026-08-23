local monitor = {
    output = "DP-3",
    mode = "2560x1440@180",
    position = "0x0",
    scale = 1,
}

if package.searchpath("machine", package.path) then
    local machine = require("machine")
    monitor = machine.monitor or monitor
end

hl.monitor(monitor)
