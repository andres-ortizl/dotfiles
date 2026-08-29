hl.config({
    input = {
        kb_layout = "neo65",
        kb_variant = "",
        kb_model = "",
        kb_options = "caps:super",
        kb_rules = "",
        repeat_rate = 35,
        repeat_delay = 300,
        accel_profile = "flat",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

local mainMod = "SUPER"

local function bind(keys, description, dispatcher, options)
    options = options or {}
    options.description = description
    hl.bind(keys, dispatcher, options)
end

bind(mainMod .. " + Q", "Windows: Close active window", hl.dsp.window.close())
bind(mainMod .. " + Return", "Applications: Toggle terminal scratchpad", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/scratchpad"))
bind(mainMod .. " + T", "Applications: Open terminal", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/launch-app ghostty"))
bind(mainMod .. " + C", "Applications: Open browser", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/launch-app zen-bin --gtk-version=4"))
bind(mainMod .. " + Z", "Applications: Open Zed", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/launch-app $HOME/.local/bin/zed"))
bind(mainMod .. " + F", "Windows: Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind(mainMod .. " + SHIFT + F", "Windows: Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind(mainMod .. " + P", "Session: Exit Hyprland", hl.dsp.exit())
bind(mainMod .. " + V", "Windows: Toggle floating", hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + E", "Applications: Open file manager", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/launch-app thunar"))
bind(mainMod .. " + SPACE", "Applications: Open launcher", hl.dsp.exec_cmd("vicinae toggle"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind(mainMod .. " + " .. direction, "Windows: Focus " .. direction, hl.dsp.focus({ direction = direction }))
    bind(mainMod .. " + SHIFT + " .. direction, "Windows: Swap " .. direction, hl.dsp.window.swap({ direction = direction }))
end

for workspace = 1, 4 do
    bind(mainMod .. " + " .. workspace, "Workspaces: Focus workspace " .. workspace, hl.dsp.focus({ workspace = workspace }))
    bind(mainMod .. " + SHIFT + " .. workspace, "Workspaces: Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

bind(mainMod .. " + mouse_down", "Workspaces: Focus previous workspace", hl.dsp.focus({ workspace = "e-1" }))
bind(mainMod .. " + mouse_up", "Workspaces: Focus next workspace", hl.dsp.focus({ workspace = "e+1" }))

bind(mainMod .. " + G", "Windows: Toggle group", hl.dsp.group.toggle())
bind(mainMod .. " + Tab", "Windows: Focus next grouped window", hl.dsp.group.next())

bind(mainMod .. " + mouse:272", "Windows: Drag window", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:274", "Windows: Resize window", hl.dsp.window.resize(), { mouse = true })

bind("XF86AudioRaiseVolume", "Media: Raise volume", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control volume-up"), { repeating = true })
bind("XF86AudioLowerVolume", "Media: Lower volume", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control volume-down"), { repeating = true })
bind("XF86AudioMute", "Media: Toggle mute", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control volume-mute"))
bind("XF86AudioPlay", "Media: Play or pause", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control play-pause"))
bind("XF86AudioNext", "Media: Next track", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control next"))
bind("XF86AudioPrev", "Media: Previous track", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/media-control previous"))

bind("Print", "Capture: Copy screen", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/grimblast --notify --cursor copy screen"))
bind("SHIFT + Print", "Capture: Copy active window", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/grimblast --notify copy window"))
bind(mainMod .. " + SHIFT + S", "Capture: Copy selected area", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/grimblast --notify copy area"))
bind(mainMod .. " + CTRL + S", "Capture: Decode QR code", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/capture-qr"))
bind(mainMod .. " + SHIFT + A", "Capture: Annotate selected area", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/annotate-screenshot"))
bind(mainMod .. " + SHIFT + C", "Capture: Pick color", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/pick-color"))

bind(mainMod .. " + W", "Appearance: Open wallpaper picker", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-wallpaper-picker"))
bind(mainMod .. " + ALT + W", "Appearance: Select random wallpaper", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/setwall"))
bind(mainMod .. " + CTRL + equal", "Appearance: Increase desktop text", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/desktop-text-scale increase"))
bind(mainMod .. " + CTRL + minus", "Appearance: Decrease desktop text", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/desktop-text-scale decrease"))

bind(mainMod .. " + L", "Session: Lock session", hl.dsp.exec_cmd("hyprlock --immediate-render --no-fade-in"))
bind(mainMod .. " + X", "Clipboard: Open clipboard history", hl.dsp.exec_cmd("vicinae 'vicinae://launch/clipboard/history?toggle=true'"))

bind(mainMod .. " + N", "Notifications: Dismiss all", hl.dsp.exec_cmd("dunstctl close-all"))
bind(mainMod .. " + SHIFT + N", "Notifications: Replay previous", hl.dsp.exec_cmd("dunstctl history-pop"))
bind(mainMod .. " + CTRL + N", "Notifications: Toggle do not disturb", hl.dsp.exec_cmd("dunstctl set-paused toggle"))
bind(mainMod .. " + ALT + N", "Notifications: Open notification history", hl.dsp.exec_cmd("qs -c control-center ipc call notificationHistory toggle"))

bind(mainMod .. " + R", "Resize: Enter resize mode", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    bind("right", "Resize: Grow width", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
    bind("left", "Resize: Shrink width", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
    bind("up", "Resize: Shrink height", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    bind("down", "Resize: Grow height", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
    bind("escape", "Resize: Leave resize mode", hl.dsp.submap("reset"))
end)

bind(mainMod .. " + M", "Applications: Toggle Spotify", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/scratchpad-spotify.sh"))
bind(mainMod .. " + K", "Help: Open keybindings", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/launch-app ghostty -e $HOME/.local/bin/uv run $HOME/.config/keybindings-helper/show_keybindings.py"))
bind(mainMod .. " + Escape", "Session: Open power menu", hl.dsp.exec_cmd("$HOME/.config/wlogout/init.sh"))
