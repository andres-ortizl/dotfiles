from libqtile.config import Key
from libqtile.command import lazy

mod = "mod4"

keys = [Key(key[0], key[1], *key[2:]) for key in [
    # ------------ Window Configs ------------

    # Switch between windows in current stack pane
    ([mod], "k", lazy.layout.up()),
    ([mod], "l", lazy.layout.right()),

    # Change window sizes (MonadTall)
    ([mod, "shift"], "l", lazy.layout.grow()),
    ([mod, "shift"], "h", lazy.layout.shrink()),

    # Toggle floating
    ([mod, "shift"], "f", lazy.window.toggle_floating()),

    # Move windows up or down in current stack
    #([mod, "downarrow"], lazy.layout.shuffle_down()),

    # Toggle between different layouts as defined below
    ([mod], "Tab", lazy.next_layout()),
    ([mod, "shift"], "Tab", lazy.prev_layout()),

    # Kill window
    ([mod], "c", lazy.window.kill()),

    # Switch focus of monitors
    ([mod], "period", lazy.next_screen()),
    ([mod], "comma", lazy.prev_screen()),

    # Restart Qtile
    ([mod, "control"], "r", lazy.restart()),
    ([mod, "control"], "q", lazy.shutdown()),
    ([mod, "shift"], "q", lazy.spawn("alacritty -e sudo shutdown now")),


    # ------------ App Configs ------------

    # Menu
    ([mod], "space", lazy.spawn("/home/andrew/.config/rofi/launchers/type-4/launcher.sh", shell=True)),

    # Powermenu
    ([mod], "end", lazy.spawn("/home/andrew/.config/rofi/powermenu/type-2/powermenu.sh", shell=True)),

    # BetterLockscreen
    ([mod, "control"], "l", lazy.spawn(
        "betterlockscreen -l")),

    # Browser
    ([mod], "b", lazy.spawn("firefox")),

    # Terminal
    ([mod], "Return", lazy.spawn("alacritty")),

    # Redshift
    ([mod], "r", lazy.spawn("redshift -O 2400")),
    ([mod, "shift"], "r", lazy.spawn("redshift -x")),

    # Screenshot
    ([mod], "s", lazy.spawn("/home/andrew/.config/qtile/scripts/scrotshot.sh", shell=True)),
    ([mod, "shift"], "s", lazy.spawn(
        "/home/andrew/.config/qtile/scripts/scrot_select.sh")),

    # Spotify
    ([mod, "shift"], "m", lazy.spawn("spotify")),

    # ------------ Hardware Configs ------------

    # Volume
    ([], "XF86AudioLowerVolume", lazy.spawn(
        "pactl set-sink-volume @DEFAULT_SINK@ -5%"
    )),
    ([], "XF86AudioRaiseVolume", lazy.spawn(
        "pactl set-sink-volume @DEFAULT_SINK@ +5%"
    )),
    ([], "XF86AudioMute", lazy.spawn(
        "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    )),

    # Brightness
    ([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +10%")),
    ([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),
]]
