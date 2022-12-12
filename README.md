# dotfile

It's a collection of my dotfiles for Arch & Mac OS X.

## Showcase for Arch :

![Qtile1](./screenshots/empty.png)
![picom1](./screenshots/picom-terminal-not-focused.png)
![picom2](./screenshots/picom-terminal-focused.png)
![rofi](./screenshots/rofi.png)

- Compositor : [picom](https://github.com/yshui/picom)
- Window Manager : [Qtile](http://www.qtile.org/)
- Window Switcher : [rofi](https://github.com/davatorium/rofi)
- Terminal Theme for Alacritty : [Catppuccin (Mocha Flavour)](https://github.com/catppuccin/alacritty)
- Terminal Font : [Caskaydia Cove](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/CascadiaCode.zip)
- Firefox : [Dracula](https://draculatheme.com/firefox)

### Installation (Arch Based) :

I've a bunch of packages installed but you can install the bare minimum to get started.
In case I'm missing something you can check the full list in the [packages](./os/archlinux/package.list) file.

```bash
paru -S nerd-fonts-cascadia-code nerd-fonts-ubuntu picom qtile-extras-git qtile-git rofi alacritty python2-iwscan xcb-util-cursor
```

Clone this repo:

```bash
git clone https://github.com/andres-ortizl/dot-files.git andrew-dotfiles
```

This will overwrite your current configuration files for this applications.
Copy configuration files to `~/.config`:

```bash
cd andrew-dotfiles/os/archlinux && cp -r alacritty/ picom/ qtile/ rofi/ tmux.conf ~/.config/
```

# Configuration

### Qtile autostart

You may need to change here the paths to the apps you want to autostart and its locations.
Do it on `os/archlinux/qtile/autostart.sh`

### Qtile themes

The themes are stored in `os/archlinux/qtile/themes/`. They are nothing but simple json file.
The default and only theme right now is `dracula.json` but you can add or edit this file.
You can change the default theme editing the file `os/archlinux/qtile/themes/config.json`

### Qtile Extra configuration

- edit default keybindings in `os/archlinux/qtile/settings/keys.py`
- edit widgets in `os/archlinux/qtile/settings/widgets.py`
- edit workspaces in `os/archlinux/qtile/settings/groups.py`

Some of the keybindings are:

- Terminal : `mod + enter`
- Rofi : `mod + space`
- Firefox : `mod + b`
- Reload qtile : `mod + ctrl + r`

### Rofi

Rofi is a window switcher, run dialog, ssh-launcher started as a clone of simpleswitcher.

- edit styles in `os/archlinux/rofi/config.rasi`
- Theme : Dracula

You can find extra themes here : [Rofi Themes](https://github.com/adi1090x/rofi)
Take into account that Rofi is being launch using a specific command in the Qtile keys config file, so you may need to
change it.

### Picom

Picom is a lightweight compositor for X11. It's used to add transparency to windows.
You can find the configuration file in `os/archlinux/picom/picom.conf`

### Redshift

Redshift is a program that adjusts the color temperature of your screen according to your surroundings. This may help
your eyes hurt less if you are working in front of the screen at night.
The default keybinding to toggle redshift is `mod + r`
You can reset it using the keybinding `mod + shift + r`

### Problems

In case the network widget is not working use `ip addr` to find your wireless modem, then :

```python
#Open the file ../qtile/settings/widget.py :

#Here you should find a list called *primary_widget*
#Find the line :

    widget.Net(**base(bg='color3'), interface='wlan0',
               mouse_callbacks={'Button1': lazy.spawn('iwgtk')}),

#Change the interface argument to your modem name, in my case 'wlan0'
```

Remember all of the keybinding will not work unless if finds all the apps I use :
To install all of the apps I use :

I also have some scripts for minor things like screenshot and toggling the mic.
You can find them in `os/archilinux/qtile/scripts.`