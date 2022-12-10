#!/bin/bash

# basic user
useradd -m andrew
passwd andrew
usermod -aG wheel andrew
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

#install paru repositories
mkdir -p /home/andrew/code/paru && cd !$ && \
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si

# install blackarch repositories
mkdir -p /home/andrew/code/blackarch && \
cd /home/andrew/code/blackarch && \
curl -O https://blackarch.org/strap.sh && \
chmod +x strap.sh
sudo su && \
./strap .sh



pacman -S sudo vim nano git kitty bat lsd zsh fzf firefox choose docker docker-compose kubectl make \
pacman-contrib stow cbatticon pamixer pcmanfm alacritty redshift scrot

paru -S jetbrains-toolbox discord spotify neovim picom-git bison xcb-util-cursor \
rofi-git bspwm-git qtile-git qtile-extras-git python2-iwscan python-dbus-next-git \
nitrogen-git nerd-fonts-cascadia-code arandr ightdm-webkit-theme-aether openssh tldrrofi feh sudo pulseaudio pavucontrol

paru -S gobuster sqlmap nmap john-git responder

# install zimrc
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh

# Configure docker
sudo usermod -a -G docker andrew
sudo systemctl enable docker
sudo systemctl start docker
