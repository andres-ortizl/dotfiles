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

paru -S docker docker-compose openssh

sudo systemctl enable opensshd
sudo systemctl start opensshd

# /etc/ssh/sshd_config allow only local ips
#Match Address 192.168.1.*
	#X11Forwarding yes
	#AllowTcpForwarding yes
	#PermitTTY yes


# Configure docker
sudo usermod -a -G docker andrew
sudo systemctl enable docker
sudo systemctl start docker


sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.33/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con down "Wired connection 1" && sudo nmcli con up "Wired connection 1"

# rofi styles
#https://github.com/adi1090x/rofi
