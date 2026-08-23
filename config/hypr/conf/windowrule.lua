hl.window_rule({
    name = "float-volume-control",
    match = { class = "pavucontrol" },
    float = true,
})

hl.window_rule({
    name = "float-picture-in-picture",
    match = { class = "^$", title = "^(Picture in picture)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file-dialog",
    match = { title = "^(Open File)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "spotify-workspace",
    match = { class = "^(Spotify)$" },
    workspace = "4 silent",
})

hl.window_rule({
    name = "dunst-no-blur",
    match = { class = "^(Dunst)$" },
    no_blur = true,
})

hl.window_rule({
    name = "ghostty-scratchpad",
    match = { class = [[^(scratchpad\.ghostty)$]] },
    float = true,
    size = "1500 800",
    center = true,
    opacity = "0.9",
    animation = "slide",
})

hl.window_rule({
    name = "youtube-music-scratchpad",
    match = { title = "^(YouTube Music.*)$" },
    animation = "slide",
    opacity = "0.85 0.75",
    border_color = "rgb(ca9ee6)",
})

hl.window_rule({
    name = "discord-opacity",
    match = { class = "^(discord)$" },
    opacity = "0.8 0.6",
})

hl.window_rule({
    name = "spotify-opacity",
    match = { class = "^(spotify)$" },
    opacity = "0.8 0.6",
})

hl.window_rule({
    name = "zed-opacity",
    match = { class = "^(dev.zed.Zed)$" },
    opacity = "0.9 0.9",
})

hl.window_rule({
    name = "thunar-opacity",
    match = { class = "^(thunar)$" },
    opacity = "0.92 0.84",
})

hl.window_rule({
    name = "wlogout-opacity",
    match = { class = "^(wlogout)$" },
    opacity = "0.8 0.6",
})

hl.window_rule({
    name = "steam-opacity",
    match = { class = "^(steam)$" },
    opacity = "0.8 0.6",
})

hl.window_rule({
    name = "cs2-fullscreen",
    match = { class = "^(cs2|steam_app_730)$" },
    fullscreen = true,
})

for _, namespace in ipairs({ "waybar", "wlogout", "zen" }) do
    hl.layer_rule({
        name = namespace .. "-blur",
        match = { namespace = namespace },
        blur = true,
    })
end

hl.window_rule({
    name = "lazyt-scratchpad",
    match = { class = [[^(scratchpad\.lazyt)$]] },
    workspace = "special:lazyt silent",
    float = true,
    size = "1500 800",
    center = true,
    animation = "slide",
})

hl.window_rule({
    name = "soloist-scratchpad",
    match = { class = [[^(scratchpad\.soloist)$]] },
    workspace = "special:music silent",
    float = true,
    size = "1500 800",
    center = true,
    animation = "slide",
})
