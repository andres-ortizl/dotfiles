from libqtile import hook
import asyncio

from settings.keys import mod, keys
from settings.groups import groups
from settings.layouts import layouts, floating_layout
from settings.widgets import widget_defaults, extension_defaults
from settings.screens import screens
from settings.mouse import mouse
from settings.path import qtile_path


import subprocess
import os


@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/.config/qtile/autostart.sh')
    subprocess.Popen([home])


# @hook.subscribe.client_new
# async def groups(client):
#     await asyncio.sleep(0.5)
#     if client.name == "firefox":
#         client.static(1)
#     if client.name == "Spotify":
#         client.togroup(8)
#     elif client.name == "discord":
#         client.togroup(9)


main = None
dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = True
auto_fullscreen = True
focus_on_window_activation = 'urgent'
wmname = 'Qtile'
