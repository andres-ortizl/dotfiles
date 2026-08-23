hl.config({
    animations = {
        enabled = true,
    },
})

local curves = {
    linear = { 0, 0, 1, 1 },
    md3_standard = { 0.2, 0, 0, 1 },
    md3_decel = { 0.05, 0.7, 0.1, 1 },
    md3_accel = { 0.3, 0, 0.8, 0.15 },
    overshot = { 0.05, 0.9, 0.1, 1.1 },
    crazyshot = { 0.1, 1.5, 0.76, 0.92 },
    hyprnostretch = { 0.05, 0.9, 0.1, 1.0 },
    menu_decel = { 0.1, 1, 0, 1 },
    menu_accel = { 0.38, 0.04, 1, 0.07 },
    easeInOutCirc = { 0.85, 0, 0.15, 1 },
    easeOutCirc = { 0, 0.55, 0.45, 1 },
    easeOutExpo = { 0.16, 1, 0.3, 1 },
    softAcDecel = { 0.26, 0.26, 0.15, 1 },
    md2 = { 0.4, 0, 0.2, 1 },
}

for name, points in pairs(curves) do
    hl.curve(name, {
        type = "bezier",
        points = {
            { points[1], points[2] },
            { points[3], points[4] },
        },
    })
end

local animations = {
    { leaf = "windows", speed = 3, bezier = "md3_decel", style = "popin 60%" },
    { leaf = "windowsIn", speed = 3, bezier = "md3_decel", style = "popin 60%" },
    { leaf = "windowsOut", speed = 3, bezier = "md3_accel", style = "popin 60%" },
    { leaf = "border", speed = 10, bezier = "default" },
    { leaf = "fade", speed = 3, bezier = "md3_decel" },
    { leaf = "layers", speed = 2, bezier = "md3_decel", style = "slide" },
    { leaf = "layersIn", speed = 3, bezier = "menu_decel", style = "slide" },
    { leaf = "layersOut", speed = 1.6, bezier = "menu_accel", style = "slide" },
    { leaf = "fadeLayersIn", speed = 2, bezier = "menu_decel" },
    { leaf = "fadeLayersOut", speed = 4.5, bezier = "menu_accel" },
    { leaf = "workspaces", speed = 7, bezier = "menu_decel", style = "slide" },
    { leaf = "specialWorkspace", speed = 3, bezier = "md3_decel", style = "slidevert" },
}

for _, animation in ipairs(animations) do
    animation.enabled = true
    hl.animation(animation)
end
