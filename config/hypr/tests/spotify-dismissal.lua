local bindings = {}
local submap = ""
local active_window
local music_workspace
local cursor = { x = 200, y = 200 }
local hide_count = 0

local dispatcher
dispatcher = setmetatable({}, {
    __index = function() return dispatcher end,
    __call = function() return dispatcher end,
})

local api = {
    dsp = dispatcher,
    config = function() end,
    bind = function(keys, callback, options)
        bindings[submap .. ":" .. keys] = { callback = callback, options = options }
    end,
    define_submap = function(name, callback)
        submap = name
        callback()
        submap = ""
    end,
    get_active_window = function() return active_window end,
    get_workspace = function(name)
        assert(name == "special:music")
        return music_workspace
    end,
    get_workspace_windows = function(workspace) return workspace.test_windows end,
    get_cursor_pos = function() return cursor end,
}

local test_path = arg[0]:match("^(.*)/") or "."
local environment = setmetatable({ hl = api }, { __index = _G })
assert(loadfile(test_path .. "/../conf/keybinding.lua", "t", environment))()

local escape = assert(bindings[":Escape"], "Missing Spotify Escape binding")
local mouse_keys = { "mouse:272", "mouse:273", "mouse:274" }
assert(escape.options.auto_consuming)
for _, key in ipairs(mouse_keys) do
    assert(bindings[":" .. key], "Missing outside-click binding: " .. key)
    assert(bindings[":" .. key].options.auto_consuming)
    assert(not bindings[":" .. key].options.ignore_mods, "Keep SUPER drag/resize separate")
end
assert(bindings["resize:escape"], "Preserve resize-mode Escape")
assert(bindings[":SUPER + Escape"], "Preserve power-menu shortcut")
assert(bindings[":SUPER + M"], "Preserve Spotify toggle")
assert(bindings[":SUPER + mouse:272"], "Preserve window dragging")
assert(bindings[":SUPER + mouse:274"], "Preserve window resizing")

local monitor = {
    set_special_workspace = function(self, options)
        assert(self == music_workspace.monitor)
        assert(next(options) == nil, "Hide, do not open another workspace")
        hide_count = hide_count + 1
        music_workspace.visible = false
    end,
}
music_workspace = { name = "special:music", visible = true, monitor = monitor }
local spotify = {
    class = "Spotify", workspace = music_workspace, mapped = true, hidden = false,
    at = { x = 100, y = 100 }, size = { x = 400, y = 300 },
}
music_workspace.test_windows = { spotify }
active_window = spotify

local checks = 0
local function check(binding, should_hide, label)
    local before = hide_count
    local result = binding.callback()
    assert(result.ok == should_hide, label .. ": wrong input consumption")
    assert(hide_count == before + (should_hide and 1 or 0), label .. ": wrong visibility change")
    checks = checks + 1
end

check(escape, true, "Escape hides focused Spotify")
check(escape, false, "Escape cannot reopen hidden Spotify")
music_workspace.visible = true
active_window = nil
check(escape, false, "Escape without a focused window passes through")
active_window = { class = "ghostty", workspace = music_workspace }
check(escape, false, "Escape in another app passes through")
active_window = { class = "Spotify", workspace = { name = "1", visible = true } }
check(escape, false, "Escape outside the music workspace passes through")
active_window = spotify
spotify.class = "spotify"
check(escape, true, "Lowercase Spotify class is supported")

for _, key in ipairs(mouse_keys) do
    local binding = bindings[":" .. key]
    music_workspace.visible = true
    for _, point in ipairs({ { 100, 100 }, { 200, 200 }, { 499, 399 } }) do
        cursor = { x = point[1], y = point[2] }
        check(binding, false, key .. " inside Spotify passes through")
    end
    cursor = { x = 500, y = 200 }
    active_window = nil
    check(binding, true, key .. " outside hides even without Spotify focus")
    check(binding, false, key .. " with Spotify hidden passes through")
end

music_workspace.visible = true
local dialog = {
    mapped = true, hidden = false,
    at = { x = 600, y = 100 }, size = { x = 200, y = 100 },
}
music_workspace.test_windows = { spotify, dialog }
cursor = { x = 650, y = 150 }
check(bindings[":mouse:272"], false, "A dialog in the music workspace remains clickable")
dialog.hidden = true
check(bindings[":mouse:272"], true, "Hidden windows do not block dismissal")
music_workspace = nil
check(bindings[":mouse:272"], false, "Clicks without a music workspace pass through")

print(string.format("PASS: %d Spotify dismissal checks and existing shortcuts preserved", checks))
