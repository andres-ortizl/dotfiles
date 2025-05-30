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

# install zimrc
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh

# Configure docker
sudo usermod -a -G docker andrew
sudo systemctl enable docker
sudo systemctl start docker

# rofi styles
#https://github.com/adi1090x/rofi
