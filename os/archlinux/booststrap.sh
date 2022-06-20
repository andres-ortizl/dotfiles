useradd -m andrew
passwd andrew
usermod -aG wheel andrew
pacman -S sudo vim nano git kitty bat lsd zsh fzf firefox choose docker docker-compose kubectl
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers


# install zimrc

sudo usermod -a -G docker andrew
sudo systemctl enable docker
sudo systemctl start docker
# install snapd
git clone https://aur.archlinux.org/snapd.git
cd snapd
makepkg -si
sudo systemctl enable --now snapd.socket
sudo ln -s /var/lib/snapd/snap /snap

snap install spotify
snap install discord
snap install slack
snap install code --classic



#install paru repositories
mkdir -p /home/andrew/Desktop/repositories/paru && cd !$ && \
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si

# install blackarch repositories
mkdir -p /home/andrew/Desktop/repositories/blackarch && \
cd /home/andrew/Desktop/respositories/blackarch && \
curl -O https://blackarch.org/strap.sh && \
chmod +x strap.sh
sudo su && \
./strap .sh\


# install theme
# https://github.com/rxyhn/dotfiles
paru -S awesome-git



systemctl --user enable mpd.service
systemctl --user start mpd.service

