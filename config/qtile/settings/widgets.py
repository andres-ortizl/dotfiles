from libqtile import widget
from .theme import colors


# Get the icons at https://www.nerdfonts.com/cheat-sheet (you need a Nerd Font)


def base(fg="text", bg="dark"):
    return {"foreground": colors[fg], "background": colors[bg]}


def separator():
    return widget.Sep(**base(), linewidth=0, padding=5)


def icon(fg="text", bg="dark", fontsize=16, text="?"):
    return widget.TextBox(**base(fg, bg), fontsize=fontsize, text=text, padding=3)


def powerline(fg="light", bg="dark"):
    return widget.TextBox(
        **base(fg, bg),
        text=" ",  # Icon: nf-oct-triangle_left
        fontsize=40,
        padding=-2.5,
    )


def workspaces():
    return [
        separator(),
        widget.GroupBox(
            **base(fg="light"),
            font="UbuntuMono Nerd Font",
            fontsize=19,
            margin_y=3,
            margin_x=0,
            padding_y=8,
            padding_x=5,
            borderwidth=1,
            active=colors["active"],
            inactive=colors["inactive"],
            rounded=False,
            highlight_method="block",
            urgent_alert_method="block",
            urgent_border=colors["urgent"],
            this_current_screen_border=colors["focus"],
            this_screen_border=colors["grey"],
            other_current_screen_border=colors["dark"],
            other_screen_border=colors["dark"],
            disable_drag=True,
        ),
        separator(),
        widget.WindowName(**base(fg="focus"), fontsize=14, padding=5),
        separator(),
    ]


def clock():
    pass


def layout():
    pass


def net():
    pass


def updates():
    pass


def memory():
    pass


def temp():
    pass


def cpu():
    pass


def volume():
    pass


primary_widgets = [
    *workspaces(),
    separator(),
    powerline("color10", "dark"),
    widget.CPU(**base(bg="color10"), format="C:{load_percent:4.1f}% ", padding=0),
    powerline("color12", "color10"),
    widget.ThermalSensor(**base(bg="color12"), padding=3, threshold=90),
    powerline("color6", "color12"),
    icon(bg="color6", text=" "),
    widget.Memory(**base(bg="color6"), padding=3, measure_mem="G"),
    powerline("color5", "color6"),
    icon(bg="color5", text=" "),
    widget.PulseVolume(**base(bg="color5"), padding=3, volume_app="pavucontrol"),
    powerline("color4", "color5"),
    icon(bg="color4", text=" "),  # Icon: nf-fa-download
    widget.CheckUpdates(
        background=colors["color4"],
        colour_have_updates=colors["text"],
        colour_no_updates=colors["text"],
        no_update_string="0",
        display_format="{updates}",
        update_interval=1800,
        custom_command="checkupdates",
    ),
    powerline("color3", "color4"),
    icon(bg="color3", text=" "),  # Icon: nf-fa-feed
    widget.Net(
        **base(bg="color3"),
        interface="enp34s0",
        format="U {up} D {down} T {total}",
        prefix="M",
    ),
    powerline("color2", "color3"),
    widget.CurrentLayoutIcon(**base(bg="color2"), scale=0.65),
    widget.CurrentLayout(**base(bg="color2"), padding=5),
    powerline("color1", "color2"),
    icon(bg="color1", fontsize=17, text=" "),  # Icon: nf-mdi-calendar_clock
    widget.Clock(**base(bg="color1"), format="%d/%m/%Y - %H:%M "),
    widget.Systray(background=colors["black"], padding=5),
]

secondary_widgets = [
    *workspaces(),
    separator(),
    powerline("color1", "dark"),
    widget.CurrentLayoutIcon(**base(bg="color1"), scale=0.65),
    widget.CurrentLayout(**base(bg="color1"), padding=5),
    powerline("color2", "color1"),
    widget.Clock(**base(bg="color2"), format="%d/%m/%Y - %H:%M "),
]

widget_defaults = {
    "font": "UbuntuMono Nerd Font Bold",
    "fontsize": 14,
    "padding": 1,
}
extension_defaults = widget_defaults.copy()
