#!/bin/bash

BASE_DIR=$(pwd)

echo "[INFO] Atualizando o sistema..."
sudo apt update && sudo apt upgrade -y
clear

echo "[INSTALL] Instalando base e susas dependencias..."
# Geral
sudo apt-get install -y wget curl git thunar
sudo apt-get install -y arandr flameshot arc-theme feh i3blocks i3status i3 i3-wm lxappearance python3-pip rofi unclutter cargo papirus-icon-theme imagemagick
sudo apt-get install -y libxcb-shape0-dev libxcb-keysyms1-dev libpango1.0-dev libxcb-util0-dev xcb libxcb1-dev libxcb-icccm4-dev libyajl-dev libev-dev libxcb-xkb-dev libxcb-cursor-dev libxkbcommon-dev libxcb-xinerama0-dev libxkbcommon-x11-dev libstartup-notification0-dev libxcb-randr0-dev libxcb-xrm0 libxcb-xrm-dev autoconf meson
sudo apt-get install -y libxcb-render-util0-dev libxcb-shape0-dev libxcb-xfixes0-dev
clear

echo "[INSTALL] Instalando fonts..."
mkdir -p ~/.local/share/fonts/
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Iosevka.zip
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/RobotoMono.zip

unzip Iosevka.zip -d ~/.local/share/fonts/
unzip RobotoMono.zip -d ~/.local/share/fonts/

fc-cache -fv
clear

echo "[INFO] Movendo arquivos de configuração..."
mkdir -p ~/.config/i3
mkdir -p ~/.config/rofi

cp "$BASE_DIR/i3/config" ~/.config/i3
cp "$BASE_DIR/rofi/config.rasi" ~/.config/rofi

cp -r wallpapers ~/.wallpapers
chmod +x fehbg.sh
cp fehbg.sh ~/.config/i3/.fehbg

echo "[INFO] Reinicie a maquine."
echo "[INFO] Após reinicar a máquina, execute o lxappearance e escola o tema dark."
